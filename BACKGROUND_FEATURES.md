# Background Features Implementation

## Overview

This document describes the implementation of background audio playback and GPS trail tracking when the app is in the background or screen is locked.

---

## 1. Background Audio Playback

### What It Does
- Audio continues playing when screen is locked
- Audio continues when user switches to another app
- Shows media controls on lock screen
- Shows media notification with play/pause controls
- Works like Spotify, YouTube Music, etc.

### Technical Implementation

**Packages:**
- `just_audio` - Audio playback engine
- `audio_service` - System integration (background, notifications, controls)

**Backend Requirements:**
- ✅ **NO CHANGES NEEDED**
- Backend continues serving audio files via HTTP as it currently does
- Works with both Cloudflare tunnel and localhost
- Audio files accessed via: `GET /pois/{city}/{poi_id}/audio/{audio_file}`

**Client Changes:**
- Replace `audioplayers` with `just_audio + audio_service`
- Configure iOS background audio mode in Info.plist
- Configure Android foreground service in AndroidManifest.xml
- Update audio playback code in:
  - `lib/widgets/poi_map_bottom_sheet.dart`
  - `lib/screens/section_list_screen.dart`

---

## 2. Background GPS Trail Tracking

### What It Does
- Continues tracking user location when screen is locked
- Continues tracking when user switches to another app
- Shows persistent notification: "🗺️ Pocket Guide is tracking your tour route"
- Batches coordinates and uploads to backend periodically

### Location Update Intervals

| Mode | Interval | Description |
|------|----------|-------------|
| **Foreground** | 5 seconds | Active tracking with screen on |
| **Background** | 30 seconds | Power-efficient tracking with screen off |

**Note:** `geolocator` package already supports this with the `isBackground` parameter in `startTracking()`.

### Coordinate Upload Strategy

**Background Mode:**
- Collect GPS coordinates locally
- Batch upload every **1 minute**
- Store coordinates in memory queue

**Foreground Mode:**
- Immediate upload on each location update (5s)
- When app returns to foreground, upload all stored coordinates first

**Upload Endpoint:**
Backend needs to provide an endpoint to receive batched coordinates.

---

## 3. Backend API Requirements

### New Endpoint: Batch Upload GPS Trail

The backend needs to provide an endpoint for uploading batched GPS coordinates.

#### Endpoint

```
POST /client/tours/{tour_id}/trail/batch
```

#### Authentication
```
Authorization: Bearer {access_token}
```

#### Request Body

```json
{
  "coordinates": [
    {
      "latitude": 41.9028,
      "longitude": 12.4964,
      "timestamp": "2026-03-27T10:15:30Z",
      "accuracy": 10.5,
      "altitude": 20.0,
      "heading": 45.0,
      "speed": 1.2
    },
    {
      "latitude": 41.9029,
      "longitude": 12.4965,
      "timestamp": "2026-03-27T10:15:35Z",
      "accuracy": 8.2,
      "altitude": 21.0,
      "heading": 47.0,
      "speed": 1.3
    }
    // ... more coordinates
  ],
  "day": 1,
  "upload_type": "background" // or "foreground"
}
```

#### Fields Description

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `coordinates` | Array | Yes | Array of GPS coordinates |
| `coordinates[].latitude` | Float | Yes | Latitude in decimal degrees |
| `coordinates[].longitude` | Float | Yes | Longitude in decimal degrees |
| `coordinates[].timestamp` | String (ISO 8601) | Yes | UTC timestamp when coordinate was recorded |
| `coordinates[].accuracy` | Float | Yes | Accuracy in meters |
| `coordinates[].altitude` | Float | No | Altitude in meters (if available) |
| `coordinates[].heading` | Float | No | Heading in degrees (0-360, if available) |
| `coordinates[].speed` | Float | No | Speed in m/s (if available) |
| `day` | Integer | Yes | Tour day number |
| `upload_type` | String | Yes | `"background"` or `"foreground"` |

#### Response

```json
{
  "status": "success",
  "coordinates_received": 120,
  "trail_updated": true
}
```

#### Error Responses

**401 Unauthorized**
```json
{
  "detail": "Invalid or expired token"
}
```

**404 Not Found**
```json
{
  "detail": "Tour not found or not owned by user"
}
```

**400 Bad Request**
```json
{
  "detail": "Invalid coordinate data"
}
```

---

## 4. iOS Configuration

### Info.plist Changes

Add background modes:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>location</string>
</array>
```

**Already have location permissions** ✅:
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

---

## 5. Android Configuration

### AndroidManifest.xml Changes

Add permissions:

```xml
<!-- Foreground service for background location and audio -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

<!-- Background location for Android 10+ -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Wake lock to keep service alive -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Add foreground service:

```xml
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>
```

---

## 6. User Experience

### Audio Playback
1. User taps play on audio section
2. Audio starts playing
3. User locks screen → Audio continues ✅
4. Lock screen shows: "🎵 POI Name - Section Title" with play/pause controls
5. Notification shows media controls
6. User can control playback from notification/lock screen

### Trail Tracking
1. User starts tour in active mode
2. Location tracking begins (5s intervals)
3. User locks screen → Tracking continues at 30s intervals ✅
4. Notification shows: "🗺️ Pocket Guide is tracking your tour route"
5. Coordinates batched and uploaded every 1 minute
6. User unlocks screen → Returns to 5s intervals, uploads stored batch

---

## 7. Battery Optimization

### Background Location
- 30-second intervals reduce battery drain
- Only updates when user moves 10+ meters (distance filter)
- Automatically stops when tour ends

### Coordinate Upload
- Batch uploads reduce network overhead
- Failed uploads retry on next batch
- Uses exponential backoff on errors

### Audio
- Efficient streaming (no full file download)
- Pauses automatically when section ends
- Releases resources when stopped

---

## 8. Testing Checklist

### Audio Background Testing
- [ ] Play audio → Lock screen → Audio continues
- [ ] Play audio → Switch to another app → Audio continues
- [ ] Play audio → Press play/pause on lock screen → Works
- [ ] Play audio → Use headphone buttons → Works
- [ ] Notification shows correct POI name and controls

### Trail Background Testing
- [ ] Start tour → Lock screen → Location updates every 30s
- [ ] Verify coordinates are batched and uploaded every 1 minute
- [ ] Unlock screen → Location updates every 5s
- [ ] Notification shows "🗺️ Pocket Guide is tracking your tour route"
- [ ] End tour → Tracking stops, notification disappears

### Network Testing
- [ ] Background upload works on WiFi
- [ ] Background upload works on cellular
- [ ] Failed uploads retry correctly
- [ ] App switches between localhost (web) and Cloudflare (mobile)

---

## 9. Implementation Order

1. **iOS Info.plist**: Add background modes
2. **Android Manifest**: Add permissions and service
3. **Audio Service**: Create audio service wrapper
4. **Migrate Audio**: Replace audioplayers with just_audio
5. **Trail Upload**: Implement batch coordinate upload
6. **Location Service**: Add background mode support
7. **API Service**: Add batch trail upload endpoint call
8. **Testing**: Test on physical devices (iOS and Android)

---

## Summary for Backend Team

### What Backend Needs to Do:

1. **Create ONE new endpoint**: `POST /client/tours/{tour_id}/trail/batch`
   - Accepts array of GPS coordinates
   - Requires authentication (Bearer token)
   - Stores trail data for the tour

2. **No changes to existing audio endpoints** ✅
   - Audio continues to be served via HTTP
   - No streaming protocol changes needed
   - Works with current setup

### What Backend DOESN'T Need to Do:

- ❌ No audio streaming protocol changes
- ❌ No WebSocket connections
- ❌ No real-time coordinate updates
- ❌ No changes to existing POI audio endpoints
- ❌ No special CORS or headers for background requests

The audio solution is entirely client-side. The GPS batching is a new feature but uses standard REST API patterns.
