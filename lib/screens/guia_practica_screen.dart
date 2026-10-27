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
// La guia recorre el marcado real paso a paso usando las mismas pantallas
// de la app (tarjeta de horario y camara de marcado) con una clase de
// ejemplo, sin enviar nada al servidor.
//
// Igual que el marcado real: al tocar Marcar Entrada se verifican huella,
// permisos y GPS y la camara se abre sola con las 3 fotos seguidas. En la
// salida solo se explica que el proceso es el mismo.

// Etapas del recorrido, en el orden en que se muestran
enum EtapaGuia {
  intro,
  tarjeta,
  verificaciones,
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
  // Foto en curso, mismos valores que el Home: 'frontal', 'gesto', 'constancia'
  String _etapaCamara = 'frontal';

  // true cuando ya se confirmo la salida de practica
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

  // Dedo indicador: posicion de la punta y zona de la tarjeta
  Offset? _posMano;
  Timer? _timerMano;
  final GlobalKey _keyStackTarjeta = GlobalKey();

  // Dedo reutilizable: que boton senala, dentro de que zona (Stack) se
  // dibuja y que texto muestra
  GlobalKey? _manoObjetivo;
  GlobalKey? _manoStack;
  String _manoTexto = '';
  final GlobalKey _keyStackSalida = GlobalKey();

  // Claves para resaltar las partes de la tarjeta en el tutorial
  final GlobalKey _keyEncabezado = GlobalKey();
  final GlobalKey _keyUbicacion = GlobalKey();
  final GlobalKey _keyEstado = GlobalKey();
  final GlobalKey _keyBotones = GlobalKey();
  final GlobalKey _keySalida = GlobalKey();

  // Dedo sobre "Confirmar" del dialogo de salida. El dialogo esta
  // encima de la pantalla, asi que el dedo se dibuja en el Overlay
  final GlobalKey _keyConfirmarSalida = GlobalKey();
  OverlayEntry? _manoConfirmar;
  Timer? _timerConfirmar;

  // Clase de ejemplo para practicar la salida (entrada ya marcada)
  Horario? _horarioSalidaDemo;

  static const Color _primaryColor = Color(0xFF4A6CF7);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _darkColor = Color(0xFF1A2B4A);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _dangerColor = Color(0xFFEF4444);

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
    _detenerManoConfirmar();
    _detenerVoz();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  Voz
  // ─────────────────────────────────────────────────────────────
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

  // Igual que el Home: si la app pasa a segundo plano se libera la camara
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _cerrarCamara();
    // Tras una verificacion exitosa no hay boton para reabrir la camara:
    // al volver a la app se reabre sola
    if (state == AppLifecycleState.resumed &&
        _etapa == EtapaGuia.verificaciones &&
        !_verificando &&
        _verificacionExitosa &&
        _cameraController == null) {
      _abrirCamara();
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Camara real (3 fotos de practica)
  // ─────────────────────────────────────────────────────────────
  // Mismas etapas que el marcado real: 'frontal' y 'gesto' con la camara
  // delantera, 'constancia' con la trasera. _etapaCamara avanza al
  // capturar (_fotoPracticada).

  Future<void> _abrirCamara() async {
    // No abrir dos veces (tampoco si ya esta abierta)
    if (_abriendoCamara || _cameraController != null) return;
    setState(() => _abriendoCamara = true);

    // Al empezar la secuencia se elige un gesto nuevo, como en el Home
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
    _mostrarMarcadoExitoso();
  }

  // Aviso de exito, con el mismo texto que el Home al marcar
  // ('Entrada marcada correctamente'). Al continuar sigue la guia:
  // entrada -> tarjeta de salida, salida -> avisos comunes.
  Future<void> _mostrarMarcadoExitoso() async {
    final esSalida = _modoSalida;
    final titulo = esSalida
        ? 'Si se cumple todo lo solicitado, aparece un mensaje de que la salida fue marcada con éxito.'
        : '¡Si se cumple todo lo solicitado, aparece un mensaje de que la entrada fue marcada con éxito.';
    // En la salida no se repite el proceso en la guia: solo se explica
    const procesoSalida =
        'Para la salida se sigue el mismo proceso de verificación que el de la entrada: huella, '
        'GPS y las 3 fotos.';
    // Salida: primero una tarjeta flotante con el proceso y
    // despues la de exito, las dos con el mismo estilo.
    if (esSalida) {
      // Sin boton: se cierra sola al terminar la frase y aparece
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
    _irAEtapa(EtapaGuia.tarjeta);
  }

  // Al terminar la verificacion se abre la camara sola, como en el Home
  Future<void> _abrirCamaraTrasVerificar() async {
    // Breve pausa para que se vean las verificaciones en verde
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _etapa != EtapaGuia.verificaciones) return;
    // Avisar que todo salio bien antes de abrir la camara.
    // Se espera a que termine de leerlo para que la voz de la camara no lo corte
    await _hablar('Verificación exitosa. La cámara se abre automaticamente.');
    if (!mounted || _etapa != EtapaGuia.verificaciones) return;
    _etapaCamara = 'frontal';
    await _abrirCamara();
  }

  void _siguiente() {
    if (_esUltima) return;
    switch (_etapa) {
      // Sin marcar: se salta la practica de entrada o de salida
      case EtapaGuia.tarjeta:
        _irAEtapa(EtapaGuia.salida);
      case EtapaGuia.salida:
        _irAEtapa(EtapaGuia.consejos);
      default:
        _irAEtapa(EtapaGuia.values[_etapa.index + 1]);
    }
  }

  void _anterior() {
    if (_esPrimera) return;
    switch (_etapa) {
      // La salida viene despues de la verificacion: volver a la tarjeta
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
  // Si algo falla se explica que pasaria en la app real y se puede repetir
  // la verificacion.
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
          : 'No se verificó. Toca Repetir verificación.';
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

    // 4. Como en el Home: con huella, permisos y GPS listos se abre la
    // camara. Si algo fallo se avisa por voz y el docente usa
    // "Repetir verificacion".
    if (huellaOk &&
        _estadoPermisos == EstadoVerificacion.ok &&
        _estadoGps == EstadoVerificacion.ok) {
      _abrirCamaraTrasVerificar();
    } else {
      _hablar('Verificación fallida. Por favor, toca Repetir verificación.');
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

  // El docente confirmo el dialogo real de salida: no se repiten huella,
  // GPS y fotos, solo se explica que el proceso es el mismo de la entrada
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
        // Primero un enfoque en toda la tarjeta
        _crearTarget(
          'tarjeta',
          _keyStackTarjeta,
          ContentAlign.bottom,
          'Una vez ingresado al sistema',
          'Se podrá observar una tarjeta por cada clase del día. Desde ella marcarás tu entrada y salida.',
        ),
        _crearTarget(
          'encabezado',
          _keyEncabezado,
          ContentAlign.bottom,
          'El encabezado de la tarjeta',
          'Muestra la materia, paralelo y el horario. El color azul significa marcado pendiente.',
        ),
        _crearTarget(
          'ubicacion',
          _keyUbicacion,
          ContentAlign.bottom,
          'Aula de ejemplo',
          'Indica el nombre del aula y la hora de inicio y fin de la clase. '
              'Para ver en el mapa la zona donde debes marcar, toca el nombre del aula.',
        ),
        _crearTarget(
          'estado',
          _keyEstado,
          ContentAlign.bottom,
          'Temporizador de entrada',
          'Indica cuánto falta para que comience la clase. La entrada se marca desde 30 min antes.',
        ),
        _crearTarget(
          'botones',
          _keyBotones,
          ContentAlign.top,
          'Boton "Marcar Entrada"',
          'Tócalo al llegar al aula para registrar su entrada.',
        ),
      ];
      _mostrarTargets(targets);
    });
  }

  // Tutorial sobre la tarjeta de salida (etapa 4)
  void _mostrarTutorialSalida() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _etapa != EtapaGuia.salida) return;

      _mostrarTargets([
        _crearTarget(
          'encabezado_salida',
          _keyEncabezado,
          ContentAlign.bottom,
          'Una vez que la entrada fue marcada',
          'La tarjeta cambia de color a un tono naranja, lo cual significa actividades en curso.',
        ),
        _crearTarget(
          'temporizador_salida',
          _keySalida,
          ContentAlign.bottom,
          'Temporizador de salida',
          'Indica cuánto falta para terminar la clase.',
        ),
        _crearTarget(
          'boton_salida',
          _keyBotones,
          ContentAlign.top,
          'Boton "Marcar Salida"',
          'Se habilita 30 min antes de que finalice las actividades.',
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
    if (_etapa == EtapaGuia.tarjeta) _mostrarManoEntrada();
    if (_etapa == EtapaGuia.salida) {
      _mostrarManoEn(
        objetivo: _keyBotones,
        stack: _keyStackSalida,
        texto: 'Toca Marcar Salida',
        voz: 'Ahora toca el botón rojo, Marcar Salida.',
      );
      _vigilarDialogoSalida();
    }
  }

  // Mientras el dialogo de salida este abierto, dibuja un dedo
  // sobre "Confirmar" (sin voz). Se revisa seguido porque el dialogo se
  // abre y se cierra desde la tarjeta, y entra con una animacion.
  void _vigilarDialogoSalida() {
    _timerConfirmar?.cancel();
    _timerConfirmar = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) return;
      final abierto = _keyConfirmarSalida.currentContext != null;
      if (abierto && _manoConfirmar == null) {
        _detenerVoz();
        // Ya se toco "Marcar Salida": quitar ese dedo del fondo
        setState(_ocultarManoPantalla);
        _manoConfirmar = OverlayEntry(builder: _buildManoConfirmar);
        Overlay.of(context, rootOverlay: true).insert(_manoConfirmar!);
      } else if (!abierto && _manoConfirmar != null) {
        _quitarManoConfirmar();
        if (_modoSalida || _etapa != EtapaGuia.salida) {
          // Se confirmo la salida: ya no hace falta ningun dedo
          _timerConfirmar?.cancel();
          _timerConfirmar = null;
        } else {
          // Se cancelo el dialogo: volver a senalar "Marcar Salida" (sin voz)
          _mostrarManoEn(
            objetivo: _keyBotones,
            stack: _keyStackSalida,
            texto: 'Toca Marcar Salida',
          );
        }
      } else {
        // Seguir la posicion del boton mientras el dialogo se anima
        _manoConfirmar?.markNeedsBuild();
      }
    });
  }

  Widget _buildManoConfirmar(BuildContext context) {
    final box =
        _keyConfirmarSalida.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return const SizedBox.shrink();
    final centro = box.localToGlobal(box.size.center(Offset.zero));
    return Positioned(
      left: centro.dx - 60,
      top: centro.dy - 8,
      child: const IgnorePointer(
        // Fuera del Scaffold: Material para que el texto tenga su estilo
        child: Material(
          type: MaterialType.transparency,
          child: _ManoIndicadora(texto: 'Toca Confirmar'),
        ),
      ),
    );
  }

  void _quitarManoConfirmar() {
    _manoConfirmar?.remove();
    _manoConfirmar = null;
  }

  void _detenerManoConfirmar() {
    _timerConfirmar?.cancel();
    _timerConfirmar = null;
    _quitarManoConfirmar();
  }

  // ─────────────────────────────────────────────────────────────
  //  Dedo indicador
  // ─────────────────────────────────────────────────────────────
  // _mostrarManoEn() sirve para cualquier boton de la tarjeta de entrada
  // o de salida. El dedo se dibuja dentro de la zona creada con _conMano().

  // Tarjeta de entrada: senala "Marcar Entrada"
  void _mostrarManoEntrada() {
    _mostrarManoEn(
      objetivo: _keyBotones,
      stack: _keyStackTarjeta,
      texto: 'Toca Marcar Entrada',
      voz: 'Ahora toca el botón azul, Marcar Entrada.',
    );
  }

  void _mostrarManoEn({
    required GlobalKey objetivo,
    required GlobalKey stack,
    required String texto,
    String? voz,
  }) {
    setState(() {
      _manoObjetivo = objetivo;
      _manoStack = stack;
      _manoTexto = texto;
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
    _detenerManoConfirmar();
    _ocultarManoPantalla();
  }

  // Solo el dedo dibujado en la pantalla (no el del dialogo de salida)
  void _ocultarManoPantalla() {
    _timerMano?.cancel();
    _timerMano = null;
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

    final punta = rect.center;
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
      case EtapaGuia.salida:
        return _buildEtapaSalida();
      case EtapaGuia.consejos:
        return _buildEtapaConsejos();
      case EtapaGuia.fin:
        return _buildEtapaFin();
    }
  }

  // Etapa 5: errores comunes. Los titulos son los mismos mensajes que
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

  // Etapa 6: resumen final
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
        // La tarjeta va dentro de un Stack para dibujar el dedo encima
        _conMano(
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
            // Sin entrada marcada no hay boton de salida (etapa 4)
            onMarcarSalida: () {},
            keyEncabezado: _keyEncabezado,
            keyUbicacion: _keyUbicacion,
            keyEstado: _keyEstado,
            keyBotones: _keyBotones,
          ),
        ),
        if (!_demoConUbicacion) _buildAvisoSinUbicacion(),
      ],
    );
  }

  // Etapa 4: tarjeta con la entrada marcada y el dialogo real de salida
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
            keyConfirmarSalida: _keyConfirmarSalida,
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

  bool get _verificacionExitosa =>
      _estadoHuella == EstadoVerificacion.ok &&
      _estadoPermisos == EstadoVerificacion.ok &&
      _estadoGps == EstadoVerificacion.ok;

  // Etapa 3: huella, permisos y GPS
  Widget _buildEtapaVerificaciones() {
    final sinIniciar = _estadoHuella == EstadoVerificacion.pendiente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Marcando entrada. Antes de la cámara se verifica:',
          style: TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
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
        // Si todo salio bien no se muestra: la camara se abre sola
        if (!_verificando && !_verificacionExitosa)
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
          // En el ultimo paso solo queda "Terminar"
          if (!_esPrimera && !_esUltima)
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
          // En la verificacion no hay boton derecho: la camara se
          // abre sola y si falla se usa "Repetir verificacion"
          if (!_esPrimera && !_esUltima && _etapa != EtapaGuia.verificaciones)
            const SizedBox(width: 12),
          if (_etapa != EtapaGuia.verificaciones)
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
                      : 'Siguiente',
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
