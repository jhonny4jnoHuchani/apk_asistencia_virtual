import 'dart:io';
import 'dart:isolate';
import 'dart:ui'; // para blur
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'guia_demo_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/horario_provider.dart';
import '../services/marcado_service.dart';
import '../services/biometric_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/horario_list_view.dart';
import '../widgets/home/empty_state.dart';
import '../widgets/home/error_state.dart';
import '../widgets/home/camera_marcado_screen.dart';
import '../widgets/common/custom_snackbar.dart';
import '../widgets/common/loading_dialog.dart';
import 'login_screen.dart';
import 'historial_screen.dart';
import 'perfil_screen.dart';
import 'registro_facial_screen.dart';

// ============================================
// FUNCIÓN PARA ISOLATE - PROCESAMIENTO DE IMAGEN (SIN RECORTE)
// ============================================
Future<File> _processImageInIsolate(File originalFile) async {
  final receivePort = ReceivePort();

  await Isolate.spawn(
      _processImageIsolate, [receivePort.sendPort, originalFile.path]);

  final result = await receivePort.first as String;
  receivePort.close();

  return File(result);
}

void _processImageIsolate(List<dynamic> args) {
  final SendPort sendPort = args[0];
  final String filePath = args[1];

  try {
    final File file = File(filePath);
    final bytes = file.readAsBytesSync();
    final image = img.decodeImage(bytes);

    if (image == null) {
      sendPort.send(filePath);
      return;
    }

    final int maxWidth = 800;
    final int maxHeight = 1066;

    img.Image resizedImage = image;

    if (image.width > maxWidth || image.height > maxHeight) {
      final double widthRatio = maxWidth / image.width;
      final double heightRatio = maxHeight / image.height;
      final double scale = widthRatio < heightRatio ? widthRatio : heightRatio;

      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();

      resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
      );
    }

    final tempDir = Directory.systemTemp;
    final processedPath =
        '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final processedFile = File(processedPath);
    processedFile.writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85));

    try {
      file.deleteSync();
    } catch (_) {}

    sendPort.send(processedPath);
  } catch (e) {
    sendPort.send(filePath);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final MarcadoService _marcadoService = MarcadoService();
  final BiometricService _biometricService = BiometricService();

  // Estado de la camara
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _mostrarCamara = false;

  // Estado del marcado
  String? _tipoMarcado;
  int? _horarioIdSeleccionado;
  String? _etapaFoto;
  File? _fotoFrontal;
  File? _fotoGesto;
  File? _fotoConstancia;
  String? _gestoSolicitado;
  Position? _posicionGPS;

  // Nuevos estados
  bool _isProcessing = false;
  String? _currentDate;
  String _userName = 'Docente';
  String _userRole = 'docente';
  bool _isSending = false;
  bool _isCameraReady = false;

  // Constantes de diseño
  static const Color _primaryColor = Color(0xFF5B67CA);
  static const Color _secondaryColor = Color(0xFF8B95E0);
  static const Color _backgroundColor = Color(0xFFF8F9FC);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _warningColor = Color(0xFFFDCB6E);
  static const Color _dangerColor = Color(0xFFE17055);
  static const Color _infoColor = Color(0xFF74B9FF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadCurrentDate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HorarioProvider>().cargarHorarios();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      setState(() {
        _cameraController = null;
        _mostrarCamara = false;
        _isCameraReady = false;
      });
    }
  }

  void _loadUserData() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user != null) {
      _userName =
          user.nombreCompleto.isNotEmpty ? user.nombreCompleto : 'Docente';
      _userRole = user.rol.isNotEmpty
          ? user.rol[0].toUpperCase() + user.rol.substring(1)
          : 'Docente';
    } else {
      _userName = 'Docente';
      _userRole = 'Docente';
    }
  }

  void _loadCurrentDate() {
    final now = DateTime.now();
    _currentDate = DateFormat('EEEE, dd MMMM yyyy', 'es').format(now);
  }

  Future<bool> _solicitarPermisos() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      CustomSnackbar.showError(context, 'Se necesita permiso de camara');
      return false;
    }
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      CustomSnackbar.showError(context, 'Se necesita permiso de ubicacion');
      return false;
    }
    return true;
  }

  // ============================================
  // FLUJO DE MARCADO
  // ============================================
  Future<void> _iniciarMarcado(String tipo, int horarioId) async {
    if (_isProcessing) return;

    final biometricOk = await _biometricService.authenticate();
    if (!biometricOk) {
      final continuar = await _showBiometricDialog();
      if (continuar != true) return;
    }

    final permisosOk = await _solicitarPermisos();
    if (!permisosOk) return;

    try {
      _posicionGPS = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      CustomSnackbar.showError(context, 'No se pudo obtener la ubicacion GPS');
      return;
    }

    setState(() {
      _tipoMarcado = tipo;
      _horarioIdSeleccionado = horarioId;
      _fotoFrontal = null;
      _fotoGesto = null;
      _fotoConstancia = null;
      _isProcessing = true;
      _isCameraReady = false;
    });

    _gestoSolicitado = _generarGestoAleatorio();
    _etapaFoto = 'frontal';
    CustomSnackbar.showInfo(context, 'Toma tu foto frontal');
    await _abrirCamara();
  }

  Future<bool?> _showBiometricDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final isSmallScreen = screenWidth < 360;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.fingerprint_rounded, color: _primaryColor, size: 28),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isSmallScreen
                      ? 'Biometria no disp.'
                      : 'Biometria no disponible',
                  overflow: TextOverflow.visible,
                  softWrap: true,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text('Desea continuar sin autenticacion biometrica?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _abrirCamara() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        CustomSnackbar.showError(context, 'No se encontro camara');
        setState(() => _isProcessing = false);
        return;
      }

      CameraDescription camaraSeleccionada = _etapaFoto == 'constancia'
          ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first)
          : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first);

      await _cameraController?.dispose();

      _cameraController = CameraController(
        camaraSeleccionada,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _mostrarCamara = true;
          _isCameraReady = true;
        });
      }
    } catch (e) {
      CustomSnackbar.showError(context, 'Error al abrir la camara: $e');
      setState(() => _isProcessing = false);
    }
  }

  // ============================================
  // CAPTURA Y PROCESAMIENTO SIN RECORTE
  // ============================================
  Future<void> _capturarYMarcar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();

      if (_etapaFoto == 'frontal') {
        final processedFile = await _processImageInIsolate(File(photo.path));
        _fotoFrontal = processedFile;
        final instruccionGesto = _instruccionGesto(_gestoSolicitado!);
        await _switchToNextStage('gesto', instruccionGesto);
        return;
      }

      if (_etapaFoto == 'gesto') {
        final processedFile = await _processImageInIsolate(File(photo.path));
        _fotoGesto = processedFile;
        await _switchToNextStage(
            'constancia', 'Ahora toma la foto de constancia');
        return;
      }

      _fotoConstancia = await _processImageInIsolate(File(photo.path));

      await _cameraController?.dispose();
      setState(() {
        _mostrarCamara = false;
        _cameraController = null;
        _isCameraReady = false;
      });

      if (!mounted) return;
      await _enviarMarcado();
    } catch (e) {
      CustomSnackbar.showError(context, 'Error al capturar foto: $e');
      setState(() {
        _isProcessing = false;
        _isSending = false;
      });
    }
  }

  Future<void> _switchToNextStage(String nextStage, String message) async {
    await _cameraController?.dispose();
    setState(() {
      _mostrarCamara = false;
      _cameraController = null;
      _etapaFoto = nextStage;
      _isCameraReady = false;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    CustomSnackbar.showInfo(context, message);
    await _abrirCamara();
  }

  // ============================================
  // ENVIAR MARCADO CON GESTIÓN DE MEMORIA
  // ============================================
  Future<void> _enviarMarcado() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    final horarioProvider = context.read<HorarioProvider>();

    LoadingDialog.show(context, 'Procesando marcado...');

    try {
      final marcadoFuture = _tipoMarcado == 'entrada'
          ? _marcadoService.marcarEntrada(
              horarioId: _horarioIdSeleccionado!,
              latitud: _posicionGPS!.latitude,
              longitud: _posicionGPS!.longitude,
              gestoSolicitado: _gestoSolicitado!,
              fotoFrontal: _fotoFrontal!,
              fotoGesto: _fotoGesto!,
              fotoConstancia: _fotoConstancia,
            )
          : _marcadoService.marcarSalida(
              horarioId: _horarioIdSeleccionado!,
              latitud: _posicionGPS!.latitude,
              longitud: _posicionGPS!.longitude,
              gestoSolicitado: _gestoSolicitado!,
              fotoFrontal: _fotoFrontal!,
              fotoGesto: _fotoGesto!,
              fotoConstancia: _fotoConstancia,
            );

      final resultado = await marcadoFuture.timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('Tiempo de espera agotado'),
      );

      _limpiarArchivosTemporales();

      if (mounted) {
        Navigator.of(context).pop();

        // Si el gesto no coincidio, avisar con advertencia.
        // El marcado se guardo igual, asi que no es un error.
        if (resultado.gestoNoCoincide) {
          CustomSnackbar.showWarning(
            context,
            resultado.message,
          );
        } else {
          CustomSnackbar.showSuccess(
            context,
            _tipoMarcado == 'entrada'
                ? 'Entrada marcada correctamente'
                : 'Salida marcada correctamente',
          );
        }

        setState(() {
          _isProcessing = false;
          _isSending = false;
        });

        horarioProvider.refrescarTodo();
      }
    } catch (e) {
      _limpiarArchivosTemporales();

      if (mounted) {
        Navigator.of(context).pop();
        setState(() {
          _isProcessing = false;
          _isSending = false;
        });

        final mensaje = e.toString().replaceAll('Exception: ', '');

        // Detectar errores especificos del reconocimiento facial
        if (mensaje.toLowerCase().contains('quitate las gafas') ||
            mensaje.toLowerCase().contains('lentes')) {
          _mostrarDialogoLentes();
        } else if (mensaje.toLowerCase().contains('gesto no coincide') ||
            mensaje.toLowerCase().contains('gesto incorrecto')) {
          _mostrarDialogoGestoIncorrecto();
        } else if (mensaje.toLowerCase().contains('suplantacion') ||
            mensaje.toLowerCase().contains('spoofing')) {
          _mostrarDialogoSpoofing();
        } else {
          _mostrarDialogoError(mensaje);
        }
      }
    }
  }

//  reintar marcado
  Future<void> _reintentarMarcado() async {
    if (_horarioIdSeleccionado == null || _tipoMarcado == null) {
      // Si no hay contexto previo, cancelamos
      _cancelarMarcado();
      return;
    }

    final tipo = _tipoMarcado!;
    final horarioId = _horarioIdSeleccionado!;

    // Limpiar todo el estado anterior
    _limpiarArchivosTemporales();
    await _cameraController?.dispose();

    setState(() {
      _cameraController = null;
      _mostrarCamara = false;
      _isCameraReady = false;
      _etapaFoto = null;
      _fotoFrontal = null;
      _fotoGesto = null;
      _fotoConstancia = null;
      _gestoSolicitado = null;
      _isProcessing = false;
      _isSending = false;
    });

    await Future.delayed(const Duration(milliseconds: 200));

    // Volver a iniciar el marcado completo (biometría, permisos, GPS, cámara)
    await _iniciarMarcado(tipo, horarioId);
  }
  // ============================================
  // DIÁLOGOS DE ERROR
  // ============================================

  void _mostrarDialogoLentes() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.visibility_off_rounded, color: _warningColor, size: 28),
            const SizedBox(width: 12),
            const Text('Gafas detectadas',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quitate las gafas para continuar con la verificacion.'),
            SizedBox(height: 12),
            Text(
              'Las gafas pueden interferir con el reconocimiento facial.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelarMarcado();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _reintentarMarcado();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoGestoIncorrecto() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.pan_tool_rounded, color: _warningColor, size: 28),
            const SizedBox(width: 12),
            const Text('Gesto incorrecto',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El gesto "${_gestoSolicitado}" no coincide con lo solicitado.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _warningColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: _warningColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Realiza el gesto: ${_instruccionGesto(_gestoSolicitado!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelarMarcado();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _reintentarMarcado();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoSpoofing() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _dangerColor, size: 28),
            const SizedBox(width: 12),
            const Text('Suplantacion detectada',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El sistema ha detectado un posible intento de suplantacion.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              'Asegurate de estar frente a la camara y no usar fotos.',
              style: TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelarMarcado();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _reintentarMarcado();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoError(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: _dangerColor, size: 28),
            const SizedBox(width: 12),
            const Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensaje, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Puede intentar nuevamente o cancelar',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelarMarcado();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _reintentarMarcado();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelarMarcado() {
    setState(() {
      _mostrarCamara = false;
      _cameraController = null;
      _tipoMarcado = null;
      _horarioIdSeleccionado = null;
      _etapaFoto = null;
      _fotoFrontal = null;
      _fotoGesto = null;
      _fotoConstancia = null;
      _gestoSolicitado = null;
      _posicionGPS = null;
      _isProcessing = false;
      _isSending = false;
      _isCameraReady = false;
    });
    _limpiarArchivosTemporales();
  }

  Future<void> _cancelarCamara() async {
    await _cameraController?.dispose();
    setState(() {
      _mostrarCamara = false;
      _cameraController = null;
      _tipoMarcado = null;
      _horarioIdSeleccionado = null;
      _etapaFoto = null;
      _fotoFrontal = null;
      _fotoGesto = null;
      _fotoConstancia = null;
      _gestoSolicitado = null;
      _posicionGPS = null;
      _isProcessing = false;
      _isSending = false;
      _isCameraReady = false;
    });
    _limpiarArchivosTemporales();
  }

  void _limpiarArchivosTemporales() {
    try {
      _fotoFrontal?.delete();
      _fotoGesto?.delete();
      _fotoConstancia?.delete();
    } catch (_) {}
  }

  String _generarGestoAleatorio() {
    final gestos = ['arriba', 'abajo', 'izquierda', 'derecha'];
    final random = DateTime.now().millisecondsSinceEpoch % gestos.length;
    return gestos[random.toInt()];
  }

  String _instruccionGesto(String gesto) {
    switch (gesto) {
      case 'arriba':
        return 'Por favor, mire hacia arriba';
      case 'abajo':
        return 'Por favor, mire hacia abajo';
      case 'izquierda':
        return 'Por favor, gire a la izquierda';
      case 'derecha':
        return 'Por favor, gire a la derecha';
      default:
        return 'Por favor, mire al frente';
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: _dangerColor, size: 28),
            const SizedBox(width: 12),
            const Text('Cerrar sesion'),
          ],
        ),
        content: const Text('Esta seguro de cerrar sesion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarCamara && _cameraController != null && _isCameraReady) {
      return CameraMarcadoScreen(
        cameraController: _cameraController!,
        // cameras: _cameras,
        etapaFoto: _etapaFoto ?? 'frontal',
        gestoSolicitado: _gestoSolicitado,
        instruccionGesto: _instruccionGesto,
        onCapture: _capturarYMarcar,
        onCancel: _cancelarCamara,
        // onCameraChanged: (newController) {
        //   _cameraController = newController;
        // },
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: HomeAppBar(
        onHelp: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GuiaDemoScreen()),
        ),
        onRegistroFacial: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegistroFacialScreen()),
        ),
        onHistorial: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistorialScreen()),
        ),
        onPerfil: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PerfilScreen()),
        ),
        onLogout: _cerrarSesion,
      ),
      body: Column(
        children: [
          _buildWelcomeSection(),
          Expanded(
            child: Consumer<HorarioProvider>(
              builder: (context, horarioProvider, _) {
                if (horarioProvider.isLoading) {
                  return const LoadingIndicator(
                      mensaje: 'Cargando horarios...');
                }
                if (horarioProvider.error != null) {
                  return ErrorState(
                    error: horarioProvider.error!,
                    onRetry: horarioProvider.cargarHorarios,
                  );
                }
                if (horarioProvider.horarios.isEmpty) {
                  return EmptyState(onRefresh: horarioProvider.cargarHorarios);
                }
                return HorarioListView(
                  horarios: horarioProvider.horarios,
                  onRefresh: horarioProvider.refrescarTodo,
                  onMarcarEntrada: (horarioId) =>
                      _iniciarMarcado('entrada', horarioId),
                  onMarcarSalida: (horarioId) =>
                      _iniciarMarcado('salida', horarioId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final user = context.watch<AuthProvider>().user;
    final userName = user?.nombreCompleto ?? 'Usuario';
    final userRole = user?.rol ?? 'Docente';
    final userPhotoUrl = user?.fotoPerfilUrl;
    final hasPhoto = userPhotoUrl != null && userPhotoUrl.isNotEmpty;
    final firstName = userName.split(' ').first;
    final saludo = _getSaludo(); // NUEVO

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 1, 10, 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // ESMERILADO
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color.fromARGB(235, 255, 253, 253)
                  .withOpacity(0.7), // Fondo translucido
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // AVATAR CON ANILLO DEGRADADO
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFFAF52DE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2), // grosor del anillo
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: hasPhoto
                                ? Image.network(
                                    userPhotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildAvatarPlaceholder(firstName),
                                  )
                                : _buildAvatarPlaceholder(firstName),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            saludo, // "Buenos dias" / "Buenas tardes"
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            firstName,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ),
                    // CHIP "HOY" CON BLUR
                    _pillChip(
                      icon: Icons.calendar_today_rounded,
                      text: 'Hoy',
                      color: const Color(0xFF007AFF),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // CHIPS DE ROL Y FECHA
                Row(
                  children: [
                    _pillChip(
                      icon: Icons.badge_outlined,
                      text: userRole,
                      color: const Color(0xFF34C759),
                    ),
                    const SizedBox(width: 8),
                    if (_currentDate != null)
                      Expanded(
                        child: _pillChip(
                          icon: Icons.event_note_rounded,
                          text: _currentDate!,
                          color: const Color(0xFFFF9500),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// NUEVO: CHIP CON BLUR Y COLOR
  Widget _pillChip(
      {required IconData icon, required String text, required Color color}) {
    return ClipRRect(
      // borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.2),
            const Color(0xFF007AFF).withOpacity(0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
              color: Color(0xFF6C63FF),
              fontSize: 20,
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

// NUEVO: SALUDO DINAMICO
  String _getSaludo() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }
}
