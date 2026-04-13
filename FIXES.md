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

## Verified Working After Fixes (tested live)

| Feature | Test method | Result |
|---|---|---|
| Stage 1A notification appears | Atomic alert write → screencapture | ✅ Pill expands, title + subtitle visible |
| Stage 1A hover expands | CGEvent mouse move to hover zone | ✅ Skip + Done buttons appear |
| Done button (right action) | Click at Quartz (3416, 546) | ✅ `action: swipe_right` logged in episodic.jsonl |
| Skip button (left action) | Click at Quartz (3216, 546) | ✅ `action: skip` logged in episodic.jsonl |
| Continuity banner | After Done click | ✅ Shows 4s then fades |
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
