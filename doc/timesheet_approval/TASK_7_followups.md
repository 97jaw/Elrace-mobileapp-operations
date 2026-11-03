# Task 7 — Follow-ups after phone test: documents section + live counters

Branch: `fix/timesheet-approval-followups` from up-to-date `main` (1d87f7a,
PR #6 merged). Follow `.cursor/rules/branching-from-main.mdc`. **Do not deploy.**
Reuse existing widgets; no new packages.

## A. Timesheet documents section (foreman dashboard) — like the old Recent section
The old "Recent timesheets" section (see `git show 57cf24f^:lib/ui/presentation/timesheet/foreman/fm1_foreman_dashboard.dart`,
`_RecentTimesheetsSection`) had: title row with an orange **Show all** button on
the right, and the list inside an `Expanded` with its **own scroll** that fills
the rest of the screen (the page itself does not scroll). Do the same for
`TmTimesheetDocumentsSection`:
- Title row: `Timesheet documents` + **Show all** (same style as before).
- Body: latest **5** docs (`watchMine` stream, newest first, Firestore
  `limit(5)`), inside `Expanded` with its own scroll; same rows, status chips,
  empty/error/loading states, tap opens the stamped PDF as today.
- **Show all** → a full list screen (glass header like other timesheet screens)
  with all of the foreman's docs, newest first, same rows, paged with Firestore
  `limit` + "Load more" (20 per page), live status updates, same tap behaviour.
- Flag OFF → section hidden and the layout still fills correctly.

## B. Waiting counter and bell badge must be right on the home screen
Now: the home Waiting counter and the bell red badge show the right number only
after opening the Waiting screen / Notification Center. Causes:
1. On app start the counts are computed before Firebase sign-in / flag read, so
   the Sign Document count and the Firestore unread count are 0, and
   `ApprovalCountService` caches that total.
2. Nothing refreshes them when a new Sign Document arrives or a result is
   stored (those pushes skip local storage, and Firestore changes are not
   watched).

Fix:
- `ApprovalCountService`: keep the Odoo part (cached as today) and the Sign
  Document part separately. Total = Odoo + (flag ON ? SD : 0). Setting the SD
  part notifies listeners without refetching Odoo.
- One live watcher (singleton, started once at app start, e.g. from the resume
  coordinator / app bootstrap) that listens to `FirebaseAuth.authStateChanges()`
  and the flag:
  - signed in + flag ON → subscribe `watchPendingCountFor(uid)` → update the SD
    part; subscribe `users/{uid}/app_notifications where read == false` →
    update a cached unread count used by `AppNotificationsRepository.addUnreadTo`
    (no extra `count()` query when the watcher is live) → notify
    `BadgeRefreshService` listeners and update the app icon badge;
  - signed out / flag OFF → cancel both, set both counts to 0;
  - flag refresh on resume / sign-in restarts it.
- Home screen visible again: when the user comes back to home from any screen
  (RouteAware `didPopNext` with the existing global `AppOrientations.routeObserver`, already used by `home_tablet_layout.dart`), refresh the waiting
  and bell counts through `BadgeRefreshService`, throttled (at most once every
  30 s) so back-and-forth does not spam the Odoo APIs.
- Foreground push of an approval type (Odoo approvals and
  `timesheet_approval*`): invalidate the Odoo approval cache and refresh the
  counts (same throttle).

## Done when
- Home Waiting counter and bell show the right numbers on first open (as soon as
  Firebase sign-in completes), change live when a timesheet is sent to me /
  approved / rejected, and after returning to home.
- `flutter analyze`: no new issues in touched files. `flutter test`: all pass
  (add tests: total = Odoo + SD, flag OFF → Odoo only, SD update does not refetch
  Odoo; throttle).

## Commits
1. `docs(timesheet-approval): task 7`
2. `feat(timesheet): Timesheet documents shows the latest 5 with Show all`
3. `fix(badges): live Sign Document count and result unread from Firestore`
4. `fix(badges): refresh waiting and bell counts on return to home and on approval pushes`

Push the branch and open a PR to `main`. Report results. Stop.
