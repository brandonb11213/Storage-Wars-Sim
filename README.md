# Storage Wars Sim

An offline, landscape, 3D isometric storage-auction game built with Godot 4.6.3 and GDScript. Phase 0–1 is the current milestone; the larger business simulation is planned, not implemented. All visuals are original procedural meshes and materials. No external assets, APIs, services, or paid dependencies are used.

## Play the milestone

1. Choose **New Game** to start with $500, a garage, and an old pickup. **Continue** restores local progress. Starting fresh requires confirmation when a save exists.
2. Preview the six sealed crates and choose **Enter auction**. **Bid** raises the price by $10; the three rivals reply after a short pause. **Pass / finish auction** resolves the remaining bidding. Cash is charged only when you win.
3. Tap a 3D crate, inspect its rarity, condition, estimated market value, and pawn offer, then **Collect to inventory**. Collect all six before starting another unit.
4. Open **Inventory / Pawn**, select items individually or select all, and sell. The shown offer is the exact cash payment.
5. Open **Business** to view cash profit/loss and purchase appraisal or auction-access upgrades. Upgrades are unavailable while bidding.
6. Save, return to the menu, continue, and repeat. Every mutation also autosaves. A garage clear-out recovery job becomes available when inventory is empty and cash is below auction funding ($35 or the current opening bid, whichever is higher).

Touch: tap crates and buttons, drag the world to pan, pinch to zoom. Desktop: left-click/drag and mouse wheel. The bottom bar also has zoom and recenter buttons. Scroll the right panel to reach longer inventory and business lists.

## Develop and run

Prerequisites: Godot **4.6.3 standard** (not .NET), Bash, Python 3, curl, unzip, and SHA-512 tools. Godot is free. No package manager or third-party game dependencies are needed.

```bash
cd /workspace/Storage-Wars-Sim
bash tools/setup_env.sh
source tools/env.sh
godot --editor --path .
# Run from the editor with F6/F5, or on a machine with a graphical display:
godot --path .
```

The setup script reuses the pinned installed editor or installs a checksum-verified official editor. It installs only the matching single-threaded web templates from the checksum-verified official archive. The archive download is about 1.25 GB; retained web templates are about 19 MB. Runtime/cache/config files live under `/workspace/.runtime`, outside the checkout. Set `STORAGE_WARS_RUNTIME` before sourcing `tools/env.sh` to use another writable directory on your own machine.

The native project uses the **Mobile** renderer. Its **Web** override uses **Compatibility**, because Godot browser exports require WebGL 2. This does not change the native renderer. Landscape layout, procedural geometry, touch events, and GDScript avoid a browser-only game architecture.

## Validate and export

```bash
bash tools/check.sh
bash tools/export_web.sh
python3 -m http.server 8060 --bind 0.0.0.0 --directory build/web
```

Serve the entire `build/web` folder and use its explicit `/index.html` path for offline caching; do not open `index.html` as a local file. Stop the server with Ctrl+C. `build/` and `test-results/` are ignored generated outputs. The static build needs no backend and supports cached offline play after its first successful online load. See [TESTING.md](TESTING.md) for validation results, browser regression testing, and free iPhone Safari testing instructions. No public deployment has been performed.

For background cloud startup with HTTP readiness checks, run `bash tools/start_web.sh`. Logs and the server PID are stored under `/workspace/.runtime`. Use `STORAGE_WARS_PORT=8062` to choose another port when needed; preserve unrelated services. Only stop a background server after verifying its recorded PID belongs to the server you started.

## Architecture

| Component | Responsibility |
| --- | --- |
| `GameState` | Cash, inventory, progression, active unit, counters, stable IDs and seed |
| `AuctionManager` | Opening bid, three NPC strategies, affordability and settlement |
| `ItemDatabase` | 60 JSON definitions, six rarity tiers, conditions and estimates |
| `StorageUnitGenerator` | Seeded themes and six-item storage units |
| `InventoryManager` | Reveal/collect ownership rules and duplicate prevention |
| `EconomyManager` | Explicit pawn offers, atomic sales and cash profit/loss |
| `ProgressionManager` | XP/levels and three tiers of two upgrades |
| `SaveManager` | Versioned, schema-validated, checksummed local saves and backup recovery |
| `TouchCameraController` | Orthographic isometric camera, pan, pinch, tap, smooth focus |
| `StorageFacility` / `LootBox` | Procedural environment, physics picking and reveal animations |
| `main.gd` | Scene integration, scalable UI and autosave orchestration |

Save data lives at `user://storage_wars_save.json` with a `.bak` fallback and temporary atomic-write file. In this cloud setup, native test data is under `/workspace/.runtime/data/godot/app_userdata/Storage Wars Sim`; web data lives in the browser's IndexedDB. Saves persist cash, inventory, XP, upgrade tiers, accounting, seed/IDs, and partially explored or active auctions. Clearing site data removes browser progress. The checksum detects corruption; it is not anti-cheat encryption. Schema version 1 has no migration from future versions.

Implemented: complete initial loop, 60 discoveries across six rarities, one interactive cutaway unit and decorative adjacent bays, procedural furniture/props/pickup, three named rivals, two upgrade tracks, local save/load and financial dashboard. No external connectivity is required by gameplay.

Incomplete by design: functioning transport/garage management, business premises and staffing, fleets/routes, restoration/authentication, quests, town districts, collections, avatar customization, dynamic demand, offline earnings, and the larger content targets. Native iOS export, physical iPhone testing, audio, accessibility screen-reader support, localization, and measured device performance are not validated or completed. See [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md). Do not start Phase 2 without authorization.
