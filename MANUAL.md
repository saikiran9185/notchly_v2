# Notchly v2 — Complete User Manual

A macOS AI personal assistant that lives in your MacBook notch.
No Dock icon. No menu bar icon. It just lives there.

---

## How it works in one sentence

Notchly watches your calendar, active app, idle time, and energy level — then
tells you exactly what to do next by growing out of the physical notch. You
respond with a swipe or a hotkey. It learns. You never need to open it.

---

## The Stages (what you see)

### Stage 0 — Idle (always)
A tiny dark pill drops below the physical notch camera housing.

| Dot colour | Meaning |
|---|---|
| No dot (invisible) | Deep focus — same app open > 20 min, no distractions |
| Dim red dot | You have missed alerts waiting |
| Dim white dot | Normal idle, nothing urgent |

**Nothing to do.** The pill will come alive when something needs your attention.

---

### Stage 1A — Notification Bar
Fires when the brain decides something needs your attention now.

```
┌─────────────────────────────────────────┐
│  ● Task name              · subtitle    │
│  ← [Skip]          [Done ✓] →          │
└─────────────────────────────────────────┘
```

- Bar grows down from the notch automatically
- Shows for **30 seconds** — if ignored, moves to Missed list
- Hover over it → hint text appears: `← skip  ·  done →`
- **Swipe right** → right action (Done / Going now / On my way)
- **Swipe left** → left action (Skip / Not now)
- **Press Y** → same as right action
- Auto-dismisses after 30s if untouched

---

### Stage 1B — Active Timer
Shows when a task timer is running.

```
┌─────────────────────────────────────┐
│  ● Task name           18:42        │
└─────────────────────────────────────┘
```

- Timer counts down live in `MM:SS` format
- **Tap the timer** → pause/resume (shows ⏸ when paused)
- **⌘E** → add 15 minutes
- When time's up: colour turns amber, buttons appear for Done or +15m
- **Never auto-dismisses** — persists until you act

---

### Stage 1.5 — Hover Peek (read only)
Move your cursor over the notch area.

```
┌──────────────────────────────────────┐
│  ● Task · 45m left · 60% done       │
│  next: Design review · 3pm          │
│  scroll ↓ to act                    │
└──────────────────────────────────────┘
```

- **No buttons.** Read only.
- Tells you: current task, time left, progress, what's next
- Scroll down 50pt → goes to NowCard (Stage 2A)
- Move cursor away → instantly collapses

---

### Stage 2A — NowCard (interactive)
Full task card with action buttons.

```
┌────────────────────────────────────────────┐
│  ⚡ Deep work task           2h 30m left   │
│  Figma project / UI redesign               │
│  ████████████░░░░░  65%                    │
│  next: Submit form · P=7.2                 │
│  [Not yet]     [Later]     [Done ✓]        │
└────────────────────────────────────────────┘
```

Triggered by:
- Clicking the Stage 1A bar
- Scrolling 50–120pt over the notch
- Dragging down from Stage 1.5

**Move cursor away → immediately collapses (no grace period)**

Button sets change by task type:

| Task type | Left | Center | Right |
|---|---|---|---|
| Task | Not yet | Later | Done ✓ |
| Meal | Skip | Done | Going now |
| Class | Skip | Later | On my way |
| Exercise | Skip today | Later | Starting now |
| Deadline | Move 8pm | +30m | Start now (red) |
| Break ending | 5 more min | Tomorrow | Back now |

---

### Stage 2B — Missed Notifications
If you ignored alerts, they collect here.

- Appears when cursor enters the zone AND missed items exist
- Shows last 2 missed alerts, newest first
- **Click any item** → expands with inline: [Done ✓] [Still needed] [Skip]
- **"see all ↓"** → opens Stage 3 dashboard
- **× button** → clear all missed

---

### Stage 3 — Full Dashboard
The complete day view.

```
┌─────────────────────────────────────────────────────┐
│  TODAY                    │  TASKS · tap ✓ to mark  │
│  9:00  ● Studio class     │  ○ Figma prototype  P8.4│
│  11:00 ▶ Deep work ◀      │  ○ Submit brief     P7.1│
│  1:00  ○ Lunch            │  ○ Reply emails     P4.2│
│  3:00  ○ Design review    │  ○ Read chapter     P3.8│
│─────────────────────────────────────────────────────│
│  NOW · PREP               │  DAY                    │
│  Figma · 18:42 remaining  │  3 done · 4 left        │
│  after: Submit form       │  energy: high            │
│─────────────────────────────────────────────────────│
│  ● double-tap to chat · add task · ask anything     │
└─────────────────────────────────────────────────────┘
```

Triggered by:
- Scroll > 120pt over notch
- **⌘Space** hotkey
- "see all ↓" from missed list

- **Tap ✓ circle** on any task → marks done with animation
- **Double-tap anywhere** → opens Stage 4 chat
- Move cursor away → immediately collapses

---

### Stage 4 — Chat (OpenClaw)
Full conversational AI. Purple accent — visually distinct from task UI.

Triggered by:
- **⌘⇧Space** — from ANY app, always works
- Double-click the notch (when not in Stage 1)
- Double-tap anywhere in Stage 3

```
┌─────────────────────────────────────────────────────┐
│  ✦ OpenClaw                          ⌘⇧Space    ✕  │
│─────────────────────────────────────────────────────│
│                           You: move figma to 4pm    │
│  Sure — moved to 4pm. Notion deadline still 6pm.    │
│  Want me to move the brief submission too?          │
│  [Yes, move it]        [No, keep it]                │
│─────────────────────────────────────────────────────│
│  ● ask anything · add task · reschedule...      ↩  │
└─────────────────────────────────────────────────────┘
```

**Session rules:**

| State | Behaviour |
|---|---|
| Action card unacknowledged | Pinned — cannot close by mouse-away |
| AI responding | Pinned — shown with "pinned · action pending" badge |
| Idle after conversation | 60s grace — move away and back within 60s, chat preserved |
| 60s expires | Chat clears, returns to idle |
| Opened via Stage 3 double-tap | No grace — closes immediately on mouse-away |

**Context Peek** — auto-appears when you type schedule keywords:
`move, tomorrow, reschedule, when, free, deadline, today, morning, evening`
Shows tomorrow's schedule so you can see free slots before rescheduling.

---

## All Gestures

### Two-finger scroll over the notch (trackpad)

| Scroll distance | Result |
|---|---|
| 0–20pt | Dead zone — nothing |
| 20–50pt | Stage 1.5 hover peek |
| 50–120pt | Stage 2A NowCard |
| > 120pt | Stage 3 Dashboard |
| Scroll UP | Collapse to idle from any stage |

### Swipe left / right (trackpad, in Stage 1A / 1B / 2A / 2B)

**Right swipe** = green wash builds → action = Done / Accept / Going now
**Left swipe** = gray wash builds → action = Skip / Not now / Dismiss

Physics:
- 1–39pt dragged: rubber-band, washes and button scales build gradually
- At 40pt: wash snaps to full, button text changes to "✓ confirmed" / "→ skip", haptic fires
- Release past 40pt or velocity > 200pt/s: card sucks into notch, action fires, banner appears
- Release before 40pt: snaps back with spring

**Left swipe is always warm grey — never red.** Red = danger. Grey = "not now, no judgment."

### First swipe ever
On first launch, the card does one affordance nudge: gently rocks right then left to show you what to do. Never shown again.

---

## Keyboard Hotkeys (work from any app)

| Hotkey | Action |
|---|---|
| **⌘⇧Space** | Open chat (Stage 4) — always works |
| **⌘Space** | Toggle dashboard (Stage 3) |
| **⌘D** | Mark current task done |
| **⌘S** | Skip current alert |
| **⌘L** | Move current task to later |
| **⌘E** | Add 15 minutes to active timer |
| **Y** | Primary action (right button) when notification visible |
| **Esc** | Collapse to idle from any stage |

---

## Continuity Banner

After every action, a small confirmation appears just below the notch for 4 seconds:

```
● Task done · Design review loading
● Skipped · Lunch loading
● Moved Figma to 4pm
● +15m added · 33m remaining
● Moved to tomorrow — postponed 3×
```

No sound. No bounce. Appears and fades quietly.

---

## The Priority Score (P)

Every task has a score from 0–10. The brain shows the highest-scoring task first.

```
P = Urgency×0.35 + Importance×0.25 + EnergyMatch×0.20 + ContextFit×0.15 + DeadlineMomentum×0.05
```

| Factor | What it measures |
|---|---|
| Urgency | How close the deadline is (exponential — 1h left → 8.6, 12h → 1.7) |
| Importance | P1 Urgent=10, P2 High=7, P3 Medium=4, P4 Low=1 |
| Energy Match | Your current energy vs what the task needs |
| Context Fit | Is the right app open? Are you in class? |
| Deadline Momentum | Builds pressure as deadline approaches (6h–72h window) |

You never see the formula. You just see the result.

---

## Self-Learning (4 invisible layers)

The app gets smarter every day. You never configure anything.

**Layer 1 — EVR confidence (W):**
Every notification type has a confidence weight. Primary tapped → W goes up. Ignored → W goes down. Below W=0.30 → shows every other time. Below W=0.10 → suppressed.

**Layer 2 — Context Bandit:**
Learns which actions you prefer in which contexts (hour of day, day of week, what's open). Adapts button placement after week 1.

**Layer 3 — CAP Penalty:**
New app = cautious. After 100 interactions = 70% confident. After 300 = 95%. Interruptions are suppressed more when the model is less certain.

**Layer 4 — ProActor Timing:**
After 2 weeks of data, shifts notification fire times toward when you actually respond. If you always respond to meal alerts at 8:10am, it fires at 8:10am.

**Every Sunday at 11pm:** full weekly rebuild using all your data.

---

## Behavioural Safeguards

### Task Purgatory (Diagnosis Mode)
If you skip or dismiss the same task 3 times, it reappears differently:
- Pill drops **40pt lower** than normal
- Background: warm grey (not black)
- Buttons stacked **vertically** (breaks muscle memory — forces conscious choice)
- Options: "Too big → split" / "Wrong time → move to peak" / "Not needed → remove"

### Glass Break (Emergency Override)
Hold **Option key** while a boundary/burnout alert is visible:
- One button transforms to **[Deadline Mode: Disable Sensors]** in red
- Disables all wellness checks until midnight
- For 11:59pm deadline crunch situations only

### Burnout Hard-Line
If AI detects burnout risk (too many hours + late night + deep work):
- Pill drops 40pt lower AND colours **invert** (red background, light text)
- Distinct from diagnosis mode (grey + vertical) — cannot be auto-clicked
- Forces conscious decision

### False Morning Gate
Morning briefing only fires if ALL THREE conditions are true:
1. Mac lid was opened (wake event)
2. Mac was idle for 5+ hours (you were sleeping)
3. Time is between 5am and 11am

3am YouTube sessions stay completely silent.

### Postpone 3× Auto-Reschedule
Postpone the same task 3 times → automatically moved to tomorrow 10am.
No confirmation. No dialog. Banner: "Moved [task] to tomorrow — postponed 3×"

### Focus Mode
Say "focus" or "back at [time]" in chat:
- Pill shows: "focus · back at 3pm"
- All non-urgent alerts silenced
- Queue resumes exactly where it left off

---

## Day Scenarios

### Morning (wakes 6–11am after 5h+ idle)
Greeted with time-aware message:
- 6am: "good morning · exercise window open · breakfast at 8:30"
- 8am: "late start · breakfast closing in 15m · 3 tasks today"
- 9am: "class in 30m · [top task] first?"

### Class mode
When a class event is detected from your USDI calendar:
- All task alerts suppressed
- Pill shows: "[subject] · class · 1h 20m left"
- **Tap pill during class** → 1-line text field for idea capture → saves to Notion queue
- Exception: mess closing < 5 min appears as 1-line sub-text

### Mess / Meals
- Reads mess schedule from Hostel Mess calendar events
- Warning 15 minutes before close
- In deep work + mess closing < 10 min: "finish this commit (8m) first? or heading to mess now?"
- Skipping lunch → reduces afternoon energy estimate

### Deep Work
Same app open > 20 minutes with no app switches:
- Dot goes completely invisible (no pulse, no dot)
- COI (cost of interruption) → 2.5× — much harder to break through
- Only urgency > 8.0 breaks through

### Distraction Detection
YouTube / Instagram / Chrome open > 20 min during a work window:
- Stakes-based message (never "you've been on YouTube"):
  "Figma deadline is today and you haven't touched it"
- Max 2 nudges per evening, then 30 min silence

### Day Closeout (last task done OR 11pm)
- Summary: "4 done · 2 moved to tomorrow · energy: medium"
- Sets tomorrow's queue (top 5 by P score) silently
- Sleep warning if class before 9am

---

## App Button (Open / Switch)

When your current task mentions an app by name, a button appears in the NowCard:

| App state | Button |
|---|---|
| Not running | "Open Figma" |
| Running, not front | "Switch to Figma" |
| Already frontmost | Button hidden |

Detected apps: Figma, Xcode, Notion, Blender, VS Code, Terminal, Chrome, Premiere, After Effects, Photoshop, Illustrator, DaVinci Resolve, Claude.

---

## Login Auto-Start

Notchly is installed as a LaunchAgent and starts automatically on every login.

```
~/Library/LaunchAgents/com.sai.notchly.plist
```

To stop it:
```bash
launchctl unload ~/Library/LaunchAgents/com.sai.notchly.plist
```

To restart it:
```bash
launchctl load ~/Library/LaunchAgents/com.sai.notchly.plist
```

Logs:
```
~/notchly/v2/logs/notchly.log
~/notchly/v2/logs/notchly_err.log
```

---

## Permissions Required

| Permission | Why |
|---|---|
| Calendar | Reads your 4 calendars to know your schedule |
| Accessibility | Global hotkeys (⌘⇧Space etc.) only work with this |

Grant Accessibility: **System Settings → Privacy & Security → Accessibility → add Notchly**

---

## Data & Memory

All data stays on your Mac. Nothing is sent anywhere.

| File | What's in it |
|---|---|
| `~/notchly/v2/memory/episodic.jsonl` | Every action you've taken, append-only |
| `~/notchly/v2/memory/semantic_profile.json` | Learned preferences, rebuilt weekly |
| `~/notchly/v2/working_memory.json` | Today's state — resets at midnight |
| `~/notchly/v2/memory/relationships.json` | Projects, deadlines, class schedule |
| `~/notchly/v2/cache/notion_cache.json` | Synced Notion tasks |
| `~/notchly/v2/cache/gcal_cache.json` | Synced Google Calendar events |

---

## Quick Reference Card

```
IDLE        → cursor over notch → hover peek
HOVER PEEK  → scroll ↓ 50pt   → NowCard
NOWCARD     → scroll ↓ 120pt  → Dashboard
ANYWHERE    → scroll ↑        → back to idle
ANYWHERE    → ⌘⇧Space         → chat
ANYWHERE    → Esc             → idle

NOTIFICATION → swipe right    → done / accept
NOTIFICATION → swipe left     → skip / not now
NOTIFICATION → Y              → primary action

TIMER       → tap timer text  → pause / resume
TIMER       → ⌘E              → +15 minutes

TASK        → ⌘D              → done
TASK        → ⌘S              → skip
TASK        → ⌘L              → later
```

---

*Notchly v2 · Built for Sai Kiran Chepuri, USDI B.Des Interaction Design*
*No cloud. No tracking. Just your Mac and your patterns.*
