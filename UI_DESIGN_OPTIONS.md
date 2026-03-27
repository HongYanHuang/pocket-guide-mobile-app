# UI Design Options for iOS-Style App

## Option 1: Flutter Cupertino Widgets (Built-in iOS Style) ⭐ RECOMMENDED

### What is it?
Flutter's built-in iOS-style widgets that match native iOS design perfectly.

### Examples:

```dart
// iOS-style navigation bar
CupertinoNavigationBar(
  middle: Text('Pocket Guide'),
  trailing: CupertinoButton(
    child: Icon(CupertinoIcons.settings),
    onPressed: () {},
  ),
)

// iOS-style buttons
CupertinoButton(
  color: CupertinoColors.activeBlue,
  child: Text('Start Tour'),
  onPressed: () {},
)

// iOS-style lists
CupertinoListSection(
  header: Text('TOURS'),
  children: [
    CupertinoListTile(
      title: Text('Rome Walking Tour'),
      subtitle: Text('3 days • 15 POIs'),
      trailing: CupertinoListTileChevron(),
      onTap: () {},
    ),
  ],
)

// iOS-style alerts
CupertinoAlertDialog(
  title: Text('Start Tour?'),
  content: Text('This will enable GPS tracking.'),
  actions: [
    CupertinoDialogAction(
      child: Text('Cancel'),
      onPressed: () {},
    ),
    CupertinoDialogAction(
      isDefaultAction: true,
      child: Text('Start'),
      onPressed: () {},
    ),
  ],
)
```

### Pros:
- ✅ Built into Flutter (no dependencies)
- ✅ Looks exactly like native iOS
- ✅ Smooth iOS animations
- ✅ Well-documented
- ✅ Maintained by Flutter team

### Cons:
- ❌ Looks out of place on Android
- ❌ Requires rewriting existing Material widgets

### When to Use:
- iOS-first apps
- Apps targeting primarily iPhone users
- When you want authentic iOS feel

---

## Option 2: FluentUI (Microsoft Design)

### What is it?
Microsoft's Fluent Design System for Flutter - modern, clean, minimalist.

**Package:** `fluent_ui: ^4.9.1`

### Examples:

```dart
// Fluent navigation
NavigationView(
  appBar: NavigationAppBar(
    title: Text('Pocket Guide'),
    actions: Icon(FluentIcons.settings),
  ),
  pane: NavigationPane(
    items: [
      PaneItem(
        icon: Icon(FluentIcons.map),
        title: Text('Tours'),
      ),
    ],
  ),
)

// Fluent cards
Card(
  child: Column(
    children: [
      Text('Rome Walking Tour'),
      FilledButton(
        child: Text('Start Tour'),
        onPressed: () {},
      ),
    ],
  ),
)
```

### Pros:
- ✅ Modern, clean design
- ✅ Great for productivity apps
- ✅ Consistent across platforms
- ✅ Active development

### Cons:
- ❌ Less iOS-native feel
- ❌ Smaller community than Material

---

## Option 3: Macos UI (Apple-style Design)

### What is it?
macOS/iOS inspired design system for Flutter.

**Package:** `macos_ui: ^2.2.1`

### Examples:

```dart
MacosWindow(
  sidebar: Sidebar(
    builder: (context, scrollController) {
      return SidebarItems(
        items: [
          SidebarItem(
            leading: MacosIcon(CupertinoIcons.map),
            label: Text('Tours'),
          ),
        ],
      );
    },
  ),
)

// macOS-style buttons
PushButton(
  buttonSize: ButtonSize.large,
  child: Text('Start Tour'),
  onPressed: () {},
)
```

### Pros:
- ✅ Apple aesthetic
- ✅ Great for iPad/desktop
- ✅ Modern design

### Cons:
- ❌ Better for desktop than mobile
- ❌ Smaller ecosystem

---

## Option 4: Custom Design System (Best for Unique Brand)

Create your own reusable components following iOS design principles.

### Structure:

```
lib/
  design_system/
    colors.dart          # Color palette
    typography.dart      # Text styles
    spacing.dart         # Spacing constants
    components/
      pg_button.dart     # Custom button
      pg_card.dart       # Custom card
      pg_nav_bar.dart    # Custom navigation
```

### Example:

```dart
// lib/design_system/colors.dart
class PGColors {
  static const primary = Color(0xFF007AFF);  // iOS blue
  static const background = Color(0xFFF2F2F7); // iOS background
  static const secondaryBackground = Color(0xFFFFFFFF);
  static const label = Color(0xFF000000);
  static const secondaryLabel = Color(0xFF3C3C43);
  static const separator = Color(0x3C3C434A);
}

// lib/design_system/typography.dart
class PGTypography {
  static const largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
  );

  static const title1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
  );

  static const body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
  );
}

// lib/design_system/components/pg_button.dart
class PGButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  const PGButton({
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      color: isPrimary ? PGColors.primary : null,
      borderRadius: BorderRadius.circular(10),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(text, style: PGTypography.body),
      onPressed: onPressed,
    );
  }
}
```

---

## Recommended Approach for Pocket Guide

### Phase 1: Use Cupertino Widgets (Quick Win)

Start by replacing Material widgets with Cupertino equivalents:

**Current (Material):**
```dart
AppBar(
  title: Text('Tours'),
  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
)
```

**Better (Cupertino):**
```dart
CupertinoNavigationBar(
  middle: Text('Tours'),
  backgroundColor: CupertinoColors.systemBackground,
)
```

### Phase 2: Add Design System Layer

Create a thin layer over Cupertino for consistency:

```dart
// lib/design_system/pg_design.dart
class PGDesign {
  // Colors (iOS-inspired)
  static const primaryBlue = Color(0xFF007AFF);
  static const systemGray = Color(0xFF8E8E93);
  static const separator = Color(0xFFD1D1D6);

  // Spacing
  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;

  // Border radius
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;

  // Shadows (subtle iOS-style)
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];
}
```

### Phase 3: Custom Components

Build reusable components:

```dart
// Tour card with iOS style
class TourCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: PGDesign.spacingM,
          vertical: PGDesign.spacingS,
        ),
        padding: EdgeInsets.all(PGDesign.spacingM),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(PGDesign.radiusM),
          boxShadow: PGDesign.cardShadow,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PGDesign.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CupertinoIcons.map_fill,
                color: PGDesign.primaryBlue,
              ),
            ),
            SizedBox(width: PGDesign.spacingM),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## UI Kit Resources to Review

### 1. iOS Human Interface Guidelines
**Link:** https://developer.apple.com/design/human-interface-guidelines/

Best resource for iOS design principles. Shows:
- Typography scales
- Color systems
- Spacing guidelines
- Component behaviors

### 2. Flutter Cupertino Gallery
**Link:** https://gallery.flutter.dev/#/demo/cupertino

Interactive demo of all Cupertino widgets.

### 3. Apple Design Resources
**Link:** https://developer.apple.com/design/resources/

Download:
- SF Symbols (iOS icons)
- iOS UI templates
- Design files

### 4. Mobbin (iOS App Design Inspiration)
**Link:** https://mobbin.com/browse/ios/apps

Browse real iOS apps for inspiration. Filter by:
- Travel & Navigation
- Maps
- Audio/Media

### 5. Dribbble iOS Designs
**Link:** https://dribbble.com/search/ios-app

Search terms:
- "travel app ios"
- "tour guide ios"
- "map navigation ios"

---

## Specific Recommendations for Your App

### Current Issues:
1. Mix of Material and custom widgets
2. Inconsistent spacing
3. Android-style cards and buttons
4. No unified color scheme

### Suggested Changes:

#### 1. Navigation
**Before:** Material AppBar
**After:** CupertinoNavigationBar with blur effect

#### 2. Tour Cards
**Before:** Material Card with sharp corners
**After:** iOS-style rounded cards with subtle shadows

#### 3. Buttons
**Before:** Material ElevatedButton
**After:** CupertinoButton or custom PGButton

#### 4. Lists
**Before:** ListView with ListTile
**After:** CupertinoListSection with CupertinoListTile

#### 5. Dialogs
**Before:** Material AlertDialog
**After:** CupertinoAlertDialog

#### 6. Bottom Sheets
**Before:** Material showModalBottomSheet
**After:** CupertinoModalPopup with rounded top corners

---

## Quick Start Guide

### Step 1: Add SF Symbols (iOS Icons)

```yaml
# pubspec.yaml
dependencies:
  cupertino_icons: ^1.0.8
  flutter_svg: ^2.0.10  # For custom icons
```

### Step 2: Use CupertinoApp Instead of MaterialApp

```dart
// lib/main.dart
CupertinoApp(
  theme: CupertinoThemeData(
    primaryColor: Color(0xFF007AFF),
    scaffoldBackgroundColor: Color(0xFFF2F2F7),
    barBackgroundColor: Color(0xFFF9F9F9),
  ),
  home: MyHomePage(),
)
```

### Step 3: Replace One Screen at a Time

Start with the most visible screen (probably tour list):
1. Replace AppBar → CupertinoNavigationBar
2. Replace Cards → Custom iOS-style containers
3. Replace Buttons → CupertinoButton
4. Test and iterate

---

## Sample Color Palette (iOS-inspired)

```dart
class PGColors {
  // Primary colors (iOS blue family)
  static const primary = Color(0xFF007AFF);
  static const primaryLight = Color(0xFF5AC8FA);
  static const primaryDark = Color(0xFF0051D5);

  // Backgrounds
  static const background = Color(0xFFF2F2F7);      // iOS system background
  static const secondaryBackground = Color(0xFFFFFFFF);  // Cards
  static const tertiaryBackground = Color(0xFFF2F2F7);   // Grouped backgrounds

  // Labels
  static const label = Color(0xFF000000);
  static const secondaryLabel = Color(0xFF3C3C43).withOpacity(0.6);
  static const tertiaryLabel = Color(0xFF3C3C43).withOpacity(0.3);

  // Separators
  static const separator = Color(0x3C3C43).withOpacity(0.29);
  static const opaqueSeparator = Color(0xFFC6C6C8);

  // System colors
  static const systemRed = Color(0xFFFF3B30);
  static const systemGreen = Color(0xFF34C759);
  static const systemOrange = Color(0xFFFF9500);
  static const systemGray = Color(0xFF8E8E93);
}
```

---

## Next Steps

1. **Review Resources:** Spend 30 minutes browsing iOS Human Interface Guidelines
2. **Choose Approach:** I recommend starting with Cupertino widgets
3. **Create Branch:** `git checkout -b feature/ios-design-system`
4. **Start Small:** Convert one screen (tour list) to iOS style
5. **Build Design System:** Extract common patterns into reusable components
6. **Iterate:** Get feedback and refine

Would you like me to:
1. Create a design system starter file for your project?
2. Convert a specific screen to iOS style as an example?
3. Create a component library with your app's most-used widgets?
