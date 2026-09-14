import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/horario.dart';
import 'full_screen_map_page.dart';

class _AppColors {
  static const blue = Color(0xFF007AFF);
  static const green = Color(0xFF34C759);
  static const orange = Color(0xFFFF9500);
  static const red = Color(0xFFFF3B30);
  static const gray = Color(0xFF8E8E93);
  static const lightGray = Color(0xFFF2F2F7);
  static const border = Color(0xFFE5E5EA);
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
  Timer? _timer;
  late final AnimationController _animController;
  late Animation<double> _progressAnim;
  GoogleMapController? _mapController;

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
  int _lastHash = 0;

  // Mapa + GPS mejorado
  List<LatLng> _poligonoPuntos = [];
  LatLng? _centro;
  LatLng? _currentLocation;
  double? _accuracy;
  String? _nombreLugar;
  DateTime? _horaInicio;
  DateTime? _horaFin;
  bool _isInside = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _parsearCoordenadas();
    _calcularHorasBase();
    _calcularTiempos(force: true);
    _initUbicacion();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _calcularTiempos());
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

  Future<void> _initUbicacion() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _accuracy = pos.accuracy;
        if (_centro != null) {
          final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude,
              _centro!.latitude, _centro!.longitude);
          _isInside = _poligonoPuntos.isNotEmpty
              ? _isPointInPolygon(_currentLocation!, _poligonoPuntos)
              : dist < 150;
        }
      });
    } catch (_) {}
  }

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
    try {
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      final hi = widget.horario.horaInicio.split(':');
      final hf = widget.horario.horaFin.split(':');
      _horaInicio = DateTime(
          hoy.year, hoy.month, hoy.day, int.parse(hi[0]), int.parse(hi[1]));
      _horaFin = DateTime(
          hoy.year, hoy.month, hoy.day, int.parse(hf[0]), int.parse(hf[1]));
    } catch (_) {}
  }

  void _parsearCoordenadas() {
    _poligonoPuntos = [];
    _centro = null;
    if (widget.horario.tienePoligono) {
      _poligonoPuntos = widget.horario.poligono!
          .where((p) => p.containsKey('lat'))
          .map((p) => LatLng(p['lat']!, p['lng']!))
          .toList();
      if (_poligonoPuntos.isNotEmpty) {
        double lat = 0, lng = 0;
        for (var p in _poligonoPuntos) {
          lat += p.latitude;
          lng += p.longitude;
        }
        _centro =
            LatLng(lat / _poligonoPuntos.length, lng / _poligonoPuntos.length);
        _nombreLugar =
            widget.horario.ubicacionNombre ?? widget.horario.ubicacionDisplay;
        return;
      }
    }
    if (widget.horario.tieneCoordenadas) {
      _centro = LatLng(
          widget.horario.ubicacionLatitud!, widget.horario.ubicacionLongitud!);
      _nombreLugar =
          widget.horario.ubicacionNombre ?? widget.horario.ubicacionDisplay;
      return;
    }
    final u = widget.horario.ubicacion;
    if (u != null && u.contains(',')) {
      try {
        final parts = u.split(',');
        _centro = LatLng(
            double.parse(parts[0].trim()), double.parse(parts[1].trim()));
        _nombreLugar =
            parts.length >= 3 ? parts.sublist(2).join(',').trim() : 'Ubicación';
      } catch (_) {}
    } else {
      _nombreLugar = u ?? 'Sin ubicación';
    }
  }

  void _calcularTiempos({bool force = false}) {
    if (_horaInicio == null || _horaFin == null) return;
    final ahora = DateTime.now();
    final inicio = _horaInicio!, fin = _horaFin!;
    Duration restE = Duration.zero,
        retrE = Duration.zero,
        trab = Duration.zero,
        restS = Duration.zero,
        retrS = Duration.zero;
    bool puedeE = false, puedeS = false, mostrarS = false;
    double prog = 0;

    if (!widget.horario.yaMarcoEntrada) {
      prog = (ahora.difference(inicio).inSeconds /
              fin.difference(inicio).inSeconds)
          .clamp(0.0, 1.0);
      if (ahora.isBefore(inicio))
        restE = inicio.difference(ahora);
      else
        retrE = ahora.difference(inicio);
    } else if (!widget.horario.yaMarcoSalida) {
      trab = ahora.difference(inicio);
      prog = 0.6;
      mostrarS = true;
      if (ahora.isBefore(fin))
        restS = fin.difference(ahora);
      else
        retrS = ahora.difference(fin);
    } else {
      prog = 1.0;
    }

    puedeE = !widget.horario.yaMarcoEntrada &&
        ahora.isAfter(inicio.subtract(const Duration(minutes: 30))) &&
        ahora.isBefore(inicio.add(const Duration(minutes: 150)));
    puedeS = mostrarS &&
        ahora.isAfter(fin.subtract(const Duration(minutes: 30))) &&
        ahora.isBefore(fin.add(const Duration(minutes: 30)));

    final hash = Object.hash(
        restE.inSeconds,
        retrE.inSeconds,
        trab.inSeconds,
        restS.inSeconds,
        retrS.inSeconds,
        puedeE,
        puedeS,
        prog.toStringAsFixed(2));
    if (!force && hash == _lastHash) return;
    _lastHash = hash;

    if ((prog - _progreso).abs() > 0.001) {
      _progressAnim = Tween<double>(begin: _progreso, end: prog).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
      _animController.forward(from: 0);
    }
    if (!mounted) return;
    setState(() {
      _progreso = prog;
      _tiempoTrabajado = trab;
      _tiempoRestanteEntrada = restE;
      _tiempoRetrasoEntrada = retrE;
      _puedeMarcarEntrada = puedeE;
      _tiempoRestanteSalida = restS;
      _tiempoRetrasoSalida = retrS;
      _puedeMarcarSalida = puedeS;
      _mostrarTemporizadorSalida = mostrarS;
    });
  }

  // ── UI HELPERS ──
  String _fmtCorto(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  Color _getColorHeader() {
    if (widget.horario.estaCompletado) return _AppColors.green;
    if (widget.horario.yaMarcoEntrada) return _AppColors.orange;
    return _AppColors.blue;
  }

  bool get _tieneUbicacion => _centro != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(),
                if (_tieneUbicacion) _buildMapaPreview(),
                const SizedBox(height: 10),
                _buildProgressBar(),
                const SizedBox(height: 10),
                _buildEstado(),
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

  // HEADER MEJORADO - sin blur, con gradiente
  Widget _buildHeader() {
    final c = _getColorHeader();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c, c.withOpacity(0.85)]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.horario.materia,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                  'Paralelo ${widget.horario.paralelo} • ${widget.horario.horaInicio} - ${widget.horario.horaFin}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
                widget.horario.estaCompletado
                    ? 'Completado'
                    : widget.horario.yaMarcoEntrada
                        ? 'En curso'
                        : 'Pendiente',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: _AppColors.lightGray,
              borderRadius: BorderRadius.circular(6)),
          child: const Icon(CupertinoIcons.clock,
              size: 12, color: _AppColors.gray)),
      const SizedBox(width: 8),
      Text('${widget.horario.horaInicio} - ${widget.horario.horaFin}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      if (_nombreLugar != null) ...[
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _mostrarMapa = !_mostrarMapa);
            },
            child: Row(children: [
              Icon(
                  _mostrarMapa
                      ? CupertinoIcons.location_slash_fill
                      : CupertinoIcons.location_fill,
                  size: 12,
                  color: _tieneUbicacion ? _AppColors.blue : _AppColors.gray),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(_nombreLugar!,
                      style: TextStyle(
                          fontSize: 12,
                          color: _tieneUbicacion
                              ? _AppColors.blue
                              : _AppColors.gray,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Icon(
                  _mostrarMapa
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 10,
                  color: _AppColors.blue),
            ]),
          ),
        ),
      ]
    ]);
  }

  // MAPA PREVIEW MEJORADO - 160px, sin controles, tappable
  Widget _buildMapaPreview() {
    if (!_mostrarMapa || !_tieneUbicacion) return const SizedBox.shrink();
    final target = _centro!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: _toggleFullMap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 160,
            decoration:
                BoxDecoration(border: Border.all(color: _AppColors.border)),
            child: Stack(
              children: [
                IgnorePointer(
                  child: GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: target, zoom: 16),
                    markers: {
                      Marker(
                          markerId: const MarkerId('d'),
                          position: target,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueBlue)),
                      if (_currentLocation != null)
                        Marker(
                            markerId: const MarkerId('yo'),
                            position: _currentLocation!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                _isInside
                                    ? BitmapDescriptor.hueGreen
                                    : BitmapDescriptor.hueAzure)),
                    },
                    circles: _currentLocation != null && _accuracy != null
                        ? {
                            Circle(
                                circleId: const CircleId('acc'),
                                center: _currentLocation!,
                                radius: _accuracy!,
                                fillColor: (_isInside
                                        ? _AppColors.green
                                        : _AppColors.blue)
                                    .withOpacity(0.15),
                                strokeColor: (_isInside
                                        ? _AppColors.green
                                        : _AppColors.blue)
                                    .withOpacity(0.3),
                                strokeWidth: 1)
                          }
                        : {},
                    polygons: _poligonoPuntos.isNotEmpty
                        ? {
                            Polygon(
                                polygonId: const PolygonId('g'),
                                points: _poligonoPuntos,
                                fillColor: (_isInside
                                        ? _AppColors.green
                                        : _AppColors.blue)
                                    .withOpacity(0.12),
                                strokeColor: _isInside
                                    ? _AppColors.green
                                    : _AppColors.blue,
                                strokeWidth: _isInside ? 3 : 2)
                          }
                        : {},
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (c) => _mapController = c,
                  ),
                ),
                Positioned.fill(child: Container(color: Colors.transparent)),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4)
                        ]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          _isInside
                              ? CupertinoIcons.checkmark_shield_fill
                              : CupertinoIcons.location_fill,
                          size: 12,
                          color:
                              _isInside ? _AppColors.green : _AppColors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(
                              _isInside
                                  ? 'Dentro del área • Toca para ampliar'
                                  : 'Fuera del área • ${_nombreLugar ?? ''}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _isInside
                                      ? _AppColors.green
                                      : _AppColors.gray),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      const Icon(CupertinoIcons.fullscreen,
                          size: 12, color: _AppColors.gray),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (widget.horario.estaCompletado) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (_, __) => LinearProgressIndicator(
            value: _progressAnim.value,
            minHeight: 4,
            backgroundColor: _AppColors.lightGray,
            valueColor: AlwaysStoppedAnimation(
                _progreso > 0.9 ? _AppColors.green : _AppColors.blue)),
      ),
    );
  }

  Widget _buildEstado() {
    if (widget.horario.estaCompletado) return _buildCompletado();
    if (widget.horario.yaMarcoEntrada) {
      if (!_mostrarTemporizadorSalida) return const SizedBox.shrink();
      final color = _tiempoRestanteSalida.inMinutes > 10
          ? _AppColors.blue
          : _tiempoRestanteSalida.inMinutes > 5
              ? _AppColors.orange
              : _AppColors.red;
      return _buildPill(
          color: color,
          icon: CupertinoIcons.timer_fill,
          text: _tiempoRestanteSalida.inSeconds > 0
              ? 'Salida en ${_fmtCorto(_tiempoRestanteSalida)}'
              : 'Salida con retraso ${_fmtCorto(_tiempoRetrasoSalida)}');
    }
    final color = _tiempoRetrasoEntrada.inMinutes > 0
        ? (_tiempoRetrasoEntrada.inMinutes < 5
            ? _AppColors.orange
            : _AppColors.red)
        : _tiempoRestanteEntrada.inMinutes > 0
            ? _AppColors.blue
            : _AppColors.green;
    final text = _tiempoRetrasoEntrada.inMinutes > 0
        ? 'Retraso: ${_fmtCorto(_tiempoRetrasoEntrada)}'
        : _tiempoRestanteEntrada.inSeconds > 0
            ? 'Entrada en: ${_fmtCorto(_tiempoRestanteEntrada)}'
            : 'Esperando entrada';
    return _buildPill(
        color: color, icon: CupertinoIcons.time_solid, text: text);
  }

  Widget _buildPill(
      {required Color color, required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)))
      ]),
    );
  }

  Widget _buildTiempoTrabajado() {
    return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          const Icon(CupertinoIcons.stopwatch_fill,
              size: 12, color: _AppColors.green),
          const SizedBox(width: 6),
          Text('Trabajado: ${_fmtCorto(_tiempoTrabajado)}',
              style: const TextStyle(
                  fontSize: 12,
                  color: _AppColors.green,
                  fontWeight: FontWeight.w600))
        ]));
  }

  Widget _buildCompletado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: _AppColors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.green.withOpacity(0.18))),
      child: Row(children: [
        Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: _AppColors.green,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(CupertinoIcons.checkmark_alt,
                color: Colors.white, size: 16, weight: 800)),
        const SizedBox(width: 10),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Asistencia completada',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _AppColors.green)),
          SizedBox(height: 1),
          Text('Jornada finalizada correctamente',
              style: TextStyle(fontSize: 11, color: _AppColors.green))
        ]))
      ]),
    );
  }

  Widget _buildBotones() {
    if (widget.horario.estaCompletado) return const SizedBox.shrink();
    return Row(children: [
      if (!widget.horario.yaMarcoEntrada)
        Expanded(
            child: _buildBoton(
                'Marcar Entrada',
                CupertinoIcons.arrow_right_circle_fill,
                _AppColors.blue,
                _puedeMarcarEntrada,
                _handleMarcarEntrada)),
      if (widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida)
        Expanded(
            child: _buildBoton(
                'Marcar Salida',
                CupertinoIcons.arrow_left_circle_fill,
                _AppColors.red,
                _puedeMarcarSalida,
                _handleMarcarSalida)),
    ]);
  }

  Widget _buildBoton(String texto, IconData icon, Color color, bool habilitado,
      VoidCallback onTap) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: habilitado && !_isLoading ? onTap : null,
        style: FilledButton.styleFrom(
            backgroundColor: habilitado ? color : _AppColors.lightGray,
            foregroundColor: habilitado ? Colors.white : _AppColors.gray,
            disabledBackgroundColor: _AppColors.lightGray,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0),
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(texto,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
    _mostrarDialogoSalida();
  }

  void _toggleFullMap() {
    if (_centro == null) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FullScreenMapPage(
            center: _centro!,
            markers: {},
            polygons: _poligonoPuntos.isNotEmpty
                ? {
                    Polygon(
                        polygonId: const PolygonId('g'),
                        points: _poligonoPuntos,
                        fillColor: _AppColors.blue.withOpacity(0.15),
                        strokeColor: _AppColors.blue,
                        strokeWidth: 2)
                  }
                : {},
            polylines: {},
            nombreLugar: _nombreLugar ?? 'Ubicación',
            geocercaPuntos: _poligonoPuntos)));
  }

  void _mostrarDialogoSalida() {
    final ahora = DateTime.now();
    final fin = _horaFin!;
    final diff = ahora.difference(fin).inMinutes;
    showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
              title: Text(diff < 0
                  ? 'Salida Anticipada'
                  : diff <= 15
                      ? 'Salida en Horario'
                      : 'Salida Tardía'),
              content: Column(children: [
                Text(diff < 0
                    ? 'Saliendo ${diff.abs()} min antes'
                    : diff <= 15
                        ? 'Dentro del horario'
                        : 'Saliendo $diff min después'),
                const SizedBox(height: 8),
                Text(
                    '${widget.horario.materia} • ${DateFormat('HH:mm').format(ahora)}',
                    style: const TextStyle(fontSize: 12))
              ]),
              actions: [
                CupertinoDialogAction(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                CupertinoDialogAction(
                    isDestructiveAction: diff > 15,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onMarcarSalida();
                    },
                    child: const Text('Confirmar')),
              ],
            ));
  }
}
