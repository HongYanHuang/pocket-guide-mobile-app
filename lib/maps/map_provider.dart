import 'package:flutter/material.dart';

/// Coordinate wrapper — decouples callers from any map SDK's LatLng type.
class RrawiLatLng {
  const RrawiLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Style for a route line segment.
enum RouteSegmentStyle {
  /// Dashed, muted — portion the user has already visited
  completed,

  /// Solid accent colour — upcoming portion of the route
  upcoming,

  /// Semi-transparent accent — GPS trail the user has actually walked
  trail,
}

/// A single polyline segment to draw on the map.
class MapRouteSegment {
  const MapRouteSegment({
    required this.points,
    required this.style,
  });
  final List<RrawiLatLng> points;
  final RouteSegmentStyle style;
}

/// Rendering state for a POI pin.
enum MapPinState { upcoming, current, completed }

/// All data needed to display a single POI pin on the map.
class MapPinData {
  const MapPinData({
    required this.id,
    required this.location,
    required this.number,
    required this.state,
    this.photoUrl,
    this.onTap,
  });

  final String id;
  final RrawiLatLng location;
  final int number;
  final MapPinState state;

  /// Remote cover-image URL. Null → circle-only pin.
  final String? photoUrl;
  final VoidCallback? onTap;
}

// ─── Abstract interfaces ──────────────────────────────────────────────────────

/// Imperative handle for controlling the map after it has initialised.
abstract class RrawiMapController {
  /// Smoothly move the camera to [center] at [zoom] (defaults to current zoom).
  Future<void> moveCamera(RrawiLatLng center, {double? zoom});

  /// Current camera zoom level (falls back to 14.0 if unknown).
  double get currentZoom;

  /// Replace all route polylines. Pass an empty list to clear.
  void updateRoute(List<MapRouteSegment> segments);

  /// Replace all POI pins. Pass an empty list to clear.
  void updatePins(List<MapPinData> pins);

  /// Show or hide the user-location dot. Pass null to hide.
  void updateUserLocation(RrawiLatLng? position);

  void dispose();
}

/// Factory that builds the map Flutter widget and supplies a controller.
/// Implement this to add a new map SDK (Mapbox, Google Maps, …).
abstract class RrawiMapProvider {
  Widget buildMap({
    required BuildContext context,
    required RrawiLatLng initialCenter,
    required double initialZoom,

    /// Called once when the map style is loaded and the controller is ready.
    required void Function(RrawiMapController controller) onReady,

    /// Called when the camera finishes moving.
    /// [wasGesture] is true when the move was user-initiated (touch/drag),
    /// false when it was a programmatic [RrawiMapController.moveCamera] call.
    required void Function(bool wasGesture) onCameraIdle,
  });
}
