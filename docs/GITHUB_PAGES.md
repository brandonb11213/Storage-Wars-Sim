# Free GitHub Pages hosting and iPhone Safari

The existing Phase 0–1 game is a static Godot 4.6.3 export. No backend, paid service, or gameplay change is needed. The workflow in `.github/workflows/pages.yml` imports the project, runs the headless game/scene suite, exports the existing Web preset, validates the package, and uploads all files together. It deploys only from `main`; pull requests build and validate without deploying. Actions are pinned to exact commits and Godot downloads retain SHA-512 verification. The first build downloads the official template archive (about 1.25 GB); subsequent builds reuse cached tools/templates. Generated builds remain outside Git history.

## Enable free hosting

1. Check repository visibility and plan first. **Public repositories support Pages on GitHub Free.** If this repository is private and Pages asks for a paid plan, stop: do not purchase anything or change visibility without the owner's decision. A separate public repository containing the static export is also a free route, if the owner chooses it. This change does not alter repository visibility or billing.
2. In [repository Pages settings](https://github.com/brandonb11213/Storage-Wars-Sim/settings/pages), set **Build and deployment → Source → GitHub Actions**. Ensure repository Actions are enabled.
3. Merge the implementation/hosting pull request into `main` using **Create a merge commit** to retain the original `eee301c` commit identity. The push triggers **Validate and deploy web game**. For a later redeploy, choose **Actions → Validate and deploy web game → Run workflow**, with branch `main`.
4. Wait for both `build` and `deploy` to pass. Use the deployment's reported HTTPS URL. With the repository's current name and no custom domain, the expected game entry is **https://brandonb11213.github.io/Storage-Wars-Sim/index.html**. This URL is available only after a successful deployment; preparing the workflow does not publish the site.

No custom domain, account upgrade, or paid service is required. A project site must retain `/Storage-Wars-Sim/` in its asset paths. The exporter already uses relative paths, and the workflow uploads the complete `build/web` directory. `.wasm` must have MIME type `application/wasm`; GitHub Pages supports it. `_headers` files do not configure HTTP headers on Pages.

## Cross-origin isolation

The existing preset deliberately uses `variant/thread_support=false` and `variant/extensions_support=false`, with the Web Compatibility renderer. The exported HTML confirms `GODOT_THREADS_ENABLED=false`. This build does **not** require SharedArrayBuffer, `Cross-Origin-Opener-Policy`, or `Cross-Origin-Embedder-Policy`. Both `progressive_web_app/ensure_cross_origin_isolation_headers` and the generated worker's corresponding option remain false. This avoids adding an isolation reload or a third-party worker to a working single-threaded game. The package validation rejects a threaded export or a new isolation dependency before deployment.

GitHub Pages does not offer arbitrary response-header configuration. If threads are authorized in a future task, Godot's built-in PWA isolation-header worker or a host that supplies COOP/COEP must be evaluated and tested on target browsers before that change. Keep the current single-threaded configuration for this milestone.

## Run on iPhone Safari

1. Use current iOS/Safari (the template requires Safari 15.2 or later). Open the deployment's HTTPS **`/Storage-Wars-Sim/index.html`** URL in normal Safari and rotate to landscape. Keep the complete path, including `index.html`.
2. Wait for the first download to finish, then tap **New Game**. Tap buttons/crates; drag the world to pan and pinch to zoom. Inventory and Business panels scroll. **Continue** restores this browser's local save.
3. After the first successful online load, reload **once while still online** so the PWA worker controls and caches the engine files. Optionally choose **Share → Add to Home Screen**. Before relying on offline play, close/reopen, check Continue, then disable networking and confirm the explicit `index.html` entry still starts.
4. Saves remain in this browser's local storage/IndexedDB. Safari can evict site data; private browsing, clearing website data, or moving to another origin can remove or separate progress. Test normal Safari and the Home Screen app separately rather than assuming their storage is shared.

The browser regression suite can emulate the Pages project path:

```bash
source tools/env.sh
bash tools/check.sh
bash tools/export_web.sh
python3 tests/validate_web_export.py build/web
bash tools/check_browser.sh --base-path /Storage-Wars-Sim
```

This checks a real Chromium/WebGL game, offline caching, project-relative assets and worker scope, saves, and landscape touch/pinch input. It does not establish physical Safari performance or native iOS compatibility. Follow the manual device checklist in [TESTING.md](../TESTING.md). No Phase 2 work is included.
