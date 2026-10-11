# Storage Wars Sim project rules

- Build an offline, iOS-first, landscape, 3D isometric game in Godot 4.x and GDScript. Keep the native Mobile renderer; use Compatibility for browser exports.
- Use only free tools and original procedural assets. No paid services, assets, dependencies, hosting, or APIs.
- Implement the authorized Phase 1.5 vertical slice; do not implement Phase 2 without authorization. See DEVELOPMENT_PLAN.md.
- Keep systems modular and data driven. Items belong in data/items.json, never individual item scripts. Seed procedural generation.
- Use the existing isolated checkout; do not create Git worktrees unless explicitly requested.
- Preserve touch pan, pinch zoom, tap picking, scalable UI, and eventual native iOS export compatibility.
- Keep game saves offline in user://. Validate untrusted save data and make monetary transactions atomic.
- Run the headless logic and integration tests after gameplay changes. Run an editor import before tests in fresh checkouts.
- Do not claim iPhone Safari or native iOS functionality has been tested without that evidence. Document platform limitations.
- Do not add dependencies or later-phase features merely to fill out the roadmap. Keep reports concise.

Commands and prerequisites are in README.md and TESTING.md.
