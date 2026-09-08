import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/marcado.dart';
import '../services/marcado_service.dart';
import '../widgets/loading_indicator.dart';
import 'package:flutter/cupertino.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final MarcadoService _marcadoService = MarcadoService();
  final TextEditingController _searchController = TextEditingController();

  List<GrupoMarcado> _grupos = [];
  List<GrupoMarcado> _gruposFiltrados = [];
  bool _isLoading = true;
  String? _error;

  DateTime? _filtroFecha;
  int? _filtroMes;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  static const Color _primary = Color(0xFF007AFF);
  static const Color _success = Color(0xFF34C759);
  static const Color _warning = Color(0xFFFF9500);
  static const Color _danger = Color(0xFFFF3B30);
  static const Color _bg = Color(0xFFF2F2F7);
  static const Color _textPrimary = Color(0xFF1C1C1E);
  static const Color _textSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _scrollController.addListener(() {
      if (mounted)
        setState(() => _showScrollToTop = _scrollController.offset > 300);
    });
    _searchController.addListener(_filtrarBusqueda);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resultado = await _marcadoService.getHistorial(
          fecha: _filtroFecha, mes: _filtroMes);
      setState(() {
        _grupos = _agruparPorHorario(resultado);
        _gruposFiltrados = _grupos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _filtrarBusqueda() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _gruposFiltrados = _grupos
          .where((g) =>
              g.materia.toLowerCase().contains(query) ||
              g.paralelo.toLowerCase().contains(query))
          .toList();
    });
  }

  List<GrupoMarcado> _agruparPorHorario(List<Marcado> marcados) {
    final Map<String, GrupoMarcado> gruposMap = {};
    for (final m in marcados) {
      final key =
          '${m.materia}_${m.paralelo}_${DateFormat('yyyy-MM-dd').format(m.fecha)}';
      gruposMap.putIfAbsent(
          key,
          () => GrupoMarcado(
                materia: m.materia,
                paralelo: m.paralelo,
                fecha: m.fecha,
                ubicacion: m.ubicacion,
                horaInicio: m.horaInicio ?? '--:--',
                horaFin: m.horaFin ?? '--:--',
              ));
      if (m.tipo == 'entrada') gruposMap[key]!.entrada = m;
      if (m.tipo == 'salida') gruposMap[key]!.salida = m;
    }
    return gruposMap.values.toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
        context: context,
        initialDate: _filtroFecha ?? DateTime.now(),
        firstDate: DateTime(2024),
        lastDate: DateTime.now(),
        locale: const Locale('es', 'ES'),
        builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: _primary)),
            child: child!));
    if (fecha != null) {
      setState(() {
        _filtroFecha = fecha;
        _filtroMes = null;
      });
      await _cargarHistorial();
    }
  }

  Future<void> _seleccionarMes() async {
    final mes = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _buildMonthPicker());
    if (mes != null) {
      setState(() {
        _filtroMes = mes;
        _filtroFecha = null;
      });
      await _cargarHistorial();
    }
  }

  void _limpiarFiltros() {
    _searchController.clear();
    setState(() {
      _filtroFecha = null;
      _filtroMes = null;
    });
    _cargarHistorial();
  }

  void _scrollToTop() => _scrollController.animateTo(0,
      duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(children: [
        _buildSearchBar(),
        _buildFiltros(),
        Expanded(child: _buildContenido())
      ]),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              backgroundColor: _primary,
              onPressed: _scrollToTop,
              child:
                  const Icon(Icons.arrow_upward, color: Colors.white, size: 20))
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _textPrimary,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded, size: 28)),
      title: const Text('Historial',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFE5E5EA))),
      actions: [
        IconButton(
            onPressed: _cargarHistorial,
            icon: const Icon(Icons.refresh_rounded, size: 22)),
        const SizedBox(width: 4)
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0), // REDUCIDO
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar materia o paralelo...',
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: _limpiarFiltros)
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    final hasFilter = _filtroFecha != null || _filtroMes != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4), // REDUCIDO
      child: Row(children: [
        Expanded(
            child: _buildFilterChip(
                icon: Icons.calendar_today_rounded,
                label: _filtroFecha != null
                    ? DateFormat('dd MMM').format(_filtroFecha!)
                    : 'Fecha',
                isActive: _filtroFecha != null,
                onPressed: _seleccionarFecha)),
        const SizedBox(width: 6),
        Expanded(
            child: _buildFilterChip(
                icon: Icons.date_range_rounded,
                label: _filtroMes != null
                    ? _capitalizarMes(DateFormat('MMMM', 'es')
                        .format(DateTime(2024, _filtroMes!, 1)))
                    : 'Mes',
                isActive: _filtroMes != null,
                onPressed: _seleccionarMes)),
        if (hasFilter) ...[
          const SizedBox(width: 6),
          InkWell(
              onTap: _limpiarFiltros,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: _danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.close_rounded, size: 14, color: _danger)))
        ],
      ]),
    );
  }

  Widget _buildFilterChip(
      {required IconData icon,
      required String label,
      required bool isActive,
      required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // REDUCIDO
        decoration: BoxDecoration(
            color: isActive ? _primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: isActive ? _primary : Colors.grey.shade200)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: isActive ? Colors.white : _textSecondary),
          const SizedBox(width: 4),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : _textSecondary),
                  overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  String _capitalizarMes(String mes) => mes[0].toUpperCase() + mes.substring(1);

  Widget _buildMonthPicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 10),
        const Text('Seleccionar mes',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6),
            itemCount: 12,
            itemBuilder: (context, index) {
              final mesNum = index + 1;
              final mesNombre =
                  DateFormat('MMMM', 'es').format(DateTime(2024, mesNum, 1));
              final isSelected = _filtroMes == mesNum;
              return InkWell(
                onTap: () => Navigator.pop(context, mesNum),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                    decoration: BoxDecoration(
                        color: isSelected ? _primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6)),
                    child: Center(
                        child: Text(_capitalizarMes(mesNombre),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : _textPrimary)))),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _buildContenido() {
    if (_isLoading)
      return const LoadingIndicator(mensaje: 'Cargando historial...');
    if (_error != null) return _buildErrorState();
    if (_gruposFiltrados.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _cargarHistorial,
      color: _primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 60), // REDUCIDO
        itemCount: _gruposFiltrados.length,
        itemBuilder: (context, index) =>
            _buildGrupoCard(_gruposFiltrados[index]),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      color: _danger.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.error_outline_rounded,
                      size: 24, color: _danger)),
              const SizedBox(height: 12),
              const Text('Error al cargar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: _cargarHistorial,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reintentar')),
            ])));
  }

  Widget _buildEmptyState() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.inbox_outlined,
                      size: 28, color: Colors.grey.shade400)),
              const SizedBox(height: 12),
              Text(
                  _searchController.text.isNotEmpty
                      ? 'Sin resultados'
                      : 'No hay registros',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  _filtroFecha != null || _filtroMes != null
                      ? 'No se encontraron registros con los filtros aplicados'
                      : 'Aún no has registrado ninguna asistencia',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _textSecondary)),
            ])));
  }

  Widget _buildGrupoCard(GrupoMarcado grupo) {
    final fechaFormateada = DateFormat('dd/MM/yyyy').format(grupo.fecha);
    final completado = grupo.entrada != null && grupo.salida != null;
    final estadoColor = completado ? _success : _warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 6), // REDUCIDO de 10 a 6
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10), // REDUCIDO de 12 a 10
        border: Border.all(color: estadoColor.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8), // REDUCIDO de 10 a 8
        child: Column(children: [
          // HEADER
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28, height: 28, // REDUCIDO de 32 a 28
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [estadoColor, estadoColor.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(7)),
              child: Icon(
                  completado
                      ? Icons.check_circle_rounded
                      : Icons.pending_rounded,
                  color: Colors.white,
                  size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(grupo.materia,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)), // 14 -> 13.5
                      const SizedBox(width: 6),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: estadoColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(completado ? 'Completado' : 'Pendiente',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: estadoColor))), // 10 -> 9
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(CupertinoIcons.clock,
                          size: 11, color: _textSecondary), // 12 -> 11
                      const SizedBox(width: 3),
                      Text('${grupo.horaInicio} - ${grupo.horaFin}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: _textSecondary,
                              fontWeight: FontWeight.w500)), // 11 -> 10.5
                      const SizedBox(width: 6),
                      Text('Paralelo ${grupo.paralelo}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: _textSecondary)), // 11 -> 10.5
                    ]),
                  ]),
            ),
          ]),
          const SizedBox(height: 6), // REDUCIDO de 8 a 6
          Divider(height: 0.5, color: Colors.grey.shade100),
          const SizedBox(height: 6),
          // ENTRADA Y SALIDA
          Row(children: [
            Expanded(
                child: _buildMarcadoItem(
                    tipo: 'Entrada',
                    marcado: grupo.entrada,
                    color: _success,
                    icon: Icons.login_rounded,
                    horaProgramada: grupo.horaInicio)),
            const SizedBox(width: 6), // REDUCIDO de 8 a 6
            Expanded(
                child: _buildMarcadoItem(
                    tipo: 'Salida',
                    marcado: grupo.salida,
                    color: _warning,
                    icon: Icons.logout_rounded,
                    horaProgramada: grupo.horaFin)),
          ]),
          if (grupo.ubicacion != null) ...[
            const SizedBox(height: 6),
            Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3), // REDUCIDO
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(5)),
                child: Row(children: [
                  Icon(Icons.location_on_outlined,
                      size: 11, color: Colors.grey.shade500), // 12 -> 11
                  const SizedBox(width: 3),
                  Expanded(
                      child: Text(grupo.ubicacion!,
                          style: TextStyle(
                              fontSize: 9.5, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)), // 10 -> 9.5
                ])),
          ],
        ]),
      ),
    );
  }

  Widget _buildMarcadoItem(
      {required String tipo,
      required Marcado? marcado,
      required Color color,
      required IconData icon,
      required String horaProgramada}) {
    final bool existe = marcado != null;
    final String horaReal = existe ? marcado!.hora : '--:--';
    final String estado = existe ? marcado!.estadoAsistencia : 'No marcado';
    final bool esPuntual = existe ? marcado!.esPuntual : false;

    String diferencia = '';
    if (existe && horaProgramada != '--:--') {
      try {
        final realMinutos = int.parse(horaReal.split(':')[0]) * 60 +
            int.parse(horaReal.split(':')[1]);
        final progMinutos = int.parse(horaProgramada.split(':')[0]) * 60 +
            int.parse(horaProgramada.split(':')[1]);
        final diff = realMinutos - progMinutos;
        if (diff.abs() > 0) diferencia = ' (${diff > 0 ? '+' : ''}$diff min)';
      } catch (e) {}
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 5), // REDUCIDO de 8,6 a 7,5
      decoration: BoxDecoration(
          color: existe ? color.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: existe ? color.withOpacity(0.12) : Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon,
              size: 11,
              color: existe ? color : Colors.grey.shade400), // 12 -> 11
          const SizedBox(width: 3),
          Text(tipo,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: existe ? color : Colors.grey.shade400)), // 10 -> 9.5
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(horaReal,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: existe
                        ? _textPrimary
                        : Colors.grey.shade400)), // 12 -> 11.5
            if (existe && diferencia.isNotEmpty)
              Text(diferencia,
                  style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w500,
                      color: esPuntual ? _success : _warning)), // 8 -> 7.5
          ]),
        ]),
        const SizedBox(height: 2),
        if (existe)
          Row(children: [
            Icon(
                esPuntual
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 9,
                color: esPuntual ? _success : _warning), // 10 -> 9
            const SizedBox(width: 3),
            Expanded(
                child: Text(estado,
                    style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                        color: esPuntual ? _success : _warning),
                    overflow: TextOverflow.ellipsis)), // 9 -> 8.5
          ])
        else
          Row(children: [
            Icon(Icons.schedule_rounded,
                size: 9, color: Colors.grey.shade400), // 10 -> 9
            const SizedBox(width: 3),
            Text('Programada: $horaProgramada',
                style: TextStyle(
                    fontSize: 8.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500)), // 9 -> 8.5
          ]),
      ]),
    );
  }
}

class GrupoMarcado {
  String materia;
  String paralelo;
  DateTime fecha;
  String? ubicacion;
  String horaInicio;
  String horaFin;
  Marcado? entrada;
  Marcado? salida;
  GrupoMarcado(
      {required this.materia,
      required this.paralelo,
      required this.fecha,
      this.ubicacion,
      required this.horaInicio,
      required this.horaFin,
      this.entrada,
      this.salida});
}
