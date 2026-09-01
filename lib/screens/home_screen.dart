import 'dart:io';
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
import '../widgets/horario_card.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MarcadoService _marcadoService = MarcadoService();
  final BiometricService _biometricService = BiometricService();

  // Estado de la cámara
  CameraController? _cameraController;
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
    _loadUserData();
    _loadCurrentDate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HorarioProvider>().cargarHorarios();
    });
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

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<bool> _solicitarPermisos() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      CustomSnackbar.showError(context, 'Se necesita permiso de cámara');
      return false;
    }
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      CustomSnackbar.showError(context, 'Se necesita permiso de ubicación');
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
      CustomSnackbar.showError(context, 'No se pudo obtener la ubicación GPS');
      return;
    }

    setState(() {
      _tipoMarcado = tipo;
      _horarioIdSeleccionado = horarioId;
      _fotoFrontal = null;
      _fotoGesto = null;
      _fotoConstancia = null;
      _isProcessing = true;
    });

    _gestoSolicitado = _generarGestoAleatorio();
    CustomSnackbar.showInfo(context, _instruccionGesto(_gestoSolicitado!));

    _etapaFoto = 'frontal';
    await _abrirCamara();
  }

  Future<bool?> _showBiometricDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.fingerprint_rounded, color: _primaryColor, size: 28),
            const SizedBox(width: 12),
            const Text('Biometría no disponible'),
          ],
        ),
        content: const Text('¿Desea continuar sin autenticación biométrica?'),
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
      ),
    );
  }

  Future<void> _abrirCamara() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        CustomSnackbar.showError(
            context, 'No se encontró cámara en el dispositivo');
        return;
      }

      CameraDescription camaraSeleccionada;
      if (_etapaFoto == 'constancia') {
        camaraSeleccionada = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
      } else {
        camaraSeleccionada = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      }

      _cameraController = CameraController(
        camaraSeleccionada,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _mostrarCamara = true);
      }
    } catch (e) {
      CustomSnackbar.showError(context, 'Error al abrir la cámara');
    }
  }

  Future<void> _capturarYMarcar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    try {
      final XFile photo = await _cameraController!.takePicture();

      if (_etapaFoto == 'frontal') {
        // Recortar la foto a formato 3x4
        final croppedFile = await _cropTo3x4(File(photo.path));
        _fotoFrontal = croppedFile;
        await _switchToNextStage('gesto', _instruccionGesto(_gestoSolicitado!));
        return;
      }

      if (_etapaFoto == 'gesto') {
        // Recortar la foto a formato 3x4
        final croppedFile = await _cropTo3x4(File(photo.path));
        _fotoGesto = croppedFile;
        await _switchToNextStage(
            'constancia', 'Ahora toma la foto de constancia (opcional)');
        return;
      }

      // CONSTANCIA (sin recorte)
      _fotoConstancia = File(photo.path);
      await _cameraController?.dispose();
      setState(() {
        _mostrarCamara = false;
        _cameraController = null;
      });

      if (!mounted) return;
      await _enviarMarcado();
    } catch (e) {
      CustomSnackbar.showError(context, 'Error al capturar foto');
    }
  }

  Future<void> _switchToNextStage(String nextStage, String message) async {
    await _cameraController?.dispose();
    setState(() {
      _mostrarCamara = false;
      _cameraController = null;
      _etapaFoto = nextStage;
    });
    CustomSnackbar.showInfo(context, message);
    await _abrirCamara();
  }

  Future<void> _enviarMarcado() async {
    final horarioProvider = context.read<HorarioProvider>();

    LoadingDialog.show(context, 'Procesando marcado...');

    try {
      if (_tipoMarcado == 'entrada') {
        await _marcadoService.marcarEntrada(
          horarioId: _horarioIdSeleccionado!,
          latitud: _posicionGPS!.latitude,
          longitud: _posicionGPS!.longitude,
          gestoSolicitado: _gestoSolicitado!,
          fotoFrontal: _fotoFrontal!,
          fotoGesto: _fotoGesto!,
          fotoConstancia: _fotoConstancia,
        );
      } else {
        await _marcadoService.marcarSalida(
          horarioId: _horarioIdSeleccionado!,
          latitud: _posicionGPS!.latitude,
          longitud: _posicionGPS!.longitude,
          gestoSolicitado: _gestoSolicitado!,
          fotoFrontal: _fotoFrontal!,
          fotoGesto: _fotoGesto!,
          fotoConstancia: _fotoConstancia,
        );
      }

      if (mounted) Navigator.of(context).pop();

      CustomSnackbar.showSuccess(
        context,
        _tipoMarcado == 'entrada'
            ? 'Entrada marcada correctamente'
            : 'Salida marcada correctamente',
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        horarioProvider.refrescarTodo();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _isProcessing = false);
      }
      CustomSnackbar.showError(
        context,
        e.toString().replaceAll('Exception: ', ''),
      );
    }
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
    });
  }

  String _generarGestoAleatorio() {
    final gestos = ['arriba', 'abajo', 'izquierda', 'derecha'];
    final random = DateTime.now().millisecondsSinceEpoch % gestos.length;
    return gestos[random];
  }

  String _instruccionGesto(String gesto) {
    switch (gesto) {
      case 'arriba':
        return 'Por favor, mire hacia arriba suavemente';
      case 'abajo':
        return 'Por favor, mire hacia abajo suavemente';
      case 'izquierda':
        return 'Por favor, gire suavemente hacia la izquierda';
      case 'derecha':
        return 'Por favor, gire suavemente hacia la derecha';

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
            const Text('Cerrar sesión'),
          ],
        ),
        content: const Text('¿Estás seguro de cerrar sesión?'),
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
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarCamara && _cameraController != null) {
      return CameraMarcadoScreen(
        cameraController: _cameraController!,
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
                  return EmptyState(
                    onRefresh: horarioProvider.cargarHorarios,
                  );
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: _primaryColor.withOpacity(0.1),
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'D',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido,',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userRole,
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Hoy',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentDate != null)
            Row(
              children: [
                Icon(
                  Icons.today_rounded,
                  size: 14,
                  color: _textSecondary.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  _currentDate!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Método para recortar la imagen a formato 3x4
  Future<File> _cropTo3x4(File originalFile) async {
    try {
      // Leer la imagen
      final bytes = await originalFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return originalFile;

      // Calcular dimensiones para recorte 3x4
      final originalWidth = image.width;
      final originalHeight = image.height;

      // Relación 3:4 (ancho:alto) = 0.75
      final targetRatio = 0.75;

      int cropWidth, cropHeight, offsetX, offsetY;

      if (originalWidth / originalHeight > targetRatio) {
        // La imagen es más ancha de lo necesario
        cropHeight = originalHeight;
        cropWidth = (originalHeight * targetRatio).round();
        offsetX = ((originalWidth - cropWidth) / 2).round();
        offsetY = 0;
      } else {
        // La imagen es más alta de lo necesario
        cropWidth = originalWidth;
        cropHeight = (originalWidth / targetRatio).round();
        offsetX = 0;
        offsetY = ((originalHeight - cropHeight) / 2).round();
      }

      // Recortar la imagen
      final croppedImage = img.copyCrop(
        image,
        x: offsetX,
        y: offsetY,
        width: cropWidth,
        height: cropHeight,
      );

      // Guardar la imagen recortada
      final tempDir = await getTemporaryDirectory();
      final croppedPath =
          '${tempDir.path}/cropped_3x4_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 95));

      // Eliminar el archivo original para ahorrar espacio
      await originalFile.delete();

      return croppedFile;
    } catch (e) {
      print('Error al recortar imagen: $e');
      return originalFile;
    }
  }
}
