import 'dart:io';
import 'dart:isolate';
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
// FUNCIÓN PARA ISOLATE - PROCESAMIENTO DE IMAGEN
// ============================================
Future<File> _cropImageInIsolate(File originalFile) async {
  // Crear un ReceivePort para recibir el resultado
  final receivePort = ReceivePort();

  // Iniciar el isolate
  await Isolate.spawn(
      _cropImageIsolate, [receivePort.sendPort, originalFile.path]);

  // Esperar el resultado
  final result = await receivePort.first as String;
  receivePort.close();

  return File(result);
}

void _cropImageIsolate(List<dynamic> args) {
  final SendPort sendPort = args[0];
  final String filePath = args[1];

  try {
    // Procesar la imagen en el isolate
    final File file = File(filePath);
    final bytes = file.readAsBytesSync();
    final image = img.decodeImage(bytes);

    if (image == null) {
      sendPort.send(filePath);
      return;
    }

    final originalWidth = image.width;
    final originalHeight = image.height;
    final targetRatio = 0.75;

    int cropWidth, cropHeight, offsetX, offsetY;

    if (originalWidth / originalHeight > targetRatio) {
      cropHeight = originalHeight;
      cropWidth = (originalHeight * targetRatio).round();
      offsetX = ((originalWidth - cropWidth) / 2).round();
      offsetY = 0;
    } else {
      cropWidth = originalWidth;
      cropHeight = (originalWidth / targetRatio).round();
      offsetX = 0;
      offsetY = ((originalHeight - cropHeight) / 2).round();
    }

    final croppedImage = img.copyCrop(
      image,
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
    );

    final int maxWidth = 800;
    img.Image resizedImage = croppedImage;
    if (croppedImage.width > maxWidth) {
      resizedImage = img.copyResize(
        croppedImage,
        width: maxWidth,
        height: (maxWidth / targetRatio).round(),
      );
    }

    final tempDir = Directory.systemTemp;
    final croppedPath =
        '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final croppedFile = File(croppedPath);
    croppedFile.writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85));

    // Eliminar el archivo original
    try {
      file.deleteSync();
    } catch (_) {}

    sendPort.send(croppedPath);
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

      // Liberar cámara anterior si existe
      await _cameraController?.dispose();

      _cameraController = CameraController(
        camaraSeleccionada,
        ResolutionPreset.low, // Usar resolución media para mejor rendimiento
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

  Future<void> _capturarYMarcar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();

      if (_etapaFoto == 'frontal') {
        // Procesar en isolate
        final croppedFile = await _cropImageInIsolate(File(photo.path));
        _fotoFrontal = croppedFile;
        final instruccionGesto = _instruccionGesto(_gestoSolicitado!);
        await _switchToNextStage('gesto', instruccionGesto);
        return;
      }

      if (_etapaFoto == 'gesto') {
        final croppedFile = await _cropImageInIsolate(File(photo.path));
        _fotoGesto = croppedFile;
        await _switchToNextStage(
            'constancia', 'Ahora toma la foto de constancia (opcional)');
        return;
      }

      // CONSTANCIA - sin recorte
      _fotoConstancia = File(photo.path);

      // Liberar cámara antes de enviar
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
    // Pequeña pausa para liberar recursos
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

    // Mostrar diálogo de carga con mensaje
    LoadingDialog.show(context, 'Procesando marcado...');

    try {
      // Ejecutar en un futuro con timeout
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

      await marcadoFuture.timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('Tiempo de espera agotado'),
      );

      // Limpiar archivos después del envío exitoso
      _limpiarArchivosTemporales();

      if (mounted) {
        Navigator.of(context).pop();

        CustomSnackbar.showSuccess(
          context,
          _tipoMarcado == 'entrada'
              ? 'Entrada marcada correctamente'
              : 'Salida marcada correctamente',
        );

        setState(() {
          _isProcessing = false;
          _isSending = false;
        });

        horarioProvider.refrescarTodo();
      }
    } catch (e) {
      // Limpiar archivos en caso de error también
      _limpiarArchivosTemporales();

      if (mounted) {
        Navigator.of(context).pop();
        setState(() {
          _isProcessing = false;
          _isSending = false;
        });
        _mostrarDialogoError(e.toString().replaceAll('Exception: ', ''));
      }
    }
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
              _enviarMarcado();
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
        cameras: _cameras,
        etapaFoto: _etapaFoto ?? 'frontal',
        gestoSolicitado: _gestoSolicitado,
        instruccionGesto: _instruccionGesto,
        onCapture: _capturarYMarcar,
        onCancel: _cancelarCamara,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade200, width: 1),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buenos dias,',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14, color: Colors.grey[700]),
                    const SizedBox(width: 5),
                    Text(
                      'Hoy',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildIosChip(icon: Icons.badge_outlined, text: userRole),
              const SizedBox(width: 8),
              if (_currentDate != null)
                Expanded(
                  child: _buildIosChip(
                      icon: Icons.event_note_rounded, text: _currentDate!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIosChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: const Color(0xFF6C63FF).withOpacity(0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
              color: Color(0xFF6C63FF),
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
