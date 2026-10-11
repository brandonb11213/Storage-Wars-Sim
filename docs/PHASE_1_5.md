# Phase 1.5 gameplay overhaul

This change extends the existing Godot 4.6.3 game. It keeps offline single-player saves, procedural art, native Mobile rendering, Compatibility web exports and the existing GitHub Pages workflow. Phase 2 is not implemented.

## Playable loop

New Game opens the town. Tap buildings or use the seven direct navigation buttons: Map, Auctions, Home, Inventory, Selling, Upgrades and Business. Preview a unit, compete against three randomly selected rivals, win or walk away, inspect and collect discoveries, sell or prepare them, buy equipment and expand into Suburban Storage.

Navigation uses equally sized buttons with camera controls in a separate row. The web shell fits the canvas inside Safari safe-area insets and uses dynamic viewport height. Long activity panels scroll vertically. Inspection buttons provide another route to each discovery when a camera position makes tapping a crate difficult.

## Town and home

The starter neighborhood contains a garage, storage facility, pawn shop, connecting roads, houses, trees, streetlights and a moving pickup. Buildings use physics picking to open activities. Purchasing the Suburban permit adds the second district to the map, connected by a road. The suburban scene has a larger, differently colored storage building, higher opening bids and a specialized theme mix. Travel is blocked while bidding or while paid items remain uncollected.

The cutaway home contains shelving, stored item models, a workbench, an office, a display area, a driveway and the old pickup. Selecting an inventory item lets the player display it at home; selling it clears that display. The Expanded Garage adds a wider building and more shelving. Equipment purchases appear at home, and the cargo rack appears on the pickup. Only the first two home tiers and first two districts are built; all five tiers and twelve districts are represented in progression data. Locked markers and the map panel show future expansion.

## Auctions and discoveries

Eight theme definitions weight item categories and set the unit's visible prop palette and public appraisal clues: Household Clutter, Electronics, Garage Tools, Vintage Collectibles, Furniture, Sports Memorabilia, Abandoned Workshop and Premium Mystery Unit. Six collectible slots stay consistently tappable while visible items, covered scenery and background props change.

Featured treasure probabilities are configured in `data/gameplay.json`: 65% ordinary, 25% interesting, 8% premium and 2% exceptional. These are probabilities, not a cycle or a guaranteed reward. Examples include a procedural motorcycle, arcade cabinet, tool chest, TV, gaming PC, safe, luggage, guitar, covered project car, jewelry case, sports display, vending machine, boat motor and collector cabinet. Two ordinary slots also expose silhouettes. Three other slots stay boxed. Only the silhouette is shown before winning; condition and exact resale value stay hidden. Covered background props are scenery and do not promise an additional collectible.

A featured item can be severely damaged or incomplete: featured values vary independently of their impressive appearance. Hidden slots can contain valuable ordinary-looking discoveries. Rare and better reveals receive a longer animated presentation and a rarity-colored ring; ordinary reveals are shorter. The inspection panel identifies rarity, condition, featured status, description, cargo size, estimate and actual pawn offer. Discovery counts, unique set members and milestone rewards persist.

Three of six archetypes attend each auction: Conservative Reseller, Aggressive Collector, Professional Dealer, Bargain Hunter, Wealthy Enthusiast and Risk-Taking Gambler. Each has available cash, a noisy appraisal, a maximum bid, category interests, risk tolerance and a walk-away rule. Visible vehicles and electronics can increase an interested rival's estimate. Hidden item values and conditions never enter NPC appraisal; a regression test changes hidden values while keeping public clues constant and requires identical rival budgets.

## Functional purchases

All purchases have level requirements, costs, a real gameplay effect, a maximum tier and save persistence. Spending is blocked during bidding.

| Upgrade | First cost | Effect / requirement |
| --- | ---: | --- |
| Appraisal desk | $75 | Better estimates; +4 percentage points to pawn offers per tier; 3 tiers |
| Auction pass | $120 | Improved rarity odds and higher opening bids; 3 tiers |
| Storage shelving | $90 | +12 cargo spaces per tier; 2 tiers |
| Expanded garage | $300 | Visible additional garage wing; +18 cargo spaces; level 2 |
| Cleaning station | $100 | Worn/Fair to Good; +20% value; pay 8% of current value, minimum $2 |
| Restoration bench | $220 | Good to Pristine; +25% value; pay 15%, minimum $2; level 2 and cleaning |
| Pickup cargo rack | $160 | Pickup capacity 6 → 12; visible rack; fewer trips |
| Resale counter | $130 | +5 percentage points to pawn offers per tier; level 2; 2 tiers |
| Showroom sign | $200 | +10 percentage points to Rare or better offers; level 2 |
| Dispatch desk | $180 | $2 less per transport trip; level 2 |
| Suburban permit | $250 | Second district; level 3 and Expanded Garage |

Starter home capacity is 24 cargo spaces. Items use 1–6 spaces. The pickup carries 6 per trip; each trip costs $6 in the neighborhood or $8 in the suburbs before dispatch equipment. The bid interface quotes the number of trips and total fee. Every bid reserves sufficient cash for transport. Settlement atomically charges the winning price and all quoted trips, so collecting owned items does not cause another unexpected bill. Collecting requires free home storage; selling existing items or buying shelving lets a full garage resume collection without discarding paid winnings. Transport is management only: there are no driving controls, fleets or automated routes.

Sales, auction costs, transport, preparation, upgrades and quest rewards are tracked separately. Operating cash profit excludes quest rewards; business value is cash plus current pawn offers plus purchased equipment at cost. Cleaning and restoration cannot be repeated on the same condition. A free garage clear-out job is available only with empty inventory, insufficient auction funding and no active/owned unit. Its tool lot sells for at least $220 (more when a high-tier opening and transport require it), restoring a useful auction budget, and holding the recovery item blocks additional jobs.

## Progression and saves

Experience drives levels. Seven automatically rewarded milestones introduce the first win, rare discovery, $1,000 cumulative sales, garage expansion, second district, vehicle upgrade and three distinct shelf classics. Rewards are paid once and saved.

Version 2 saves retain the existing checksum, bounded schema validation, temporary atomic write and validated backup. Version 1 envelopes are validated against the previous schema before migration. Money, IDs, inventory, upgrades, auction stage and partial reveals/collections survive migration. Old paid units receive no retroactive transport charge. Existing inventory is preserved even if it exceeds the new capacity; sell stock to free space. New fields and upgrades receive safe defaults. Future versions, invalid IDs, duplicate ownership/rewards, negative balances and malformed nested data are rejected.

## Reproducible validation

Run:

```bash
source tools/env.sh
bash tools/check.sh
bash tools/export_web.sh
python3 tests/validate_web_export.py build/web
bash tools/check_browser.sh --base-path /Storage-Wars-Sim
```

The required check includes editor import, gameplay/scene integration and the production-system economy simulation. Results are written to ignored `test-results/` files. The simulation uses fixed seeds 1–1,000 twice, plus 100 forty-auction sessions and 100 initially bankrupt recovery fixtures. It runs actual GDScript auction, inventory, economy, progression and save validation code; it does not hardcode a player win rate or alter auction outcomes.

Web saves explicitly request IndexedDB synchronization after the atomic rename.

Recorded headless validation: **12,378 gameplay/scene checks and 16,789 simulation checks; zero failures**. The release export and Pages package validation pass. The full browser result is recorded in TESTING.md after completion.

| Seeded strategy | Auctions | Win rate | Average winning price | Average profit per won unit | Loss frequency among wins |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cautious: ceiling 55% of public estimate | 1,000 | 4.0% | $128.13 | $329.05 | 17.5% |
| Speculative: ceiling 140% of public estimate, bounded by cash and transport | 1,000 | 82.9% | $249.37 | $124.20 | 43.1% |

Observed featured counts: **636 ordinary, 273 interesting, 74 premium, 17 exceptional**. All eight themes occurred. Across each strategy's sample, 65 units had a rival's limit beyond the initial wallet after transport. Both strategies had five wins at $80 or less.

In the 100 sessions with an 80% ceiling and first-tier purchases while retaining $100, all 100 expanded the garage and unlocked the second district within 40 auctions. The median second-district unlock was auction 6.5; every session bought its first upgrade after auction 1. These are auction counts, not measured play time. At an assumed 45–75 seconds per loop, that median is roughly 5–8 minutes; manual pacing still needs evaluation. The strategy used 279 low-funding jobs, all of which restored the bidding reserve. All 100 zero-cash fixtures recovered useful auction funding with one job, and a second job was rejected while its item remained held. A maximum-wallet strategy then won 39 of those 100 auctions naturally; recovery funds do not force a win.

## Known limits and next verification

Physical iPhone Safari, native iOS export and measured device FPS/memory are unrun. Chromium uses software WebGL and touch emulation; safe-area tests simulate canvas insets. Use a physical iPhone to check Safari chrome changes, notches, heat, memory, input and IndexedDB persistence. No new deployment or merge is performed by this task; the unchanged Pages workflow deploys only after changes reach main.

The exceptionally conservative ceiling rarely wins; the high ceiling overpays often. Further economy tuning should use real play sessions and these reproducible reports. There is no elapsed-time or sell-through market simulation: pawn sales remain instant. Districts 3–12 and home tiers 3–5 are data-only. Staff, multiple vehicles, fleets, routes, manual driving, advanced restoration/authentication, dynamic demand, offline earnings, audio and localization are not implemented. Item silhouettes use inexpensive primitive meshes, covered props are decorative, and unit slots retain a stable six-crate layout. This is the Phase 1.5 vertical slice.

## iPhone Safari acceptance

1. Check out the branch, run the commands above, then serve the **entire** `build/web` directory. For local WebGL/input testing, use `python3 -m http.server 8060 --bind 0.0.0.0 --directory build/web` on a computer on the phone's Wi-Fi, then visit `http://COMPUTER-LAN-IP:8060/index.html`.
2. Use the existing GitHub Pages HTTPS `/Storage-Wars-Sim/index.html` entry for secure persistence/offline checks once the PR is reviewed, merged and deployed. The single-threaded build needs no isolation headers. Keep the explicit `/index.html` path for offline reloads.
3. In landscape, tap all seven tabs, especially **Upgrades**, on the smallest supported screen and with Safari chrome shown/hidden. Pan, pinch and tap each town building.
4. Visit home, preview an auction and set a budget. Test a loss with no cash charge and a win with exactly the price plus transport deducted, then separately account for any milestone reward.
5. Inspect all six discoveries, sell selected items, prepare a Worn/Fair item after buying cleaning equipment, display a find at home and expand the garage. Check the changed geometry, capacity, pickup rack and finances.
6. Reach level 3, expand the garage and buy the $250 permit. Visit the suburban district, save, reload and Continue. Confirm the new map, upgrades, stock, finances and any unfinished unit survive.
7. Load once online, reload and Continue with connectivity disabled. Clearing site data removes local progress. Physical Safari results should be recorded separately from browser emulation.
