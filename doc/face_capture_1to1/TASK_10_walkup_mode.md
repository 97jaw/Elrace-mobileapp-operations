# TASK 10 — Walk-up mode (auto identification) behind an Odoo match-mode switch

Side: Backend (1 config key group) + App
Depends on: best-frame pipeline (Tasks 08/09 + Android perf work) merged and stable
Read first: `doc/face_capture_1to1/10_BEST_FRAME_APPROACH.md`

## Goal
On the project camera, any labor of the foreman's team who walks in front of the camera is identified and captured automatically — no labor selection. Safety comes from strict bars inside the system, not from extra foreman steps. Mode is switchable from Odoo; `verify` (today's 1:1) stays the default and the fallback.

## Part A — Backend
In `get_app_config` (`/api/app/config`) add, same pattern as the other face keys:

| Response key | Odoo parameter | Type | Default when missing |
|---|---|---|---|
| `face_match_mode` | `elrace.face_match_mode` | `"verify"` \| `"walkup"` | `null` → app uses `verify` |
| `face_walkup_min_score` | `elrace.face_walkup_min_score` | float | `null` → app 0.40 |
| `face_walkup_min_lead` | `elrace.face_walkup_min_lead` | float | `null` → app 0.15 |

Unknown mode string → `null`. Bump module version. No other backend change: the existing audit field `x_face_method` carries the mode (`profile_1to1` / `profile_walkup`).

## Part B — App

### 1. Config
Parse + cache the three keys (same as other face tuning). Valid ranges: score 0.20–0.90, lead 0.05–0.40. Mode applies on next camera open.

### 2. Where walk-up applies
- **Project camera only** (opened from day hub / project dates, no `expectedEmployeeId`).
- **Labor camera** (opened for one labor from the dashboard) always stays `verify`.
- AT2 legacy untouched. iOS and Android both.

### 3. Identification rule (per evidence frame)
- Candidates = Your Team labors with a ready template, **excluding** templates flagged `LOW_RES` (source face < 90 px) or look-alike (≥ 0.45 to another template). Excluded labors can only be captured via "Pick labor" (verify flow).
- Competitors = all candidates + the project-labor cohort (same cohort as verify, LOW_RES excluded).
- Per frame: winner W = highest score among candidates; `lead = score(W) − max(score of every other template, team or cohort)`.
- Frame "identified" when `score(W) ≥ walkup_min_score` AND `lead ≥ walkup_min_lead`.

### 4. Accept rule (walk-up)
Within the evidence window, exactly the best-frame rule plus identity consistency:
- ≥ 3 frames that are PAD live AND identified **as the same W** (each with the bars above).
- Zero spoof frames; temporal check as today (≥3 frames, ≥600 ms span); best frame verified + live.
- Any identified frame for a different labor in the window → reset that labor's evidence (no mixing).
- Already captured W → existing blue "already attended" card (replay check on best frame).
- On accept: existing success flow (card, haptic, spoken name, background save). Audit `method = profile_walkup`, score/lead from best frame.

### 5. UI in walk-up mode
| Situation | Shows |
|---|---|
| Camera open | Full preview, **no picker strip**. Small counter chip at top: "Captured 7 / 25" (tap → read-only list of captured / remaining) |
| Face, not yet identified | No marker (same as verify) |
| Identified team labor, evidence collecting | White square + emp id + progress (1/3, 2/3) |
| Accepted | Green square + emp id → success card (photo, name, emp id) + **Undo** button for 3 s |
| Recognized project labor not in Your Team | Amber square, text "Not in your team" (no name, no id); never added |
| No identification for ~3 s while a face is present | Bottom hint "Not recognized" + button **Pick labor** → opens picker → that labor in verify (1:1) flow → returns to walk-up after |
| Spoof | Existing presentation-attack message |

Undo: removes the entry + queued draft + saved photo, labor back to remaining. Log it.

### 6. Verify mode
Unchanged (picker strip, target, "Doesn't match {target}").

### 7. Logs
- `WalkUp: frame W=<emp> score=… lead=… second=<emp> second_score=… identified=true|false`
- `WalkUp: accept emp=… frames=3 min_score=… min_lead=… ms_from_first_face=…`
- `WalkUp: excluded_low_res=[ids] excluded_lookalike=[ids]` once per camera open
- `WalkUp: undo emp=…`

## Do not
- Change models, PAD thresholds, zero-spoof, min live frames (3), verify-mode bars or behaviour.
- Show any other employee's name or id on the camera except the identified team labor (out-of-team = "Not in your team" only).

## Test (iPhone, iPad, Android low-end + good Android)
1. Mode `walkup`: 3 team labors walk in one after another in random order → each captured without touching the screen; counter updates.
2. Same labor again → blue already-attended.
3. Project labor from another team → amber "Not in your team", never added.
4. Stranger → no marker, then "Not recognized" + Pick labor after ~3 s; never added.
5. Photo / video / phone screen of a team labor → blocked.
6. Low-res-photo labor → not auto-identified; Pick labor works.
7. Undo within 3 s → entry removed, labor back in remaining.
8. Set `elrace.face_match_mode = verify` → next camera open shows picker strip, 1:1 as today.
9. Check logs: every accepted frame `lead ≥ 0.15`; send the `WalkUp: frame` lines for review.

---

## ADDENDUM (2026-10-18) — entry point & labor list ticks (overrides §2 and §5 where they conflict)

### A. Verify (1:1) stays exactly as finalized
No change to the 1:1 camera screen, flow, cards, picker strip or behaviour. The only shared change is the labor-list tick in C below.

### B. Walk-up entry point = Your Team sheet header
File: `lib/ui/presentation/timesheet/widgets/tm_team_members_sheet.dart` (`TmTeamMembersSheet`, opened from `fm1_foreman_dashboard.dart` and the other dashboards).
- When `face_match_mode = walkup`:
  - **Hide the per-labor capture button** (`_CaptureButton`, `assets/png/capture_attendance.png`) on every row.
  - Add **one camera icon in the sheet header** (same asset/size as the row icon). Tap → opens the walk-up camera for the whole team (no target, no strip), using the same project / task / date resolution the per-labor capture uses today. If the team spans more than one project for today, show a small project chooser first — **ask me before building this if it applies**.
  - The camera returns captured entries to the sheet (same return-captures path used today).
- When `face_match_mode = verify`: header unchanged (no header camera), per-labor capture buttons as today.

### C. Captured tick in the labor list (both modes)
- A labor captured today shows a **green tick the same size as the camera icon** (`_iconSize`) in the row's capture slot:
  - verify mode: replaces that row's camera icon once captured (today it's the icon + a small 14 px badge).
  - walk-up mode: shown in the same slot (there is no camera icon per row).
- Ticks update immediately when returning from the camera (and on session restore). Not-yet-captured rows: walk-up → empty slot; verify → camera icon as today.
- No-photo warning badge stays as today.

### D. Tests to add
1. walkup: sheet shows header camera, no row cameras; capture 3 labors in random order; back in the sheet those 3 rows show big green ticks.
2. verify: row camera icons as before; after capturing one labor its row shows the big green tick; 1:1 camera screen unchanged.
3. Switch mode in Odoo → reopen sheet → correct layout.
