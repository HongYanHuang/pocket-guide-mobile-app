import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';

/// Wraps the three session-lifecycle endpoints:
///   POST   /client/tours/{id}/sessions
///   PATCH  /client/tours/{id}/sessions/{sid}/progress
///   POST   /client/tours/{id}/sessions/{sid}/end
///
/// Also provides read access to the history endpoints:
///   GET    /client/history
///   GET    /client/history/{session_id}
///
/// Auth: pass the user's JWT to every call.
/// Progress updates are fire-and-forget — errors are swallowed so a network
/// hiccup never interrupts the tour experience.
class TourSessionService {
  final Dio _dio;

  static const _keySessionId = 'active_session_id';

  TourSessionService(this._dio);

  // ── Session management ─────────────────────────────────────────────────────

  /// Call when the user enters the active map screen.
  /// Persists the session_id so crash-recovery can find it.
  /// Returns the new session_id.
  Future<String> startSession({
    required String tourId,
    required String tourTitle,
    required String city,
    required String citySlug,
    required String language,
    required int durationDays,
    required int totalPois,
    required String accessToken,
  }) async {
    final response = await _dio.post(
      '${ApiService.baseUrl}/client/tours/$tourId/sessions',
      data: {
        'tour_title': tourTitle,
        'city': city,
        'city_slug': citySlug,
        'language': language,
        'duration_days': durationDays,
        'total_pois': totalPois,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final sessionId = response.data['session_id'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionId, sessionId);
    print('📋 Tour session started: $sessionId');
    return sessionId;
  }

  /// Record current playback position. Safe to call frequently — the endpoint
  /// is idempotent and errors are swallowed.
  Future<void> updateProgress({
    required String tourId,
    required String sessionId,
    required String poiId,
    required String poiName,
    required int day,
    required int sectionIndex,
    required double positionSeconds,
    required double totalSeconds,
    required bool completed,
    required String accessToken,
    bool poiVisited = false,
  }) async {
    try {
      final response = await _dio.patch(
        '${ApiService.baseUrl}/client/tours/$tourId/sessions/$sessionId/progress',
        data: {
          'poi_id': poiId,
          'poi_name': poiName,
          'day': day,
          'section_index': sectionIndex,
          'position_seconds': positionSeconds,
          'total_seconds': totalSeconds,
          'completed': completed,
          'poi_visited': poiVisited,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      // pois_completed from the response is useful but not stored here —
      // the caller can read it from response.data if needed in future.
      final poisCompleted = response.data['pois_completed'];
      print('📍 Progress: $poiId §$sectionIndex '
          '${positionSeconds.toStringAsFixed(0)}s '
          '(pois_completed: $poisCompleted)');
    } catch (e) {
      // Never interrupt the tour over a progress update failure.
      print('⚠️  Progress update failed (non-fatal): $e');
    }
  }

  /// Call when the user leaves the map screen (back = ended, finish = completed).
  /// Clears the persisted session_id afterward.
  /// Returns the end-session response (total_duration_seconds, pois_completed, etc.)
  Future<Map<String, dynamic>?> endSession({
    required String tourId,
    required String sessionId,
    required bool userCompleted,
    required int poisCompleted,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiService.baseUrl}/client/tours/$tourId/sessions/$sessionId/end',
        data: {
          'status': userCompleted ? 'completed' : 'ended',
          'pois_completed': poisCompleted,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      print('🏁 Session ended: ${userCompleted ? "completed" : "ended"} '
          '(${response.data['total_duration_seconds']}s)');
      await _clearSessionId();
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Session was already closed (e.g. backend timeout / crash recovery).
        // Safe to ignore.
        print('⚠️  endSession 409 — session already closed, ignoring');
      } else {
        print('⚠️  endSession failed: $e');
      }
      await _clearSessionId();
      return null;
    } catch (e) {
      print('⚠️  endSession error: $e');
      await _clearSessionId();
      return null;
    }
  }

  // ── History ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHistory({
    required String accessToken,
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final response = await _dio.get(
      '${ApiService.baseUrl}/client/history',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (status != null) 'status': status,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getHistoryDetail({
    required String sessionId,
    required String accessToken,
  }) async {
    final response = await _dio.get(
      '${ApiService.baseUrl}/client/history/$sessionId',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Crash recovery ─────────────────────────────────────────────────────────

  /// Returns the session_id saved from the last startSession call, if any.
  /// On next session start the backend auto-abandons it, so no action needed.
  Future<String?> getSavedSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionId);
  }

  Future<void> _clearSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionId);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Derive a URL-safe city slug from a display name.
  /// "Gold Coast" → "gold-coast",  "São Paulo" → "são-paulo"
  static String cityToSlug(String city) =>
      city.trim().toLowerCase().replaceAll(' ', '-');
}
