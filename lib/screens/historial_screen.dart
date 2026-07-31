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

  // Filtros
  DateTime? _filtroFecha;
  int? _filtroMes;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  // ============================================
  // CARGA DE DATOS
  // ============================================
  Future<void> _cargarHistorial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _marcados = await _marcadoService.getHistorial(
        fecha: _filtroFecha,
        mes: _filtroMes,
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ============================================
  // FILTROS
  // ============================================
  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _filtroFecha ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );

    if (fecha != null) {
      setState(() {
        _filtroFecha = fecha;
        _filtroMes = null; // Limpiar filtro de mes
      });
      _cargarHistorial();
    }
  }

  Future<void> _seleccionarMes() async {
    final mes = await showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Seleccionar mes'),
          children: List.generate(12, (index) {
            final mesNum = index + 1;
            final mesNombre = DateFormat('MMMM', 'es').format(
              DateTime(2024, mesNum, 1),
            );
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(mesNum),
              child: Text(
                mesNombre[0].toUpperCase() + mesNombre.substring(1),
                style: const TextStyle(fontSize: 16),
              ),
            );
          }),
        );
      },
    );

    if (mes != null) {
      setState(() {
        _filtroMes = mes;
        _filtroFecha = null; // Limpiar filtro de fecha
      });
      _cargarHistorial();
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroFecha = null;
      _filtroMes = null;
    });
    _cargarHistorial();
  }

  // ============================================
  // UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Marcados'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filtros
          _buildFiltros(),
          // Contenido
          Expanded(child: _buildContenido()),
        ],
      ),
    );
  }

  // Widget de filtros
  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Filtro por fecha
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _seleccionarFecha,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                _filtroFecha != null
                    ? DateFormat('dd/MM/yyyy').format(_filtroFecha!)
                    : 'Por fecha',
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _filtroFecha != null ? Colors.blue : Colors.grey,
                side: BorderSide(
                  color: _filtroFecha != null ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filtro por mes
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _seleccionarMes,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                _filtroMes != null
                    ? DateFormat('MMMM', 'es').format(
                        DateTime(2024, _filtroMes!, 1),
                      )[0].toUpperCase() +
                        DateFormat('MMMM', 'es')
                            .format(DateTime(2024, _filtroMes!, 1))
                            .substring(1)
                    : 'Por mes',
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _filtroMes != null ? Colors.blue : Colors.grey,
                side: BorderSide(
                  color: _filtroMes != null ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ),
          // Limpiar filtros
          if (_filtroFecha != null || _filtroMes != null)
            IconButton(
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.clear, color: Colors.red),
              tooltip: 'Limpiar filtros',
            ),
        ],
      ),
    );
  }

  // Contenido principal
  Widget _buildContenido() {
    if (_isLoading) {
      return const LoadingIndicator(mensaje: 'Cargando historial...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarHistorial,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_marcados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron marcados',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_filtroFecha != null || _filtroMes != null)
              TextButton(
                onPressed: _limpiarFiltros,
                child: const Text('Limpiar filtros'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarHistorial,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _marcados.length,
        itemBuilder: (context, index) {
          return _buildMarcadoCard(_marcados[index]);
        },
      ),
    );
  }

  // Card de marcado individual
  Widget _buildMarcadoCard(Marcado marcado) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: marcado.tipo == 'entrada'
              ? Colors.green.shade100
              : Colors.red.shade100,
          child: Icon(
            marcado.tipo == 'entrada' ? Icons.login : Icons.logout,
            color: marcado.tipo == 'entrada' ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          marcado.materia,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paralelo: ${marcado.paralelo}'),
            Text(
              '${DateFormat('dd/MM/yyyy').format(marcado.fecha)} - ${marcado.hora}',
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Tipo de marcado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: marcado.tipo == 'entrada'
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                marcado.tipo == 'entrada' ? 'Entrada' : 'Salida',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: marcado.tipo == 'entrada' ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Estado (puntual/retraso)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: marcado.esPuntual
                    ? Colors.blue.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                marcado.estado,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: marcado.esPuntual ? Colors.blue : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}