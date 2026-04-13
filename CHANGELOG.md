# Changelog — Notchly v2

All notable changes ordered newest-first. Each version maps to a git commit on `main`.

---

## v0.9 — Scroll Boundary Audit (2026-04-13)

**Commit:** `e5e6eec`

### Fixed
- **BUG-A — Async guards only checked 85pt trigger zone, not full pill**
  Three `DispatchQueue.main.async` blocks in `ScrollDepthHandler` re-checked only `cursorInHoverZone()`. BUG-25 (v0.8) fixed the outer guard but missed these inner async guards. Cursor anywhere in the 222pt dead zone below the trigger strip (but still inside the pill at S3) caused all progress updates to be silently dropped. All three guards updated to check both zones.

- **BUG-D — New trackpad gesture at expanded stage collapsed pill to S0**
  `phase == .began` reset `accumulator = 0`. Starting a fresh gesture while the pill was at S3 (rawProgress=0.70) made `rawP = 0/200 = 0`, triggering an immediate hard-stop to S0. Fixed by seeding accumulator from `rawProgress × 200` on gesture start so each new gesture continues from the current pill position.

### Zone Geometry Reference (Built-in Retina, external on left)
```
Trigger zone (85pt tall):   x 3091–3541, y 897–982
Pill at S1.5 (102pt tall):  x 3129–3503, y 880–982
Pill at S3   (307pt tall):  x 3037–3595, y 675–982  ← 222pt dead zone below trigger
Pill at S4   (382pt tall):  x 3037–3595, y 600–982
```

---

## v0.8 — Adversarial Audit + Simplify (2026-04-13)

**Commits:** `3fabeea` (simplify), `a10c8f6` (interaction bugs), `c8b8ebf` (data/BDI bugs)

### Fixed
- **BUG-18 — Alert storm dropped alerts 2–N**
  Added `pendingNotificationQueue` to `NotchState`. Alerts arriving while S1A is already showing are buffered and drained in order as each is dismissed.

- **BUG-19 — Malformed JSON alert crashed FSEventWatcher**
  Added `moveToError(_:)` to `FSEventWatcher`. Invalid JSON files are moved to `alerts/error/` instead of crashing or silently vanishing.

- **BUG-20 — Diagnosis mode immediately overridden by collapse**
  After `BDIAgent.checkDiagnosisMode()` transitioned to `s1_5x_diagnosis`, `Stage1AView.performLeft()` was calling `dismissCurrentNotification()` → `collapse()`, immediately undoing the transition. Fixed with a stage check: if diagnosis triggered, call `clearNotificationForDiagnosis()` instead.

- **BUG-21 — EVRUpdater dead no-op ternary**
  `reward: signal > 0 ? signal : signal` — both branches identical. Removed, pass `signal` directly.

- **BUG-22 — DiagnosisMode.handleWrongTime() rescheduled task never saved**
  `!found` branch created a local `var t2 = task` and set `scheduledStart` on it, then `t2` went out of scope. `t` (written back to the queue) was never updated in that branch. Fixed by updating `t` directly in both branches.

- **BUG-23 — Hover entry never triggered S1.5**
  `HoverZoneMonitor.updateHoverState()` had no code to transition from S0 to S1.5 when the cursor entered the trigger zone. Added the entry detection.

- **BUG-24 — Collapse fired when cursor moved to lower half of expanded pill**
  Collapse was based only on `cursorInHoverZone()` (85pt). A pill at S3 is 307pt tall — 222pt of it is outside the trigger zone. Added `cursorInPillZone()` which computes the full pill rect from `NotchlyLayout(progress: state.displayProgress)`.

- **BUG-25 — Scroll-back from inside pill was blocked**
  `ScrollDepthHandler.handle()` outer guard checked only `cursorInHoverZone()`. Extended to `cursorInHoverZone() || (cursorInPillZone() && stage != .s0_idle)`.

### Refactored (simplify pass)
- Extracted `shouldShowMissedCard` computed property on `NotchState` — replaces duplicated S2B routing logic in `ScrollDepthHandler` and `stageFor()`
- Replaced `filter().isEmpty` with `contains(where:)` on the hot scroll path (eliminates array allocation)
- Used `transitionWith(stage:progress:)` consistently instead of manually setting 3 progress values

---

## v0.7 — Adversarial Audit Visual (2026-04-13)

**Commit:** `e85fa37`

### Fixed
- **ADV-01 — Dual-layer shadow missing at S3**
  Added separate soft ambient shadow (starts at p=0.40) and hard contact shadow (starts at p=0.70) to `NotchRootView`.

- **ADV-02 — S3 task cards showed raw priority score "P=9.2"**
  Replaced with human-readable duration ("90m", "2h").

- **ADV-03 — S3 NOW·PREP "after:" showed current task, not next**
  Fixed the `after:` lookup to skip the current active task.

---

## v0.6 — Visual Audit (2026-04-13)

**Commit:** `d77a31d`

8 bugs fixed across all stages. See `FIXES.md` BUG-10 through BUG-17 for full details.

---

## v0.5 — Critical Boot Bugs (2026-04-13)

**Commit:** `80a8796`

### Fixed
- **BUG-01 — Notifications never appeared on screen**
  `enqueue()` called `transition(to: .s1a_notification)` but never set `displayProgress`. At `displayProgress=0` the pill is the same size as the physical notch — invisible.

- **BUG-02 — Alert file race condition**
  `FSEventWatcher` processed files before they were fully written. Fixed with atomic write: Python brain writes to `.alert_tmp.json`, then `rename()` to `alert_<id>.json`.

- Plus BUG-03 through BUG-09 — see `FIXES.md`.

---

## v0.4 (2026-03-30)

22 bugs across Swift, Python brain, and LaunchAgent config. See `FIXES.md` for details.

---

## v0.3 (2026-03-29)

Hover-still-open race condition fixed. Idle pill alignment with physical notch.

---

## v0.2 (2026-03-28)

Hover close race, stage hard-stops, opacity and size calibration.
