import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:pocket_guide_mobile/maps/map_provider.dart';

// ─── Public provider ──────────────────────────────────────────────────────────

/// MapLibre GL + OpenFreeMap vector tiles implementation of [RrawiMapProvider].
///
/// All map content (route lines, POI pins, user dot) is rendered as native
/// MapLibre GL layers via GeoJSON sources.  This keeps everything inside the
/// GL render pipeline so all layers move perfectly in sync — no Flutter overlay
/// lag during panning.
///
/// Trade-off: POI photos are not supported in this approach (they would require
/// pre-rendering Flutter widgets to bitmaps and registering them as sprite
/// images).  Numbers + state colours are rendered with GL circle + text layers.
class OpenFreeMapProvider implements RrawiMapProvider {
  static const String _styleUrl =
      'https://tiles.openfreemap.org/styles/liberty';

  @override
  Widget buildMap({
    required BuildContext context,
    required RrawiLatLng initialCenter,
    required double initialZoom,
    required void Function(RrawiMapController) onReady,
    required void Function(bool wasGesture) onCameraIdle,
  }) {
    return _OpenFreeMapView(
      styleUrl: _styleUrl,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
      onReady: onReady,
      onCameraIdle: onCameraIdle,
    );
  }
}

// ─── Internal stateful map view ───────────────────────────────────────────────

class _OpenFreeMapView extends StatefulWidget {
  const _OpenFreeMapView({
    required this.styleUrl,
    required this.initialCenter,
    required this.initialZoom,
    required this.onReady,
    required this.onCameraIdle,
  });

  final String styleUrl;
  final RrawiLatLng initialCenter;
  final double initialZoom;
  final void Function(RrawiMapController) onReady;
  final void Function(bool wasGesture) onCameraIdle;

  @override
  State<_OpenFreeMapView> createState() => _OpenFreeMapViewState();
}

class _OpenFreeMapViewState extends State<_OpenFreeMapView> {
  MapLibreMapController? _mlController;
  late final _OpenFreeMapController _controller;

  bool _styleLoaded = false;
  bool _programmaticMove = false;

  /// id → tap callback for the currently displayed pins
  final Map<String, VoidCallback?> _pinTapCallbacks = {};

  // Updates buffered before the style finishes loading
  List<MapRouteSegment>? _pendingRoute;
  List<MapPinData>? _pendingPins;
  RrawiLatLng? _pendingUserLocation;

  @override
  void initState() {
    super.initState();
    _controller = _OpenFreeMapController(this);
  }

  // ── MapLibre callbacks ────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _mlController = controller;
  }

  Future<void> _onStyleLoaded() async {
    if (_mlController == null || !mounted) return;
    await _initLayers();
    if (!mounted) return;
    setState(() => _styleLoaded = true);

    // Flush buffered updates
    if (_pendingRoute != null) _applyRoute(_pendingRoute!);
    if (_pendingPins != null) _applyPins(_pendingPins!);
    if (_pendingUserLocation != null) _applyUserLocation(_pendingUserLocation);
    _pendingRoute = null;
    _pendingPins = null;
    _pendingUserLocation = null;

    widget.onReady(_controller);
  }

  static Map<String, dynamic> _emptyCollection() =>
      {'type': 'FeatureCollection', 'features': <dynamic>[]};

  Future<void> _initLayers() async {
    final ctrl = _mlController!;
    final empty = _emptyCollection();

    // ── Route sources & layers ────────────────────────────────────────────────
    await ctrl.addGeoJsonSource('route-completed', empty);
    await ctrl.addGeoJsonSource('route-upcoming', empty);
    await ctrl.addGeoJsonSource('route-trail', empty);

    await ctrl.addLineLayer('route-completed', 'route-completed-layer',
        LineLayerProperties(
          lineColor: '#1B1915',
          lineWidth: 2.5,
          lineOpacity: 0.3,
          lineDasharray: [8.0, 6.0],
          lineCap: 'round',
          lineJoin: 'round',
        ));

    await ctrl.addLineLayer('route-upcoming', 'route-upcoming-layer',
        LineLayerProperties(
          lineColor: '#3A4A3A',
          lineWidth: 4.5,
          lineOpacity: 0.7,
          lineCap: 'round',
          lineJoin: 'round',
        ));

    await ctrl.addLineLayer('route-trail', 'route-trail-layer',
        LineLayerProperties(
          lineColor: '#3A4A3A',
          lineWidth: 3.0,
          lineOpacity: 0.5,
          lineCap: 'round',
          lineJoin: 'round',
        ));

    // ── User-location source & layers ─────────────────────────────────────────
    await ctrl.addGeoJsonSource('user-loc', empty);

    await ctrl.addCircleLayer('user-loc', 'user-halo-layer',
        const CircleLayerProperties(
          circleRadius: 14.0,
          circleColor: '#4583F0',
          circleOpacity: 0.22,
        ));

    await ctrl.addCircleLayer('user-loc', 'user-dot-layer',
        const CircleLayerProperties(
          circleRadius: 8.0,
          circleColor: '#4583F0',
          circleStrokeWidth: 3.0,
          circleStrokeColor: '#FFFFFF',
        ));

    // ── POI pin source & layers ───────────────────────────────────────────────
    // All pins live in a single GeoJSON source. Each feature carries 'state'
    // ('upcoming' | 'current' | 'completed') and 'number' (string) properties.
    // Data-driven expressions drive colour / size — no Flutter overlay needed.
    await ctrl.addGeoJsonSource('pins', empty);

    // Pulse ring — rendered only for the 'current' pin
    await ctrl.addCircleLayer(
      'pins',
      'pins-pulse-layer',
      const CircleLayerProperties(
        circleRadius: 30.0,
        circleColor: '#3A4A3A',
        circleOpacity: 0.18,
        circleStrokeWidth: 0.0,
      ),
      filter: ['==', ['get', 'state'], 'current'],
    );

    // Main pin circle — radius and colours driven by 'state'
    await ctrl.addCircleLayer(
      'pins',
      'pins-circle-layer',
      CircleLayerProperties(
        // rawiAccent for current/completed, rawiPaper for upcoming
        circleColor: [
          'case',
          ['==', ['get', 'state'], 'upcoming'], '#F6F1E7',
          '#3A4A3A',
        ],
        circleRadius: [
          'case',
          ['==', ['get', 'state'], 'current'], 20.0,
          ['==', ['get', 'state'], 'completed'], 13.0,
          14.0, // upcoming
        ],
        circleStrokeWidth: [
          'case',
          ['==', ['get', 'state'], 'current'], 3.0,
          2.0,
        ],
        circleStrokeColor: [
          'case',
          ['==', ['get', 'state'], 'upcoming'], '#1B1915',
          '#F6F1E7',
        ],
      ),
      enableInteraction: true,
    );

    // Number / checkmark text on top of the circle
    await ctrl.addSymbolLayer(
      'pins',
      'pins-text-layer',
      SymbolLayerProperties(
        textField: [
          'case',
          ['==', ['get', 'state'], 'completed'], '✓',
          ['to-string', ['get', 'number']],
        ],
        textSize: [
          'case',
          ['==', ['get', 'state'], 'current'], 14.0,
          11.0,
        ],
        textColor: [
          'case',
          ['==', ['get', 'state'], 'upcoming'], '#1B1915',
          '#F6F1E7',
        ],
        textFont: ['Noto Sans Bold', 'Arial Unicode MS Bold'],
        textIgnorePlacement: true,
        textAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAllowOverlap: true,
      ),
      enableInteraction: false, // taps handled by the circle layer below
    );
  }

  // ── State mutators called by _OpenFreeMapController ───────────────────────

  Future<void> moveCameraInternal(RrawiLatLng center, double zoom) async {
    if (_mlController == null) return;
    _programmaticMove = true;
    await _mlController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(center.latitude, center.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  double get currentZoom =>
      _mlController?.cameraPosition?.zoom ?? widget.initialZoom;

  void setRoute(List<MapRouteSegment> segments) {
    if (!_styleLoaded) { _pendingRoute = segments; return; }
    _applyRoute(segments);
  }

  void setPins(List<MapPinData> pins) {
    if (!_styleLoaded) { _pendingPins = pins; return; }
    _applyPins(pins);
  }

  void setUserLocation(RrawiLatLng? position) {
    if (!_styleLoaded) { _pendingUserLocation = position; return; }
    _applyUserLocation(position);
  }

  void _applyRoute(List<MapRouteSegment> segments) {
    _setLineSource('route-completed', RouteSegmentStyle.completed, segments);
    _setLineSource('route-upcoming', RouteSegmentStyle.upcoming, segments);
    _setLineSource('route-trail', RouteSegmentStyle.trail, segments);
  }

  void _setLineSource(
    String sourceId,
    RouteSegmentStyle style,
    List<MapRouteSegment> all,
  ) {
    final matching = all.where((s) => s.style == style).toList();
    final features = matching.map((s) => <String, dynamic>{
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': s.points
            .map((p) => [p.longitude, p.latitude])
            .toList(),
      },
      'properties': <String, dynamic>{},
    }).toList();
    _mlController?.setGeoJsonSource(sourceId, {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  void _applyPins(List<MapPinData> pins) {
    _pinTapCallbacks.clear();
    final features = <Map<String, dynamic>>[];
    for (final pin in pins) {
      _pinTapCallbacks[pin.id] = pin.onTap;
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [pin.location.longitude, pin.location.latitude],
        },
        'properties': {
          'id': pin.id,
          'number': '${pin.number}',
          'state': pin.state.name, // 'upcoming' | 'current' | 'completed'
        },
      });
    }
    _mlController?.setGeoJsonSource('pins', {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  void _applyUserLocation(RrawiLatLng? position) {
    if (position == null) {
      _mlController?.setGeoJsonSource('user-loc', _emptyCollection());
      return;
    }
    _mlController?.setGeoJsonSource('user-loc', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [position.longitude, position.latitude],
          },
          'properties': <String, dynamic>{},
        },
      ],
    });
  }

  /// Handle map taps — query which pin (if any) was hit.
  Future<void> _onMapClick(Point<double> point, LatLng latLng) async {
    if (_mlController == null) return;
    try {
      final features = await _mlController!.queryRenderedFeatures(
        point,
        ['pins-circle-layer', 'pins-pulse-layer'],
        null,
      );
      if (features.isNotEmpty) {
        final props = Map<String, dynamic>.from(
          features.first['properties'] as Map,
        );
        final id = props['id'] as String?;
        if (id != null) _pinTapCallbacks[id]?.call();
      }
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: widget.styleUrl,
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      initialCameraPosition: CameraPosition(
        target: LatLng(
          widget.initialCenter.latitude,
          widget.initialCenter.longitude,
        ),
        zoom: widget.initialZoom,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
      trackCameraPosition: true,
      onMapClick: _onMapClick,
      onCameraIdle: () {
        final wasGesture = !_programmaticMove;
        _programmaticMove = false;
        widget.onCameraIdle(wasGesture);
      },
    );
  }
}

// ─── Controller implementation ────────────────────────────────────────────────

class _OpenFreeMapController implements RrawiMapController {
  _OpenFreeMapController(this._state);
  final _OpenFreeMapViewState _state;

  @override
  Future<void> moveCamera(RrawiLatLng center, {double? zoom}) async {
    await _state.moveCameraInternal(center, zoom ?? _state.currentZoom);
  }

  @override
  double get currentZoom => _state.currentZoom;

  @override
  void updateRoute(List<MapRouteSegment> segments) =>
      _state.setRoute(segments);

  @override
  void updatePins(List<MapPinData> pins) => _state.setPins(pins);

  @override
  void updateUserLocation(RrawiLatLng? position) =>
      _state.setUserLocation(position);

  @override
  void dispose() {
    // MapLibreMapController lifecycle is owned by the MapLibreMap widget.
  }
}
