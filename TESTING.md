# Testing and platform limits

## Required development checks

From the checkout:

```bash
source tools/env.sh
bash tools/check.sh
bash tools/export_web.sh
```

`check.sh` imports the actual project, rejects import/runtime errors, and runs `tests/run_tests.gd`. It preserves Godot's exit status through `tee` and fails on recorded assertions or runtime errors. Results are generated in `test-results/`; tests use a separate `user://test_storage_save.json` and never overwrite player saves.

Coverage includes:

- Unique item definitions, all six rarity tiers, and 12,000 seeded item samples with positive values and valid conditions.
- Reproducible seeds/serials, distinct unit generation and improved rarity distribution from auction access.
- Opening bids, NPC replies, affordability, losing without charges, exactly-once settlement, and 40 winnable auction seeds.
- Ownership/reveal/collect rules, duplicate prevention, atomic invalid/duplicate sales, exact offers, bulk sales and XP/accounting.
- Upgrade prices/effects/caps and protection of active bid funds; bankruptcy recovery constraints, including higher opening bids after access upgrades.
- Save round-trip including partially collected/revealed units, corrupt/missing file behavior, backup recovery, malformed schema and invalid IDs/tiers/cash.
- The real scene's controls: auction, physics-ray crate taps, collect, pawn sale, upgrade, Save, Menu, Continue and a second auction. Camera pan/zoom methods are checked too.

The runner currently executes **12,222 assertions with zero failures** on Godot 4.6.3. Counts include individual samples; they are not 12,222 independently named test cases. Headless import and the single-threaded release web export pass. The generated web package is about 37 MB uncompressed, dominated by the engine's WASM binary.

## Browser regression

Optional test tooling, outside the game: Python Playwright and Pillow, Chromium and Tesseract. These were already available in the cloud machine. These are not runtime dependencies. If installing on another development machine, use their free official releases; normal gameplay and headless tests do not require them.

```bash
# Run check.sh first: it writes the verified 1280×720 camera tap coordinates.
bash tools/check_browser.sh
```

The test serves `build/web` on a temporary loopback port, launches real Chromium/WebGL 2, clicks rendered canvas buttons using OCR and primary-button pixel detection, sends actual touch events to the six crates, and reads the saved IndexedDB state to verify the transactions. It tests persistence through a reload/Continue, PWA cached offline reload, and an 844×390 landscape viewport with touch buttons and pinch input. It does not inject game state or call a production debug API. It shuts down its own browser/server. Failures raise an error and exit nonzero; runtime errors also fail the test.

Generated screenshots and browser logs live in `test-results/`. Chromium uses software WebGL in this cloud environment, so GPU screenshot-stall warnings are not device FPS measurements. Passing browser emulation is not physical iPhone Safari evidence.

Recorded validation on October 9, 2026: the full `bash tools/check_browser.sh` run completed with exit code 0 and no runtime errors. It verified the auction/payment, six touch-picked reveals and collections, selected pawn sales, appraisal purchase, reload/Continue, cached offline startup, and landscape touch/pinch checks. The headless suite also covers recovery when auction-access upgrades raise opening bids above the initial funding threshold.

Recorded hosting validation on October 10, 2026: the restored environment passed all **12,222 headless checks**, the release web export, complete-package/path checks, and `actionlint` 1.7.7 workflow validation. The full `bash tools/check_browser.sh --base-path /Storage-Wars-Sim` run exited 0 with no runtime errors: actual auction/payment, six touch-picked crates, collection/sales/upgrade, IndexedDB reload/Continue, cached offline reload, and 844×390 touch/pinch checks. It also confirmed the project-relative worker scope and startup without cross-origin isolation headers. The local Pages simulation returned the complete WASM file as `application/wasm`. GitHub-hosted CI/deployment and physical Safari remain unrun.

## Free iPhone Safari testing

The Web preset uses Compatibility/WebGL 2, GDScript, **no threads**, and no extensions. It does not require SharedArrayBuffer or special cross-origin isolation headers. The shipped engine template requires Safari 15.2 or later; use a current iOS/Safari version for testing. It is a browser test build of the iOS-intended game, not a verified native iOS package.

Free local route, on a development computer reachable from the phone:

1. Run `bash tools/export_web.sh`, then `python3 -m http.server 8060 --bind 0.0.0.0 --directory build/web`.
2. Put the iPhone and computer on the same trusted Wi-Fi. Open the **computer's LAN address** with port `8060` and path `/index.html` in Safari. The phone's loopback address points to the phone, not the computer. Cloud loopback servers are not exposed by this onboarding UI.
3. Rotate to landscape. Complete the loop below. Ordinary HTTP can test WebGL/input locally, but secure browser persistence/PWA features should be tested using HTTPS.

Free static HTTPS route: follow the [GitHub Pages guide](docs/GITHUB_PAGES.md) to set Pages' source to **GitHub Actions**, merge the pull request, and use the deployment's reported URL with `/index.html`. The included workflow validates pull requests and deploys `main`. Pages on GitHub Free requires a public repository; do not buy an upgrade if a private repository is ineligible. This preparation does not enable Pages, change visibility, or publish a site. Keep all exported assets together; Pages supplies the correct WASM MIME type. Reload once online before testing offline startup, and test physical Safari separately.

Manual acceptance checklist:

- New Game displays $500; Continue is unavailable with no valid save. Fresh-game replacement asks for confirmation.
- Preview one unit, bid against Penny/Rafi/Mo, lose without a charge or win with exactly the winning price deducted.
- Pan with one finger without opening a crate. Pinch inward/outward; tap each crate once to reveal. Check rare-tier color and lid/item animation. Collecting twice must not duplicate items.
- Select one or several items; verify the displayed pawn total equals the credited cash and only sold items disappear.
- Buy appraisal ($75 for tier one), verify the tier/offer improvement, and inspect the financial dashboard. Finish active bidding before buying upgrades.
- Save, close/reopen the browser, Continue, and compare cash, items, XP, upgrades and the partially explored unit. Try another auction after all six crates are collected.
- Check landscape portrait-rotation prompt, readable panels, scrolling long inventory/business lists, notches, touch-target comfort, pinch behavior, responsiveness, heat/memory, and offline PWA behavior on a physical phone.

The stock Godot service worker caches `index.html`, not the directory's root URL. Use the explicit `/index.html` URL for cached offline reloads (the PWA manifest already uses it). A directory URL can launch online but failed offline reload in validation. Targeted startup/platform checks can be repeated with `bash tools/check_browser.sh --platform-only`; the default command keeps the entire gameplay and platform suite enabled.

## Native iOS

The source is prepared for eventual Godot iOS export: no .NET, no web-only game logic, Mobile renderer, landscape configuration, touch controls and `user://` persistence. The exported web shell is the only browser-specific layer.

Native export/signing/device execution is **unrun**. This Linux cloud machine has no macOS/Xcode, iOS SDK, signing team or connected iPhone. Only web export templates were installed. A future native verification task requires a Mac, matching free Godot iOS templates, Xcode and a device. Free Apple personal-team development provisioning may permit testing with its restrictions; App Store distribution is outside this milestone and no paid program may be purchased. Do not claim native iOS support has been validated.

## Scope of evidence

Logic/scene checks and web export are required and run here. Browser checks validate the exported game on desktop Chromium, with mobile-size touch emulation. Physical Safari, native Mobile rendering on an iPhone, native export, audio/accessibility/localization and device performance remain unrun/incomplete. No Phase 2 features or public deployment are part of this milestone.
