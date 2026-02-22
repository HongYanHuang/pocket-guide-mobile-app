import 'package:dio/dio.dart';
import 'package:built_collection/built_collection.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';

class ApiService {
  late final DefaultApi _api;
  late final Dio _dio;

  static const String baseUrl = 'http://localhost:8000';

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    final serializers = standardSerializers;
    _api = DefaultApi(_dio, serializers);
  }

  /// Get list of all cities
  Future<List<String>> getCities() async {
    try {
      final response = await _api.listCitiesCitiesGet();
      if (response.data == null) {
        return [];
      }

      // Extract city names from City objects
      return response.data!.map((city) => city.name ?? '').where((name) => name.isNotEmpty).toList();
    } catch (e) {
      print('Error fetching cities: $e');
      // Return fallback cities if API fails
      return [
        'Rome',
        'Paris',
        'London',
        'Tokyo',
        'New York',
        'Barcelona',
        'Amsterdam',
        'Venice',
        'Florence',
        'Berlin',
      ];
    }
  }

  /// Get list of tours for a specific city
  Future<List<TourSummary>> getToursByCity(String city) async {
    try {
      print('Fetching tours for city: $city');
      final response = await _api.listToursToursGet();
      print('API response received: ${response.data?.length ?? 0} tours');

      if (response.data == null) {
        print('No tour data returned');
        return [];
      }

      // Filter tours by city (case-insensitive)
      final cityLower = city.toLowerCase();
      final filteredTours = response.data!
          .where((tour) => tour.city.toLowerCase() == cityLower)
          .toList();

      print('Filtered ${filteredTours.length} tours for $city');
      return filteredTours;
    } catch (e) {
      print('Error fetching tours: $e');
      rethrow;
    }
  }

  /// Get tour details by ID
  Future<TourDetail?> getTourById(String tourId) async {
    try {
      print('Fetching tour detail for: $tourId');

      // Try to fetch tour directly first
      final response = await _api.getTourToursTourIdGet(tourId: tourId);
      print('Tour detail fetched successfully');
      return response.data;
    } catch (e) {
      print('Error fetching tour details: $e');

      // If it's a deserialization error, try fetching raw data
      if (e.toString().contains('BackupPOI')) {
        print('BackupPOI deserialization error detected, fetching raw data...');
        try {
          // Fetch raw JSON and parse manually without backup_pois
          final rawResponse = await _dio.get('/tours/$tourId');
          print('Raw response received, attempting manual parse');

          // For now, return null and show a helpful message
          // TODO: Parse raw JSON manually to create TourDetail without backup_pois
          return null;
        } catch (rawError) {
          print('Error fetching raw data: $rawError');
          return null;
        }
      }

      return null;
    }
  }

  /// Batch replace POIs in a tour
  Future<BatchPOIReplacementResponse> batchReplacePOIs(String tourId, Map<String, dynamic> requestBody) async {
    try {
      print('Batch replacing POIs for tour: $tourId');
      print('Request body: $requestBody');

      // Convert the request body to proper BuiltValue objects
      final replacements = (requestBody['replacements'] as List).map((item) {
        return POIReplacementItem(
          (b) => b
            ..originalPoi = item['original_poi']
            ..replacementPoi = item['replacement_poi']
            ..day = item['day'],
        );
      }).toList();

      // Create the batch replacement request
      final request = BatchPOIReplacementRequest(
        (b) => b
          ..replacements = ListBuilder<POIReplacementItem>(replacements)
          ..mode = requestBody['mode']
          ..language = requestBody['language'],
      );

      // Call the generated API method
      final response = await _api.batchReplacePoisInTourToursTourIdReplacePoisBatchPost(
        tourId: tourId,
        batchPOIReplacementRequest: request,
      );

      print('Batch replacement response: ${response.data}');

      if (response.data == null) {
        throw Exception('No data returned from batch replace API');
      }

      return response.data!;
    } catch (e) {
      print('Error batch replacing POIs: $e');
      rethrow;
    }
  }

  /// Fetch tour-specific transcript for a POI
  Future<String> fetchTranscript(String city, String poiId, String tourId, String language) async {
    try {
      print('Fetching transcript for: $city/$poiId (tour: $tourId, language: $language)');

      final response = await _dio.get(
        '/pois/$city/$poiId/transcript',
        queryParameters: {
          'language': language,
          'tour_id': tourId,
        },
      );

      if (response.data != null && response.data is Map) {
        return response.data['transcript'] ?? 'No transcript content available';
      }

      return 'No transcript available';
    } catch (e) {
      print('Error fetching transcript: $e');
      rethrow;
    }
  }
}
