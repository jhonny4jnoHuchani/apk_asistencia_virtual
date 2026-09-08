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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final MarcadoService _marcadoService = MarcadoService();
  final BiometricService _biometricService = BiometricService();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _mostrarCamara = false;

  String? _tipoMarcado;
  int? _horarioIdSeleccionado;
  String? _etapaFoto;
  File? _fotoFrontal;
  File? _fotoGesto;
  File? _fotoConstancia;
  String? _gestoSolicitado;
  Position? _posicionGPS;

  bool _isProcessing = false;
  String? _currentDate;
  String _userName = 'Docente';
  String _userRole = 'docente';

  // COLORES iOS 17
  static const Color _primary = Color(0xFF007AFF);
  static const Color _success = Color(0xFF34C759);
  static const Color _warning = Color(0xFFFF9500);
  static const Color _danger = Color(0xFFFF3B30);
  static const Color _bg = Color(0xFFF2F2F7);
  static const Color _textPrimary = Color(0xFF1C1C1E);
  static const Color _textSecondary = Color(0xFF8E8E93);

  bool get _isTablet => MediaQuery.of(context).size.width > 700;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadCurrentDate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarHorarios());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarHorarios();
      _loadCurrentDate();
    }
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _userName =
          user.nombreCompleto.isNotEmpty ? user.nombreCompleto : 'Docente';
      _userRole = user.rol.isNotEmpty
          ? user.rol[0].toUpperCase() + user.rol.substring(1)
          : 'Docente';
    }
  }

  void _loadCurrentDate() {
    final now = DateTime.now();
    final fecha = DateFormat('EEEE, dd MMMM yyyy', 'es').format(now);
    if (mounted)
      setState(
          () => _currentDate = fecha[0].toUpperCase() + fecha.substring(1));
  }

  void _cargarHorarios() {
    final horarioProvider = context.read<HorarioProvider>();
    if (!horarioProvider.isLoading) horarioProvider.cargarHorarios();
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
          desiredAccuracy: LocationAccuracy.high);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.fingerprint_rounded, color: _primary, size: 24),
          const SizedBox(width: 8),
          const Text('Biometría', style: TextStyle(fontSize: 16))
        ]),
        content: const Text('¿Continuar sin autenticación biométrica?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar')),
        ],
      ),
    );
  }

  Future<void> _abrirCamara() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        CustomSnackbar.showError(context, 'No se encontró cámara');
        return;
      }
      CameraDescription camara = _etapaFoto == 'constancia'
          ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first)
          : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first);
      _cameraController =
          CameraController(camara, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _mostrarCamara = true);
    } catch (e) {
      CustomSnackbar.showError(context, 'Error al abrir la cámara: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _capturarYMarcar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      if (_etapaFoto == 'frontal') {
        _fotoFrontal = await _cropTo3x4(File(photo.path));
        await _switchToNextStage('gesto', _instruccionGesto(_gestoSolicitado!));
        return;
      }
      if (_etapaFoto == 'gesto') {
        _fotoGesto = await _cropTo3x4(File(photo.path));
        await _switchToNextStage(
            'constancia', 'Ahora foto de constancia (opcional)');
        return;
      }
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
            fotoConstancia: _fotoConstancia);
      } else {
        await _marcadoService.marcarSalida(
            horarioId: _horarioIdSeleccionado!,
            latitud: _posicionGPS!.latitude,
            longitud: _posicionGPS!.longitude,
            gestoSolicitado: _gestoSolicitado!,
            fotoFrontal: _fotoFrontal!,
            fotoGesto: _fotoGesto!,
            fotoConstancia: _fotoConstancia);
      }
      if (mounted) Navigator.of(context).pop();
      CustomSnackbar.showSuccess(
          context,
          _tipoMarcado == 'entrada'
              ? 'Entrada marcada correctamente'
              : 'Salida marcada correctamente');
      if (mounted) {
        setState(() => _isProcessing = false);
        horarioProvider.refrescarTodo();
        _loadCurrentDate();
        _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _isProcessing = false);
      }
      CustomSnackbar.showError(
          context, e.toString().replaceAll('Exception: ', ''));
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
    return gestos[DateTime.now().millisecondsSinceEpoch % gestos.length];
  }

  String _instruccionGesto(String gesto) => 'Por favor, mire al frente';

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.logout_rounded, color: _danger, size: 24),
          const SizedBox(width: 10),
          const Text('Cerrar sesión')
        ]),
        content: const Text('¿Estás seguro de cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _danger),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarCamara && _cameraController != null) {
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
      backgroundColor: _bg,
      appBar: HomeAppBar(
        onHelp: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const GuiaDemoScreen())),
        onRegistroFacial: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const RegistroFacialScreen())),
        onHistorial: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HistorialScreen())),
        onPerfil: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const PerfilScreen())),
        onLogout: _cerrarSesion,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000), // RESPONSIVE
          child: Column(children: [
            _buildWelcomeSection(),
            Expanded(child: _buildBody())
          ]),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<HorarioProvider>(
      builder: (context, horarioProvider, _) {
        if (horarioProvider.isLoading)
          return const LoadingIndicator(mensaje: 'Cargando horarios...');
        if (horarioProvider.error != null)
          return ErrorState(
              error: horarioProvider.error!,
              onRetry: horarioProvider.cargarHorarios);
        if (horarioProvider.horarios.isEmpty)
          return EmptyState(onRefresh: horarioProvider.cargarHorarios);
        return HorarioListView(
          horarios: horarioProvider.horarios,
          onRefresh: horarioProvider.refrescarTodo,
          onMarcarEntrada: (id) => _iniciarMarcado('entrada', id),
          onMarcarSalida: (id) => _iniciarMarcado('salida', id),
        );
      },
    );
  }

  Widget _buildWelcomeSection() {
    final user = context.watch<AuthProvider>().user;
    final userName = user?.nombreCompleto ?? 'Usuario';
    final userRole = user?.rol ?? 'Docente';
    final userPhotoUrl = user?.fotoPerfilUrl;
    final hasPhoto = userPhotoUrl != null && userPhotoUrl.isNotEmpty;
    final firstName = userName.split(' ').first;
    final saludo = _getSaludo();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          _isTablet ? 24 : 14, 14, _isTablet ? 24 : 14, 6), // REDUCIDO
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 42, height: 42, // REDUCIDO de 48 a 42
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade200)),
              child: ClipOval(
                  child: hasPhoto
                      ? Image.network(userPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildAvatarPlaceholder(firstName))
                      : _buildAvatarPlaceholder(firstName)),
            ),
          ),
          const SizedBox(width: 10), // REDUCIDO
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(saludo,
                  style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500)), // 14 -> 12
              Text(firstName,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3)), // 22 -> 19
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 5), // REDUCIDO
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_rounded,
                  size: 12, color: _textSecondary),
              const SizedBox(width: 4),
              const Text('Hoy',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 10), // REDUCIDO
        SingleChildScrollView(
          // RESPONSIVE: scroll horizontal en chips
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildIosChip(icon: Icons.badge_outlined, text: userRole),
            const SizedBox(width: 6),
            if (_currentDate != null)
              _buildIosChip(
                  icon: Icons.event_note_rounded, text: _currentDate!),
          ]),
        ),
      ]),
    );
  }

  String _getSaludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Widget _buildIosChip({required IconData icon, required String text}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 5), // REDUCIDO
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _textSecondary),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _textPrimary)), // 12 -> 11
      ]),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: _primary.withOpacity(0.15),
      child: Center(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                  color: _primary, fontSize: 16, fontWeight: FontWeight.w700))),
    );
  }

  Future<File> _cropTo3x4(File originalFile) async {
    try {
      final bytes = await originalFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return originalFile;
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
      final croppedImage = img.copyCrop(image,
          x: offsetX, y: offsetY, width: cropWidth, height: cropHeight);
      final tempDir = await getTemporaryDirectory();
      final croppedPath =
          '${tempDir.path}/cropped_3x4_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(
          img.encodeJpg(croppedImage, quality: 90)); // REDUCIDO quality
      await originalFile.delete();
      return croppedFile;
    } catch (e) {
      debugPrint('Error al recortar imagen: $e');
      return originalFile;
    }
  }
}
