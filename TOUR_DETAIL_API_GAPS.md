# Tour Detail Page — Backend API Requirements

Handoff to backend team for the **tour detail screen** redesign.

The frontend is building a new tour detail screen (pre-start preview).
The items below are data gaps discovered between the current API and the design requirements.

---

## 1. Add narrator fields to `TourMetadata`

**Why:** `narrator_name` and `narrator_avatar_url` exist on `TourSummary` (list endpoint) but are absent from `TourMetadata` (which is the schema embedded in `TourDetail`). The detail screen only receives `TourDetail` — it should not have to separately cache the list-level summary to render the narrator footer.

**Change:** Add the following nullable fields to the `TourMetadata` schema:

```json
"narrator_name": {
  "type": "string",
  "nullable": true,
  "description": "Display name of the tour narrator / voice actor."
},
"narrator_avatar_url": {
  "type": "string",
  "nullable": true,
  "description": "Relative URL to narrator avatar image. Prefix with base URL."
}
```

---

## 2. Add summary fields to `TourMetadata`

**Why:** `blurb`, `rating`, `review_count`, and `cover_image_url` are on `TourSummary` but absent from `TourMetadata`. The detail screen needs all four without making a second list call.

Currently `cover_image_url` is only accessible via the untyped `TourDetail.images` map (raw JSON). This is fragile — it should be a typed field.

**Change:** Add to `TourMetadata`:

```json
"blurb": {
  "type": "string",
  "nullable": true,
  "description": "1–3 sentence user-facing description of the tour. Shown in the About section."
},
"cover_image_url": {
  "type": "string",
  "nullable": true,
  "description": "Relative URL to the tour cover image. Prefix with base URL."
},
"rating": {
  "type": "number",
  "nullable": true,
  "description": "Aggregate star rating (0.0–5.0)."
},
"review_count": {
  "type": "integer",
  "nullable": true,
  "description": "Total number of submitted reviews."
}
```

---

## 3. Add per-stop fields to `TourPOI`

**Why:** The detail screen renders each stop as a card with three display-only pieces of data that are currently missing from `TourPOI`:

| Field | Purpose in UI |
|---|---|
| `cover_image_url` | 72×72 px square photo on the stop card (left side). Gradient fallback if null. |
| `blurb` | 1–2 sentence user-facing teaser shown in the collapsed stop card. Different from `reason` (which is an internal note). |
| `section_count` | Shown as "N chapters" in the stop card meta row. Without this, the app must load the full transcript per-stop just to show a count — expensive on page open. |

**Change:** Add to `TourPOI`:

```json
"cover_image_url": {
  "type": "string",
  "nullable": true,
  "description": "Relative URL to a representative photo for this stop. Source from POI images. Prefix with base URL."
},
"blurb": {
  "type": "string",
  "nullable": true,
  "description": "1–2 sentence user-facing teaser about this stop. Distinct from `reason` (internal). Shown collapsed on the stop card."
},
"section_count": {
  "type": "integer",
  "nullable": true,
  "description": "Number of audio chapters (transcript sections) for this stop. Shown as 'N chapters' without requiring a transcript fetch."
}
```

**Note on `cover_image_url` sourcing:** the backend can pull this from the POI's images record if available, or leave null (frontend will render a deterministic warm gradient fallback keyed by stop index).

---

## 4. New endpoint: `GET /tours/{tour_id}/reviews`

**Why:** The design shows individual review cards (reviewer name, star rating, review text, date). Currently only aggregate `rating` + `review_count` exist. There is no way to display review content.

**New endpoint:**

```
GET /tours/{tour_id}/reviews
```

**Query parameters:**

| Param | Type | Description |
|---|---|---|
| `limit` | integer | Max reviews to return. Default `10`. |
| `offset` | integer | Pagination offset. Default `0`. |

**Response schema — `TourReviewsResponse`:**

```json
{
  "tour_id": "string",
  "total_count": "integer",
  "reviews": [
    {
      "review_id": "string",
      "reviewer_name": "string",
      "reviewer_avatar_url": "string | null",
      "rating": "integer (1–5)",
      "text": "string",
      "created_at": "string (ISO 8601)"
    }
  ]
}
```

**Notes:**
- Reviews are about the **tour experience** (pacing, walk, content) — not about the narrator.
- `reviewer_avatar_url` is nullable; frontend will render an initial-based or gradient fallback.
- Authentication: read endpoint is public. Submit endpoint (if built later) requires auth.
- If no review system exists yet, returning an empty `reviews: []` list is sufficient for the initial implementation.

---

## Summary table

| # | Schema / Endpoint | Field(s) to add | Priority |
|---|---|---|---|
| 1 | `TourMetadata` | `narrator_name`, `narrator_avatar_url` | High |
| 2 | `TourMetadata` | `blurb`, `cover_image_url`, `rating`, `review_count` | High |
| 3 | `TourPOI` | `cover_image_url`, `blurb`, `section_count` | High |
| 4 | New endpoint | `GET /tours/{tour_id}/reviews` | Medium |

Items 1–3 are schema additions to existing endpoints (no new routes needed).
Item 4 is a new read-only route.

After backend ships these, the frontend will run `npm run update-api` to regenerate the typed Dart client.
