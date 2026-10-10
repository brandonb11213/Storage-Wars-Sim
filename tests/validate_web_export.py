"""Reject incomplete or threaded exports before uploading to GitHub Pages."""
import json
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit


def validate(directory):
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    def local_file(name):
        url = urlsplit(name)
        require(not url.scheme and not url.netloc and not url.path.startswith("/"),
                f"Asset must resolve within the Pages project path: {name}")
        path = directory / url.path
        require(path.resolve().is_relative_to(directory.resolve()), f"Asset escapes export: {name}")
        require(path.is_file() and path.stat().st_size > 0, f"Missing or empty export file: {name}")
        return path

    html = local_file("index.html").read_text()
    config_match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html)
    require(config_match is not None, "Missing Godot engine configuration")
    config = json.loads(config_match.group(1))
    require("const GODOT_THREADS_ENABLED = false;" in html,
            "GitHub Pages build must use the single-threaded template")
    require(config.get("ensureCrossOriginIsolationHeaders") is False,
            "Single-threaded build must not depend on isolation-header reloads")
    require(not config.get("gdextensionLibs"), "Pages preset must not require extensions")
    for name, size in config["fileSizes"].items():
        require(local_file(name).stat().st_size == size, f"Engine asset size mismatch: {name}")
    for name in re.findall(r'(?:src|href)="([^"]+)"', html):
        local_file(name)

    worker = local_file(config["serviceWorker"]).read_text()
    require("const ENSURE_CROSSORIGIN_ISOLATION_HEADERS = false;" in worker,
            "Service worker must match the single-threaded export")
    for list_name in ("CACHED_FILES", "CACHEABLE_FILES"):
        match = re.search(rf"const {list_name} = (\[[^\n]+\]);", worker)
        require(match is not None, f"Missing worker list: {list_name}")
        for name in json.loads(match.group(1)):
            local_file(name)
    manifest = json.loads(local_file("index.manifest.json").read_text())
    require(manifest["start_url"] == "./index.html", "Offline startup needs the explicit relative index.html")
    require(manifest["orientation"] == "landscape", "Expected the existing landscape PWA")
    for icon in manifest["icons"]:
        local_file(icon["src"])
    print("PASS Pages package: complete relative assets, landscape PWA, no threads or isolation-header dependency")


if __name__ == "__main__":
    validate(Path(sys.argv[1] if len(sys.argv) > 1 else "build/web"))
