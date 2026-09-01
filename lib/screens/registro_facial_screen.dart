// screens/registro_facial_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
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
import 'reset_password_screen.dart';

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
  final int _totalCapturas = 76;
  int _posicionActual = 0;
  int _posicionAnunciada = -1;
  bool _capturando = false;
  bool _modoAutomatico = false;
  int _calidadPromedio = 0;
  int _intentosFallidos = 0;
  final int _maxIntentosFallidos = 3;

  // Variables para manejo de lentes
  bool _mostrarAlertaLentes = false;
  String _mensajeLentes = '';

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

  final List<Map<String, dynamic>> _posiciones = [
    {
      'nombre': 'centro',
      'descripcion': 'Mira directo a la cámara',
      'icono': Icons.center_focus_strong_rounded,
      'instruccion': 'Frente a la cámara',
      'total': 10,
      'color': Color(0xFF5B67CA),
    },
    {
      'nombre': 'izquierda',
      'descripcion': 'Gira SUAVEMENTE a la izquierda',
      'icono': Icons.arrow_back_rounded,
      'instruccion': 'Perfil izquierdo suave',
      'total': 14,
      'color': Color(0xFF74B9FF),
    },
    {
      'nombre': 'derecha',
      'descripcion': 'Gira SUAVEMENTE a la derecha',
      'icono': Icons.arrow_forward_rounded,
      'instruccion': 'Perfil derecho suave',
      'total': 14,
      'color': Color(0xFF00B894),
    },
    {
      'nombre': 'arriba',
      'descripcion': 'Inclina SUAVEMENTE hacia arriba',
      'icono': Icons.arrow_upward_rounded,
      'instruccion': 'Mirando arriba suavemente',
      'total': 14,
      'color': Color(0xFFFDCB6E),
    },
    {
      'nombre': 'abajo',
      'descripcion': 'Inclina SUAVEMENTE hacia abajo',
      'icono': Icons.arrow_downward_rounded,
      'instruccion': 'Mirando abajo suavemente',
      'total': 14,
      'color': Color(0xFFE17055),
    },
    {
      'nombre': 'sonrisa',
      'descripcion': 'Sonríe naturalmente',
      'icono': Icons.emoji_emotions_rounded,
      'instruccion': 'Sonrisa natural',
      'total': 10,
      'color': Color(0xFFA29BFE),
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
    _posicionActual = _calcularPosicion(_capturasRealizadas);
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
        ResolutionPreset.high,
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
        _loadingMessage = 'Listo!';
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
      _mostrarAlertaLentes = false;
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

    setState(() {
      _capturando = true;
      _mostrarAlertaLentes = false;
    });

    try {
      final photo = await _cameraController!.takePicture();
      final posicion = _posiciones[_posicionActual]['nombre']!;

      final processedFile = await _procesarImagen(File(photo.path));

      final response = await _reconocimientoService.registrarEmbedding(
        posicion: posicion,
        image: processedFile,
      );

      await processedFile.delete();

      if (!mounted) return;

      // ============================================
      // VERIFICAR DETECCION DE LENTES
      // ============================================
      if (_reconocimientoService.isEyeglassDetected(response)) {
        setState(() {
          _capturando = false;
          _intentosFallidos++;
          _mostrarAlertaLentes = true;
          _mensajeLentes = _reconocimientoService.getEyeglassMessage(response);
        });

        await _flutterTts.speak('Por favor, quítese las gafas');
        return;
      }

      // ============================================
      // VERIFICAR SPOOFING
      // ============================================
      if (_reconocimientoService.isSpoofingDetected(response)) {
        setState(() {
          _capturando = false;
          _intentosFallidos++;
        });
        _mostrarError('Posible suplantación detectada');
        await _flutterTts.speak('Posible suplantación detectada');
        return;
      }

      // ============================================
      // PROCESAR REGISTRO EXITOSO
      // ============================================
      if (response['success'] == true) {
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
          _mostrarAlertaLentes = false;
        });

        final authProvider = context.read<AuthProvider>();
        await authProvider.actualizarPerfil();

        final nuevaPosicion = _calcularPosicion(totalEmbeddings);
        if (nuevaPosicion != _posicionActual) {
          setState(() => _posicionActual = nuevaPosicion);
          if (_modoAutomatico) {
            _posicionAnunciada = nuevaPosicion;
            await _hablarInstruccion(_posiciones[nuevaPosicion]['nombre']!);
            await Future.delayed(const Duration(milliseconds: 400));
          }
        }
      } else {
        final mensaje = response['message'] ?? 'Error al registrar';
        _mostrarError(mensaje);

        setState(() {
          _capturando = false;
          _intentosFallidos++;
        });
      }
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

  Future<File> _procesarImagen(File originalFile) async {
    try {
      final bytes = await originalFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            '${tempDir.path}/temp_registro_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final tempFile = File(tempPath);
        await originalFile.copy(tempPath);
        await originalFile.delete();
        return tempFile;
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

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/temp_registro_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File(tempPath);

      await tempFile.writeAsBytes(
        img.encodeJpg(resizedImage, quality: 90),
      );

      await originalFile.delete();
      return tempFile;
    } catch (e) {
      print('Error al procesar imagen: $e');
      try {
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            '${tempDir.path}/temp_registro_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final tempFile = File(tempPath);
        await originalFile.copy(tempPath);
        await originalFile.delete();
        return tempFile;
      } catch (copyError) {
        print('Error al copiar imagen: $copyError');
        return originalFile;
      }
    }
  }

  int _calcularPosicion(int capturas) {
    int acumulado = 0;
    for (int i = 0; i < _posiciones.length; i++) {
      acumulado += _posiciones[i]['total'] as int;
      if (capturas < acumulado) return i;
    }
    return _posiciones.length - 1;
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
            final authProvider = context.read<AuthProvider>();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(
                  token: '', // Se obtendrá desde el AuthProvider
                  email: authProvider.user?.email ?? '',
                  fromRegistration:
                      true, // Indica que viene del registro facial
                ),
              ),
            );
          },
        ),
      );
    });
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _dangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================
  // DIALOGO DE ALERTA POR LENTES
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
            Icon(
              Icons.visibility_off_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Gafas detectadas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_emotions_rounded,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              _mensajeLentes.isNotEmpty
                  ? _mensajeLentes
                  : 'Por favor, quítese las gafas para continuar con el registro facial.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Quítate las gafas y presiona "Intentar de nuevo"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
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
              setState(() {
                _mostrarAlertaLentes = false;
                _intentosFallidos = 0;
              });
            },
            child: const Text('Intentar de nuevo'),
          ),
        ],
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
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Registro Facial',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: _textPrimary,
          elevation: 0,
          centerTitle: true,
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
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
            // ============================================
            // OVERLAY DE ALERTA DE LENTES
            // ============================================
            if (_mostrarAlertaLentes)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icono animado
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0.8, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.orange.shade700,
                                size: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Gafas detectadas',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _mensajeLentes.isNotEmpty
                                ? _mensajeLentes
                                : 'Por favor, quítese las gafas para continuar.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Quítate las gafas y presiona "Intentar de nuevo"',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _mostrarAlertaLentes = false;
                                  _intentosFallidos = 0;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text(
                                'Intentar de nuevo',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
          color: _textPrimary,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: _textPrimary,
      elevation: 0,
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.percent_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${(prog * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
