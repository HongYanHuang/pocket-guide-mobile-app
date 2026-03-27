# Pocket Guide Design System

## Overview

Minimalist black & white design with dark green accent for brand identity.

**Philosophy:**
- Clean, uncluttered interfaces
- iOS-native feel
- Maximum readability
- Subtle, elegant interactions

---

## Color Palette

### Brand Color (Dark Green)
```dart
PGColors.brand        // #1B4332 - Primary brand color
PGColors.brandLight   // #2D6A4F - Hover/pressed states
PGColors.brandDark    // #081C15 - Dark accents
```

**Usage:**
- Primary buttons
- Active states
- Icons
- Links
- Important UI elements

### Grayscale
```dart
PGColors.black        // #000000 - Primary text
PGColors.gray900      // #1A1A1A - Almost black
PGColors.gray600      // #616161 - Secondary text
PGColors.gray500      // #9E9E9E - Tertiary text
PGColors.gray300      // #E0E0E0 - Borders
PGColors.gray100      // #F5F5F5 - Subtle backgrounds
PGColors.white        // #FFFFFF - Main background
```

### Semantic Colors (Use Sparingly)
```dart
PGColors.success      // Muted green for success states
PGColors.error        // Muted red for errors
PGColors.warning      // Muted orange for warnings
```

---

## Typography

Based on iOS San Francisco font scale.

### Display Text
```dart
PGTypography.largeTitle       // 34px, Bold - Screen titles
PGTypography.title1           // 28px, Bold - Section headers
PGTypography.title2           // 22px, Semibold - Subsections
PGTypography.title3           // 20px, Semibold - Card headers
```

### Body Text
```dart
PGTypography.headline         // 17px, Semibold - Emphasized text
PGTypography.body             // 17px, Regular - Main text
PGTypography.callout          // 16px, Regular - Secondary content
PGTypography.subheadline      // 15px, Regular - Metadata
```

### Small Text
```dart
PGTypography.footnote         // 13px - Small descriptions
PGTypography.caption1         // 12px - Labels, tags
PGTypography.caption2         // 11px - Tiny labels
```

**Best Practices:**
- Use black for primary text
- Use gray600 for secondary text
- Use gray500 for tertiary text/hints
- Maintain clear hierarchy

---

## Spacing

Based on 4px grid system.

```dart
PGSpacing.xs          // 4px
PGSpacing.s           // 8px
PGSpacing.m           // 12px
PGSpacing.l           // 16px - Most common
PGSpacing.xl          // 24px
PGSpacing.xxl         // 32px - Section spacing
```

### Common Patterns
```dart
PGSpacing.paddingL              // Padding for cards/containers
PGSpacing.screen                // Safe area screen padding
PGSpacing.sectionSpacing        // Between major sections
PGSpacing.itemSpacing           // Between list items
```

---

## Components

### Buttons

#### Primary Button (Dark Green)
```dart
PGButton(
  text: 'Start Tour',
  onPressed: () {},
  icon: CupertinoIcons.play_fill, // Optional
  isFullWidth: true,               // Optional
  size: PGButtonSize.large,        // small, medium, large
)
```

#### Secondary Button (Outlined)
```dart
PGButtonSecondary(
  text: 'Cancel',
  onPressed: () {},
)
```

#### Text Button (Minimal)
```dart
PGButtonText(
  text: 'Learn More',
  onPressed: () {},
  icon: CupertinoIcons.arrow_right, // Optional
)
```

**When to Use:**
- Primary: Main actions (Start, Save, Confirm)
- Secondary: Alternative actions (Cancel, Back)
- Text: Tertiary actions (Learn More, Skip)

---

### Cards

#### Tour Card
```dart
PGTourCard(
  title: 'Rome Walking Tour',
  subtitle: 'Historical landmarks',
  duration: '3 days',
  poiCount: 15,
  isPrivate: false,
  onTap: () {},
)
```

#### POI Card
```dart
PGPOICard(
  number: 1,
  name: 'Colosseum',
  description: 'Ancient amphitheater',
  completed: false,
  onTap: () {},
)
```

#### Content Card
```dart
PGContentCard(
  title: 'About This Tour',
  content: Text('Tour description here...'),
)
```

#### Generic Card
```dart
PGCard(
  onTap: () {},          // Optional
  elevated: true,         // Adds subtle shadow
  child: YourContent(),
)
```

---

### Navigation

#### Navigation Bar
```dart
PGNavigationBar(
  title: 'Tours',
  leading: PGBackButton(),           // Optional
  trailing: PGNavButton(             // Optional
    icon: CupertinoIcons.settings,
    onPressed: () {},
  ),
  showBorder: true,
)
```

#### Tab Bar
```dart
PGTabBar(
  currentIndex: 0,
  onTap: (index) {},
  items: [
    PGTabItem(
      icon: CupertinoIcons.map,
      activeIcon: CupertinoIcons.map_fill,
      label: 'Tours',
    ),
    PGTabItem(
      icon: CupertinoIcons.person,
      activeIcon: CupertinoIcons.person_fill,
      label: 'Profile',
    ),
  ],
)
```

---

## Layout Patterns

### Screen Structure
```dart
CupertinoPageScaffold(
  navigationBar: PGNavigationBar(title: 'Screen Title'),
  child: SafeArea(
    child: Padding(
      padding: PGSpacing.screen,
      child: Column(
        children: [
          // Your content
        ],
      ),
    ),
  ),
)
```

### List with Cards
```dart
ListView.separated(
  padding: PGSpacing.screen,
  itemCount: items.length,
  separatorBuilder: (_, __) => SizedBox(height: PGSpacing.m),
  itemBuilder: (context, index) => PGTourCard(...),
)
```

### Section Headers
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Section Title', style: PGTypography.title2),
    SizedBox(height: PGSpacing.l),
    // Section content
  ],
)
```

---

## Examples

### Simple Screen
```dart
import 'package:flutter/cupertino.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_navigation.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_button.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_card.dart';

class ToursScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PGColors.background,
      navigationBar: PGNavigationBar(
        title: 'My Tours',
        trailing: PGNavButton(
          icon: CupertinoIcons.add,
          onPressed: () {},
        ),
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: PGSpacing.screen,
          itemCount: 5,
          separatorBuilder: (_, __) => SizedBox(height: PGSpacing.m),
          itemBuilder: (context, index) {
            return PGTourCard(
              title: 'Rome Walking Tour',
              subtitle: 'Historical landmarks and culture',
              duration: '3 days',
              poiCount: 15,
              onTap: () {},
            );
          },
        ),
      ),
    );
  }
}
```

### Screen with Actions
```dart
class TourDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PGColors.background,
      navigationBar: PGNavigationBar(
        title: 'Tour Details',
        leading: PGBackButton(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: PGSpacing.screen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Rome Walking Tour',
                      style: PGTypography.largeTitle,
                    ),
                    SizedBox(height: PGSpacing.s),
                    Text(
                      'Explore ancient Rome',
                      style: PGTypography.body.copyWith(
                        color: PGColors.textSecondary,
                      ),
                    ),

                    SizedBox(height: PGSpacing.xxl),

                    // Content
                    PGContentCard(
                      title: 'About',
                      content: Text(
                        'Tour description here...',
                        style: PGTypography.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action
            Container(
              padding: PGSpacing.paddingL,
              decoration: BoxDecoration(
                color: PGColors.white,
                border: Border(
                  top: BorderSide(
                    color: PGColors.divider,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: PGButton(
                  text: 'Start Tour',
                  icon: CupertinoIcons.play_fill,
                  isFullWidth: true,
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Icons

Use **CupertinoIcons** for iOS-native icons.

**Common Icons:**
```dart
CupertinoIcons.map              // Tours
CupertinoIcons.map_fill         // Active tours
CupertinoIcons.placemark        // POI
CupertinoIcons.location         // Location
CupertinoIcons.play_fill        // Start/Play
CupertinoIcons.pause_fill       // Pause
CupertinoIcons.settings         // Settings
CupertinoIcons.person           // Profile
CupertinoIcons.time             // Duration
CupertinoIcons.checkmark        // Completed
CupertinoIcons.lock_fill        // Private
```

---

## Best Practices

### Do's ✅
- Use dark green sparingly for impact
- Maintain generous white space
- Use subtle shadows (never heavy)
- Keep borders thin (1px)
- Use iOS-native components
- Follow spacing scale consistently
- Test on actual iPhone

### Don'ts ❌
- Don't overuse green - it should stand out
- Don't use bright, saturated colors
- Don't use heavy shadows or gradients
- Don't mix Material and Cupertino widgets
- Don't ignore safe areas
- Don't use custom fonts (system font is best)

---

## Migration Path

### Phase 1: Core Components (Week 1)
1. Replace all AppBars with PGNavigationBar
2. Replace all ElevatedButtons with PGButton
3. Use PGCard for all card-like containers

### Phase 2: Screens (Week 2-3)
1. Convert tour list screen
2. Convert tour detail screen
3. Convert map screen
4. Convert profile screen

### Phase 3: Polish (Week 4)
1. Ensure consistent spacing
2. Refine animations
3. Test on device
4. Fix edge cases

---

## Questions?

Check examples in:
- `lib/design_system/components/` - Component implementations
- UI_DESIGN_OPTIONS.md - Alternative approaches
- iOS Human Interface Guidelines - https://developer.apple.com/design/human-interface-guidelines/
