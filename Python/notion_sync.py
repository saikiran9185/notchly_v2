#!/usr/bin/env python3
"""
Reads tasks from Notion Tasks DB every 5 minutes.
DB ID: 1fc3dd7c-08d5-81ce-84c8-000b72a96013
Writes to ~/notchly/v2/cache/notion_cache.json (atomic)
"""
import json
import os
import time
import datetime
from pathlib import Path

BASE       = Path.home() / "notchly/v2"
CACHE      = BASE / "cache" / "notion_cache.json"
NOTION_KEY = os.environ.get("NOTION_API_KEY", "")
DB_ID      = "1fc3dd7c-08d5-81ce-84c8-000b72a96013"


def write_atomic(path: Path, data) -> None:
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, default=str)
    os.rename(tmp, path)


def fetch_notion_tasks() -> list:
    if not NOTION_KEY:
        return []
    try:
        import urllib.request
        url = f"https://api.notion.com/v1/databases/{DB_ID}/query"
        payload = json.dumps({"page_size": 100}).encode()
        req = urllib.request.Request(
            url, data=payload,
            headers={
                "Authorization": f"Bearer {NOTION_KEY}",
                "Notion-Version": "2022-06-28",
                "Content-Type": "application/json"
            },
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
        return parse_tasks(data.get("results", []))
    except Exception as e:
        print(f"[notion_sync] error: {e}")
        return []


def parse_tasks(pages: list) -> list:
    tasks = []
    for page in pages:
        props = page.get("properties", {})

        def text(key):
            items = props.get(key, {}).get("title", []) or props.get(key, {}).get("rich_text", [])
            return "".join(t.get("plain_text", "") for t in items)

        def date(key):
            d = props.get(key, {}).get("date", {})
            return d.get("start") if d else None

        def select(key):
            s = props.get(key, {}).get("select", {})
            return s.get("name") if s else None

        title = text("Name") or text("Task") or text("Title")
        if not title:
            continue

        tasks.append({
            "id": page["id"].replace("-", ""),
            "title": title,
            "priority": select("Priority") or "P3",
            "category": select("Category") or "other",
            "deadline": date("Due"),
            "status": select("Status") or "todo",
            "notionID": page["id"]
        })
    return tasks


def sync_loop():
    print(f"[notion_sync] starting")
    while True:
        tasks = fetch_notion_tasks()
        if tasks:
            write_atomic(CACHE, {"tasks": tasks, "synced_at": datetime.datetime.now().isoformat()})
            print(f"[notion_sync] synced {len(tasks)} tasks")
        time.sleep(300)  # 5 minutes


if __name__ == "__main__":
    sync_loop()
