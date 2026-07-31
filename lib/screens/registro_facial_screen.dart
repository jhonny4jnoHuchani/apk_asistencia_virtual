import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/auth_provider.dart';
import '../services/reconocimiento_service.dart';
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

  int _capturasRealizadas = 0;
  final int _totalCapturas = 50;
  int _posicionActual = 0;
  int _posicionAnunciada = -1; // última posición que ya se anunció por voz
  bool _capturando = false;
  bool _modoAutomatico = false;
  bool _ttsListo = false;

  final List<Map<String, String>> _posiciones = [
    {'nombre': 'centro',     'descripcion': 'Mira directo a la cámara',        'icono': '🎯'},
    {'nombre': 'izquierda',  'descripcion': 'Gira a la izquierda',             'icono': '👈'},
    {'nombre': 'derecha',    'descripcion': 'Gira a la derecha',               'icono': '👉'},
    {'nombre': 'arriba',     'descripcion': 'Inclina hacia arriba',            'icono': '👆'},
    {'nombre': 'abajo',      'descripcion': 'Inclina hacia abajo',             'icono': '👇'},
    {'nombre': 'sonrisa',    'descripcion': 'Sonríe a la cámara',              'icono': '😊'},
  ];

  @override
  void initState() {
    super.initState();
    // Si el docente ya tenía capturas previas (ej. cerró la app a mitad
    // del registro), retomamos el conteo en vez de empezar de 0.
    _capturasRealizadas = context.read<AuthProvider>().embeddingsCount;
    if (_capturasRealizadas > _totalCapturas) {
      _capturasRealizadas = _totalCapturas;
    }
    _posicionActual = (_capturasRealizadas * _posiciones.length) ~/ _totalCapturas;
    if (_posicionActual >= _posiciones.length) {
      _posicionActual = _posiciones.length - 1;
    }
    _iniciarCamara();
    _iniciarTTS();
  }

  Future<void> _iniciarTTS() async {
    await _flutterTts.setLanguage('es-MX');
    await _flutterTts.setSpeechRate(0.38);
    await _flutterTts.setPitch(1.0);
    // Clave: hace que speak() no retorne hasta que termine de hablar,
    // así podemos usar await para sincronizar voz -> pausa -> captura.
    await _flutterTts.awaitSpeakCompletion(true);
    _ttsListo = true;
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _iniciarCamara() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorCamara = 'No se encontró cámara');
        return;
      }
      final frontal = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(frontal, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      setState(() => _camaraInicializada = true);
    } catch (e) {
      setState(() => _errorCamara = 'Error al iniciar cámara');
    }
  }

  /// Habla la instrucción de una posición y espera a que termine
  /// (gracias a awaitSpeakCompletion). Si el TTS no está listo o
  /// falla, no bloquea el flujo de captura.
  Future<void> _hablarInstruccion(String posicion) async {
    if (!_ttsListo) return;
    final data = _posiciones.firstWhere((p) => p['nombre'] == posicion);
    try {
      await _flutterTts.speak('${data['nombre']}. ${data['descripcion']}');
    } catch (_) {
      // Si el TTS falla (dispositivo sin motor de voz, etc.) seguimos
      // igual con la captura visual.
    }
  }

  Future<void> _iniciarCapturaAutomatica() async {
    setState(() => _modoAutomatico = true);

    await _flutterTts.speak('Iniciando captura automática. Sigue las instrucciones.');

    // Anunciamos la posición actual ANTES de empezar a tomar fotos,
    // para que el usuario ya esté posicionado cuando arranque el loop.
    await _hablarInstruccion(_posiciones[_posicionActual]['nombre']!);
    _posicionAnunciada = _posicionActual;
    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = _capturasRealizadas; i < _totalCapturas; i++) {
      if (!mounted || !_modoAutomatico) break;
      await _capturarYEnviar();
      if (!mounted || !_modoAutomatico) break;
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (mounted && _capturasRealizadas >= _totalCapturas) {
      setState(() => _modoAutomatico = false);
      await _flutterTts.speak('Registro completo. Felicitaciones.');
      _mostrarCompletado();
    }
  }

  void _detenerCaptura() {
    setState(() => _modoAutomatico = false);
    _flutterTts.stop();
  }

  Future<void> _capturarYEnviar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _capturando = true);

    try {
      final photo = await _cameraController!.takePicture();
      final posicion = _posiciones[_posicionActual]['nombre']!;

      final response = await _reconocimientoService.registrarEmbedding(
        posicion: posicion,
        image: File(photo.path),
      );

      if (!mounted) return;

      final nuevaPosicion = _calcularPosicion(response['total_embeddings'] ?? _capturasRealizadas + 1);

      setState(() {
        _capturasRealizadas = response['total_embeddings'] ?? _capturasRealizadas + 1;
        _capturando = false;
        _posicionActual = nuevaPosicion;
      });

      // Si la posición cambió, avisamos por voz y damos una pausa
      // para que el usuario se acomode ANTES de que sigan las fotos.
      if (_posicionActual != _posicionAnunciada && _modoAutomatico) {
        _posicionAnunciada = _posicionActual;
        await _hablarInstruccion(_posiciones[_posicionActual]['nombre']!);
        await Future.delayed(const Duration(milliseconds: 400));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturando = false);
      _mostrarError('Error: ${e.toString().replaceAll('Exception: ', '')}');
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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ¡Registro Completo! Ya puedes marcar asistencia.'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorCamara != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registro Facial')),
        body: Center(child: Text(_errorCamara!, style: const TextStyle(color: Colors.red))),
      );
    }

    if (!_camaraInicializada || _cameraController == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registro Facial')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pos = _posiciones[_posicionActual];
    final prog = _capturasRealizadas / _totalCapturas;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_cameraController!),
            Center(
              child: Container(
                width: 260, height: 330,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(130),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(16), color: Colors.black54,
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Registro Facial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('${(prog * 100).toInt()}%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: prog, minHeight: 6, borderRadius: BorderRadius.circular(3), backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)),
                    const SizedBox(height: 4),
                    Text('$_capturasRealizadas de $_totalCapturas', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 130, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Text(pos['icono']!, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('🔊 ${pos['nombre']!.toUpperCase()}', style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(pos['descripcion']!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ])),
                ]),
              ),
            ),
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: _modoAutomatico
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Capturando...', style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _detenerCaptura,
                          icon: const Icon(Icons.stop, color: Colors.red),
                          label: const Text('DETENER', style: TextStyle(color: Colors.red)),
                        ),
                      ]),
                    )
                  : Center(
                      child: ElevatedButton.icon(
                        onPressed: _iniciarCapturaAutomatica,
                        icon: const Icon(Icons.play_arrow, size: 28),
                        label: const Text('INICIAR CAPTURA AUTOMÁTICA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}