# rrawi — Landing Site Brief

> This file is a brief for the code agent building the rrawi landing website in a separate repo.
> Read it fully before writing any code.

---

## What is rrawi?

**rrawi** is an iOS & Android app for **AI-powered audio walking tours**, narrated by people who actually know the place.

The name is written lowercase with a signature green dot: **rrawi.**

**Core tagline:** "The one who narrates, walks with you."
**Sub-tagline:** "Audio tours, narrated by people who actually know the place."

Unlike generic travel guides, rrawi creates **personalised tour itineraries** — tailored to the user's interests, walking pace, and available days — then narrates each stop with richly written audio segments. The result feels like having a knowledgeable local walking alongside you.

---

## Key Features

| Feature | Description |
|---|---|
| **AI-generated itineraries** | Tours built around interests, pace, and trip length |
| **Audio narration** | Each stop has professionally written, sectioned audio narration |
| **Smart routing** | Stops ordered for coherence and minimal walking |
| **Multi-day support** | Tours spanning 1–7+ days with per-day breakdowns |
| **City coverage** | Multiple cities (Taipei, Rome, etc.) with more added regularly |
| **Saved tours** | Bookmark tours to revisit later |
| **Nearby discovery** | Browse tours close to your current location |
| **Private tours** | Users can generate their own private tours |

---

## Design System ("rawi" palette)

The brand uses a warm, editorial aesthetic — cream paper tones, dark ink, and an olive accent.

| Token | Hex | Usage |
|---|---|---|
| `rawiPaper` | `#F6F1E7` | Main background — warm off-white |
| `rawiPaper2` | `#EFE8D8` | Elevated surfaces |
| `rawiInk` | `#1B1915` | Primary text & icons — warm near-black |
| `rawiInk3` | `#6B6459` | Secondary text |
| `rawiInk4` | `#9A9285` | Muted / hint text |
| `rawiAccent` | `#3A4A3A` | Olive green — CTA buttons, highlights |
| `rawiHair` | `rgba(27,25,21,0.12)` | Dividers and subtle borders |

**Typography:** [Source Sans 3](https://fonts.google.com/specimen/Source+Sans+3) from Google Fonts — used for all body and UI text.

**Logo:** Wordmark `rrawi` in Source Sans 3 Bold + an oversized olive green dot (`rrawi.`). No separate icon file — the dot is part of the type.

---

## App Store Presence

| Platform | Status |
|---|---|
| iOS (App Store) | In submission |
| Android (Play Store) | Planned |

> Replace the placeholder download links below with real App Store / Play Store URLs once live.

---

## Pages to Build

### 1. Landing Page (`/`)

**Goal:** Introduce the app, communicate the value proposition, and drive App Store downloads.

**Sections (in order):**

1. **Hero**
   - Large `rrawi.` wordmark
   - Headline: *"The one who narrates, walks with you."*
   - Sub-copy: *"AI-powered audio walking tours, personalised for you."*
   - Download buttons: App Store (primary) + Google Play (secondary, greyed out / "coming soon")
   - App screenshot or phone mockup showing the tour card UI

2. **How it works** (3 steps)
   - Step 1 — *Choose a city* — Pick from our growing list of destinations
   - Step 2 — *Personalise your tour* — Tell us your interests, pace, and days
   - Step 3 — *Walk and listen* — Audio narration plays as you reach each stop

3. **Feature highlights** (3–4 cards)
   - Narrated by people who know the place
   - Personalised to your interests and pace
   - Smart multi-day itineraries
   - Works offline (audio cached on device)

4. **City showcase** (optional)
   - Visual grid or carousel of available cities (Taipei, Rome, …)

5. **Footer**
   - `rrawi.` wordmark
   - Links: Tour Intro · Terms & Conditions · Privacy Policy
   - *"Inspired by ❤️ over 🌏 & Edward Gibbon."*

---

### 2. Tour Intro Page (`/tours/[city]/[tour-slug]`)

**Goal:** One page per tour — introduces the tour, shows the itinerary, and drives app downloads. Primary SEO entry point.

**URL pattern:** `/tours/taipei/old-town-walking-tour`

**Data source:** Tour pages are either statically generated from a list of known tours, or server-rendered via the rrawi API:
```
GET /tours/{tour_id}
```
Response includes: `title_display`, `city`, `duration_days`, `total_pois`, `itinerary` (days → stops), cover image URL, narrator name/avatar.

**Sections:**

1. **Hero**
   - Cover image (full-width)
   - Tour title (`title_display`)
   - City · Duration · Number of stops
   - Narrator pill: "Narrated by [name]" with small avatar
   - CTA button: *"Start this tour — Download rrawi"*

2. **Itinerary preview**
   - Day-by-day accordion or list
   - Each day shows its stops (POI names only — no transcript text, to avoid content scraping)
   - Walking distance + estimated hours per day

3. **About this tour**
   - Short description of the tour's theme / angle
   - City context paragraph (good for SEO)

4. **Download CTA** (sticky or bottom section)
   - *"Experience this tour with audio narration"*
   - App Store + Google Play buttons

**SEO requirements:**
- `<title>`: `{Tour Title} — Audio Walking Tour in {City} | rrawi`
- `<meta description>`: `Explore {City} with {Tour Title}, a {N}-day audio walking tour narrated by locals. Download rrawi.`
- `<h1>`: Tour title
- Schema.org `TouristTrip` structured data

---

### 3. Terms & Conditions (`/terms`)

Placeholder page for now. Must include:

- Effective date
- Sections covering: use of the app, account creation, AI-generated content, user data, acceptable use, limitation of liability, changes to terms
- Contact email placeholder: `legal@rrawi.app` (replace when ready)

The app currently links to this page from the login screen ("By continuing you agree to our Terms of Service") and from the Account screen footer.

---

### 4. Privacy Policy (`/privacy`)

Placeholder page for now. Must include:

- Effective date
- Sections covering: data collected (name, email from Google/Apple sign-in, GPS location for tour navigation, usage analytics), how it is used, third-party services (Google Sign-In, Apple Sign-In), data retention, account deletion (with reference to the in-app delete account feature), contact for data requests
- Contact email placeholder: `privacy@rrawi.app` (replace when ready)

The app links to this page from the login screen and Account screen footer.

---

## Tech Recommendations

Use whatever stack fits a fast, SEO-friendly static site. Suggestions:

- **Next.js** (App Router) — good for static + dynamic tour pages with SSG/ISR
- **Astro** — excellent for mostly-static SEO pages
- Avoid heavy client-side-only frameworks for the tour intro pages (SEO matters there)

**Hosting:** Vercel or Cloudflare Pages both work well.

---

## Assets Needed

| Asset | Status |
|---|---|
| App Store screenshots | Produce from app |
| Phone mockup frames | Use public mockup templates |
| City cover images | Source from Unsplash or API response |
| Narrator avatar images | Served by rrawi API |
| App Store download link | Replace placeholder when live |
| Google Play download link | Replace placeholder when live |

---

## Tone of Voice

- **Warm, literary, unhurried** — not techy or startup-y
- Write as if a well-travelled friend is recommending the app
- Avoid: "revolutionary", "seamless", "cutting-edge", "unlock"
- Use: place names, sensory details, the word "walk"

---

## Placeholder URLs

Until the real legal pages are written, the app uses `https://www.google.com` as a placeholder for both T&C and Privacy links. Replace with the real site URLs once deployed:

| In-app reference | Target URL |
|---|---|
| Terms of Service (login screen) | `https://rrawi.app/terms` |
| Privacy Policy (login screen) | `https://rrawi.app/privacy` |
| Terms & Conditions (account footer) | `https://rrawi.app/terms` |
| Privacy Policy (account footer) | `https://rrawi.app/privacy` |

---

## What NOT to Build

- No user authentication on the website — download-only
- No tour generation UI — that lives in the app
- No admin panel
- Keep it simple: marketing site + SEO tour pages + legal pages
