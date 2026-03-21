import 'package:pocket_guide_mobile/services/tour_progress_service.dart';
import 'package:pocket_guide_mobile/models/tour_progress.dart';

class ProgressUpdate {
  final String poiId;
  final int day;
  final bool completed;

  ProgressUpdate({
    required this.poiId,
    required this.day,
    required this.completed,
  });
}

class ProgressManager {
  final TourProgressService _progressService;
  final String _tourId;

  TourProgress? _currentProgress;
  final List<ProgressUpdate> _offlineQueue = [];
  bool _isUploading = false;

  ProgressManager({
    required TourProgressService progressService,
    required String tourId,
  })  : _progressService = progressService,
        _tourId = tourId;

  /// Get current progress
  TourProgress? get currentProgress => _currentProgress;

  /// Load progress from backend
  Future<TourProgress?> loadProgress({String language = 'en'}) async {
    try {
      print('📊 Loading tour progress from backend...');
      print('   Tour ID: $_tourId');
      print('   Language: $language');

      _currentProgress = await _progressService.getTourProgress(
        tourId: _tourId,
        language: language,
      );

      print('✅ Progress loaded: ${_currentProgress!.completedCount}/${_currentProgress!.totalPois} POIs completed');
      print('   POIs in progress:');
      for (final completion in _currentProgress!.completions) {
        print('     - ${completion.poiId} (day ${completion.day}): ${completion.completed}');
      }

      // Process offline queue if any
      if (_offlineQueue.isNotEmpty) {
        print('📤 Processing ${_offlineQueue.length} offline updates...');
        await _syncOfflineQueue();
      }

      return _currentProgress;
    } catch (e) {
      final errorMessage = e.toString();
      print('❌ Error loading progress: $e');

      // Handle 404 - no progress data exists yet for this tour
      if (errorMessage.contains('Tour not found') || errorMessage.contains('404')) {
        print('ℹ️  No progress data exists yet - this is expected for new tours');
        print('ℹ️  Backend will create progress data when you mark first POI as complete');
        print('ℹ️  Treating all POIs as incomplete for now');

        // Create empty progress (will be populated after first POI update)
        _currentProgress = null; // Keep null until first update creates it

        return null; // Returning null is OK - markers will show as grey (incomplete)
      }

      print('   This could be due to:');
      print('   - Invalid or expired JWT token (if 401)');
      print('   - Network connectivity issues');
      print('   - User does not have access to this tour (if 403)');
      return null;
    }
  }

  /// Mark POI as complete/incomplete
  Future<bool> updatePOICompletion({
    required String poiId,
    required int day,
    required bool completed,
  }) async {
    final wasProgressNull = _currentProgress == null;

    // Update local state immediately for responsive UI
    if (_currentProgress != null) {
      final index = _currentProgress!.completions.indexWhere(
        (c) => c.poiId == poiId && c.day == day,
      );

      if (index != -1) {
        final updatedCompletion = POICompletionStatus(
          poiId: poiId,
          poiName: _currentProgress!.completions[index].poiName,
          day: day,
          completed: completed,
          completedAt: completed ? DateTime.now() : null,
        );

        final completions = List<POICompletionStatus>.from(_currentProgress!.completions);
        completions[index] = updatedCompletion;

        final completedCount = completions.where((c) => c.completed).length;

        _currentProgress = TourProgress(
          tourId: _currentProgress!.tourId,
          completions: completions,
          totalPois: _currentProgress!.totalPois,
          completedCount: completedCount,
          completionPercentage: (completedCount / _currentProgress!.totalPois) * 100,
        );
      }
    }

    // Try to sync to backend immediately
    try {
      print('📤 Updating POI progress: $poiId (day $day) -> ${completed ? "completed" : "incomplete"}');

      await _progressService.updatePOIProgress(
        tourId: _tourId,
        poiId: poiId,
        day: day,
        completed: completed,
      );

      print('✅ POI progress updated successfully');

      // If this was the first update (progress was null), reload progress to get full data
      if (wasProgressNull) {
        print('ℹ️  First POI update - reloading progress from backend...');
        await loadProgress();
      }

      return true;
    } catch (e) {
      print('❌ Failed to update progress, adding to offline queue: $e');

      // Add to offline queue for retry
      _offlineQueue.add(ProgressUpdate(
        poiId: poiId,
        day: day,
        completed: completed,
      ));

      return false;
    }
  }

  /// Check if a POI is completed
  bool isPOICompleted(String poiId, int day) {
    if (_currentProgress == null) {
      print('⚠️  isPOICompleted: No progress loaded yet');
      return false;
    }

    print('🔍 Checking completion for POI: $poiId (day $day)');
    print('   Available POIs in progress:');
    for (final c in _currentProgress!.completions) {
      print('     - ${c.poiId} (day ${c.day}): ${c.completed}');
    }

    final completion = _currentProgress!.completions.firstWhere(
      (c) => c.poiId == poiId && c.day == day,
      orElse: () {
        print('   ❌ POI not found in progress data, defaulting to incomplete');
        return POICompletionStatus(
          poiId: poiId,
          poiName: '',
          day: day,
          completed: false,
        );
      },
    );

    print('   ✅ Result: ${completion.completed}');
    return completion.completed;
  }

  /// Get completion percentage
  double getCompletionPercentage() {
    if (_currentProgress == null) return 0.0;
    return _currentProgress!.completionPercentage;
  }

  /// Sync offline queue
  Future<void> _syncOfflineQueue() async {
    if (_isUploading || _offlineQueue.isEmpty) return;

    _isUploading = true;

    print('📤 Syncing ${_offlineQueue.length} offline progress updates...');

    final updates = List<ProgressUpdate>.from(_offlineQueue);

    for (final update in updates) {
      try {
        await _progressService.updatePOIProgress(
          tourId: _tourId,
          poiId: update.poiId,
          day: update.day,
          completed: update.completed,
        );

        _offlineQueue.remove(update);
        print('✅ Synced offline update for ${update.poiId}');
      } catch (e) {
        print('❌ Failed to sync update for ${update.poiId}: $e');
        break; // Stop on first failure, will retry later
      }
    }

    _isUploading = false;

    if (_offlineQueue.isEmpty) {
      print('✅ All offline updates synced');
    } else {
      print('⚠️  ${_offlineQueue.length} updates still in offline queue');
    }
  }

  /// Force sync offline queue
  Future<void> forceSyncOfflineQueue() async {
    await _syncOfflineQueue();
  }

  /// Get offline queue size
  int get offlineQueueSize => _offlineQueue.length;

  /// Dispose resources
  void dispose() {
    // Sync any remaining offline updates
    if (_offlineQueue.isNotEmpty) {
      print('⚠️  ${_offlineQueue.length} progress updates not synced on dispose');
    }
  }
}
