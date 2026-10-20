# TASK 09 — Square face marker with employee id, no oval/guides, delayed hints

Side: App (Flutter)
Depends on: TASK 08 (`markerState`, `noUsableFrameSince`, dominant reason)
Read first: `doc/face_capture_1to1/10_BEST_FRAME_APPROACH.md` §4

## Context
The capture camera should look like a BioTime terminal: plain full-screen preview, a square marker that tracks the face, and the employee id on it when verified. No oval, no framing guide, no name on the marker.

## Files
- `lib/ui/presentation/timesheet/foreman/attendance/timesheet_capture_camera_panel.dart` → `TimesheetFaceOverlayPainter` (box → view mapping with `BoxFit.cover`, `verifiedOnly`), overlay hint widgets, any oval/guide overlay
- `lib/ui/presentation/timesheet/widgets/face_recognition/tm_face_mesh_painter.dart` (`paintNameBadge`, colors)
- `lib/core/timesheet/network/timesheet_odoo_employee.dart` (`employeeId`)

## Change
1. **Marker (verify mode):**
   - `markerState = none` → draw nothing (default). Keep a const flag `showNeutralSquare = false`; when true, draw a thin neutral square without text.
   - `markerState = verified` → green **square** around the face: square side = max(box w, h) × 1.15, centred on the face box; corner-bracket style (four L-shaped corners, ~22 % of side each, stroke ~3 dp, rounded caps). Use the existing box → view transform so it sits on the face on phones and tablets, front and back camera.
   - Label: **employee id only** (`employeeId`, integer, e.g. `4255`) in a small green pill above the square (below if no room at the top). No name, no file id.
   - Smooth movement: lerp box position/size between frames (~100 ms) so the square doesn't jitter.
2. **Remove** any oval, face guide, or framing overlay from the 1:1 capture screen. Remove the immediate quality hints ("Move back", "Come closer", etc.) in verify mode.
3. **Delayed hint:** only when `noUsableFrameSince` ≥ 2 s, show one short line at the bottom of the preview based on the dominant reason: "Move back a little" / "Come closer" / "Look at the camera" / "Hold still" / "More light needed". Hide as soon as usable frames return. No hint while the marker is green or a card is shown.
4. Cards (green / blue / doesn't match / no photo), picker strip, shutter colour: unchanged. Shutter turns green when `markerState = verified`.
5. Switch off (`face_best_frame_enabled = false`) → today's overlay unchanged.

## Do not
- Change capture logic, anti-spoof, verification, cards or sounds.
- Touch AT2 or enrollment overlays.

## Verify (iPhone small + large, iPad, Android phone + tablet; front and back camera)
1. No oval or guide visible at any time.
2. Wrong person / unverified face → no marker.
3. Target verified → green corner-bracket square tightly on the face, label shows only the employee id.
4. Move head → square follows smoothly, no jitter, stays on the face in portrait on all devices.
5. Stand too close or turn away for > 2 s → one hint line appears; disappears once usable frames return.
6. Switch off in Odoo → old overlay back.
