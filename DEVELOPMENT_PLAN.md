# Development plan

## Product boundaries

Free-to-develop, offline single-player, iOS-first landscape 3D isometric management gameplay. Use Godot 4.x, GDScript, modular data-driven systems, and original low-poly geometry or demonstrably free assets. Codex credits are the only permitted expense. Browser testing is a free development route; native iOS remains the intended eventual product. No first/third-person gameplay or paid services.

## Current milestone: Phase 0–1

Phase 0 foundation: organized project, permanent rules, Mobile renderer, Web Compatibility override, isometric camera, touch pan/pinch/tap, mouse alternatives, scalable UI, main menu/New Game/Continue, validated local saves, automated tests, and repeatable setup/export commands.

Phase 1 vertical slice: $500 start, garage/pickup premise and visuals, one interactive six-crate facility unit, procedural shelf/furniture/doors/props, three named budget-driven NPC rivals, bid increments, winning/losing and exact settlement, seeded contents, 60 item definitions, six rarity tiers, item inspection/condition/estimate, explicit inventory collection, atomic pawn sales, XP, two simple upgrade tracks, accounting, replay and bankruptcy recovery. Save partially explored units and active auctions so closing the game does not lose paid discoveries.

Completion gate: import, headless logic checks, integrated scene loop, generated web export, and browser regression tests pass. Physical Safari/native iOS claims need separate real-device evidence. Details and reproducible commands are in TESTING.md. Stop at this gate; subsequent phases require user authorization.

## Full roadmap (future work, not implemented)

| Phase | Scope and targets | Prerequisite / acceptance focus |
| --- | --- | --- |
| 2 — Content and discovery | Expand toward 750+ items in 40+ categories and 25+ storage themes; restoration, cleaning, authentication, appraisal depth, collectible sets, achievements, rare/legendary/mythic discoveries | Authorize Phase 2; reusable schemas and versioned save migrations; maintain balanced seeded distributions |
| 3 — Town and transport | 12 expandable districts, 40+ vehicles, capacity/operating costs/upgrades, warehouses, cargo jobs, automated delivery routes and fleets | Native mobile profiling, durable item ownership across transfers, pathfinding and simulation budgets |
| 4 — Retail operations | Pawn shops, flea stalls, retail stores/workshops, shelves/displays/checkouts, customers, store customization, stockers/appraisers/mechanics, employees/managers/drivers | Transaction ledger, simulation tick model, staffing and UI usability |
| 5 — Economy and society | Dynamic supply/demand, negotiated prices, business expenses, rival businesses, random events, 150+ named NPCs with personality/relationships/rivalries/preferences | Deterministic economy rules, fair progression and save compatibility |
| 6 — Progression and identity | Full 100-level progression balance, 200+ quests/procedural mission templates, area unlocks, avatar customization in menus/auctions/events | Content authoring tools and progression coverage; avoid bespoke scripts per content entry |
| 7 — Offline operations and release quality | Bounded offline earnings, financial dashboard expansion, accessibility/localization/audio, memory/FPS/battery profiling, native iOS packaging and lifecycle testing | Real iPhone measurements, clock-change handling, save migration/backup tests and free-tool constraints |

## Architectural growth

Extend item/theme/NPC/vehicle data and shared generators rather than copying item scripts. Keep auction generation deterministic from seed plus serial. Add separate transport, retail, quest, relationship, and offline-tick systems only when their phases are authorized. Inventory UID ownership and atomic economy changes form the foundation for future transfer/ledger systems.

Cash profit/loss currently means accumulated sale revenue minus all auction purchases and upgrade spend; it does not allocate per-item cost basis or mark unsold stock to market. Appraisal improves estimates and pawn offers. Auction access improves rarity odds and increases opening prices. Level calculation supports a cap of 100, but this milestone does not provide 100 levels of authored content. Garage clear-out is a limited bankruptcy escape, not a production/idle-income business.

## Known follow-up work

Confirm physical iPhone Safari UI targets, notch/safe-area behavior, PWA offline storage, thermal performance and touch gestures. Profile/merge static meshes before scaling the town. Validate the native Mobile renderer and iOS export on macOS/Xcode with free development provisioning where supported. Public/App Store distribution is not included, and no paid account or service may be purchased. Complete separate platform verification before release claims.


## Authorized Phase 1.5 vertical slice

The October 11, 2026 request authorizes the gameplay overhaul described in [docs/PHASE_1_5.md](docs/PHASE_1_5.md): direct mobile navigation, competitive auctions, featured procedural silhouettes, eight themes, two town districts, two garage tiers, functional upgrades, pickup capacity/costs, preparation, milestones and validated v1 save migration. Later districts and garage tiers are data only. Phase 2 remains unauthorized.
