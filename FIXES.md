# Notchly v2 — Bug Fixes Log

Complete record of every bug found and fixed across all audit sessions (v0.2–v0.9).
Each entry explains **what broke**, **why it broke**, and **what the fix was**.

## Quick Reference

| Bug | File | Summary | Version |
|---|---|---|---|
| BUG-01 | NotchState.swift | Notifications invisible — `displayProgress` never set in `enqueue()` | v0.5 |
| BUG-02 | FSEventWatcher.swift | Alert race condition — file read before fully written | v0.5 |
| BUG-03–09 | various | Swipe physics, timer sync, hotkey progress, shadow, S2B routing | v0.5–v0.6 |
| BUG-10–17 | various | 8 visual audit bugs — stage content, animations, layout | v0.6 |
| ADV-01 | NotchRootView.swift | Dual-layer shadow missing at S3/S4 | v0.7 |
| ADV-02 | Stage3View.swift | Task cards showed raw "P=9.2" score instead of duration | v0.7 |
| ADV-03 | Stage3View.swift | `after:` label showed current task not next | v0.7 |
| BUG-18 | NotchState.swift | Alert storm — alerts 2–N dropped (no pending queue) | v0.8 |
| BUG-19 | FSEventWatcher.swift | Malformed JSON crashed watcher — now routed to `alerts/error/` | v0.8 |
| BUG-20 | Stage1AView.swift | Diagnosis mode immediately overridden by `collapse()` | v0.8 |
| BUG-21 | EVRUpdater.swift | Dead no-op ternary `signal > 0 ? signal : signal` | v0.8 |
| BUG-22 | DiagnosisMode.swift | `handleWrongTime()` — rescheduled task never saved to queue | v0.8 |
| BUG-23 | HoverZoneMonitor.swift | Hover never triggered S1.5 — no entry detection existed | v0.8 |
| BUG-24 | HoverZoneMonitor.swift | Collapse fired on lower half of expanded pill — zone too small | v0.8 |
| BUG-25 | ScrollDepthHandler.swift | Scroll-back from inside pill blocked — outer guard too narrow | v0.8 |
| BUG-A | ScrollDepthHandler.swift | Async guards still narrow — pill-zone scroll dropped after BUG-25 fix | v0.9 |
| BUG-D | ScrollDepthHandler.swift | `phase == .began` reset accumulator to 0 — collapsed pill on new gesture | v0.9 |

---

---

## BUG-01 · Notifications never appeared on screen (Stage 1A invisible)

**File:** `Sources/State/NotchState.swift` — `enqueue()`

**Symptom:** Alert files were processed and moved to `processed/` but nothing was ever shown on screen. The pill stayed notch-sized (32pt tall).

**Root cause:** `enqueue()` called `transition(to: .s1a_notification)` but never set `displayProgress`. `NotchlyLayout(progress:)` uses `displayProgress` to compute pill width and height. At `displayProgress=0`, the pill is exactly notch-sized (162×32pt) — identical to the hardware camera cutout — so all content was hidden behind it.

**Fix:**
```swift
// Before (broken):
func enqueue(_ notification: NotchNotification) {
    if stage == .s0_idle || stage == .s1_5_hover {
        currentNotification = notification
        transition(to: .s1a_notification)  // displayProgress still 0 → invisible
    }
}

// After (fixed):
func enqueue(_ notification: NotchNotification) {
    if stage == .s0_idle || stage == .s1_5_hover {
        currentNotification = notification
        rawProgress     = 0.15
        displayProgress = 0.15  // pill expands to 300×108pt → content visible
        scrollProgress  = 0.15
        transition(to: .s1a_notification)
    }
}
```

---

## BUG-02 · Alert file race condition — FSEvent fires before content is written

**File:** `Sources/Watchers/AlertWatcher.swift` (runtime behaviour), `~/notchly/v2/alerts/`

**Symptom:** Alerts written with shell heredoc (`cat > file << 'EOF'`) were silently discarded. `enqueue()` was never called.

**Root cause:** Shell heredoc writes in two steps:
1. `open()` / truncate → FSEvent fires immediately on file creation
2. Write content → happens milliseconds later

`AlertWatcher`'s `DispatchSource` fires on step 1 (empty file). `JSONDecoder` fails on empty content. The file is moved to `processed/` without ever calling `enqueue()`.

**Fix:** Write alerts **atomically** — write to a `.tmp` file first, then `os.rename()` to the final name. `rename()` is atomic on the same filesystem; the FSEvent fires only after the file is complete.

```python
# Broken (shell heredoc / direct write):
# cat > ~/notchly/v2/alerts/alert_001.json << 'EOF'
# { ... }
# EOF

# Fixed (atomic rename):
import json, os
alert = { ... }
base = os.path.expanduser('~/notchly/v2/alerts')
tmp  = os.path.join(base, '.alert_tmp.json')
dest = os.path.join(base, 'alert_001.json')
with open(tmp, 'w') as f:
    json.dump(alert, f)
os.rename(tmp, dest)  # atomic — FSEvent fires with complete file
```

**Rule for all future alert writers (Python brain, test scripts, etc.):** Always use `os.rename()` from a `.tmp` file. Never write directly to the final filename.

---

## BUG-03 · Stage 1B timer — pill stays invisible

**File:** `Sources/State/NotchState.swift` — `startTimer(for:)`

**Symptom:** Starting a task timer via `startTimer()` transitioned to `.s1b_timer` but the pill stayed notch-sized.

**Root cause:** Same as BUG-01 — `displayProgress` was never set before the stage transition.

**Fix:**
```swift
func startTimer(for task: NotchTask) {
    activeTimerTask = task
    timerSecondsLeft = task.estimatedMinutes * 60
    timerIsPaused = false
    withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
        rawProgress     = 0.15   // added
        displayProgress = 0.15   // added
        scrollProgress  = 0.15   // added
    }
    transition(to: .s1b_timer)
}
```

---

## BUG-04 · ⌘⇧Space hotkey opened invisible chat (Stage 4 pill stayed notch-sized)

**File:** `Sources/Gestures/HotKeyManager.swift` — global and local monitors

**Symptom:** Pressing ⌘⇧Space transitioned to `.s4_chat` but the pill didn't expand. The chat UI was invisible.

**Root cause:** Both the global and local ⌘⇧Space handlers only set `scrollProgress = 1.0`, leaving `rawProgress` and `displayProgress` at their previous values (often 0). `NotchlyLayout` uses `displayProgress`, so the pill stayed at whatever size it was before.

**Fix:** Set all three progress values:
```swift
// Before (broken):
withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
    state.scrollProgress = 1.0   // displayProgress unchanged → invisible
}

// After (fixed):
withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
    state.rawProgress     = 1.0
    state.displayProgress = 1.0
    state.scrollProgress  = 1.0
}
```

---

## BUG-05 · ⌘Space toggle to S3 used wrong progress value

**File:** `Sources/Gestures/HotKeyManager.swift` — local ⌘Space handler

**Symptom:** ⌘Space from an expanded stage transitioned to `.s3_dashboard` but set `scrollProgress = 0.75`, slightly outside the canonical S3 value (0.70). The layout would render at the wrong size.

**Fix:**
```swift
// Before:
withAnimation(...) { state.scrollProgress = 0.75 }

// After:
withAnimation(...) {
    state.rawProgress     = 0.70
    state.displayProgress = 0.70
    state.scrollProgress  = 0.70
}
```

Also removed a spurious `withAnimation { state.scrollProgress = 0 }` before `state.collapse()` in the S3→collapse branch (collapse() already animates internally).

---

## BUG-06 · Stage 3 double-tap to chat — pill stayed S3-sized

**File:** `Sources/UI/Stages/Stage3View.swift` — double-tap gesture

**Symptom:** Double-tapping the dashboard transitioned to `.s4_chat` but the pill stayed at S3 geometry (0.70 progress).

**Root cause:** The `TapGesture(count: 2)` handler called `state.transition(to: .s4_chat)` without setting `displayProgress = 1.0`.

**Fix:**
```swift
.gesture(TapGesture(count: 2).onEnded {
    withAnimation(Springs.expand) {
        state.rawProgress     = 1.0
        state.displayProgress = 1.0
        state.scrollProgress  = 1.0
    }
    state.transition(to: .s4_chat, spring: Springs.expand)
})
```

---

## BUG-07 · Stage 3 timeline always empty

**File:** `Sources/UI/Stages/Stage3View.swift` — `todayTimelineItems`

**Symptom:** The "TODAY" timeline card in the dashboard was always blank.

**Root cause:** `todayTimelineItems` was stubbed out as `return []`.

**Fix:** Implemented properly — reads `state.taskQueue`, maps tasks with `scheduledStart` to `TimelineItem`:
```swift
private var todayTimelineItems: [TimelineItem] {
    let fmt = DateFormatter()
    fmt.dateFormat = "h:mm a"
    let now = Date()
    return state.taskQueue.prefix(6).compactMap { task -> TimelineItem? in
        guard let start = task.scheduledStart else { return nil }
        let isCurrent = start <= now && (task.deadline.map { $0 >= now } ?? true)
        return TimelineItem(
            time: fmt.string(from: start),
            label: task.title,
            type: task.category.rawValue,
            isDone: task.isCompleted,
            isCurrent: isCurrent
        )
    }
}
```

---

## BUG-08 · Onboarding fires every launch + opens invisible

**File:** `Sources/App/AppDelegate.swift` — `showOnboarding()` + missing `import SwiftUI`

**Symptom:** On every app launch the pill would try to show the onboarding chat, but appeared invisible (pill stayed notch-sized).

**Root cause (two parts):**
1. `notchly_setup_complete` UserDefaults key was never written, so `showOnboarding()` fires every launch.
2. `showOnboarding()` called `transition(to: .s4_chat)` without setting `displayProgress = 1.0`.
3. `AppDelegate.swift` was missing `import SwiftUI`, causing `withAnimation` to fail at compile time (was `import AppKit` only).

**Fix:**
```swift
// AppDelegate.swift — added:
import SwiftUI  // needed for withAnimation

private func showOnboarding() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let state = NotchState.shared
        withAnimation(.spring(response: 0.50, dampingFraction: 0.88)) {
            state.rawProgress     = 1.0
            state.displayProgress = 1.0
            state.scrollProgress  = 1.0
        }
        state.transition(to: .s4_chat, spring: Springs.expand)
    }
}
```

To suppress onboarding during development/testing:
```bash
defaults write -g notchly_setup_complete -bool true
```

---

## BUG-09 · Swipe nudge was invisible — `Color.clear.offset(x:)` 

**File:** `Sources/UI/Stages/Stage1AView.swift` — `swipeAffordanceNudge` + `nudgeOffset`

**Symptom:** The first-time swipe hint (left/right nudge animation) had no visible indicator. Users had no affordance showing them they could swipe.

**Root cause:** `swipeAffordanceNudge` returned `Color.clear.offset(x: nudgeOffset)` — a transparent view. The nudge animated but nothing was drawn. Also, `nudgeOffset` was applied to the `Color.clear` view instead of the whole pill.

**Fix:**
1. Replaced `Color.clear` with actual directional arrow text:
```swift
private var swipeAffordanceNudge: some View {
    HStack {
        Text("←").font(.system(size: 10, weight: .light)).foregroundColor(.white.opacity(0.20))
        Spacer()
        Text("→").font(.system(size: 10, weight: .light)).foregroundColor(NT.green.opacity(0.35))
    }
    .padding(.horizontal, 14)
    .offset(y: NotchDimensions.shared.notchH + 6)
}
```

2. Moved `nudgeOffset` to the whole pill view:
```swift
.frame(width: pillWidth, height: pillH)
.offset(x: nudgeOffset)   // was on Color.clear, now on whole view
.animation(Springs.hoverExpand, value: isHovered)
```

3. Increased nudge magnitude: `±10` → `±12`

---

## BUG-10 · HotKeyManager accessibility path missing displayProgress

**File:** `Sources/Gestures/HotKeyManager.swift` — `checkAccessibilityPermission()`

**Symptom:** On first launch when accessibility is not granted, the accessibility prompt handler called `transition(to: .s4_chat)` without setting displayProgress. Pill stayed notch-sized.

**Fix:**
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    if !UserDefaults.standard.bool(forKey: "notchly_setup_complete") {
        let state = NotchState.shared
        withAnimation(.spring(response: 0.50, dampingFraction: 0.88)) {
            state.rawProgress     = 1.0
            state.displayProgress = 1.0
            state.scrollProgress  = 1.0
        }
        state.transition(to: .s4_chat, spring: Springs.expand)
    }
}
```

---

## BUG-11 · Continuity message "loading loading" — wrong nextTask lookup

**Files:** `Sources/UI/Stages/Stage1AView.swift`, `Sources/UI/Stages/Stage2AView.swift`

**Symptom:** After clicking Done/Skip, the continuity banner showed "3D Modelling Assignment done · loading loading" (double "loading") instead of "… · Lunch Break up next".

**Root cause (two parts):**
1. `nextTaskLabel()` in Stage1AView returned `state.taskQueue.first?.title ?? "loading"` — when the queue was empty (world state not yet loaded), it returned `"loading"` and the message format `"\(title) done · \(nextLabel()) loading"` produced "loading loading".
2. `nextTaskLabel()` also returned the CURRENT task itself (first in queue) instead of the next different task.

**Fix:**
```swift
// Stage1AView + Stage2AView:
private func nextTaskLabel() -> String {
    state.taskQueue.first(where: { !$0.isCompleted && $0.title != notification?.title })?.title ?? ""
}

private func continuityMessage(...) -> String {
    let next = nextTaskLabel()
    return next.isEmpty ? "\(notif.title) done" : "\(notif.title) done · \(next) up next"
}
```

---

## BUG-12 · Stage 4 chat messages from BridgeWatcher never displayed

**File:** `Sources/UI/Stages/Stage4View.swift`

**Symptom:** Python brain replies injected via `~/notchly/v2/bridge/response.json` were processed by `BridgeWatcher` and stored in `state.chatMessages`, but Stage4View showed an empty chat.

**Root cause:** Stage4View had `@State private var messages: [ChatMessage] = []` — its OWN local array. It never observed `state.chatMessages`. `BridgeWatcher` appends to `state.chatMessages`. The two arrays were completely disconnected.

**Fix:** Remove the local `messages` array. Replace all references with `state.chatMessages`, `state.chatIsPinned`, and `state.aiIsThinking`.

---

## BUG-13 · Stage 3 double-tap gesture had no hit area in hover zone

**File:** `Sources/UI/Stages/Stage3View.swift`

**Symptom:** Double-tapping the S3 pill while mouse was in the hover zone (top 85pt of screen) never triggered the S4 transition. The TapGesture fired only within the content area, which starts 50pt below the notch — below the hover zone.

**Root cause:** The VStack had `.padding(.top, notchH + 12)` = 50pt. Without `.contentShape(Rectangle())`, the padding area has no hit-testing surface. Mouse was in hover zone (< 85pt from top) but content starts at 50pt, so the tap landed in dead space.

**Fix:**
```swift
.contentShape(Rectangle())   // added before .gesture(...)
.gesture(TapGesture(count: 2).onEnded { ... })
```

---

## BUG-14 · Stage 2A "next" label shows current task, displays debug P= value

**File:** `Sources/UI/Stages/Stage2AView.swift`

**Symptom:** ROW 3 showed "next: 3D Modelling Assignment · P=9.2" — the SAME task as current, with a raw priority debug label.

**Root cause:** `state.taskQueue.first` returns the first task in the queue, which is the current task itself.

**Fix:** Skip the current task ID when finding next:
```swift
private var nextTask: NotchTask? {
    let currentId = state.currentTask?.id
    return state.taskQueue.first(where: { !$0.isCompleted && $0.id != currentId })
}
```
Also removed the `· P=\(...)` debug string from the label.

---

## BUG-15 · S2B (missed panel) never triggered — routing dead code

**File:** `Sources/Gestures/ScrollDepthHandler.swift`

**Symptom:** Scrolling to 0.40 progress always showed S2A (NowCard), never S2B (missed panel). S2B was unreachable.

**Root cause:** `updateStage()` and `stageFor()` always returned `.s2a_nowcard` for `p >= 0.40`, with no condition to choose S2B.

**Fix:** Route to S2B when there is no active task but there are missed items:
```swift
else if p >= 0.40 {
    let hasCurrent = state.currentTask != nil || !state.taskQueue.filter({ !$0.isCompleted }).isEmpty
    let hasMissed  = !state.missedNotifications.isEmpty || state.pulseMissedCount > 0
    target = (!hasCurrent && hasMissed) ? .s2b_missed : .s2a_nowcard
}
```

---

## BUG-16 · S2B "MISSED · 0" when count comes from pulseMissedCount

**File:** `Sources/UI/Stages/Stage2BView.swift`

**Symptom:** S2B showed "MISSED · 0" even when `pulseMissedCount = 2` from world state.

**Root cause:** Count display only used `state.missedNotifications.count` (local array). `pulseMissedCount` from the Rust Pulse bridge was ignored.

**Fix:**
```swift
Text("MISSED · \(max(state.missedNotifications.count, state.pulseMissedCount))")
```

---

## BUG-17 · WorldStateReader silently skips reload if generated_at < lastTS

**File:** `Sources/Brain/Scheduler.swift` — `reload()`

**Root cause (discovered during testing):** `reload()` guards: `world.generatedAt > lastTS`. If a test script writes a `generated_at` from the past (e.g., `1744560000` = April 2025 while system clock is April 2026), the reload is silently skipped.

**Rule for all world state writers:** Always use `time.time()` (current timestamp) for `generated_at`. Never hardcode a timestamp.

---

---

## ADV-01 · Single-layer shadow replaced with dual-layer system

**Files:** `Sources/App/NotchWindowController.swift`, `Sources/UI/NotchRootView.swift`

**Symptom:** At S3/S4, pill shadow looked flat — one blurry ring with no depth separation. Failed adversarial shadow audit.

**Root cause:** A single combined `.shadow()` modifier blended both ambient and contact shadows into one pass. No layering meant no depth gradient as the pill expanded.

**Fix:** Split into two independent shadow layers:
- **Soft ambient** (large, diffuse): opacity 0.18×t, radius 0→12, y 0→6; starts at p=0.40 (S2A)
- **Hard contact** (tight, crisp): opacity 0.22×t, radius 0→4, y 0→2; starts at p=0.70 (S3)

```swift
.shadow(color: .black.opacity(layout.shadowSoftOpacity), radius: layout.shadowSoftRadius, y: layout.shadowSoftY)
.shadow(color: .black.opacity(layout.shadowHardOpacity), radius: layout.shadowHardRadius, y: layout.shadowHardY)
```

Each shadow channel uses `smoothstep` for perceptually linear fade-in.

---

## ADV-02 · S3 task cards showed raw debug label "P=5.2"

**File:** `Sources/UI/Stages/Stage3View.swift` — `tasksCard`

**Symptom:** Each task row in the S3 dashboard showed `P=5.2` (raw `pFinal` priority float) instead of meaningful data.

**Root cause:** Debug label `Text("P=\(String(format: "%.1f", task.pFinal))")` was left in the task row.

**Fix:** Replaced with task duration in minutes:
```swift
Text("\(task.estimatedMinutes)m")
```

---

## ADV-03 · S3 "after:" card showed current task as next task

**File:** `Sources/UI/Stages/Stage3View.swift` — `nowPrepCard`

**Symptom:** The NOW·PREP card showed "after: 3D Modelling Assignment" even when 3D Modelling was the current task.

**Root cause:** `state.taskQueue.first` returned the first task regardless of whether it was already the current task.

**Fix:**
```swift
if let next = state.taskQueue.first(where: { !$0.isCompleted && $0.id != state.currentTask?.id }) {
    Text("after: \(next.title)")
}
```

---

---

## BUG-18 · Multi-alert storm — alerts 2-N silently dropped

**File:** `Sources/State/NotchState.swift` — `enqueue()`

**Symptom:** Dropping 10 alerts atomically showed only the first. Alerts 2-10 were silently discarded.

**Root cause:** `enqueue()` only accepted notifications when `stage == .s0_idle || .s1_5_hover`. After alert 1 set the stage to `.s1a_notification`, every subsequent call was a no-op.

**Fix:** Added `pendingNotificationQueue: [NotchNotification]`. When `enqueue()` is called while stage is `.s1a_notification`, the notification is buffered. `dismissCurrentNotification()` now pops the queue and shows the next one instead of collapsing.

---

## BUG-19 · Malformed JSON alert routed to `processed/` instead of `error/`

**Files:** `Sources/App/DirectorySetup.swift`, `Sources/DataSources/FSEventWatcher.swift`

**Symptom:** Dropping a JSON file with a syntax error caused `AlertWatcher` to move it to `alerts/processed/`. It was indistinguishable from successfully handled alerts — could not be debugged.

**Root cause:** `AlertWatcher` had one destination — `moveToProcessed()` — for both success and decode failure paths.

**Fix:** Added `DirectorySetup.alertsError = alerts/error/`. Created the directory in `createAll()`. Decode failures now call `moveToError()` instead.

---

## BUG-20 · Diagnosis stage immediately overridden by `dismissCurrentNotification()`

**File:** `Sources/UI/Stages/Stage1AView.swift` — `performLeft()`

**Symptom:** After skipping a task 3 times, the pill never showed the diagnosis view. Stage `.s1_5x_diagnosis` was set by `BDIAgent.checkDiagnosisMode()` and immediately overridden back to `.s0_idle` by the very next line.

**Root cause:** `performLeft()` always called `state.dismissCurrentNotification()` after `checkDiagnosisMode()`. `dismissCurrentNotification()` calls `collapse()` which sets `stage = .s0_idle`, wiping the diagnosis transition.

**Fix:**
```swift
if state.stage == .s1_5x_diagnosis {
    state.clearNotificationForDiagnosis()   // clears notif, does NOT collapse
} else {
    state.dismissCurrentNotification()
}
```
Also added `clearNotificationForDiagnosis()` to `NotchState` — clears `currentNotification` and `pendingNotificationQueue` without calling `collapse()`.

---

## BUG-21 · EVRUpdater — dead no-op ternary in bandit reward

**File:** `Sources/Learning/EVRUpdater.swift` — `updateW()`

**Symptom:** Code review: `reward: signal > 0 ? signal : signal` — both branches identical, ternary never has any effect.

**Root cause:** Dead code. The ternary was likely a placeholder for clipping negative rewards to 0, but both branches were written as `signal`.

**Fix:** Removed ternary, pass `signal` directly (negative signals correctly decrease Q-values in the bandit update formula).

---

## BUG-22 · `DiagnosisMode.handleWrongTime()` — rescheduled task never saved

**File:** `Sources/Safeguards/DiagnosisMode.swift` — `handleWrongTime()`

**Symptom:** Tapping "Wrong time" in the diagnosis pill showed the continuity banner "Moved to next peak energy window" but the task's `scheduledStart` was not actually updated. Next time the queue ran, the task still had its original time.

**Root cause:** The `!found` branch (no peak slot today → move to tomorrow) created a local `var t2 = task` and set its `scheduledStart`, but `t2` went out of scope immediately. The actual `t` variable (which is written back to the queue) was never updated in this branch.

**Fix:** Removed `t2`. Both branches (`found` and `!found`) now update `t.scheduledStart`. After the branch, `t` is written back to `state.taskQueue` by index.

---

## BUG-A · ScrollDepthHandler async guards check only trigger zone, not full pill

**File:** `Sources/Gestures/ScrollDepthHandler.swift` — `handle()` and `finalizeScroll()`

**Symptom:** After BUG-25 fix, scrolling while cursor is in the lower part of the pill (below the 85pt trigger zone) still didn't work. Progress values never updated even though the outer guard correctly passed — the async blocks re-checked only `cursorInHoverZone()` and immediately bailed.

**Root cause:** Three `DispatchQueue.main.async` blocks all contained `guard HoverZoneMonitor.shared.cursorInHoverZone() else { return }`. BUG-25 fixed the *outer* guard to allow pill-zone scrolling but forgot to update these inner async guards. At S3 the dead zone between trigger bottom and pill bottom is 222pt — cursor in that range hit the outer guard OK but was immediately dropped by the async guard.

**Fix:** All three async guards updated to:
```swift
guard monitor.cursorInHoverZone() || (monitor.cursorInPillZone() && state.stage != .s0_idle) else { return }
```

---

## BUG-D · ScrollDepthHandler `.began` resets accumulator to 0, collapses pill

**File:** `Sources/Gestures/ScrollDepthHandler.swift` — `handle()`, `phase == .began` block

**Symptom:** When starting a new trackpad gesture while pill is at S3 (or any expanded stage), the pill immediately collapsed to S0 on the very first event.

**Root cause:** `phase == .began` reset `accumulator = 0`. But `rawP = accumulator / 200.0` — with accumulator at 0, rawP=0, which maps to S0. `updateStage()` immediately hard-stopped to S0 and collapsed the pill.

At S3, accumulator should be ~140 (= 0.70 × 200). Resetting it to 0 discarded the entire scroll position on every new gesture start.

**Fix:**
```swift
// Before (broken):
accumulator = 0

// After (fixed):
// Seed from current rawProgress so gesture continues from wherever the pill is
accumulator = NotchState.shared.rawProgress * 200.0
```

---

## Verified Working After Fixes v0.9 (scroll + boundary audit)

| Feature | Test method | Result |
|---|---|---|
| Scroll from inside pill at S3 | Scroll up/down while cursor in lower pill area (below 85pt trigger) | ✅ Progress updates — BUG-A fixed |
| New gesture at S3 doesn't collapse | Start fresh trackpad gesture while at S3 | ✅ Pill stays at S3 — BUG-D fixed |
| Scroll-back to S0 from S3 | Scroll up all the way, then scroll down | ✅ Returns to S0 cleanly |
| Scroll-up all the way to S4 | Scroll down from S0 past all stages | ✅ Passes S1.5→S2→S3→S4 with hard-stops |
| No limbo stage on scroll-back | Scroll to S3, cursor stay in pill, scroll back | ✅ Snaps to correct stage, no orphan progress |
| Hard-settle fires correctly | Scroll to S3, release, wait 500ms | ✅ Geometry locks to canonical 0.70 |
| Boundary box: trigger zone | Cursor at notch, off center | ✅ 85pt × 450pt narrow zone triggers entry |
| Boundary box: pill zone at S3 | Cursor at lower pill edge | ✅ 307pt × 558pt zone keeps pill alive |
| App compiles cleanly | `xcodebuild` | ✅ BUILD SUCCEEDED |
| All previous v0.7 checks | Re-run | ✅ No regressions |

---

## Verified Working After Fixes v0.7 (adversarial audit)

| Feature | Test method | Result |
|---|---|---|
| Dual-layer shadow at S3 | Scroll to p=0.70, inspect shadow | ✅ Soft ambient + hard contact both visible |
| Shadow absent at S0–S1 | Stay at idle/hover, inspect | ✅ No shadow at p < 0.40 |
| S3 task cards show duration | Open dashboard | ✅ "90m" shown instead of "P=9.2" |
| S3 NOW·PREP "after:" skips current | Open dashboard with active task | ✅ Shows next different task |
| S2B routing with missed items | Empty queue + missed=2 + scroll | ✅ Routes to S2B, not S2A |
| S3 double-tap → S4 | Double-click in hover zone at S3 | ✅ Full S4 expansion with contentShape fix |
| Multi-alert storm (10 alerts) | Drop 10 atomic alert files | ✅ All buffered and shown in sequence |
| Malformed JSON alert | Drop invalid JSON in alerts/ | ✅ Moved to alerts/error/, not processed/ |
| Diagnosis mode after 3x skip | Skip same task 3 times | ✅ Diagnosis pill appears, not overridden |
| DiagnosisMode wrong-time reschedule | Tap "Wrong time" in diagnosis | ✅ Task scheduledStart updated in queue |
| EVRUpdater bandit reward | Code audit | ✅ No-op ternary removed, signal passed directly |
| All previous v0.6 checks | Re-run | ✅ No regressions |
| App compiles cleanly | `xcodebuild` | ✅ BUILD SUCCEEDED |

---

## Testing Infrastructure Notes

### Alert injection (for testing/Python brain)
Always write atomically:
```python
import json, os
def write_alert(alert: dict, alerts_dir: str):
    tmp  = os.path.join(alerts_dir, '.alert_tmp.json')
    name = f"alert_{alert['id']}.json"
    dest = os.path.join(alerts_dir, name)
    with open(tmp, 'w') as f:
        json.dump(alert, f)
    os.rename(tmp, dest)
```

### Alert JSON schema
```json
{
  "id": "unique-string",
  "title": "Task Title",
  "subtitle": "context text",
  "type": "task|meal|class_",
  "task_id": null,
  "priority": 8.0,
  "left_action": "Skip",
  "right_action": "Done",
  "expire_at": null
}
```

### Quartz button coordinates (built-in MBP display, external monitor on left)
- Pill center X: **3316** (Quartz)
- Done button: **(3416, 546)**
- Skip button: **(3216, 546)**
- Hover zone center: **(3316, 490)**

### displayProgress canonical values
| Stage | Progress | Pill size (approx) |
|---|---|---|
| s0_idle | 0.00 | 162 × 32 pt (notch-sized, invisible) |
| s1_5_hover | 0.12 | 276 × 102 pt |
| s1a_notification / s1b_timer | 0.15 | 300 × 108 pt |
| s2a_nowcard / s2b_missed | 0.40 | 443 × 162 pt |
| s3_dashboard | 0.70 | 511 × 287 pt |
| s4_chat | 1.00 | 520 × 362 pt |

**Rule:** Any code that transitions to a new stage MUST also set `rawProgress`, `displayProgress`, AND `scrollProgress` to that stage's canonical value. Setting only one or two of the three will cause geometry/state divergence.
