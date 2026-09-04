import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/marcado.dart';
import '../services/marcado_service.dart';
import '../widgets/loading_indicator.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final MarcadoService _marcadoService = MarcadoService();
  List<Marcado> _marcados = [];
  List<GrupoMarcado> _grupos = [];
  bool _isLoading = true;
  String? _error;

  DateTime? _filtroFecha;
  int? _filtroMes;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  static const Color _primaryColor = Color(0xFF5B67CA);
  static const Color _secondaryColor = Color(0xFF8B95E0);
  static const Color _backgroundColor = Color(0xFFF8F9FC);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _warningColor = Color(0xFFFDCB6E);
  static const Color _dangerColor = Color(0xFFE17055);
  static const Color _cardShadowColor = Color(0x1A5B67CA);

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _showScrollToTop = _scrollController.offset > 300;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final resultado = await _marcadoService.getHistorial(
        fecha: _filtroFecha,
        mes: _filtroMes,
      );

      if (mounted) {
        final grupos = _agruparPorHorario(resultado);
        setState(() {
          _marcados = resultado;
          _grupos = grupos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<GrupoMarcado> _agruparPorHorario(List<Marcado> marcados) {
    final Map<String, GrupoMarcado> gruposMap = {};

    for (final marcado in marcados) {
      final key =
          '${marcado.materia}_${marcado.paralelo}_${marcado.fecha.toIso8601String().split('T')[0]}';

      if (!gruposMap.containsKey(key)) {
        gruposMap[key] = GrupoMarcado(
          materia: marcado.materia,
          paralelo: marcado.paralelo,
          fecha: marcado.fecha,
          ubicacion: marcado.ubicacion,
          entrada: null,
          salida: null,
        );
      }

      final grupo = gruposMap[key]!;
      if (marcado.tipo == 'entrada') {
        grupo.entrada = marcado;
      } else if (marcado.tipo == 'salida') {
        grupo.salida = marcado;
      }
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
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textPrimary,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (fecha != null) {
      setState(() {
        _filtroFecha = fecha;
        _filtroMes = null;
      });
      await _cargarHistorial();
    }
  }

  Future<void> _seleccionarMes() async {
    final mes = await showDialog<int>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Seleccionar mes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.date_range_rounded,
                        color: _primaryColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: List.generate(12, (index) {
                    final mesNum = index + 1;
                    final mesNombre = DateFormat('MMM', 'es').format(
                      DateTime(2024, mesNum, 1),
                    );
                    final isSelected = _filtroMes == mesNum;
                    return Material(
                      color: isSelected ? _primaryColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(mesNum),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                mesNombre.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isSelected ? Colors.white : _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mes != null) {
      setState(() {
        _filtroMes = mes;
        _filtroFecha = null;
      });
      await _cargarHistorial();
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroFecha = null;
      _filtroMes = null;
    });
    _cargarHistorial();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFiltros(),
            Expanded(child: _buildContenido()),
          ],
        ),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              mini: true,
              backgroundColor: _primaryColor,
              onPressed: _scrollToTop,
              elevation: 4,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // Reducido padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: _cardShadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 22, // Reducido tamaño
            ),
          ),
          const SizedBox(width: 12),
          // Usamos Flexible para evitar overflow
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historial',
                  style: TextStyle(
                    fontSize: 20, // Reducido de 24
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  _grupos.isNotEmpty
                      ? '${_grupos.length} registros agrupados'
                      : 'Sin registros',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_grupos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Total: ${_grupos.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              icon: Icons.calendar_today_rounded,
              label: _filtroFecha != null
                  ? DateFormat('dd MMM yyyy').format(_filtroFecha!)
                  : 'Fecha',
              isActive: _filtroFecha != null,
              onPressed: _seleccionarFecha,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildFilterChip(
              icon: Icons.date_range_rounded,
              label: _filtroMes != null
                  ? _capitalizarMes(
                      DateFormat('MMMM', 'es')
                          .format(DateTime(2024, _filtroMes!, 1)),
                    )
                  : 'Mes',
              isActive: _filtroMes != null,
              onPressed: _seleccionarMes,
            ),
          ),
          if (_filtroFecha != null || _filtroMes != null) ...[
            const SizedBox(width: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _limpiarFiltros,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8), // Reducido
                  decoration: BoxDecoration(
                    color: _dangerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16, // Reducido
                    color: _dangerColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: isActive ? _primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: isActive ? 2 : 0,
      shadowColor: _primaryColor.withOpacity(0.3),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? _primaryColor : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Importante: evita overflow
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : _textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? Colors.white : _textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalizarMes(String mes) {
    return mes[0].toUpperCase() + mes.substring(1);
  }

  Widget _buildContenido() {
    if (_isLoading) {
      return const LoadingIndicator(mensaje: 'Cargando historial...');
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_grupos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _cargarHistorial,
      color: _primaryColor,
      backgroundColor: Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: _grupos.length,
        itemBuilder: (context, index) {
          final grupo = _grupos[index];
          return _buildGrupoCard(grupo);
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _dangerColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: _dangerColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargarHistorial,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: _primaryColor.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade100, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 50,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No hay registros',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filtroFecha != null || _filtroMes != null
                  ? 'No se encontraron registros con los filtros aplicados'
                  : 'Aún no has registrado asistencias',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
            if (_filtroFecha != null || _filtroMes != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Limpiar filtros'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  foregroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrupoCard(GrupoMarcado grupo) {
    final fechaFormateada = DateFormat('dd/MM/yyyy').format(grupo.fecha);
    final tieneEntrada = grupo.entrada != null;
    final tieneSalida = grupo.salida != null;
    final completado = tieneEntrada && tieneSalida;
    final estadoColor = completado ? _successColor : _warningColor;
    final estadoTexto = completado ? 'Completado' : 'Pendiente';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _cardShadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: completado
              ? _successColor.withOpacity(0.2)
              : _warningColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Con diseño compacto
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [estadoColor, estadoColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    completado
                        ? Icons.check_circle_rounded
                        : Icons.pending_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grupo.materia,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            'Paralelo ${grupo.paralelo}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fechaFormateada,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        completado
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        size: 10,
                        color: estadoColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        estadoTexto,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: estadoColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade100,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          // Entrada y Salida - AHORA MÁS COMPACTO
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _buildMarcadoItem(
                    tipo: 'Entrada',
                    marcado: grupo.entrada,
                    color: _successColor,
                    icon: Icons.login_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMarcadoItem(
                    tipo: 'Salida',
                    marcado: grupo.salida,
                    color: _warningColor,
                    icon: Icons.logout_rounded,
                  ),
                ),
              ],
            ),
          ),
          // Ubicación - MÁS COMPACTA
          if (grupo.ubicacion != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        grupo.ubicacion!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarcadoItem({
    required String tipo,
    required Marcado? marcado,
    required Color color,
    required IconData icon,
  }) {
    final bool existe = marcado != null;
    final String hora = existe ? marcado!.hora : '--:--';
    final String estado = existe ? marcado!.estadoAsistencia : 'No marcado';
    final bool esPuntual = existe ? marcado!.esPuntual : false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: existe ? color.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: existe ? color.withOpacity(0.2) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 12,
                color: existe ? color : Colors.grey.shade400,
              ),
              const SizedBox(width: 3),
              Text(
                tipo,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: existe ? color : Colors.grey.shade400,
                ),
              ),
              const Spacer(),
              Text(
                hora,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: existe ? _textPrimary : Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          if (existe) ...[
            Row(
              children: [
                Icon(
                  esPuntual
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  size: 10,
                  color: esPuntual ? _successColor : _warningColor,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    estado,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: esPuntual ? _successColor : _warningColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'No registrado',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GrupoMarcado {
  String materia;
  String paralelo;
  DateTime fecha;
  String? ubicacion;
  Marcado? entrada;
  Marcado? salida;

  GrupoMarcado({
    required this.materia,
    required this.paralelo,
    required this.fecha,
    this.ubicacion,
    this.entrada,
    this.salida,
  });
}
