# Quick Start Guide - Pocket Guide Mobile App (Flutter)

Get up and running with the Pocket Guide mobile app in 5 minutes!

## Prerequisites

- ✅ Flutter 3.41.1+ installed
- ✅ Node.js installed (for API generation scripts)
- ✅ Backend API running at http://localhost:8000

## Step 1: Install Dependencies

```bash
flutter pub get
npm install -g @openapitools/openapi-generator-cli
```

## Step 2: Generate API Client

Fetch the OpenAPI spec from your running backend and generate the Dart client:

```bash
npm run update-api
```

This will:
1. Fetch `openapi.json` from http://localhost:8000/openapi.json
2. Generate Dart client code in `lib/api/generated/`

You should see:
```
📡 Fetching OpenAPI spec from http://localhost:8000/openapi.json...
✅ OpenAPI spec saved to api-spec/openapi.json
🔧 Generating Dart API client for Flutter...
✅ Dart client generated at lib/api/generated
```

## Step 3: Run the App

### On iOS Simulator
```bash
flutter run -d ios
```

### On Android Emulator
```bash
flutter run -d android
```

### On Web (for quick testing)
```bash
flutter run -d chrome
```

## Step 4: Try the API

Edit `lib/main.dart` to test the API:

```dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:pocket_guide_mobile/api/generated/lib/pocket_guide_api.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Guide',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final api = PocketGuideApi(dio: Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
  )));

  String? tourId;
  bool loading = false;

  Future<void> generateTour() async {
    setState(() => loading = true);

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

      setState(() {
        tourId = response.data?.tourId;
        loading = false;
      });

      print('Generated tour: $tourId');
    } catch (e) {
      setState(() => loading = false);
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pocket Guide')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              CircularProgressIndicator()
            else if (tourId != null)
              Text('Generated Tour ID:\n$tourId', textAlign: TextAlign.center)
            else
              Text('Press the button to generate a tour'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : generateTour,
              child: Text('Generate Rome Tour'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Step 5: Hot Reload

Make changes to your code and press `r` in the terminal for hot reload, or `R` for hot restart!

## That's It! 🎉

You now have a Flutter app with a fully type-safe API client.

## Daily Workflow

When the backend API changes:

```bash
# Update everything in one command
npm run update-api

# Or step by step:
npm run fetch-api      # Fetch latest spec
npm run generate-api   # Regenerate client
flutter pub get        # Update dependencies
```

## Common Commands

### Run Flutter doctor (check setup)
```bash
flutter doctor
```

### Format code
```bash
flutter format .
```

### Analyze code
```bash
flutter analyze
```

## Common Issues

**App won't connect to API?**
- Make sure backend is running: http://localhost:8000/docs
- For iOS simulator: use `http://localhost:8000`
- For Android emulator: use `http://10.0.2.2:8000` (Android's host machine IP)

**Generated code has errors?**
- Make sure backend is running
- Run `npm run update-api` again
- Run `flutter pub get`

**Can't run on iOS?**
- Install Xcode from App Store
- Run: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
- Run: `sudo gem install cocoapods`

**Can't run on Android?**
- Install Android Studio: https://developer.android.com/studio
- Open Android Studio → SDK Manager → Install Android SDK
- Create an AVD (Android Virtual Device) in AVD Manager

## Next Steps

1. Check out the full [README.md](README.md) for detailed documentation
2. Explore the generated API client in `lib/api/generated/`
3. Start building your tour screens!

## Development Tips

1. **Always use generated types** - Never manually write API types
2. **Keep API client updated** - Run `npm run update-api` when backend changes
3. **Use hot reload** - Press `r` for instant feedback
4. **Check Flutter DevTools** - Run `flutter pub global activate devtools` for debugging UI
5. **Follow project structure** - See CLAUDE.md for code organization guidelines

## Questions?

- Backend API docs: http://localhost:8000/docs
- OpenAPI spec: `api-spec/openapi.json`
- Generated client: `lib/api/generated/`

Happy coding! 🚀
