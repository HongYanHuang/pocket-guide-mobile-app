# Map Mode - Active Tour Implementation Plan

## Overview
Transform tour viewing into an active, location-aware experience with real-time GPS tracking, audio playback, and completion tracking.

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

### Backend API Requirements (Need Backend Team)
```
POST   /tours/{tour_id}/progress
       Body: { poi_id: string, day: int, completed: bool }
       Response: { success: bool }

GET    /tours/{tour_id}/progress
       Response: { completions: [{ poi_id, day, completed, completed_at }] }

POST   /tours/{tour_id}/trail
       Body: { points: [{ lat, lng, timestamp, accuracy }] }
       Response: { success: bool }

GET    /tours/{tour_id}/trail
       Response: { points: [{ lat, lng, timestamp }] }
```

---

## Implementation Phases

### Phase 1: Basic Map UI (Week 1)
- [ ] Add dependencies to pubspec.yaml
- [ ] Create MapTourScreen with flutter_map
- [ ] Display POI markers with numbers
- [ ] Draw lines connecting POIs
- [ ] Add "Start Tour" and "Preview in Map" buttons to tour details page
- [ ] Implement active/preview mode toggle

### Phase 2: GPS Tracking (Week 1-2)
- [ ] Create LocationService for GPS tracking
- [ ] Request location permissions on active mode entry
- [ ] Show user's current location as blue dot
- [ ] Implement 5s (active) / 30s (background) update intervals
- [ ] Handle permission denied scenarios

### Phase 3: Trail Recording (Week 2)
- [ ] Record GPS points to local list
- [ ] Draw trail polyline on map
- [ ] Implement periodic trail saving to backend
- [ ] Add trail visualization options

### Phase 4: Audio Player Integration (Week 2-3)
- [ ] Create POIBottomSheet widget
- [ ] Integrate audio player from existing code
- [ ] Implement bottom sheet slide up/down
- [ ] Create MiniAudioPlayer widget
- [ ] Handle audio playback state across widgets
- [ ] Add "Navigate" button → url_launcher to Google Maps

### Phase 5: Auto-Completion (Week 3)
- [ ] Monitor user distance to each POI
- [ ] Track audio completion per POI
- [ ] Auto-mark complete when: within 100m + all audio finished
- [ ] Add manual complete/uncomplete buttons
- [ ] Sync completion status to backend

### Phase 6: Multi-Day Support (Week 3)
- [ ] Create DaySelector widget
- [ ] Filter POIs by selected day
- [ ] Save active day state
- [ ] Update markers based on day

### Phase 7: Polish & Testing (Week 4)
- [ ] Handle edge cases (no GPS signal, permission issues)
- [ ] Optimize performance (don't track when user is stationary)
- [ ] Add loading states
- [ ] Error handling and user feedback
- [ ] Test on real devices outdoors

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

## Open Questions for Backend Team

1. **Trail Data Format:** What format do you prefer for GPS points?
   - Array of objects with lat/lng/timestamp?
   - Compressed format (encoded polyline)?

2. **Trail Storage Frequency:** How often should we batch-upload trail points?
   - Every 1 minute?
   - Every 10 points?
   - When user leaves the map?

3. **Privacy & Data Retention:**
   - How long should trail data be stored?
   - Can users delete their trail history?

4. **Progress Sync Strategy:**
   - Real-time update on every completion?
   - Batch update on app close?

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
