# Face Capture — Backlog (later tasks)

Date added: 2026-10-15. Not scheduled yet; discuss before writing Cursor tasks.

## B1 — Movement during capture (test + hardening)
- Confirm behaviour when the phone moves after tap / auto-capture starts:
  - Fast path: decision uses the 4 pre-tap buffered frames → completes, never adds a different person.
  - Slow path: 4 new frames after tap → face lost/blurred/too close → blocked with retry, nothing added.
- Add explicit test cases: tap then swing away (fast + slow), tap on labor A then swing to labor B (B must never be added).
- Optional hardening: if face box jumps a lot between the 4 burst frames, treat as "hold still" instead of a generic PAD block.

## B2 — Guided framing ("capture guidance")
- Responsive target oval per device/orientation, runtime instructions (closer/back/center/look straight/light), capture enabled only when framing is ready, exposure/focus on the face, optional voice prompts.
- Approach discussion in chat 2026-10-15; decide scope before writing tasks.

## B3 — Auto-zoom to frame the face
- Camera zooms in when the face is small/far (mainly tablets, back camera) and back toward 1x when too close; "Move back" when already at 1x.
- Rules under discussion: zoom only when the face is centred, cap ~2x, smooth steps with hysteresis/cooldown, freeze zoom when the badge is green and during the anti-spoof burst, reset buffers after each zoom change, reset to 1x when face lost or target changes.
- Needs full anti-spoof regression (zoom changes what the spoof models see). Odoo on/off switch recommended. Build after B2 (guidance).
