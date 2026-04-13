# Notchly v2 — Bug Fixes Log (v0.5)

This document records every bug found and fixed during the visual audit session.
Each entry explains **what broke**, **why it broke**, and **what the fix was**.

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

## Verified Working After Fixes v0.7 (adversarial audit)

| Feature | Test method | Result |
|---|---|---|
| Dual-layer shadow at S3 | Scroll to p=0.70, inspect shadow | ✅ Soft ambient + hard contact both visible |
| Shadow absent at S0–S1 | Stay at idle/hover, inspect | ✅ No shadow at p < 0.40 |
| S3 task cards show duration | Open dashboard | ✅ "90m" shown instead of "P=9.2" |
| S3 NOW·PREP "after:" skips current | Open dashboard with active task | ✅ Shows next different task |
| S2B routing with missed items | Empty queue + missed=2 + scroll | ✅ Routes to S2B, not S2A |
| S3 double-tap → S4 | Double-click in hover zone at S3 | ✅ Full S4 expansion with contentShape fix |
| All previous v0.6 checks | Re-run | ✅ No regressions |
| App compiles cleanly | `xcodebuild` | ✅ No errors |

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
