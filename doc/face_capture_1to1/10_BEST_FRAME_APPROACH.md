# Best-Frame Capture — Technical Approach

Date: 2026-10-16
Status: approved direction, ready for Cursor tasks
Builds on: `00_TECHNICAL_APPROACH.md` (1:1 verification), current fast-path capture

---

## 1. Goal

As soon as the camera opens, a labor standing in front of it — at any natural angle or distance — is detected and captured without the foreman or labor adjusting framing.

- No oval, no framing guide on screen.
- A BioTime-style **square marker** tracks the face; it turns green with the **employee id** when the target is verified.
- Anti-spoof strength stays the same or improves. Models, thresholds and zero-spoof tolerance do not change.

## 2. What changes conceptually

| Today ("gates") | After ("best frame") |
|---|---|
| A frame must pass all quality gates or it is ignored, and the user is told to fix framing ("Move back", etc.) | Every frame gets a **quality score**; nothing is shown to the user unless no usable frame appears for ~2 s |
| Anti-spoof burst is collected around the tap (ring buffer, 4 frames, 350 ms apart) | Anti-spoof and identity run **continuously in the background** on every usable frame and are stored as frame evidence |
| Capture decides on 4 burst frames | Capture decides on the **evidence window** (last ~1.2 s): several good frames, all live, all verified, no spoof |
| "Face too close" blocks capture | Too-close frames are simply **not used for anti-spoof** (they can still drive the marker); no block |
| Marker = name badge | Marker = **square around the face + employee id** |

## 3. Pipeline

```
camera stream (720p, all devices)
  → ML Kit detection (largest face only)
  → frame quality score (0..1, frame-relative, device-independent)
  → if identity-eligible: 1:1 verify vs target (score, lead)           [stored on frame]
  → if PAD-eligible:      MiniFASNet dual-model PAD (live/spoof/uncertain) [stored on frame]
  → FrameEvidence appended to rolling window (last 1.2 s)
  → decision:
      marker  → green square + emp id when target verified on ≥2 recent frames and no spoof in window
      accept  → when ACCEPT RULE holds (below) → green card, background save (as today)
```

### Eligibility (all frame-relative, % of frame short side)

| Use | Condition |
|---|---|
| Identity | face width ≥ 8 %, yaw ≤ 35°, roll ≤ 30°, 5 landmarks present |
| Anti-spoof | face width 10–55 %, yaw ≤ 30°, face box fully inside frame, sharpness ≥ today's still threshold |
| Neither | frame still updates the marker position, nothing else |

### Quality score

Weighted, frame-relative: face size closeness to ~35 %, frontalness (yaw/roll/pitch), sharpness, eyes open, brightness. Used only to pick the **best frame** (saved photo + audit values), never to block.

### ACCEPT RULE (security core)

Within the evidence window (last 1.2 s):

1. **≥ 3 frames** that are PAD-eligible, PAD = live (today's thresholds), and 1:1 verified (today's bars, today's cohort).
2. **Zero frames with PAD = spoof** in the window. One spoof frame → reject, clear window, 1.5 s cooldown, existing presentation-attack message.
3. Those frames span **≥ 400 ms** (temporal spread) and pass the existing frozen-box / head-motion temporal check.
4. The **best frame** (highest quality score among the ≥3) is itself verified and live.
5. "Uncertain" PAD frames (between today's uncertain and live thresholds) are not counted and do not block.

Never accept on a single "best" frame (cherry-picking risk).

### Throughput

- Normal devices: process a frame every ~200 ms (≈5 fps for detection + PAD + identity; each costs ~10–40 ms).
- Low-end devices: every ~400 ms (existing low-end mode).
- Under load: drop frames, never queue.

## 4. UX

- Full camera preview. **No oval, no guide.**
- Face detected, not yet verified: **no marker** (default). Optional flag to show a thin neutral square.
- Target verified: **green square** (corner-bracket style) around the face + label **employee id** (e.g. `4255`). No name on the marker.
- Accept: green card (unchanged), haptic + spoken name (unchanged).
- Only if **no usable frame for ~2 s**: one short text hint at the bottom — "Move back a little" / "Come closer" / "Look at the camera" / "Hold still" / "More light needed". Hidden again as soon as usable frames return.
- Manual shutter: if the ACCEPT RULE already holds → accept instantly; otherwise wait up to 1.5 s for it, then show "Hold still".

## 5. What stays the same

- Models (MiniFASNet v2 + v1SE, MobileFaceNet), all thresholds, verification bars, cohort, Odoo config.
- 1:1 target, labor picker, auto-advance, held cards, already-attended (replay check on best frame), background save, audit fields (from best frame), submit.
- AT2 legacy camera untouched.

## 6. Safety switch

`elrace.face_best_frame_enabled` (Odoo, via `/api/app/config`, default **true** when missing) and a const fallback. Off → today's fast/slow capture path exactly as it is now.

## 7. Tasks

| # | Task | Side |
|---|---|---|
| 08 | Best-frame evidence pipeline + accept rule + safety switch | App (+ 1 key backend) |
| 09 | Square marker with employee id, remove oval/guides, delayed hints | App |

Run 08, verify, then 09.

## 8. Must-pass tests (both tasks, iPhone + Android phone + iPad/tablet, profile build)

1. Labor walks in at a natural angle → green square + id < 1 s, accepted without anyone adjusting.
2. Labor too close → still accepted once a usable frame appears, no "Move back" unless ~2 s without usable frames.
3. Printed photo, phone-screen photo, video replay → never accepted; spoof message.
4. Photo until green, then swap to a live different person → rejected (identity on same frames).
5. Live target, then photo swapped in → blocked (spoof frame in window).
6. Wrong person → no marker, never accepted.
7. Two faces in view → only the largest is used; wrong-person never accepted.
8. Switch off in Odoo → old behaviour back after config refresh.
9. Low-end Android: no freeze, accepts within ~2 s.
