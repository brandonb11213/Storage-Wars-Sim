"""Exercise the real exported canvas. Optional dev tools: Playwright, Chromium, Tesseract.

Uses OCR to click rendered buttons and reads browser saves to assert behavior.
It never injects game state or calls a production debug API.
"""
import argparse
import csv
import functools
import http.server
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit

from playwright.sync_api import sync_playwright
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-results"
OUT.mkdir(exist_ok=True)
SAVE_KEY = "/userfs/godot/app_userdata/Storage Wars Sim/storage_wars_save.json"
READ_SAVE = """key => new Promise((resolve,reject) => {
 const timeout=setTimeout(()=>reject(new Error('IndexedDB read timed out')),10000);
 const request=indexedDB.open('/userfs');
 request.onerror=()=>reject(request.error);
 request.onsuccess=()=>{const db=request.result;
  if(!db.objectStoreNames.contains('FILE_DATA')) {clearTimeout(timeout);db.close();resolve(null);return;}
  const tx=db.transaction('FILE_DATA','readonly');
  const get=tx.objectStore('FILE_DATA').get(key);
  get.onsuccess=()=>{clearTimeout(timeout);db.close();
   try {resolve(get.result ? JSON.parse(JSON.parse(new TextDecoder().decode(get.result.contents)).body) : null);}
   catch(error){reject(error);}
  };get.onerror=()=>reject(get.error);
 };
})"""


class QuietServer(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, base_path="", **kwargs):
        self.base_path = base_path
        super().__init__(*args, **kwargs)

    def do_GET(self):
        path = urlsplit(self.path)
        if self.base_path:
            if not path.path.startswith(self.base_path + "/"):
                self.send_error(404)
                return
            self.path = path.path[len(self.base_path):]
            if path.query:
                self.path += "?" + path.query
        super().do_GET()

    def log_message(self, *_args):
        pass


def saved_state(page):
    return page.evaluate(READ_SAVE, SAVE_KEY)


def wait_state(page, predicate, description, seconds=60):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        state = saved_state(page)
        if state and predicate(state):
            return state
        # Present a frame while polling: software WebGL may otherwise leave
        # Godot's deferred IndexedDB sync behind the canvas compositor.
        page.screenshot()
        page.wait_for_timeout(250)
    page.screenshot(path=str(OUT / "browser-failure.png"))
    (OUT / "browser-failure-state.json").write_text(json.dumps(saved_state(page), indent=2))
    raise AssertionError("Timed out: " + description + "; saved state: " + str(saved_state(page)))


def lines(page):
    image_path = OUT / "browser-current.png"
    page.screenshot(path=str(image_path))
    groups = {}
    for segmentation in [3, 11]:
        raw = subprocess.check_output(["tesseract", str(image_path), "stdout", "--psm", str(segmentation), "tsv"], stderr=subprocess.DEVNULL, text=True)
        for row in csv.DictReader(io.StringIO(raw), delimiter="\t"):
            word = row.get("text", "").strip()
            if not word:
                continue
            key = (segmentation, row["block_num"], row["par_num"], row["line_num"])
            groups.setdefault(key, []).append(row)
    result = []
    for words in groups.values():
        text = " ".join(w["text"] for w in words)
        x0 = min(int(w["left"]) for w in words)
        y0 = min(int(w["top"]) for w in words)
        x1 = max(int(w["left"]) + int(w["width"]) for w in words)
        y1 = max(int(w["top"]) + int(w["height"]) for w in words)
        result.append((text, ((x0+x1)/2, (y0+y1)/2)))
    return result


def click_text(page, pattern, touch=False, scroll=False):
    for attempt in range(9 if scroll else 4):
        for text, center in lines(page):
            if re.search(pattern, text, re.I):
                if touch:
                    touch_tap(page, *center)
                else:
                    page.mouse.click(*center, delay=120)
                page.wait_for_timeout(450)
                return
        if scroll:
            page.mouse.move(page.viewport_size["width"] - 80, page.viewport_size["height"] / 2)
            page.mouse.wheel(0, 180)
        page.wait_for_timeout(350)
    raise AssertionError(f"Rendered button not found: {pattern}. OCR: {lines(page)}")


def click_primary(page, touch=False, scroll=False):
    """Locate the actual gold button pixels; OCR can miss dark text on a gold background."""
    for _ in range(10 if scroll else 4):
        # Normalize hover before pixel matching; the same enabled button can
        # otherwise change color under a stationary pointer.
        if not touch: page.mouse.move(5, 5)
        capture = page.screenshot()
        (OUT / "browser-primary-current.png").write_bytes(capture)
        image = Image.open(io.BytesIO(capture)).convert("RGB")
        width, height = image.size
        scale = min(width / 960, height / 540)
        x0, x1 = int(width - 322 * scale), int(width - 25 * scale)
        # Build a gold mask in Pillow's C code; a Python loop over every pixel
        # competes heavily with software WebGL in the cloud test environment.
        red, green, blue = image.split()
        mask = ImageChops.multiply(red.point([255 if value >= 249 else 0 for value in range(256)]),
            ImageChops.multiply(green.point([255 if 190 <= value <= 209 else 0 for value in range(256)]),
                blue.point([255 if 101 <= value <= 131 else 0 for value in range(256)])))
        y0, y1 = int(82 * scale), int(height - 96 * scale)
        scan_width = x1 - x0
        samples = mask.crop((x0, y0, x1, y1)).tobytes()
        rows = [y0 + offset for offset in range(y1 - y0)
            if samples[offset * scan_width:(offset + 1) * scan_width].count(255) > 150 * scale]
        groups = []
        for y in rows:
            if not groups or y > groups[-1][-1] + 1:
                groups.append([y])
            else:
                groups[-1].append(y)
        groups = [g for g in groups if len(g) >= 30 * scale]
        if groups:
            center = ((x0+x1)/2, (groups[0][0]+groups[0][-1])/2)
            with (OUT / "browser-clicks.jsonl").open("a") as trace:
                trace.write(json.dumps({"center": center, "touch": touch, "state": saved_state(page)}) + "\n")
            if touch:
                touch_tap(page, *center)
            else:
                page.mouse.click(*center, delay=120)
            page.wait_for_timeout(450)
            return
        if scroll:
            page.mouse.move(width-80, height/2)
            page.mouse.wheel(0, 180)
        page.wait_for_timeout(300)
    page.screenshot(path=str(OUT / "browser-failure.png"))
    (OUT / "browser-failure-state.json").write_text(json.dumps(saved_state(page), indent=2))
    raise AssertionError("Enabled primary button not visible in the rendered sidebar")




def touch_tap(page, x, y):
    # Use a real press/release interval; instantaneous CDP taps can be coalesced
    # while software WebGL is presenting a frame.
    if not hasattr(page, "_phase15_touch_session"):
        page._phase15_touch_session = page.context.new_cdp_session(page)
    session = page._phase15_touch_session
    session.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": x, "y": y, "id": 1}]})
    page.wait_for_timeout(120)
    session.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})

def click_nav(page, key, touch=False):
    keys = ["map", "auction", "home", "inventory", "selling", "upgrades", "business"]
    rect = page.locator("#canvas").bounding_box()
    scale = min(rect["width"] / 960, rect["height"] / 540)
    inside = rect["width"] - 24 * scale
    x = rect["x"] + 12 * scale + inside * (keys.index(key) + 0.5) / 7
    y = rect["y"] + rect["height"] - 44 * scale
    if touch: touch_tap(page, x, y)
    else: page.mouse.click(x, y, delay=120)
    page.wait_for_timeout(500)


def unit_quote(state):
    definitions = {item["id"]: item for item in json.loads((ROOT / "data/items.json").read_text())}
    cargo = sum(definitions[box["item"]["definition"]]["size"] for box in state["auction"]["boxes"])
    capacity = 6 + 6 * state["upgrades"]["vehicle"]
    trips = (cargo + capacity - 1) // capacity
    return trips * (6 + state["auction"]["district"] * 2 - 2 * state["upgrades"]["operations"])

def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform-only", action="store_true")
    parser.add_argument("--base-path", default="", help="Emulate a Pages project mount, e.g. /Storage-Wars-Sim")
    options = parser.parse_args()
    base_path = options.base_path.rstrip("/")
    if base_path and not re.fullmatch(r"(?:/[A-Za-z0-9_-]+)+", base_path):
        parser.error("--base-path must be a simple absolute directory path")
    handler = functools.partial(QuietServer, directory=str(ROOT / "build/web"), base_path=base_path)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    errors = []
    messages = []
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=os.environ.get("CHROMIUM", "/usr/bin/chromium"), headless=True,
                args=["--no-sandbox", "--enable-unsafe-swiftshader", "--use-angle=swiftshader-webgl", "--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows"])
            context = browser.new_context(viewport={"width": 1280, "height": 720}, has_touch=True)
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("console", lambda msg: messages.append(msg.text))
            origin = f"http://127.0.0.1:{server.server_port}"
            page.goto(origin + base_path + "/index.html", wait_until="networkidle")
            page.wait_for_timeout(2500)
            click_text(page, r"^New Game")
            state = wait_state(page, lambda s: s["cash"] == 500, "new game starts at $500")
            page.evaluate("navigator.serviceWorker.ready")
            registration = page.evaluate("navigator.serviceWorker.ready.then(registration => ({scope: registration.scope, script: registration.active.scriptURL}))")
            assert registration["scope"] == origin + base_path + "/", registration
            assert registration["script"] == origin + base_path + "/index.service.worker.js", registration
            assert not page.evaluate("crossOriginIsolated"), "This build must work without isolation headers"
            print("PASS browser: New Game renders and saves $500", flush=True)
            print("PASS browser: project path and service worker scope", base_path or "/", flush=True)
            page.screenshot(path=str(OUT / "browser-facility.png"))
            if not options.platform_only:
                click_nav(page, "auction")
                page.screenshot(path=str(OUT / "browser-auction-preview.png"))
                for attempt in range(8):
                    click_primary(page, scroll=True)
                    wait_state(page, lambda s: s["auction"]["stage"] == "bidding", "auction enters bidding")
                    for _ in range(150):
                        state = saved_state(page)
                        if state["auction"]["stage"] != "bidding": break
                        previous_round = state["auction"]["round"]
                        quote = unit_quote(state)
                        if state["auction"]["price"] + state["auction"]["increment"] + quote > state["cash"]:
                            click_text(page, r"Pass / finish", scroll=True)
                        else:
                            click_primary(page, touch=True, scroll=True)
                        state = wait_state(page, lambda s: s["auction"]["round"] > previous_round, "NPC responds after round %d" % previous_round)
                        if state["auction"]["round"] % 5 == 0: print("Browser round", state["auction"]["round"], "stage", state["auction"]["stage"], flush=True)
                    if state["auction"]["stage"] == "owned": break
                    assert state["auction"]["stage"] == "lost" and state["cash"] == 500
                    click_nav(page, "auction")
                    click_primary(page, scroll=True)
                assert state["auction"]["stage"] == "owned", state
                assert state["cash"] == 500 - state["auction"]["price"] - state["transport_spent"] + state["quest_earned"]
                print("PASS browser: canvas NPC competition and exact acquisition/transport/reward accounting", flush=True)
                # Coordinates come from the independently tested camera rays at this viewport.
                targets = json.loads((OUT / "ray_targets.json").read_text())
                for index, (x, y) in enumerate(targets):
                    touch_tap(page, x * page.viewport_size["width"] / 960, y * page.viewport_size["height"] / 540)
                    wait_state(page, lambda s: s["auction"]["boxes"][index]["revealed"], f"touch reveals crate {index}")
                    if index == 0:
                        page.screenshot(path=str(OUT / "browser-reveal.png"))
                    click_primary(page, touch=True, scroll=True)
                    wait_state(page, lambda s: s["auction"]["boxes"][index]["collected"], f"collect crate {index}")
                state = saved_state(page)
                assert state["auction"]["stage"] == "cleared" and len(state["inventory"]) == 6
                print("PASS browser: six real touch-picked crate reveals and collection", flush=True)
                click_nav(page, "inventory")
                click_text(page, r"^Select al")
                before = saved_state(page)
                click_primary(page)
                state = wait_state(page, lambda s: not s["inventory"], "sale clears inventory")
                assert state["cash"] > before["cash"] and state["sales"] == 6
                click_nav(page, "upgrades")
                click_primary(page, scroll=True)
                state = wait_state(page, lambda s: s["upgrades"]["appraisal"] == 1, "appraisal purchased")
                assert state["upgrade_spent"] == 75
                print("PASS browser: selected pawn sales and upgrade", flush=True)
                click_text(page, r"^Save$")
                saved = saved_state(page)
                page.reload(wait_until="networkidle")
                page.wait_for_timeout(2000)
                click_text(page, r"^Continue$")
                assert saved_state(page) == saved
                click_nav(page, "auction")
                previous_serial = saved["auction_serial"]
                click_primary(page)
                wait_state(page, lambda s: s["auction_serial"] == previous_serial + 1, "repeat auction after reload")
                print("PASS browser: IndexedDB progress survives reload and Continue", flush=True)
            else:
                page.reload(wait_until="networkidle")
                page.wait_for_timeout(2000)
                click_text(page, r"^Continue$")
                assert saved_state(page)["cash"] == 500
                print("PASS browser: canonical URL and saved startup", flush=True)
            before_offline = saved_state(page)
            page.evaluate("navigator.serviceWorker.ready")
            context.set_offline(True)
            page.reload(wait_until="load")
            page.wait_for_timeout(2500)
            click_text(page, r"^Continue$")
            assert saved_state(page) == before_offline
            print("PASS browser: cached offline reload and saved gameplay", flush=True)
            for width, height in [(667, 375), (812, 375), (844, 390), (932, 430)]:
                page.set_viewport_size({"width": width, "height": height})
                page.wait_for_timeout(800)
                for key, expected in [("map", "YOUR GROWING TOWN"), ("home", "YOUR BUSINESS HAS A HOME"), ("inventory", "Your inventory"), ("selling", "Prepare and sell"), ("upgrades", "BUILD YOUR BUSINESS"), ("business", "Your business"), ("auction", "SUNSET")]:
                    click_nav(page, key, touch=True)
                    # Real touch routes are checked against visible panel text, not production debug methods.
                    assert any(re.search(expected, text, re.I) for text, _ in lines(page)), (width, height, key, lines(page))
                print(f"PASS browser: all seven screens via actual touch at {width}×{height}", flush=True)
            page.set_viewport_size({"width": 844, "height": 390})
            page.wait_for_timeout(600)
            page.add_style_tag(content="#canvas{left:44px!important;top:6px!important;width:calc(100vw - 88px)!important;height:calc(100dvh - 12px)!important}")
            page.wait_for_timeout(800)
            click_nav(page, "upgrades", touch=True)
            assert any("BUILD YOUR BUSINESS" in text.upper() for text, _ in lines(page)), lines(page)
            page.screenshot(path=str(OUT / "browser-phone-landscape.png"))
            click_nav(page, "auction", touch=True)
            print("PASS browser: touch Upgrades with simulated landscape safe-area insets", flush=True)
            # Real multi-touch input reaches the camera; dragging does not reveal crates.
            before = saved_state(page)
            page.wait_for_timeout(1000)
            before_image = page.screenshot()
            cdp = context.new_cdp_session(page)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": 180, "y": 180, "id": 1}, {"x": 270, "y": 180, "id": 2}]})
            cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [{"x": 150, "y": 180, "id": 1}, {"x": 300, "y": 180, "id": 2}]})
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            page.wait_for_timeout(500)
            assert saved_state(page) == before
            page.screenshot(path=str(OUT / "browser-phone-zoom.png"))
            assert page.screenshot() != before_image, "Pinch must visibly change camera framing"
            assert not errors, errors
            assert not any("SCRIPT ERROR:" in m or m.startswith("ERROR:") for m in messages), messages
            scope = "offline cache, landscape touch UI and pinch input" if options.platform_only else "desktop canvas loop, touch picks, reload persistence, offline cache, landscape touch UI and pinch input"
            (OUT / "browser.log").write_text("\n".join(messages) + "\nPASS: " + scope + ".\n")
            print("PASS browser: 844×390 landscape touch UI and pinch events; no runtime errors", flush=True)
            browser.close()
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    run()
