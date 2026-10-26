"""DriveBC notices for Cypress Bowl Road and the Sea to Sky corridor."""
import json
import re
import threading
import time
import urllib.parse
import urllib.request
from pathlib import Path

SOURCE = "https://api.open511.gov.bc.ca/events"
CACHE = Path.home() / "Library/Application Support/MountainCams/traffic.json"
LOCK = threading.Lock()
last_attempt = 0
last_result = None


def road_matches(event, route):
    for road in event.get("roads", []):
        name = road.get("name", "").casefold()
        if route == "seatosky" and name == "highway 99":
            return True
        # Highway 1 exit works are not the Cypress uphill road itself.
        if route == "cypress" and name != "highway 1":
            text = " ".join(str(road.get(k, "")) for k in ("name", "from", "to"))
            if re.search(r"cypress bowl (?:road|rd)\b", text, re.I):
                return True
    return False


def notice(event):
    description = event.get("description", "")
    text = description.lower()
    category = {"CONSTRUCTION": "施工通告", "INCIDENT": "事故通告",
                "WEATHER_CONDITION": "天气通告", "ROAD_CONDITION": "路面通告"}.get(event.get("event_type"), "道路通告")
    if "single lane alternating" in text:
        impact = "单线交替通行"
    elif re.search(r"(?:road|highway) (?:is )?closed|closed in both directions", text):
        impact = "道路封闭通告"
    elif "lane closure" in text or "lane closed" in text:
        impact = "部分车道关闭"
    elif "icy" in text or "ice covered" in text:
        impact = "结冰提醒"
    elif "snow" in text:
        impact = "降雪／积雪提醒"
    else:
        impact = "查看官方通告"
    return {"id": event["id"], "headline": category + " · " + impact,
            "description": description, "updated": event.get("updated", ""),
            "severity": event.get("severity", "UNKNOWN"),
            "location": (event.get("roads") or [{}])[0].get("from", ""),
            "schedule": event.get("schedule", {})}


def summarize(events, checked_at):
    routes = []
    for key, name in (("cypress", "Cypress Bowl Road"), ("seatosky", "Sea to Sky · Hwy 99")):
        selected = [e for e in events if e.get("status") == "ACTIVE" and road_matches(e, key)]
        selected.sort(key=lambda e: (e.get("severity") in ("MAJOR", "CRITICAL"), e.get("updated", "")), reverse=True)
        routes.append({"name": name, "notices": [notice(e) for e in selected],
                       "count": len(selected)})
    return {"checked_at": checked_at, "stale": False, "source": "DriveBC", "routes": routes}


def fetch_events():
    # Horseshoe Bay through Whistler; excludes the southern Highway 99 corridor.
    query = {"status": "ACTIVE", "bbox": "-123.35,49.32,-122.85,50.17", "limit": 500}
    events = []
    while True:
        url = SOURCE + "?" + urllib.parse.urlencode(query)
        with urllib.request.urlopen(url, timeout=15) as response:
            payload = json.load(response)
        page = payload["events"]
        if not isinstance(page, list):
            raise ValueError("Invalid DriveBC events")
        events.extend(page)
        if not payload.get("pagination", {}).get("next"):
            return events
        query["offset"] = query.get("offset", 0) + len(page)
        if not page:
            raise ValueError("Empty DriveBC page")


def traffic():
    global last_attempt, last_result
    with LOCK:
        if last_result is not None and time.monotonic() - last_attempt < 300:
            return last_result
        last_attempt = time.monotonic()
        try:
            result = summarize(fetch_events(), time.time())
            CACHE.parent.mkdir(parents=True, exist_ok=True)
            temporary = CACHE.with_suffix(".tmp")
            temporary.write_text(json.dumps(result, ensure_ascii=False))
            temporary.replace(CACHE)
        except Exception as error:
            print("DriveBC refresh failed:", type(error).__name__, flush=True)
            try:
                result = last_result or json.loads(CACHE.read_text())
            except (OSError, ValueError):
                result = summarize([], 0)
            result = dict(result, stale=True)
        last_result = result
        return result


if __name__ == "__main__":
    print(json.dumps(traffic(), ensure_ascii=False, indent=2))
