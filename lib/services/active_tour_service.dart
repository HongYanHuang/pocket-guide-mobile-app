import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's active tour across app kills/restarts.
///
/// When iOS terminates the app under memory pressure, Flutter's navigation
/// stack is destroyed. This service saves enough state to restore the user
/// directly to the active tour map screen on next launch, making the kill
/// invisible to the user.
///
/// Storage keys are intentionally minimal — only what's needed to resume:
///   active_tour_id   → tourId string (used to fetch fresh TourDetail)
///   active_tour_day  → last selected day (int)
///   active_tour_at   → ISO-8601 timestamp of when tour was started
class ActiveTourService {
  static const _keyTourId = 'active_tour_id';
  static const _keyDay = 'active_tour_day';
  static const _keyStartedAt = 'active_tour_at';

  // Tours inactive for longer than this are not auto-resumed (user likely
  // finished without tapping Finish, e.g. phone died).
  static const _maxAgeDays = 1;

  /// Save active tour state. Call when the user starts a tour.
  Future<void> saveActiveTour({
    required String tourId,
    required int day,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTourId, tourId);
    await prefs.setInt(_keyDay, day);
    await prefs.setString(_keyStartedAt, DateTime.now().toIso8601String());
    print('💾 Active tour saved: $tourId (day $day)');
  }

  /// Update the persisted day when the user switches days mid-tour.
  Future<void> updateActiveDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyTourId)) {
      await prefs.setInt(_keyDay, day);
    }
  }

  /// Clear active tour state. Call when the user explicitly finishes the tour.
  Future<void> clearActiveTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTourId);
    await prefs.remove(_keyDay);
    await prefs.remove(_keyStartedAt);
    print('🗑️  Active tour cleared');
  }

  /// Returns the saved tour ID if a recent active tour exists, otherwise null.
  Future<String?> getActiveTourId() async {
    final prefs = await SharedPreferences.getInstance();
    final tourId = prefs.getString(_keyTourId);
    if (tourId == null) return null;

    // Expire stale sessions so the user isn't dropped into a tour from days ago
    final startedAt = prefs.getString(_keyStartedAt);
    if (startedAt != null) {
      final started = DateTime.tryParse(startedAt);
      if (started != null) {
        final age = DateTime.now().difference(started);
        if (age.inDays >= _maxAgeDays) {
          print('⏰ Active tour session expired (${age.inHours}h old) — clearing');
          await clearActiveTour();
          return null;
        }
      }
    }

    return tourId;
  }

  /// Returns the last saved day (defaults to 1 if not set).
  Future<int> getActiveDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDay) ?? 1;
  }
}
