import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  bool _isTracking = false;

  // Callback for location updates
  Function(Position)? onLocationUpdate;

  // Get current location status
  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;

  /// Check if location permissions are granted
  Future<bool> hasPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Request location permissions
  Future<bool> requestPermission() async {
    print('📍 Requesting location permission...');

    final status = await Permission.location.request();

    if (status.isGranted) {
      print('✅ Location permission granted');
      return true;
    } else if (status.isDenied) {
      print('❌ Location permission denied');
      return false;
    } else if (status.isPermanentlyDenied) {
      print('❌ Location permission permanently denied');
      // User needs to enable in settings
      return false;
    }

    return false;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Start tracking location
  /// [isBackground] - true for 30s intervals (background), false for 5s intervals (active)
  Future<bool> startTracking({bool isBackground = false}) async {
    if (_isTracking) {
      print('⚠️  Location tracking already active');
      return true;
    }

    // Check if location service is enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Location services are disabled');
      return false;
    }

    // Check/request permissions
    final hasPermission = await this.hasPermission();
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        print('❌ Cannot start tracking: Permission denied');
        return false;
      }
    }

    try {
      // Configure location settings
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Only update if moved 10+ meters
        timeLimit: Duration(seconds: isBackground ? 30 : 5),
      );

      print('📍 Starting location tracking (${isBackground ? "30s background" : "5s active"})...');

      // Get initial position
      try {
        _lastPosition = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
        print('✅ Initial location: ${_lastPosition!.latitude}, ${_lastPosition!.longitude}');

        // Notify callback
        if (onLocationUpdate != null && _lastPosition != null) {
          onLocationUpdate!(_lastPosition!);
        }
      } catch (e) {
        print('⚠️  Could not get initial position: $e');
      }

      // Start listening to position stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastPosition = position;
          print('📍 Location update: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');

          // Notify callback
          if (onLocationUpdate != null) {
            onLocationUpdate!(position);
          }
        },
        onError: (error) {
          print('❌ Location stream error: $error');
        },
      );

      _isTracking = true;
      return true;
    } catch (e) {
      print('❌ Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop tracking location
  void stopTracking() {
    if (!_isTracking) {
      return;
    }

    print('🛑 Stopping location tracking...');

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;

    print('✅ Location tracking stopped');
  }

  /// Get current position once (without streaming)
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location service is enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return null;
      }

      // Check permissions
      final hasPermission = await this.hasPermission();
      if (!hasPermission) {
        print('❌ Location permission not granted');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _lastPosition = position;
      return position;
    } catch (e) {
      print('❌ Error getting current position: $e');
      return null;
    }
  }

  /// Calculate distance between two positions in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Clean up resources
  void dispose() {
    stopTracking();
  }
}
