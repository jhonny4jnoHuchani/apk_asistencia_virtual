import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../models/horario.dart';
import '../services/biometric_service.dart';
import '../utils/gestos.dart';
import '../widgets/home/camera_marcado_screen.dart';
import '../widgets/home/horario_card_extended.dart';
import 'home_screen.dart';

// ============================================
// GUIA DE USO - MODO PRACTICO
// ============================================
// Reemplaza a guia_demo_screen.dart (que se conserva como referencia).
// La guia recorre el marcado real paso a paso usando las mismas pantallas
// de la app (tarjeta de horario y camara de marcado) con una clase de
// ejemplo, sin enviar nada al servidor.
//
// [25/10] Igual que el marcado real: al tocar Marcar Entrada o Marcar
// Salida se verifican huella, permisos y GPS y la camara se abre sola con
// las 3 fotos seguidas. Textos acortados a pedido del supervisor (textos
// anteriores en el commit 007ee99).

// Etapas del recorrido, en el orden en que se muestran.
// verificaciones se usa dos veces: para la entrada y para la salida.
enum EtapaGuia {
  intro,
  tarjeta,
  verificaciones,
  // [DESACTIVADO 25/10] Las fotos ya no son pantallas aparte: la camara
  // pasa sola de una foto a otra, como en el Home (ver _etapaCamara).
  // fotoFrontal,
  // fotoGesto,
  // fotoConstancia,
  salida,
  consejos,
  fin,
}

// Estado de cada verificacion previa a la camara (huella, permisos, GPS)
enum EstadoVerificacion { pendiente, enCurso, ok, fallo }

class GuiaPracticaScreen extends StatefulWidget {
  const GuiaPracticaScreen({super.key});

  @override
  State<GuiaPracticaScreen> createState() => _GuiaPracticaScreenState();
}

class _GuiaPracticaScreenState extends State<GuiaPracticaScreen>
    with WidgetsBindingObserver {
  EtapaGuia _etapa = EtapaGuia.intro;

  // Clase de ejemplo que se muestra en la tarjeta real
  Horario? _horarioDemo;
  bool _demoConUbicacion = false;
  bool _buscandoUbicacion = false;
  String _horaInicioDemo = '';
  String _horaFinDemo = '';

  // Verificaciones reales antes de la camara (mismo orden que el Home)
  final BiometricService _biometricService = BiometricService();
  bool _verificando = false;
  EstadoVerificacion _estadoHuella = EstadoVerificacion.pendiente;
  EstadoVerificacion _estadoPermisos = EstadoVerificacion.pendiente;
  EstadoVerificacion _estadoGps = EstadoVerificacion.pendiente;
  String _detalleHuella = 'Huella o bloqueo del teléfono.';
  String _detallePermisos = 'Cámara y ubicación.';
  String _detalleGps = 'Debe estar encendido.';

  // Camara real de practica (no se toman ni se envian fotos)
  // Si hay controlador, la camara esta abierta en pantalla
  CameraController? _cameraController;
  bool _abriendoCamara = false;
  String _gestoDemo = generarGestoAleatorio();
  // [DESACTIVADO 25/10] final Set<EtapaGuia> _fotosPracticadas = {};
  // Foto en curso, mismos valores que el Home: 'frontal', 'gesto', 'constancia'
  String _etapaCamara = 'frontal';

  // true mientras se repite huella, GPS y fotos para la salida
  bool _modoSalida = false;

  // Voz: lee cada paso al aparecer. Se puede silenciar y se recuerda.
  final FlutterTts _flutterTts = FlutterTts();
  bool _vozActiva = true;
  static const String _vozActivaKey = 'guia_voz_activa';
  // Texto que se lee para cada recuadro del tutorial (por id)
  final Map<String, String> _vozTargets = {};
  // Turno de la voz: cambia cada vez que se habla o se corta la voz, asi
  // una lectura interrumpida no hace avanzar el tutorial
  int _vozId = 0;

  // Tutorial en pantalla (para avanzarlo solo al terminar la voz)
  TutorialCoachMark? _tutorial;
  String? _targetActual;

  // Dedo de la tarjeta despues de su tutorial:
  // 0 = otro / oculto, 1 = "Aula de ejemplo", 2 = "Marcar Entrada"
  int _pasoMano = 0;
  Offset? _posMano;
  Timer? _timerMano;
  final GlobalKey _keyStackTarjeta = GlobalKey();

  // Dedo reutilizable: que boton senala, dentro de que zona (Stack) se
  // dibuja, que texto muestra y en que parte del ancho del boton apunta
  GlobalKey? _manoObjetivo;
  GlobalKey? _manoStack;
  String _manoTexto = '';
  double _manoFx = 0.5;
  // [DESACTIVADO 25/10] Sin pantallas de foto ya no hay boton "Abrir camara"
  // final GlobalKey _keyStackFoto = GlobalKey();
  // final GlobalKey _keyBotonCamara = GlobalKey();
  final GlobalKey _keyStackSalida = GlobalKey();

  // Claves para resaltar las partes de la tarjeta en el tutorial
  final GlobalKey _keyEncabezado = GlobalKey();
  final GlobalKey _keyUbicacion = GlobalKey();
  final GlobalKey _keyEstado = GlobalKey();
  final GlobalKey _keyBotones = GlobalKey();
  final GlobalKey _keySalida = GlobalKey();

  // Clase de ejemplo para practicar la salida (entrada ya marcada)
  Horario? _horarioSalidaDemo;

  static const Color _primaryColor = Color(0xFF4A6CF7);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _darkColor = Color(0xFF1A2B4A);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _dangerColor = Color(0xFFEF4444);

  // [ANTERIOR] int get _numeroPaso => _etapa.index + 1;
  // [ANTERIOR] int get _totalPasos => EtapaGuia.values.length;
  // [DESACTIVADO 25/10] Contaba la verificacion de la salida como un paso
  // mas; la salida ya no repite la verificacion.
  // int get _numeroPaso {
  //   if (_modoSalida && _etapa == EtapaGuia.verificaciones) {
  //     return EtapaGuia.salida.index + 2;
  //   }
  //   if (_etapa.index > EtapaGuia.salida.index) return _etapa.index + 2;
  //   return _etapa.index + 1;
  // }
  // int get _totalPasos => EtapaGuia.values.length + 1;
  int get _numeroPaso => _etapa.index + 1;
  int get _totalPasos => EtapaGuia.values.length;
  bool get _esPrimera => _etapa == EtapaGuia.values.first;
  bool get _esUltima => _etapa == EtapaGuia.values.last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepararClaseDemo();
    _iniciarVoz();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _timerMano?.cancel();
    _detenerVoz();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  Voz
  // ─────────────────────────────────────────────────────────────
  // Misma configuracion que la guia anterior
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
        return 'Verificando huella, permisos y GPS. Luego se abre la cámara.';
      // [DESACTIVADO 25/10] Las fotos se explican en la propia camara
      // case EtapaGuia.fotoFrontal: ...
      // case EtapaGuia.fotoGesto: ...
      // case EtapaGuia.fotoConstancia: ...
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

  // Igual que el Home: si la app pasa a segundo plano se libera la camara
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _cerrarCamara();
  }

  // ─────────────────────────────────────────────────────────────
  //  Camara real (3 fotos de practica)
  // ─────────────────────────────────────────────────────────────
  // Mismas etapas que el marcado real: 'frontal' y 'gesto' con la camara
  // delantera, 'constancia' con la trasera.
  // [ANTERIOR] String get _etapaCamara { switch (_etapa) { ... } }
  // Ahora _etapaCamara es un campo que avanza al capturar (_fotoPracticada)

  Future<void> _abrirCamara() async {
    // [ANTERIOR] if (_abriendoCamara) return;
    // Tambien si ya esta abierta (la camara ahora se abre sola)
    if (_abriendoCamara || _cameraController != null) return;
    setState(() => _abriendoCamara = true);

    // Al empezar la secuencia se elige un gesto nuevo, como en el Home
    // [ANTERIOR] if (_etapa == EtapaGuia.fotoFrontal) _gestoDemo = generarGestoAleatorio();
    if (_etapaCamara == 'frontal') _gestoDemo = generarGestoAleatorio();

    try {
      final permiso = await Permission.camera.request();
      if (!permiso.isGranted) {
        throw Exception('Se necesita permiso de cámara');
      }

      final camaras = await availableCameras();
      if (camaras.isEmpty) throw Exception('No se encontró cámara');

      final lente = _etapaCamara == 'constancia'
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      final seleccionada = camaras.firstWhere(
        (c) => c.lensDirection == lente,
        orElse: () => camaras.first,
      );

      final controller = CameraController(
        seleccionada,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
      _hablar(_textoVozCamara());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'No se pudo abrir la cámara: '
          '${e.toString().replaceAll('Exception: ', '')}',
        ),
        backgroundColor: _dangerColor,
      ));
    } finally {
      if (mounted) setState(() => _abriendoCamara = false);
    }
  }

  // Se libera la camara despues de quitarla de la pantalla
  void _cerrarCamara() {
    final controller = _cameraController;
    if (controller == null) return;
    setState(() => _cameraController = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  // Boton de captura: en la practica no se toma ni se guarda la foto.
  // Igual que _capturarYMarcar del Home: frontal -> gesto -> constancia,
  // abriendo la camara siguiente sola.
  // [ANTERIOR] Cerraba la camara y pasaba a otra pantalla con "Abrir camara"
  void _fotoPracticada() {
    if (_etapaCamara == 'frontal') {
      _siguienteFoto('gesto', 'Ahora: ${instruccionGesto(_gestoDemo)}');
      return;
    }
    if (_etapaCamara == 'gesto') {
      _siguienteFoto('constancia', 'Ahora la foto del aula');
      return;
    }

    // Tercera foto: termina el marcado de practica
    _cerrarCamara();
    _etapaCamara = 'frontal';
    // [ANTERIOR] SnackBar "¡Entrada/Salida practicada!" y pasaba de etapa
    _mostrarMarcadoExitoso();
  }

  // Aviso de exito, con el mismo texto que el Home al marcar
  // ('Entrada marcada correctamente'). Al continuar sigue la guia:
  // entrada -> tarjeta de salida, salida -> avisos comunes.
  Future<void> _mostrarMarcadoExitoso() async {
    final esSalida = _modoSalida;
    final titulo =
        esSalida ? 'Si se cumple todo lo solicitado, aparece un mensaje de que la salida fue marcada con éxito.' : '¡Si se cumple todo lo solicitado, aparece un mensaje de que la entrada fue marcada con éxito.';
    // En la salida no se repite el proceso en la guia: solo se explica
    const procesoSalida =
        'Para la salida se sigue el mismo proceso de la entrada: huella, '
        'GPS y las 3 fotos.';
    // [ANTERIOR] _hablar(titulo);
    // [ANTERIOR] _hablar(esSalida ? '$procesoSalida $titulo' : titulo);
    // [ANTERIOR] Un solo dialogo con la explicacion encima del exito.
    // [25/10] Salida: primero una tarjeta flotante con el proceso y
    // despues la de exito, las dos con el mismo estilo.
    if (esSalida) {
      // [ANTERIOR] _hablar(procesoSalida); y la tarjeta tenia "Continuar".
      // [25/10] Sin boton: se cierra sola al terminar la frase y aparece
      // la de exito.
      BuildContext? ctxProceso;
      var procesoAbierta = true;
      final procesoCerrada = _mostrarTarjetaFlotante(
        conBoton: false,
        alConstruir: (ctx) => ctxProceso = ctx,
        cabecera: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint_rounded, size: 40, color: _primaryColor),
            SizedBox(width: 12),
            Icon(Icons.location_on_rounded, size: 40, color: _primaryColor),
            SizedBox(width: 12),
            Icon(Icons.photo_camera_rounded, size: 40, color: _primaryColor),
          ],
        ),
        titulo: 'Mismo proceso',
        texto: procesoSalida,
        color: _primaryColor,
      ).whenComplete(() => procesoAbierta = false);

      // Esperar a que termine la frase. Con la voz silenciada (o si falla)
      // se deja la tarjeta unos segundos para leerla.
      final inicio = DateTime.now();
      final leida = await _hablar(procesoSalida);
      if (!leida) {
        final restante =
            const Duration(seconds: 4) - DateTime.now().difference(inicio);
        if (!restante.isNegative) await Future.delayed(restante);
      }
      if (!mounted) return;
      final ctxTarjeta = ctxProceso;
      if (procesoAbierta && ctxTarjeta != null && ctxTarjeta.mounted) {
        Navigator.pop(ctxTarjeta);
      }
      await procesoCerrada;
      if (!mounted) return;
    }

    _hablar(titulo);
    await _mostrarTarjetaFlotante(
      cabecera: const Icon(Icons.check_circle_rounded,
          size: 64, color: _successColor),
      titulo: titulo,
      texto: 'Práctica: no se envió nada.',
      color: _successColor,
      textoSecundario: true,
    );

    if (!mounted) return;
    _irAEtapa(esSalida ? EtapaGuia.consejos : EtapaGuia.salida);
  }

  // Tarjeta flotante (dialogo) con icono, titulo, texto y "Continuar".
  // Sin boton (conBoton: false) no se cierra con "atras": la cierra quien
  // la abrio, usando el contexto que recibe alConstruir.
  Future<void> _mostrarTarjetaFlotante({
    required Widget cabecera,
    required String titulo,
    required String texto,
    required Color color,
    bool textoSecundario = false,
    bool conBoton = true,
    void Function(BuildContext ctx)? alConstruir,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        alConstruir?.call(ctx);
        return PopScope(
          canPop: conBoton,
          child: _buildTarjetaFlotante(
            ctx,
            cabecera: cabecera,
            titulo: titulo,
            texto: texto,
            color: color,
            textoSecundario: textoSecundario,
            conBoton: conBoton,
          ),
        );
      },
    );
  }

  Widget _buildTarjetaFlotante(
    BuildContext ctx, {
    required Widget cabecera,
    required String titulo,
    required String texto,
    required Color color,
    required bool textoSecundario,
    required bool conBoton,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cabecera,
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: textoSecundario
                ? TextStyle(fontSize: 12.5, color: Colors.grey.shade600)
                : const TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
          ),
        ],
      ),
      actions: [
        if (conBoton)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continuar'),
            ),
          ),
      ],
    );
  }

  // Como _switchToNextStage del Home: cierra la camara, avisa y abre la
  // siguiente
  Future<void> _siguienteFoto(String etapaCamara, String mensaje) async {
    _cerrarCamara();
    _etapaCamara = etapaCamara;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      duration: const Duration(seconds: 2),
    ));
    await _abrirCamara();
  }

  // Boton X de la camara: se cancela el marcado y se vuelve a la tarjeta
  void _cancelarCamara() {
    _cerrarCamara();
    _etapaCamara = 'frontal';
    _irAEtapa(_modoSalida ? EtapaGuia.salida : EtapaGuia.tarjeta);
  }

  // Al terminar la verificacion se abre la camara sola, como en el Home
  Future<void> _abrirCamaraTrasVerificar() async {
    // Breve pausa para que se vean las verificaciones en verde
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _etapa != EtapaGuia.verificaciones) return;
    _etapaCamara = 'frontal';
    await _abrirCamara();
  }

  void _siguiente() {
    if (_esUltima) return;
    // [ANTERIOR] _irAEtapa(EtapaGuia.values[_etapa.index + 1]);
    switch (_etapa) {
      // Sin marcar: se salta la practica de entrada o de salida
      case EtapaGuia.tarjeta:
        _irAEtapa(EtapaGuia.salida);
      case EtapaGuia.salida:
        _irAEtapa(EtapaGuia.consejos);
      // Si la camara se cerro (ej. la app paso a segundo plano), reabrirla
      case EtapaGuia.verificaciones:
        _etapaCamara = 'frontal';
        _abrirCamara();
      default:
        _irAEtapa(EtapaGuia.values[_etapa.index + 1]);
    }
  }

  void _anterior() {
    if (_esPrimera) return;
    // [ANTERIOR] _irAEtapa(EtapaGuia.values[_etapa.index - 1]);
    switch (_etapa) {
      case EtapaGuia.verificaciones:
        _irAEtapa(_modoSalida ? EtapaGuia.salida : EtapaGuia.tarjeta);
      case EtapaGuia.salida:
        _irAEtapa(EtapaGuia.tarjeta);
      default:
        _irAEtapa(EtapaGuia.values[_etapa.index - 1]);
    }
  }

  void _irAEtapa(EtapaGuia etapa) {
    _ocultarMano();
    setState(() {
      _etapa = etapa;
      // Volver a la tarjeta o a la salida reinicia esa practica
      if (etapa == EtapaGuia.tarjeta) _modoSalida = false;
      if (etapa == EtapaGuia.salida) _modoSalida = false;
    });
    // La voz habla al aparecer cada paso (corta la del paso anterior)
    _hablar(_textoVozEtapa(etapa));
    if (etapa == EtapaGuia.tarjeta) _mostrarTutorialTarjeta();
    // [DESACTIVADO 25/10] Dedo sobre "Abrir camara" en cada foto: ya no hay
    // pantallas de foto, la camara se abre sola
    if (etapa == EtapaGuia.salida) {
      _prepararSalidaDemo();
      _mostrarTutorialSalida();
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Clase de ejemplo
  // ─────────────────────────────────────────────────────────────
  // Empieza 10 min despues de abrir la guia y dura 2 horas, asi el boton
  // "Marcar Entrada" queda habilitado (se permite desde 30 min antes).
  // La zona del aula se centra en la ubicacion actual del docente para
  // que la tarjeta lo muestre "dentro de zona". Si no hay GPS, la tarjeta
  // se muestra sin mapa.
  Future<void> _prepararClaseDemo() async {
    final ahora = DateTime.now();
    DateTime inicio = ahora.add(const Duration(minutes: 10));
    DateTime fin = inicio.add(const Duration(hours: 2));

    // La tarjeta calcula las horas sobre el dia de hoy: evitar pasar
    // de la medianoche
    if (fin.day != ahora.day) {
      inicio = ahora.subtract(const Duration(minutes: 5));
      fin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59);
    }

    final formato = DateFormat('HH:mm');
    _horaInicioDemo = formato.format(inicio);
    _horaFinDemo = formato.format(fin);

    await _cargarUbicacionDemo();

    // Si el docente ya esta en la etapa de la tarjeta, mostrar el tutorial
    if (_etapa == EtapaGuia.tarjeta) _mostrarTutorialTarjeta();
  }

  // ─────────────────────────────────────────────────────────────
  //  Huella y GPS (reales)
  // ─────────────────────────────────────────────────────────────
  // Mismo orden que _iniciarMarcado en home_screen.dart:
  // huella -> permisos de camara y ubicacion -> GPS encendido -> ubicacion.
  // A diferencia del Home, si algo falla no se bloquea: se explica que
  // pasaria en la app real y se permite continuar con la practica.
  Future<void> _iniciarVerificaciones() async {
    if (_verificando) return;
    setState(() {
      _verificando = true;
      _estadoHuella = EstadoVerificacion.enCurso;
      _estadoPermisos = EstadoVerificacion.pendiente;
      _estadoGps = EstadoVerificacion.pendiente;
      _detalleHuella = 'Pon tu dedo en el lector.';
      _detallePermisos = 'Cámara y ubicación.';
      _detalleGps = 'Debe estar encendido.';
    });

    // 1. Huella
    final huellaOk = await _biometricService.authenticate();
    if (!mounted) return;
    setState(() {
      _estadoHuella =
          huellaOk ? EstadoVerificacion.ok : EstadoVerificacion.fallo;
      _detalleHuella = huellaOk
          ? 'Identidad confirmada.'
          : 'No se verificó. La app te dejará continuar sin huella.';
      _estadoPermisos = EstadoVerificacion.enCurso;
    });

    // 2. Permisos de camara y ubicacion
    final camara = await Permission.camera.request();
    final ubicacion = await Permission.location.request();
    if (!mounted) return;
    final faltantes = [
      if (!camara.isGranted) 'cámara',
      if (!ubicacion.isGranted) 'ubicación',
    ];
    setState(() {
      _estadoPermisos =
          faltantes.isEmpty ? EstadoVerificacion.ok : EstadoVerificacion.fallo;
      _detallePermisos = faltantes.isEmpty
          ? 'Permisos concedidos.'
          : 'Falta permiso de ${faltantes.join(' y ')}. Actívalo en '
              'Ajustes > Aplicaciones.';
      _estadoGps = EstadoVerificacion.enCurso;
    });

    // 3. GPS encendido y ubicacion
    await _verificarGps();
    if (!mounted) return;
    setState(() => _verificando = false);

    // 4. Como en el Home: con permisos y GPS listos se abre la camara.
    // Si algo fallo, el docente lo ve y puede reintentar.
    if (_estadoPermisos == EstadoVerificacion.ok &&
        _estadoGps == EstadoVerificacion.ok) {
      _abrirCamaraTrasVerificar();
    }
  }

  Future<void> _verificarGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() {
        _estadoGps = EstadoVerificacion.fallo;
        _detalleGps = 'GPS apagado. Actívalo: sin GPS no se puede marcar.';
      });
      return;
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _estadoGps = EstadoVerificacion.ok;
        _detalleGps = 'Ubicación obtenida (±'
            '${posicion.accuracy.toStringAsFixed(0)} m).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estadoGps = EstadoVerificacion.fallo;
        _detalleGps = 'Sin ubicación. Acércate a una ventana y reintenta.';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Salida
  // ─────────────────────────────────────────────────────────────
  // La misma clase de ejemplo con la entrada ya marcada. Termina 10 min
  // despues de llegar a esta etapa, asi el boton rojo queda habilitado
  // (se permite desde 30 min antes hasta 30 min despues del fin).
  void _prepararSalidaDemo() {
    final ahora = DateTime.now();
    final inicioDia = DateTime(ahora.year, ahora.month, ahora.day);
    final finDia = DateTime(ahora.year, ahora.month, ahora.day, 23, 59);

    // La tarjeta calcula las horas sobre el dia de hoy
    var inicio = ahora.subtract(const Duration(hours: 2));
    if (inicio.isBefore(inicioDia)) inicio = inicioDia;
    var fin = ahora.add(const Duration(minutes: 10));
    if (fin.isAfter(finDia)) fin = finDia;

    final formato = DateFormat('HH:mm');
    setState(() {
      // Misma zona que la tarjeta de entrada (si ya se consiguio)
      _horarioSalidaDemo = _crearHorarioDemo(
        horaInicio: formato.format(inicio),
        horaFin: formato.format(fin),
        yaMarcoEntrada: true,
        poligono: _horarioDemo?.poligono,
      );
    });
  }

  // Clase de ejemplo con los datos que se muestran en la tarjeta real
  Horario _crearHorarioDemo({
    required String horaInicio,
    required String horaFin,
    bool yaMarcoEntrada = false,
    List<Map<String, double>>? poligono,
  }) {
    return Horario(
      id: 0,
      diaSemana: '',
      horaInicio: horaInicio,
      horaFin: horaFin,
      materia: 'Clase de ejemplo',
      paralelo: 'A',
      ubicacion: 'Aula de ejemplo',
      paraleloMateriaId: 0,
      ubicacionId: 0,
      yaMarcoEntrada: yaMarcoEntrada,
      yaMarcoSalida: false,
      ubicacionNombre: 'Aula de ejemplo',
      poligono: poligono,
    );
  }

  // El docente confirmo el dialogo real de salida: igual que el Home
  // (_iniciarMarcado('salida')), se repiten huella, GPS y las 3 fotos
  // [ANTERIOR] Mostraba un aviso "en la app real se repiten..." y pasaba
  // a los consejos sin practicarlo
  // [DESACTIVADO 25/10] Repetir huella, GPS y fotos alargaba la guia:
  // ahora solo se explica que el proceso es el mismo que en la entrada.
  // void _salidaPracticada() {
  //   _irAEtapa(EtapaGuia.verificaciones);
  //   setState(() => _modoSalida = true);
  //   _iniciarVerificaciones();
  // }
  void _salidaPracticada() {
    setState(() => _modoSalida = true);
    _mostrarMarcadoExitoso();
  }

  // Boton "Reintentar ubicacion"
  Future<void> _reintentarUbicacion() async {
    if (_buscandoUbicacion) return;
    setState(() => _buscandoUbicacion = true);
    await _cargarUbicacionDemo();
  }

  // Obtiene la ubicacion y arma la clase de ejemplo con su zona
  Future<void> _cargarUbicacionDemo() async {
    final posicion = await _obtenerPosicion();

    List<Map<String, double>>? poligono;
    if (posicion != null) {
      // Cuadrado de ~90 m de lado alrededor del docente
      const d = 0.0004;
      final lat = posicion.latitude;
      final lng = posicion.longitude;
      poligono = [
        {'lat': lat + d, 'lng': lng - d},
        {'lat': lat + d, 'lng': lng + d},
        {'lat': lat - d, 'lng': lng + d},
        {'lat': lat - d, 'lng': lng - d},
      ];
    }

    if (!mounted) return;
    setState(() {
      _buscandoUbicacion = false;
      _demoConUbicacion = posicion != null;
      _horarioDemo = _crearHorarioDemo(
        horaInicio: _horaInicioDemo,
        horaFin: _horaFinDemo,
        poligono: poligono,
      );
    });
  }

  Future<Position?> _obtenerPosicion() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return null;
      }
      try {
        // Mismo tiempo de espera que el marcado real
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (_) {
        // Sin respuesta a tiempo (ej. dentro de un edificio):
        // usar la ultima ubicacion conocida del telefono
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Tutorial sobre la tarjeta
  // ─────────────────────────────────────────────────────────────
  // Solo resalta partes que ya estan dibujadas en pantalla
  void _mostrarTutorialTarjeta() {
    if (_horarioDemo == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Esperar a que la tarjeta termine de dibujarse
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _etapa != EtapaGuia.tarjeta) return;

      final targets = <TargetFocus>[
        _crearTarget(
          'encabezado',
          _keyEncabezado,
          ContentAlign.bottom,
          'Tu clase',
          'Materia, paralelo y horario. El color azul significa marcado pendiente.',
        ),
        _crearTarget(
          'ubicacion',
          _keyUbicacion,
          ContentAlign.bottom,
          'Aula',
          _demoConUbicacion
              ? 'Tócala para ver en el mapa la zona donde debes marcar.'
              : 'Con el GPS activo, tócala para ver el mapa.',
        ),
        _crearTarget(
          'estado',
          _keyEstado,
          ContentAlign.bottom,
          'Temporizador',
          'Cuánto falta para empezar. La entrada se marca desde 30 min antes.',
        ),
        _crearTarget(
          'botones',
          _keyBotones,
          ContentAlign.top,
          'Boton: Marcar Entrada',
          'Tócalo al llegar al aula para registrar su entrada.,',
        ),
      ];
      _mostrarTargets(targets);
    });
  }

  // Tutorial sobre la tarjeta de salida (etapa 7)
  void _mostrarTutorialSalida() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _etapa != EtapaGuia.salida) return;

      _mostrarTargets([
        _crearTarget(
          'encabezado_salida',
          _keyEncabezado,
          ContentAlign.bottom,
          'Clase en curso',
          'Con la entrada marcada, la tarjeta se pone de color naranja, lo cual significa actividades en curso.',
        ),
        _crearTarget(
          'temporizador_salida',
          _keySalida,
          ContentAlign.bottom,
          'Temporizador de salida',
          'Cuánto falta para terminar la clase.',
        ),
        _crearTarget(
          'boton_salida',
          _keyBotones,
          ContentAlign.top,
          'Marcar Salida',
          'Se habilita 30 min antes del fin. ¡Pruébalo!',
        ),
      ]);
    });
  }

  // Muestra el tutorial solo con las partes que ya estan dibujadas
  void _mostrarTargets(List<TargetFocus> targets) {
    final visibles =
        targets.where((t) => t.keyTarget?.currentContext != null).toList();
    if (visibles.isEmpty) return;

    _tutorial = TutorialCoachMark(
      targets: visibles,
      colorShadow: Colors.black87,
      opacityShadow: 0.8,
      paddingFocus: 8,
      textSkip: 'SALTAR',
      // Lee cada recuadro al mostrarse y avanza solo al terminar.
      // No se espera aqui: el tutorial no muestra el recuadro hasta que
      // beforeFocus termina.
      beforeFocus: (target) {
        _targetActual = target.identify;
        _leerYAvanzar(target.identify);
      },
      onFinish: _alTerminarTutorial,
      onSkip: () {
        _alTerminarTutorial();
        return true;
      },
    )..show(context: context);
  }

  Future<void> _leerYAvanzar(String id) async {
    final termino = await _hablar(_vozTargets[id] ?? '');
    if (!termino) return; // silenciado o interrumpido: avanza al tocar
    await Future.delayed(const Duration(milliseconds: 600));
    // Seguir solo si nadie avanzo el tutorial mientras tanto
    if (mounted && _tutorial != null && _targetActual == id) {
      _tutorial!.next();
    }
  }

  void _alTerminarTutorial() {
    _tutorial = null;
    _targetActual = null;
    _detenerVoz();
    if (!mounted) return;
    // [ANTERIOR] if (_etapa == EtapaGuia.tarjeta) _mostrarMano(1);
    // [25/10] Sin el dedo sobre el mapa: va directo a "Marcar Entrada"
    if (_etapa == EtapaGuia.tarjeta) _mostrarMano(2);
    if (_etapa == EtapaGuia.salida) {
      _mostrarManoEn(
        objetivo: _keyBotones,
        stack: _keyStackSalida,
        texto: 'Toca Marcar Salida',
        voz: 'Ahora toca el botón rojo, Marcar Salida.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Dedo indicador
  // ─────────────────────────────────────────────────────────────
  // _mostrarManoEn() sirve para cualquier boton: la tarjeta, las camaras
  // y la salida. El dedo se dibuja dentro de la zona creada con _conMano().

  // Tarjeta: 1 = "Aula de ejemplo", 2 = "Marcar Entrada"
  void _mostrarMano(int paso) {
    _pasoMano = paso;
    _mostrarManoEn(
      objetivo: paso == 1 ? _keyUbicacion : _keyBotones,
      stack: _keyStackTarjeta,
      texto: paso == 1
          ? 'Toca aquí para ver el mapa'
          : 'Ahora toca Marcar Entrada',
      voz: paso == 1
          ? 'Toca Aula de ejemplo para ver el mapa de tu clase.'
          // [ANTERIOR] : 'Muy bien. Ahora toca el botón azul, Marcar Entrada.',
          : 'Ahora toca el botón azul, Marcar Entrada.',
      // "Aula de ejemplo" esta a la derecha de su fila
      fx: paso == 1 ? 0.62 : 0.5,
    );
  }

  void _mostrarManoEn({
    required GlobalKey objetivo,
    required GlobalKey stack,
    required String texto,
    String? voz,
    double fx = 0.5,
  }) {
    setState(() {
      _manoObjetivo = objetivo;
      _manoStack = stack;
      _manoTexto = texto;
      _manoFx = fx;
      _posMano = null;
    });
    if (voz != null) _hablar(voz);

    // El contenido cambia de tamano (mapa, temporizador): reubicar el dedo
    _timerMano?.cancel();
    _timerMano = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _actualizarPosicionMano(),
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _actualizarPosicionMano());
  }

  void _ocultarMano() {
    _timerMano?.cancel();
    _timerMano = null;
    _pasoMano = 0;
    _manoObjetivo = null;
    _manoStack = null;
    _posMano = null;
  }

  // Posicion de la punta del dedo, relativa a su zona (Stack)
  void _actualizarPosicionMano() {
    final objetivo = _manoObjetivo;
    final stack = _manoStack;
    if (!mounted || objetivo == null || stack == null) return;
    final rect = _rectRelativo(objetivo, stack);
    if (rect == null) return;

    final punta = Offset(rect.left + rect.width * _manoFx, rect.center.dy);
    if (punta != _posMano) setState(() => _posMano = punta);
  }

  Rect? _rectRelativo(GlobalKey key, GlobalKey stackKey) {
    final stack = stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || box == null || !box.attached || !stack.attached) {
      return null;
    }
    final origen = box.localToGlobal(Offset.zero, ancestor: stack);
    return origen & box.size;
  }

  // Envuelve un contenido en una zona donde se puede dibujar el dedo.
  // Deja espacio abajo para la etiqueta cuando el dedo esta visible.
  Widget _conMano(GlobalKey stackKey, Widget child) {
    final visible = _manoStack == stackKey && _posMano != null;
    return Padding(
      padding: EdgeInsets.only(bottom: visible ? 90 : 0),
      child: Stack(
        key: stackKey,
        clipBehavior: Clip.none,
        children: [
          child,
          if (visible)
            Positioned(
              // La punta del dedo (arriba al centro del widget) toca el objetivo
              left: _posMano!.dx - 60,
              top: _posMano!.dy - 8,
              child: IgnorePointer(child: _ManoIndicadora(texto: _manoTexto)),
            ),
        ],
      ),
    );
  }

  // Detecta el toque sobre "Aula de ejemplo" sin bloquear la tarjeta
  void _alSoltarToqueTarjeta(PointerUpEvent evento) {
    if (_pasoMano != 1) return;
    final box = _keyUbicacion.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.contains(evento.position)) return;

    // Esperar a que el mapa se abra antes de mover el dedo al boton
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _pasoMano == 1) _mostrarMano(2);
    });
  }

  TargetFocus _crearTarget(
    String id,
    GlobalKey key,
    ContentAlign alineacion,
    String titulo,
    String descripcion,
  ) {
    _vozTargets[id] = '$titulo. $descripcion';
    return TargetFocus(
      identify: id,
      keyTarget: key,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: alineacion,
          child: _buildTextoTutorial(titulo, descripcion),
        ),
      ],
    );
  }

  Widget _buildTextoTutorial(String titulo, String descripcion) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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

  // Marca la guia como vista y sale:
  // - Abierta desde el Home o Perfil (push): vuelve a esa pantalla.
  // - Primer ingreso (pushReplacement, sin pantalla anterior): va al Home.
  Future<void> _finalizar() async {
    _detenerVoz();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ya_vio_tutorial', true);
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Igual que el Home: la camara ocupa toda la pantalla
    if (_cameraController != null) {
      return CameraMarcadoScreen(
        cameraController: _cameraController!,
        etapaFoto: _etapaCamara,
        gestoSolicitado: _gestoDemo,
        instruccionGesto: instruccionGesto,
        onCapture: _fotoPracticada,
        // [ANTERIOR] onCancel: _cerrarCamara,
        onCancel: _cancelarCamara,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Guía de uso',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: _warningColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _alternarVoz,
            tooltip: _vozActiva ? 'Silenciar voz' : 'Activar voz',
            icon: Icon(
              _vozActiva ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: Colors.white,
            ),
          ),
          TextButton(
            onPressed: _finalizar,
            child: const Text(
              'Saltar',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // [DESACTIVADO 25/10] Banner "MODO PRÁCTICA" quitado por
            // innecesario (la bienvenida ya dice que nada se envia)
            // _buildBanner(),
            _buildProgreso(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [_buildContenidoEtapa()],
              ),
            ),
            _buildNavegacion(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Banner de modo practica
  // ─────────────────────────────────────────────────────────────
  /* [DESACTIVADO 25/10] Ya no se muestra (ver build)
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: _warningColor.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: _warningColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'MODO PRÁCTICA: los datos son de ejemplo y no se registra ninguna asistencia.',
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
  [FIN DESACTIVADO] */

  // ─────────────────────────────────────────────────────────────
  //  Indicador "Paso X de N"
  // ─────────────────────────────────────────────────────────────
  Widget _buildProgreso() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso $_numeroPaso de $_totalPasos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _numeroPaso / _totalPasos,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Contenido de cada etapa
  // ─────────────────────────────────────────────────────────────
  Widget _buildContenidoEtapa() {
    switch (_etapa) {
      case EtapaGuia.intro:
        return _buildTextoEtapa(
          Icons.waving_hand_rounded,
          'Guía de uso',
          'Conoce la aplicacion y practica el marcado de entrada y salida. ',
        );
      case EtapaGuia.tarjeta:
        return _buildEtapaTarjeta();
      case EtapaGuia.verificaciones:
        return _buildEtapaVerificaciones();
      // [DESACTIVADO 25/10] Pantallas de cada foto (fotoFrontal, fotoGesto,
      // fotoConstancia) con _buildEtapaFoto: la camara se abre sola
      case EtapaGuia.salida:
        return _buildEtapaSalida();
      case EtapaGuia.consejos:
        return _buildEtapaConsejos();
      case EtapaGuia.fin:
        return _buildEtapaFin();
    }
  }

  // Etapa 8: errores comunes. Los titulos son los mismos mensajes que
  // muestra el marcado real (home_screen.dart)
  Widget _buildEtapaConsejos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Avisos comunes. Toca uno para ver qué hacer.',
          style: TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
        ),
        const SizedBox(height: 12),
        _buildConsejo(
          Icons.visibility_off_rounded,
          _warningColor,
          'Gafas detectadas',
          'Los lentes impiden reconocer tu rostro.',
          'Quítatelos y toca "Reintentar".',
        ),
        _buildConsejo(
          Icons.warning_amber_rounded,
          _dangerColor,
          'Suplantación detectada',
          'La foto parece de una pantalla, impresa o de otra persona. Se '
              'informa al supervisor.',
          'Ponte tú frente a la cámara.',
        ),
        _buildConsejo(
          Icons.pan_tool_rounded,
          _warningColor,
          'Gesto incorrecto',
          'El gesto no coincide con el pedido.',
          'Lee la instrucción del marco y haz el gesto claro.',
        ),
        _buildConsejo(
          Icons.wrong_location_rounded,
          _dangerColor,
          'Fuera de la zona',
          'No estás dentro de la zona del aula.',
          'Marca desde el aula. Toca el aula en la tarjeta para ver el mapa.',
        ),
        _buildConsejo(
          Icons.location_off_rounded,
          _dangerColor,
          'El GPS está desactivado',
          'Sin GPS no se puede marcar.',
          'Activa la ubicación; la app te lleva a los ajustes.',
        ),
        const SizedBox(height: 4),
        Text(
          'En cualquier error, "Reintentar" repite el marcado.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildConsejo(
    IconData icono,
    Color color,
    String titulo,
    String causa,
    String solucion,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icono, color: color),
        title: Text(
          titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _darkColor,
          ),
        ),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLineaConsejo('Por qué aparece', causa),
          const SizedBox(height: 8),
          _buildLineaConsejo('Qué hacer', solucion),
        ],
      ),
    );
  }

  Widget _buildLineaConsejo(String etiqueta, String texto) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$etiqueta: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: texto),
        ],
      ),
      style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
    );
  }

  // Etapa 9: resumen final
  Widget _buildEtapaFin() {
    const pasos = [
      'En el aula, toca "Marcar Entrada".',
      'Huella y GPS encendido.',
      'Las 3 fotos: rostro, gesto y aula.',
      'Al terminar, "Marcar Salida": se repite lo mismo.',
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 56, color: _successColor),
            const SizedBox(height: 12),
            const Text(
              '¡Listo! Ya conoces el marcado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < pasos.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: _primaryColor,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pasos[i],
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Puedes volver a ver esta guía desde el botón de ayuda del '
              'Home o en Perfil > Opciones > Guía de uso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // Etapa 2: la misma tarjeta del Home con la clase de ejemplo
  Widget _buildEtapaTarjeta() {
    if (_horarioDemo == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparando clase de ejemplo...'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Así verás cada clase. Toca "Marcar Entrada".',
          style: TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
        ),
        const SizedBox(height: 12),
        // La tarjeta va dentro de un Stack para dibujar el dedo encima, y
        // de un Listener para saber si se toco "Aula de ejemplo"
        Listener(
          onPointerUp: _alSoltarToqueTarjeta,
          child: _conMano(
            _keyStackTarjeta,
            HorarioCardExtended(
              // Al conseguir la ubicacion se crea una tarjeta nueva para que
              // vuelva a calcular la zona y si el docente esta dentro
              key: ValueKey(_demoConUbicacion),
              horario: _horarioDemo!,
              // Igual que en el Home: al tocar el boton se piden huella y GPS
              onMarcarEntrada: () {
                _irAEtapa(EtapaGuia.verificaciones);
                _iniciarVerificaciones();
              },
              // Sin entrada marcada no hay boton de salida (etapa 7)
              onMarcarSalida: () {},
              keyEncabezado: _keyEncabezado,
              keyUbicacion: _keyUbicacion,
              keyEstado: _keyEstado,
              keyBotones: _keyBotones,
            ),
          ),
        ),
        if (!_demoConUbicacion) _buildAvisoSinUbicacion(),
      ],
    );
  }

  // Etapa 7: tarjeta con la entrada marcada y el dialogo real de salida
  Widget _buildEtapaSalida() {
    if (_horarioSalidaDemo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Al terminar la clase, toca "Marcar Salida".',
          style: TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
        ),
        const SizedBox(height: 12),
        _buildReglaSalida(),
        const SizedBox(height: 12),
        _conMano(
          _keyStackSalida,
          HorarioCardExtended(
            key: const ValueKey('salida'),
            horario: _horarioSalidaDemo!,
            onMarcarEntrada: () {},
            // Se llama solo si el docente confirma el dialogo real de salida
            onMarcarSalida: _salidaPracticada,
            keyEncabezado: _keyEncabezado,
            keyBotones: _keyBotones,
            keySalida: _keySalida,
          ),
        ),
      ],
    );
  }

  // Linea de tiempo de la regla de los 30 minutos
  Widget _buildReglaSalida() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: _primaryColor, size: 18),
              SizedBox(width: 6),
              Text(
                '¿Cuándo puedo marcar la salida?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTramo('Antes', Colors.grey.shade400, 'Deshabilitado'),
              _buildTramo('30 min antes → 30 min después del fin',
                  _successColor, 'Habilitado',
                  flex: 2),
              _buildTramo('Después', Colors.grey.shade400, 'Deshabilitado'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Si sales antes o después, el aviso te muestra los minutos.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildTramo(String texto, Color color, String estado, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              estado,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color == _successColor
                    ? _successColor
                    : Colors.grey.shade600,
              ),
            ),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /* [DESACTIVADO 25/10] Pantalla de cada foto con boton "Abrir camara".
     Ya no se usa: la camara se abre sola y pasa de una foto a otra.

  // Etapas 4, 5 y 6: explicacion de cada foto y boton para abrir la camara
  Widget _buildEtapaFoto(
    IconData icono,
    String titulo,
    String camara,
    List<String> consejos,
  ) {
    final practicada = _fotosPracticadas.contains(_etapa);

    // Zona con dedo: senala "Abrir camara" mientras la foto no se practique
    return _conMano(
        _keyStackFoto,
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icono, size: 36, color: _primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _darkColor,
                            ),
                          ),
                          Text(
                            camara,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (practicada)
                      const Icon(Icons.check_circle_rounded,
                          color: _successColor, size: 26),
                  ],
                ),
                const SizedBox(height: 14),
                for (final consejo in consejos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: _warningColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            consejo,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey.shade800,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Es solo práctica: la foto no se guarda ni se envía.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  key: _keyBotonCamara,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _abriendoCamara ? null : _abrirCamara,
                    icon: _abriendoCamara
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded),
                    label: Text(practicada ? 'Repetir foto' : 'Abrir cámara'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
  [FIN DESACTIVADO] */

  // Etapa 3: huella, permisos y GPS
  Widget _buildEtapaVerificaciones() {
    final sinIniciar = _estadoHuella == EstadoVerificacion.pendiente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _modoSalida
              ? 'Marcando salida. Se verifica igual que en la entrada:'
              : 'Marcando entrada. Antes de la cámara se verifica:',
          style: const TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
        ),
        const SizedBox(height: 12),
        _buildFilaVerificacion(
          Icons.fingerprint_rounded,
          '1. Huella',
          _estadoHuella,
          _detalleHuella,
        ),
        _buildFilaVerificacion(
          Icons.verified_user_rounded,
          '2. Permisos',
          _estadoPermisos,
          _detallePermisos,
        ),
        _buildFilaVerificacion(
          Icons.location_on_rounded,
          '3. GPS',
          _estadoGps,
          _detalleGps,
        ),
        const SizedBox(height: 4),
        if (!_verificando)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_estadoGps == EstadoVerificacion.fallo)
                OutlinedButton.icon(
                  onPressed: Geolocator.openLocationSettings,
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Activar GPS'),
                ),
              OutlinedButton.icon(
                onPressed: _iniciarVerificaciones,
                icon: Icon(
                  sinIniciar ? Icons.play_arrow_rounded : Icons.refresh_rounded,
                  size: 18,
                ),
                label: Text(
                  sinIniciar ? 'Iniciar verificación' : 'Repetir verificación',
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFilaVerificacion(
    IconData icono,
    String titulo,
    EstadoVerificacion estado,
    String detalle,
  ) {
    final Color color;
    final Widget indicador;
    switch (estado) {
      case EstadoVerificacion.pendiente:
        color = Colors.grey;
        indicador = const Icon(Icons.radio_button_unchecked_rounded,
            color: Colors.grey, size: 22);
      case EstadoVerificacion.enCurso:
        color = _primaryColor;
        indicador = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case EstadoVerificacion.ok:
        color = _successColor;
        indicador = const Icon(Icons.check_circle_rounded,
            color: _successColor, size: 22);
      case EstadoVerificacion.fallo:
        color = _dangerColor;
        indicador =
            const Icon(Icons.cancel_rounded, color: _dangerColor, size: 22);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _darkColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            indicador,
          ],
        ),
      ),
    );
  }

  Widget _buildAvisoSinUbicacion() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warningColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_off_rounded, color: _warningColor, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No se pudo obtener tu ubicación',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _darkColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Activa el GPS y el permiso de ubicación para ver el mapa con la '
            'zona de la clase. Sin GPS no podrás marcar en la app real.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _buscandoUbicacion ? null : _reintentarUbicacion,
              icon: _buscandoUbicacion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                _buscandoUbicacion ? 'Buscando...' : 'Reintentar ubicación',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextoEtapa(IconData icono, String titulo, String descripcion) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icono, size: 48, color: _primaryColor),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Botones Anterior / Siguiente
  // ─────────────────────────────────────────────────────────────
  Widget _buildNavegacion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (!_esPrimera)
            Expanded(
              child: OutlinedButton(
                onPressed: (_verificando || _abriendoCamara) ? null : _anterior,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Anterior'),
              ),
            ),
          if (!_esPrimera) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: (_verificando || _abriendoCamara)
                  ? null
                  : (_esUltima ? _finalizar : _siguiente),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                // Primer ingreso: va al Home. Desde Home o Perfil: vuelve.
                _esUltima
                    ? (Navigator.canPop(context)
                        ? 'Terminar'
                        : 'Ir a mi horario')
                    // En la verificacion el boton (re)abre la camara
                    : (_etapa == EtapaGuia.verificaciones
                        ? 'Abrir cámara'
                        : 'Siguiente'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dedo animado que indica donde tocar
// ─────────────────────────────────────────────────────────────
// La punta del dedo queda arriba al centro del widget (ancho 120)
class _ManoIndicadora extends StatefulWidget {
  final String texto;

  const _ManoIndicadora({required this.texto});

  @override
  State<_ManoIndicadora> createState() => _ManoIndicadoraState();
}

// Mano blanca con sombra que "presiona" y una onda de toque en la punta
// del dedo. Cada ciclo: la mano baja (toque), sale la onda y la mano sube.
class _ManoIndicadoraState extends State<_ManoIndicadora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _ancho = 120;
  // Punta del dedo dentro del widget (arriba al centro)
  static const double _puntaY = 8;
  static const double _tamanoMano = 46;
  static const Color _azul = Color(0xFF4A6CF7);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ancho,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _ancho,
            height: _tamanoMano + 10,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;

                // La mano baja durante el primer 20% del ciclo y vuelve
                final presion = t < 0.2
                    ? Curves.easeOut.transform(t / 0.2)
                    : t < 0.45
                        ? 1 - Curves.easeIn.transform((t - 0.2) / 0.25)
                        : 0.0;

                // La onda sale cuando la mano toca y se desvanece
                final onda = t < 0.15 ? 0.0 : ((t - 0.15) / 0.85);
                final tamanoOnda = 12 + 42 * Curves.easeOut.transform(onda);
                final opacidadOnda = (1 - onda) * 0.55;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Onda de toque centrada en la punta del dedo
                    Positioned(
                      left: _ancho / 2 - tamanoOnda / 2,
                      top: _puntaY - tamanoOnda / 2,
                      child: Container(
                        width: tamanoOnda,
                        height: tamanoOnda,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _azul.withValues(alpha: opacidadOnda * 0.5),
                          border: Border.all(
                            color: _azul.withValues(alpha: opacidadOnda),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Mano: el indice de pan_tool_alt esta un poco a la
                    // izquierda del centro del icono
                    Positioned(
                      left: _ancho / 2 - _tamanoMano * 0.42,
                      top: _puntaY - _tamanoMano * 0.06 + presion * 4,
                      child: Transform.scale(
                        scale: 1 - presion * 0.08,
                        child: const Icon(
                          Icons.pan_tool_alt_rounded,
                          size: _tamanoMano,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          // Etiqueta tipo "pildora"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _azul,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _azul.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
