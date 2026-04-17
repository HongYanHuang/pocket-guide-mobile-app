# Geofencing Feature — API Requirements

**Feature:** Auto-play audio guide when user enters POI radius. Resume section progress across sessions.
**Status:** Planning — ready for backend review  
**Mobile team contact:** Pocket Guide Mobile App

---

## Summary

Two new backend endpoints are needed. All other existing endpoints remain unchanged.

| # | Endpoint | Priority |
|---|---|---|
| 1 | `POST /tours/{tourId}/audio-progress` | **Required for launch** |
| 2 | `POST /tours/{tourId}/gps-completion` | Post-launch enhancement |

---

## Context: How Geofencing Works on Mobile

### Android
- Continuous GPS monitoring when tour is active (foreground service)
- When user enters **80m radius** of a POI: automatically interrupt any playing audio and play the POI guide
- Audio plays section by section (section 1 → 2 → 3...)
- When all sections complete → `POST /tours/{tourId}/progress` (existing endpoint, already in use)

### iOS
- OS-level geofencing (Core Location) — works even when app is killed
- Fires a local notification: *"You've arrived at Colosseum — tap to hear the guide"*
- User taps → app opens, map screen highlights that POI, bottom sheet opens with audio ready
- Same section-by-section playback and completion logic as Android

### Completion state
- Mobile explicitly POSTs `{ poiId, completed: true }` when all sections finish playing
- This is the **primary source of truth** for POI completion
- GPS trail inference (described below) is a backend-side supplement

---

## Endpoint 1 (Required): Audio Section Progress

### Why
Users may listen to sections 1–2 of a 4-section guide, close the app, and return later. They should resume from section 3, not restart. This progress must be stored on the backend so it survives app reinstalls and works across devices.

### Sync strategy (no recursive calls)
Mobile updates section progress locally (device storage) immediately on each section change. It syncs to backend at these events only:
1. All sections of a POI complete → POST immediately
2. App goes to background (`AppLifecycleState.paused`) → flush pending progress
3. App is killed → best-effort flush

### Request

```
POST /tours/{tourId}/audio-progress
Authorization: Bearer {access_token}

{
  "poi_id": "colosseum",
  "day": 1,
  "completed_sections": [1, 2],       // 1-indexed section numbers played so far
  "last_section_index": 1,             // 0-indexed, last section the user was on
  "total_sections": 4,
  "all_sections_completed": false      // true when fully done
}
```

### Response

```json
// 200 OK
{
  "poi_id": "colosseum",
  "day": 1,
  "last_section_index": 1,
  "completed_sections": [1, 2],
  "all_sections_completed": false,
  "updated_at": "2026-04-17T10:32:00Z"
}
```

### GET endpoint (for resume on app open)

```
GET /tours/{tourId}/audio-progress?language=en
Authorization: Bearer {access_token}
```

Response:

```json
{
  "tour_id": "rome-tour-20260320-175540-6b0704",
  "audio_progress": [
    {
      "poi_id": "colosseum",
      "day": 1,
      "last_section_index": 1,
      "completed_sections": [1, 2],
      "all_sections_completed": false,
      "updated_at": "2026-04-17T10:32:00Z"
    },
    {
      "poi_id": "roman-forum",
      "day": 1,
      "last_section_index": 3,
      "completed_sections": [1, 2, 3, 4],
      "all_sections_completed": true,
      "updated_at": "2026-04-17T11:15:00Z"
    }
  ]
}
```

Mobile uses this on tour load to seed the local resume cache. No polling — fetched once per session.

---

## Endpoint 2 (Post-Launch): GPS Trail Inference for POI Completion

### Why
Edge cases where explicit mobile POST may not fire:
- App crashes while user is at a POI
- User visited a POI before activating the tour
- Audio was unavailable for a POI but user was clearly there

### How (backend-side only — zero mobile changes)
Backend runs a background job that analyses uploaded GPS trails:
- If trail shows user within 80m of a POI for **≥ 60 consecutive seconds** → mark as visited
- Does not overwrite an existing explicit completion — only fills gaps

### Request (mobile-triggered, optional)

```
POST /tours/{tourId}/gps-completion
Authorization: Bearer {access_token}

{
  "request_inference": true   // ask backend to run inference on existing trail now
}
```

Mobile calls this once when the tour ends or app resumes, as a best-effort catch-up. Backend can also run this as a scheduled job without mobile triggering it.

---

## Existing Endpoints Used by Geofencing (No Changes Needed)

| Endpoint | Used for |
|---|---|
| `GET /tours/{tourId}` | POI coordinates (lat/lng already in TourPOI) |
| `GET /pois/{city}/{poiId}/sectioned-transcript` | Fetch audio sections at geofence trigger |
| `GET /pois/{city}/{poiId}/audio/{audioFile}` | Stream audio section files |
| `POST /tours/{tourId}/progress` | Mark POI complete when all sections finish |
| `GET /tours/{tourId}/progress` | Load existing completion state on resume |

---

## Optional Future Enhancement: Per-POI Geofence Radius

Add optional field to `TourPOI` schema in OpenAPI spec:

```json
"geofence_radius_meters": {
  "type": "integer",
  "nullable": true,
  "description": "Custom geofence radius in metres. Client defaults to 80m when absent.",
  "example": 150
}
```

Allows tour authors to set wider radii for large parks/museums and tighter radii for small statues. Not blocking launch.

---

## iOS Notification Payload

When Core Location fires a geofence event (app killed/background), mobile sends a local notification. No backend involvement — this is client-side only.

Notification format:
- **Title:** `"You've arrived at Colosseum"`
- **Body:** `"Tap to hear your audio guide"`
- **Sound:** Short custom chime (~2s)
- **Data payload:** `{ "tourId": "...", "poiId": "colosseum", "day": 1 }` — used to open the correct POI when user taps

---

## Behaviour Summary

| Scenario | Behaviour |
|---|---|
| Enter 80m radius, tour active, POI not done | Auto-play (Android) / Notify (iOS) |
| Enter 80m radius, tour not active | Nothing |
| Enter 80m radius, POI already completed | Silently skip |
| Re-enter radius of completed POI | Silently skip |
| All sections of POI finish playing | Mark POI complete via existing `/progress` endpoint |
| User closes app mid-section | Save section index locally + sync to backend on app lifecycle events |
| User reopens app | Fetch `/audio-progress`, resume from last section |
| Another app is playing audio (Android) | Tour audio takes focus, other app pauses |
| Phone call during audio | Audio pauses, resumes automatically after call |
