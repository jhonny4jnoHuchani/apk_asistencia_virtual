import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../models/horario.dart';
import '../providers/auth_provider.dart';
import '../services/biometric_service.dart';
import '../utils/gestos.dart';
import '../widgets/home/camera_marcado_screen.dart';
import '../widgets/home/horario_card_extended.dart';
import 'home_screen.dart';

// La guia esta repartida en partes de este mismo archivo (comparten lo
// privado), en la carpeta lib/widgets/guia/ (como las piezas del Home en
// lib/widgets/home/):
part '../widgets/guia/guia_voz.dart'; // voz y textos que se leen
part '../widgets/guia/guia_demo.dart'; // clase de ejemplo y primer ingreso
part '../widgets/guia/guia_tutorial.dart'; // recuadros del tutorial y dedo
part '../widgets/guia/guia_etapas.dart'; // piezas visuales de cada etapa

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
//
// Este archivo tiene el flujo: etapas, navegacion, verificaciones y
// camara.

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
    with WidgetsBindingObserver, _GuiaVoz, _GuiaDemo, _GuiaTutorial {
  @override
  EtapaGuia _etapa = EtapaGuia.intro;

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
  @override
  String _gestoDemo = generarGestoAleatorio();
  // Foto en curso, mismos valores que el Home: 'frontal', 'gesto', 'constancia'
  @override
  String _etapaCamara = 'frontal';

  // true cuando ya se confirmo la salida de practica
  @override
  bool _modoSalida = false;

  int get _numeroPaso => _etapa.index + 1;
  int get _totalPasos => EtapaGuia.values.length;
  bool get _esPrimera => _etapa == EtapaGuia.values.first;
  bool get _esUltima => _etapa == EtapaGuia.values.last;

  bool get _verificacionExitosa =>
      _estadoHuella == EstadoVerificacion.ok &&
      _estadoPermisos == EstadoVerificacion.ok &&
      _estadoGps == EstadoVerificacion.ok;

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
    _posMano.dispose();
    _detenerManoConfirmar();
    _detenerVoz();
    super.dispose();
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
  //  Navegacion entre etapas
  // ─────────────────────────────────────────────────────────────
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

  // Marca la guia como vista y sale:
  // - Abierta desde el Home o Perfil (push): vuelve a esa pantalla.
  // - Primer ingreso (pushReplacement, sin pantalla anterior): va al Home.
  Future<void> _finalizar() async {
    _detenerVoz();
    final userId = context.read<AuthProvider>().user?.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveGuiaVista(userId), true);
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

  // ─────────────────────────────────────────────────────────────
  //  Fin del marcado de practica
  // ─────────────────────────────────────────────────────────────
  // El docente confirmo el dialogo real de salida: no se repiten huella,
  // GPS y fotos, solo se explica que el proceso es el mismo de la entrada
  void _salidaPracticada() {
    setState(() => _modoSalida = true);
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
          child: _TarjetaFlotante(
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

  // ─────────────────────────────────────────────────────────────
  //  Pantalla
  // ─────────────────────────────────────────────────────────────
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
            _ProgresoGuia(numeroPaso: _numeroPaso, totalPasos: _totalPasos),
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

  Widget _buildContenidoEtapa() {
    switch (_etapa) {
      case EtapaGuia.intro:
        return const _TextoEtapa(
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
        return const _EtapaConsejos();
      case EtapaGuia.fin:
        return const _EtapaFin();
    }
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
        if (!_demoConUbicacion)
          _AvisoSinUbicacion(
            buscando: _buscandoUbicacion,
            onReintentar: _reintentarUbicacion,
          ),
      ],
    );
  }

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
        _FilaVerificacion(
          Icons.fingerprint_rounded,
          '1. Huella',
          _estadoHuella,
          _detalleHuella,
        ),
        _FilaVerificacion(
          Icons.verified_user_rounded,
          '2. Permisos',
          _estadoPermisos,
          _detallePermisos,
        ),
        _FilaVerificacion(
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
        const _ReglaSalida(),
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
