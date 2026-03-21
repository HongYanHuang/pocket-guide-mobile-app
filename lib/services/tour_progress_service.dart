import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pocket_guide_mobile/models/tour_progress.dart';
import 'package:pocket_guide_mobile/models/gps_trail_point.dart';
import 'package:pocket_guide_mobile/models/progress_update.dart';
import 'package:pocket_guide_mobile/models/trail_upload.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';

class TourProgressService {
  final String baseUrl = ApiService.baseUrl;
  String? _jwtToken;

  TourProgressService({String? jwtToken}) : _jwtToken = jwtToken;

  // Update JWT token
  void setToken(String token) {
    _jwtToken = token;
  }

  // Update POI completion status
  Future<void> updatePOIProgress({
    required String tourId,
    required String poiId,
    required int day,
    required bool completed,
  }) async {
    if (_jwtToken == null) {
      throw Exception('Authentication required: No JWT token available');
    }

    try {
      print('📍 Updating POI progress: $poiId (day $day) -> ${completed ? "completed" : "incomplete"}');

      final request = ProgressUpdateRequest(
        poiId: poiId,
        day: day,
        completed: completed,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/tours/$tourId/progress'),
        headers: {
          'Authorization': 'Bearer $_jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        print('✅ POI progress updated successfully');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: No access to this tour');
      } else if (response.statusCode == 404) {
        throw Exception('Tour not found');
      } else {
        throw Exception('Failed to update progress: ${response.body}');
      }
    } catch (e) {
      print('❌ Error updating POI progress: $e');
      rethrow;
    }
  }

  // Get tour progress
  Future<TourProgress> getTourProgress({
    required String tourId,
    String language = 'en',
  }) async {
    if (_jwtToken == null) {
      throw Exception('Authentication required: No JWT token available');
    }

    try {
      print('📊 Fetching tour progress for: $tourId');

      final response = await http.get(
        Uri.parse('$baseUrl/tours/$tourId/progress?language=$language'),
        headers: {
          'Authorization': 'Bearer $_jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final progress = TourProgress.fromJson(jsonDecode(response.body));
        print('✅ Tour progress loaded: ${progress.completedCount}/${progress.totalPois} POIs completed');
        return progress;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: No access to this tour');
      } else if (response.statusCode == 404) {
        throw Exception('Tour not found');
      } else {
        throw Exception('Failed to get progress: ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching tour progress: $e');
      rethrow;
    }
  }

  // Upload GPS trail points (batch)
  Future<void> uploadTrailPoints({
    required String tourId,
    required List<GPSPoint> points,
  }) async {
    if (_jwtToken == null) {
      throw Exception('Authentication required: No JWT token available');
    }

    if (points.isEmpty) {
      print('⚠️  No trail points to upload');
      return;
    }

    try {
      // Limit to 100 points per request as per API spec
      final batch = points.take(100).toList();
      print('📤 Uploading ${batch.length} GPS trail points for tour: $tourId');

      final request = TrailUploadRequest(points: batch);

      final response = await http.post(
        Uri.parse('$baseUrl/tours/$tourId/trail'),
        headers: {
          'Authorization': 'Bearer $_jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Trail uploaded: ${data['points_saved']} points saved (total: ${data['total_points']})');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: No access to this tour');
      } else if (response.statusCode == 404) {
        throw Exception('Tour not found');
      } else {
        throw Exception('Failed to upload trail: ${response.body}');
      }
    } catch (e) {
      print('❌ Error uploading trail points: $e');
      rethrow;
    }
  }

  // Get GPS trail for a tour
  Future<TourTrail> getTrail({required String tourId}) async {
    if (_jwtToken == null) {
      throw Exception('Authentication required: No JWT token available');
    }

    try {
      print('🗺️  Fetching GPS trail for tour: $tourId');

      final response = await http.get(
        Uri.parse('$baseUrl/tours/$tourId/trail'),
        headers: {
          'Authorization': 'Bearer $_jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final trail = TourTrail.fromJson(jsonDecode(response.body));
        print('✅ Trail loaded: ${trail.totalPoints} points');
        return trail;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: No access to this tour');
      } else if (response.statusCode == 404) {
        throw Exception('Tour not found');
      } else {
        throw Exception('Failed to get trail: ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching trail: $e');
      rethrow;
    }
  }
}
