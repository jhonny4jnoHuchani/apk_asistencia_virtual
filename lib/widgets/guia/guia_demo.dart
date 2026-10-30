part of '../../screens/guia_practica_screen.dart';

// ============================================
// GUIA DE USO - DATOS DE EJEMPLO
// ============================================
// Cuando se abre la guia sola (primer ingreso de cada usuario) y la clase
// de ejemplo que se muestra en la tarjeta real del Home.

// La guia se abre sola una vez por usuario: en el celular se guarda una
// marca con el id de cada usuario que ya la termino.
String _claveGuiaVista(int? userId) => 'ya_vio_tutorial_$userId';

// Pantalla a la que se va al terminar el login: la guia si este usuario
// aun no la vio, si no el Home.
Future<Widget> pantallaTrasLogin(int? userId) async {
  final prefs = await SharedPreferences.getInstance();
  final yaVioTutorial = prefs.getBool(_claveGuiaVista(userId)) ?? false;
  return yaVioTutorial ? const HomeScreen() : const GuiaPracticaScreen();
}

mixin _GuiaDemo on State<GuiaPracticaScreen> {
  // Datos de la pantalla que usa la clase de ejemplo
  EtapaGuia get _etapa;
  void _mostrarTutorialTarjeta();

  // Clase de ejemplo que se muestra en la tarjeta real
  Horario? _horarioDemo;
  bool _demoConUbicacion = false;
  bool _buscandoUbicacion = false;
  String _horaInicioDemo = '';
  String _horaFinDemo = '';

  // Clase de ejemplo para practicar la salida (entrada ya marcada)
  Horario? _horarioSalidaDemo;

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
}
