import 'package:dio/dio.dart';
import 'package:built_collection/built_collection.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';

class ApiService {
  late final DefaultApi _api;
  late final AuthenticationApi _authApi;
  late final Dio _dio;

  // Cloudflare Tunnel URL for testing on physical device
  static const String baseUrl = 'https://binding-extras-significant-musician.trycloudflare.com';

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
  /// For private tours, accessToken is required
  Future<TourDetail?> getTourById(String tourId, {String? accessToken}) async {
    print('=====================================');
    print('🔍 Fetching tour detail for: $tourId');
    print('=====================================');

    try {
      // Set authorization header if token provided (required for private tours)
      if (accessToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      }

      // First, fetch raw JSON to see what the backend actually returns
      print('📡 Fetching raw JSON response...');
      final rawResponse = await _dio.get(
        '/tours/$tourId',
        queryParameters: {'language': 'en'},
      );

      print('');
      print('✅ Raw API Response received:');
      print('════════════════════════════════════');
      print('Response Type: ${rawResponse.data.runtimeType}');
      print('');
      print('📄 Full JSON Response:');
      print(rawResponse.data);
      print('════════════════════════════════════');
      print('');

      // Check specific fields that might be null
      final data = rawResponse.data as Map<String, dynamic>;

      print('🔎 Checking key fields:');
      print('  - metadata: ${data['metadata'] != null ? 'EXISTS ✅' : 'NULL ❌'}');
      print('  - itinerary: ${data['itinerary'] != null ? 'EXISTS ✅' : 'NULL ❌'}');
      print('  - input_parameters: ${data['input_parameters'] != null ? 'EXISTS ✅' : 'NULL ❌'}');
      print('  - backup_pois: ${data['backup_pois'] != null ? 'EXISTS ✅' : 'NULL ❌'}');
      print('  - optimization_scores: ${data['optimization_scores'] != null ? 'EXISTS ✅' : 'NULL ❌'}');
      print('');

      if (data['metadata'] != null) {
        final metadata = data['metadata'] as Map<String, dynamic>;
        print('📋 Metadata contents:');
        print('  - tour_id: ${metadata['tour_id']}');
        print('  - city: ${metadata['city']}');
        print('  - created_at: ${metadata['created_at']}');
        print('  - duration_days: ${metadata['duration_days']}');
        print('  - total_pois: ${metadata['total_pois']}');
        print('');
      }

      if (data['input_parameters'] != null) {
        print('⚙️  Input parameters type: ${data['input_parameters'].runtimeType}');
        print('⚙️  Input parameters value: ${data['input_parameters']}');
      } else {
        print('⚠️  Input parameters is NULL - This will cause deserialization error!');
      }
      print('');

      print('🔄 Now attempting to deserialize with generated API client...');
      print('');

      // Clear the raw request headers and try with the generated client
      // Try to fetch tour using generated API client
      final response = await _api.getTourToursTourIdGet(tourId: tourId);

      print('✅ Tour detail fetched and deserialized successfully!');
      print('=====================================');
      print('');

      // Clear authorization header after request
      if (accessToken != null) {
        _dio.options.headers.remove('Authorization');
      }

      return response.data;
    } catch (e) {
      print('');
      print('❌ ERROR during tour fetch/deserialization:');
      print('════════════════════════════════════');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      print('════════════════════════════════════');
      print('');

      // Clear authorization header on error
      if (accessToken != null) {
        _dio.options.headers.remove('Authorization');
      }

      // If it's a deserialization error, provide helpful error message
      if (e.toString().contains('Deserializing') ||
          e.toString().contains('JsonObject') ||
          e.toString().contains('BackupPOI') ||
          e.toString().contains('type \'Null\' is not a subtype')) {
        print('💡 This is a deserialization error.');
        print('💡 The backend response does not match the OpenAPI specification.');
        print('💡 Check the logged API response above to see which fields are null.');
        print('💡 Backend team needs to either:');
        print('   1. Return non-null values for required fields, OR');
        print('   2. Update OpenAPI spec to mark those fields as nullable');
        print('');

        // Rethrow with a user-friendly message
        throw Exception(
          'Tour data format error. Check console for detailed API response. '
          'Backend needs to fix null fields in the response.'
        );
      }

      rethrow;
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
    String language, {
    String? accessToken, // Optional for private/personalized tours
  }) async {
    try {
      print('Fetching sectioned transcript for: $city/$poiId (tour: $tourId, language: $language)');

      // Set authorization header if token provided (for private tours)
      if (accessToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $accessToken';
        print('🔑 Using authenticated request for tour-specific content');
      }

      final response = await _api.getSectionedTranscriptPoisCityPoiIdSectionedTranscriptGet(
        city: city,
        poiId: poiId,
        language: language,
        tourId: tourId,
      );

      // Clear authorization header after request
      if (accessToken != null) {
        _dio.options.headers.remove('Authorization');
      }

      return response.data;
    } catch (e) {
      print('Error fetching sectioned transcript: $e');
      // Clear authorization header on error
      if (accessToken != null) {
        _dio.options.headers.remove('Authorization');
      }
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

      // Clean up authorization header
      _dio.options.headers.remove('Authorization');

      print('User info retrieved successfully');
      return response.data;
    } catch (e) {
      print('Error getting current user: $e');
      // Clean up authorization header on error
      _dio.options.headers.remove('Authorization');
      rethrow;
    }
  }

  /// Generate a personalized tour
  Future<Map<String, dynamic>> generateTour({
    required String accessToken,
    required String city,
    required int days,
    List<String>? interests,
    List<String>? mustSee,
    String? pace,
    String? walking,
    String? language,
    String? startLocation,
    String? endLocation,
    String? startDate,
  }) async {
    try {
      // Set authorization header
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final response = await _dio.post(
        '/client/tours/generate',
        data: {
          'city': city,
          'days': days,
          if (interests != null && interests.isNotEmpty) 'interests': interests,
          if (mustSee != null && mustSee.isNotEmpty) 'must_see': mustSee,
          'pace': pace ?? 'normal',
          'walking': walking ?? 'moderate',
          'language': language ?? 'en',
          'mode': 'ilp', // Use ILP mode for optimal results
          if (startLocation != null) 'start_location': startLocation,
          if (endLocation != null) 'end_location': endLocation,
          if (startDate != null) 'start_date': startDate,
          'provider': 'anthropic',
        },
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Error generating tour: $e');
      rethrow;
    }
  }

  /// Get user's private tours
  Future<List<dynamic>> getMyTours(String accessToken) async {
    try {
      print('🔑 getMyTours: Access token (first 20 chars): ${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}...');

      // Set authorization header
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      print('🔑 Authorization header set for /client/tours/my-tours');

      final response = await _dio.get('/client/tours/my-tours');

      // Clean up authorization header
      _dio.options.headers.remove('Authorization');
      print('✅ getMyTours: Successfully retrieved ${(response.data as Map<String, dynamic>)['tours'].length} tours');

      final data = response.data as Map<String, dynamic>;
      return data['tours'] as List<dynamic>;
    } catch (e) {
      print('❌ Error getting my tours: $e');
      // Clean up authorization header on error
      _dio.options.headers.remove('Authorization');
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
