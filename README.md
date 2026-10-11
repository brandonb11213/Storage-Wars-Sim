# Storage Wars Sim

An offline, landscape, 3D isometric storage-auction game built with Godot 4.6.3 and GDScript. Phase 1.5 is the current vertical slice; future business systems remain planned. All visuals are original procedural meshes and materials. No external assets, APIs, services, or paid dependencies are used.

## Play Phase 1.5

Start with $500, a starter garage and a pickup. Explore the town using tappable buildings or the seven direct tabs: **Map, Auctions, Home, Inventory, Selling, Upgrades, Business**. Inspect visible auction clues, bid against three of six imperfect NPC archetypes, then discover and transport winnings, sell or prepare items and build your garage business. Winning requires funding both the bid and the displayed transport fee; some units are poor investments. Free recovery work is available when stock and auction funds run out.

Buy shelving, appraisal, cleaning/restoration equipment, a cargo rack and business upgrades. The $300 garage expansion requires level 2; the $250 Suburban permit requires level 3 and that garage. Unlocking the second district adds a connected area to the town. Changes save locally after every mutation, and version 1 saves migrate without dropping existing items or paid auction progress.

Touch: tap buildings/crates/buttons, drag the world to pan, pinch to zoom. Desktop: click/drag and mouse wheel. Camera controls are above the world; activity panels scroll. **Upgrades** has its own always-accessible bottom button. The web canvas respects Safari safe areas.

See [the implementation report](docs/PHASE_1_5.md) for features, upgrade effects, economy results, known limits and iPhone testing steps.

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

For free HTTPS hosting, the [GitHub Pages guide](docs/GITHUB_PAGES.md) explains the included build/deployment workflow, repository settings, cross-origin isolation configuration, and the exact iPhone Safari entry path. Pull requests validate the export; `main` deploys after Pages is configured. The existing single-threaded export needs no COOP/COEP headers.

For background cloud startup with HTTP readiness checks, run `bash tools/start_web.sh`. Logs and the server PID are stored under `/workspace/.runtime`. Use `STORAGE_WARS_PORT=8062` to choose another port when needed; preserve unrelated services. Only stop a background server after verifying its recorded PID belongs to the server you started.

## Architecture

The existing managers remain the foundation: `GameState`, `AuctionManager`, `ItemDatabase`, `StorageUnitGenerator`, `InventoryManager`, `EconomyManager`, `ProgressionManager` and `SaveManager`. New `GameplayData` loads unit themes, treasure probabilities, eleven upgrades, twelve districts and five home tiers from `data/gameplay.json`; 74 item definitions live in `data/items.json`. `TransportManager` quotes trips/costs and storage capacity. Reusable procedural meshes build storage previews, home equipment and district scenes. `main.gd` connects the UI, touch camera, physics picking, autosaves and milestones.

Saves live at `user://storage_wars_save.json`, with a validated `.bak` fallback and temporary atomic-write file. Browser saves use IndexedDB. Version 2 validates and migrates version 1. Clearing site data deletes progress. The checksum detects corruption; it is not anti-cheat encryption.

Only home tiers 1–2 and districts 1–2 are built. Phase 2 remains unauthorized. Physical Safari, native iOS and measured device performance still need testing; see [TESTING.md](TESTING.md).
