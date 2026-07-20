# ADR 0001: Riverpod as the standard state-management approach

**Status:** Accepted
**Date:** 2026-07-19
**Context:** FIX_IMPLEMENTATION_PLAN.md Phase 7.1, following
INDEPENDENT_PERFORMANCE_AND_ARCHITECTURE_REVIEW.md §3.

## Context

The app currently runs five state-management approaches concurrently:

| Approach | Files using it (at time of writing) |
|---|---|
| `flutter_riverpod` | 127 |
| `flutter_bloc` / `bloc` | 56 |
| `provider` (ChangeNotifier) | 43 |
| GetX (`package:get/get.dart`) | 7 |
| Raw `StatefulWidget`/`setState` | pervasive, uncounted |

`main.dart` nests all of these on top of each other in one widget tree
(`ProviderScope` → `MultiProvider` → `MultiBlocProvider`, with GetX
controllers living independently outside all of it). This is not purely
cosmetic:

- `HomeBloc.currentIndex` (Bloc) drives the exact bottom-nav rebuild bug
  fixed in Phase 1, while the tab content built on top of it
  (`fm2_project_detail.dart`, `pm2_project_detail.dart`) is Riverpod-heavy.
  Fixing tab/nav performance means coordinating a Riverpod-heavy subtree
  under a Bloc-driven parent.
- Four different disposal/lifecycle models (`Bloc.close()`,
  `ChangeNotifier.dispose()`, Riverpod `ref.onDispose`, GetX `onClose()`)
  make it harder to reason about "did this screen actually clean up its
  listeners/timers/requests" — directly relevant to the rapid-navigation
  hang investigation, since a leaked listener or timer looks identical to
  a leaked network request from the outside.

## Decision

Riverpod is the standard for all **new** state-management code. It already
backs the majority of the codebase (127 files) and everything built in
this fix pass (the centralized `ApiClient`, the Phase 3 tab-cancellation
work) assumes Riverpod's `.autoDispose` + `ref.onDispose` lifecycle model.

`provider` and GetX are treated as legacy — do not add new code in either
pattern. `flutter_bloc` is not deprecated by this decision (it's a
reasonable, still-used pattern, and `HomeBloc` is not being rewritten as
part of this fix pass), but new screens should default to Riverpod unless
there's a specific reason to extend an existing Bloc.

## Consequences

- No mandate to migrate existing `provider`/GetX/Bloc code to Riverpod.
  This is a multi-month effort with no immediate user-facing payoff (per
  the plan) and is explicitly out of scope here.
- New tab/navigation work should not deepen the five-way fragmentation —
  e.g., a new project-detail tab should use a Riverpod `FutureProvider`,
  not introduce a sixth pattern or extend GetX.
- Code review should flag new `ChangeNotifierProvider`/GetX controllers in
  otherwise-Riverpod areas as a convention violation, not wave them
  through because "that's how the neighboring file does it."

## Not decided here

- Whether/when to migrate `HomeBloc` (bottom-nav index state) to Riverpod.
  The Phase 1 `IndexedStack` fix works with `HomeBloc` as-is; revisiting
  the Bloc itself is a separate, larger decision.
- A concrete migration timeline for `provider`/GetX call sites — there
  isn't one; they're legacy-to-migrate opportunistically, not on a clock.
