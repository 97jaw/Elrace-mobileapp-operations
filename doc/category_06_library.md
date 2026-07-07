# Library — Widget Development Plan

## Overview

This category surfaces reference content the user accesses but doesn't actively manage from this screen — personal documents, project media, and prayer times. All three are full-width stacked rows at the bottom of screen 2.

**Widgets in this category**
1. My Documents (full width, row 1)
2. Media (full width, row 2)
3. Prayer Times (full width, row 3)

**Frontend reference:** `screen2_v7` — Library section. Each widget uses a distinct theme: light gray for Documents, near-black for Media, gold/olive for Prayer.

---

## Widget model configuration (emp_mobile_conf)

| Field | My Documents | Media | Prayer |
|---|---|---|---|
| code | `my_documents` | `media` | `prayer_times` |
| name | My Documents | Media | Prayer Times |
| category | `library` | `library` | `library` |
| sequence | 1 | 2 | 3 |
| size | `full` | `full` | `full` |
| icon | documents-stack | camera | mosque-crescent |
| theme_color | gray (#D8DEE8) | charcoal (#1A1F2E) | gold (#6B5328) |
| is_active | True | True | True |
| role_ids | All employees | All employees (with project scope) | All employees |

---

## Widget 1: My Documents

### Frontend (must match v7)
- Full-width card with min-height 140px
- Gradient: `#F0F3F8 → #E5E9F0 → #D8DEE8 → #CFD5DE` (light gray) with white highlight top-left
- Faded stacked-papers pattern top-right (navy strokes at opacity ~0.15)
- Gold gradient icon container top-right with documents-stack icon
- Top label "Personal" in gold, title "My Documents"
- Layout split:
  - **Left:** big number "12" (total docs) + trend in amber "⚠ 4 expire soon"
  - **Right:** row of 4 small document thumbnails (Emirates ID, License, Insurance, Passport) — each in its original theme color from the v7 design

### Backend business logic

#### Data source
- Personal documents are stored on `hr.employee` as fields (e.g. `identification_id` for Emirates ID, passport copy, license fields) AND/OR as `ir.attachment` records linked to the employee with a document-type tag.
- Use whichever pattern is already in production. Likely a combination — Emirates ID has a dedicated field, supporting documents live as attachments.

#### Document types to surface
A fixed set of "personal identity documents" that the widget always shows (4 thumbnails). The set is configurable via `ir.config_parameter` so HR can adjust which 4 appear:
1. Emirates ID
2. Trade License
3. Insurance
4. Passport

If the user is missing one of these, its thumbnail is shown as "Not uploaded" with a dotted border. Frontend handles that visual variant.

#### Counts and logic
- **Total documents:** count of all personal documents for the employee (including the 4 fixed types + any other uploaded). Includes Emirates ID, passport, licenses, certifications, insurance cards, etc.
- **Expiring soon:** documents where `expiry_date` is within next 30 days AND not already expired.
  - Trend message variants:
    - 0 expiring → "All up to date" (in green)
    - 1 expiring → "⚠ 1 document expires soon" (in amber)
    - 2+ expiring → "⚠ N documents expire soon" (in amber)
    - Any already expired → "⚠ N expired" (in red, takes priority over expiring)
- **Thumbnails:** 4 fixed types with each one's:
  - `document_type` (eid / lic / ins / psp — drives the thumbnail color in the frontend)
  - `is_uploaded` (true/false)
  - `expiry_date` (if applicable)
  - `document_id` (so frontend can deep-link on tap)

### Edge cases
- Employee with no documents uploaded at all: total = 0, all 4 thumbnails show as "Not uploaded" empty state.
- Document type with no expiry date concept (e.g., a permanent ID): never shown in "expiring soon" count.
- Multi-page documents (insurance with 5 attachments): counted as one document.
- Recently expired (1 day ago): counted as "expired", takes priority in the trend message.

### API contract (data only)
- Input: employee from middleware.
- Output payload: `total_count`, `expiring_soon_count`, `expired_count`, `trend_message` (pre-formatted string), `trend_color` (green/amber/red), `featured_documents[]` (exactly 4 entries — Emirates ID, License, Insurance, Passport — each with `type_code`, `name`, `is_uploaded`, `expiry_date`, `document_id`).

### Tap behavior (frontend)
- Tapping the card opens Documents module with the full list.
- Tapping a specific thumbnail opens that document (or upload flow if not uploaded).

### Caching
Lazy cache keyed by `(employee_id, widget_code)`. TTL: 1 hour (documents change infrequently). Invalidated on `hr.employee` write for document-related fields and on `ir.attachment` create/write/unlink for the employee.

### Acceptance criteria
- The 4 fixed thumbnails always appear in the same order matching v7.
- Expiry logic correctly distinguishes "expiring soon" vs "expired".
- Empty / uploaded states render distinct visuals for each thumbnail.
- Card renders identically to v7 including the stacked-papers pattern.

---

## Widget 2: Media

### Frontend (must match v7)
- Full-width card with min-height 150px
- Gradient: `#2A2D35 → #1A1F2E → #0F0F15 → #050507` (near-black) with subtle gray highlight
- Camera-lens-ring pattern faded right-center (gray rings at opacity ~0.5)
- Glass icon container top-right with camera icon
- Top label "Gallery" in light gray, title "Media"
- Layout split:
  - **Left:** big number "128" (total photos) + trend in light-green "+24 photos today"
  - **Right:** row of 4 small image thumbnails (3 real previews in varied gradient tones + 1 "+24" overflow tile)

### Backend business logic

#### Data source
- Media items are stored as `ir.attachment` records with `mimetype` starting with `image/` or `video/`, linked to projects, sites, or directly to employees.
- Optionally a custom `elrace.media` model with categorization tags exists — use it if present.

#### Scoping
- **Personal media:** photos/videos the user uploaded.
- **Project media:** photos/videos linked to projects the user is part of (via `staff_list_ids`).
- **Site media:** photos/videos linked to sites the user works on.
- Widget shows the **union** of all three buckets — everything the user has access to see, deduplicated.

#### Calculations
- **Total count:** all media items in the user's accessible scope.
- **Today's new count:** items where `create_date.date() == today.date()`.
- **Trend message variants:**
  - 0 new today → "No new today"
  - 1 new today → "+1 photo today"
  - 2+ new today → "+N photos today"
  - If there are videos too → "+N items today" (more generic phrasing)
- **Thumbnails:** the 3 most recent media items (videos and photos mixed by date). Each item provides:
  - `media_id`
  - `thumbnail_url` (server returns a small pre-generated thumbnail or signed S3 URL — Elrace uses AWS S3 for media)
  - `media_type` (photo / video — frontend shows a small play icon on videos)
- The 4th slot is the "more" tile: shows "+N" where N = `total_count − 3`.

### Edge cases
- User with no media at all: total = 0, all 4 thumbnail slots show empty (gray placeholder), trend message "No media yet".
- Media uploaded recently but still processing: server should only return items with a usable thumbnail (skip processing items).
- S3 URLs need signed access: backend returns time-limited signed URLs (e.g., 15-minute expiry) — frontend doesn't cache them indefinitely.
- Deleted media: filtered out before counting.
- Permission edge: if user loses access to a project after a media was created, that media disappears from their count on next cache refresh.

### API contract (data only)
- Input: employee from middleware.
- Output payload: `total_count`, `new_today_count`, `trend_message`, `recent_media[]` (exactly 3 most recent items with `id`, `thumbnail_url`, `media_type`), `overflow_count` (`total_count − 3`, never negative).

### Tap behavior (frontend)
- Tapping the card opens Media module with the user's accessible gallery, sorted by recent.
- Tapping a specific thumbnail opens that item in a fullscreen viewer.
- Tapping the "+N" overflow tile opens the module with no pre-filter (full gallery).

### Caching
Lazy cache keyed by `(employee_id, widget_code)`. TTL: 10 minutes (media uploads happen during the day). Invalidated on `ir.attachment` create/write/unlink for any item in the user's scope.

Note: signed S3 URLs have their own expiry (~15 min). If the cache TTL is shorter than the URL expiry, no issue. If a request comes after cache TTL but the URLs are still fresh, they're regenerated on the next fetch.

### Acceptance criteria
- Total count matches Media module for the same user scope.
- The 3 thumbnails are genuinely the 3 most recent.
- Signed S3 URLs work and don't expire before frontend has rendered.
- Video items show a play icon overlay (frontend handles, backend just signals `media_type`).
- Card renders identically to v7 including the camera-lens pattern.

---

## Widget 3: Prayer Times

### Frontend (must match v7)
- Full-width card with min-height 140px
- Gradient: `#6B5328 → #5A4520 → #4A3820 → #3A2D18` (gold/olive) with gold radial highlight top-right
- Islamic geometric pattern faded across the right half (gold strokes at opacity ~0.5)
- Gold gradient icon container top-right with mosque-crescent icon
- Top label "Al Ain" (location) in light gold, title "Prayer Times"
- Subtitle below in gold: "Next: Dhuhr in 1h 12m"
- **Prayer times row** in a darker sub-card (rounded inset): 6 times displayed equally spaced — Fajr, Shuruk, Dhuhr, Asr, Maghrib, Isha
- The currently active prayer time is highlighted with:
  - Small gold dot above its name
  - Name and time in gold instead of white

### Backend business logic

#### Data source
- Prayer times are not stored as Odoo records — they are computed daily based on location and date.
- Options:
  - **Recommended:** call an external API (e.g., `https://api.aladhan.com/v1/timings`) once per day per location, cache the result.
  - Alternative: implement a calculation in Python using standard astronomical formulas (more complex but no external dependency).

The first option is preferred for accuracy and time-to-build.

#### Location resolution
- **Default:** the user's employee `work_location_id` or assigned site location. Backend resolves location coordinates (latitude/longitude) from the location record.
- **Fallback:** if no location set, default to Al Ain coordinates (24.2075° N, 55.7447° E).
- **Override:** future feature — user-selectable location. Out of scope for v1.

#### Calculations
- **Daily fetch:** when the first user requests prayer times for a given (location, date), call the external API, store the 6 timings in `hub.widget.cache` with the date as part of the key.
- **6 prayer times:** Fajr, Shuruk (Sunrise), Dhuhr, Asr, Maghrib, Isha — in 12-hour AM/PM format.
- **Current/next prayer:** compare current time with the 6 times. The current prayer is the most recent one that has already started; the next prayer is the next one in sequence.
- **Active highlight:** the prayer time that is currently the most-recently-started (between Dhuhr and Asr → Dhuhr is highlighted).
- **Countdown to next:** `next_prayer_time − now`, formatted as "1h 12m" or "23m" or "45s" (smallest unit only).

### Edge cases
- After Isha and before midnight: "next" is tomorrow's Fajr. Backend handles the cross-day boundary by fetching tomorrow's times if needed.
- Before Fajr (early morning): "next" is today's Fajr; no prayer is currently "active" — show Isha from previous day as the most-recent, or show nothing as active and label as "Awaiting Fajr".
- External API down: serve last-known-good cache for the location (even if a few days old) and add `data_stale: true` flag. Frontend can show a subtle "Offline" indicator.
- Daylight saving / timezone change: backend always stores times in UTC, converts to user's timezone (typically Asia/Dubai for UAE) on response.
- Friday Jumu'ah: not differentiated in this widget (special Jumu'ah display is a future enhancement).

### API contract (data only)
- Input: employee from middleware → location resolved server-side.
- Output payload: `location_name` ("Al Ain"), `prayers[]` (6 entries, each with `name`, `time_display` "12:22", `is_active` boolean, `is_next` boolean), `next_prayer_name` ("Dhuhr"), `next_prayer_countdown_display` ("1h 12m"), `next_prayer_countdown_seconds` (raw number for client-side ticking if desired), `data_stale` (boolean).

### Tap behavior (frontend)
- Tapping the card opens a dedicated Prayer Times screen with monthly view, Qibla direction, and (future) Quran-related features.
- No deep-link on individual prayer times — the whole card opens the module.

### Caching
Lazy cache keyed by `(location_id, current_date)`. TTL: until midnight in user's timezone. Single cache entry serves all employees at the same location, since prayer times are not personal.

Countdown ("1h 12m") is computed server-side at fetch time, but the frontend may also tick locally to avoid stale countdown text. Backend doesn't refresh purely for countdown changes.

### Acceptance criteria
- Times match the external source (or calculated formula) within 1-minute tolerance.
- "Active" highlight moves correctly between prayers throughout the day (test at boundaries: just before Dhuhr, just after Asr, etc.).
- Countdown updates correctly when the user pulls to refresh.
- Card renders identically to v7 including the Islamic pattern and the inset prayer-times sub-card.

---

## Common to all 3 widgets

### Shared characteristics
- All three are stacked full-width rows — no 2-column splits.
- All three are essentially **read-only reference content** — the user looks at them, doesn't act on them from the card itself.
- All three have longer cache TTLs than the Productivity widgets because the underlying data changes less frequently (or, in the case of Prayer, changes only at predictable times).

### Shared dependencies
- `hr.employee` (resolved from middleware).
- `ir.attachment` (Documents and Media both rely on it).
- AWS S3 / Lambda for media thumbnails and signed URLs (already in production for Elrace).
- External Prayer Times API or astronomical calculation library (for Prayer widget).

### Sequencing (build order)
1. **Prayer first** — simplest data model (just a daily fetch + cache), no Odoo permission complexity, validates the "external data source" pattern that might be useful elsewhere later.
2. **My Documents second** — extends the personal-scope pattern with a fixed-set-of-types display.
3. **Media last** — most complex (S3 signed URLs, thumbnails, video/photo type handling).

### Testing checkpoints
- Documents: verify all 4 thumbnails appear in correct order; verify expiry message variants; verify "not uploaded" empty state per thumbnail.
- Media: verify signed S3 URLs work and refresh on cache miss; verify the 3 thumbnails are genuinely most-recent; verify "+N" overflow appears only when total > 3.
- Prayer: verify "active" prayer highlight moves correctly across all 6 time slots throughout a simulated day; verify countdown format ("1h 12m" → "59m" → "5m" → "45s"); verify external API down → serves stale cache with `data_stale: true`.
- Flutter golden tests for all three cards.

### Out of scope (for this iteration)
- Upload action directly from widgets (lives in respective modules).
- Document expiry push notifications (separate notification system).
- Qibla direction in the Prayer widget (lives in the dedicated screen).
- User-selectable prayer location override (defaults to assigned site for v1).
- Video playback inline in Media widget (taps open full screen).
- Multi-language prayer time labels (English only for v1; Arabic added with localization in a later release).
