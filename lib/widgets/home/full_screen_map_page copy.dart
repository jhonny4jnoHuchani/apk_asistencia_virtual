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

  const FullScreenMapPage({
    super.key,
    required this.center,
    required this.markers,
    required this.polygons,
    required this.polylines,
    required this.nombreLugar,
  });

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage>
    with WidgetsBindingObserver {
  GoogleMapController? _controller;
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  StreamSubscription<Position>? _positionSub;

  LatLng? _currentLocation;
  double? _accuracy;
  double _distanciaMetros = 0;
  int _tiempoMinutos = 0;
  double? _bearing;

  MapType _mapType = MapType.normal;
  bool _siguiendo = false;

  static const Color _blue = Color(0xFF007AFF);
  static const Color _darkCard = Color(0xE61C1C1E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initUbicacionStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initUbicacionStream();
    } else if (state == AppLifecycleState.paused) {
      _positionSub?.pause();
    }
  }

  // ============================================
  // GPS MEJORADO
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

      // Fix inicial rápido
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _onPositionUpdate(last);
      } catch (_) {}

      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
          timeLimit: Duration(seconds: 15),
        ),
      ).listen(_onPositionUpdate, onError: (e) => _showSnack('Error GPS: $e'));
    } catch (e) {
      debugPrint('GPS init error: $e');
    }
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    // Filtro: ignora fixes muy malos si ya tenemos uno bueno
    if (position.accuracy > 40 && _accuracy != null && _accuracy! < 15) return;

    final nueva = LatLng(position.latitude, position.longitude);

    // Usamos el cálculo nativo, no haversine manual
    final distMetros = Geolocator.distanceBetween(
      nueva.latitude,
      nueva.longitude,
      widget.center.latitude,
      widget.center.longitude,
    );

    final minutos = (distMetros / 1000 / 5 * 60).round(); // 5km/h caminando

    setState(() {
      _currentLocation = nueva;
      _accuracy = position.accuracy;
      _bearing = position.heading;
      _distanciaMetros = distMetros;
      _tiempoMinutos = minutos;
    });

    if (_siguiendo) _centrarEnMi(animado: true);
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
  // ACCIONES MAPA
  // ============================================
  Future<void> _ensureController() async {
    if (_controllerCompleter.isCompleted) {
      _controller = await _controllerCompleter.future;
    }
  }

  void _centrarEnMi({bool animado = true}) {
    if (_currentLocation == null) return;
    HapticFeedback.lightImpact();
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation!,
          zoom: 17.5,
          bearing: _bearing ?? 0,
        ),
      ),
    );
    setState(() => _siguiendo = animado);
  }

  void _centrarEnDestino() {
    HapticFeedback.lightImpact();
    setState(() => _siguiendo = false);
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: widget.center, zoom: 17),
      ),
    );
  }

  Future<void> _ajustarParaVerAmbos() async {
    if (_currentLocation == null || _controller == null) return;
    HapticFeedback.lightImpact();
    setState(() => _siguiendo = false);

    try {
      final bounds = _createBounds(_currentLocation!, widget.center);
      await _controller!
          .animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {
      // Fallback si bounds es muy pequeño
      _centrarEnDestino();
    }
  }

  LatLngBounds _createBounds(LatLng a, LatLng b) {
    // Evita crash cuando los puntos están a < 10m
    final latDelta = (a.latitude - b.latitude).abs();
    final lngDelta = (a.longitude - b.longitude).abs();
    final padding = 0.0002; // ~20m

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

  Future<void> _abrirRutaEnGoogleMaps() async {
    HapticFeedback.mediumImpact();
    final dest = '${widget.center.latitude},${widget.center.longitude}';
    final orig = _currentLocation != null
        ? '${_currentLocation!.latitude},${_currentLocation!.longitude}'
        : '';

    // Intenta app nativa, luego web
    final urls = [
      Uri.parse('google.navigation:q=$dest&mode=w'), // Android
      Uri.parse(
          'https://www.google.com/maps/dir/?api=1&origin=$orig&destination=$dest&travelmode=walking'),
      Uri.parse(
          'https://maps.apple.com/?daddr=$dest&saddr=$orig&dirflg=w'), // iOS fallback
    ];

    for (final url in urls) {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
    _showSnack('No se pudo abrir mapas');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================
  // MARKERS / POLYLINES DINÁMICOS
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
          flat: false,
          anchor: const Offset(0.5, 0.5),
          rotation: _bearing ?? 0,
          // Punto azul estilo Google Maps
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
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

  // ============================================
  // UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    final hasLocation = _currentLocation != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.nombreLugar,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white.withOpacity(0.85),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
                _siguiendo ? Icons.navigation : Icons.navigation_outlined,
                color: _siguiendo ? _blue : null),
            tooltip: _siguiendo ? 'Siguiendo' : 'Seguirme',
            onPressed: () {
              setState(() => _siguiendo = !_siguiendo);
              if (_siguiendo) _centrarEnMi();
            },
          ),
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_outlined),
            initialValue: _mapType,
            onSelected: (type) {
              HapticFeedback.selectionClick();
              setState(() => _mapType = type);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: MapType.normal,
                  child:
                      _MapTypeTile(icon: Icons.map_outlined, label: 'Normal')),
              PopupMenuItem(
                  value: MapType.satellite,
                  child: _MapTypeTile(
                      icon: Icons.satellite_alt_outlined, label: 'Satélite')),
              PopupMenuItem(
                  value: MapType.hybrid,
                  child: _MapTypeTile(
                      icon: Icons.layers_outlined, label: 'Híbrido')),
              PopupMenuItem(
                  value: MapType.terrain,
                  child: _MapTypeTile(
                      icon: Icons.terrain_outlined, label: 'Terreno')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: widget.center, zoom: 16),
            mapType: _mapType,
            markers: _getMarkers(),
            polygons: widget.polygons,
            polylines: _getPolylines(),
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            compassEnabled: true,
            buildingsEnabled: true,
            onMapCreated: (c) {
              if (!_controllerCompleter.isCompleted) {
                _controllerCompleter.complete(c);
              }
              _controller = c;
              if (hasLocation)
                Future.delayed(
                    const Duration(milliseconds: 300), _ajustarParaVerAmbos);
            },
          ),

          // FABs
          Positioned(
            right: 12,
            bottom: 140,
            child: Column(
              children: [
                _buildFab(
                    icon: Icons.my_location,
                    active: hasLocation,
                    onTap: hasLocation
                        ? _centrarEnMi
                        : () => _showSnack('Esperando GPS...')),
                const SizedBox(height: 10),
                _buildFab(icon: Icons.location_on, onTap: _centrarEnDestino),
                const SizedBox(height: 10),
                _buildFab(
                    icon: Icons.zoom_out_map,
                    onTap:
                        hasLocation ? _ajustarParaVerAmbos : _centrarEnDestino),
              ],
            ),
          ),

          // Card inferior
          Positioned(left: 12, right: 12, bottom: 12, child: _buildRouteCard()),
        ],
      ),
    );
  }

  Widget _buildFab(
      {required IconData icon,
      required VoidCallback onTap,
      bool active = true}) {
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
            child: Icon(icon,
                size: 22, color: active ? Colors.black87 : Colors.black38)),
      ),
    );
  }

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
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.directions_walk,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    if (!sinUbicacion)
                      Text(
                          '${_formatearTiempo(_tiempoMinutos)} a pie • ±${_accuracy?.toStringAsFixed(0) ?? '--'}m',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              if (_siguiendo)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _blue, borderRadius: BorderRadius.circular(20)),
                  child: const Text('SIGUIENDO',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                )
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _abrirRutaEnGoogleMaps,
              icon: const Icon(Icons.directions, size: 18),
              label: Text(sinUbicacion ? 'Ver ruta' : 'Ir con Google Maps',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MapTypeTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18),
      const SizedBox(width: 10),
      Text(label)
    ]);
  }
}
