# Notchly v2

A macOS AI productivity assistant that lives inside the MacBook notch. No Dock icon. No menu bar clutter. It grows out of the camera housing only when it needs your attention, then disappears.

---

## What it does

Notchly watches your calendar, active app, idle time, and personal energy model, then decides when to interrupt you with the exact task you should do next. You swipe right (done) or left (skip) in under a second. It learns your patterns and gets better over time.

The entire UI fits inside the physical notch at rest. It expands downward as a pill when needed. You can scroll to expand it manually through all stages at any time.

---

## Requirements

- macOS 13+ on a MacBook Pro with a notch (2021+)
- Xcode 15+
- Python 3.11+ (for the AI brain bridge — optional, app works without it)
- Accessibility permission (for global event monitors)
- Calendar permission (for schedule reading)

---

## Build & Run

```bash
git clone https://github.com/saikiran9185/notchly_v2.git
cd notchly_v2
xcodebuild -scheme NotchlyV2 -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/NotchlyV2.app
```

Grant Accessibility permission when prompted. The pill will appear above the physical notch.

---

## Architecture

```
notchly_v2/
├── Sources/
│   ├── App/              # Entry point, window controller, dimensions, math helpers
│   ├── State/            # NotchState (ObservableObject), stage enum, task/notification models
│   ├── UI/               # SwiftUI views for all 8 stages + components
│   │   ├── Stages/       # Stage0–Stage4 views (S0, S1.5, S1A, S1B, S2A, S2B, S3, S4)
│   │   └── Components/   # Shared: ActionButton, SwipeCardView, ContinuityBanner, etc.
│   ├── Gestures/         # HoverZoneMonitor, ScrollDepthHandler, SwipeGestureHandler, HotKeys
│   ├── Brain/            # BDIAgent, ContextEngine, EnergyModel, PriorityScorer, Scheduler
│   ├── DataSources/      # AppFocusMonitor, CalendarReader, FSEventWatcher, IdleDetector
│   ├── Learning/         # EVRUpdater, ContextualBandit, EpisodicLog, WeeklyRebuilder
│   ├── Memory/           # WorkingMemory, SemanticProfile, RelationshipMemory
│   ├── Safeguards/       # DiagnosisMode, BurnoutPill, FocusMode, MorningGate, GlassBreak
│   └── Bridge/           # BridgeWatcher (Python brain IPC), TaskStore, WorldStateReader
├── FIXES.md              # Full bug log — every bug found and fixed with root cause + fix
├── MANUAL.md             # End-user manual — all stages, gestures, hotkeys
└── MASTER_PROMPT.md      # AI context — how to prompt the Python brain
```

---

## Stage System

The pill has 8 stages driven by a single `displayProgress` value (0.0–1.0).

| Stage | Progress | Size (pt) | Description |
|---|---|---|---|
| S0 idle | 0.00 | 162 × 32 | Invisible — same size as camera notch |
| S1.5 hover | 0.12 | ~186 × 102 | Hover preview — pill expands on cursor entry |
| S1A notification | 0.15 | ~200 × 108 | Alert bar — swipe right/left to act |
| S1B timer | 0.15 | ~200 × 108 | Countdown for active task |
| S2A now-card | 0.40 | ~280 × 162 | Current task card with context |
| S2B missed | 0.40 | ~280 × 162 | Missed alerts panel |
| S3 dashboard | 0.70 | ~380 × 287 | Full task list + energy bar |
| S4 chat | 1.00 | ~520 × 362 | AI chat interface |

**Critical rule:** Any code transitioning to a new stage MUST set `rawProgress`, `displayProgress`, AND `scrollProgress` to that stage's canonical value. Use `state.transitionWith(stage:progress:)` — never set them individually.

---

## Key Files

### `Sources/State/NotchState.swift`
The single source of truth. `@Published` ObservableObject shared across all views via `.environmentObject`. Key methods:
- `transitionWith(stage:progress:)` — sets all 3 progress layers + animates stage change
- `collapse()` — returns to S0, resets all progress, resets scroll accumulator
- `enqueue(_:)` — adds a notification; buffers into `pendingNotificationQueue` if already showing one
- `showContinuity(_:)` — shows a 4-second banner with feedback text

### `Sources/App/NotchWindowController.swift`
Creates the `NSPanel` at `statusWindow + 2` level and positions it centered on the notch screen. Also contains `NotchDimensions` (cached screen metrics), `NotchlyLayout` (all pill geometry from progress), and `NotchMath` helpers.

### `Sources/Gestures/HoverZoneMonitor.swift`
Two detection zones:
- **Trigger zone** (85 × 450 pt) — narrow strip at top of screen. Entering this from S0 triggers S1.5.
- **Pill zone** — full pill rectangle computed from current `displayProgress`. Keeps the pill alive when cursor is anywhere inside the expanded pill, not just the narrow trigger strip.

Safety poll every 100ms via `Timer` catches cursor exits that `mouseMoved` events miss.

### `Sources/Gestures/ScrollDepthHandler.swift`
Translates trackpad/mouse scroll into continuous `rawProgress` (0.0–1.0). Key behaviors:
- Hard-stops at stage boundaries: when crossing a threshold, accumulator is reset to `canonical × 200` and progress is locked to the canonical value.
- `phase == .began` seeds the accumulator from `rawProgress × 200` so new gestures continue from the current pill position (not from 0).
- Async guards check both trigger zone AND pill zone so scroll works anywhere inside the expanded pill.

### `Sources/Safeguards/DiagnosisMode.swift`
When a task is skipped 3+ times (`rejectionCount >= 3`), this shows a special "Task Purgatory" pill (S1.5x) with 3 vertical buttons: Too big / Wrong time / Not needed.

---

## Gesture & Interaction Map

```
Hover into notch area  →  S0 → S1.5 (hover preview)
Scroll down            →  S0 → S1.5 → S2A → S3 → S4 (one fluid motion)
Scroll up              →  Any stage → collapse back to S0
Leave pill area        →  Collapse to S0 (after short debounce)
Swipe right in S1A     →  Primary action (Done / Going now)
Swipe left in S1A      →  Skip (increments rejectionCount)
Double-tap at S3       →  S3 → S4 (open chat)
Press Y hotkey         →  Same as swipe right
```

---

## Alert Injection (for testing and Python brain)

The Python brain delivers notifications by writing JSON files atomically:

```python
import json, os

def inject_alert(alert: dict, alerts_dir: str = "~/notchly/v2/alerts"):
    alerts_dir = os.path.expanduser(alerts_dir)
    tmp  = os.path.join(alerts_dir, ".alert_tmp.json")
    dest = os.path.join(alerts_dir, f"alert_{alert['id']}.json")
    with open(tmp, "w") as f:
        json.dump(alert, f)
    os.rename(tmp, dest)   # atomic — FSEventWatcher sees this in one event
```

Alert JSON schema:
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

Malformed JSON is automatically moved to `~/notchly/v2/alerts/error/` for inspection.

---

## Display Coordinates (Built-in Retina, external on left)

If your setup has an external monitor to the LEFT of the built-in:

| Value | Quartz (AppKit) | Notes |
|---|---|---|
| Built-in origin X | 2560 | External is 2560pt wide |
| Built-in midX | 3316 | Notch center |
| Built-in maxY | 982 | Top of screen in AppKit coords |
| Trigger zone | x: 3091–3541, y: 897–982 | 450 × 85 pt |
| Pill at S3 | x: 3037–3595, y: 675–982 | 558 × 307 pt |

For a single-display setup the midX will be 756 and the trigger zone shifts accordingly. `NotchDimensions.recalculate()` reads these from `NSScreen` on launch and on display change.

---

## Bug History Summary

| Version | Bugs Fixed | Key Changes |
|---|---|---|
| v0.2 | BUG-01–05 | Hover close race, stage hard stops, opacity calibration |
| v0.3 | BUG-06–09 | Idle pill alignment, hover-still-open race |
| v0.4 | BUG-10–17 | 22 bugs across Swift/Python/LaunchAgent |
| v0.5 | BUG-18 | Notifications invisible (displayProgress never set) |
| v0.6 | BUG-10–BUG-17 | 8 visual audit bugs |
| v0.7 | ADV-01–03 | Shadow layers, P= label, `after:` skip logic |
| v0.8 | BUG-18–22 | Alert storm buffer, malformed JSON routing, diagnosis never visible, reschedule bug, EVR dead ternary |
| v0.9 | BUG-23–25, A, D | Hover dead zone, collapse too early, scroll limbo, async guard pill zone, accumulator reset on gesture start |

Full details in `FIXES.md`.

---

## Learning System

Notchly adapts to your behavior using a contextual bandit (Thompson sampling):

- **EVR (Engagement Value Rating):** Each notification gets a reward signal based on whether you acted on it (primary = high reward), skipped it (low), or ignored it (penalty).
- **CAP Penalty:** Consecutive skips of the same type penalize that notification class's Q-value.
- **EpisodicLog:** Every interaction is timestamped and stored for weekly model rebuilding.
- **WeeklyRebuilder:** Sunday night, Q-values are recalculated from the past week's EpisodicLog.

---

## Safeguards

| Safeguard | Trigger | Action |
|---|---|---|
| DiagnosisMode | Task skipped 3× | Shows "Too big / Wrong time / Not needed" pill |
| BurnoutPill | Energy < 3 for 2+ hours | Blocks all non-critical interruptions |
| FocusMode | Y+Y double-press | 25-min Pomodoro, collapses pill |
| MorningGate | Lid open 6–10am | Morning briefing sequence |
| GlassBreak | Emergency override | Shows pill regardless of focus/burnout |
| InterruptionGuard | Class/meeting active | Delays non-urgent alerts until after |

---

## License

MIT — see individual source files for copyright notices.
