import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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

// Etapas del recorrido, en el orden en que se muestran
enum EtapaGuia {
  intro,
  tarjeta,
  verificaciones,
  fotoFrontal,
  fotoGesto,
  fotoConstancia,
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
  String _detalleHuella = 'Se pedirá tu huella o el bloqueo del teléfono.';
  String _detallePermisos = 'Se pedirá permiso de cámara y de ubicación.';
  String _detalleGps = 'Se comprobará que el GPS esté encendido.';

  // Camara real de practica (no se toman ni se envian fotos)
  CameraController? _cameraController;
  bool _mostrarCamara = false;
  bool _abriendoCamara = false;
  String _gestoDemo = generarGestoAleatorio();
  final Set<EtapaGuia> _fotosPracticadas = {};

  // Claves para resaltar las partes de la tarjeta en el tutorial
  final GlobalKey _keyEncabezado = GlobalKey();
  final GlobalKey _keyUbicacion = GlobalKey();
  final GlobalKey _keyEstado = GlobalKey();
  final GlobalKey _keyBotones = GlobalKey();

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
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
  String get _etapaCamara {
    switch (_etapa) {
      case EtapaGuia.fotoGesto:
        return 'gesto';
      case EtapaGuia.fotoConstancia:
        return 'constancia';
      default:
        return 'frontal';
    }
  }

  Future<void> _abrirCamara() async {
    if (_abriendoCamara) return;
    setState(() => _abriendoCamara = true);

    // Al empezar la secuencia se elige un gesto nuevo, como en el Home
    if (_etapa == EtapaGuia.fotoFrontal) _gestoDemo = generarGestoAleatorio();

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
      setState(() {
        _cameraController = controller;
        _mostrarCamara = true;
      });
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
    setState(() {
      _mostrarCamara = false;
      _cameraController = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  // Boton de captura: en la practica no se toma ni se guarda la foto,
  // solo se avanza a la siguiente etapa
  void _fotoPracticada() {
    final etapaActual = _etapa;
    _cerrarCamara();
    _fotosPracticadas.add(etapaActual);

    final mensajes = {
      EtapaGuia.fotoFrontal: '¡Foto frontal practicada! Ahora el gesto.',
      EtapaGuia.fotoGesto: '¡Gesto practicado! Ahora la foto del aula.',
      EtapaGuia.fotoConstancia: '¡Las 3 fotos practicadas!',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensajes[etapaActual] ?? '¡Foto practicada!'),
      backgroundColor: _successColor,
      duration: const Duration(seconds: 2),
    ));
    _siguiente();
  }

  void _siguiente() {
    if (_esUltima) return;
    _irAEtapa(EtapaGuia.values[_etapa.index + 1]);
  }

  void _anterior() {
    if (_esPrimera) return;
    _irAEtapa(EtapaGuia.values[_etapa.index - 1]);
  }

  void _irAEtapa(EtapaGuia etapa) {
    setState(() => _etapa = etapa);
    if (etapa == EtapaGuia.tarjeta) _mostrarTutorialTarjeta();
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
      _detalleHuella = 'Coloca tu dedo en el lector o usa el bloqueo del teléfono.';
      _detallePermisos = 'Se pedirá permiso de cámara y de ubicación.';
      _detalleGps = 'Se comprobará que el GPS esté encendido.';
    });

    // 1. Huella
    final huellaOk = await _biometricService.authenticate();
    if (!mounted) return;
    setState(() {
      _estadoHuella =
          huellaOk ? EstadoVerificacion.ok : EstadoVerificacion.fallo;
      _detalleHuella = huellaOk
          ? 'Identidad confirmada.'
          : 'No se pudo verificar. En la app real te preguntará si deseas '
              'continuar sin huella.';
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
      _estadoPermisos = faltantes.isEmpty
          ? EstadoVerificacion.ok
          : EstadoVerificacion.fallo;
      _detallePermisos = faltantes.isEmpty
          ? 'Permisos concedidos.'
          : 'Falta el permiso de ${faltantes.join(' y ')}. En la app real no '
              'podrás marcar sin él; actívalo en Ajustes > Aplicaciones.';
      _estadoGps = EstadoVerificacion.enCurso;
    });

    // 3. GPS encendido y ubicacion
    await _verificarGps();
    if (!mounted) return;
    setState(() => _verificando = false);
  }

  Future<void> _verificarGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() {
        _estadoGps = EstadoVerificacion.fallo;
        _detalleGps = 'El GPS está apagado. En la app real se abrirán los '
            'ajustes para que lo actives; sin GPS no se puede marcar.';
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
        _detalleGps = 'Ubicación obtenida (precisión ±'
            '${posicion.accuracy.toStringAsFixed(0)} m). En la app real se '
            'envía con las fotos para verificar que estés en el aula.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estadoGps = EstadoVerificacion.fallo;
        _detalleGps = 'No se pudo obtener tu ubicación. Acércate a una '
            'ventana o sal al exterior e inténtalo de nuevo.';
      });
    }
  }

  Future<void> _activarGps() async {
    await Geolocator.openLocationSettings();
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
      _horarioDemo = Horario(
        id: 0,
        diaSemana: '',
        horaInicio: _horaInicioDemo,
        horaFin: _horaFinDemo,
        materia: 'Clase de ejemplo',
        paralelo: 'A',
        ubicacion: 'Aula de ejemplo',
        paraleloMateriaId: 0,
        ubicacionId: 0,
        yaMarcoEntrada: false,
        yaMarcoSalida: false,
        ubicacionNombre: 'Aula de ejemplo',
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
          'Encabezado de la clase',
          'Muestra la materia, el paralelo y el horario. El color indica el '
              'estado: azul pendiente, naranja en curso y verde completado.',
        ),
        _crearTarget(
          'ubicacion',
          _keyUbicacion,
          ContentAlign.bottom,
          'Ubicación del aula',
          _demoConUbicacion
              ? 'Toca aquí para ver el mapa con la zona de tu clase. Tu '
                  'ubicación GPS se envía con el marcado para verificar que '
                  'estés en el aula.'
              : 'Aquí aparece el aula. Con el GPS activado, al tocarla verás '
                  'el mapa con la zona de tu clase.',
        ),
        _crearTarget(
          'estado',
          _keyEstado,
          ContentAlign.bottom,
          'Temporizador',
          'Indica cuánto falta para que empiece la clase o cuánto retraso '
              'llevas. Puedes marcar la entrada desde 30 minutos antes del '
              'inicio.',
        ),
        _crearTarget(
          'botones',
          _keyBotones,
          ContentAlign.top,
          'Botón azul: Marcar Entrada',
          'Cuando llegues a tu clase, tócalo. Primero te pedirá tu huella y '
              'el GPS, y luego abrirá la cámara. ¡Pruébalo ahora!',
        ),
      ].where((t) => t.keyTarget?.currentContext != null).toList();

      if (targets.isEmpty) return;

      TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black87,
        opacityShadow: 0.8,
        paddingFocus: 8,
        textSkip: 'SALTAR',
      ).show(context: context);
    });
  }

  TargetFocus _crearTarget(
    String id,
    GlobalKey key,
    ContentAlign alineacion,
    String titulo,
    String descripcion,
  ) {
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

  // Igual que en la guia anterior: marca la guia como vista y va al Home
  Future<void> _finalizar() async {
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
    // Igual que el Home: la camara ocupa toda la pantalla
    if (_mostrarCamara && _cameraController != null) {
      return CameraMarcadoScreen(
        cameraController: _cameraController!,
        etapaFoto: _etapaCamara,
        gestoSolicitado: _gestoDemo,
        instruccionGesto: instruccionGesto,
        onCapture: _fotoPracticada,
        onCancel: _cerrarCamara,
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
          TextButton(
            onPressed: _finalizar,
            child: const Text(
              'Saltar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(),
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
  //  (por ahora un texto que indica en que fase se implementa)
  // ─────────────────────────────────────────────────────────────
  Widget _buildContenidoEtapa() {
    switch (_etapa) {
      case EtapaGuia.intro:
        return _buildTextoEtapa(
          Icons.waving_hand_rounded,
          'Bienvenido a la guía',
          'Vas a practicar un marcado completo con una clase de ejemplo, '
              'usando las mismas pantallas de la app. Nada se envía al servidor.',
        );
      case EtapaGuia.tarjeta:
        return _buildEtapaTarjeta();
      case EtapaGuia.verificaciones:
        return _buildEtapaVerificaciones();
      case EtapaGuia.fotoFrontal:
        return _buildEtapaFoto(
          Icons.face_rounded,
          'Foto 1 de 3: frontal',
          'Se usa la cámara delantera.',
          const [
            'Centra tu rostro dentro del marco.',
            'Busca buena iluminación y mira directo a la cámara.',
            'Quítate los lentes: pueden impedir el reconocimiento.',
          ],
        );
      case EtapaGuia.fotoGesto:
        return _buildEtapaFoto(
          Icons.pan_tool_rounded,
          'Foto 2 de 3: gesto',
          'Se usa la cámara delantera.',
          [
            'Comprueba que eres una persona real y no una foto.',
            'El gesto cambia en cada marcado. En esta práctica te tocó: '
                '"${instruccionGesto(_gestoDemo)}".',
            'La instrucción aparece dentro del marco de la cámara.',
          ],
        );
      case EtapaGuia.fotoConstancia:
        return _buildEtapaFoto(
          Icons.photo_camera_rounded,
          'Foto 3 de 3: constancia del aula',
          'Se usa la cámara trasera.',
          const [
            'Toma una foto del aula donde estás dando la clase.',
            'Encuadra el entorno completo.',
            'Si hay poca luz, puedes activar el flash.',
          ],
        );
      case EtapaGuia.salida:
        return _buildTextoEtapa(
          Icons.logout_rounded,
          'Marcar salida',
          'Pendiente (Fase 5): diálogo real de confirmación de salida.',
        );
      case EtapaGuia.consejos:
        return _buildTextoEtapa(
          Icons.lightbulb_rounded,
          'Consejos',
          'Pendiente (Fase 6): errores comunes y cómo evitarlos.',
        );
      case EtapaGuia.fin:
        return _buildTextoEtapa(
          Icons.check_circle_rounded,
          '¡Listo!',
          'Ya conoces todo el proceso de marcado.',
        );
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
          'Así verás cada clase en tu pantalla principal. '
          'Toca "Marcar Entrada" para continuar.',
          style: TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
        ),
        const SizedBox(height: 12),
        HorarioCardExtended(
          // Al conseguir la ubicacion se crea una tarjeta nueva para que
          // vuelva a calcular la zona y si el docente esta dentro
          key: ValueKey(_demoConUbicacion),
          horario: _horarioDemo!,
          // [ANTERIOR] onMarcarEntrada: () => _irAEtapa(EtapaGuia.verificaciones),
          // Igual que en el Home: al tocar el boton se piden huella y GPS
          onMarcarEntrada: () {
            _irAEtapa(EtapaGuia.verificaciones);
            _iniciarVerificaciones();
          },
          // Fase 5: dialogo real de confirmacion de salida
          onMarcarSalida: () {},
          keyEncabezado: _keyEncabezado,
          keyUbicacion: _keyUbicacion,
          keyEstado: _keyEstado,
          keyBotones: _keyBotones,
        ),
        // [ANTERIOR] Aviso sin opcion de reintentar:
        // if (!_demoConUbicacion)
        //   Text(
        //     'Activa el GPS y vuelve a abrir la guía para ver el mapa de la zona.',
        //     style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        //   ),
        if (!_demoConUbicacion) _buildAvisoSinUbicacion(),
      ],
    );
  }

  // Etapas 4, 5 y 6: explicacion de cada foto y boton para abrir la camara
  Widget _buildEtapaFoto(
    IconData icono,
    String titulo,
    String camara,
    List<String> consejos,
  ) {
    final practicada = _fotosPracticadas.contains(_etapa);

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
    );
  }

  // Etapa 3: huella, permisos y GPS
  Widget _buildEtapaVerificaciones() {
    final sinIniciar = _estadoHuella == EstadoVerificacion.pendiente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Antes de abrir la cámara, la app comprueba que seas tú y que '
          'estés en el aula:',
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
        if (!_verificando)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_estadoGps == EstadoVerificacion.fallo)
                OutlinedButton.icon(
                  onPressed: _activarGps,
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
                _esUltima ? 'Ir a mi horario' : 'Siguiente',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
