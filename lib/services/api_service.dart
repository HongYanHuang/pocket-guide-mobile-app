import 'package:dio/dio.dart';
import 'package:built_collection/built_collection.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';

class ApiService {
  late final DefaultApi _api;
  late final AuthenticationApi _authApi;
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
    _authApi = AuthenticationApi(_dio, serializers);
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

  /// Fetch sectioned transcript with audio for a POI
  Future<SectionedTranscriptData?> fetchSectionedTranscript(
    String city,
    String poiId,
    String tourId,
    String language,
  ) async {
    try {
      print('Fetching sectioned transcript for: $city/$poiId (tour: $tourId, language: $language)');

      final response = await _api.getSectionedTranscriptPoisCityPoiIdSectionedTranscriptGet(
        city: city,
        poiId: poiId,
        language: language,
        tourId: tourId,
      );

      return response.data;
    } catch (e) {
      print('Error fetching sectioned transcript: $e');
      // Return null to allow fallback to regular transcript
      return null;
    }
  }

  /// Get audio file URL for a POI section
  String getAudioUrl(String city, String poiId, String audioFile) {
    return '$baseUrl/pois/$city/$poiId/audio/$audioFile';
  }

  // ==================== Authentication Methods ====================

  /// Initiate Google OAuth login (client-specific endpoint)
  Future<Map<String, dynamic>?> initiateGoogleLogin({
    required String redirectUri,
    required String codeChallenge,
  }) async {
    try {
      // Use client-specific endpoint: /auth/client/google/login
      final response = await _dio.get(
        '/auth/client/google/login',
        queryParameters: {
          'redirect_uri': redirectUri,
          'code_challenge': codeChallenge,
        },
      );

      if (response.data == null) {
        throw Exception('No data returned from login initiation');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Error initiating Google login: $e');
      rethrow;
    }
  }

  /// Exchange authorization code for tokens (client-specific endpoint)
  Future<AuthTokenResponse?> exchangeCodeForTokens({
    required String code,
    required String state,
    required String codeVerifier,
  }) async {
    try {
      // Use client-specific endpoint: /auth/client/google/callback
      final response = await _dio.get(
        '/auth/client/google/callback',
        queryParameters: {
          'code': code,
          'state': state,
          'code_verifier': codeVerifier,
        },
      );

      if (response.data == null) {
        throw Exception('No data returned from token exchange');
      }

      // Parse response as AuthTokenResponse
      final tokenData = response.data as Map<String, dynamic>;
      final authResponse = AuthTokenResponse(
        (b) => b
          ..accessToken = tokenData['access_token']
          ..refreshToken = tokenData['refresh_token']
          ..tokenType = tokenData['token_type']
          ..expiresIn = tokenData['expires_in'],
      );

      return authResponse;
    } catch (e) {
      print('Error exchanging code for tokens: $e');
      rethrow;
    }
  }

  /// Refresh access token
  Future<AuthTokenResponse?> refreshToken(String refreshToken) async {
    try {
      print('Refreshing access token...');

      final request = RefreshTokenRequest(
        (b) => b..refreshToken = refreshToken,
      );

      final response = await _authApi.refreshTokenAuthRefreshPost(
        refreshTokenRequest: request,
      );

      print('Token refreshed successfully');
      return response.data;
    } catch (e) {
      print('Error refreshing token: $e');
      rethrow;
    }
  }

  /// Get current user info
  Future<UserInfo?> getCurrentUser(String accessToken) async {
    try {
      print('Fetching current user info...');

      // Set authorization header
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final response = await _authApi.getMeAuthMeGet();

      print('User info retrieved successfully');
      return response.data;
    } catch (e) {
      print('Error getting current user: $e');
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout(String accessToken, String refreshToken) async {
    try {
      print('Logging out user...');

      // Set authorization header
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final request = RefreshTokenRequest(
        (b) => b..refreshToken = refreshToken,
      );

      await _authApi.logoutAuthLogoutPost(
        refreshTokenRequest: request,
      );

      // Clear authorization header
      _dio.options.headers.remove('Authorization');

      print('Logout successful');
    } catch (e) {
      print('Error during logout: $e');
      // Clear header even on error
      _dio.options.headers.remove('Authorization');
      rethrow;
    }
  }
}
