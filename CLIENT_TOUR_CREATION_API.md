# Client-Side Tour Creation API

Complete API documentation for client apps (mobile/web) to create personalized tours.

## Overview

Client-side users can create **private, personalized tours** using the same powerful AI-powered tour generation engine used by the backstage admin panel.

**Key Features:**
- 🔒 **Private tours**: Only visible to creator (and backstage admins)
- 🌍 **Multi-language support**: Generate tours in any supported language
- 🎯 **Personalization**: Customize based on interests, pace, and walking tolerance
- 📍 **Smart routing**: AI-optimized itineraries with distance and coherence scoring
- ⚡ **Fast or optimal**: Choose between quick (simple mode) or optimal (ILP mode)

## Base URL

```
http://localhost:8000/client/tours
```

Production: `https://your-domain.com/client/tours`

---

## Authentication

**All endpoints require authentication** with `client_app` scope.

### Include Bearer Token in Header

```http
Authorization: Bearer <your-access-token>
```

### How to Get Access Token

Follow the [Client Authentication Guide](./CLIENT_AUTH_API.md) to:
1. Login with Google OAuth
2. Get access token
3. Use token for API calls

---

## Endpoints

### 1. Generate Tour

**POST** `/client/tours/generate`

Generate a personalized AI-powered tour itinerary.

#### Request Headers

```http
Content-Type: application/json
Authorization: Bearer <access-token>
```

#### Request Body

```json
{
  "city": "rome",
  "days": 3,
  "interests": ["history", "architecture"],
  "must_see": ["Colosseum", "Roman Forum"],
  "pace": "normal",
  "walking": "moderate",
  "language": "en",
  "mode": "simple",
  "start_location": "Colosseum",
  "end_location": "Trevi Fountain",
  "start_date": "2026-04-15",
  "provider": "anthropic"
}
```

#### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `city` | string | ✅ Yes | - | City name (e.g., "rome", "paris", "athens") |
| `days` | integer | ✅ Yes | - | Number of days (1-14) |
| `interests` | array[string] | No | `[]` | List of interests (e.g., ["history", "food", "art"]) |
| `must_see` | array[string] | No | `[]` | POIs that must be included |
| `pace` | string | No | `"normal"` | Trip pace: `"relaxed"`, `"normal"`, or `"packed"` |
| `walking` | string | No | `"moderate"` | Walking tolerance: `"low"`, `"moderate"`, or `"high"` |
| `language` | string | No | `"en"` | Language code (ISO 639-1: "en", "zh-tw", "fr", "es", "pt-br") |
| `mode` | string | No | `"simple"` | Optimization mode: `"simple"` (fast) or `"ilp"` (optimal) |
| `start_location` | string | No | `null` | Starting point (POI name or "lat,lng") |
| `end_location` | string | No | `null` | Ending point (POI name or "lat,lng") |
| `start_date` | string | No | `null` | Trip start date (YYYY-MM-DD) for checking hours |
| `provider` | string | No | `"anthropic"` | AI provider: `"anthropic"`, `"openai"`, or `"google"` |

#### Parameter Details

**Pace Options:**
- `relaxed`: 2-3 POIs per day, more time at each location
- `normal`: 4-5 POIs per day, balanced schedule
- `packed`: 6+ POIs per day, fast-paced sightseeing

**Walking Tolerance:**
- `low`: < 3km per day
- `moderate`: 3-6km per day
- `high`: > 6km per day

**Optimization Modes:**
- `simple`: Greedy + 2-opt algorithm (fast, ~1-5 seconds)
- `ilp`: Integer Linear Programming (optimal, ~10-60 seconds)

**Languages Supported:**
- `en`: English
- `zh-tw`: Traditional Chinese
- `zh-cn`: Simplified Chinese
- `fr`: French
- `es`: Spanish
- `pt-br`: Brazilian Portuguese
- `ja`: Japanese
- `ko`: Korean

#### Success Response (200 OK)

```json
{
  "success": true,
  "tour_id": "rome-tour-20260320-143022-a7b3f1",
  "city": "rome",
  "duration_days": 3,
  "total_pois": 12,
  "message": "Tour generated successfully with 12 POIs",
  "title_display": "Ancient Rome History · 3 Days",
  "visibility": "private",
  "creator_email": "user@example.com",
  "optimization_scores": {
    "distance_score": 0.85,
    "coherence_score": 0.92,
    "overall_score": 0.88,
    "total_distance_km": 15.3
  },
  "itinerary": [
    {
      "day": 1,
      "date": "2026-04-15",
      "pois": [
        {
          "poi": "Colosseum",
          "arrival_time": "09:00",
          "departure_time": "10:30",
          "visit_duration_minutes": 90,
          "walking_distance_km": 0,
          "walking_time_minutes": 0,
          "notes": "Start of the tour"
        },
        {
          "poi": "Roman Forum",
          "arrival_time": "10:45",
          "departure_time": "12:15",
          "visit_duration_minutes": 90,
          "walking_distance_km": 0.5,
          "walking_time_minutes": 15
        }
      ],
      "total_distance_km": 5.2,
      "total_walking_time_minutes": 65
    }
  ]
}
```

#### Error Responses

**400 Bad Request** - Invalid parameters
```json
{
  "detail": "Invalid start_date format. Use YYYY-MM-DD (e.g., 2026-04-15)."
}
```

**401 Unauthorized** - Missing or invalid token
```json
{
  "detail": "Missing auth token"
}
```

**403 Forbidden** - Insufficient permissions
```json
{
  "detail": "Client app access required"
}
```

**500 Internal Server Error** - Server error
```json
{
  "detail": "Failed to generate tour: <error message>"
}
```

---

### 2. List My Tours

**GET** `/client/tours/my-tours`

Get all tours created by the current user.

#### Request Headers

```http
Authorization: Bearer <access-token>
```

#### Success Response (200 OK)

```json
{
  "tours": [
    {
      "tour_id": "rome-tour-20260320-143022-a7b3f1",
      "city": "rome",
      "duration_days": 3,
      "total_pois": 12,
      "interests": ["history", "architecture"],
      "created_at": "2026-03-20T14:30:22.123456",
      "title_display": "Ancient Rome History · 3 Days",
      "visibility": "private",
      "languages": ["en"]
    },
    {
      "tour_id": "paris-tour-20260315-091045-c2d4e5",
      "city": "paris",
      "duration_days": 2,
      "total_pois": 8,
      "interests": ["art", "food"],
      "created_at": "2026-03-15T09:10:45.654321",
      "title_display": "Parisian Art & Cuisine · 2 Days",
      "visibility": "private",
      "languages": ["en", "fr"]
    }
  ],
  "total_count": 2
}
```

**Tours are sorted by creation date (newest first).**

---

## Example Usage

### Flutter/Dart Example

```dart
import 'package:dio/dio.dart';

class TourService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
    headers: {'Content-Type': 'application/json'},
  ));

  String? _accessToken;

  void setAccessToken(String token) {
    _accessToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<Map<String, dynamic>> generateTour({
    required String city,
    required int days,
    List<String> interests = const [],
    List<String> mustSee = const [],
    String pace = 'normal',
    String walking = 'moderate',
    String language = 'en',
    String mode = 'simple',
    String? startLocation,
    String? endLocation,
    String? startDate,
  }) async {
    final response = await _dio.post(
      '/client/tours/generate',
      data: {
        'city': city,
        'days': days,
        'interests': interests,
        'must_see': mustSee,
        'pace': pace,
        'walking': walking,
        'language': language,
        'mode': mode,
        if (startLocation != null) 'start_location': startLocation,
        if (endLocation != null) 'end_location': endLocation,
        if (startDate != null) 'start_date': startDate,
      },
    );

    return response.data;
  }

  Future<List<dynamic>> getMyTours() async {
    final response = await _dio.get('/client/tours/my-tours');
    return response.data['tours'];
  }
}

// Usage
void main() async {
  final tourService = TourService();

  // Set access token (obtained from authentication)
  tourService.setAccessToken('your-access-token-here');

  // Generate a tour
  try {
    final tour = await tourService.generateTour(
      city: 'rome',
      days: 3,
      interests: ['history', 'architecture'],
      pace: 'normal',
      walking: 'moderate',
      language: 'en',
    );

    print('Tour created: ${tour['tour_id']}');
    print('Title: ${tour['title_display']}');
    print('Total POIs: ${tour['total_pois']}');

  } catch (e) {
    if (e is DioException) {
      print('Error: ${e.response?.data['detail']}');
    }
  }

  // Get user's tours
  final myTours = await tourService.getMyTours();
  print('You have ${myTours.length} tours');
}
```

### JavaScript/React Example

```javascript
import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000';

// Create axios instance with token
const createTourClient = (accessToken) => {
  return axios.create({
    baseURL: API_BASE_URL,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    }
  });
};

// Generate tour
export const generateTour = async (accessToken, tourParams) => {
  const client = createTourClient(accessToken);

  try {
    const response = await client.post('/client/tours/generate', {
      city: tourParams.city,
      days: tourParams.days,
      interests: tourParams.interests || [],
      must_see: tourParams.mustSee || [],
      pace: tourParams.pace || 'normal',
      walking: tourParams.walking || 'moderate',
      language: tourParams.language || 'en',
      mode: tourParams.mode || 'simple',
      start_location: tourParams.startLocation,
      end_location: tourParams.endLocation,
      start_date: tourParams.startDate
    });

    return response.data;
  } catch (error) {
    console.error('Failed to generate tour:', error.response?.data);
    throw error;
  }
};

// Get user's tours
export const getMyTours = async (accessToken) => {
  const client = createTourClient(accessToken);

  try {
    const response = await client.get('/client/tours/my-tours');
    return response.data.tours;
  } catch (error) {
    console.error('Failed to get tours:', error.response?.data);
    throw error;
  }
};

// React component example
function TourGenerator() {
  const [tour, setTour] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleGenerateTour = async () => {
    setLoading(true);

    try {
      const accessToken = localStorage.getItem('access_token');

      const result = await generateTour(accessToken, {
        city: 'rome',
        days: 3,
        interests: ['history', 'architecture'],
        pace: 'normal',
        walking: 'moderate'
      });

      setTour(result);
      alert(`Tour created: ${result.title_display}`);

    } catch (error) {
      alert('Failed to create tour: ' + error.response?.data?.detail);
    } finally {
      setLoading(false);
    }
  };

  return (
    <button onClick={handleGenerateTour} disabled={loading}>
      {loading ? 'Generating...' : 'Generate Tour'}
    </button>
  );
}
```

### cURL Example

```bash
# Generate a tour
curl -X POST "http://localhost:8000/client/tours/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-access-token>" \
  -d '{
    "city": "rome",
    "days": 3,
    "interests": ["history", "architecture"],
    "pace": "normal",
    "walking": "moderate",
    "language": "en"
  }'

# List my tours
curl -X GET "http://localhost:8000/client/tours/my-tours" \
  -H "Authorization: Bearer <your-access-token>"
```

---

## Tour Visibility

Tours created via `/client/tours/generate` are **PRIVATE by default**.

### What "Private" Means

- ✅ **You can see**: Your own tours
- ✅ **Backstage admins can see**: All tours (for support/moderation)
- ❌ **Other users cannot see**: Your private tours

### Accessing Your Tours

Use these endpoints to view your tours:

1. **List your tours**: `GET /client/tours/my-tours`
2. **Get tour details**: `GET /tours/{tour_id}?language=en` (with auth header)

### Public Tours

Public tours (created by backstage admins) are visible to everyone and can be accessed without authentication.

---

## Error Handling

### Common Errors

**No POIs selected**
```json
{
  "detail": "No POIs were selected for the tour. Try adjusting your preferences."
}
```
**Solution**: Try different interests, increase days, or remove must-see constraints.

**Invalid date format**
```json
{
  "detail": "Invalid start_date format. Use YYYY-MM-DD (e.g., 2026-04-15)."
}
```
**Solution**: Use ISO date format (YYYY-MM-DD).

**Token expired**
```json
{
  "detail": "Token expired"
}
```
**Solution**: Refresh your access token using the refresh token.

---

## Best Practices

### 1. Cache Tours Locally

Store generated tours in local database to avoid regenerating:

```dart
// Save tour to local DB after generation
await localDB.saveTour(tour);

// Load from local DB on app start
final cachedTours = await localDB.getTours();
```

### 2. Handle Long Generation Times

Tour generation can take 10-60 seconds depending on optimization mode:

```javascript
// Show loading indicator
setLoading(true);
setProgress('Selecting POIs...');

const tour = await generateTour(token, params);

setProgress('Optimizing route...');
// Tour complete
setLoading(false);
```

### 3. Validate Input Before Sending

```dart
if (days < 1 || days > 14) {
  throw Exception('Days must be between 1 and 14');
}

if (startDate != null) {
  try {
    DateTime.parse(startDate);
  } catch (e) {
    throw Exception('Invalid date format');
  }
}
```

### 4. Use Simple Mode for Speed

For most users, `mode: "simple"` provides excellent results in 1-5 seconds.

Use `mode: "ilp"` only when:
- Users explicitly request "optimal" routing
- Tour has complex constraints (must-see POIs, start/end locations)
- Small number of days (<= 3)

### 5. Implement Retry Logic

```javascript
const generateTourWithRetry = async (token, params, maxRetries = 3) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await generateTour(token, params);
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
};
```

---

## Rate Limiting (Future)

Currently there are no rate limits. In the future, we may implement:

- **10 tours per hour** per user
- **100 tours per day** per user

Monitor API responses for `X-RateLimit-*` headers.

---

## Support

For issues or questions:
- **GitHub Issues**: https://github.com/your-repo/pocket-guide/issues
- **Documentation**: https://github.com/your-repo/pocket-guide/docs

---

## Changelog

### v1.0.0 (2026-03-20)
- Initial release
- Tour generation with AI-powered POI selection
- Private tour visibility
- Multi-language support
- Simple and ILP optimization modes
