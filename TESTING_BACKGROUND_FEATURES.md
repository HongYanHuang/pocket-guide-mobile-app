# Testing Background Features

## Prerequisites

1. **Backend Requirements:**
   - Backend must have the new batch endpoint implemented: `POST /client/tours/{tour_id}/trail/batch`
   - Backend should be running (localhost for web, Cloudflare for mobile)

2. **Build Requirements:**
   - Run `flutter pub get` to install new packages (just_audio, audio_service)
   - For iOS: May need to run `cd ios && pod install` to update CocoaPods
   - For Android: May need to rebuild to apply manifest changes

## Test 1: Background Audio Playback

### Setup
1. Build and run the app on a physical device (iOS or Android)
2. Navigate to a tour with audio content
3. Open a POI with audio sections

### Test Steps

**Test 1.1: Lock Screen Playback**
1. Tap play on an audio section
2. Wait for audio to start playing
3. Lock the screen (press power button)
4. **Expected:** Audio continues playing ✅
5. **Expected:** Lock screen shows media controls with POI name ✅
6. Unlock screen
7. **Expected:** Audio still playing, UI shows correct state ✅

**Test 1.2: App Backgrounding**
1. Start audio playback
2. Switch to another app (home button → open another app)
3. **Expected:** Audio continues playing ✅
4. **Expected:** Notification shows media controls ✅
5. Return to Pocket Guide app
6. **Expected:** Audio still playing, UI in sync ✅

**Test 1.3: Lock Screen Controls**
1. Start audio playback
2. Lock screen
3. Use lock screen media controls to pause
4. **Expected:** Audio pauses ✅
5. Use lock screen controls to resume
6. **Expected:** Audio resumes ✅

**Test 1.4: Notification Controls**
1. Start audio playback
2. Background the app
3. Swipe down notification panel
4. Use notification play/pause button
5. **Expected:** Audio responds to controls ✅

---

## Test 2: Background GPS Tracking

### Setup
1. Build and run app on physical device
2. Create/open a personalized tour
3. Start tour in active mode
4. Allow location permissions (Always if prompted)

### Test Steps

**Test 2.1: Foreground Tracking**
1. Start tour in active mode
2. Wait for GPS to activate
3. Walk around for 1 minute
4. Check console output for:
   ```
   📍 [Foreground] Location: ...
   📤 Uploading trail batch: X coordinates
   ```
5. **Expected:** Location updates every ~5 seconds ✅
6. **Expected:** Trail points appear on map ✅

**Test 2.2: Background Tracking**
1. With tour active and GPS tracking
2. Lock the screen or background the app
3. Wait for console message:
   ```
   📱 App going to background
   📍 Switching to 30s GPS intervals + 1min batch uploads
   ```
4. Walk around for 2-3 minutes (keep screen locked)
5. Unlock/foreground the app
6. Check console for:
   ```
   📍 [Background] Location: ...
   📦 Batch size: X coordinates
   📤 Uploading batch: X coordinates
   ```
7. **Expected:** Location updates every ~30 seconds while backgrounded ✅
8. **Expected:** Coordinates batched and uploaded every 1 minute ✅

**Test 2.3: Foreground Resume**
1. Background app with GPS tracking
2. Walk around for 1 minute (backgrounded)
3. Return to foreground
4. Check console for:
   ```
   📱 App resuming to foreground
   📍 Switching to 5s GPS intervals + immediate uploads
   📤 Uploading batch: X coordinates  (stored batch)
   ```
5. **Expected:** Stored coordinates uploaded immediately ✅
6. **Expected:** Tracking switches back to 5s intervals ✅

**Test 2.4: Background Notification**
1. Start tour with GPS tracking
2. Background the app
3. **Expected:** Persistent notification shows: "🗺️ Pocket Guide is tracking your tour route" ✅
4. End tour
5. **Expected:** Notification disappears ✅

---

## Test 3: Combined Audio + GPS Background

### Test Steps

**Test 3.1: Both Features in Background**
1. Start tour in active mode (GPS tracking active)
2. Start audio playback on a POI
3. Lock the screen
4. Wait 2 minutes
5. **Expected:** Audio continues playing ✅
6. **Expected:** GPS tracking continues (30s intervals) ✅
7. **Expected:** Lock screen shows audio controls ✅
8. **Expected:** Notification shows tracking status ✅
9. Unlock screen
10. **Expected:** Both audio and map in sync ✅

---

## Test 4: Network Conditions

**Test 4.1: Offline to Online**
1. Start GPS tracking
2. Turn off WiFi/cellular
3. Walk around for 1 minute
4. Check console for:
   ```
   ❌ Trail upload failed: ...
   📦 Moved X points to offline queue for retry
   ```
5. Turn on WiFi/cellular
6. Wait 1 minute
7. **Expected:** Offline queue uploads successfully ✅

**Test 4.2: API Base URL**
1. Test on Chrome: Should use `http://localhost:8000` ✅
2. Test on iOS: Should use Cloudflare tunnel URL ✅
3. Check console at app start:
   ```
   🌐 API Service initialized
      Platform: Web (Chrome) or Mobile (iOS/Android)
      Base URL: ...
   ```

---

## Test 5: Permissions

**iOS Test**
1. First launch: Should request "While Using" permission
2. If tracking enabled: Should prompt for "Always" permission
3. Check Settings → Pocket Guide → Location
4. **Expected:** "Always" option available ✅

**Android Test**
1. First launch: Should request location permission
2. For Android 10+: Should request background location
3. **Expected:** App works with "Allow all the time" permission ✅

---

## Expected Console Output

### Audio Service Initialization
```
🎵 Initializing background audio service...
✅ Background audio service initialized
```

### Audio Playback
```
🎵 Playing audio: [Section Title]
   URL: http://localhost:8000/pois/...
```

### GPS Foreground Mode
```
📍 Starting location tracking (5s active)...
✅ Initial location: 41.9028, 12.4964
📍 [Foreground] Location: 41.9029, 12.4965 (accuracy: 10.5m)
📤 Uploading trail batch: 5 coordinates
✅ Trail batch uploaded: 5 coordinates received
```

### GPS Background Mode
```
📱 App going to background
🌙 Entering background location tracking mode...
✅ Background mode active (30s intervals, 1min batches)
📍 [Background] Location: 41.9030, 12.4966
📦 Batch size: 15 coordinates
📤 Uploading batch: 15 coordinates
✅ Trail batch uploaded: 15 coordinates received
```

### GPS Foreground Resume
```
📱 App resuming to foreground
☀️ Entering foreground location tracking mode...
📤 Uploading batch: 10 coordinates  (stored batch)
✅ Foreground mode active (5s intervals, immediate updates)
```

---

## Common Issues

### Audio Not Playing in Background

**iOS:**
- Check Info.plist has `UIBackgroundModes` with `audio`
- Restart app after adding background modes
- Check device is not in silent mode with vibrate

**Android:**
- Check AndroidManifest.xml has all required permissions
- Check notification permission is granted
- May need to disable battery optimization for the app

### GPS Not Tracking in Background

**iOS:**
- Check "Always" location permission is granted
- Check Info.plist has `UIBackgroundModes` with `location`
- Check `NSLocationAlwaysAndWhenInUseUsageDescription` is present

**Android:**
- Check `ACCESS_BACKGROUND_LOCATION` permission granted
- For Android 10+: Must explicitly request background location
- Check battery optimization disabled
- Check "Location" is enabled in device settings

### Batch Upload Failing

**Backend Issues:**
- Verify endpoint `POST /client/tours/{tour_id}/trail/batch` exists
- Check backend logs for errors
- Verify request format matches expected schema
- Check authentication token is valid

**Network Issues:**
- Check device has internet connection
- Verify API baseUrl is correct (localhost for web, Cloudflare for mobile)
- Check CORS if testing on web

### Audio Service Not Initializing

**Common Causes:**
- Packages not installed: Run `flutter pub get`
- iOS pods not updated: Run `cd ios && pod install`
- Build cache: Run `flutter clean && flutter pub get`
- Platform-specific: Test on actual device, not simulator/emulator

---

## Testing Checklist

### Before Testing
- [ ] Backend `/client/tours/{tour_id}/trail/batch` endpoint implemented
- [ ] Backend is running (localhost:8000 or Cloudflare)
- [ ] `flutter pub get` completed successfully
- [ ] iOS: `pod install` completed (if needed)
- [ ] Build successful (no errors)

### Audio Tests
- [ ] Audio plays in foreground
- [ ] Audio continues when screen locks
- [ ] Audio continues when app backgrounds
- [ ] Lock screen controls work
- [ ] Notification controls work
- [ ] Audio UI state stays in sync

### GPS Tests
- [ ] Foreground tracking (5s intervals)
- [ ] Background tracking (30s intervals)
- [ ] Batch uploads (1min intervals)
- [ ] Foreground resume uploads stored batch
- [ ] Trail displays on map
- [ ] Offline queue works

### Integration Tests
- [ ] Audio + GPS work together in background
- [ ] Notifications show correct info
- [ ] Battery drain is reasonable
- [ ] No crashes or memory leaks

### Platform Tests
- [ ] iOS physical device
- [ ] Android physical device
- [ ] Web (Chrome) - audio only, no GPS background

---

## Debug Commands

### View real-time logs (iOS)
```bash
flutter logs
```

### View Android logs
```bash
adb logcat | grep flutter
```

### Check background tasks (iOS)
Settings → Developer → Background App Refresh → Pocket Guide (should be ON)

### Check battery optimization (Android)
Settings → Battery → Battery optimization → Pocket Guide (should be "Not optimized")

---

## Success Criteria

✅ **Audio Background Playback**
- Audio plays continuously when screen locked
- Audio plays continuously when app backgrounded
- Lock screen media controls work
- Notification media controls work

✅ **GPS Background Tracking**
- Location updates continue in background (30s)
- Coordinates batched and uploaded (1min)
- Stored coordinates uploaded when returning to foreground
- Tracking notification shows
- Battery drain is acceptable

✅ **Platform Support**
- iOS: All features work
- Android: All features work
- Web: Audio background works (GPS not applicable)

✅ **Integration**
- Audio + GPS work simultaneously in background
- No conflicts between features
- App remains stable under all conditions
