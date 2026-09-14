import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/horario.dart';
import 'full_screen_map_page.dart';

// ============================================
// CONSTANTES CENTRALIZADAS
// ============================================
class _AppColors {
  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color red = Color(0xFFFF3B30);
  static const Color gray = Color(0xFF8E8E93);
  static const Color lightGray = Color(0xFFF2F2F7);
  static const Color darkGray = Color(0xFF6C6C70);
  static const Color border = Color(0xFFE5E5EA);
}

class _Durations {
  static const Duration tick = Duration(seconds: 1);
  static const Duration animation = Duration(milliseconds: 600);
  static const Duration mapAnimation = Duration(milliseconds: 300);
  static const Duration entradaAntes = Duration(minutes: 30);
  static const Duration entradaDespues = Duration(minutes: 150);
  static const Duration salidaMargen = Duration(minutes: 30);
  static const Duration proximoSalir = Duration(minutes: 30);
  static const Duration preparandoSalida = Duration(minutes: 10);
  static const Duration salidaInminente = Duration(minutes: 5);
}

class HorarioCardExtended extends StatefulWidget {
  final Horario horario;
  final VoidCallback onMarcarEntrada;
  final VoidCallback onMarcarSalida;

  const HorarioCardExtended({
    super.key,
    required this.horario,
    required this.onMarcarEntrada,
    required this.onMarcarSalida,
  });

  @override
  State<HorarioCardExtended> createState() => _HorarioCardExtendedState();
}

class _HorarioCardExtendedState extends State<HorarioCardExtended>
    with SingleTickerProviderStateMixin {
  // ============================================
  // ESTADO
  // ============================================
  Timer? _timer;
  late final AnimationController _animController;
  late Animation<double> _progressAnim;

  // Tiempos
  Duration _tiempoRestanteEntrada = Duration.zero;
  Duration _tiempoRetrasoEntrada = Duration.zero;
  Duration _tiempoTrabajado = Duration.zero;
  Duration _tiempoRestanteSalida = Duration.zero;
  Duration _tiempoRetrasoSalida = Duration.zero;
  bool _puedeMarcarEntrada = false;
  bool _puedeMarcarSalida = false;
  bool _mostrarTemporizadorSalida = false;
  double _progreso = 0.0;

  // UI
  bool _mostrarMapa = false;
  bool _isLoading = false;

  // Mapa
  GoogleMapController? _mapController;
  List<LatLng> _poligonoPuntos = [];
  LatLng? _centro;
  String? _nombreLugar;
  LatLng? _currentLocation;

  // Cache de horarios parseados
  DateTime? _horaInicio;
  DateTime? _horaFin;

  // Control de cambios para evitar rebuilds innecesarios
  int _lastStateHash = 0;

  static const bool _ubicacionHabilitada = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: _Durations.animation,
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _parsearCoordenadas();
    _calcularHorasBase();
    _calcularTiempos(force: true);
    _initUbicacion();

    _timer = Timer.periodic(_Durations.tick, (_) => _calcularTiempos());
  }

  // ============================================
  // INICIALIZACIÓN
  // ============================================
  Future<void> _initUbicacion() async {
    if (!_ubicacionHabilitada) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // Silencioso: ubicación es opcional
    }
  }

  void _calcularHorasBase() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    try {
      final inicioParts = widget.horario.horaInicio.split(':');
      final finParts = widget.horario.horaFin.split(':');

      _horaInicio = DateTime(
        hoy.year,
        hoy.month,
        hoy.day,
        int.parse(inicioParts[0]),
        int.parse(inicioParts[1]),
      );
      _horaFin = DateTime(
        hoy.year,
        hoy.month,
        hoy.day,
        int.parse(finParts[0]),
        int.parse(finParts[1]),
      );
    } catch (e) {
      debugPrint('Error parseando horas: $e');
      _horaInicio = null;
      _horaFin = null;
    }
  }

  void _parsearCoordenadas() {
    _poligonoPuntos = [];
    _centro = null;

    if (!_ubicacionHabilitada) {
      _nombreLugar = widget.horario.ubicacion ?? 'Sin ubicación';
      return;
    }

    if (widget.horario.tienePoligono) {
      _poligonoPuntos = _parsearPoligonoDesdeLista(widget.horario.poligono!);
      if (_poligonoPuntos.isNotEmpty) {
        _centro = _calcularCentroPoligono(_poligonoPuntos);
        _nombreLugar =
            widget.horario.ubicacionNombre ?? widget.horario.ubicacionDisplay;
        return;
      }
    }

    if (widget.horario.tieneCoordenadas) {
      _centro = LatLng(
        widget.horario.ubicacionLatitud!,
        widget.horario.ubicacionLongitud!,
      );
      _nombreLugar =
          widget.horario.ubicacionNombre ?? widget.horario.ubicacionDisplay;
      _poligonoPuntos = _crearPoligonoDesdePunto(_centro!, 0.0005);
      return;
    }

    final ubicacion = widget.horario.ubicacion;
    if (ubicacion != null && ubicacion.contains(',')) {
      try {
        final partes = ubicacion.split(',');
        if (partes.length >= 2) {
          final lat = double.parse(partes[0].trim());
          final lng = double.parse(partes[1].trim());
          _centro = LatLng(lat, lng);
          _nombreLugar = partes.length >= 3
              ? partes.sublist(2).join(',').trim()
              : 'Ubicación';
          _poligonoPuntos = _crearPoligonoDesdePunto(_centro!, 0.0005);
          return;
        }
      } catch (_) {
        // Ignorar
      }
    }

    _nombreLugar = widget.horario.ubicacion ?? 'Sin ubicación';
  }

  List<LatLng> _parsearPoligonoDesdeLista(List<Map<String, double>> poligono) {
    return poligono
        .where((p) => p.containsKey('lat') && p.containsKey('lng'))
        .map((p) => LatLng(p['lat']!, p['lng']!))
        .toList();
  }

  List<LatLng> _crearPoligonoDesdePunto(LatLng centro, double radio) => [
        LatLng(centro.latitude - radio, centro.longitude - radio),
        LatLng(centro.latitude - radio, centro.longitude + radio),
        LatLng(centro.latitude + radio, centro.longitude + radio),
        LatLng(centro.latitude + radio, centro.longitude - radio),
      ];

  LatLng _calcularCentroPoligono(List<LatLng> puntos) {
    if (puntos.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in puntos) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / puntos.length, lng / puntos.length);
  }

  // ============================================
  // CÁLCULO DE TIEMPOS (OPTIMIZADO)
  // ============================================
  void _calcularTiempos({bool force = false}) {
    if (_horaInicio == null || _horaFin == null) return;

    final ahora = DateTime.now();
    final inicio = _horaInicio!;
    final fin = _horaFin!;

    // Calcular todos los valores localmente primero
    Duration tiempoRestanteEntrada = Duration.zero;
    Duration tiempoRetrasoEntrada = Duration.zero;
    Duration tiempoTrabajado = Duration.zero;
    Duration tiempoRestanteSalida = Duration.zero;
    Duration tiempoRetrasoSalida = Duration.zero;
    bool puedeMarcarEntrada = false;
    bool puedeMarcarSalida = false;
    bool mostrarTemporizadorSalida = false;
    double nuevoProgreso = 0.0;

    final totalDuracion = fin.difference(inicio);

    // Progreso y tiempo trabajado
    if (!widget.horario.yaMarcoEntrada && totalDuracion.inSeconds > 0) {
      nuevoProgreso =
          (ahora.difference(inicio).inSeconds / totalDuracion.inSeconds)
              .clamp(0.0, 1.0);
    } else if (widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida) {
      // Horario no expone una hora real de entrada; usar la hora programada.
      tiempoTrabajado = ahora.difference(inicio);
      nuevoProgreso = (ahora.difference(fin).inSeconds /
              const Duration(minutes: 30).inSeconds)
          .clamp(0.0, 1.0);
    } else if (widget.horario.estaCompletado) {
      nuevoProgreso = 1.0;
    }

    // Entrada
    if (ahora.isBefore(inicio)) {
      tiempoRestanteEntrada = inicio.difference(ahora);
    } else if (ahora.isAfter(inicio) && !widget.horario.yaMarcoEntrada) {
      tiempoRetrasoEntrada = ahora.difference(inicio);
    }

    final entradaAntes = inicio.subtract(_Durations.entradaAntes);
    final entradaDespues = inicio.add(_Durations.entradaDespues);
    puedeMarcarEntrada = !widget.horario.yaMarcoEntrada &&
        ahora.isAfter(entradaAntes) &&
        ahora.isBefore(entradaDespues);

    // Salida
    mostrarTemporizadorSalida =
        widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida;

    if (mostrarTemporizadorSalida) {
      if (ahora.isBefore(fin)) {
        tiempoRestanteSalida = fin.difference(ahora);
      } else if (ahora.isAfter(fin)) {
        tiempoRetrasoSalida = ahora.difference(fin);
      }
    }

    final salidaAntes = fin.subtract(_Durations.salidaMargen);
    final salidaDespues = fin.add(_Durations.salidaMargen);
    puedeMarcarSalida = widget.horario.yaMarcoEntrada &&
        !widget.horario.yaMarcoSalida &&
        ahora.isAfter(salidaAntes) &&
        ahora.isBefore(salidaDespues);

    // Hash para detectar cambios reales (evita rebuilds innecesarios)
    final newHash = Object.hash(
      tiempoRestanteEntrada.inSeconds,
      tiempoRetrasoEntrada.inSeconds,
      tiempoTrabajado.inSeconds,
      tiempoRestanteSalida.inSeconds,
      tiempoRetrasoSalida.inSeconds,
      puedeMarcarEntrada,
      puedeMarcarSalida,
      mostrarTemporizadorSalida,
      nuevoProgreso.toStringAsFixed(3),
    );

    if (!force && newHash == _lastStateHash) return;
    _lastStateHash = newHash;

    // Animación del progreso (sin reiniciar si no cambió)
    if ((nuevoProgreso - _progreso).abs() > 0.001) {
      _progressAnim = Tween<double>(begin: _progreso, end: nuevoProgreso)
          .animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ));
      _animController.forward(from: 0);
    }

    if (!mounted) return;

    setState(() {
      _progreso = nuevoProgreso;
      _tiempoTrabajado = tiempoTrabajado;
      _tiempoRestanteEntrada = tiempoRestanteEntrada;
      _tiempoRetrasoEntrada = tiempoRetrasoEntrada;
      _puedeMarcarEntrada = puedeMarcarEntrada;
      _tiempoRestanteSalida = tiempoRestanteSalida;
      _tiempoRetrasoSalida = tiempoRetrasoSalida;
      _puedeMarcarSalida = puedeMarcarSalida;
      _mostrarTemporizadorSalida = mostrarTemporizadorSalida;
    });
  }

  @override
  void didUpdateWidget(covariant HorarioCardExtended oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.horario != widget.horario) {
      _parsearCoordenadas();
      _calcularHorasBase();
      _calcularTiempos(force: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ============================================
  // FORMATEADORES
  // ============================================
  String _formatearTiempo(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h == '00' ? '$m:$s' : '$h:$m:$s';
  }

  String _formatearTiempoCorto(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (d.inHours > 0) return '${d.inHours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  // ============================================
  // COLORES DE ESTADO
  // ============================================
  Color _getColorEstadoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0) {
      return _tiempoRetrasoEntrada.inMinutes < 5
          ? _AppColors.orange
          : _AppColors.red;
    }
    return _tiempoRestanteEntrada.inMinutes > 0
        ? _AppColors.blue
        : _AppColors.green;
  }

  String _getTextoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0) {
      return 'Retraso: ${_formatearTiempoCorto(_tiempoRetrasoEntrada)}';
    }
    if (_tiempoRestanteEntrada.inSeconds > 0) {
      return 'Entrada en: ${_formatearTiempoCorto(_tiempoRestanteEntrada)}';
    }
    if (widget.horario.yaMarcoEntrada) return 'Entrada OK';
    return 'Esperando entrada';
  }

  Color _getColorEstadoSalidaDetallado() {
    if (widget.horario.yaMarcoSalida) return _AppColors.green;
    if (_tiempoRestanteSalida.inSeconds > 0) {
      final m = _tiempoRestanteSalida.inMinutes;
      if (m > 10) return _AppColors.blue;
      if (m > 5) return _AppColors.orange;
      return _AppColors.red;
    }
    if (_tiempoRetrasoSalida.inMinutes > 0) return _AppColors.red;
    return _AppColors.gray;
  }

  String _getEstadoSalidaDetallado() {
    if (widget.horario.yaMarcoSalida) return 'Salida completada';
    if (_tiempoRestanteSalida.inSeconds > 0) {
      final m = _tiempoRestanteSalida.inMinutes;
      if (m > 30) return 'Salida programada';
      if (m > 10) return 'Próximo a salir ($m min)';
      if (m > 5) return 'Preparando salida ($m min)';
      return '¡Salida inminente! ${_formatearTiempoCorto(_tiempoRestanteSalida)}';
    }
    if (_tiempoRetrasoSalida.inMinutes > 0) return 'Salida con retraso';
    return 'Esperando salida';
  }

  IconData _getIconoEstadoSalida() {
    if (widget.horario.yaMarcoSalida) {
      return CupertinoIcons.checkmark_circle_fill;
    }
    if (_tiempoRestanteSalida.inSeconds > 0) {
      final m = _tiempoRestanteSalida.inMinutes;
      if (m > 10) return CupertinoIcons.clock;
      if (m > 5) return CupertinoIcons.hourglass;
      return CupertinoIcons.alarm;
    }
    if (_tiempoRetrasoSalida.inMinutes > 0) {
      return CupertinoIcons.exclamationmark_triangle_fill;
    }
    return CupertinoIcons.clock;
  }

  Color _getColorHeader() {
    if (widget.horario.estaCompletado) return _AppColors.green;
    if (widget.horario.yaMarcoEntrada) return _AppColors.orange;
    return _AppColors.blue;
  }

  bool get _tieneUbicacion => _poligonoPuntos.isNotEmpty || _centro != null;

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(),
                if (_ubicacionHabilitada) _buildMapaWidget(),
                _buildProgressBar(),
                _buildEstado(),
                if (_mostrarTemporizadorSalida) _buildEstadoSalidaDetallado(),
                if (_tiempoTrabajado.inMinutes > 0) _buildTiempoTrabajado(),
                const SizedBox(height: 10),
                _buildBotones(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final color = _getColorHeader();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.horario.materia,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paralelo ${widget.horario.paralelo}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              _buildBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    String texto = 'Pendiente';
    if (widget.horario.estaCompletado) {
      texto = 'Completado';
    } else if (widget.horario.yaMarcoEntrada) {
      texto = 'En curso';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        Icon(CupertinoIcons.clock, size: 13, color: _AppColors.gray),
        const SizedBox(width: 4),
        Text(
          '${widget.horario.horaInicio} - ${widget.horario.horaFin}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        if (_ubicacionHabilitada && _nombreLugar != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _handleUbicacionTap,
              child: Row(
                children: [
                  Icon(
                    _mostrarMapa
                        ? CupertinoIcons.location_slash
                        : CupertinoIcons.location,
                    size: 12,
                    color: _tieneUbicacion ? _AppColors.blue : _AppColors.gray,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      _nombreLugar!,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            _tieneUbicacion ? _AppColors.blue : _AppColors.gray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_tieneUbicacion)
                    Icon(
                      _mostrarMapa
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 10,
                      color: _AppColors.blue,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleUbicacionTap() {
    HapticFeedback.lightImpact();
    if (_tieneUbicacion) {
      setState(() => _mostrarMapa = !_mostrarMapa);
    } else {
      _showSnack('No hay coordenadas disponibles para esta ubicación');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ============================================
  // MAPA
  // ============================================
  Widget _buildMapaWidget() {
    if (!_tieneUbicacion) return const SizedBox.shrink();

    final LatLng target = _poligonoPuntos.isNotEmpty
        ? _calcularCentroPoligono(_poligonoPuntos)
        : _centro!;

    return AnimatedSize(
      duration: _Durations.mapAnimation,
      curve: Curves.easeInOut,
      child: _mostrarMapa
          ? Column(
              children: [
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: target,
                            zoom: 16,
                          ),
                          markers: _buildMarkers(target),
                          polygons: _buildPolygons(),
                          polylines: _buildPolylines(target),
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          myLocationButtonEnabled: false,
                          compassEnabled: true,
                          indoorViewEnabled: false,
                          trafficEnabled: false,
                          buildingsEnabled: true,
                          padding: const EdgeInsets.all(4),
                          onMapCreated: (c) => _mapController = c,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Column(
                            children: [
                              _buildMapControlButton(
                                icon: Icons.add,
                                onTap: () => _zoomMap(1.0),
                              ),
                              const SizedBox(height: 4),
                              _buildMapControlButton(
                                icon: Icons.remove,
                                onTap: () => _zoomMap(-1.0),
                              ),
                              const SizedBox(height: 4),
                              _buildMapControlButton(
                                icon: Icons.my_location,
                                onTap: _goToMyLocation,
                              ),
                              const SizedBox(height: 4),
                              _buildMapControlButton(
                                icon: Icons.fullscreen,
                                onTap: _toggleFullMap,
                              ),
                            ],
                          ),
                        ),
                        if (_currentLocation != null)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: _buildRouteInfo(target),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.directions,
                        label: 'Ruta',
                        onTap: () => _showRouteToLocation(target),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.center_focus_strong,
                        label: 'Centrar',
                        onTap: () => _centerMap(target),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.zoom_out_map,
                        label: 'Ajustar',
                        onTap: () => _fitMapToPolygon(target),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: _AppColors.blue),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _AppColors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers(LatLng target) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('destino'),
        position: target,
        infoWindow: InfoWindow(
          title: _nombreLugar ?? 'Ubicación',
          snippet: 'Lugar de marcado',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
      ),
    };

    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('mi_ubicacion'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(
            title: 'Mi ubicación',
            snippet: 'Tu ubicación actual',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          flat: true,
        ),
      );
    }
    return markers;
  }

  Set<Polygon> _buildPolygons() {
    if (_poligonoPuntos.isEmpty && _centro == null) return {};

    final puntos = _poligonoPuntos.isNotEmpty
        ? _poligonoPuntos
        : _crearPoligonoDesdePunto(_centro!, 0.0005);

    return {
      Polygon(
        polygonId: const PolygonId('geocerca'),
        points: puntos,
        fillColor: _AppColors.blue.withOpacity(0.1),
        strokeColor: _AppColors.blue,
        strokeWidth: 1,
      ),
    };
  }

  Set<Polyline> _buildPolylines(LatLng target) {
    if (_currentLocation == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('ruta'),
        points: [_currentLocation!, target],
        color: _AppColors.blue,
        width: 2,
        patterns: [PatternItem.dash(10), PatternItem.gap(5)],
      ),
    };
  }

  // ============================================
  // ACCIONES DEL MAPA
  // ============================================
  void _zoomMap(double delta) {
    _mapController?.animateCamera(CameraUpdate.zoomBy(delta));
  }

  Future<void> _goToMyLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 16),
        ),
      );
    } catch (_) {
      _showSnack('No se pudo obtener tu ubicación');
    }
  }

  void _centerMap(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 16),
      ),
    );
  }

  void _fitMapToPolygon(LatLng target) {
    if (_poligonoPuntos.isNotEmpty) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          _getBoundsFromPoints(_poligonoPuntos),
          40,
        ),
      );
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 15),
        ),
      );
    }
  }

  LatLngBounds _getBoundsFromPoints(List<LatLng> puntos) {
    double minLat = puntos.first.latitude;
    double maxLat = puntos.first.latitude;
    double minLng = puntos.first.longitude;
    double maxLng = puntos.first.longitude;

    for (final p in puntos) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _toggleFullMap() {
    if (_centro == null) return;

    HapticFeedback.lightImpact();

    final center = _centro!;

    Navigator.of(context)
        .push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenMapPage(
          center: center,
          markers: _buildMarkers(center),
          polygons: _buildPolygons(),
          polylines: _buildPolylines(center),
          nombreLugar: _nombreLugar ?? 'Ubicación',
          geocercaPuntos: _poligonoPuntos.isNotEmpty ? _poligonoPuntos : null,
        ),
      ),
    )
        .catchError((Object e) {
      _showSnack('No se pudo abrir el mapa completo');
      debugPrint('Error abriendo mapa fullscreen: $e');
    });
  }

  // ============================================
  // INFORMACIÓN DE RUTA
  // ============================================
  Widget _buildRouteInfo(LatLng target) {
    if (_currentLocation == null) return const SizedBox.shrink();

    final distancia = _calcularDistancia(_currentLocation!, target);
    final tiempo = _calcularTiempoEstimado(distancia);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_walk, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            '${distancia.toStringAsFixed(1)} km',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.access_time, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            tiempo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _AppColors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'A pie',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calcularDistancia(LatLng inicio, LatLng destino) {
    const double r = 6371; // Radio de la Tierra en km
    final dLat = _toRadians(destino.latitude - inicio.latitude);
    final dLng = _toRadians(destino.longitude - inicio.longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(inicio.latitude)) *
            math.cos(_toRadians(destino.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  String _calcularTiempoEstimado(double distanciaKm) {
    final minutos = (distanciaKm / 5 * 60).round();
    if (minutos < 1) return 'Menos de 1 min';
    if (minutos < 60) return '$minutos min';
    final horas = (minutos / 60).floor();
    final mins = minutos % 60;
    return mins > 0 ? '${horas}h ${mins}min' : '${horas}h';
  }

  Future<void> _showRouteToLocation(LatLng target) async {
    if (_currentLocation == null) {
      await _goToMyLocation();
      if (_currentLocation == null) return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/${_currentLocation!.latitude},${_currentLocation!.longitude}/${target.latitude},${target.longitude}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showSnack('No se pudo abrir Google Maps');
      }
    } catch (_) {
      _showSnack('Error al abrir la ruta');
    }
  }

  // ============================================
  // COMPONENTES DE ESTADO
  // ============================================
  Widget _buildProgressBar() {
    if (widget.horario.estaCompletado) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _progressAnim.value,
              minHeight: 2.5,
              backgroundColor: _AppColors.lightGray,
              valueColor: AlwaysStoppedAnimation<Color>(
                _progreso > 0.8
                    ? const Color.fromARGB(255, 227, 236, 229)
                    : _AppColors.blue,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEstado() {
    if (widget.horario.estaCompletado) return _buildCompletado();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          if (!widget.horario.yaMarcoEntrada)
            _buildEstadoPill(
              _getColorEstadoEntrada(),
              _getTextoEntrada(),
              CupertinoIcons.timer,
            ),
        ],
      ),
    );
  }

  Widget _buildEstadoSalidaDetallado() {
    if (!_mostrarTemporizadorSalida) return const SizedBox.shrink();

    final color = _getColorEstadoSalidaDetallado();
    final texto = _getEstadoSalidaDetallado();
    final icono = _getIconoEstadoSalida();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: _buildGlassContainer(
        color: color,
        child: Row(
          children: [
            Icon(icono, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (_tiempoRestanteSalida.inSeconds > 0 &&
                _tiempoRestanteSalida.inMinutes <= 10)
              _buildBadgeSmall(
                _formatearTiempoCorto(_tiempoRestanteSalida),
                color,
              ),
            if (_tiempoRetrasoSalida.inMinutes > 0)
              _buildBadgeSmall(
                  '${_tiempoRetrasoSalida.inMinutes} min', _AppColors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeSmall(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildEstadoPill(Color color, String texto, IconData icon) {
    return _buildGlassContainer(
      color: color,
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({
    required Color color,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 7,
    ),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTiempoTrabajado() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(CupertinoIcons.stopwatch, size: 12, color: _AppColors.green),
          const SizedBox(width: 4),
          Text(
            'Trabajado: ${_formatearTiempoCorto(_tiempoTrabajado)}',
            style: const TextStyle(
              fontSize: 11,
              color: _AppColors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletado() {
    return _buildGlassContainer(
      color: _AppColors.green,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(CupertinoIcons.checkmark_circle_fill,
              color: _AppColors.green, size: 14),
          const SizedBox(width: 6),
          const Text(
            'Asistencia completada',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // BOTONES
  // ============================================
  Widget _buildBotones() {
    if (widget.horario.estaCompletado) return const SizedBox.shrink();

    final mostrarEntrada = !widget.horario.yaMarcoEntrada;
    final mostrarSalida =
        widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida;

    return Row(
      children: [
        if (mostrarEntrada)
          Expanded(
            child: _buildBoton(
              'Marcar Entrada',
              CupertinoIcons.arrow_right_to_line_alt,
              _AppColors.blue,
              _puedeMarcarEntrada,
              _handleMarcarEntrada,
            ),
          ),
        if (mostrarEntrada && mostrarSalida) const SizedBox(width: 8),
        if (mostrarSalida)
          Expanded(
            child: _buildBoton(
              'Marcar Salida',
              CupertinoIcons.arrow_left_to_line_alt,
              _AppColors.red,
              _puedeMarcarSalida,
              _handleMarcarSalida,
            ),
          ),
      ],
    );
  }

  Widget _buildBoton(
    String texto,
    IconData icon,
    Color color,
    bool habilitado,
    VoidCallback onTap,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: habilitado ? color : _AppColors.lightGray,
        child: InkWell(
          onTap: habilitado && !_isLoading ? onTap : null,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: habilitado ? Colors.white : _AppColors.gray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        texto,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: habilitado ? Colors.white : _AppColors.gray,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMarcarEntrada() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    widget.onMarcarEntrada();
    setState(() => _isLoading = false);
  }

  Future<void> _handleMarcarSalida() async {
    HapticFeedback.mediumImpact();
    _mostrarDialogoSalida(context);
  }

  void _mostrarDialogoSalida(BuildContext context) {
    final ahora = DateTime.now();
    final fin = _horaFin;

    if (fin == null) return;

    final minutosDiferencia = ahora.difference(fin).inMinutes;

    String titulo;
    String mensaje;

    if (minutosDiferencia < 0) {
      titulo = 'Salida Anticipada';
      mensaje =
          'Está saliendo ${minutosDiferencia.abs()} min antes de lo programado.';
    } else if (minutosDiferencia <= 15) {
      titulo = 'Salida en Horario';
      mensaje = 'Está saliendo dentro del horario establecido.';
    } else {
      titulo = 'Salida Tardía';
      mensaje =
          'Está saliendo $minutosDiferencia min después de lo programado.';
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Column(
          children: [
            Text(mensaje),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _AppColors.lightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRowIOS('Materia', widget.horario.materia),
                  _buildInfoRowIOS('Paralelo', widget.horario.paralelo),
                  _buildInfoRowIOS('Hora salida', widget.horario.horaFin),
                  _buildInfoRowIOS(
                      'Hora actual', DateFormat('HH:mm').format(ahora)),
                  if (minutosDiferencia.abs() > 0)
                    _buildInfoRowIOS(
                      'Diferencia',
                      '${minutosDiferencia.abs()} min ${minutosDiferencia > 0 ? 'después' : 'antes'}',
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              widget.onMarcarSalida();
            },
            isDestructiveAction: minutosDiferencia > 15,
            child: Text(
              'Confirmar',
              style: TextStyle(
                color:
                    minutosDiferencia > 15 ? _AppColors.red : _AppColors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowIOS(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: _AppColors.gray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
