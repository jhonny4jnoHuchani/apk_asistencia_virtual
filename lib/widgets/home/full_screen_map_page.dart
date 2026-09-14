import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class FullScreenMapPage extends StatefulWidget {
  final LatLng center;
  final Set<Marker> markers;
  final Set<Polygon> polygons;
  final Set<Polyline> polylines;
  final String nombreLugar;

  /// Si se pasa, se evalúa dentro/fuera de la geocerca.
  final List<LatLng>? geocercaPuntos;

  const FullScreenMapPage({
    super.key,
    required this.center,
    required this.markers,
    required this.polygons,
    required this.polylines,
    required this.nombreLugar,
    this.geocercaPuntos,
  });

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ============================================
  // CONSTANTES
  // ============================================
  static const Color _blue = Color(0xFF007AFF);
  static const Color _green = Color(0xFF34C759);
  static const Color _red = Color(0xFFFF3B30);
  static const Color _darkCard = Color(0xE61C1C1E);

  // ============================================
  // ESTADO
  // ============================================
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  GoogleMapController? _controller;

  StreamSubscription<Position>? _positionSub;
  late final AnimationController _pulseController;

  LatLng? _currentLocation;
  double? _accuracy;
  double _distanciaMetros = 0;
  int _tiempoMinutos = 0;
  double? _bearing;

  /// null = sin geocerca que evaluar
  bool? _isInside;

  MapType _mapType = MapType.normal;
  bool _siguiendo = false;

  // Cache de círculos para no regenerar cada frame
  double? _lastAccuracyForCache;
  bool? _lastInsideForCache;

  // ============================================
  // LIFECYCLE
  // ============================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initUbicacionStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _pulseController.dispose();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Reanuda el stream; si no existe, lo reinicia
        if (_positionSub == null) {
          _initUbicacionStream();
        } else {
          _initUbicacionStream();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _positionSub?.pause();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  // ============================================
  // GPS
  // ============================================
  Future<void> _initUbicacionStream() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showSnack('Activa el GPS para ver tu ubicación');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Sin permiso de ubicación');
        return;
      }

      // Fix inicial rápido con última ubicación conocida
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _onPositionUpdate(last);
      } catch (_) {}

      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen(
        _onPositionUpdate,
        onError: (Object e) => debugPrint('GPS stream error: $e'),
      );
    } catch (e) {
      debugPrint('GPS init error: $e');
    }
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;

    // Filtra fixes malos si ya tenemos uno bueno
    if (position.accuracy > 40 && _accuracy != null && _accuracy! < 15) {
      return;
    }

    final nueva = LatLng(position.latitude, position.longitude);

    // Distancia nativa (más precisa que Haversine manual)
    final distMetros = Geolocator.distanceBetween(
      nueva.latitude,
      nueva.longitude,
      widget.center.latitude,
      widget.center.longitude,
    );

    // Tiempo estimado caminando (5 km/h)
    final minutos = (distMetros / 1000 / 5 * 60).round();

    // Evaluar dentro/fuera si hay geocerca
    bool? inside;
    if (widget.geocercaPuntos != null && widget.geocercaPuntos!.isNotEmpty) {
      inside = _isPointInPolygon(nueva, widget.geocercaPuntos!);
    }

    setState(() {
      _currentLocation = nueva;
      _accuracy = position.accuracy;
      _bearing = position.heading >= 0 ? position.heading : null;
      _distanciaMetros = distMetros;
      _tiempoMinutos = minutos;
      _isInside = inside;
    });

    if (_siguiendo) _centrarEnMi(animado: true);
  }

  /// Algoritmo ray-casting: punto dentro de polígono.
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  // ============================================
  // FORMATEO
  // ============================================
  String _formatearDistancia(double metros) {
    if (metros < 1000) return '${metros.round()} m';
    if (metros < 10000) return '${(metros / 1000).toStringAsFixed(2)} km';
    return '${(metros / 1000).toStringAsFixed(1)} km';
  }

  String _formatearTiempo(int minutos) {
    if (minutos < 1) return '< 1 min';
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m > 0 ? '${h}h ${m}min' : '${h}h';
  }

  // ============================================
  // ACCIONES DE CÁMARA
  // ============================================
  Future<GoogleMapController?> _ensureController() async {
    if (_controller != null) return _controller;
    if (_controllerCompleter.isCompleted) {
      _controller = await _controllerCompleter.future;
    }
    return _controller;
  }

  Future<void> _centrarEnMi({bool animado = true}) async {
    if (_currentLocation == null) return;
    HapticFeedback.lightImpact();
    final c = await _ensureController();
    c?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation!,
          zoom: 17.5,
          bearing: _bearing ?? 0,
        ),
      ),
    );
    if (mounted && _siguiendo != animado) {
      setState(() => _siguiendo = animado);
    }
  }

  Future<void> _centrarEnDestino() async {
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _siguiendo = false);
    final c = await _ensureController();
    c?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: widget.center, zoom: 17),
      ),
    );
  }

  Future<void> _ajustarParaVerAmbos() async {
    if (_currentLocation == null) return;
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _siguiendo = false);

    final c = await _ensureController();
    if (c == null) return;

    try {
      final bounds = _createBounds(_currentLocation!, widget.center);
      await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {
      // Fallback si bounds es inválido (puntos casi iguales)
      await _centrarEnDestino();
    }
  }

  LatLngBounds _createBounds(LatLng a, LatLng b) {
    final latDelta = (a.latitude - b.latitude).abs();
    final lngDelta = (a.longitude - b.longitude).abs();
    const padding = 0.0002; // ~20m
    return LatLngBounds(
      southwest: LatLng(
        math.min(a.latitude, b.latitude) - (latDelta < 0.0001 ? padding : 0),
        math.min(a.longitude, b.longitude) - (lngDelta < 0.0001 ? padding : 0),
      ),
      northeast: LatLng(
        math.max(a.latitude, b.latitude) + (latDelta < 0.0001 ? padding : 0),
        math.max(a.longitude, b.longitude) + (lngDelta < 0.0001 ? padding : 0),
      ),
    );
  }

  // ============================================
  // ABRIR GOOGLE MAPS / APPLE MAPS
  // ============================================
  Future<void> _abrirRutaEnGoogleMaps() async {
    HapticFeedback.mediumImpact();
    final dest = '${widget.center.latitude},${widget.center.longitude}';
    final orig = _currentLocation != null
        ? '${_currentLocation!.latitude},${_currentLocation!.longitude}'
        : '';

    // Intenta app nativa Android → Google Maps web → Apple Maps
    final urls = <Uri>[
      Uri.parse('google.navigation:q=$dest&mode=w'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '${orig.isNotEmpty ? '&origin=$orig' : ''}'
        '&destination=$dest&travelmode=walking',
      ),
      Uri.parse(
        'https://maps.apple.com/?daddr=$dest'
        '${orig.isNotEmpty ? '&saddr=$orig' : ''}&dirflg=w',
      ),
    ];

    for (final url in urls) {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
    _showSnack('No se pudo abrir la app de mapas');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================
  // MARKERS / POLYLINES / CIRCLES DINÁMICOS
  // ============================================
  Set<Marker> _getMarkers() {
    final markers = <Marker>{...widget.markers};

    if (_currentLocation != null) {
      markers.removeWhere((m) => m.markerId.value == 'mi_ubicacion');
      markers.add(
        Marker(
          markerId: const MarkerId('mi_ubicacion'),
          position: _currentLocation!,
          zIndex: 10,
          anchor: const Offset(0.5, 0.5),
          rotation: _bearing ?? 0,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _isInside == true
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: 'Tú',
            snippet:
                '±${_accuracy?.toStringAsFixed(0) ?? '--'}m • ${_formatearDistancia(_distanciaMetros)}',
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _getPolylines() {
    final polylines = <Polyline>{...widget.polylines};
    if (_currentLocation == null) return polylines;

    polylines.removeWhere((p) => p.polylineId.value == 'ruta');
    polylines.add(
      Polyline(
        polylineId: const PolylineId('ruta'),
        points: [_currentLocation!, widget.center],
        color: _blue,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        patterns: [PatternItem.dash(20), PatternItem.gap(12)],
      ),
    );
    return polylines;
  }

  Set<Polygon> _getPolygons() {
    if (widget.polygons.isEmpty) return widget.polygons;

    // Si no hay geocerca que evaluar, devuelve los originales
    if (_isInside == null) return widget.polygons;

    final color = _isInside! ? _green : _blue;

    return widget.polygons.map((p) {
      return Polygon(
        polygonId: p.polygonId,
        points: p.points,
        fillColor: color.withOpacity(0.18),
        strokeColor: color,
        strokeWidth: _isInside! ? 3 : 2,
        geodesic: p.geodesic,
        consumeTapEvents: p.consumeTapEvents,
      );
    }).toSet();
  }

  Set<Circle> _getCircles() {
    if (_currentLocation == null || _accuracy == null) return {};

    // Cache: solo regenera si cambió la precisión significativamente
    final needRecalc = _lastAccuracyForCache == null ||
        (_lastAccuracyForCache! - _accuracy!).abs() > 1 ||
        _lastInsideForCache != _isInside;

    if (!needRecalc) {
      // Reutiliza los últimos círculos pero con nueva posición
      return _buildCircles();
    }

    _lastAccuracyForCache = _accuracy;
    _lastInsideForCache = _isInside;
    return _buildCircles();
  }

  Set<Circle> _buildCircles() {
    final color = _isInside == false ? _red : _blue;
    return {
      // Halo exterior (pulso)
      Circle(
        circleId: const CircleId('accuracy_outer'),
        center: _currentLocation!,
        radius: (_accuracy! * 1.8).clamp(5, 200),
        fillColor: color.withOpacity(0.08),
        strokeWidth: 0,
        zIndex: 0,
      ),
      // Precisión real
      Circle(
        circleId: const CircleId('accuracy'),
        center: _currentLocation!,
        radius: _accuracy!.clamp(3, 100),
        fillColor: color.withOpacity(0.18),
        strokeColor: color.withOpacity(0.45),
        strokeWidth: 1,
        zIndex: 1,
      ),
    };
  }

  // ============================================
  // UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    final hasLocation = _currentLocation != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.nombreLugar,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _siguiendo ? Icons.navigation : Icons.navigation_outlined,
              color: _siguiendo ? _blue : null,
            ),
            tooltip: _siguiendo ? 'Siguiendo' : 'Seguirme',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _siguiendo = !_siguiendo);
              if (_siguiendo) _centrarEnMi();
            },
          ),
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_outlined),
            initialValue: _mapType,
            tooltip: 'Tipo de mapa',
            onSelected: (type) {
              HapticFeedback.selectionClick();
              setState(() => _mapType = type);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: MapType.normal,
                child: _MapTypeTile(icon: Icons.map_outlined, label: 'Normal'),
              ),
              PopupMenuItem(
                value: MapType.satellite,
                child: _MapTypeTile(
                    icon: Icons.satellite_alt_outlined, label: 'Satélite'),
              ),
              PopupMenuItem(
                value: MapType.hybrid,
                child:
                    _MapTypeTile(icon: Icons.layers_outlined, label: 'Híbrido'),
              ),
              PopupMenuItem(
                value: MapType.terrain,
                child: _MapTypeTile(
                    icon: Icons.terrain_outlined, label: 'Terreno'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAPA
          RepaintBoundary(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.center,
                zoom: 16,
              ),
              mapType: _mapType,
              markers: _getMarkers(),
              polygons: _getPolygons(),
              polylines: _getPolylines(),
              circles: _getCircles(),
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false, // usamos stream propio
              compassEnabled: true,
              indoorViewEnabled: false,
              trafficEnabled: false,
              buildingsEnabled: true,
              onMapCreated: (c) {
                if (!_controllerCompleter.isCompleted) {
                  _controllerCompleter.complete(c);
                }
                _controller = c;
                // Si ya tenemos ubicación, ajusta bounds
                if (_currentLocation != null) {
                  Future.delayed(
                    const Duration(milliseconds: 400),
                    _ajustarParaVerAmbos,
                  );
                }
              },
            ),
          ),

          // BADGE SUPERIOR: DENTRO / FUERA
          if (hasLocation && _isInside != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              left: 12,
              right: 12,
              child: _buildStatusBadge(),
            ),

          // FABs DERECHA
          Positioned(
            right: 12,
            bottom: 160,
            child: Column(
              children: [
                _buildFab(
                  icon: Icons.my_location,
                  active: hasLocation,
                  onTap: hasLocation
                      ? () => _centrarEnMi()
                      : () => _showSnack('Esperando GPS...'),
                ),
                const SizedBox(height: 10),
                _buildFab(
                  icon: Icons.location_on,
                  onTap: _centrarEnDestino,
                ),
                const SizedBox(height: 10),
                _buildFab(
                  icon: Icons.zoom_out_map,
                  onTap: hasLocation ? _ajustarParaVerAmbos : _centrarEnDestino,
                ),
              ],
            ),
          ),

          // CARD INFERIOR
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildRouteCard(),
          ),
        ],
      ),
    );
  }

  // ============================================
  // BADGE DENTRO / FUERA
  // ============================================
  Widget _buildStatusBadge() {
    final inside = _isInside ?? false;
    final baseColor = inside ? _green : _red;
    final icon = inside ? Icons.check_circle : Icons.warning_amber_rounded;
    final texto = inside
        ? 'Dentro del área • ±${_accuracy!.toStringAsFixed(0)}m'
        : 'Fuera • ${_formatearDistancia(_distanciaMetros)}';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: baseColor.withOpacity(0.9 + _pulseController.value * 0.1),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: baseColor.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  texto,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // CARD INFERIOR CON RUTA
  // ============================================
  Widget _buildRouteCard() {
    final sinUbicacion = _currentLocation == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_walk,
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
                      sinUbicacion
                          ? 'Buscando señal GPS...'
                          : _formatearDistancia(_distanciaMetros),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sinUbicacion
                          ? 'Activa el GPS para continuar'
                          : '${_formatearTiempo(_tiempoMinutos)} a pie • ±${_accuracy?.toStringAsFixed(0) ?? '--'}m',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_siguiendo)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SIGUIENDO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _abrirRutaEnGoogleMaps,
              icon: const Icon(Icons.directions, size: 18),
              label: Text(
                sinUbicacion ? 'Ver ruta' : 'Ir con Google Maps',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // FAB
  // ============================================
  Widget _buildFab({
    required IconData icon,
    required VoidCallback onTap,
    bool active = true,
  }) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      color: active ? Colors.white : Colors.white70,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            size: 22,
            color: active ? Colors.black87 : Colors.black38,
          ),
        ),
      ),
    );
  }
}

// ============================================
// WIDGET AUXILIAR PARA EL MENÚ DE TIPOS DE MAPA
// ============================================
class _MapTypeTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MapTypeTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
