import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:pocket_guide_mobile/maps/map_provider.dart';
import 'package:pocket_guide_mobile/widgets/map/stop_pin_widget.dart';

// ─── Public provider ──────────────────────────────────────────────────────────

/// MapLibre GL + OpenFreeMap vector tiles implementation of [RrawiMapProvider].
///
/// POC strategy
/// ─────────────
/// • Route polylines → MapLibre GL GeoJSON sources + line layers (GPU-native).
/// • User-location dot → MapLibre GL GeoJSON source + circle layers.
/// • POI pins → Flutter widget overlay positioned via [toScreenLocation].
///   This preserves [StopPinWidget] (photos, pulse ring, etc.) with no
///   bitmap pre-rendering.  Pin positions refresh on every [onCameraIdle].
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

  // Overlay state
  List<MapPinData> _pins = [];
  final Map<String, Offset> _pinScreenPositions = {};

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

    // ── Route GeoJSON sources ─────────────────────────────────────────────────
    await ctrl.addGeoJsonSource('route-completed', empty);
    await ctrl.addGeoJsonSource('route-upcoming', empty);
    await ctrl.addGeoJsonSource('route-trail', empty);

    // Completed segment: dashed, 30 % opacity rawiInk
    await ctrl.addLineLayer(
      'route-completed',
      'route-completed-layer',
      LineLayerProperties(
        lineColor: '#1B1915',
        lineWidth: 2.5,
        lineOpacity: 0.3,
        lineDasharray: [8.0, 6.0],
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    // Upcoming segment: solid accent, 70 %
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
    );

    // GPS trail: lighter accent
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
    );

    // ── User-location GeoJSON source & layers ─────────────────────────────────
    await ctrl.addGeoJsonSource('user-loc', empty);

    // Outer halo
    await ctrl.addCircleLayer(
      'user-loc',
      'user-halo-layer',
      const CircleLayerProperties(
        circleRadius: 14.0,
        circleColor: '#4583F0',
        circleOpacity: 0.22,
      ),
    );

    // Core dot with white stroke
    await ctrl.addCircleLayer(
      'user-loc',
      'user-dot-layer',
      const CircleLayerProperties(
        circleRadius: 8.0,
        circleColor: '#4583F0',
        circleStrokeWidth: 3.0,
        circleStrokeColor: '#FFFFFF',
      ),
    );
  }

  // ── State mutators (called by _OpenFreeMapController) ─────────────────────

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
    _pins = pins;
    _recalculateScreenPositions();
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

  Future<void> _recalculateScreenPositions() async {
    if (_mlController == null || !mounted) return;
    final updated = <String, Offset>{};
    for (final pin in _pins) {
      try {
        final pt = await _mlController!.toScreenLocation(
          LatLng(pin.location.latitude, pin.location.longitude),
        );
        updated[pin.id] = Offset(pt.x.toDouble(), pt.y.toDouble());
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _pinScreenPositions
          ..clear()
          ..addAll(updated);
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Base map (vector tiles from OpenFreeMap) ──────────────────────────
        MapLibreMap(
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
          onCameraIdle: () {
            final wasGesture = !_programmaticMove;
            _programmaticMove = false;
            _recalculateScreenPositions();
            widget.onCameraIdle(wasGesture);
          },
        ),

        // ── POI pin overlays ──────────────────────────────────────────────────
        // Centre each 72×72 container on the pin's screen coordinate.
        // Matches the containerSize=72 anchor used in the old flutter_map setup.
        ..._pins.map((pin) {
          final pos = _pinScreenPositions[pin.id];
          if (pos == null) return const SizedBox.shrink();
          return Positioned(
            key: ValueKey('pin-${pin.id}'),
            left: pos.dx - 36,
            top: pos.dy - 36,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: StopPinWidget(
                  number: pin.number,
                  state: _toStopPinState(pin.state),
                  photoUrl: pin.photoUrl,
                  onTap: pin.onTap,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  StopPinState _toStopPinState(MapPinState s) => switch (s) {
    MapPinState.upcoming  => StopPinState.upcoming,
    MapPinState.current   => StopPinState.current,
    MapPinState.completed => StopPinState.completed,
  };
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
