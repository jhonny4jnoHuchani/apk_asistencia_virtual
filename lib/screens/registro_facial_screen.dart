// screens/registro_facial_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/auth_provider.dart';
import '../services/reconocimiento_service.dart';
import '../widgets/wave_loading_indicator.dart';
import '../widgets/progress_section.dart';
import '../widgets/camera_preview_container.dart';
import '../widgets/status_bar.dart';
import '../widgets/start_button.dart';
import '../widgets/stop_button.dart';
import '../widgets/error_screen.dart';
import '../widgets/completed_dialog.dart';
import '../widgets/permission_dialog.dart';
import 'home_screen.dart';

class RegistroFacialScreen extends StatefulWidget {
  const RegistroFacialScreen({super.key});

  @override
  State<RegistroFacialScreen> createState() => _RegistroFacialScreenState();
}

class _RegistroFacialScreenState extends State<RegistroFacialScreen> {
  final ReconocimientoService _reconocimientoService = ReconocimientoService();
  final FlutterTts _flutterTts = FlutterTts();
  CameraController? _cameraController;
  bool _camaraInicializada = false;
  String? _errorCamara;
  bool _permisoConcedido = false;
  bool _ttsListo = false;
  bool _isLoading = false;
  String _loadingMessage = 'Iniciando...';
  double _loadingProgress = 0.0;

  int _capturasRealizadas = 0;
  final int _totalCapturas = 50;
  int _posicionActual = 0;
  int _posicionAnunciada = -1;
  bool _capturando = false;
  bool _modoAutomatico = false;
  int _calidadPromedio = 0;
  int _intentosFallidos = 0;
  final int _maxIntentosFallidos = 3;

  final List<Map<String, dynamic>> _posiciones = [
    {
      'nombre': 'centro',
      'descripcion': 'Mira directo a la cámara',
      'icono': Icons.center_focus_strong,
      'instruccion': 'Frente a la cámara'
    },
    {
      'nombre': 'izquierda',
      'descripcion': 'Gira ligeramente a la izquierda',
      'icono': Icons.arrow_back,
      'instruccion': 'Perfil izquierdo'
    },
    {
      'nombre': 'derecha',
      'descripcion': 'Gira ligeramente a la derecha',
      'icono': Icons.arrow_forward,
      'instruccion': 'Perfil derecho'
    },
    {
      'nombre': 'arriba',
      'descripcion': 'Inclina hacia arriba',
      'icono': Icons.arrow_upward,
      'instruccion': 'Mirando arriba'
    },
    {
      'nombre': 'abajo',
      'descripcion': 'Inclina hacia abajo',
      'icono': Icons.arrow_downward,
      'instruccion': 'Mirando abajo'
    },
    {
      'nombre': 'sonrisa',
      'descripcion': 'Sonríe naturalmente',
      'icono': Icons.emoji_emotions,
      'instruccion': 'Sonrisa natural'
    },
  ];

  @override
  void initState() {
    super.initState();
    _cargarEstadoInicial();
    _solicitarPermisosYIniciarCamara();
    _iniciarTTS();
  }

  void _cargarEstadoInicial() {
    final authProvider = context.read<AuthProvider>();
    _capturasRealizadas = authProvider.embeddingsCount;
    if (_capturasRealizadas > _totalCapturas) {
      _capturasRealizadas = _totalCapturas;
    }
    _posicionActual =
        (_capturasRealizadas * _posiciones.length) ~/ _totalCapturas;
    if (_posicionActual >= _posiciones.length) {
      _posicionActual = _posiciones.length - 1;
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _solicitarPermisosYIniciarCamara() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Solicitando permisos...';
      _loadingProgress = 0.1;
    });

    final status = await Permission.camera.request();

    if (status.isGranted) {
      setState(() {
        _permisoConcedido = true;
        _loadingMessage = 'Permiso concedido';
        _loadingProgress = 0.25;
      });
      await _iniciarCamara();
    } else if (status.isDenied) {
      setState(() {
        _errorCamara = 'Se necesita permiso de cámara para continuar';
        _isLoading = false;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _errorCamara = 'Permiso de cámara denegado permanentemente';
        _isLoading = false;
      });
      _mostrarDialogoPermiso();
    }
  }

  void _mostrarDialogoPermiso() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDialog(
        onOpenSettings: () async {
          Navigator.pop(context);
          await openAppSettings();
          _solicitarPermisosYIniciarCamara();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _iniciarTTS() async {
    try {
      await _flutterTts.setLanguage('es-MX');
      await _flutterTts.setSpeechRate(0.4);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);
      setState(() => _ttsListo = true);
    } catch (e) {
      print('Error al iniciar TTS: $e');
    }
  }

  Future<void> _iniciarCamara() async {
    try {
      setState(() {
        _loadingMessage = 'Buscando cámaras...';
        _loadingProgress = 0.4;
      });

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorCamara = 'No se encontró cámara disponible';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _loadingMessage = 'Configurando cámara frontal...';
        _loadingProgress = 0.6;
      });

      final frontal = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontal,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      setState(() {
        _loadingMessage = 'Inicializando cámara...';
        _loadingProgress = 0.8;
      });

      await _cameraController!.initialize();

      if (frontal.lensDirection == CameraLensDirection.front) {
        await _cameraController!.setFlashMode(FlashMode.off);
      }

      setState(() {
        _camaraInicializada = true;
        _isLoading = false;
        _loadingProgress = 1.0;
        _loadingMessage = '¡Listo!';
      });
    } catch (e) {
      setState(() {
        _errorCamara = 'Error al iniciar la cámara: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _hablarInstruccion(String posicion) async {
    if (!_ttsListo || !mounted) return;
    final data = _posiciones.firstWhere((p) => p['nombre'] == posicion);
    try {
      final instruccion = data['instruccion'] ?? data['descripcion'];
      await _flutterTts.speak(instruccion);
    } catch (_) {}
  }

  Future<void> _iniciarCapturaAutomatica() async {
    setState(() {
      _modoAutomatico = true;
      _intentosFallidos = 0;
    });

    await _flutterTts
        .speak('Iniciando registro facial. Sigue las instrucciones.');

    await Future.delayed(const Duration(milliseconds: 500));

    await _hablarInstruccion(_posiciones[_posicionActual]['nombre']!);
    _posicionAnunciada = _posicionActual;
    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = _capturasRealizadas; i < _totalCapturas; i++) {
      if (!mounted || !_modoAutomatico) break;

      await _capturarYEnviar();

      if (!mounted || !_modoAutomatico) break;

      await Future.delayed(const Duration(milliseconds: 400));

      if (_intentosFallidos >= _maxIntentosFallidos) {
        await _flutterTts
            .speak('Por favor, ajusta tu posición frente a la cámara');
        _intentosFallidos = 0;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (mounted && _capturasRealizadas >= _totalCapturas) {
      setState(() => _modoAutomatico = false);
      await _flutterTts.speak('Excelente. Registro completado correctamente.');
      _mostrarCompletado();
    } else if (mounted) {
      setState(() => _modoAutomatico = false);
    }
  }

  void _detenerCaptura() {
    setState(() => _modoAutomatico = false);
    _flutterTts.stop();
  }

  Future<void> _capturarYEnviar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _capturando = true);

    try {
      final photo = await _cameraController!.takePicture();
      final posicion = _posiciones[_posicionActual]['nombre']!;

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/temp_registro_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File(tempPath);
      await File(photo.path).copy(tempPath);

      final response = await _reconocimientoService.registrarEmbedding(
        posicion: posicion,
        image: tempFile,
      );

      await tempFile.delete();

      if (!mounted) return;

      final totalEmbeddings =
          response['total_embeddings'] ?? _capturasRealizadas + 1;
      final calidad = response['quality_score'] ?? 0.0;

      setState(() {
        _capturasRealizadas = totalEmbeddings;
        _calidadPromedio =
            ((_calidadPromedio * (totalEmbeddings - 1) + calidad) /
                    totalEmbeddings)
                .round();
        _capturando = false;
        _intentosFallidos = 0;
      });

      final nuevaPosicion = _calcularPosicion(totalEmbeddings);
      if (nuevaPosicion != _posicionActual) {
        setState(() => _posicionActual = nuevaPosicion);
        if (_modoAutomatico) {
          _posicionAnunciada = nuevaPosicion;
          await _hablarInstruccion(_posiciones[nuevaPosicion]['nombre']!);
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }

      final authProvider = context.read<AuthProvider>();
      await authProvider.actualizarPerfil();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _capturando = false;
        _intentosFallidos++;
      });

      _mostrarError('Error: ${e.toString().replaceAll('Exception: ', '')}');

      if (_intentosFallidos >= _maxIntentosFallidos) {
        await _flutterTts.speak(
            'Por favor, asegúrate de estar bien iluminado y frente a la cámara');
      }
    }
  }

  int _calcularPosicion(int capturas) {
    int posicion = (capturas * _posiciones.length) ~/ _totalCapturas;
    if (posicion >= _posiciones.length) posicion = _posiciones.length - 1;
    return posicion;
  }

  void _mostrarCompletado() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<AuthProvider>().actualizarPerfil();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => CompletedDialog(
          calidadPromedio: _calidadPromedio,
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
      );
    });
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorCamara != null) {
      return ErrorScreen(
        error: _errorCamara!,
        onRetry: _solicitarPermisosYIniciarCamara,
      );
    }

    if (_isLoading || !_camaraInicializada || _cameraController == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Registro Facial'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          elevation: 1,
        ),
        body: WaveLoadingIndicator(
          message: _loadingMessage,
          progress: _loadingProgress,
        ),
      );
    }

    final isComplete = _capturasRealizadas >= _totalCapturas;
    final pos = _posiciones[_posicionActual];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            ProgressSection(
              capturasRealizadas: _capturasRealizadas,
              totalCapturas: _totalCapturas,
              posicionActual: _posicionActual,
              totalPosiciones: _posiciones.length,
              calidadPromedio: _calidadPromedio,
            ),
            CameraPreviewContainer(
              cameraController: _cameraController!,
              posicion: pos,
              isCapturing: _capturando,
              isComplete: isComplete,
            ),
            StatusBar(
              posicion: pos,
              isAutomaticMode: _modoAutomatico,
              isCapturing: _capturando,
              capturasRealizadas: _capturasRealizadas,
              totalCapturas: _totalCapturas,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: _modoAutomatico
                  ? StopButton(
                      onPressed: _detenerCaptura,
                      capturasRealizadas: _capturasRealizadas,
                      totalCapturas: _totalCapturas,
                    )
                  : StartButton(onPressed: _iniciarCapturaAutomatica),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final prog = _capturasRealizadas / _totalCapturas;

    return AppBar(
      title: const Text(
        'Registro Facial Docente',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.deepPurple,
      elevation: 0,
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${(prog * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
