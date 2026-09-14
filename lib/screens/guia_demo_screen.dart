import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class GuiaDemoScreen extends StatefulWidget {
  const GuiaDemoScreen({super.key});

  @override
  State<GuiaDemoScreen> createState() => _GuiaDemoScreenState();
}

class _GuiaDemoScreenState extends State<GuiaDemoScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  // Keys para los targets del tutorial
  final GlobalKey _keyCardHorario = GlobalKey();
  final GlobalKey _keyBtnEntrada = GlobalKey();
  final GlobalKey _keyCamara = GlobalKey();
  final GlobalKey _keyBtnCapturar = GlobalKey();
  final GlobalKey _keyMensajeExito = GlobalKey();
  final GlobalKey _keyBtnSalida = GlobalKey();
  final GlobalKey _keyBtnFinal = GlobalKey();

  bool _mostrarExito = false;
  bool _mostrarCamara = false;

  static const Color _primaryColor = Color(0xFF4A6CF7);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _dangerColor = Color(0xFFEF4444);
  static const Color _darkColor = Color(0xFF1A2B4A);

  @override
  void initState() {
    super.initState();
    _iniciarTTS();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iniciarTutorial();
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _iniciarTTS() async {
    await _flutterTts.setLanguage('es-MX');
    await _flutterTts.setSpeechRate(0.38);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _hablar(String texto) async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak(texto);
  }

  Future<void> _iniciarTutorial() async {
    // Esperar un poco para que la UI se dibuje
    await Future.delayed(const Duration(milliseconds: 500));

    final targets = [
      TargetFocus(
        identify: 'card_horario',
        keyTarget: _keyCardHorario,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTargetContent(
              'Ejemplo de horario',
              'Así verás tus clases del día. Cada tarjeta muestra la materia, el paralelo y el horario correspondiente.',
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'btn_entrada',
        keyTarget: _keyBtnEntrada,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTargetContent(
              'Botón verde: Marcar Entrada',
              'Cuando llegues a tu clase, presiona este botón para registrar tu ingreso.',
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'camara',
        keyTarget: _keyCamara,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTargetContent(
              'Cámara de verificación',
              'La cámara se abrirá automáticamente. Ubica tu rostro dentro del óvalo blanco.',
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'btn_capturar',
        keyTarget: _keyBtnCapturar,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTargetContent(
              'Botón de captura',
              'Presiona este botón blanco para tomar la fotografía.',
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'mensaje_exito',
        keyTarget: _keyMensajeExito,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTargetContent(
              'Importante: evitar fraude',
              'Esta foto verifica tu identidad. El sistema detecta intentos de suplantación y notifica al supervisor correspondiente.',
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'btn_salida',
        keyTarget: _keyBtnSalida,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _buildTargetContent(
              'Botón rojo: Marcar Salida',
              'Al finalizar tu clase, presiona este botón y repite los mismos pasos.',
            ),
          ),
        ],
      ),
    ];

    final tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black87,
      paddingFocus: 12,
      opacityShadow: 0.8,
      onFinish: () => _mostrarBotonFinal(),
      onClickTarget: (target) => _hablarTarget(target.identify),
      onClickOverlay: (target) => _hablarTarget(target.identify),
    );

    tutorial.show(context: context);
  }

  Future<void> _hablarTarget(String identify) async {
    switch (identify) {
      case 'card_horario':
        await _hablar(
            'Este es un ejemplo de tu horario. Así verás tus clases del día.');
        break;
      case 'btn_entrada':
        await _hablar(
            'Este es el botón verde. Cuando llegues a tu clase, tócalo para marcar tu entrada.');
        break;
      case 'camara':
        await _hablar(
            'Aquí se abrirá la cámara. Coloca tu rostro dentro del óvalo blanco.');
        break;
      case 'btn_capturar':
        await _hablar('Toca el botón blanco grande para tomarte la foto.');
        break;
      case 'mensaje_exito':
        await _hablar(
            'Importante. Esta foto verifica que seas tú. No intentes hacer fraude porque el sistema se dará cuenta y tu supervisor será notificado.');
        break;
      case 'btn_salida':
        await _hablar(
            'Este es el botón rojo. Al terminar tu clase, tócalo para marcar tu salida.');
        break;
    }
  }

  Widget _buildTargetContent(String titulo, String descripcion) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarBotonFinal() {
    setState(() {
      _mostrarCamara = false;
      _mostrarExito = true;
    });
  }

  Future<void> _irAHomeReal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ya_vio_tutorial', true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Modo Guía',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: _warningColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHorarioDemo(),
                  const SizedBox(height: 20),
                  if (_mostrarCamara) ...[
                    _buildCamaraDemo(),
                    const SizedBox(height: 20),
                  ],
                  if (_mostrarExito) ...[
                    _buildMensajeExito(),
                    const SizedBox(height: 20),
                  ],
                  if (_mostrarExito) _buildBotonFinal(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Banner superior
  // ─────────────────────────────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: _warningColor.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: _warningColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Esta es una demostración. No corresponde a tu horario real.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Tarjeta de horario demo
  // ─────────────────────────────────────────────────────────────
  Widget _buildHorarioDemo() {
    return Card(
      key: _keyCardHorario,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Matemáticas I',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _darkColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'DEMO',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),

            // Info de horario
            _buildInfoRow(
              icon: Icons.access_time_rounded,
              textos: ['08:00 - 10:00'],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.groups_rounded,
              textos: ['Paralelo A'],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.location_on_rounded,
              textos: ['Aula 101'],
            ),

            const SizedBox(height: 16),

            // Botones
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: _keyBtnEntrada,
                    onPressed: () {
                      setState(() {
                        _mostrarCamara = true;
                        _mostrarExito = false;
                      });
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Marcar Entrada'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    key: _keyBtnSalida,
                    onPressed: () {
                      setState(() {
                        _mostrarCamara = false;
                        _mostrarExito = true;
                      });
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Marcar Salida'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dangerColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required List<String> textos}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            textos.join('   ·   '),
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Cámara simulada
  // ─────────────────────────────────────────────────────────────
  Widget _buildCamaraDemo() {
    return Container(
      key: _keyCamara,
      height: 340,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warningColor, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Óvalo guía
          Container(
            width: 220,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(125),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),

          // Etiqueta superior
          Positioned(
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _warningColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'CÁMARA DE PRUEBA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Texto dentro del óvalo
          Positioned(
            top: 150,
            child: Text(
              'Coloca tu rostro\ndentro del óvalo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),

          // Botón capturar
          Positioned(
            bottom: 20,
            child: GestureDetector(
              key: _keyBtnCapturar,
              onTap: () {
                setState(() {
                  _mostrarCamara = false;
                  _mostrarExito = true;
                });
              },
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Mensaje de éxito
  // ─────────────────────────────────────────────────────────────
  Widget _buildMensajeExito() {
    return Container(
      key: _keyMensajeExito,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _successColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _successColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _successColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _successColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrada registrada correctamente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'En el uso real, aquí verás el comprobante.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Botón final
  // ─────────────────────────────────────────────────────────────
  Widget _buildBotonFinal() {
    return Container(
      key: _keyBtnFinal,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: _irAHomeReal,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Entendido, ir a mi horario real',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
