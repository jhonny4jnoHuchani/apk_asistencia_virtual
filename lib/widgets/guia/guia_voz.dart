part of '../../screens/guia_practica_screen.dart';

// ============================================
// GUIA DE USO - VOZ
// ============================================
// Lee cada paso al aparecer. Se puede silenciar desde la barra superior y
// la eleccion se recuerda. Aqui estan todos los textos que se leen, salvo
// los de cada recuadro del tutorial (guia_tutorial.dart).

mixin _GuiaVoz on State<GuiaPracticaScreen> {
  // Datos de la pantalla que usa la voz
  EtapaGuia get _etapa;
  String get _etapaCamara;
  String get _gestoDemo;

  final FlutterTts _flutterTts = FlutterTts();
  bool _vozActiva = true;
  static const String _vozActivaKey = 'guia_voz_activa';
  // Turno de la voz: cambia cada vez que se habla o se corta la voz, asi
  // una lectura interrumpida no hace avanzar el tutorial
  int _vozId = 0;

  // Voz en espanol; al terminar de configurarla lee el paso actual
  Future<void> _iniciarVoz() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _vozActiva = prefs.getBool(_vozActivaKey) ?? true;
      await _flutterTts.setLanguage('es-MX');
      await _flutterTts.setSpeechRate(0.38);
      await _flutterTts.setPitch(1.0);
      // speak() espera a que termine de hablar (para el avance automatico)
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (_) {
      // Si el telefono no tiene voz en espanol, la guia sigue sin voz
    }
    if (!mounted) return;
    setState(() {});
    _hablar(_textoVozEtapa(_etapa));
  }

  // Corta lo que se este leyendo y lee el nuevo texto.
  // Devuelve true solo si termino de leerlo sin que lo interrumpieran.
  Future<bool> _hablar(String texto) async {
    if (!_vozActiva) return false;
    final turno = ++_vozId;
    try {
      await _flutterTts.stop();
      if (texto.isEmpty) return false;
      await _flutterTts.speak(texto);
    } catch (_) {
      return false;
    }
    return mounted && _vozActiva && turno == _vozId;
  }

  void _detenerVoz() {
    _vozId++;
    _flutterTts.stop();
  }

  Future<void> _alternarVoz() async {
    setState(() => _vozActiva = !_vozActiva);
    if (_vozActiva) {
      _hablar(_textoVozEtapa(_etapa));
    } else {
      _detenerVoz();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vozActivaKey, _vozActiva);
    } catch (_) {}
  }

  String _textoVozEtapa(EtapaGuia etapa) {
    switch (etapa) {
      case EtapaGuia.intro:
        return 'Bienvenido a la guia de uso, puedes practicar el marcado de entrada y salida paso a paso.';
      // En tarjeta y salida lee el tutorial, que aparece enseguida
      case EtapaGuia.tarjeta:
        return '';
      case EtapaGuia.verificaciones:
        // Lo de la camara se dice al terminar (_abrirCamaraTrasVerificar)
        return 'Verificando huella, permisos y GPS.';
      case EtapaGuia.salida:
        return '';
      case EtapaGuia.consejos:
        return 'Avisos comunes. Toca uno para ver qué hacer.';
      case EtapaGuia.fin:
        return '¡Listo! Ya sabes marcar entrada y salida.';
    }
  }

  // Lo que se lee al abrir la camara
  String _textoVozCamara() {
    switch (_etapaCamara) {
      case 'gesto':
        return 'Foto 2: ${instruccionGesto(_gestoDemo)}, y captura.';
      case 'constancia':
        return 'Foto 3: apunta al aula y captura.';
      default:
        return 'Foto 1: centra tu rostro, sin lentes, y captura.';
    }
  }
}
