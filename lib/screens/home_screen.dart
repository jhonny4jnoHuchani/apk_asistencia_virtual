import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'guia_demo_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/horario_provider.dart';
import '../services/marcado_service.dart';
import '../services/biometric_service.dart';
import '../widgets/horario_card.dart';
import '../widgets/loading_indicator.dart';
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
  CameraController? _cameraController;
  bool _mostrarCamara = false;
  String? _tipoMarcado;
  int? _horarioIdSeleccionado;

  // NUEVO: Para las 3 fotos + gesto
  String? _etapaFoto; // 'frontal', 'gesto' o 'constancia'
  File? _fotoFrontal;
  File? _fotoGesto;
  File? _fotoConstancia;
  String? _gestoSolicitado;
  Position? _posicionGPS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HorarioProvider>().cargarHorarios();
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<bool> _solicitarPermisos() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _mostrarError('Se necesita permiso de cámara');
      return false;
    }
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      _mostrarError('Se necesita permiso de ubicación');
      return false;
    }
    return true;
  }

  // ============================================
  // FLUJO DE MARCADO
  // ============================================
  Future<void> _iniciarMarcado(String tipo, int horarioId) async {
    final biometricOk = await _biometricService.authenticate();
    if (!biometricOk) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Biometría no disponible'),
          content: const Text('¿Desea continuar sin autenticación biométrica?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continuar')),
          ],
        ),
      );
      if (continuar != true) return;
    }

    final permisosOk = await _solicitarPermisos();
    if (!permisosOk) return;

    // Obtener GPS ANTES de las fotos
    try {
      _posicionGPS = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _mostrarError('No se pudo obtener la ubicación GPS');
      return;
    }

    _tipoMarcado = tipo;
    _horarioIdSeleccionado = horarioId;
    _fotoFrontal = null;
    _fotoGesto = null;
    _fotoConstancia = null;

    // Generar gesto aleatorio
    _gestoSolicitado = _generarGestoAleatorio();
    _mostrarInfo(_instruccionGesto(_gestoSolicitado!));

    // Empezar con foto FRONTAL
    _etapaFoto = 'frontal';
    await _abrirCamara();
  }






  Future<void> _abrirCamara() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _mostrarError('No se encontró cámara en el dispositivo');
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
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      setState(() => _mostrarCamara = true);
    } catch (e) {
      _mostrarError('Error al abrir la cámara');
    }
  }




  Future<void> _capturarYMarcar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    try {
      final XFile photo = await _cameraController!.takePicture();

      // FRONTAL
      if (_etapaFoto == 'frontal') {
        _fotoFrontal = File(photo.path);
        await _cameraController?.dispose();
        setState(() {
          _mostrarCamara = false;
          _cameraController = null;
          _etapaFoto = 'gesto';
        });
        _mostrarInfo(_instruccionGesto(_gestoSolicitado!));
        await _abrirCamara();
        return;
      }

      // GESTO
      if (_etapaFoto == 'gesto') {
        _fotoGesto = File(photo.path);
        await _cameraController?.dispose();
        setState(() {
          _mostrarCamara = false;
          _cameraController = null;
          _etapaFoto = 'constancia';
        });
        _mostrarInfo('Ahora toma la foto de constancia (opcional)');
        await _abrirCamara();
        return;
      }

      // CONSTANCIA
      _fotoConstancia = File(photo.path);

      await _cameraController?.dispose();
      setState(() {
        _mostrarCamara = false;
        _cameraController = null;
      });

      if (!mounted) return;
      await _enviarMarcado();
    } catch (e) {
      _mostrarError('Error al capturar foto');
    }
  }




  Future<void> _enviarMarcado() async {
    final horarioProvider = context.read<HorarioProvider>();
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

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

      _mostrarExito(
        _tipoMarcado == 'entrada'
            ? 'Entrada marcada correctamente'
            : 'Salida marcada correctamente',
      );

      if (mounted) {
        horarioProvider.refrescarTodo();
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _mostrarError(e.toString().replaceAll('Exception: ', ''));
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
    });
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _mostrarInfo(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating),
    );
  }

    String _generarGestoAleatorio() {
    final gestos = ['arriba', 'abajo', 'izquierda', 'derecha', 'sonrisa'];
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
      case 'sonrisa':
        return 'Por favor, sonría para la cámara';
      default:
        return 'Por favor, mire al frente';
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar sesión')),
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
      return _buildCamaraScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Horarios'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ver guía de uso',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GuiaDemoScreen()),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.face),
              tooltip: 'Registro Facial',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RegistroFacialScreen()))),
          IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Historial',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistorialScreen()))),
          IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Perfil',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PerfilScreen()))),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: _cerrarSesion),
        ],
      ),
      body: Consumer<HorarioProvider>(
        builder: (context, horarioProvider, _) {
          if (horarioProvider.isLoading) {
            return const LoadingIndicator(mensaje: 'Cargando horarios...');
          }
          if (horarioProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(horarioProvider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: () => horarioProvider.cargarHorarios(),
                      child: const Text('Reintentar')),
                ],
              ),
            );
          }
          if (horarioProvider.horarios.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No tienes horarios para hoy',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: () => horarioProvider.cargarHorarios(),
                      child: const Text('Refrescar')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => horarioProvider.refrescarTodo(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: horarioProvider.horarios.length,
              itemBuilder: (context, index) {
                final horario = horarioProvider.horarios[index];
                return HorarioCard(
                  horario: horario,
                  onMarcarEntrada: () => _iniciarMarcado('entrada', horario.id),
                  onMarcarSalida: () => _iniciarMarcado('salida', horario.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCamaraScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_cameraController!),

            // Overlay óvalo SOLO para foto de rostro
            if (_etapaFoto == 'frontal' || _etapaFoto == 'gesto')
              Center(
                child: Container(
                  width: 280,
                  height: 350,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(140),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),

            // Texto informativo
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black54,
                child: Text(

                  _etapaFoto == 'frontal'
                      ? '📸 Foto FRONTAL (mire al frente)'
                      : _etapaFoto == 'gesto'
                          ? '📸 Foto del GESTO (${_instruccionGesto(_gestoSolicitado!)})'
                          : '📸 Foto de CONSTANCIA (entorno)',


                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Botones
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'cancel',
                    backgroundColor: Colors.red,
                    onPressed: _cancelarCamara,
                    child: const Icon(Icons.close),
                  ),
                  FloatingActionButton(
                    heroTag: 'capture',
                    backgroundColor: Colors.white,
                    onPressed: _capturarYMarcar,
                    child:
                        const Icon(Icons.camera, color: Colors.black, size: 32),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
