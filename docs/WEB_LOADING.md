# Web loading

What ships, how fast it loads, and what is left to cut. Numbers are from the live Pages build (bcccc1d onwards); gz means what GitHub Pages sends (gzip).

## What was done

- **Loader**: `web/shell.html` is the export's custom HTML shell (preset `html/custom_html_shell`). Soot background, brass hairline progress bar, PIXEL BRAWLERS wordmark in text, MB readout, error card. No Godot logo, no engine splash image. Swap the wordmark for logo art when it lands.
- **Boot splash**: `application/boot_splash/show_image=false`, bg soot (`project.godot`).
- **Repeat visits**: `web/pb.service.worker.js` caches `index.html/js/wasm/pck` on the first visit (Godot's stock worker only starts on the second) and each deploy gets its own cache, named from the commit hash (CI fills `__BUILD_ID__`). The shell registers it once the game is running and turns the stock worker off. A new deploy is picked up in the background and used on the visit after. `progressive_web_app/enabled=true` still supplies the manifest and icons.
- **First download**: lossy WebP (quality 0.8) on every fighter texture (a rendered frame differs by at most 25 summed channel levels, no pixel over 30), `addons/gut/*` and the unused `fighters/e/*` dropped from the export.

## Download size (gz, first visit)

| File | Before | Now |
|---|---|---|
| index.wasm | 10.25 MB | 10.25 MB |
| index.pck | 6.96 MB | 1.29 MB (2.0 MB raw) |
| index.js + html + worker | 0.07 MB | 0.07 MB |
| **Total** | **17.28 MB** | **11.62 MB** |

The wasm is now 88 % of the download. Run `python tools/pck_report.py` for the pck by folder: about 2.2 MB, of which `fighters/shared/anims.res` is 1.26 MB, models 0.35 MB, textures 0.42 MB.

## Time to download (computed, not throttled in a browser)

Download time = gz bytes x 8 / bandwidth. Add roughly 1 to 2 s for wasm compile and engine start (estimate, not measured here).

| Link | Before | Now | Repeat visit |
|---|---|---|---|
| 5 Mbps | 27.6 s | 18.6 s | about 2 s (all from cache) |
| 50 Mbps | 2.8 s | 1.9 s | about 2 s |

## Next cuts

1. **Brotli host**: GitHub Pages only serves gzip. Netlify, Cloudflare Pages or Vercel serve brotli, which is usually 20 to 25 % smaller on wasm (about 7.5 MB instead of 10.25 MB) for zero build work.
2. **Custom export template** (not built): `scons platform=web target=template_release optimize=size lto=full` plus disabling modules the game never uses (navigation, both physics engines, gltf at runtime since models are baked, openxr/webxr, enet/websocket/webrtc/multiplayer, mbedtls, theora, text_server_adv in favour of fb) and `wasm-opt -Oz`. Estimate: 25 to 40 % off the wasm, so 10.25 MB becomes about 6 to 7.5 MB gz. It needs emsdk and a 15 to 25 minute CI compile, so it has to run in GitHub Actions; about half a day to wire up and verify. Worth doing once the character art is final.
3. **anims.res** (1.26 MB): drop clips the move set does not use.
