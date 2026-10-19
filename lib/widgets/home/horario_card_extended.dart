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
  // static const Duration animation = Duration(milliseconds: 600);
  static const Duration animation = Duration(milliseconds: 900);
  static const Duration mapAnimation = Duration(milliseconds: 300);
  static const Duration entradaAntes = Duration(minutes: 30);
  static const Duration entradaDespues = Duration(minutes: 150);
  static const Duration salidaMargen = Duration(minutes: 30);
}

// ═══════════════════════════════════════════
// WIDGET PRINCIPAL
// ═══════════════════════════════════════════
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
  // ESTADO   // ─── Estado de tiempo ───
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

  // GPS
  LatLng? _currentLocation;
  double? _accuracy;
  bool _isInside = false;

  // Cache de horarios parseados
  DateTime? _horaInicio;
  DateTime? _horaFin;

  // Control de cambios
  int _lastStateHash = 0;

  static const bool _ubicacionHabilitada = true;
// ═══════════════════════════════════════════
  // CICLO DE VIDA
  // ═══════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: _Durations.animation,
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      if (!mounted) return;

      final loc = LatLng(position.latitude, position.longitude);
      bool inside = false;

      if (_centro != null) {
        if (_poligonoPuntos.isNotEmpty) {
          inside = _isPointInPolygon(loc, _poligonoPuntos);
        } else {
          final dist = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            _centro!.latitude,
            _centro!.longitude,
          );
          inside = dist < 150;
        }
      }

      setState(() {
        _currentLocation = loc;
        _accuracy = position.accuracy;
        _isInside = inside;
      });
    } catch (_) {
      // Silencioso
    }
  }

  // ============================================
  // GEOMETRÍA
  // ============================================
  bool _isPointInPolygon(LatLng p, List<LatLng> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if ((poly[i].longitude > p.longitude) !=
              (poly[j].longitude > p.longitude) &&
          (p.latitude <
              (poly[j].latitude - poly[i].latitude) *
                      (p.longitude - poly[i].longitude) /
                      (poly[j].longitude - poly[i].longitude) +
                  poly[i].latitude)) {
        inside = !inside;
      }
    }
    return inside;
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

    // 1) Polígono real
    if (widget.horario.tienePoligono) {
      _poligonoPuntos = _parsearPoligonoDesdeLista(widget.horario.poligono!);
      if (_poligonoPuntos.isNotEmpty) {
        _centro = _calcularCentroPoligono(_poligonoPuntos);
        _nombreLugar =
            widget.horario.ubicacionNombre ?? widget.horario.ubicacionDisplay;
        return;
      }
    }

    // 2) Coordenadas puntuales
    if (widget.horario.tieneCoordenadas) {
      _centro = LatLng(
        widget.horario.ubicacionLatitud!,
        widget.horario.ubicacionLongitud!,
      );
      _nombreLugar =
          widget.horario.ubicacionNombre ?? widget.horario.ubicacionDisplay;
      return;
    }

    // 3) Fallback texto "lat,lng,nombre"
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
          return;
        }
      } catch (_) {}
    }

    _nombreLugar = widget.horario.ubicacion ?? 'Sin ubicación';
  }

  List<LatLng> _parsearPoligonoDesdeLista(List<Map<String, double>> poligono) {
    return poligono
        .where((p) => p.containsKey('lat') && p.containsKey('lng'))
        .map((p) => LatLng(p['lat']!, p['lng']!))
        .toList();
  }

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
  // CÁLCULO DE TIEMPOS
  // ============================================
  void _calcularTiempos({bool force = false}) {
    if (_horaInicio == null || _horaFin == null) return;

    final ahora = DateTime.now();
    final inicio = _horaInicio!;
    final fin = _horaFin!;

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

    if (!widget.horario.yaMarcoEntrada && totalDuracion.inSeconds > 0) {
      nuevoProgreso =
          (ahora.difference(inicio).inSeconds / totalDuracion.inSeconds)
              .clamp(0.0, 1.0);
    } else if (widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida) {
      tiempoTrabajado = ahora.difference(inicio);
      nuevoProgreso = (ahora.difference(fin).inSeconds /
              const Duration(minutes: 30).inSeconds)
          .clamp(0.0, 1.0);
    } else if (widget.horario.estaCompletado) {
      nuevoProgreso = 1.0;
    }

    if (ahora.isBefore(inicio)) {
      tiempoRestanteEntrada = inicio.difference(ahora);
    } else if (ahora.isAfter(inicio) && !widget.horario.yaMarcoEntrada) {
      tiempoRetrasoEntrada = ahora.difference(inicio);
    }

    puedeMarcarEntrada = !widget.horario.yaMarcoEntrada &&
        ahora.isAfter(inicio.subtract(_Durations.entradaAntes)) &&
        ahora.isBefore(inicio.add(_Durations.entradaDespues));

    mostrarTemporizadorSalida =
        widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida;

    if (mostrarTemporizadorSalida) {
      if (ahora.isBefore(fin)) {
        tiempoRestanteSalida = fin.difference(ahora);
      } else if (ahora.isAfter(fin)) {
        tiempoRetrasoSalida = ahora.difference(fin);
      }
    }

    puedeMarcarSalida = widget.horario.yaMarcoEntrada &&
        !widget.horario.yaMarcoSalida &&
        ahora.isAfter(fin.subtract(_Durations.salidaMargen)) &&
        ahora.isBefore(fin.add(_Durations.salidaMargen));

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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(),
                if (_ubicacionHabilitada) _buildMapaWidget(),
                _buildProgressBar(),
                _buildEstado(),
                if (_mostrarTemporizadorSalida) _buildEstadoSalidaDetallado(),
                if (_tiempoTrabajado.inMinutes > 0) _buildTiempoTrabajado(),
                const SizedBox(height: 12),
                _buildBotones(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // HEADER con gradiente y estado
  Widget _buildHeader() {
    final color = _getColorHeader();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.82)],
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Paralelo ${widget.horario.paralelo} • ${widget.horario.horaInicio} - ${widget.horario.horaFin}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildBadge(),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _AppColors.lightGray,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            CupertinoIcons.clock,
            size: 12,
            color: _AppColors.gray,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${widget.horario.horaInicio} - ${widget.horario.horaFin}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (_ubicacionHabilitada && _nombreLugar != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _handleUbicacionTap,
              child: Row(
                children: [
                  Icon(
                    _mostrarMapa
                        ? CupertinoIcons.location_slash_fill
                        : CupertinoIcons.location_fill,
                    size: 12,
                    color: _tieneUbicacion ? _AppColors.blue : _AppColors.gray,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _nombreLugar!,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            _tieneUbicacion ? _AppColors.blue : _AppColors.gray,
                        fontWeight: FontWeight.w600,
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
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _AppColors.border,
                        width: 0.5,
                      ),
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
                          circles: _buildCircles(),
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
                const SizedBox(height: 6),
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
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: _AppColors.blue),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
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
            _isInside ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
          ),
          flat: true,
        ),
      );
    }
    return markers;
  }

  Set<Polygon> _buildPolygons() {
    if (_poligonoPuntos.isEmpty) return {};
    final color = _isInside ? _AppColors.green : _AppColors.blue;
    return {
      Polygon(
        polygonId: const PolygonId('geocerca'),
        points: _poligonoPuntos,
        fillColor: color.withOpacity(0.12),
        strokeColor: color,
        strokeWidth: _isInside ? 3 : 2,
      ),
    };
  }

  Set<Circle> _buildCircles() {
    if (_currentLocation == null || _accuracy == null) return {};
    final color = _isInside ? _AppColors.green : _AppColors.blue;
    return {
      Circle(
        circleId: const CircleId('accuracy'),
        center: _currentLocation!,
        radius: _accuracy!,
        fillColor: color.withOpacity(0.15),
        strokeColor: color.withOpacity(0.3),
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      final loc = LatLng(position.latitude, position.longitude);
      bool inside = false;
      if (_centro != null) {
        if (_poligonoPuntos.isNotEmpty) {
          inside = _isPointInPolygon(loc, _poligonoPuntos);
        } else {
          final dist = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            _centro!.latitude,
            _centro!.longitude,
          );
          inside = dist < 150;
        }
      }
      setState(() {
        _currentLocation = loc;
        _accuracy = position.accuracy;
        _isInside = inside;
      });
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: loc, zoom: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isInside
                ? CupertinoIcons.checkmark_shield_fill
                : CupertinoIcons.location_fill,
            color: _isInside ? _AppColors.green : _AppColors.blue,
            size: 12,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _isInside
                  ? 'Dentro del área'
                  : 'Fuera del área • ${distancia.toStringAsFixed(2)} km',
              style: TextStyle(
                color: _isInside ? _AppColors.green : _AppColors.blue,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.access_time, color: _AppColors.gray, size: 12),
          const SizedBox(width: 3),
          Text(
            tiempo,
            style: const TextStyle(
              color: _AppColors.gray,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double _calcularDistancia(LatLng inicio, LatLng destino) {
    const double r = 6371;
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
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _progressAnim.value,
              minHeight: 4,
              backgroundColor: _AppColors.lightGray,
              valueColor: AlwaysStoppedAnimation<Color>(
                _progreso > 0.9 ? _AppColors.green : _AppColors.blue,
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
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          if (!widget.horario.yaMarcoEntrada)
            _buildEstadoPill(
              _getColorEstadoEntrada(),
              _getTextoEntrada(),
              CupertinoIcons.timer_fill,
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
      padding: const EdgeInsets.only(top: 8),
      child: _buildGlassContainer(
        color: color,
        child: Row(
          children: [
            Icon(icono, color: color, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10,
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
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
      horizontal: 12,
      vertical: 8,
    ),
    bool showAccentBar = false,
    double radius = 12,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          // Sombra tintada con el color de acento (muy sutil)
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          // Sombra neutra para profundidad
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              // Gradiente diagonal sutil en vez de color plano
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.14),
                  color.withOpacity(0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: color.withOpacity(0.18),
                width: 0.8,
              ),
            ),
            child: Stack(
              children: [
                // Highlight superior tipo "luz" (efecto cristal premium)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.55),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Barra lateral de acento opcional
                if (showAccentBar)
                  Positioned(
                    left: 0,
                    top: 6,
                    bottom: 6,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    left: showAccentBar ? 8 : 0,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTiempoTrabajado() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.stopwatch_fill,
            size: 12,
            color: _AppColors.green,
          ),
          const SizedBox(width: 6),
          Text(
            'Trabajado: ${_formatearTiempoCorto(_tiempoTrabajado)}',
            style: const TextStyle(
              fontSize: 12,
              color: _AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletado() {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: _buildGlassContainer(
        color: const Color.fromARGB(255, 52, 199, 76),
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 52, 199, 91),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.checkmark_alt,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asistencia completada',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.green,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Jornada finalizada correctamente',
                    style: TextStyle(
                      fontSize: 11,
                      color: _AppColors.green,
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
              CupertinoIcons.arrow_right_circle_fill,
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
              CupertinoIcons.arrow_left_circle_fill,
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
    final bool activo = habilitado && !_isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // Sombra solo cuando está activo → da sensación de "levitación"
        boxShadow: activo
            ? [
                BoxShadow(
                  color: color.withOpacity(0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: activo ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withOpacity(0.20),
          highlightColor: Colors.white.withOpacity(0.08),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              // Gradiente diagonal para dar volumen
              gradient: activo
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(color, Colors.white, 0.15)!,
                        color,
                        Color.lerp(color, Colors.black, 0.08)!,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    )
                  : LinearGradient(
                      colors: [
                        _AppColors.lightGray,
                        _AppColors.lightGray.withOpacity(0.9),
                      ],
                    ),
              // Borde con highlight superior (efecto "cristal")
              border: Border.all(
                color: activo
                    ? Colors.white.withOpacity(0.18)
                    : _AppColors.border.withOpacity(0.6),
                width: 0.8,
              ),
            ),
            child: Stack(
              children: [
                // Highlight superior tipo luz
                if (activo)
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.6),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Contenido centrado
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isLoading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(
                                habilitado ? Colors.white : _AppColors.gray,
                              ),
                            ),
                          )
                        : Row(
                            key: const ValueKey('content'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: activo ? Colors.white : _AppColors.gray,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                texto,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                  color:
                                      activo ? Colors.white : _AppColors.gray,
                                ),
                              ),
                            ],
                          ),
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
