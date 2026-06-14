# Tour History & Session Tracking — Client Integration Guide

## Overview

Every time a user starts a tour a **session** is created on the backend. The session records:

- When the tour started and ended
- How long the user was on the tour
- Which POIs were physically visited
- Which audio sections were played, half-played, or skipped
- Exact playback position in seconds (for the future Resume feature)

These sessions power the **History screen** and will power the **Resume Tour** feature.

---

## Session Lifecycle

```
User taps "Start Tour"
        │
        ▼
POST /client/tours/{tour_id}/sessions
        │  ← save session_id locally (e.g. SharedPreferences)
        ▼
   [user on map screen]
        │
        ├── audio paused / app backgrounds
        │       ▼
        │   PATCH .../progress   (repeat as needed)
        │
        ├── user arrives at a POI  →  poi_visited: true in next PATCH
        │
        ├── audio section ends  →  completed: true in PATCH
        │
        └── user exits map screen
                │
                ├── tapped Back (mid-tour)  →  POST .../end { status: "ended" }
                │
                └── tapped "Finish Tour" (all done)  →  POST .../end { status: "completed" }
```

### Session Statuses

| Status | Meaning |
|--------|---------|
| `in_progress` | User is currently on the map screen |
| `completed` | User finished all POIs and tapped "Finish Tour" |
| `ended` | User exited via Back before finishing |
| `abandoned` | Auto-closed by backend (a new session started for the same tour) |

---

## Endpoints

All endpoints require the client JWT:
```
Authorization: Bearer <access_token>
```

---

### 1. Start Session

```
POST /client/tours/{tour_id}/sessions
```

Call this when the user taps **"Start Tour"** and enters the map screen.

**Request body:**
```json
{
  "tour_title": "Rome's Ancient Wonders & Renaissance Treasures · 1 Day",
  "city": "Rome",
  "city_slug": "rome",
  "language": "en",
  "duration_days": 1,
  "total_pois": 8
}
```

| Field | Type | Description |
|-------|------|-------------|
| `tour_title` | string | Full display title including duration (what appears in history) |
| `city` | string | City display name e.g. `"Rome"` |
| `city_slug` | string | City slug e.g. `"rome"`, `"gold-coast"` |
| `language` | string | ISO language code e.g. `"en"`, `"zh-tw"` |
| `duration_days` | int | Number of days in the tour |
| `total_pois` | int | Total number of POI stops in the tour |

**Response `201`:**
```json
{
  "session_id": "a3f1c2d4-8e5b-4a7f-b9c1-2d3e4f5a6b7c",
  "tour_id": "rome-tour-20260419-062648-8f1c9a",
  "started_at": "2026-06-14T09:00:00.000000",
  "orphaned_sessions_closed": 0
}
```

> **Important:** Store `session_id` locally (e.g. in SharedPreferences or a state provider). You will need it for every progress update and to end the session.

> `orphaned_sessions_closed > 0` means there was a previous unfinished session for this tour that was auto-closed. You can safely ignore this value.

---

### 2. Update Audio Progress

```
PATCH /client/tours/{tour_id}/sessions/{session_id}/progress
```

Call this to record where the user is in the audio. **Call on:**
- Audio paused (user taps pause)
- App goes to background (`AppLifecycleState.paused`)
- An audio section completes (set `completed: true`)

**Request body:**
```json
{
  "poi_id": "colosseum",
  "poi_name": "Colosseum",
  "day": 1,
  "section_index": 2,
  "position_seconds": 47.5,
  "total_seconds": 180.0,
  "completed": false,
  "poi_visited": false
}
```

| Field | Type | Description |
|-------|------|-------------|
| `poi_id` | string | POI identifier (kebab-case) e.g. `"colosseum"` |
| `poi_name` | string | Display name e.g. `"Colosseum"` |
| `day` | int | Which day of the tour this POI is on (1-based) |
| `section_index` | int | 0-based index of the audio section within this POI |
| `position_seconds` | float | Current playback position in seconds |
| `total_seconds` | float | Total length of this section in seconds |
| `completed` | bool | `true` when the section has played to the end |
| `poi_visited` | bool | `true` the **first time** the user physically arrives at this POI on the map |

> **`poi_visited`:** Send `true` exactly once — when the user's location triggers the POI geofence (or when they manually tap "I'm here"). On subsequent progress updates for the same POI, send `false` (or omit it).

**Response `200`:**
```json
{
  "session_id": "a3f1c2d4-...",
  "poi_id": "colosseum",
  "section_index": 2,
  "pois_completed": 3
}
```

`pois_completed` reflects the count of POIs where **all** sections have been marked `completed: true`. You can use this to show a progress indicator.

This endpoint is **idempotent** — sending the same position twice is safe.

---

### 3. End Session

```
POST /client/tours/{tour_id}/sessions/{session_id}/end
```

Call this when the user **leaves the map screen**, regardless of how much they completed.

**Request body:**
```json
{
  "status": "ended",
  "pois_completed": 3
}
```

| `status` value | When to use |
|----------------|-------------|
| `"ended"` | User tapped Back / exited mid-tour |
| `"completed"` | User tapped "Finish Tour" after completing all POIs |

`pois_completed` — pass your local count of how many POIs the user finished.

**Response `200`:**
```json
{
  "session_id": "a3f1c2d4-...",
  "status": "ended",
  "total_duration_seconds": 5400,
  "pois_completed": 3,
  "total_pois": 8
}
```

After receiving this response, **clear the stored `session_id`** from local state.

---

### 4. Get History List

```
GET /client/history
```

Returns the authenticated user's tour history, newest first.

**Query parameters:**

| Param | Default | Description |
|-------|---------|-------------|
| `limit` | `50` | Max results (1–200) |
| `offset` | `0` | Pagination offset |
| `status` | _(all)_ | Filter: `in_progress`, `ended`, `completed`, `abandoned` |

**Response `200`:**
```json
[
  {
    "session_id": "a3f1c2d4-8e5b-4a7f-b9c1-2d3e4f5a6b7c",
    "tour_id": "rome-tour-20260419-062648-8f1c9a",
    "tour_title": "Rome's Ancient Wonders & Renaissance Treasures · 1 Day",
    "city": "Rome",
    "city_slug": "rome",
    "language": "en",
    "duration_days": 1,
    "total_pois": 8,
    "pois_completed": 8,
    "status": "completed",
    "started_at": "2026-04-19T09:00:00.000000",
    "ended_at": "2026-04-19T13:30:00.000000",
    "total_duration_seconds": 16200
  },
  {
    "session_id": "b4e2d3f5-...",
    "tour_id": "taipei-tour-20260419-062648-8f1c9a",
    "tour_title": "台北經典文化古蹟探索之旅 · 1 Day",
    "city": "Taipei",
    "city_slug": "taipei",
    "language": "zh-tw",
    "duration_days": 1,
    "total_pois": 6,
    "pois_completed": 3,
    "status": "ended",
    "started_at": "2026-04-15T10:00:00.000000",
    "ended_at": "2026-04-15T12:00:00.000000",
    "total_duration_seconds": 7200
  }
]
```

**Mapping to the History screen UI:**

| UI element | Field |
|-----------|-------|
| Card title | `tour_title` |
| Subtitle (city) | `city_slug` |
| Date shown | `started_at` (format as "Apr 2026") |
| Duration label | `duration_days` → "1 day" |
| In-progress badge | `status == "in_progress"` |
| Progress (future) | `pois_completed / total_pois` |

---

### 5. Get Session Detail

```
GET /client/history/{session_id}
```

Returns full per-POI, per-section audio progress. Used for the detail screen and the future Resume feature.

**Response `200`:**
```json
{
  "session_id": "a3f1c2d4-...",
  "tour_id": "rome-tour-20260419-062648-8f1c9a",
  "tour_title": "Rome's Ancient Wonders & Renaissance Treasures · 1 Day",
  "city": "Rome",
  "city_slug": "rome",
  "language": "en",
  "duration_days": 1,
  "total_pois": 8,
  "pois_completed": 3,
  "status": "ended",
  "started_at": "2026-06-14T09:00:00.000000",
  "ended_at": "2026-06-14T11:00:00.000000",
  "total_duration_seconds": 7200,
  "poi_progress": [
    {
      "poi_id": "colosseum",
      "poi_name": "Colosseum",
      "day": 1,
      "visited": true,
      "visited_at": "2026-06-14T09:30:00.000000",
      "all_sections_completed": true,
      "sections": [
        {
          "section_index": 0,
          "played": true,
          "completed": true,
          "position_seconds": 180.0,
          "total_seconds": 180.0,
          "started_at": "2026-06-14T09:30:00.000000",
          "last_updated_at": "2026-06-14T09:33:00.000000"
        }
      ]
    },
    {
      "poi_id": "roman-forum",
      "poi_name": "Roman Forum",
      "day": 1,
      "visited": true,
      "visited_at": "2026-06-14T10:15:00.000000",
      "all_sections_completed": false,
      "sections": [
        {
          "section_index": 0,
          "played": true,
          "completed": true,
          "position_seconds": 210.0,
          "total_seconds": 210.0,
          "started_at": "2026-06-14T10:15:00.000000",
          "last_updated_at": "2026-06-14T10:18:30.000000"
        },
        {
          "section_index": 1,
          "played": true,
          "completed": false,
          "position_seconds": 47.5,
          "total_seconds": 150.0,
          "started_at": "2026-06-14T10:20:00.000000",
          "last_updated_at": "2026-06-14T10:20:47.000000"
        }
      ]
    }
  ],
  "resume": {
    "poi_id": "roman-forum",
    "poi_name": "Roman Forum",
    "day": 1,
    "section_index": 1,
    "position_seconds": 47.5
  }
}
```

#### The `resume` field

Present only when `status` is `in_progress` or `ended`. Points to the last half-played section.

When implementing the **Resume Tour** feature, use this to:
1. Navigate to the correct POI on the map
2. Seek the audio player to `position_seconds` before playback

`resume` is `null` if no section has been partially played (e.g. the user left without playing any audio).

---

## Error Responses

| Status | Meaning |
|--------|---------|
| `401` | Missing or expired access token — refresh and retry |
| `403` | Token does not have `client_app` scope |
| `404` | Session not found (wrong `session_id`) |
| `409` | Session already ended — cannot update progress or end again |

---

## Flutter Implementation

### 1. Service class

```dart
class TourHistoryService {
  final Dio _dio;
  final String _baseUrl;

  TourHistoryService(this._dio, this._baseUrl);

  // ── Session management ─────────────────────────────────────

  Future<String> startSession({
    required String tourId,
    required String tourTitle,
    required String city,
    required String citySlug,
    required String language,
    required int durationDays,
    required int totalPois,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/client/tours/$tourId/sessions',
      data: {
        'tour_title': tourTitle,
        'city': city,
        'city_slug': citySlug,
        'language': language,
        'duration_days': durationDays,
        'total_pois': totalPois,
      },
    );
    return response.data['session_id'] as String;
  }

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
    bool poiVisited = false,
  }) async {
    await _dio.patch(
      '$_baseUrl/client/tours/$tourId/sessions/$sessionId/progress',
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
    );
  }

  Future<void> endSession({
    required String tourId,
    required String sessionId,
    required bool completed,
    required int poisCompleted,
  }) async {
    await _dio.post(
      '$_baseUrl/client/tours/$tourId/sessions/$sessionId/end',
      data: {
        'status': completed ? 'completed' : 'ended',
        'pois_completed': poisCompleted,
      },
    );
  }

  // ── History ────────────────────────────────────────────────

  Future<List<TourHistorySummary>> getHistory({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/client/history',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (status != null) 'status': status,
      },
    );
    return (response.data as List)
        .map((e) => TourHistorySummary.fromJson(e))
        .toList();
  }

  Future<TourHistoryDetail> getHistoryDetail(String sessionId) async {
    final response = await _dio.get('$_baseUrl/client/history/$sessionId');
    return TourHistoryDetail.fromJson(response.data);
  }
}
```

---

### 2. Storing `session_id` during an active tour

Store the active session in a provider or SharedPreferences so it survives app restarts:

```dart
class ActiveTourSession {
  final String sessionId;
  final String tourId;
  final int totalPois;
  int poisCompleted;

  ActiveTourSession({
    required this.sessionId,
    required this.tourId,
    required this.totalPois,
    this.poisCompleted = 0,
  });
}

// In your state provider / Riverpod notifier:
ActiveTourSession? _activeSession;

Future<void> startTour(Tour tour) async {
  final sessionId = await historyService.startSession(
    tourId: tour.id,
    tourTitle: tour.titleDisplay,
    city: tour.city,
    citySlug: tour.citySlug,
    language: tour.language,
    durationDays: tour.durationDays,
    totalPois: tour.totalPois,
  );

  _activeSession = ActiveTourSession(
    sessionId: sessionId,
    tourId: tour.id,
    totalPois: tour.totalPois,
  );

  // Persist to SharedPreferences in case app restarts mid-tour
  await prefs.setString('active_session_id', sessionId);
  await prefs.setString('active_tour_id', tour.id);
}
```

---

### 3. Sending progress updates

Hook into your audio player's event stream:

```dart
void _setupAudioListeners(AudioPlayer player) {
  // On pause
  player.playerStateStream.listen((state) {
    if (state.processingState == ProcessingState.ready &&
        !state.playing &&
        _activeSession != null) {
      _sendProgressUpdate(completed: false);
    }
  });

  // On section complete
  player.playerStateStream.listen((state) {
    if (state.processingState == ProcessingState.completed &&
        _activeSession != null) {
      _sendProgressUpdate(completed: true);
    }
  });
}

// App lifecycle — send on background
class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _sendProgressUpdate(completed: false);
    }
  }
}

Future<void> _sendProgressUpdate({required bool completed}) async {
  if (_activeSession == null || _currentPoi == null) return;
  final position = await _audioPlayer.position;
  final duration = _audioPlayer.duration ?? Duration.zero;

  await historyService.updateProgress(
    tourId: _activeSession!.tourId,
    sessionId: _activeSession!.sessionId,
    poiId: _currentPoi!.id,
    poiName: _currentPoi!.name,
    day: _currentPoi!.day,
    sectionIndex: _currentSectionIndex,
    positionSeconds: position.inMilliseconds / 1000.0,
    totalSeconds: duration.inMilliseconds / 1000.0,
    completed: completed,
    poiVisited: _justArrivedAtPoi, // true only once per POI
  );

  if (_justArrivedAtPoi) _justArrivedAtPoi = false;
}
```

---

### 4. Ending the session

Call this from `dispose()` or `WillPopScope`/`PopScope`:

```dart
@override
Future<bool> onWillPop() async {
  await _endSession(userFinished: false);
  return true; // allow pop
}

Future<void> onFinishTourTapped() async {
  await _endSession(userFinished: true);
  Navigator.pop(context);
}

Future<void> _endSession({required bool userFinished}) async {
  if (_activeSession == null) return;

  // Send one final progress update before ending
  await _sendProgressUpdate(completed: _currentSectionCompleted);

  await historyService.endSession(
    tourId: _activeSession!.tourId,
    sessionId: _activeSession!.sessionId,
    completed: userFinished && _activeSession!.poisCompleted >= _activeSession!.totalPois,
    poisCompleted: _activeSession!.poisCompleted,
  );

  // Clear local state
  _activeSession = null;
  await prefs.remove('active_session_id');
  await prefs.remove('active_tour_id');
}
```

---

### 5. History screen

```dart
class HistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<TourHistorySummary>>(
        future: historyService.getHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No tours yet'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => HistoryCard(session: items[i]),
          );
        },
      ),
    );
  }
}

class HistoryCard extends StatelessWidget {
  final TourHistorySummary session;

  const HistoryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMM yyyy').format(
      DateTime.parse(session.startedAt),
    );
    final dayLabel = session.durationDays == 1 ? '1 day' : '${session.durationDays} days';

    return ListTile(
      leading: const Icon(Icons.map_outlined),
      title: Text(session.tourTitle),
      subtitle: Text('${session.citySlug}\n$month · $dayLabel'),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.status == 'in_progress')
            const Chip(label: Text('In Progress')),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TourHistoryDetailScreen(sessionId: session.sessionId),
        ),
      ),
    );
  }
}
```

---

## Edge Cases

### App crashes mid-tour

On next app launch, check SharedPreferences for a stored `active_session_id`. If found:
- The session is still `in_progress` on the backend
- When the user starts a new session for the same tour, the backend will auto-close the crashed session as `abandoned`
- No action needed from the frontend — it's handled silently

### Token expires during a long tour

If a progress update returns `401`:
1. Refresh the access token using the refresh token
2. Retry the progress update with the new token
3. Continue normally

### Same tour opened twice

This shouldn't happen in normal UX, but if it does:
- Starting a new session auto-closes the previous one as `abandoned`
- The old session still appears in History with `status: "abandoned"`
- The new session starts fresh

---

## Future: Resume Tour Feature

When implementing Resume, use `GET /client/history/{session_id}` and check the `resume` field:

```dart
Future<void> resumeTour(String sessionId) async {
  final detail = await historyService.getHistoryDetail(sessionId);

  if (detail.resume != null) {
    final r = detail.resume!;
    // Navigate to the map, jump to r.poiId on day r.day
    // Seek audio to r.positionSeconds on section r.sectionIndex
    navigateToMapScreen(
      tourId: detail.tourId,
      resumePoiId: r.poiId,
      resumeDay: r.day,
      resumeSectionIndex: r.sectionIndex,
      resumePositionSeconds: r.positionSeconds,
    );
  } else {
    // No resume point — start from beginning
    navigateToMapScreen(tourId: detail.tourId);
  }
}
```

> Note: when resuming, still call `POST /sessions` to create a new session entry — do **not** re-use the old session_id. The `resume` field tells you *where* to start, not to reopen the old session.
