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
  bool _isLoading = true;
  String? _error;

  DateTime? _filtroFecha;
  int? _filtroMes;

  // Controladores de scroll
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  // Constantes de diseño
  static const Color _primaryColor = Color(0xFF5B67CA);
  static const Color _secondaryColor = Color(0xFF8B95E0);
  static const Color _backgroundColor = Color(0xFFF8F9FC);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _warningColor = Color(0xFFFDCB6E);
  static const Color _dangerColor = Color(0xFFE17055);

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
        setState(() {
          _marcados = resultado;
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
            borderRadius: BorderRadius.circular(20),
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
                const SizedBox(height: 24),
                const Text(
                  'Seleccionar mes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
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
                    return Material(
                      color: _filtroMes == mesNum
                          ? _primaryColor
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(mesNum),
                        borderRadius: BorderRadius.circular(12),
                        child: Center(
                          child: Text(
                            mesNombre.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _filtroMes == mesNum
                                  ? Colors.white
                                  : _textPrimary,
                            ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historial',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _marcados.isNotEmpty
                    ? '${_marcados.length} registros'
                    : 'Sin registros',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: _primaryColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              icon: Icons.calendar_today_rounded,
              label: _filtroFecha != null
                  ? DateFormat('dd MMM').format(_filtroFecha!)
                  : 'Fecha',
              isActive: _filtroFecha != null,
              onPressed: _seleccionarFecha,
            ),
          ),
          const SizedBox(width: 8),
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
          if (_filtroFecha != null || _filtroMes != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _limpiarFiltros,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: _dangerColor.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
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
      borderRadius: BorderRadius.circular(16),
      elevation: isActive ? 4 : 0,
      shadowColor: _primaryColor.withOpacity(0.3),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? _primaryColor : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : _textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
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

    if (_marcados.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _cargarHistorial,
      color: _primaryColor,
      backgroundColor: Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _marcados.length,
        itemBuilder: (context, index) {
          final marcado = _marcados[index];
          return _buildMarcadoCard(marcado);
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
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
                fontSize: 20,
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
              TextButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Limpiar filtros'),
                style: TextButton.styleFrom(
                  foregroundColor: _primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarcadoCard(Marcado marcado) {
    final isEntrada = marcado.tipo == 'entrada';
    final Color color = isEntrada ? _successColor : _warningColor;
    final icon = isEntrada ? Icons.login_rounded : Icons.logout_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icono y tipo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marcado.materia,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Paralelo ${marcado.paralelo}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de tipo
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isEntrada ? 'Entrada' : 'Salida',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.grey.shade100,
            ),
            const SizedBox(height: 12),
            // Información adicional
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Fecha',
                    value: DateFormat('dd/MM/yyyy').format(marcado.fecha),
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.access_time_rounded,
                    label: 'Hora',
                    value: marcado.hora,
                  ),
                ),
                Expanded(
                  child: _buildEstadoAsistencia(marcado),
                ),
              ],
            ),
            // Ubicación (si existe)
            if (marcado.ubicacion != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      marcado.ubicacion!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEstadoAsistencia(Marcado marcado) {
    final Color color = marcado.esPuntual ? _successColor : _warningColor;
    final icon = marcado.esPuntual
        ? Icons.check_circle_rounded
        : Icons.warning_amber_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                marcado.estadoAsistencia,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
