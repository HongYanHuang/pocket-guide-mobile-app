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
      final response = await _api.getTourToursTourIdGet(tourId: tourId);
      return response.data;
    } catch (e) {
      print('Error fetching tour details: $e');
      return null;
    }
  }
}
