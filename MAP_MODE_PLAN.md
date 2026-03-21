# Map Mode - Active Tour Implementation Plan

## Overview
Transform tour viewing into an active, location-aware experience with real-time GPS tracking, audio playback, and completion tracking.

---

## Quick Start for Flutter Developers

### ✅ Backend API Status: COMPLETED & READY

The backend API is fully implemented and deployed. You can start integrating immediately!

**Base URL:** `https://your-api-domain.com` (replace with actual production URL)
**Development:** `http://localhost:8000`

### Getting Started (5 Steps)

1. **Get JWT Token**
   - User must be authenticated via Google OAuth
   - Token available from existing auth flow
   - Include in all requests: `Authorization: Bearer <token>`

2. **Add HTTP Client** (or use existing)
   ```dart
   dependencies:
     http: ^1.1.0
   ```

3. **Create Service Class**
   - Copy the `TourProgressService` example from this doc
   - Configure base URL
   - Inject JWT token

4. **Load Tour Progress** (on tour start)
   ```dart
   final progress = await service.getTourProgress(
     tourId: tourId,
     language: 'en',
   );
   ```

5. **Update Progress** (when POI completed)
   ```dart
   await service.updatePOIProgress(
     tourId: tourId,
     poiId: 'colosseum',
     day: 1,
     completed: true,
   );
   ```

### Important Links
- **API Documentation:** Full specs in "Backend API Implementation" section below
- **Error Handling:** See "Edge Cases & Error Handling" section
- **Data Models:** See "Flutter Data Models" section
- **Testing:** See "Testing Checklist" section

---

## Feature Requirements

### Map Display
- **Provider:** flutter_map with OpenStreetMap (Leaflet-based, free)
- **POI Markers:**
  - Numbered sequence (1, 2, 3...)
  - Color coding: Gray (not started) → Blue (in progress) → Green (completed)
  - Lines connecting POIs showing recommended route
- **User Location:** Real-time blue dot showing current position
- **GPS Trail:** Polyline showing user's walking path

### Two Entry Modes
1. **"Start Tour" (Active Mode)**
   - GPS tracking enabled
   - Real-time location updates
   - Auto-completion detection
   - Trail recording

2. **"Preview in Map" (Preview Mode)**
   - No GPS tracking
   - Static view of POI locations
   - Can still play audio
   - No completion tracking

### GPS Tracking
- **Active app:** Update every 5 seconds
- **Background:** Update every 30 seconds
- **Permission:** Request when entering active mode
- **Accuracy:** High accuracy mode for better trail recording

### Audio Player Integration
- **Bottom Sheet:** Slides up when POI marker tapped
  - POI name, details
  - All audio sections
  - Emphasized play buttons
  - Navigation button → Opens Google Maps
- **Minimized Player:** Floating at bottom when audio playing
  - POI name
  - Play/pause control
  - Tap to expand bottom sheet
- **Full Screen:** Only when user wants to read full transcript

### Multi-Day Tours
- **Day Selector:** Buttons at top of map
- **Active Day:** User selects which day to activate
- **Filter:** Show only POIs for selected day

### Auto-Completion Logic
- **Trigger:** User within 100m of POI AND finished ALL audio sections under that POI
- **Manual Control:**
  - Complete button (force mark as completed)
  - Uncomplete button (remove completion status)
- **Backend Sync:** Save completion status to server

### Trail Recording
- **Data Points:** { latitude, longitude, timestamp, accuracy }
- **Storage:** Save to backend periodically
- **Visualization:** Show user's walking path as colored polyline
- **Privacy:** User can view their achievement/trail

---

## Technical Architecture

### Dependencies to Add
```yaml
dependencies:
  flutter_map: ^6.1.0              # Leaflet-based maps
  latlong2: ^0.9.0                  # Coordinate handling
  geolocator: ^11.0.0               # GPS tracking
  permission_handler: ^11.0.0       # Location permissions
  url_launcher: ^6.2.0              # Open Google Maps
```

### New Files Structure
```
lib/
├── screens/
│   └── map_tour_screen.dart           # Main map screen
├── widgets/
│   ├── poi_bottom_sheet.dart          # POI details + audio player
│   ├── mini_audio_player.dart         # Floating minimized player
│   └── day_selector.dart              # Multi-day tour selector
├── services/
│   ├── location_service.dart          # GPS tracking service
│   └── tour_progress_service.dart     # Completion tracking
└── models/
    ├── tour_progress.dart             # POI completion state
    └── gps_trail_point.dart           # Trail data point
```

### Backend API Implementation ✅ COMPLETED

**Base URL:** `https://your-api-domain.com` (or `http://localhost:8000` for development)

**Authentication:** All endpoints require JWT token in Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

---

#### 1. Update POI Completion Status

**Endpoint:** `POST /tours/{tour_id}/progress`

**Description:** Mark a POI as completed or not completed. Each user has independent progress tracking.

**Request Body:**
```json
{
  "poi_id": "colosseum",
  "day": 1,
  "completed": true
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "poi_id": "colosseum",
  "day": 1,
  "completed": true,
  "completed_at": "2026-03-21T11:30:00.000000",
  "message": "POI progress updated"
}
```

**Fields:**
- `poi_id` (string, required): POI identifier in kebab-case (e.g., "colosseum", "roman-forum")
- `day` (integer, required): Day number where this POI appears (≥ 1)
- `completed` (boolean, required): Completion status

**Errors:**
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: User doesn't have access to this tour (private tour by another user)
- `404 Not Found`: Tour doesn't exist

---

#### 2. Get Tour Progress

**Endpoint:** `GET /tours/{tour_id}/progress?language=en`

**Description:** Get completion status for all POIs in the tour for the authenticated user.

**Query Parameters:**
- `language` (string, optional): Language code for POI names (default: "en")
  - Supported: `en`, `zh-tw`, `zh-cn`, `es`, `fr`, `de`, `it`, `ja`, `ko`, etc.

**Response (200 OK):**
```json
{
  "tour_id": "rome-tour-20260304-095656-185fb3",
  "completions": [
    {
      "poi_id": "colosseum",
      "poi_name": "Colosseum",
      "day": 1,
      "completed": true,
      "completed_at": "2026-03-21T11:30:00.000000"
    },
    {
      "poi_id": "roman-forum",
      "poi_name": "Roman Forum",
      "day": 1,
      "completed": false,
      "completed_at": null
    }
  ],
  "total_pois": 12,
  "completed_count": 1,
  "completion_percentage": 8.3
}
```

**Fields:**
- `completions`: Array of POI completion statuses
  - `poi_id`: POI identifier
  - `poi_name`: Localized POI name (based on language parameter)
  - `day`: Day number
  - `completed`: Whether POI is completed
  - `completed_at`: ISO 8601 timestamp when completed (null if not completed)
- `total_pois`: Total number of POIs in tour
- `completed_count`: Number of completed POIs
- `completion_percentage`: Percentage completed (0-100)

**Errors:**
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: User doesn't have access to this tour
- `404 Not Found`: Tour doesn't exist or itinerary not found for language

---

#### 3. Upload GPS Trail Points

**Endpoint:** `POST /tours/{tour_id}/trail`

**Description:** Batch upload GPS trail points. Maximum 100 points per request.

**Request Body:**
```json
{
  "points": [
    {
      "lat": 41.8902,
      "lng": 12.4922,
      "timestamp": "2026-03-21T10:05:00.000000",
      "accuracy": 15.5
    },
    {
      "lat": 41.8905,
      "lng": 12.4925,
      "timestamp": "2026-03-21T10:06:00.000000",
      "accuracy": 12.0
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "points_saved": 2,
  "total_points": 245,
  "message": "Saved 2 GPS points"
}
```

**Fields:**
- `points` (array, required): GPS points to save (1-100 points per request)
  - `lat` (float, required): Latitude (-90 to 90)
  - `lng` (float, required): Longitude (-180 to 180)
  - `timestamp` (string, required): ISO 8601 timestamp when point was recorded
  - `accuracy` (float, optional): GPS accuracy in meters (≥ 0)

**Response Fields:**
- `points_saved`: Number of points saved in this request
- `total_points`: Total points in trail after save

**Errors:**
- `400 Bad Request`: More than 100 points in request
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: User doesn't have access to this tour
- `404 Not Found`: Tour doesn't exist

---

#### 4. Get GPS Trail

**Endpoint:** `GET /tours/{tour_id}/trail`

**Description:** Get all GPS trail points for the authenticated user.

**Response (200 OK):**
```json
{
  "tour_id": "rome-tour-20260304-095656-185fb3",
  "points": [
    {
      "lat": 41.8902,
      "lng": 12.4922,
      "timestamp": "2026-03-21T10:05:00.000000"
    },
    {
      "lat": 41.8905,
      "lng": 12.4925,
      "timestamp": "2026-03-21T10:06:00.000000"
    }
  ],
  "total_points": 245
}
```

**Fields:**
- `points`: Array of GPS trail points (simplified, without accuracy field)
- `total_points`: Total number of points

**Errors:**
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: User doesn't have access to this tour
- `404 Not Found`: Tour doesn't exist

---

#### Flutter HTTP Client Example

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class TourProgressService {
  final String baseUrl = 'https://your-api-domain.com';
  final String jwtToken;

  TourProgressService({required this.jwtToken});

  // Update POI completion
  Future<void> updatePOIProgress({
    required String tourId,
    required String poiId,
    required int day,
    required bool completed,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tours/$tourId/progress'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'poi_id': poiId,
        'day': day,
        'completed': completed,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update progress: ${response.body}');
    }
  }

  // Get tour progress
  Future<TourProgress> getTourProgress({
    required String tourId,
    String language = 'en',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tours/$tourId/progress?language=$language'),
      headers: {'Authorization': 'Bearer $jwtToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get progress: ${response.body}');
    }

    return TourProgress.fromJson(jsonDecode(response.body));
  }

  // Upload GPS trail (batch)
  Future<void> uploadTrailPoints({
    required String tourId,
    required List<GPSPoint> points,
  }) async {
    // Limit to 100 points per request
    final batch = points.take(100).toList();

    final response = await http.post(
      Uri.parse('$baseUrl/tours/$tourId/trail'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'points': batch.map((p) => {
          'lat': p.latitude,
          'lng': p.longitude,
          'timestamp': p.timestamp.toIso8601String(),
          'accuracy': p.accuracy,
        }).toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upload trail: ${response.body}');
    }
  }

  // Get GPS trail
  Future<List<TrailPoint>> getTrail({required String tourId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tours/$tourId/trail'),
      headers: {'Authorization': 'Bearer $jwtToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get trail: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['points'] as List)
        .map((p) => TrailPoint.fromJson(p))
        .toList();
  }
}
```

---

## Implementation Phases

### ✅ Phase 0: Backend API (COMPLETED)
- [x] Implement 4 API endpoints
- [x] Per-user progress storage
- [x] Per-user trail storage
- [x] Access control (public/private tours)
- [x] Authentication integration
- [x] API documentation

### Phase 1: API Integration & Data Layer (Week 1)
- [ ] Add http dependency to pubspec.yaml
- [ ] Create TourProgressService class
- [ ] Implement all 4 API methods (progress + trail)
- [ ] Create data models (TourProgress, TrailPoint, etc.)
- [ ] Add error handling and retry logic
- [ ] Write unit tests for API service

### Phase 2: Basic Map UI (Week 1)
- [ ] Add flutter_map dependencies
- [ ] Create MapTourScreen with flutter_map
- [ ] Display POI markers with numbers
- [ ] Draw lines connecting POIs
- [ ] Add "Start Tour" and "Preview in Map" buttons to tour details page
- [ ] Implement active/preview mode toggle

### Phase 3: GPS Tracking (Week 1-2)
- [ ] Create LocationService for GPS tracking
- [ ] Request location permissions on active mode entry
- [ ] Show user's current location as blue dot
- [ ] Implement 5s (active) / 30s (background) update intervals
- [ ] Handle permission denied scenarios

### Phase 4: Trail Recording & Backend Sync (Week 2)
- [ ] Record GPS points to local list
- [ ] Draw trail polyline on map
- [ ] Implement TrailUploadManager (1 min OR 20 points)
- [ ] Add periodic trail saving to backend (POST /trail)
- [ ] Load existing trail on tour start (GET /trail)
- [ ] Add offline queue for network failures

### Phase 5: Progress Tracking & Backend Sync (Week 2)
- [ ] Load progress on tour start (GET /progress)
- [ ] Update POI markers based on completion status
- [ ] Implement manual complete/uncomplete buttons
- [ ] Sync completion to backend immediately (POST /progress)
- [ ] Add offline queue for network failures
- [ ] Show completion percentage

### Phase 6: Audio Player Integration (Week 2-3)
- [ ] Create POIBottomSheet widget
- [ ] Integrate audio player from existing code
- [ ] Implement bottom sheet slide up/down
- [ ] Create MiniAudioPlayer widget
- [ ] Handle audio playback state across widgets
- [ ] Add "Navigate" button → url_launcher to Google Maps

### Phase 7: Auto-Completion (Week 3)
- [ ] Monitor user distance to each POI
- [ ] Track audio completion per POI
- [ ] Auto-mark complete when: within 100m + all audio finished
- [ ] Test auto-completion in real environment

### Phase 8: Multi-Day Support (Week 3)
- [ ] Create DaySelector widget
- [ ] Filter POIs by selected day
- [ ] Save active day state
- [ ] Update markers based on day
- [ ] Handle progress per day

### Phase 9: Polish & Testing (Week 4)
- [ ] Handle edge cases (no GPS signal, permission issues)
- [ ] Optimize performance (don't track when user is stationary)
- [ ] Add loading states for all API calls
- [ ] Error handling and user feedback
- [ ] Test offline queue functionality
- [ ] Test on real devices outdoors
- [ ] Battery optimization testing

---

## UI Mockup Flow

```
Tour Details Page
├─ [Preview in Map] button → MapTourScreen (preview mode)
└─ [Start Tour] button → Permission Request → MapTourScreen (active mode)

MapTourScreen (Active Mode)
├─ Top: Day Selector (for multi-day tours)
├─ Map View
│  ├─ POI Markers (numbered, color-coded)
│  ├─ Route Lines (connecting POIs)
│  ├─ User Location (blue dot)
│  └─ GPS Trail (polyline)
├─ Bottom: Mini Audio Player (if playing)
└─ On POI Tap: Bottom Sheet
   ├─ POI Details
   ├─ Audio Sections (emphasized)
   ├─ Complete/Uncomplete Button
   └─ Navigate Button → Google Maps
```

---

## Color Scheme for POI Status

- **Not Started:** `Colors.grey.shade400`
- **In Progress:** `Colors.blue.shade600` (at least one audio played)
- **Completed:** `Colors.green.shade600` (all audio finished + visited)

---

## Backend Implementation Answers ✅

### 1. Trail Data Format
**Answer:** Array of objects with lat/lng/timestamp/accuracy
```json
{
  "points": [
    {
      "lat": 41.8902,
      "lng": 12.4922,
      "timestamp": "2026-03-21T10:05:00.000000",
      "accuracy": 15.5
    }
  ]
}
```

### 2. Trail Storage Frequency
**Answer:** Hybrid approach (recommended)
- **Client-side batching:** Upload every **1 minute** OR when **20 points** collected, whichever comes first
- **Max per request:** 100 points (server validation)
- **Retry logic:** Queue locally and retry on failure

**Implementation Example:**
```dart
class TrailUploadManager {
  final List<GPSPoint> _buffer = [];
  DateTime? _lastUpload;

  void addPoint(GPSPoint point) {
    _buffer.add(point);

    // Upload if: 1 minute passed OR 20+ points
    final shouldUpload =
      _lastUpload == null ||
      DateTime.now().difference(_lastUpload!) > Duration(minutes: 1) ||
      _buffer.length >= 20;

    if (shouldUpload) {
      _uploadBatch();
    }
  }

  Future<void> _uploadBatch() async {
    if (_buffer.isEmpty) return;

    try {
      await tourProgressService.uploadTrailPoints(
        tourId: currentTourId,
        points: _buffer.take(100).toList(),
      );
      _buffer.clear();
      _lastUpload = DateTime.now();
    } catch (e) {
      // Keep in buffer for retry
      print('Upload failed, will retry: $e');
    }
  }
}
```

### 3. Privacy & Data Retention
**Answer:**
- **Retention:** Trail data stored **permanently** (no automatic deletion)
- **User control:** Future enhancement - users can request deletion via support
- **Access:** Each user's trail is private (only accessible to that user)
- **Storage location:** `user_data/{email}/tour_{tour_id}_trail.json`

### 4. Progress Sync Strategy
**Answer:** Real-time update (recommended)
- **On completion:** Immediate `POST /progress` when POI marked complete
- **On uncomplete:** Immediate `POST /progress` when POI unmarked
- **On app start:** Fetch latest progress with `GET /progress`
- **Benefits:** Immediate user feedback, no data loss if app crashes

**Implementation Example:**
```dart
Future<void> markPOIComplete(String poiId, int day) async {
  // Update local state immediately
  setState(() {
    poiStatuses[poiId] = true;
  });

  // Sync to backend immediately
  try {
    await tourProgressService.updatePOIProgress(
      tourId: tourId,
      poiId: poiId,
      day: day,
      completed: true,
    );
  } catch (e) {
    // Revert local state on failure
    setState(() {
      poiStatuses[poiId] = false;
    });
    showError('Failed to save progress');
  }
}
```

---

## Important Implementation Notes

### POI Identifier Format
- **POI IDs are kebab-case:** Convert POI names to IDs using kebab-case
  - Example: "Colosseum" → "colosseum"
  - Example: "Roman Forum" → "roman-forum"
  - Example: "Trevi Fountain" → "trevi-fountain"

**Dart helper function:**
```dart
String poiNameToId(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
      .trim()
      .replaceAll(RegExp(r'\s+'), '-');    // Replace spaces with hyphens
}
```

### Composite Keys for Progress
- Backend uses composite key: `"poi_id:day"`
- This handles cases where same POI appears on multiple days
- Example: "Colosseum" on Day 1 and Day 3 are tracked separately

### Access Control
Users can track progress for:
- ✅ **Public tours** (any authenticated user)
- ✅ **Private tours** they created (creator only)
- ❌ Private tours by other users → `403 Forbidden`

### Data Storage (Backend)
Each user has separate files:
```
user_data/
└── user@example.com/
    ├── tour_{tour_id}_progress.json
    └── tour_{tour_id}_trail.json
```

Multiple users can track the same tour independently.

---

## Edge Cases & Error Handling

### 1. No Internet Connection
**Scenario:** User completes POI offline

**Solution:**
```dart
class OfflineProgressQueue {
  final List<ProgressUpdate> _queue = [];

  Future<void> markComplete(String poiId, int day, bool completed) async {
    // Add to queue
    _queue.add(ProgressUpdate(poiId, day, completed));

    // Try to sync
    await _syncQueue();
  }

  Future<void> _syncQueue() async {
    while (_queue.isNotEmpty && await _hasConnection()) {
      final update = _queue.first;
      try {
        await api.updateProgress(update);
        _queue.removeAt(0); // Success - remove from queue
      } catch (e) {
        break; // Network error - stop and retry later
      }
    }
  }
}
```

### 2. GPS Accuracy Filtering
**Scenario:** GPS returns inaccurate points (accuracy > 50m)

**Solution:**
```dart
void addTrailPoint(Position position) {
  // Filter out inaccurate points
  if (position.accuracy > 50.0) {
    print('Skipping inaccurate point: ${position.accuracy}m');
    return;
  }

  _trailPoints.add(GPSPoint(
    latitude: position.latitude,
    longitude: position.longitude,
    timestamp: DateTime.now(),
    accuracy: position.accuracy,
  ));
}
```

### 3. User Hasn't Started Tour
**Scenario:** `GET /progress` when user hasn't visited any POIs

**Response:** All POIs with `completed=false`, `completion_percentage=0.0`

### 4. Same POI on Multiple Days
**Scenario:** Colosseum appears on Day 1 and Day 3

**Solution:** Track separately with `day` parameter
```dart
// Day 1
await api.updateProgress(poiId: 'colosseum', day: 1, completed: true);

// Day 3 (different instance)
await api.updateProgress(poiId: 'colosseum', day: 3, completed: true);
```

### 5. Tour Language Mismatch
**Scenario:** User requests progress in unsupported language

**Fallback:** Backend returns English if requested language not available

**Client handling:**
```dart
try {
  final progress = await api.getTourProgress(
    tourId: tourId,
    language: userLanguage,
  );
} catch (e) {
  // Fallback to English
  final progress = await api.getTourProgress(
    tourId: tourId,
    language: 'en',
  );
}
```

### 6. Trail Upload Failure
**Scenario:** Network error during trail upload

**Solution:** Keep points in buffer and retry
```dart
try {
  await api.uploadTrailPoints(tourId, points);
  _buffer.clear(); // Success
} catch (e) {
  // Keep in buffer, will retry on next batch
  print('Upload failed, buffering for retry: $e');
}
```

---

## Best Practices

### 1. Battery Optimization
```dart
// Stop tracking when user is stationary
void onLocationUpdate(Position position) {
  final distance = Geolocator.distanceBetween(
    _lastPosition.latitude,
    _lastPosition.longitude,
    position.latitude,
    position.longitude,
  );

  // Only record if moved > 10 meters
  if (distance > 10.0) {
    addTrailPoint(position);
    _lastPosition = position;
  }
}
```

### 2. Memory Management
```dart
// Limit trail points in memory (display last 1000 only)
List<TrailPoint> get displayableTrail {
  if (_trailPoints.length <= 1000) {
    return _trailPoints;
  }
  return _trailPoints.sublist(_trailPoints.length - 1000);
}
```

### 3. Loading States
```dart
// Show loading indicator during API calls
Future<void> loadProgress() async {
  setState(() => _isLoading = true);

  try {
    final progress = await api.getTourProgress(tourId: tourId);
    setState(() {
      _progress = progress;
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  }
}
```

### 4. Auto-Completion Detection
```dart
bool shouldAutoComplete(POI poi, Position userPosition, AudioState audioState) {
  // Check distance (100m threshold)
  final distance = Geolocator.distanceBetween(
    userPosition.latitude,
    userPosition.longitude,
    poi.latitude,
    poi.longitude,
  );

  final isWithinRange = distance <= 100.0;

  // Check if all audio sections finished
  final allAudioFinished = audioState.hasFinishedAllSections(poi.id);

  return isWithinRange && allAudioFinished;
}
```

---

## Testing Checklist

### API Integration Tests
- [ ] Mark POI complete → verify response
- [ ] Mark POI uncomplete → verify response
- [ ] Get progress for tour with 0 completions
- [ ] Get progress for tour with partial completions
- [ ] Upload 1 GPS point
- [ ] Upload 20 GPS points (batch)
- [ ] Upload 100 GPS points (max)
- [ ] Upload 101 GPS points → expect 400 error
- [ ] Get trail with 0 points
- [ ] Get trail with many points

### Authentication Tests
- [ ] Call API without token → expect 401
- [ ] Call API with expired token → expect 401
- [ ] Access private tour by another user → expect 403
- [ ] Access public tour → expect 200

### Offline/Network Tests
- [ ] Complete POI while offline → queue locally
- [ ] Restore connection → queue syncs
- [ ] Upload trail while offline → retry on reconnect

### Edge Cases
- [ ] Same POI on Day 1 and Day 3 → both tracked separately
- [ ] Request progress in unsupported language → fallback to English
- [ ] GPS accuracy > 50m → point filtered out
- [ ] User stationary > 1 min → no new trail points

---

## Technical Considerations

### GPS Accuracy
- Use `LocationAccuracy.best` for active tracking
- Consider battery impact (30s background is reasonable)
- Filter out inaccurate points (accuracy > 50m)

### Background Tracking
- iOS: Requires "Location When In Use" permission + background modes
- Android: Requires foreground service notification
- Need to handle app kill/restart scenarios

### Performance
- Limit trail points displayed (last 1000 points max)
- Use polyline simplification for long trails
- Cache map tiles for better performance

### Error Handling
- No GPS signal → Show message, use last known location
- Permission denied → Gracefully degrade to preview mode
- Backend API failure → Queue data locally, retry later

---

## Flutter Data Models

### 1. Tour Progress Models

**lib/models/tour_progress.dart**
```dart
class POICompletionStatus {
  final String poiId;
  final String poiName;
  final int day;
  final bool completed;
  final DateTime? completedAt;

  POICompletionStatus({
    required this.poiId,
    required this.poiName,
    required this.day,
    required this.completed,
    this.completedAt,
  });

  factory POICompletionStatus.fromJson(Map<String, dynamic> json) {
    return POICompletionStatus(
      poiId: json['poi_id'],
      poiName: json['poi_name'],
      day: json['day'],
      completed: json['completed'],
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }
}

class TourProgress {
  final String tourId;
  final List<POICompletionStatus> completions;
  final int totalPois;
  final int completedCount;
  final double completionPercentage;

  TourProgress({
    required this.tourId,
    required this.completions,
    required this.totalPois,
    required this.completedCount,
    required this.completionPercentage,
  });

  factory TourProgress.fromJson(Map<String, dynamic> json) {
    return TourProgress(
      tourId: json['tour_id'],
      completions: (json['completions'] as List)
          .map((c) => POICompletionStatus.fromJson(c))
          .toList(),
      totalPois: json['total_pois'],
      completedCount: json['completed_count'],
      completionPercentage: json['completion_percentage'].toDouble(),
    );
  }
}
```

### 2. GPS Trail Models

**lib/models/gps_trail_point.dart**
```dart
class GPSPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  GPSPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'timestamp': timestamp.toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
    };
  }
}

class TrailPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory TrailPoint.fromJson(Map<String, dynamic> json) {
    return TrailPoint(
      latitude: json['lat'].toDouble(),
      longitude: json['lng'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  // Convert to LatLng for flutter_map
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

class TourTrail {
  final String tourId;
  final List<TrailPoint> points;
  final int totalPoints;

  TourTrail({
    required this.tourId,
    required this.points,
    required this.totalPoints,
  });

  factory TourTrail.fromJson(Map<String, dynamic> json) {
    return TourTrail(
      tourId: json['tour_id'],
      points: (json['points'] as List)
          .map((p) => TrailPoint.fromJson(p))
          .toList(),
      totalPoints: json['total_points'],
    );
  }
}
```

### 3. Progress Update Request

**lib/models/progress_update.dart**
```dart
class ProgressUpdateRequest {
  final String poiId;
  final int day;
  final bool completed;

  ProgressUpdateRequest({
    required this.poiId,
    required this.day,
    required this.completed,
  });

  Map<String, dynamic> toJson() {
    return {
      'poi_id': poiId,
      'day': day,
      'completed': completed,
    };
  }
}
```

### 4. Trail Upload Request

**lib/models/trail_upload.dart**
```dart
class TrailUploadRequest {
  final List<GPSPoint> points;

  TrailUploadRequest({required this.points});

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => p.toJson()).toList(),
    };
  }
}
```

---

## API Response Examples

### Success Response - Update Progress
```json
{
  "success": true,
  "poi_id": "colosseum",
  "day": 1,
  "completed": true,
  "completed_at": "2026-03-21T11:30:00.000000",
  "message": "POI progress updated"
}
```

### Success Response - Get Progress
```json
{
  "tour_id": "rome-tour-20260304-095656-185fb3",
  "completions": [
    {
      "poi_id": "colosseum",
      "poi_name": "Colosseum",
      "day": 1,
      "completed": true,
      "completed_at": "2026-03-21T11:30:00.000000"
    },
    {
      "poi_id": "roman-forum",
      "poi_name": "Roman Forum",
      "day": 1,
      "completed": false,
      "completed_at": null
    }
  ],
  "total_pois": 12,
  "completed_count": 1,
  "completion_percentage": 8.3
}
```

### Success Response - Upload Trail
```json
{
  "success": true,
  "points_saved": 20,
  "total_points": 245,
  "message": "Saved 20 GPS points"
}
```

### Error Response - 401 Unauthorized
```json
{
  "detail": "Not authenticated"
}
```

### Error Response - 403 Forbidden
```json
{
  "detail": "Access denied. This is a private tour."
}
```

### Error Response - 404 Not Found
```json
{
  "detail": "Tour 'invalid-tour-id' not found"
}
```

### Error Response - 400 Bad Request
```json
{
  "detail": "Maximum 100 points per request"
}
```

---

## Success Criteria

✅ User can see POIs on a map with numbered markers
✅ GPS tracking works in foreground and background
✅ Audio plays when POI is tapped
✅ POI auto-completes when within 100m + all audio finished
✅ User can manually complete/uncomplete POIs
✅ GPS trail is visible and saved to backend
✅ "Navigate" button opens Google Maps for turn-by-turn directions
✅ Multi-day tours can switch between days
✅ Preview mode works without GPS tracking

---

## Future Enhancements (Not in Initial Scope)

- Offline map tiles download
- Progress tracking dashboard
- Achievements/badges for tour completion
- Share trail with friends
- Photo capture at POIs
- Augmented reality POI overlay
- Voice navigation hints
- Export trail to GPX format
- Trail filtering (by date range, day)
- Progress statistics (avg completion time, daily progress)

---

## Backend API Changelog

### Version 1.0 (2026-03-21) - Initial Release ✅
- ✅ POST /tours/{tour_id}/progress - Update POI completion
- ✅ GET /tours/{tour_id}/progress - Get tour progress
- ✅ POST /tours/{tour_id}/trail - Upload GPS trail (batch)
- ✅ GET /tours/{tour_id}/trail - Get GPS trail
- ✅ Per-user storage model
- ✅ Access control (public/private tours)
- ✅ JWT authentication
- ✅ Language support for POI names

### Upcoming Features (Planned)
- Trail filtering (query by time range, day)
- Trail export (GPX format)
- Shared trails (view other users' trails)
- Progress statistics API

---

## Support & Questions

### Backend Team Contact
- **GitHub Issues:** https://github.com/HongYanHuang/pocket-guide/issues
- **Branch:** `feature/map-mode-api`
- **Documentation:** `/client_docs/MAP_MODE_PLAN.md` (this file)

### Need Help?
- API not working? → Check JWT token and authentication
- Getting 403 errors? → Verify tour access (public vs private)
- Trail upload failing? → Check max 100 points per request
- Need new features? → Open GitHub issue with requirements

### Testing Environment
- **Backend API:** http://localhost:8000
- **API Docs:** http://localhost:8000/docs (Swagger UI)
- **Health Check:** http://localhost:8000/health

---

**Document Version:** 2.0 (Updated: 2026-03-21)
**Backend API Version:** 1.0
**Status:** ✅ Backend Ready for Integration
