import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:pocket_guide_mobile/maps/map_provider.dart';

// ─── Public provider ──────────────────────────────────────────────────────────

/// MapLibre GL + OpenFreeMap vector tiles implementation of [RrawiMapProvider].
///
/// Circles use the annotation manager (addCircles) — the officially tested
/// path.  Text labels use a custom GeoJSON source + symbol layer so we can
/// specify 'Noto Sans Regular', the font that is actually bundled in the
/// OpenFreeMap liberty style (the annotation SymbolManager hard-codes
/// 'Open Sans Regular' which is absent, causing silent text failures).
///
/// Route lines are inserted *below* the annotation circle layer so that pins
/// always render on top of the route path.
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

  /// Maps annotation Circle.id → tap callback for pin circles.
  final Map<String, VoidCallback?> _circleTapCallbacks = {};

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
    // Tap on a pin circle → fire its registered callback.
    controller.onCircleTapped.add((circle) {
      _circleTapCallbacks[circle.id]?.call();
    });
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

    // The annotation circle layer was already added during manager
    // initialisation (before this callback).  Inserting route lines *below*
    // it means circles always render on top of the route path.
    final circleLayerId = ctrl.circleManager?.layerIds.firstOrNull;
    debugPrint('🗺️  [initLayers] 3 — circleLayerId=$circleLayerId');

    // ── Route sources & layers (below pin circles) ─────────────────────────
    debugPrint('🗺️  [initLayers] 4 — addGeoJsonSource route-*');
    await ctrl.addGeoJsonSource('route-completed', empty);
    await ctrl.addGeoJsonSource('route-upcoming', empty);
    await ctrl.addGeoJsonSource('route-trail', empty);

    // Add in ascending z-order (trail → completed → upcoming → pulse ring).
    // All go below circleLayerId; each subsequent call pushes just below
    // circleLayerId, so the last added ends up closest to the circles.
    debugPrint('🗺️  [initLayers] 5 — addLineLayer route-trail');
    await ctrl.addLineLayer(
        'route-trail',
        'route-trail-layer',
        LineLayerProperties(
          lineColor: '#3A4A3A',
          lineWidth: 3.0,
          lineOpacity: 0.5,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        belowLayerId: circleLayerId);

    debugPrint('🗺️  [initLayers] 6 — addLineLayer route-completed');
    await ctrl.addLineLayer(
        'route-completed',
        'route-completed-layer',
        LineLayerProperties(
          lineColor: '#9A9285',
          lineWidth: 2.5,
          lineOpacity: 0.55,
          lineDasharray: [4.0, 4.0],
          lineCap: 'round',
          lineJoin: 'round',
        ),
        belowLayerId: circleLayerId);

    debugPrint('🗺️  [initLayers] 7 — addLineLayer route-upcoming');
    await ctrl.addLineLayer(
        'route-upcoming',
        'route-upcoming-layer',
        LineLayerProperties(
          lineColor: '#3A4A3A',
          lineWidth: 4.5,
          lineOpacity: 0.7,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        belowLayerId: circleLayerId);

    // ── Pulse ring for current stop (added last → sits just below circles) ──
    debugPrint('🗺️  [initLayers] 8 — addCircleLayer pin-pulse');
    await ctrl.addGeoJsonSource('pin-pulse', empty);
    await ctrl.addCircleLayer(
        'pin-pulse',
        'pin-pulse-layer',
        const CircleLayerProperties(
          circleRadius: 27.0,
          circleColor: '#3A4A3A',
          circleOpacity: 0.20,
        ),
        belowLayerId: circleLayerId);

    // ── User-location source & layers (above circles) ──────────────────────
    debugPrint('🗺️  [initLayers] 9 — addCircleLayer user-loc');
    await ctrl.addGeoJsonSource('user-loc', empty);

    await ctrl.addCircleLayer(
        'user-loc',
        'user-halo-layer',
        const CircleLayerProperties(
          circleRadius: 14.0,
          circleColor: '#4583F0',
          circleOpacity: 0.22,
        ));

    await ctrl.addCircleLayer(
        'user-loc',
        'user-dot-layer',
        const CircleLayerProperties(
          circleRadius: 8.0,
          circleColor: '#4583F0',
          circleStrokeWidth: 3.0,
          circleStrokeColor: '#FFFFFF',
        ));

    // ── Pin number labels ──────────────────────────────────────────────────
    // Three separate sources so each state gets constant (non-expression)
    // colour and size — avoids fragile iOS color-expression handling.
    // textFont uses 'Noto Sans Bold' which IS bundled in the OpenFreeMap
    // liberty style (the annotation SymbolManager hard-codes 'Open Sans
    // Regular' which is absent, causing silent text failures).
    debugPrint('🗺️  [initLayers] 10 — addGeoJsonSource pin-labels-*');
    await ctrl.addGeoJsonSource('pin-labels-upcoming', empty);
    await ctrl.addGeoJsonSource('pin-labels-current', empty);
    await ctrl.addGeoJsonSource('pin-labels-completed', empty);

    debugPrint('🗺️  [initLayers] 11 — addSymbolLayer pin-labels-upcoming');
    await ctrl.addSymbolLayer(
      'pin-labels-upcoming',
      'pin-labels-upcoming-layer',
      SymbolLayerProperties(
        textField: ['get', 'label'],
        textFont: ['Noto Sans Bold'],
        textSize: 12.0,
        textColor: '#1B1915',
        textIgnorePlacement: true,
        textAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAllowOverlap: true,
      ),
      enableInteraction: false,
    );

    debugPrint('🗺️  [initLayers] 12 — addSymbolLayer pin-labels-current');
    await ctrl.addSymbolLayer(
      'pin-labels-current',
      'pin-labels-current-layer',
      SymbolLayerProperties(
        textField: ['get', 'label'],
        textFont: ['Noto Sans Bold'],
        textSize: 14.0,
        textColor: '#F6F1E7',
        textIgnorePlacement: true,
        textAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAllowOverlap: true,
      ),
      enableInteraction: false,
    );

    debugPrint('🗺️  [initLayers] 13 — addSymbolLayer pin-labels-completed');
    await ctrl.addSymbolLayer(
      'pin-labels-completed',
      'pin-labels-completed-layer',
      SymbolLayerProperties(
        textField: ['get', 'label'],
        textFont: ['Noto Sans Bold'],
        textSize: 10.0,
        textColor: '#F6F1E7',
        textIgnorePlacement: true,
        textAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAllowOverlap: true,
      ),
      enableInteraction: false,
    );
    debugPrint('🗺️  [initLayers] 14 — DONE');
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
    if (!_styleLoaded) {
      _pendingRoute = segments;
      return;
    }
    _applyRoute(segments);
  }

  void setPins(List<MapPinData> pins) {
    if (!_styleLoaded) {
      _pendingPins = pins;
      return;
    }
    _applyPins(pins);
  }

  void setUserLocation(RrawiLatLng? position) {
    if (!_styleLoaded) {
      _pendingUserLocation = position;
      return;
    }
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
    final features = matching
        .map((s) => <String, dynamic>{
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates':
                    s.points.map((p) => [p.longitude, p.latitude]).toList(),
              },
              'properties': <String, dynamic>{},
            })
        .toList();
    _mlController?.setGeoJsonSource(sourceId, {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  void _applyPins(List<MapPinData> pins) {
    _applyPinsAsync(pins);
  }

  Future<void> _applyPinsAsync(List<MapPinData> pins) async {
    final ctrl = _mlController;
    if (ctrl == null) return;

    await ctrl.clearCircles();
    _circleTapCallbacks.clear();

    // Always update all sources (clears them when pins is empty).
    _updatePulseSource(ctrl, pins);
    _updateLabelSource(ctrl, 'pin-labels-upcoming', MapPinState.upcoming, pins);
    _updateLabelSource(ctrl, 'pin-labels-current', MapPinState.current, pins);
    _updateLabelSource(ctrl, 'pin-labels-completed', MapPinState.completed, pins);

    if (pins.isEmpty) return;

    // ── Main pin circles ───────────────────────────────────────────────────
    final circleOptionsList = pins.map((p) {
      final double radius;
      final String fill;
      final String stroke;
      final double strokeW;
      switch (p.state) {
        case MapPinState.current:
          radius = 19.0;
          fill = '#3A4A3A';
          stroke = '#3A4A3A'; // no visible border
          strokeW = 0.0;
        case MapPinState.upcoming:
          radius = 13.0;
          fill = '#F6F1E7';
          stroke = '#1B1915';
          strokeW = 1.5;
        case MapPinState.completed:
          radius = 11.0;
          fill = '#3A4A3A';
          stroke = '#F6F1E7';
          strokeW = 2.0;
      }
      return CircleOptions(
        geometry: LatLng(p.location.latitude, p.location.longitude),
        circleRadius: radius,
        circleColor: fill,
        circleStrokeColor: stroke,
        circleStrokeWidth: strokeW,
      );
    }).toList();

    final circles = await ctrl.addCircles(circleOptionsList);
    for (var i = 0; i < circles.length; i++) {
      _circleTapCallbacks[circles[i].id] = pins[i].onTap;
    }
  }

  void _updatePulseSource(MapLibreMapController ctrl, List<MapPinData> pins) {
    final features = pins
        .where((p) => p.state == MapPinState.current)
        .map((p) => <String, dynamic>{
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [p.location.longitude, p.location.latitude],
              },
              'properties': <String, dynamic>{},
            })
        .toList();
    ctrl.setGeoJsonSource('pin-pulse', {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  void _updateLabelSource(
    MapLibreMapController ctrl,
    String sourceId,
    MapPinState state,
    List<MapPinData> allPins,
  ) {
    final features = allPins
        .where((p) => p.state == state)
        .map((p) => <String, dynamic>{
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [p.location.longitude, p.location.latitude],
              },
              'properties': {
                'label': state == MapPinState.completed ? '✓' : '${p.number}',
              },
            })
        .toList();
    ctrl.setGeoJsonSource(sourceId, {
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
      // circles must be below symbols so pin numbers render on top.
      annotationOrder: const [
        AnnotationType.fill,
        AnnotationType.line,
        AnnotationType.circle,
        AnnotationType.symbol,
      ],
      annotationConsumeTapEvents: const [AnnotationType.circle],
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
