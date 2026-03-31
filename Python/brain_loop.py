#!/usr/bin/env python3
"""
Notchly Brain Daemon — runs every 90 seconds via launchd KeepAlive.
Reads:  ~/notchly/v2/working_memory.json
Reads:  ~/notchly/v2/memory/semantic_profile.json
Writes: ~/notchly/v2/pending_alerts.json  (atomic: write .tmp then rename)
Writes: ~/notchly/v2/memory/working_memory.json  (atomic)
"""
import json
import os
import time
import datetime
from pathlib import Path

from scorer import score_all

BASE = Path.home() / "notchly/v2"
MEMORY = BASE / "memory"

WORKING_MEMORY   = BASE / "working_memory.json"
SEMANTIC_PROFILE = MEMORY / "semantic_profile.json"
PENDING_ALERTS   = BASE / "pending_alerts.json"
NOTION_CACHE     = BASE / "cache" / "notion_cache.json"
GCAL_CACHE       = BASE / "cache" / "gcal_cache.json"


def read_json(path: Path) -> dict:
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}


def write_atomic(path: Path, data) -> None:
    """Atomic write: write to .tmp then os.rename (atomic swap)"""
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, default=str)
    os.rename(tmp, path)


def build_context(wm: dict) -> dict:
    now = datetime.datetime.now()
    return {
        "hour": now.hour,
        "day_of_week": now.weekday(),
        "is_in_class": wm.get("classMode", False),
        "idle_minutes": wm.get("idleMinutes", 0),
        "frontmost_app": "",
        "deadline_today": False,
    }


def generate_alerts(wm: dict, profile: dict, context: dict) -> list:
    """Determine what alerts to fire this cycle"""
    alerts = []
    tasks = wm.get("taskQueue", [])
    if not tasks:
        return alerts

    # Score tasks
    scored = score_all(tasks, context, profile)

    # Check top-priority task for notification
    if scored:
        top = scored[0]
        urgency = top.get("urgency", 2.0)
        p_final = top.get("pFinal", 0.0)

        # EVR gate — simplified Python version
        w = profile.get("W_values", {}).get("task", 0.60)
        coi = 2.0 * (4.0 if context.get("is_in_class") else 1.0)
        evr = w * p_final - coi

        if evr > 0 or urgency > 8.0:
            alerts.append({
                "title": top.get("title", "Task"),
                "subtitle": deadline_subtitle(top),
                "type": "task",
                "taskTitle": top.get("title", ""),
                "urgency": urgency,
                "pFinal": p_final
            })

    return alerts


def deadline_subtitle(task: dict) -> str:
    deadline = task.get("deadline")
    if not deadline:
        return ""
    try:
        h = (float(deadline) - time.time()) / 3600
        if h < 0:
            return "overdue"
        if h < 1:
            return f"due in <1h"
        return f"due in {int(h)}h"
    except Exception:
        return ""


def check_wellbeing(wm: dict, context: dict) -> list:
    """Check distraction, idle, burnout"""
    alerts = []
    hour = context["hour"]
    idle_mins = context.get("idle_minutes", 0)

    # Idle nudge (20+ min idle during work hours)
    if idle_mins >= 20 and 8 <= hour <= 22:
        tasks = wm.get("taskQueue", [])
        if tasks:
            alerts.append({
                "title": f"{tasks[0].get('title', 'task')} is waiting",
                "subtitle": "20min idle",
                "type": "lazy",
                "taskTitle": tasks[0].get("title", ""),
                "urgency": 3.0
            })

    return alerts


def main_loop():
    print(f"[brain_loop] starting at {datetime.datetime.now().isoformat()}")
    while True:
        try:
            wm      = read_json(WORKING_MEMORY)
            profile = read_json(SEMANTIC_PROFILE)
            context = build_context(wm)

            # Generate alerts
            alerts = generate_alerts(wm, profile, context)
            alerts += check_wellbeing(wm, context)

            # Write pending alerts atomically (only if changed)
            existing = read_json(PENDING_ALERTS) if PENDING_ALERTS.exists() else []
            if alerts != existing:
                write_atomic(PENDING_ALERTS, alerts)

        except Exception as e:
            print(f"[brain_loop] error: {e}")

        time.sleep(90)


if __name__ == "__main__":
    main_loop()
