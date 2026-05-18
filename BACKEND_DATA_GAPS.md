# Backend Data Gaps — Mobile Frontend Requirements

**Requested by:** Mobile Frontend Team  
**Date:** 2026-05-18  
**Status:** Open — awaiting backend implementation  

This document catalogues every place in the mobile app where data is either hardcoded on the frontend or derived by the client from a larger payload, but should instead come from the backend. Grouped by priority.

---

## P0 — Already requested, still not delivered

### 1. Tour cover image URL missing from `TourSummary`

**Current behaviour:** Every tour card (large, compact, and "continue walking" banner) shows a deterministic gradient derived by hashing `tour_id` on the client. This is a placeholder — there are no real images.

**Where in code:**
- `lib/widgets/home/tour_card_large.dart` — `_gradient()` method, lines 24–26
- `lib/widgets/home/tour_card_compact.dart` — `_gradient()` method, lines 23–25
- `lib/widgets/home/continue_walking_banner.dart` — `_gradient()` method, lines 27–29

**What backend needs to add:**

Add `cover_image_url` (nullable string) to the `TourSummary` model returned by `GET /tours/`:

```json
{
  "tour_id": "rome-tour-abc123",
  "title_display": "Ancient Rome · 2 Days",
  "cover_image_url": "https://cdn.example.com/tours/rome-tour-abc123/cover.jpg",
  ...
}
```

**OpenAPI spec change:**
```yaml
TourSummary:
  properties:
    cover_image_url:
      type: string
      nullable: true
      description: "Absolute URL to the tour cover image. Null if no image has been uploaded."
```

**Frontend behaviour after delivery:**
- If `cover_image_url` is a non-empty string → load image via `Image.network`, show gradient while loading
- If `cover_image_url` is null, empty, or the image request fails (404/network error) → fall back to gradient

**Note:** `TourDetail` (the full tour response) already has `images.cover.url` but it is a relative URL and only available after opening a tour. `TourSummary` needs its own flat `cover_image_url` field for the home feed list.

---

### 2. Tour categories derived on frontend instead of served by API

**Current behaviour:** The category rail ("All / Julius Caesar / Ancient Rome") is built on the client by scanning the `category` field of every tour returned by `GET /tours/` and deduplicating them. This means:
- Categories appear only after all tours are loaded
- The client cannot know the canonical category list or display counts before tours arrive
- New/empty categories cannot be shown proactively

**Where in code:**
- `lib/screens/home_screen.dart` — `_categories` getter, lines 88–94

```dart
List<String> get _categories {
  final cats = <String>{};
  for (final t in _tours) {
    if (t.category != null) cats.add(t.category!);
  }
  return ['All', ...cats.toList()..sort()];
}
```

**What backend needs to add:**

New endpoint:

```
GET /tours/categories
```

Optional query param: `?city=rome` to scope to a city.

Response:
```json
{
  "categories": [
    { "slug": "all",            "label": "All",            "count": 12 },
    { "slug": "julius-caesar",  "label": "Julius Caesar",  "count": 4  },
    { "slug": "ancient-rome",   "label": "Ancient Rome",   "count": 3  },
    { "slug": "food",           "label": "Food & Wine",    "count": 2  }
  ]
}
```

Fields:
| Field | Type | Purpose |
|---|---|---|
| `slug` | string | Machine identifier used for filtering (`?category=julius-caesar`) |
| `label` | string | Human-readable display name for the pill |
| `count` | int | Number of tours in this category; client may show/hide zero-count entries |

**Also needed:** Support `?category=julius-caesar` filter on `GET /tours/` so the client can request a filtered list rather than fetching everything and filtering in memory.

**Frontend behaviour after delivery:**
- Call `GET /tours/categories` on home screen load (parallel with tours call)
- Render the rail immediately from the category list, before tours finish loading
- Pass the selected category slug as a query param to `GET /tours/`

---

## P1 — Not previously documented, found in audit

### 3. City emoji icons hardcoded on frontend

**Current behaviour:** The city picker sheet maps city names to emoji icons in a static Dart map. Only 14 cities are covered; any city not in the map falls back to `📍`.

**Where in code:**
- `lib/widgets/home/city_picker_sheet.dart` — `_kCityIcons` constant, lines 10–25

```dart
const _kCityIcons = <String, String>{
  'Rome': '🏛️',
  'Kyoto': '⛩️',
  'Lisbon': '🚋',
  // ... 14 cities total
};
```

**What backend needs to add:**

Add `emoji` (nullable string) to the `City` model returned by `GET /cities/`:

```json
{
  "name": "Rome",
  "slug": "rome",
  "country": "Italy",
  "poi_count": 42,
  "emoji": "🏛️"
}
```

**OpenAPI spec change:**
```yaml
City:
  properties:
    emoji:
      type: string
      nullable: true
      description: "Single emoji representing the city. Null falls back to the generic 📍 pin."
```

**Frontend behaviour after delivery:**
- Use `city.emoji ?? '📍'` instead of the hardcoded lookup map
- The hardcoded `_kCityIcons` map in `city_picker_sheet.dart` can be removed entirely

---

### 4. Interest options for tour generation hardcoded on frontend

**Current behaviour:** The "Create Tour" screen shows 10 interest chips that are a static list in Dart. Adding, renaming, or removing an interest category requires a mobile app release.

**Where in code:**
- `lib/screens/create_tour_screen.dart` — `_selectedInterests` map, lines 33–44

```dart
final Map<String, bool> _selectedInterests = {
  'History': false,
  'Architecture': false,
  'Food & Dining': false,
  'Art & Museums': false,
  'Nature & Parks': false,
  'Shopping': false,
  'Nightlife': false,
  'Local Culture': false,
  'Religious Sites': false,
  'Photography': false,
};
```

**What backend needs to add:**

New endpoint (or include in an existing config/metadata endpoint):

```
GET /config/interests
```

Optional query param: `?city=rome` if interests are city-specific in the future.

Response:
```json
{
  "interests": [
    { "slug": "history",        "label": "History"        },
    { "slug": "architecture",   "label": "Architecture"   },
    { "slug": "food-dining",    "label": "Food & Dining"  },
    { "slug": "art-museums",    "label": "Art & Museums"  },
    { "slug": "nature-parks",   "label": "Nature & Parks" },
    { "slug": "shopping",       "label": "Shopping"       },
    { "slug": "nightlife",      "label": "Nightlife"      },
    { "slug": "local-culture",  "label": "Local Culture"  },
    { "slug": "religious-sites","label": "Religious Sites"},
    { "slug": "photography",    "label": "Photography"    }
  ]
}
```

**Frontend behaviour after delivery:**
- Fetch interests on `CreateTourScreen` init, alongside cities
- Send `slug` values (not labels) in the tour generation request

---

### 5. Pace and walking intensity enum values hardcoded on frontend

**Current behaviour:** The "Preferences" section in CreateTourScreen uses hardcoded string literals for `pace` and `walking`. If the backend renames or adds an option, the mobile silently sends a value the backend no longer recognises.

**Where in code:**
- `lib/screens/create_tour_screen.dart` — `_buildPreferenceRow` calls, lines 394–408

```dart
_buildPreferenceRow('Pace', _pace, {
  'relaxed': 'Relaxed',
  'normal': 'Normal',
  'fast': 'Fast',
}, ...),
_buildPreferenceRow('Walking', _walking, {
  'light': 'Light',
  'moderate': 'Moderate',
  'intensive': 'Intensive',
}, ...),
```

**What backend needs to add:**

Include pace and walking options in the config endpoint from item 4 above (or a separate `GET /config/tour-options`):

```json
{
  "pace_options": [
    { "value": "relaxed",  "label": "Relaxed"  },
    { "value": "normal",   "label": "Normal"   },
    { "value": "fast",     "label": "Fast"     }
  ],
  "walking_options": [
    { "value": "light",     "label": "Light"     },
    { "value": "moderate",  "label": "Moderate"  },
    { "value": "intensive", "label": "Intensive" }
  ]
}
```

Alternatively, these can be OpenAPI `enum` values on the tour generation request schema — the generated client enforces them at compile time.

---

### 6. All-tours fetch + client-side city filter (no server-side `?city=` param)

**Current behaviour:** `ApiService.getToursByCity(city)` calls `GET /tours/` (no params), receives **all** tours, then filters by city in Dart. This scales poorly as the tour library grows.

**Where in code:**
- `lib/services/api_service.dart` — `getToursByCity()`, lines 94–117

```dart
final response = await _api.listToursToursGet();  // no city param
// then filters in Dart...
```

**What backend needs to add:**

Support an optional `city` query parameter on the existing `GET /tours/` endpoint:

```
GET /tours/?city=rome
```

**OpenAPI spec change:**
```yaml
/tours/:
  get:
    parameters:
      - name: city
        in: query
        required: false
        schema:
          type: string
        description: "Filter by city slug (e.g. 'rome'). Omit to return all tours."
      - name: category
        in: query
        required: false
        schema:
          type: string
        description: "Filter by category slug (e.g. 'ancient-rome')."
```

**Frontend behaviour after delivery:**
- Pass `city` and `category` as query params; remove in-memory filtering from `_filteredTours` getter

---

### 7. Supported languages hardcoded on frontend

**Current behaviour:** `CreateTourScreen._setDefaultLanguage()` contains a hardcoded allowlist. When the backend adds a new supported language, the mobile app never detects it.

**Where in code:**
- `lib/screens/create_tour_screen.dart` — `_setDefaultLanguage()`, lines 101–114

```dart
if (['en', 'fr', 'es', 'ja', 'ko'].contains(languageCode)) {
  _language = languageCode;
}
```

**What backend needs to add:**

Include in the config endpoint from item 4:

```json
{
  "supported_languages": [
    { "code": "en",    "label": "English"             },
    { "code": "fr",    "label": "Français"            },
    { "code": "es",    "label": "Español"             },
    { "code": "ja",    "label": "日本語"              },
    { "code": "ko",    "label": "한국어"              },
    { "code": "zh-tw", "label": "繁體中文"            },
    { "code": "zh-cn", "label": "简体中文"            },
    { "code": "pt-br", "label": "Português (Brasil)"  }
  ]
}
```

---

## Summary Table

| # | What | Where (mobile) | Backend change needed | Priority |
|---|---|---|---|---|
| 1 | Tour cover image URL | `tour_card_*.dart`, `continue_walking_banner.dart` | Add `cover_image_url` to `TourSummary` | P0 |
| 2 | Category list for filter rail | `home_screen.dart:88` | New `GET /tours/categories` endpoint | P0 |
| 3 | City emoji icons | `city_picker_sheet.dart:10` | Add `emoji` to `City` model | P1 |
| 4 | Tour generation interests | `create_tour_screen.dart:33` | New `GET /config/interests` endpoint | P1 |
| 5 | Pace & walking enum values | `create_tour_screen.dart:394` | Add to config endpoint or OpenAPI enum | P1 |
| 6 | City/category filter on tour list | `api_service.dart:94` | Add `?city=` and `?category=` to `GET /tours/` | P1 |
| 7 | Supported language codes | `create_tour_screen.dart:101` | Add to config endpoint | P2 |

---

## Recommended config endpoint

Items 4, 5, and 7 can all be served by a single lightweight endpoint:

```
GET /config
```

Response:
```json
{
  "interests": [ { "slug": "...", "label": "..." } ],
  "pace_options": [ { "value": "...", "label": "..." } ],
  "walking_options": [ { "value": "...", "label": "..." } ],
  "supported_languages": [ { "code": "...", "label": "..." } ]
}
```

This endpoint is read-only, public (no auth), and can be cached aggressively (e.g. `Cache-Control: max-age=3600`).

---

## Frontend integration notes

- All new fields should be **nullable / optional** — the mobile app degrades gracefully when a field is missing, it never crashes
- After backend delivers each item, the mobile team will:
  1. Update `api-spec/openapi.json`
  2. Run `npm run update-api` to regenerate the Dart client
  3. Replace the hardcoded value with the API-sourced one
  4. Remove the now-dead hardcoded constant
- Please notify the mobile team via the shared channel when each item ships so we can update accordingly
