# Pocket Guide Mobile App

Cross-platform mobile application (iOS & Android) built with Flutter for customized tour generation.

## Project Structure

```
pocket-guide-mobile-app/
├── api-spec/
│   └── openapi.json          # OpenAPI specification from backend
├── scripts/
│   ├── fetch-api-spec.sh     # Fetch latest API spec
│   └── generate-api-client.sh # Generate type-safe Dart client
├── lib/
│   ├── main.dart             # App entry point
│   └── api/
│       ├── generated/        # Auto-generated API client (gitignored)
│       └── example_usage.dart # Example usage patterns
├── ios/                      # iOS platform code
├── android/                  # Android platform code
└── pubspec.yaml              # Flutter dependencies
```

## Setup

### Prerequisites

- Flutter 3.41.1 or later
- Dart 3.11.0 or later
- Xcode (for iOS development)
- Android Studio (for Android development)

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Fetch Latest API Spec

Make sure the backend API is running at `http://localhost:8000`, then:

```bash
npm run fetch-api
```

Or from a different URL:
```bash
API_URL=https://api.pocket-guide.com npm run fetch-api
```

### 3. Generate API Client

Generate Dart client using openapi-generator:
```bash
npm run generate-api
```

This uses `openapi-generator-cli` with the `dart-dio` generator.

### 4. Update Everything (Recommended Workflow)

Fetch the latest spec and regenerate client in one command:
```bash
npm run update-api
```

## Usage in Flutter Code

### Basic Example

```dart
import 'package:pocket_guide_mobile/api/generated/lib/pocket_guide_api.dart';
import 'package:dio/dio.dart';

// Create Dio instance
final dio = Dio(BaseOptions(
  baseUrl: 'http://localhost:8000',
  connectTimeout: Duration(seconds: 5),
  receiveTimeout: Duration(seconds: 3),
));

// Create API client
final api = PocketGuideApi(dio: dio);

// Generate a tour
Future<void> generateTour() async {
  try {
    final request = TourGenerationRequest(
      city: 'rome',
      days: 3,
      interests: ['history', 'art'],
      provider: 'anthropic',
      pace: 'normal',
      language: 'en',
      save: true,
    );

    final response = await api.getTourApi().generateTourTourGeneratePost(request);

    print('Tour ID: ${response.data?.tourId}');
    print('Itinerary: ${response.data?.itinerary}');
  } catch (e) {
    print('Failed to generate tour: $e');
  }
}

// Get tour by ID
Future<void> getTour(String tourId) async {
  final tour = await api.getToursApi().getTourDetailToursTourIdGet(tourId);
  print('Tour: ${tour.data}');
}

// List all tours
Future<void> listTours() async {
  final tours = await api.getToursApi().listToursToursGet(
    city: 'rome',
    limit: 10,
  );
  print('Tours: ${tours.data}');
}
```

### Flutter Widget Example

```dart
import 'package:flutter/material.dart';
import 'package:pocket_guide_mobile/api/generated/lib/pocket_guide_api.dart';

class TourListScreen extends StatefulWidget {
  @override
  _TourListScreenState createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {
  final api = PocketGuideApi(dio: Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
  )));

  List<Tour>? tours;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTours();
  }

  Future<void> loadTours() async {
    try {
      final response = await api.getToursApi().listToursToursGet();
      setState(() {
        tours = response.data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      print('Error loading tours: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('My Tours')),
      body: ListView.builder(
        itemCount: tours?.length ?? 0,
        itemBuilder: (context, index) {
          final tour = tours![index];
          return ListTile(
            title: Text(tour.city ?? 'Unknown'),
            subtitle: Text('${tour.days} days'),
          );
        },
      ),
    );
  }
}
```

### More Examples

See `lib/api/example_usage.dart` for complete examples including:
- Tour generation with all parameters
- POI management and transcripts
- Combo ticket lookups
- Error handling patterns
- State management with Provider/Riverpod
- Batch operations

## Running the App

### iOS
```bash
flutter run -d ios
```

### Android
```bash
flutter run -d android
```

### Web (for testing)
```bash
flutter run -d chrome
```

## API Spec Updates

The OpenAPI spec should be updated whenever the backend API changes:

1. Backend team updates the API and deploys
2. Mobile team runs `npm run update-api`
3. Review generated code changes
4. Update Flutter app code if needed
5. Commit the new `api-spec/openapi.json` (NOT the generated code)

## Benefits of This Approach

✅ **Type Safety**: Full Dart type checking
✅ **Auto-Complete**: IDE knows all API endpoints and models
✅ **Single Source of Truth**: Backend defines API contract
✅ **No Manual Updates**: Changes sync automatically
✅ **Error Prevention**: Compile-time errors for API mismatches
✅ **Documentation**: Generated code includes DartDoc comments

## Development Workflow

1. **Backend changes API** → Updates FastAPI code
2. **Mobile fetches spec** → `npm run fetch-api`
3. **Mobile regenerates client** → `npm run generate-api`
4. **Dart analyzer** → Shows errors if breaking changes
5. **Mobile developer** → Fixes code to match new API
6. **Commit** → Only commit `api-spec/openapi.json`, not generated code

## Current API Status

- **API Version**: 1.0.0
- **Total Endpoints**: 24
- **Base URL**: `http://localhost:8000` (development)
- **Documentation**: `http://localhost:8000/docs` (Swagger UI)

## Available Endpoints

Key endpoints in the generated client:

- `generateTourTourGeneratePost()` - Generate a new tour
- `listToursToursGet()` - List all tours
- `getTourDetailToursTourIdGet()` - Get tour details
- `replacePoiToursTourIdReplacePoiPost()` - Replace POI in tour
- `listPoisPoisCityGet()` - List POIs for a city
- `getPoiDetailPoisCityPoiIdGet()` - Get POI details
- `getPoiTranscriptPoisCityPoiIdTranscriptGet()` - Get POI transcript
- `listComboTicketsComboTicketsGet()` - List combo tickets
- And more...

## Troubleshooting

**Q: Generated code has errors?**
A: Make sure you're using the latest API spec. Run `npm run update-api`

**Q: API call returns 404?**
A: Check the base URL configuration. Development uses `localhost:8000`, production will be different.

**Q: Need authentication?**
A: Add interceptor to Dio:
```dart
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    options.headers['Authorization'] = 'Bearer $token';
    return handler.next(options);
  },
));
```

**Q: Want to customize generated code?**
A: Don't edit generated files directly. They'll be overwritten. Instead, create wrapper classes in your own code.

**Q: Flutter doctor shows issues?**
A: Run `flutter doctor` to see what needs to be installed. You may need:
- Xcode (for iOS): https://developer.apple.com/xcode/
- Android Studio (for Android): https://developer.android.com/studio
- CocoaPods (for iOS): `sudo gem install cocoapods`

## License

Same as main Pocket Guide project
