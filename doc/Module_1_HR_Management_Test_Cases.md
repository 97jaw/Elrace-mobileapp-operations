# Module 1 — HR Management | Manual test cases

Use after Foundation **F.0–F.7** and asset forms **F2–F4**.  
**Environment:** debug build (`flutter run`), logged-in user, online.

---

## 1. App bootstrap & Riverpod (F.0 / F.6 / `main.dart`)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T1.1 | Cold start | Launch app, sign in, open Home | No crash; home loads |
| T1.2 | ProviderScope | Open **HR Management** from home | Leave flows and HR screens open without Riverpod errors |

---

## 2. Role resolution & dev toggle (F.4 / SRD §1.4)

**Pre:** `kDebugMode` only for toggle bar.

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T2.1 | Default view | Clear override (↻), note label | Matches login flags once API sends `is_hr_manager` / `is_management` / `is_pm`; if all null → **Employee** |
| T2.2 | Force Employee | Tap person icon | Label **Employee** |
| T2.3 | Force Manager | Tap groups icon | Label **Manager** |
| T2.4 | Force HR Manager | Tap briefcase icon | Label **HR Manager** |
| T2.5 | Clear override | Tap ↻ | Label returns to login-derived view |

---

## 3. Routing (F.5)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T3.1 | SIM route | HR Management → **SIM Card Request** | `HrSimCardRequestScreen` opens; back returns to menu |
| T3.2 | Car rent route | **Car Rent Request** | Car rent form opens |
| T3.3 | Allowance route | **Car Allowance** | Allowance form opens |
| T3.4 | Named routes | From dev menu, **F.2 widget sandbox** | Sandbox opens via `HrRouteNames.widgetSandbox` |

---

## 4. Networking mock (F.3)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T4.1 | Mock submit SIM | Fill valid SIM form → Submit | Toast with ref `HR/SIM/2026/…`; screen pops |
| T4.2 | Mock list | (When E1 wired) refresh list | No 401; mock or parsed data |

---

## 5. PDF watermark (F.7)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T5.1 | Sample PDF | F.2 sandbox → **Preview PDF with watermark** | Share/print UI; diagonal light gray watermark; text uses `emp_id` or `EMP-DEV` |

---

## 6. SIM Card form (SRD §5.2 / F2)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T6.1 | Required fields | Submit empty | Validation errors on reason, plan, justification |
| T6.2 | Date | Pick required-by in the past | Not allowed (picker starts today) |
| T6.3 | Justification length | &lt; 10 or &gt; 500 chars | Inline error |
| T6.4 | Phone conditional | Reason **Plan Upgrade**, empty phone | Error; valid `+971…` passes |
| T6.5 | Save draft | **Save Draft**, reopen screen | Fields restored from SharedPreferences |
| T6.6 | Attachment | Attach file | Filename shown |

---

## 7. Car Rent form (SRD §5.3 / F3)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T7.1 | To after From | To ≤ From | Toast “End must be after start” |
| T7.2 | Locations | Empty pickup/dropoff | Validation error |
| T7.3 | Distance | Enter `6000` | Toast “Distance 0–5000 km” |
| T7.4 | 30-minute rounding | Pick arbitrary time | Snapped to 30-minute grid |

---

## 8. Car Allowance form (SRD §5.4 / F4)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T8.1 | Amount | Invalid / negative | Validation error |
| T8.2 | Justification | &lt; 20 or &gt; 1000 chars | Validation error |
| T8.3 | Monthly + Mulkiya | Type **Monthly Fixed**, no Mulkiya, Submit | Toast requires Mulkiya; no submit |
| T8.4 | Effective date | Older than 90 days past | Blocked by picker range / toast |

---

## 9. E1 — Employee landing (SRD §3.1)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T9.0 | Entry | Home → **HR Management** tile | Opens **HrEmployeeLandingScreen** (not old menu-only page) |
| T9.1 | KPI row | Note counts vs list | Pending **3**, Approved **4**, Rejected **1**, Draft **2** (mock set) |
| T9.2 | KPI tap | Tap **Pending** KPI | Chip **Pending** selected; list only `PENDING` rows |
| T9.3 | Search | Type `0142` in search (wait ~300ms) | Only **Annual Leave** ref HR/LV/2026/0142 |
| T9.4 | Sort | **By type** | Alphabetical by type, ties by recency |
| T9.5 | Pull refresh | Pull down | List reloads (mock delay) |
| T9.6 | Overflow | ⋮ → **Refresh** | Same as refresh |
| T9.7 | FAB | **New request** | Opens **HrManagementMenuPage** (leave + asset hub until E2) |
| T9.8 | Card tap | Tap any request | Stub detail screen with summary + E3 note |
| T9.9 | Empty filter | Filter + search so nothing matches | “No requests match…” + **Create your first request** |
| T9.10 | Loading | (Optional) throttle network | Skeleton KPI + card placeholders |

---

## 10. Shared widgets (F.2)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T9.1 | Sandbox | Open F.2 sandbox | All components visible; chips select; search debounces (~300 ms) |

---

## 11. Regression (non-HR)

| ID | Case | Steps | Expected |
|----|------|--------|----------|
| T11.1 | Home other tiles | Open non-HR modules | Unchanged behavior |
| T11.2 | Sign-in model | Login JSON without new HR flags | App works; HR defaults to Employee view |

---

## Sign-off checklist

- [ ] All **P0** cases (T1.x, T3.x, T6.1, T7.1, T8.1) pass on iOS/Android target.
- [ ] No new analyzer **errors** under `lib/core/hr_management/`, `lib/ui/presentation/hr_management/`, `lib/core/utils/pdf_watermark.dart`.
