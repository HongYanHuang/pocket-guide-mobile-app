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

    // Apply rawi palette overrides to the base Liberty style before we add
    // our own layers — keeps everything in one initialisation pass.
    debugPrint('🗺️  [initLayers] 1 — applyStyleOverrides');
    await _applyStyleOverrides(ctrl);

    // ── Path casing (Liberty has no native casing for non-bridge paths) ───
    // Adds a hairline outline behind pedestrian paths/footways so they read
    // clearly against pale park fills.  Uses old-style any/== filters instead
    // of ["in", ...] because NSPredicate(mglJSONObject:) in MapLibre 6.26 can
    // throw an ObjC exception (not catchable by Swift do-catch) when the
    // legacy "in" format is used, crashing the app.
    debugPrint('🗺️  [initLayers] 2 — addLineLayer path-casing');
    await ctrl.addLineLayer(
      'openmaptiles',
      'path-casing',
      const LineLayerProperties(
        lineColor: 'rgba(27,25,21,0.14)',
        lineWidth: 3.0,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      belowLayerId: 'road_path_pedestrian',
      sourceLayer: 'transportation',
      filter: ['any',
        ['==', 'class', 'path'],
        ['==', 'class', 'pedestrian'],
        ['==', 'class', 'footway'],
        ['==', 'class', 'cycleway'],
      ],
    );

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

  // ── Liberty base-map style overrides ─────────────────────────────────────

  /// Overrides OpenFreeMap Liberty colours to match the rawi paper/ink palette.
  ///
  /// Called once in [_initLayers] immediately after style load.  Each call
  /// uses [setLayerProperties] (paint overrides) or [setLayerVisibility]
  /// (show/hide layers).  Layers missing in a future Liberty version are
  /// silently skipped via [_trySet].
  Future<void> _applyStyleOverrides(MapLibreMapController ctrl) async {
    // ── Base & land ──────────────────────────────────────────────────────
    // Ground #DCD0B6 (~0.79 luminance) vs roads #FFFFFF (~1.0).
    // The ~0.21 gap gives white roads strong contrast as bright ribbons.
    // BackgroundLayerProperties is absent from maplibre_gl 0.26; use inline
    // implementation — toJson() is all setLayerProperties needs.
    await _trySet(ctrl, 'background',
        _RawLayerProperties({'background-color': '#DCD0B6'}));

    await _trySet(ctrl, 'landuse_residential',
        const FillLayerProperties(fillColor: '#DCD0B6'));

    await _trySet(ctrl, 'landcover_wood',
        const FillLayerProperties(fillColor: 'hsla(75,18%,68%,0.55)'));

    // Parks/grass keep a greenish tint to read as parks, just slightly darker.
    await _trySet(ctrl, 'landcover_grass',
        const FillLayerProperties(fillColor: '#CBD2B0'));

    await _trySet(ctrl, 'park',
        const FillLayerProperties(
          fillColor: '#CBD2B0',
          fillOutlineColor: 'rgba(58,74,58,0.25)',
        ));

    await _trySet(ctrl, 'park_outline',
        const LineLayerProperties(lineColor: 'rgba(58,74,58,0.18)'));

    // ── Water ────────────────────────────────────────────────────────────
    // Warm slate-blue — clearly distinct from the tan ground.
    await _trySet(ctrl, 'water',
        const FillLayerProperties(fillColor: '#AEC3C8'));

    for (final id in ['waterway_river', 'waterway_other', 'waterway_tunnel']) {
      await _trySet(ctrl, id,
          const LineLayerProperties(lineColor: '#A8BBC0'));
    }

    // Water labels — halo matches ground #DCD0B6.
    for (final id in [
      'waterway_line_label',
      'water_name_point_label',
      'water_name_line_label',
    ]) {
      await _trySet(ctrl, id,
          const SymbolLayerProperties(
            textColor: '#6B6459',
            textHaloColor: '#DCD0B6',
            textHaloWidth: 1.5,
          ));
      try { await ctrl.setLayerVisibility(id, true); } catch (_) {}
    }

    // ── Roads — major fill (white ribbons on tan ground) ─────────────────
    // Motorway tinted slightly warm so it reads as "bigger" than plain white.
    await _trySet(ctrl, 'road_motorway',
        const LineLayerProperties(lineColor: '#F5EFE0'));

    for (final id in [
      'road_trunk_primary', 'road_secondary_tertiary',
      'road_link', 'road_motorway_link',
      'bridge_trunk_primary', 'bridge_secondary_tertiary',
      'bridge_link', 'bridge_motorway', 'bridge_motorway_link',
      'tunnel_trunk_primary', 'tunnel_secondary_tertiary',
      'tunnel_link', 'tunnel_motorway', 'tunnel_motorway_link',
    ]) {
      await _trySet(ctrl, id,
          const LineLayerProperties(lineColor: '#FFFFFF'));
    }

    // ── Roads — minor fill ───────────────────────────────────────────────
    for (final id in [
      'road_minor', 'road_service_track', 'road_path_pedestrian',
      'bridge_street', 'bridge_service_track', 'bridge_path_pedestrian',
      'tunnel_minor', 'tunnel_service_track', 'tunnel_path_pedestrian',
    ]) {
      await _trySet(ctrl, id,
          const LineLayerProperties(lineColor: '#FFFFFF'));
    }

    // ── Roads — casings ──────────────────────────────────────────────────
    // Solid near-black #3C3730 casings: dark enough to frame white fills
    // against the tan ground without the casing disappearing at opacity.
    // Major roads get 2 px casing each side; minor roads get 1.5 px.
    for (final id in [
      'road_motorway_casing', 'road_trunk_primary_casing',
      'road_secondary_tertiary_casing', 'road_link_casing',
      'road_motorway_link_casing',
      'bridge_motorway_casing', 'bridge_trunk_primary_casing',
      'bridge_secondary_tertiary_casing', 'bridge_link_casing',
      'bridge_motorway_link_casing',
      'tunnel_motorway_casing', 'tunnel_trunk_primary_casing',
      'tunnel_secondary_tertiary_casing', 'tunnel_link_casing',
      'tunnel_motorway_link_casing',
    ]) {
      await _trySet(ctrl, id,
          const LineLayerProperties(lineColor: '#3C3730', lineWidth: 2.0));
    }

    for (final id in [
      'road_minor_casing', 'road_service_track_casing',
      'bridge_street_casing', 'bridge_path_pedestrian_casing',
      'bridge_service_track_casing',
      'tunnel_street_casing', 'tunnel_service_track_casing',
    ]) {
      await _trySet(ctrl, id,
          const LineLayerProperties(lineColor: '#3C3730', lineWidth: 1.5));
    }

    // ── Rail ─────────────────────────────────────────────────────────────
    for (final id in [
      'road_major_rail', 'road_transit_rail',
      'road_major_rail_hatching', 'road_transit_rail_hatching',
      'bridge_major_rail', 'bridge_transit_rail',
      'bridge_major_rail_hatching', 'bridge_transit_rail_hatching',
      'tunnel_major_rail', 'tunnel_transit_rail',
      'tunnel_major_rail_hatching', 'tunnel_transit_rail_hatching',
    ]) {
      await _trySet(ctrl, id,
          const LineLayerProperties(lineColor: '#C9C2B4'));
    }

    // ── Buildings ────────────────────────────────────────────────────────
    // Slightly darker than ground (#D2C6AE < #DCD0B6) so footprints read,
    // but quieter than roads so they don't compete with the street network.
    // Outline uses #3C3730 at ~25% alpha (hex AA = 0x40).
    await _trySet(ctrl, 'building',
        const FillLayerProperties(
          fillColor: '#D2C6AE',
          fillOutlineColor: '#3C373040',
        ));

    // 3D extrusion at fixed 0.65 opacity — consistent depth without fading.
    await _trySet(ctrl, 'building-3d',
        const FillExtrusionLayerProperties(
          fillExtrusionColor: '#D2C6AE',
          fillExtrusionOpacity: 0.65,
        ));

    // ── Place & water labels — ink on tan ground, ensure visible ─────────
    // Halo colour matches ground #DCD0B6.
    for (final id in [
      'label_city', 'label_city_capital',
      'label_town', 'label_village',
      'label_state', 'label_other',
      'label_country_1', 'label_country_2', 'label_country_3',
    ]) {
      await _trySet(ctrl, id,
          const SymbolLayerProperties(
            textColor: '#1B1915',
            textHaloColor: '#DCD0B6',
            textHaloWidth: 1.5,
          ));
      try { await ctrl.setLayerVisibility(id, true); } catch (_) {}
    }

    // Road name labels — muted ink-4, halo matches ground.
    for (final id in [
      'highway-name-major', 'highway-name-minor', 'highway-name-path',
    ]) {
      await _trySet(ctrl, id,
          const SymbolLayerProperties(
            textColor: '#9A9285',
            textHaloColor: '#DCD0B6',
            textHaloWidth: 1.5,
          ));
      try { await ctrl.setLayerVisibility(id, true); } catch (_) {}
    }

    for (final id in ['airport']) {
      await _trySet(ctrl, id,
          const SymbolLayerProperties(
            textHaloColor: '#DCD0B6',
            textHaloWidth: 1.5,
          ));
    }

    // ── Hide clutter ─────────────────────────────────────────────────────
    // Transit/POI icons compete with numbered stop pins — hide them.
    // Oneway arrows are pedestrian noise on a walking tour.
    for (final id in [
      'poi_transit', 'poi_r1', 'poi_r7', 'poi_r20',
      'road_one_way_arrow', 'road_one_way_arrow_opposite',
    ]) {
      try { await ctrl.setLayerVisibility(id, false); } catch (_) {}
    }
  }

  /// Calls [setLayerProperties] and silently swallows "layer not found"
  /// errors so that future Liberty style changes don't crash the app.
  Future<void> _trySet(
    MapLibreMapController ctrl,
    String layerId,
    LayerProperties props,
  ) async {
    try {
      await ctrl.setLayerProperties(layerId, props);
    } catch (_) {}
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Thin [LayerProperties] wrapper for layer types that maplibre_gl 0.26 does
/// not expose a typed class for (e.g. the `background` layer).
///
/// [setLayerProperties] only calls [toJson] on the properties object, so
/// passing a raw paint-property map is perfectly safe.
class _RawLayerProperties implements LayerProperties {
  const _RawLayerProperties(this._paint);
  final Map<String, dynamic> _paint;

  @override
  Map<String, dynamic> toJson({bool skipNulls = true}) => _paint;
}
