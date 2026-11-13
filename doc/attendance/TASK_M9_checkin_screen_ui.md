# TASK M9 — Check-in screen: new design (UI only)

Repo `Elrace-mobileapp-operations`, branch: **confirm with the user** (default: continue on
`feat/checkin-attendance-v2`, PR #9). Screen: `lib/ui/presentation/attendance_checkin/`.
Reference design: the user's first screenshot ("Inside allowed area" sheet). No backend change in this task;
logic review comes after the UI.

## Remove

- The BioTime office / device gate and listing: `_OfficeDeviceList`, `_OfficeRow`, the
  `hasBiotimeAssignment` branch in `CheckinEligibilitySection` and the sentence "Use your assigned BioTime
  office or device…". `_sliderEnabled` must no longer return false because of `hasBiotimeAssignment`.
  Keep the model fields (`biotimeOffices`, `biotimeTerminals`) so old/new servers still parse — just stop
  using them in the UI.
- The swipe control on this screen (replaced by two buttons, see below). Do not delete
  `custom_swipe_button.dart` (used elsewhere).

## Map (top) — as in the design

- Geofence of the selected project: **dashed** circle border (bottle green), light green fill (~12–15 %).
- Pill label above the centre: **"Allowed Zone {radius} m"** (dark green pill, white text, small pointer dot).
- Project marker in the centre; user location as the blue dot with a heading cone when available.
- Under the user's marker a white pill: **"{distance} away"** (e.g. "11 m away", "1.2 km away").
- Keep: back button (top-left), search (top-right), re-centre button (right, above the sheet).
- Remove the old "Near 17 m" faded banner (its info moves to the sheet).
- No project with coordinates → no circle/pills; map centres on the user.

## Bottom sheet — as in the design

Rounded top sheet with a grab handle. Content top → bottom:

1. **Location card** (icon in a round tinted badge + title + subtitle + chip on the right):
   | State | Title | Subtitle | Chip | Colour |
   | --- | --- | --- | --- | --- |
   | Inside | Inside allowed area | `{d} away · Allowed radius {r} m` | ✓ Location verified | green |
   | Outside | Outside allowed area | `{d} away · Allowed radius {r} m` | Move closer | red/amber |
   | Waiting for GPS | Getting your location… | Allowed radius {r} m | — | grey |
   | Location not required (`location_required == false`) | Check-in from anywhere | — | — | neutral |
2. **Linked location name**: the selected project name (marquee if long) + `wo_ref_no` small under it; tap
   opens the existing project search panel when the user has more than one allowed project.
3. **Today**: compact In / Out times row (reuse `HomeMidAttendanceTimes`).
4. **Info strip**: "Actions available at this location" (green) / "Move inside the zone to check in"
   (amber) / "No linked location — contact HR" (grey).
5. **Two buttons** side by side: **Check In** (green, login icon) and **Check Out** (navy, logout icon).
   - Enabled only when actions are available (rules below) AND the today status allows it:
     not checked in → Check In enabled, Check Out disabled; checked in → the opposite; checked out → both
     disabled with "Checked out for today".
   - They call the SAME existing check-in / check-out flows the swipe used (`onValidateBeforeCheckIn`,
     server time, GPS payload from A1). Show a loading state on the pressed button; disable both while
     a request runs.

## When is the bottom section disabled (grey)

- `location_required == true` and **no allowed project has coordinates** → whole section grey
  (card + buttons disabled), info strip "No linked location — contact HR".
- `location_required == true`, user outside the zone → card red/amber, buttons disabled.
- `mobileCheckinAllowed == false` or the existing `_checkinWidgetDisabled` → section grey, strip
  "Mobile check-in is not enabled for your profile".
- `location_required == false` → **open question for the user** (see report): today the server lets these
  staff check in from anywhere. Implement it behind one boolean in the widget
  (`disableWhenNoLinkedLocation`, default **false** = keep today's behaviour) so the decision is a one-line
  change.

## Rules

- No backend/API change; responses and models stay compatible with the current server.
- Keep the existing geofence math (`checkin_geofence_service.dart`) and distance formatter; add a formatter
  for "{d} away" (m below 1000, km with 1 decimal above).
- Colours/typography from `HomeGlassTheme`; sizes with ScreenUtil; no new packages. The dashed circle can be
  drawn with a polyline of short segments around the centre (flutter_map has no dashed circle).
- Old app behaviour for staff with BioTime offices now changes (they see the mobile buttons) — this is
  intended (user decision); mention it in the report.
- `flutter analyze` clean for the touched files; existing tests still pass; add widget tests for the four
  location-card states and the button enable/disable matrix.

## Report back

Files changed, screenshots of: inside / outside / no linked location / checked-in / checked-out, and anything
in the design you could not match.
