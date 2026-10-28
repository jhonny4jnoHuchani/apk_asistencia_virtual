import 'package:flutter/material.dart';
import '../models/clase_semanal.dart';
import '../services/horario_service.dart';
import '../widgets/loading_indicator.dart';

// Horario de toda la semana (GET /horarios/semanal), agrupado por dia
class HorarioSemanalScreen extends StatefulWidget {
  const HorarioSemanalScreen({super.key});

  @override
  State<HorarioSemanalScreen> createState() => _HorarioSemanalScreenState();
}

class _HorarioSemanalScreenState extends State<HorarioSemanalScreen> {
  final HorarioService _horarioService = HorarioService();

  List<ClaseSemanal> _horarios = [];
  bool _isLoading = true;
  String? _error;
  // Indice del dia que se muestra (0 = Lunes). Por defecto hoy
  int? _diaSeleccionado;

  // Misma paleta que Inicio, Historial y la tarjeta de clase
  static const Color _primary = Color(0xFF007AFF);
  static const Color _purple = Color(0xFFAF52DE);
  static const Color _success = Color(0xFF34C759);
  static const Color _warning = Color(0xFFFF9500);
  static const Color _danger = Color(0xFFFF3B30);
  static const Color _bg = Color(0xFFF2F2F7);
  static const Color _border = Color(0xFFE5E5EA);
  static const Color _textPrimary = Color(0xFF1C1C1E);
  static const Color _textSecondary = Color(0xFF8E8E93);

  // Horas de jornada por dia con clases: 10 h de permanencia menos 1 h 30 min
  // de descanso y 30 min de tolerancia
  static const int _horasJornada = 8;

  // Franja de color de cada materia
  static const List<Color> _coloresMateria = [
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFF5856D6),
    Color(0xFFFF2D55),
    Color(0xFF30B0C7),
  ];

  static const List<String> _diasCortos = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  static const List<String> _dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    _cargarHorarios();
  }

  Future<void> _cargarHorarios() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final horarios = await _horarioService.getHorariosSemanal();
      if (!mounted) return;
      setState(() {
        _horarios = horarios;
        _isLoading = false;
        _diaSeleccionado ??= _diaInicial();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Indice 0-6 del dia (Lunes = 0). Acepta nombre con o sin tilde, en
  // cualquier mayuscula, o numero (1 = Lunes ... 7 = Domingo).
  int _indiceDia(String dia) {
    final numero = int.tryParse(dia.trim());
    if (numero != null && numero >= 1 && numero <= 7) return numero - 1;
    final normal =
        dia.trim().toLowerCase().replaceAll('é', 'e').replaceAll('á', 'a');
    const nombres = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];
    final i = nombres.indexOf(normal);
    return i == -1 ? 7 : i; // dias desconocidos al final
  }

  // Horario agrupado por dia, en orden de la semana y por hora de inicio
  Map<int, List<ClaseSemanal>> get _porDia {
    final mapa = <int, List<ClaseSemanal>>{};
    for (final h in _horarios) {
      mapa.putIfAbsent(_indiceDia(h.diaSemana), () => []).add(h);
    }
    for (final lista in mapa.values) {
      lista.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    }
    return Map.fromEntries(
        mapa.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  // Hoy si tiene clases (o si es Lun-Sab, para ver "Dia libre"); si es
  // domingo sin clases, el primer dia con clases
  int? _diaInicial() {
    final porDia = _porDia;
    if (porDia.isEmpty) return null;
    final hoy = DateTime.now().weekday - 1;
    if (porDia.containsKey(hoy) || hoy < 6) return hoy;
    return porDia.keys.first;
  }

  // "08:00:00" -> "08:00"
  String _hora(String hora) => hora.length >= 5 ? hora.substring(0, 5) : hora;

  // Diseño con la misma escala compacta de Historial: tarjetas de
  // radio 10 con borde de color, icono cuadrado con degradado y textos
  // pequenos. Resumen de la semana, selector de dias y clases del dia elegido
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
        ),
        title: const Text(
          'Horario semanal',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _border),
        ),
        actions: [
          IconButton(
            onPressed: _cargarHorarios,
            icon: const Icon(Icons.refresh_rounded, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(mensaje: 'Cargando horario...');
    }
    if (_error != null) {
      return _buildMensaje(
        Icons.error_outline_rounded,
        'Error al cargar',
        _error!,
        color: _danger,
        reintentar: true,
      );
    }
    if (_horarios.isEmpty) {
      return _buildMensaje(
        Icons.event_busy_rounded,
        'Sin clases esta semana',
        'No tienes horarios asignados.',
        reintentar: true,
      );
    }

    final porDia = _porDia;
    final seleccionado = _diaSeleccionado ?? porDia.keys.first;
    final clases = porDia[seleccionado] ?? [];

    return RefreshIndicator(
      color: _primary,
      onRefresh: _cargarHorarios,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 40),
        children: [
          _buildResumen(porDia),
          const SizedBox(height: 8),
          _buildSelectorDias(porDia, seleccionado),
          const SizedBox(height: 12),
          _buildEncabezadoDia(seleccionado, clases),
          const SizedBox(height: 6),
          if (clases.isEmpty)
            _buildDiaLibre(seleccionado)
          else
            for (final h in clases) _buildClase(h, seleccionado),
        ],
      ),
    );
  }

  // Tarjeta superior: icono con degradado, titulo y tres cajitas con el
  // total de clases, dias y horas (mismo estilo que Entrada/Salida)
  Widget _buildResumen(Map<int, List<ClaseSemanal>> porDia) {
    final dias = porDia.keys.where((d) => d < 7).length;
    // Cada dia con clases cuenta como una jornada fija
    final horas = dias * _horasJornada;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primary.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              _buildIconoCuadrado(
                Icons.calendar_month_rounded,
                const [_primary, _purple],
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi semana',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Carga horaria asignada',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 0.5, color: Colors.grey.shade100),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildCajaDato(
                  Icons.class_outlined,
                  'Clases',
                  '${_horarios.length}',
                  _primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCajaDato(
                  Icons.event_available_rounded,
                  'Días',
                  '$dias',
                  _success,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCajaDato(
                  Icons.schedule_rounded,
                  'Horas',
                  '$horas',
                  _warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Cuadrado de 28 con degradado e icono blanco (como el de Historial)
  Widget _buildIconoCuadrado(IconData icono, List<Color> colores) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colores),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icono, color: Colors.white, size: 14),
    );
  }

  // Cajita de color con icono, etiqueta a la izquierda y valor a la derecha
  Widget _buildCajaDato(
      IconData icono, String etiqueta, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              etiqueta,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const Spacer(),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Fila de dias (Lun ... Sab, Dom solo si tiene clases), con el estilo de
  // los filtros de Historial: elegido en azul, hoy con borde azul
  Widget _buildSelectorDias(
      Map<int, List<ClaseSemanal>> porDia, int seleccionado) {
    final hoy = DateTime.now().weekday - 1;
    final indices = [
      for (var i = 0; i < 6; i++) i,
      if (porDia.containsKey(6)) 6,
      if (porDia.containsKey(7)) 7,
    ];

    return Row(
      children: [
        for (var n = 0; n < indices.length; n++) ...[
          if (n > 0) const SizedBox(width: 6),
          Expanded(
            child: _buildDiaChip(
              indice: indices[n],
              total: porDia[indices[n]]?.length ?? 0,
              activo: indices[n] == seleccionado,
              esHoy: indices[n] == hoy,
            ),
          ),
        ],
      ],
    );
  }

  // Estilo calendario: dia corto, numero del dia del mes y un punto
  // por clase
  Widget _buildDiaChip({
    required int indice,
    required int total,
    required bool activo,
    required bool esHoy,
  }) {
    final corto = indice < _diasCortos.length ? _diasCortos[indice] : 'Otro';
    final fecha = indice < 7 ? '${_fechaDia(indice).day}' : '?';
    final colorBorde = activo
        ? _primary
        : (esHoy ? _primary.withValues(alpha: 0.5) : Colors.grey.shade200);
    final colorPunto = activo ? Colors.white : _primary;

    return InkWell(
      onTap: () => setState(() => _diaSeleccionado = indice),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: activo ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorBorde),
        ),
        child: Column(
          children: [
            Text(
              corto,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: activo ? Colors.white70 : _textSecondary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              fecha,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    activo ? Colors.white : (esHoy ? _primary : _textPrimary),
              ),
            ),
            const SizedBox(height: 3),
            // Un punto por clase (maximo 3, luego "+")
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < total.clamp(0, 3); i++)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: colorPunto,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (total > 3)
                    Text(
                      '+',
                      style: TextStyle(
                        fontSize: 7,
                        height: 0.7,
                        fontWeight: FontWeight.w700,
                        color: colorPunto,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fecha del dia en la semana actual (0 = lunes de esta semana)
  DateTime _fechaDia(int indice) {
    final hoy = DateTime.now();
    return DateTime(hoy.year, hoy.month, hoy.day)
        .subtract(Duration(days: hoy.weekday - 1))
        .add(Duration(days: indice));
  }

  Widget _buildEncabezadoDia(int indice, List<ClaseSemanal> clases) {
    final nombre = indice < _dias.length
        ? _dias[indice]
        : (clases.isEmpty || clases.first.diaSemana.isEmpty
            ? 'Sin día'
            : clases.first.diaSemana);
    final esHoy = indice == DateTime.now().weekday - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Text(
            nombre,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          if (esHoy) ...[
            const SizedBox(width: 6),
            _buildEtiqueta('Hoy', _primary),
          ],
          const Spacer(),
          if (clases.isNotEmpty)
            Text(
              '${clases.length} ${clases.length == 1 ? 'clase' : 'clases'}'
              ' · Jornada $_horasJornada h',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: _textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  // Clase con la misma forma que la tarjeta de Historial: cabecera con
  // icono y materia, cajitas de Entrada/Salida y ubicacion abajo
  Widget _buildClase(ClaseSemanal h, int indiceDia) {
    final color = _colorMateria(h.materia);
    final enCurso = _estaEnCurso(h, indiceDia);
    final colorBorde = enCurso ? _success : color;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorBorde.withValues(alpha: enCurso ? 0.5 : 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // CABECERA
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIconoCuadrado(
                  Icons.menu_book_rounded,
                  [color, color.withValues(alpha: 0.7)],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              h.materia,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (enCurso)
                            _buildEtiqueta('En curso', _success)
                          else if (!h.estaActivo)
                            _buildEtiqueta(h.estado!, _textSecondary)
                          else
                            _buildEtiqueta('Paralelo ${h.paralelo}', color),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 11, color: _textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            _formatoDuracion(_duracionMinutos(h)),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: _textSecondary,
                            ),
                          ),
                          if (enCurso || !h.estaActivo) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Paralelo ${h.paralelo}',
                              style: const TextStyle(
                                  fontSize: 10.5, color: _textSecondary),
                            ),
                          ],
                          if (h.actividad != null) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                h.actividad!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10.5, color: _textSecondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(height: 0.5, color: Colors.grey.shade100),
            const SizedBox(height: 6),
            // ENTRADA Y SALIDA
            Row(
              children: [
                Expanded(
                  child: _buildCajaDato(
                    Icons.login_rounded,
                    'Entrada',
                    _hora(h.horaInicio),
                    _success,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCajaDato(
                    Icons.logout_rounded,
                    'Salida',
                    _hora(h.horaFin),
                    _warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // UBICACION
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 11, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      h.ubicacionDisplay ?? 'Sin ubicación',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dia elegido sin clases (mismo estilo que el estado vacio de Historial)
  Widget _buildDiaLibre(int indice) {
    final nombre = indice < _dias.length ? _dias[indice].toLowerCase() : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.free_breakfast_rounded,
                size: 24, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 10),
          const Text(
            'Día de descanso',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'No tienes clases programadas el $nombre.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  // Etiqueta pequena de color ("Hoy", "En curso", "Paralelo B")
  Widget _buildEtiqueta(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // Error o semana sin clases (mismo estilo que Historial)
  Widget _buildMensaje(
    IconData icono,
    String titulo,
    String detalle, {
    Color? color,
    bool reintentar = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color?.withValues(alpha: 0.1) ?? Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(icono, size: 28, color: color ?? Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _textSecondary),
            ),
            if (reintentar) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargarHorarios,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Mismo color siempre para la misma materia
  Color _colorMateria(String materia) {
    final suma = materia.codeUnits.fold<int>(0, (a, b) => a + b);
    return _coloresMateria[suma % _coloresMateria.length];
  }

  // "08:30" -> 510
  int _minutos(String hora) {
    final partes = hora.split(':');
    if (partes.length < 2) return 0;
    return (int.tryParse(partes[0]) ?? 0) * 60 + (int.tryParse(partes[1]) ?? 0);
  }

  int _duracionMinutos(ClaseSemanal h) {
    final duracion = _minutos(h.horaFin) - _minutos(h.horaInicio);
    return duracion > 0 ? duracion : 0;
  }

  // 90 -> "1 h 30 min"
  String _formatoDuracion(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  // Clase de hoy cuya hora actual esta entre inicio y fin
  bool _estaEnCurso(ClaseSemanal h, int indiceDia) {
    final ahora = DateTime.now();
    if (indiceDia != ahora.weekday - 1) return false;
    final actual = ahora.hour * 60 + ahora.minute;
    return actual >= _minutos(h.horaInicio) && actual < _minutos(h.horaFin);
  }
}
