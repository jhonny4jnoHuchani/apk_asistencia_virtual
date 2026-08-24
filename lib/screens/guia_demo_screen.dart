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

  // Keys para las flechas
  final GlobalKey _keyCardHorario = GlobalKey();
  final GlobalKey _keyBtnEntrada = GlobalKey();
  final GlobalKey _keyCamara = GlobalKey();
  final GlobalKey _keyBtnCapturar = GlobalKey();
  final GlobalKey _keyMensajeExito = GlobalKey();
  final GlobalKey _keyBtnSalida = GlobalKey();
  final GlobalKey _keyBtnFinal = GlobalKey();

  bool _mostrarExito = false;
  bool _mostrarCamara = false;

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
              'Este es un EJEMPLO de tu horario',
              'Así verás tus clases del día. Cada clase tiene su materia, paralelo y horario.',
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
              'Botón VERDE: Marcar Entrada',
              'Cuando llegues a tu clase, toca este botón con tu dedo.',
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
              'Cámara para tu rostro',
              'La cámara se abrirá. Coloca tu cara dentro del óvalo blanco.',
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
              'Toca este botón blanco grande para tomarte la foto.',
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
              'Importante - No hagas fraude',
              'Esta foto verifica que seas tú. El sistema detectará si intentas hacer trampa y tu supervisor será notificado.',
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
              'Botón ROJO: Marcar Salida',
              'Al terminar tu clase, toca este botón y repite los mismos pasos.',
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
        await _hablar('Este es un ejemplo de tu horario. Así verás tus clases del día.');
        break;
      case 'btn_entrada':
        await _hablar('Este es el botón verde. Cuando llegues a tu clase, tócalo para marcar tu entrada.');
        break;
      case 'camara':
        await _hablar('Aquí se abrirá la cámara. Coloca tu rostro dentro del óvalo blanco.');
        break;
      case 'btn_capturar':
        await _hablar('Toca el botón blanco grande para tomarte la foto.');
        break;
      case 'mensaje_exito':
        await _hablar('Importante. Esta foto verifica que seas tú. No intentes hacer fraude porque el sistema se dará cuenta y tu supervisor será notificado.');
        break;
      case 'btn_salida':
        await _hablar('Este es el botón rojo. Al terminar tu clase, tócalo para marcar tu salida.');
        break;
    }
  }

  Widget _buildTargetContent(String titulo, String descripcion) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(descripcion, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('MODO GUÍA - EJEMPLO'),
        centerTitle: true,
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner de ejemplo
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8),
              child: const Text(
                '⚠️ ESTO ES UNA DEMOSTRACIÓN - NO ES TU HORARIO REAL',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Card de horario demo
                  _buildHorarioDemo(),
                  const SizedBox(height: 20),

                  // Cámara simulada
                  if (_mostrarCamara) ...[
                    _buildCamaraDemo(),
                    const SizedBox(height: 20),
                  ],

                  // Mensaje de éxito
                  if (_mostrarExito) ...[
                    _buildMensajeExito(),
                    const SizedBox(height: 20),
                  ],

                  // Botón final
                  if (_mostrarExito) _buildBotonFinal(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorarioDemo() {
    return Card(
      key: _keyCardHorario,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Matemáticas I (EJEMPLO)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('EJEMPLO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('08:00 - 10:00', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                const SizedBox(width: 16),
                const Icon(Icons.group, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Paralelo A', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Aula 101 (EJEMPLO)', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
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
                    icon: const Icon(Icons.login),
                    label: const Text('Marcar Entrada'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                    icon: const Icon(Icons.logout),
                    label: const Text('Marcar Salida'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildCamaraDemo() {
    return Container(
      key: _keyCamara,
      height: 350,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 250,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(125),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const Positioned(
            top: 10,
            child: Text(
              'CÁMARA DE PRUEBA',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
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
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  color: Colors.white,
                ),
                child: const Icon(Icons.camera, color: Colors.black, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMensajeExito() {
    return Container(
      key: _keyMensajeExito,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '✅ Entrada registrada correctamente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonFinal() {
    return Container(
      key: _keyBtnFinal,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton(
        onPressed: _irAHomeReal,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Entendido, ir a mi horario real',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}