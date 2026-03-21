import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:pocket_guide_mobile/models/gps_trail_point.dart';
import 'package:pocket_guide_mobile/services/tour_progress_service.dart';

class TrailUploadManager {
  final TourProgressService _progressService;
  final String _tourId;

  final List<GPSPoint> _buffer = [];
  final List<GPSPoint> _offlineQueue = [];
  DateTime? _lastUpload;
  Timer? _uploadTimer;
  bool _isUploading = false;

  // Configuration
  static const int _pointsThreshold = 20; // Upload when 20+ points collected
  static const Duration _timeThreshold = Duration(minutes: 1); // Upload every 1 minute
  static const int _maxBatchSize = 100; // Max points per request
  static const double _accuracyThreshold = 50.0; // Filter out points with accuracy > 50m
  static const double _minimumDistance = 10.0; // Minimum distance between points in meters

  GPSPoint? _lastRecordedPoint;

  TrailUploadManager({
    required TourProgressService progressService,
    required String tourId,
  })  : _progressService = progressService,
        _tourId = tourId;

  /// Start automatic upload timer
  void start() {
    print('🚀 TrailUploadManager started for tour: $_tourId');

    // Set up periodic timer to check if upload is needed
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndUpload();
    });
  }

  /// Stop automatic upload timer
  void stop() {
    print('🛑 TrailUploadManager stopped');

    _uploadTimer?.cancel();
    _uploadTimer = null;

    // Upload any remaining points
    if (_buffer.isNotEmpty) {
      _uploadBatch();
    }
  }

  /// Add a GPS point to the buffer
  void addPoint(Position position) {
    // Filter out inaccurate points
    if (position.accuracy > _accuracyThreshold) {
      print('⚠️  Skipping inaccurate point: ${position.accuracy}m accuracy');
      return;
    }

    // Filter out points that are too close to the last recorded point
    if (_lastRecordedPoint != null) {
      final distance = _calculateDistance(
        _lastRecordedPoint!.latitude,
        _lastRecordedPoint!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance < _minimumDistance) {
        // print('⚠️  Skipping point: only ${distance.toStringAsFixed(1)}m from last point');
        return;
      }
    }

    final gpsPoint = GPSPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
    );

    _buffer.add(gpsPoint);
    _lastRecordedPoint = gpsPoint;

    print('📍 Trail point added: ${_buffer.length} points in buffer');

    // Check if upload is needed
    _checkAndUpload();
  }

  /// Check if upload should be triggered and upload if needed
  void _checkAndUpload() {
    if (_buffer.isEmpty && _offlineQueue.isEmpty) {
      return;
    }

    final shouldUploadByCount = _buffer.length >= _pointsThreshold;
    final shouldUploadByTime = _lastUpload == null ||
        DateTime.now().difference(_lastUpload!) >= _timeThreshold;

    if (shouldUploadByCount || shouldUploadByTime) {
      _uploadBatch();
    }
  }

  /// Upload batch of points to backend
  Future<void> _uploadBatch() async {
    if (_isUploading) {
      print('⚠️  Upload already in progress, skipping...');
      return;
    }

    if (_buffer.isEmpty && _offlineQueue.isEmpty) {
      return;
    }

    _isUploading = true;

    try {
      // Combine offline queue and buffer (prioritize offline queue)
      final pointsToUpload = <GPSPoint>[
        ..._offlineQueue,
        ..._buffer,
      ];

      if (pointsToUpload.isEmpty) {
        _isUploading = false;
        return;
      }

      // Take up to 100 points
      final batch = pointsToUpload.take(_maxBatchSize).toList();

      print('📤 Uploading ${batch.length} trail points to backend...');

      await _progressService.uploadTrailPoints(
        tourId: _tourId,
        points: batch,
      );

      print('✅ Trail upload successful: ${batch.length} points');

      // Clear uploaded points from offline queue and buffer
      if (_offlineQueue.length >= batch.length) {
        _offlineQueue.removeRange(0, batch.length);
      } else {
        final remainingCount = batch.length - _offlineQueue.length;
        _offlineQueue.clear();
        _buffer.removeRange(0, remainingCount);
      }

      _lastUpload = DateTime.now();
    } catch (e) {
      print('❌ Trail upload failed: $e');

      // Move buffer to offline queue for retry
      _offlineQueue.addAll(_buffer);
      _buffer.clear();

      print('📦 Moved ${_offlineQueue.length} points to offline queue for retry');
    } finally {
      _isUploading = false;
    }
  }

  /// Force upload all buffered points immediately
  Future<void> forceUpload() async {
    if (_buffer.isEmpty && _offlineQueue.isEmpty) {
      print('ℹ️  No points to upload');
      return;
    }

    print('🚀 Force uploading all buffered points...');
    await _uploadBatch();
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Get current buffer size
  int get bufferSize => _buffer.length;

  /// Get offline queue size
  int get offlineQueueSize => _offlineQueue.length;

  /// Get total points (buffer + offline queue)
  int get totalPoints => _buffer.length + _offlineQueue.length;

  /// Dispose resources
  void dispose() {
    stop();
  }
}
