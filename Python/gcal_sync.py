#!/usr/bin/env python3
"""
Reads all 4 Google Calendars via Google Calendar API every 5 minutes.
Writes to ~/notchly/v2/cache/gcal_cache.json (atomic)

Calendars:
  1. Primary: saikiran9185@gmail.com
  2. Hostel Mess calendar
  3. Google Tasks
  4. USDI B.Des: set CLASS_CALENDAR_ID env var
"""
import json
import os
import time
import datetime
from pathlib import Path

BASE    = Path.home() / "notchly/v2"
CACHE   = BASE / "cache" / "gcal_cache.json"
CREDS   = BASE / "memory" / "gcal_creds.json"

CLASS_CALENDAR_ID = os.environ.get("CLASS_CALENDAR_ID", "")
CLASS_KEYWORDS    = ["lecture", "class", "lab", "studio", "tutorial", "workshop", "crit", "seminar"]
LOCATION_KEYWORDS = ["usdi", "ip university", "university", "college", "campus"]


def write_atomic(path: Path, data) -> None:
    # BUG-29 fix: use os.replace (atomic) and handle errors; also cleans up .tmp on failure
    tmp = path.with_suffix(".tmp")
    try:
        with open(tmp, "w") as f:
            json.dump(data, f, indent=2, default=str)
        os.replace(tmp, path)
    except Exception as e:
        print(f"[gcal_sync] write_atomic failed for {path}: {e}")
        try:
            tmp.unlink(missing_ok=True)
        except Exception:
            pass


def is_class_event(event: dict) -> bool:
    cal_id = event.get("organizer", {}).get("email", "")
    if CLASS_CALENDAR_ID in cal_id:
        return True
    title    = event.get("summary", "").lower()
    location = event.get("location", "").lower()
    if any(k in title for k in CLASS_KEYWORDS):
        return True
    if any(k in location for k in LOCATION_KEYWORDS):
        return True
    return False


def fetch_events(service, calendar_id: str, time_min: str, time_max: str) -> list:
    try:
        result = service.events().list(
            calendarId=calendar_id,
            timeMin=time_min,
            timeMax=time_max,
            singleEvents=True,
            orderBy="startTime"
        ).execute()
        return result.get("items", [])
    except Exception as e:
        print(f"[gcal_sync] error fetching {calendar_id}: {e}")
        return []


def build_service():
    try:
        from google.oauth2.credentials import Credentials
        from googleapiclient.discovery import build
        from google.auth.transport.requests import Request

        if not CREDS.exists():
            return None

        creds = Credentials.from_authorized_user_file(str(CREDS))
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
            # BUG-29 fix: write refreshed credentials atomically so partial writes
            # can't corrupt the creds file permanently
            tmp = CREDS.with_suffix(".tmp")
            tmp.write_text(creds.to_json())
            os.replace(tmp, CREDS)
        return build("calendar", "v3", credentials=creds)
    except ImportError:
        return None
    except Exception as e:
        print(f"[gcal_sync] auth error: {e}")
        return None


def sync_loop():
    print("[gcal_sync] starting")
    while True:
        service = build_service()
        if not service:
            print("[gcal_sync] no credentials — writing empty cache")
            write_atomic(CACHE, {"today": [], "tomorrow": [], "synced_at": datetime.datetime.now().isoformat()})
            time.sleep(300)
            continue

        # BUG-31 fix: utcnow() is deprecated in Python 3.12+; use timezone-aware now()
        now = datetime.datetime.now(datetime.timezone.utc)
        tomorrow = now + datetime.timedelta(days=2)
        time_min = now.strftime("%Y-%m-%dT00:00:00Z")
        time_max = tomorrow.strftime("%Y-%m-%dT00:00:00Z")

        calendars = ["primary", CLASS_CALENDAR_ID]
        all_events = []
        for cal_id in calendars:
            events = fetch_events(service, cal_id, time_min, time_max)
            all_events.extend(events)

        today_str     = now.strftime("%Y-%m-%d")
        tomorrow_str  = (now + datetime.timedelta(days=1)).strftime("%Y-%m-%d")

        def event_date(e):
            start = e.get("start", {})
            return start.get("dateTime", start.get("date", ""))[:10]

        def format_event(e):
            start = e.get("start", {})
            t = start.get("dateTime", "")
            time_str = t[11:16] if len(t) >= 16 else ""
            duration = ""
            try:
                s = datetime.datetime.fromisoformat(t.replace("Z", "+00:00"))
                end_str = e.get("end", {}).get("dateTime", "")
                if end_str:
                    en = datetime.datetime.fromisoformat(end_str.replace("Z", "+00:00"))
                    mins = int((en - s).total_seconds() / 60)
                    duration = f"{mins//60}h {mins%60}m" if mins >= 60 else f"{mins}m"
            except Exception as fmt_err:
                # BUG-30 fix: log which event failed so sync issues are diagnosable
                print(f"[gcal_sync] format_event error for '{e.get('summary', '?')}': {fmt_err}")
            return {
                "time": time_str,
                "title": e.get("summary", "Event"),
                "duration": duration,
                "is_class": is_class_event(e),
                "color": "#4A90E2" if is_class_event(e) else "#5F5E5A"
            }

        today_events    = [format_event(e) for e in all_events if event_date(e) == today_str]
        tomorrow_events = [format_event(e) for e in all_events if event_date(e) == tomorrow_str]

        write_atomic(CACHE, {
            "today": today_events,
            "tomorrow": tomorrow_events,
            "synced_at": datetime.datetime.now().isoformat()
        })
        print(f"[gcal_sync] synced {len(today_events)} today, {len(tomorrow_events)} tomorrow")
        time.sleep(300)


if __name__ == "__main__":
    sync_loop()
