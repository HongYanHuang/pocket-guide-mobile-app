# Backend Data Gaps — Mobile Frontend Requirements

**Requested by:** Mobile Frontend Team  
**Date:** 2026-05-18  
**Status:** Open — awaiting backend implementation  

---

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

**Frontend behaviour after delivery:**
- Call `GET /tours/categories` on home screen load (parallel with tours call)
- Render the rail immediately from the category list, before tours finish loading
- Pass the selected category slug as a query param to `GET /tours/`

---

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

### 6. All-tours fetch + client-side city/category filter (no server-side query params)

**Current behaviour:** `ApiService.getToursByCity(city)` calls `GET /tours/` with no parameters, receives all tours, then filters by city in Dart. The home screen similarly filters by category in memory. This scales poorly as the tour library grows.

**Where in code:**
- `lib/services/api_service.dart` — `getToursByCity()`, lines 94–117

```dart
final response = await _api.listToursToursGet();  // no city or category param
// then filters in Dart...
```

**What backend needs to add:**

Support optional `city` and `category` query parameters on the existing `GET /tours/` endpoint:

```
GET /tours/?city=rome
GET /tours/?city=rome&category=ancient-rome
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
- Pass `city` and `category` as query params instead of fetching everything and filtering in Dart
- Remove in-memory filtering from `ApiService.getToursByCity()` and the `_filteredTours` getter in `home_screen.dart`

---

## Summary

| # | What | Where (mobile) | Backend change needed |
|---|---|---|---|
| 1 | Tour cover image URL | `tour_card_*.dart`, `continue_walking_banner.dart` | Add `cover_image_url` to `TourSummary` |
| 2 | Category list for filter rail | `home_screen.dart:88` | New `GET /tours/categories` endpoint |
| 3 | City emoji icons | `city_picker_sheet.dart:10` | Add `emoji` to `City` model |
| 6 | City/category filter on tour list | `api_service.dart:94` | Add `?city=` and `?category=` to `GET /tours/` |

## Frontend integration notes

- All new fields should be **nullable / optional** — the mobile app degrades gracefully when a field is missing, it never crashes
- After backend delivers each item, the mobile team will:
  1. Update `api-spec/openapi.json`
  2. Run `npm run update-api` to regenerate the Dart client
  3. Replace the hardcoded value with the API-sourced one
  4. Remove the now-dead hardcoded constant
- Please notify the mobile team when each item ships so we can update accordingly
