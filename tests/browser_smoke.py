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
from PIL import Image

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


def wait_state(page, predicate, description, seconds=30):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        state = saved_state(page)
        if state and predicate(state):
            return state
        page.wait_for_timeout(350)
    raise AssertionError("Timed out: " + description)


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
                    page.touchscreen.tap(*center)
                else:
                    page.mouse.click(*center)
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
        image = Image.open(io.BytesIO(page.screenshot())).convert("RGB")
        width, height = image.size
        scale = min(width / 1280, height / 720)
        x0, x1 = int(width - 352 * scale), int(width - 35 * scale)
        rows = []
        for y in range(int(120 * scale), int(height - 112 * scale)):
            count = sum(1 for x in range(x0, x1) if all(abs(a-b) <= 6 for a,b in zip(image.getpixel((x,y)), (255,196,107))))
            if count > 150 * scale:
                rows.append(y)
        groups = []
        for y in rows:
            if not groups or y > groups[-1][-1] + 1:
                groups.append([y])
            else:
                groups[-1].append(y)
        groups = [g for g in groups if len(g) >= 30 * scale]
        if groups:
            center = ((x0+x1)/2, (groups[0][0]+groups[0][-1])/2)
            if touch:
                page.touchscreen.tap(*center)
            else:
                page.mouse.click(*center)
            page.wait_for_timeout(450)
            return
        if scroll:
            page.mouse.move(width-80, height/2)
            page.mouse.wheel(0, 180)
        page.wait_for_timeout(300)
    raise AssertionError("Enabled primary button not visible in the rendered sidebar")


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
                args=["--no-sandbox", "--enable-unsafe-swiftshader", "--use-angle=swiftshader-webgl"])
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
                click_primary(page)
                wait_state(page, lambda s: s["auction"]["stage"] == "bidding", "auction enters bidding")
                print("PASS browser: canvas auction entry", flush=True)
                for _ in range(40):
                    state = saved_state(page)
                    if state["auction"]["stage"] != "bidding":
                        break
                    previous_round = state["auction"]["round"]
                    click_primary(page)
                    state = wait_state(page, lambda s: s["auction"]["round"] > previous_round, "NPC responds")
                    if state["auction"]["round"] % 4 == 0:
                        print("Browser auction round", state["auction"]["round"], "completed", flush=True)
                assert state["auction"]["stage"] == "owned", state
                assert state["cash"] == 500 - state["auction"]["price"]
                print("PASS browser: actual canvas auction and exact payment", flush=True)
                # Coordinates come from the independently tested camera rays at this viewport.
                targets = json.loads((OUT / "ray_targets.json").read_text())
                for index, (x, y) in enumerate(targets):
                    page.touchscreen.tap(x, y)
                    wait_state(page, lambda s: s["auction"]["boxes"][index]["revealed"], f"touch reveals crate {index}")
                    if index == 0:
                        page.screenshot(path=str(OUT / "browser-reveal.png"))
                    click_primary(page, touch=True, scroll=True)
                    wait_state(page, lambda s: s["auction"]["boxes"][index]["collected"], f"collect crate {index}")
                state = saved_state(page)
                assert state["auction"]["stage"] == "cleared" and len(state["inventory"]) == 6
                print("PASS browser: six real touch-picked crate reveals and collection", flush=True)
                click_text(page, r"Inventory / Pawn")
                click_text(page, r"^Select al")
                before = saved_state(page)
                click_primary(page)
                state = wait_state(page, lambda s: not s["inventory"], "sale clears inventory")
                assert state["cash"] > before["cash"] and state["sales"] == 6
                click_text(page, r"^Business$")
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
                click_primary(page)
                wait_state(page, lambda s: s["auction_serial"] == 2, "repeat auction after reload")
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
            page.set_viewport_size({"width": 844, "height": 390})
            page.wait_for_timeout(1200)
            click_text(page, r"^Business$", touch=True)
            page.screenshot(path=str(OUT / "browser-phone-landscape.png"))
            click_text(page, r"Auction$", touch=True)
            # Real multi-touch input reaches the camera; dragging does not reveal crates.
            before = saved_state(page)
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
