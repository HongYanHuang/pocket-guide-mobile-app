# Design System Preview

## Color Palette

### Brand Color (Use Sparingly!)
```
🟩 Dark Green (#1B4332) - Primary brand color
   Use for: Buttons, icons, active states, links
```

### Grayscale Palette
```
⬛ Black (#000000) - Primary text
🔲 Gray 900 (#1A1A1A) - Almost black
🔲 Gray 600 (#616161) - Secondary text
🔲 Gray 500 (#9E9E9E) - Tertiary text
🔲 Gray 300 (#E0E0E0) - Borders
🔲 Gray 100 (#F5F5F5) - Subtle backgrounds
⬜ White (#FFFFFF) - Main background
```

---

## Component Examples

### Primary Button (Dark Green)
```
┌─────────────────────────┐
│   🟩 Start Tour         │  ← Dark green background
│       ⚪ White text       │  ← Always white text
└─────────────────────────┘
```

### Secondary Button (Outlined)
```
┌─────────────────────────┐
│ ┃  Cancel              ┃│  ← Green border, no fill
│ ┃  🟩 Green text        ┃│  ← Green text
└─────────────────────────┘
```

### Tour Card
```
┌─────────────────────────────────────┐
│  ┌───┐                              │
│  │🗺️ │  Rome Walking Tour          │  ← Icon in gray box
│  └───┘  Historical landmarks        │  ← Black text
│         ⏰ 3 days • 📍 15 POIs      │  ← Gray metadata
│                                  ›  │  ← Gray chevron
└─────────────────────────────────────┘
```

### POI Card
```
┌─────────────────────────────────────┐
│  ┌──┐                               │
│  │ 1│  Colosseum                    │  ← Number badge
│  └──┘  Ancient amphitheater         │  ← Description
│                                  ›  │
└─────────────────────────────────────┘
```

### Navigation Bar
```
┌─────────────────────────────────────┐
│  ‹  Tours                        ⚙️ │  ← Clean, minimal
└─────────────────────────────────────┘
         Thin gray divider line
```

---

## Screen Examples

### Tour List Screen
```
┌─────────────────────────────────────┐
│  ‹  My Tours                     +  │  ← Nav bar
├─────────────────────────────────────┤
│                                      │
│  ┌─────────────────────────────┐   │
│  │ 🗺️  Rome Walking Tour       │   │  ← Tour card
│  │     Historical landmarks    │   │
│  │     ⏰ 3 days • 📍 15 POIs   │   │
│  └─────────────────────────────┘   │
│                                      │
│  ┌─────────────────────────────┐   │
│  │ 🔒  My Custom Tour          │   │  ← Private tour
│  │     Personal itinerary      │   │
│  │     ⏰ 2 days • 📍 8 POIs    │   │
│  └─────────────────────────────┘   │
│                                      │
│  ┌─────────────────────────────┐   │
│  │ 🗺️  Paris Adventure         │   │
│  │     Art and culture         │   │
│  │     ⏰ 4 days • 📍 20 POIs   │   │
│  └─────────────────────────────┘   │
│                                      │
└─────────────────────────────────────┘
```

### Tour Detail Screen
```
┌─────────────────────────────────────┐
│  ‹  Tour Details                    │
├─────────────────────────────────────┤
│                                      │
│  Rome Walking Tour                  │  ← Large title
│  Explore ancient Rome               │  ← Subtitle
│                                      │
│  ┌─────────────────────────────┐   │
│  │ About                       │   │  ← Content card
│  │                             │   │
│  │ Discover the ancient heart  │   │
│  │ of Rome on this 3-day tour. │   │
│  │ Visit iconic landmarks...   │   │
│  └─────────────────────────────┘   │
│                                      │
│  ┌─────────────────────────────┐   │
│  │ Points of Interest          │   │
│  │                             │   │
│  │  1  Colosseum            ›  │   │
│  │  2  Roman Forum          ›  │   │
│  │  3  Pantheon             ›  │   │
│  └─────────────────────────────┘   │
│                                      │
├─────────────────────────────────────┤
│                                      │
│  ┌─────────────────────────────┐   │
│  │   🟩 Start Tour              │   │  ← Green button
│  └─────────────────────────────┘   │
│                                      │
└─────────────────────────────────────┘
```

---

## Typography Scale

```
Large Title (34px, Bold)
This is the main screen title

Title 1 (28px, Bold)
Section headers

Title 2 (22px, Semibold)
Subsection headers

Headline (17px, Semibold)
Emphasized text and card titles

Body (17px, Regular)
Main content text

Callout (16px, Regular)
Secondary content

Subheadline (15px, Regular)
Metadata and descriptions

Footnote (13px, Regular)
Small descriptions

Caption (12px, Regular)
Labels and tiny text
```

---

## Spacing Scale

```
XS  (4px)  ▮
S   (8px)  ▮▮
M   (12px) ▮▮▮
L   (16px) ▮▮▮▮           ← Most common
XL  (24px) ▮▮▮▮▮▮
XXL (32px) ▮▮▮▮▮▮▮▮       ← Section spacing
```

---

## Usage Examples

### Using Colors
```dart
// Brand color - use sparingly!
Container(color: PGColors.brand)          // Dark green
Text('Link', style: TextStyle(color: PGColors.brand))

// Text colors
Text('Primary', style: TextStyle(color: PGColors.textPrimary))    // Black
Text('Secondary', style: TextStyle(color: PGColors.textSecondary)) // Gray
```

### Using Components
```dart
// Primary button (green)
PGButton(
  text: 'Start Tour',
  icon: CupertinoIcons.play_fill,
  onPressed: () {},
)

// Tour card
PGTourCard(
  title: 'Rome Walking Tour',
  subtitle: 'Historical landmarks',
  duration: '3 days',
  poiCount: 15,
  onTap: () {},
)
```

---

## Visual Hierarchy

### Text Hierarchy
```
1. Black text = Primary (most important)
2. Gray text = Secondary (supporting info)
3. Light gray = Tertiary (metadata, hints)
```

### Color Hierarchy
```
1. Green = Action (buttons, active states)
2. Black/Gray = Content (text, icons)
3. White = Background (clean, spacious)
```

### Size Hierarchy
```
1. Large = Important (titles, main actions)
2. Medium = Normal (body text, secondary actions)
3. Small = Supporting (metadata, labels)
```

---

## Design Principles

1. **Minimalism First**
   - Remove unnecessary elements
   - Use white space generously
   - Keep layouts clean

2. **Green is Precious**
   - Only for primary actions
   - Only for active states
   - Makes buttons stand out

3. **Black & White Base**
   - Most of UI is grayscale
   - Easy to read
   - Professional look

4. **iOS Native**
   - Cupertino widgets
   - iOS animations
   - Native feel

5. **Subtle Elegance**
   - Thin borders (1px)
   - Soft shadows
   - Gentle corners (12px)

---

## To See It in Action

Run the preview screen:
```dart
Navigator.push(
  context,
  CupertinoPageRoute(
    builder: (context) => DesignSystemPreview(),
  ),
);
```

Or check the guide:
- **DESIGN_SYSTEM_GUIDE.md** - Complete usage guide
- **UI_DESIGN_OPTIONS.md** - Alternative approaches
