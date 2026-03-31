#!/usr/bin/env python3
"""
Scheduler — called by brain_loop after any user action.
Proposes specific times (never asks "when?").
Returns schedule proposal → brain_loop writes to schedule.json
"""
import json
import datetime
from pathlib import Path
from scorer import score_all, ENERGY_CURVE

BASE          = Path.home() / "notchly/v2"
GCAL_CACHE    = BASE / "cache" / "gcal_cache.json"
SCHEDULE_FILE = BASE / "schedule.json"


def write_atomic(path: Path, data) -> None:
    import os
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, default=str)
    os.rename(tmp, path)


def load_today_events() -> list:
    try:
        with open(GCAL_CACHE) as f:
            data = json.load(f)
        return data.get("today", [])
    except Exception:
        return []


def free_blocks(events: list) -> list:
    """Compute free time blocks today (>= 15min)"""
    now = datetime.datetime.now()
    day_end = now.replace(hour=23, minute=0, second=0)
    cursor = now

    blocks = []
    for event in sorted(events, key=lambda e: e.get("time", "")):
        try:
            parts = event["time"].split(":")
            ev_start = now.replace(hour=int(parts[0]), minute=int(parts[1]))
            dur_str = event.get("duration", "0m")
            dur_min = 0
            if "h" in dur_str:
                h, rest = dur_str.split("h")
                dur_min += int(h.strip()) * 60
                if "m" in rest:
                    dur_min += int(rest.replace("m", "").strip() or "0")
            elif "m" in dur_str:
                dur_min = int(dur_str.replace("m", "").strip())
            ev_end = ev_start + datetime.timedelta(minutes=dur_min)

            if ev_start > cursor:
                gap_min = (ev_start - cursor).total_seconds() / 60
                if gap_min >= 15:
                    blocks.append({"start": cursor, "end": ev_start, "minutes": int(gap_min)})
            cursor = max(cursor, ev_end)
        except Exception:
            continue

    if cursor < day_end:
        gap_min = (day_end - cursor).total_seconds() / 60
        if gap_min >= 15:
            blocks.append({"start": cursor, "end": day_end, "minutes": int(gap_min)})
    return blocks


HIGH_ENERGY_CATS  = {"deep_work", "creative", "study"}
LOW_ENERGY_CATS   = {"admin", "review"}
SKIP_CATS         = {"class"}


def match_tasks_to_slots(tasks: list, blocks: list, context: dict, profile: dict) -> list:
    """Match tasks to free blocks, respecting energy levels"""
    schedule = []
    assigned = set()

    for block in blocks:
        hour = block["start"].hour
        if profile and "energy_by_hour" in profile:
            energy = profile["energy_by_hour"].get(str(hour), ENERGY_CURVE.get(hour, 5.0))
        else:
            energy = ENERGY_CURVE.get(hour, 5.0)

        is_peak = energy >= 8
        is_dip  = energy <= 5

        for task in tasks:
            tid = task.get("id", task.get("title", ""))
            if tid in assigned:
                continue
            cat = task.get("category", "other")
            if cat in SKIP_CATS:
                continue
            if is_peak and cat not in HIGH_ENERGY_CATS and cat not in {"meeting", "exercise"}:
                continue
            if is_dip and cat not in LOW_ENERGY_CATS and cat not in {"meal", "break", "other"}:
                continue

            est_min = task.get("estimatedMinutes", 30)
            if block["minutes"] < est_min:
                continue

            # Add 10min context switch buffer
            start = block["start"] + datetime.timedelta(minutes=10)
            end   = start + datetime.timedelta(minutes=est_min)
            if end > block["end"]:
                continue

            schedule.append({
                "taskID": tid,
                "taskTitle": task.get("title", ""),
                "start": start.isoformat(),
                "end": end.isoformat(),
                "energy": energy,
            })
            assigned.add(tid)

            # Update block cursor
            block["start"] = end
            block["minutes"] = int((block["end"] - end).total_seconds() / 60)
            break

    return schedule


def propose_schedule(wm: dict, context: dict, profile: dict) -> list:
    tasks  = wm.get("taskQueue", [])
    scored = score_all(tasks, context, profile)
    events = load_today_events()
    blocks = free_blocks(events)
    return match_tasks_to_slots(scored, blocks, context, profile)


def run_once(wm: dict, context: dict, profile: dict) -> None:
    schedule = propose_schedule(wm, context, profile)
    write_atomic(SCHEDULE_FILE, {"schedule": schedule, "generated_at": datetime.datetime.now().isoformat()})
    print(f"[scheduler] proposed {len(schedule)} scheduled blocks")
