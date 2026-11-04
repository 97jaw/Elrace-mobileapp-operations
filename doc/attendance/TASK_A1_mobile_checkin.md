# A1 (Mobile) — Check-in: remove Face ID step, location only when required, server time

Branch (approved name only) from up-to-date `main`. Follow
`.cursor/rules/branching-from-main.mdc`. Needs Odoo A1 for `location_required`.
A missing key (old server) = **true** (today's behaviour), so nothing gets looser
before the server is deployed.

## 1. Remove the Face ID / biometric step from check-in and check-out
- `lib/ui/presentation/home_screen/screens/custom_swipe_button.dart`
  `_startAttendanceAction`: after the confirm popup go straight to
  `_performCheckInOut()`. Remove the `shouldSkipFaceId` branch, the
  `UnifiedBiometricHelper.authenticateForAttendance` call, `isProcessingFace`,
  the `wasCheckedInBeforeFaceAuth` preference and the now-unused import.
- Remove `UnifiedBiometricHelper.authenticateForAttendance` if nothing else uses
  it. **Keep** the helper's other methods and `AppConfigService.faceIdEnabled`: the
  home biometric sign-in gate (`home_screen.dart`) still uses them.
- Clean the "requires Face ID" comment on `isAutoCheckout` in `check_out_event.dart`.

## 2. Location only when required
`checkin_context.location_required`:
- **true** (foremen; other staff when Odoo param is ON): today's map flow, with
  the projects from `checkin_projects` (they are now the ones that count). Remove
  the extra `validate_user_location` call before check-in: `check_in` is the
  authority; show its message when it refuses.
- **false**: the slider is enabled without picking a project or being in range.
  Keep the map as information only. Still send GPS if available.

## 3. Send full-precision GPS
`check_in_repo.dart` rounds latitude/longitude to 2 decimals (~800 m) before
`/api/check_in/`. Send the full values (check-out already does).

## 4. Show the server's time
After check-in / check-out, show and store `check_in_time` / `check_out_time` from
the server response (the home card and the 16-hour reset), not the phone clock.
Keep sending `checkin_date_time` / `checkout_date_time` (the server ignores them,
older servers still need them). If the response has no time, fall back to today's
behaviour.

## No crash rule
Every new key is read null-safe (`location_required` missing → true, time missing →
local fallback). Never assume a new key exists; an older server must work exactly
like today.

## Done when
Foreman: on site → checked in; outside 100 m → server message, no record. Other
staff with param OFF: check-in works anywhere with no project picked. No Face ID
prompt on check-in or check-out. A phone with a wrong clock shows the server's
check-in time. Old server: app behaves as today. Biometric sign-in gate unchanged.
`flutter analyze` no new issues; `flutter test` all pass. Push, PR to `main`, report,
stop.

## Commits
1. `docs(attendance): A1 check-in task`
2. `refactor(attendance): remove the Face ID step from check-in and check-out`
3. `feat(attendance): ask for location only when the server requires it`
4. `fix(attendance): send full-precision GPS on check-in`
5. `fix(attendance): show check-in and check-out times from the server`
