import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  bool _isTracking = false;
  bool _isBackgroundMode = false;

  // Callback for location updates
  Function(Position)? onLocationUpdate;

  // Coordinate batching for background uploads
  final List<_CoordinatePoint> _coordinateBatch = [];
  Timer? _batchUploadTimer;
  Function(List<_CoordinatePoint>)? onBatchUpload;

  // Get current location status
  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;

  /// Check if location permissions are granted
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  /// Request location permissions
  Future<bool> requestPermission() async {
    print('📍 Requesting location permission...');

    final permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      print('✅ Location permission granted: $permission');
      return true;
    } else if (permission == LocationPermission.denied) {
      print('❌ Location permission denied');
      return false;
    } else if (permission == LocationPermission.deniedForever) {
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

  /// Switch to background mode (30s intervals with batching)
  void enterBackgroundMode() {
    if (!_isTracking || _isBackgroundMode) return;

    print('🌙 Entering background location tracking mode...');
    _isBackgroundMode = true;

    // Stop current tracking
    _positionSubscription?.cancel();

    // Restart with background settings (30s intervals)
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      timeLimit: const Duration(seconds: 30),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastPosition = position;
        print('📍 [Background] Location: ${position.latitude}, ${position.longitude}');

        // Add to batch
        _addCoordinateToBatch(position);

        // Still notify callback for UI updates
        if (onLocationUpdate != null) {
          onLocationUpdate!(position);
        }
      },
      onError: (error) {
        print('❌ Background location error: $error');
      },
    );

    // Start batch upload timer (every 1 minute)
    _startBatchUploadTimer();

    print('✅ Background mode active (30s intervals, 1min batches)');
  }

  /// Switch to foreground mode (5s intervals with immediate upload)
  void enterForegroundMode() {
    if (!_isTracking || !_isBackgroundMode) return;

    print('☀️ Entering foreground location tracking mode...');
    _isBackgroundMode = false;

    // Upload any stored coordinates first
    _uploadBatch();

    // Stop batch timer
    _batchUploadTimer?.cancel();
    _batchUploadTimer = null;

    // Stop current tracking
    _positionSubscription?.cancel();

    // Restart with foreground settings (5s intervals)
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      timeLimit: const Duration(seconds: 5),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastPosition = position;
        print('📍 [Foreground] Location: ${position.latitude}, ${position.longitude}');

        // Immediate callback for real-time updates
        if (onLocationUpdate != null) {
          onLocationUpdate!(position);
        }
      },
      onError: (error) {
        print('❌ Foreground location error: $error');
      },
    );

    print('✅ Foreground mode active (5s intervals, immediate updates)');
  }

  /// Add coordinate to batch
  void _addCoordinateToBatch(Position position) {
    _coordinateBatch.add(_CoordinatePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now().toUtc(),
      accuracy: position.accuracy,
      altitude: position.altitude,
      heading: position.heading,
      speed: position.speed,
    ));

    print('📦 Batch size: ${_coordinateBatch.length} coordinates');
  }

  /// Start batch upload timer (uploads every 1 minute)
  void _startBatchUploadTimer() {
    _batchUploadTimer?.cancel();
    _batchUploadTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _uploadBatch();
    });
  }

  /// Upload batched coordinates
  void _uploadBatch() {
    if (_coordinateBatch.isEmpty) {
      print('📦 No coordinates to upload');
      return;
    }

    print('📤 Uploading batch: ${_coordinateBatch.length} coordinates');

    // Callback to upload coordinates
    if (onBatchUpload != null) {
      final batch = List<_CoordinatePoint>.from(_coordinateBatch);
      onBatchUpload!(batch);
    }

    // Clear batch after upload
    _coordinateBatch.clear();
  }

  /// Clean up resources
  void dispose() {
    _batchUploadTimer?.cancel();
    _uploadBatch(); // Upload remaining coordinates
    stopTracking();
  }
}

/// Coordinate point with metadata
class _CoordinatePoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double altitude;
  final double heading;
  final double speed;

  _CoordinatePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.altitude,
    required this.heading,
    required this.speed,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'altitude': altitude,
      'heading': heading,
      'speed': speed,
    };
  }
}
