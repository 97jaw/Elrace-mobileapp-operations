# TASK LT3 — Mobile (Flutter)

Branch `feature/labor-transfer` (from main). Follow app theme (TimesheetModuleTheme), Riverpod patterns, existing API client.

1. Foreman dashboard: entry "Labor transfer" (button/card near Your Team).
2. New request screen: labor multi-select (search, photo, emp id, current foreman, disabled if in pending transfer or already in my team), target foreman picker, note, Submit → confirmation → success toast.
3. Transfers list: tabs **My requests / To approve / Incoming** (To approve only if the user is an approver of any). Status chips (pending amber, approved green, rejected red).
4. Detail: labors with previous foreman, requester, target, approver, timeline. Approver sees Approve / Reject (reason sheet). Requester sees Cancel while pending.
5. Push notification tap → opens detail. On approve/reject push, refresh Your Team + face roster (`WalkUp: roster refreshed`) so the walk-up candidates include the new labors.
6. Offline: request creation requires network (show message), no queue.

Do not change camera / face capture code except triggering the existing roster refresh.
