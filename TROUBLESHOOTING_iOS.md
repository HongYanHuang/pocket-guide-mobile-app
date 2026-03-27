# Troubleshooting iOS Build Issues

## Issue 1: Code Signature Error

**Error:**
```
Failed to verify code signature of .../objective_c.framework : 0xe8008014
(The executable contains an invalid signature.)
```

### Solution:

This error occurs when frameworks aren't properly signed. Follow these steps:

#### Option A: Use Xcode (Recommended)

1. **Open project in Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Select your development team:**
   - Click on "Runner" project in left panel
   - Select "Runner" target
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Select your Apple Developer Team from dropdown
   - If you don't have a team, you can use your personal Apple ID (free)

3. **Add your Apple ID (if needed):**
   - Xcode → Settings → Accounts
   - Click "+" to add account
   - Sign in with your Apple ID
   - This creates a free personal team for development

4. **Build and run from Xcode:**
   - Select your iPhone from device dropdown
   - Click Run button (▶️)

#### Option B: Use Flutter CLI

1. **Clean everything:**
   ```bash
   flutter clean
   rm -rf ios/Pods ios/Podfile.lock
   ```

2. **Reinstall dependencies:**
   ```bash
   flutter pub get
   cd ios && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install && cd ..
   ```

3. **Build with signing:**
   ```bash
   flutter build ios --debug
   ```

   Note: This will prompt you to set up signing in Xcode if not configured.

---

## Issue 2: Local Network Permission

**Error:**
```
Flutter could not access the local network.
SocketException: Send failed (OS Error: No route to host, errno = 65)
```

### Solution:

This is a macOS permission issue. Flutter needs local network access to communicate with your iPhone.

#### Step 1: Grant Terminal/IDE Local Network Permission

1. **Open System Settings:**
   - Click Apple menu → System Settings
   - Or: Open "System Settings" from Applications

2. **Navigate to Privacy & Security:**
   - Click "Privacy & Security" in left sidebar
   - Scroll down and click "Local Network"

3. **Enable for your development tool:**

   **If using VS Code:**
   - Find "Code" in the list
   - Toggle it ON ✅

   **If using Terminal:**
   - Find "Terminal" in the list
   - Toggle it ON ✅

   **If using Android Studio:**
   - Find "Android Studio" in the list
   - Toggle it ON ✅

4. **Restart your IDE/Terminal:**
   - Quit completely (⌘ + Q)
   - Reopen

#### Step 2: Grant Xcode Automation Permission (if needed)

If you see: "You may be prompted to give access to control Xcode"

1. **Open System Settings:**
   - Click Apple menu → System Settings

2. **Navigate to Privacy & Security:**
   - Click "Privacy & Security"
   - Click "Automation"

3. **Find your IDE/Terminal:**
   - Look for "Terminal" or "Code" or "Android Studio"
   - Check the box next to "Xcode" ✅

4. **Restart your development tool**

---

## Quick Fix Checklist

Run through these steps in order:

### 1. Clean Build
```bash
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
cd ios && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install && cd ..
```

### 2. Configure Signing in Xcode
```bash
open ios/Runner.xcworkspace
```
- Select Runner target
- Signing & Capabilities → Select Team
- Build & Run from Xcode first

### 3. Grant macOS Permissions
- System Settings → Privacy & Security → Local Network
- Enable for Terminal/Code/Android Studio
- System Settings → Privacy & Security → Automation
- Enable Xcode access for your development tool

### 4. Test Connection
```bash
flutter devices
```
Should show your iPhone in the list.

### 5. Run the App
```bash
flutter run
```

---

## Common Issues

### "No development team selected"

**Solution:**
1. Open Xcode
2. Add your Apple ID: Xcode → Settings → Accounts → +
3. In project settings, select your personal team
4. Free Apple IDs can deploy to your own device

### "Untrusted Developer"

When you first run the app on your iPhone, you'll see:
```
"Untrusted Enterprise Developer"
```

**Solution:**
1. On your iPhone: Settings → General → VPN & Device Management
2. Find your developer profile
3. Tap "Trust"
4. Confirm

### "iPhone is not available"

**Solution:**
- Unlock your iPhone
- Trust the computer (tap "Trust" when prompted on iPhone)
- Make sure iPhone and Mac are on same network (for wireless debugging)

### "Could not find iPhone"

**Solution:**
1. Connect iPhone with cable
2. Unlock iPhone
3. Trust computer when prompted
4. Run: `flutter devices`
5. Should see iPhone listed

---

## Testing Commands

After fixing the issues, test with these commands:

```bash
# Check if Flutter can see your device
flutter devices

# Expected output:
# iPhone 15 Pro (mobile) • 00008110-XXXX • ios • iOS 18.0

# Run in debug mode
flutter run

# Or build first
flutter build ios --debug
```

---

## Still Having Issues?

### Check Developer Mode (iOS 16+)

1. On iPhone: Settings → Privacy & Security → Developer Mode
2. Toggle ON
3. Restart iPhone
4. Confirm when prompted

### Check iOS Version Compatibility

The app requires iOS 12.0+. Check:
- iPhone Settings → General → About → iOS Version

### Check Xcode Version

```bash
xcodebuild -version
```

Should be Xcode 14+ for iOS 17 development.

---

## Success Indicators

✅ **Code signing fixed when:**
- App installs on your iPhone
- No signature errors in build output

✅ **Network access fixed when:**
- `flutter devices` shows your iPhone
- `flutter run` connects successfully
- No "No route to host" errors

✅ **Everything working when:**
- App launches on iPhone
- Hot reload works
- Console shows debug logs
