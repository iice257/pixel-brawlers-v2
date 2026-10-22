# Online play and mobile

## Online (menu: ONLINE)

Peer-to-peer GGPO-style rollback over the deterministic 60 Hz sim: local input delay 2 frames, rollback window 8 frames (the match stalls
rather than predict further), redundant input packets, and a state checksum exchanged every few frames to detect desync. Code: `net/`.

| Platform | Transport | Room code |
|---|---|---|
| Windows / Android | UDP (`net/udp_transport.gd`) | 11 characters that encode the host's IPv4 address and port (default UDP 7777). Same network, or forward UDP 7777 on the host's router. |
| Web | WebRTC data channel (`net/rtc_transport.gd`) through the signalling relay | 4 letters from the relay |

The host is player 1, the guest player 2; the host's fighter pick, stage and RNG seed are sent in the handshake. Pause is an overlay only (the match keeps running).

### Signalling (web only)

Browsers swap WebRTC setup messages through a signalling backend chosen in `data/net.json` (`net/net_config.gd`):

- `{"signal_type": "http", "signal_url": "https://..."}`: `python tools/signal_server.py [port]`, a stdlib-only relay (rooms live 15 minutes). Needs an HTTPS host for phones.
- `{"signal_type": "supabase", "url": "https://<project>.supabase.co", "anon_key": "<anon public key>"}`: a Supabase Realtime broadcast channel `redline-<ROOM>`, no server code (free tier is enough, broadcast needs no tables).

`--signal=<url>`, `?signal=<url>` or `[online] signal_url` in `user://settings.cfg` override the file with an HTTP relay. With nothing configured the web build says "no signalling server".
Desktop WebRTC would need the webrtc-native extension (deferred), so desktop and Android use UDP.

### Testing

- `GODOT=<exe> sh tools/net_selftest.sh [latency_ms] [matches] [loss]` plays full matches between two headless processes over real UDP.
- `tests/test_netplay.gd` runs 3 matches in-process at 100 ms one-way latency, jitter plus loss, 200 ms stalls and a corrupted-state case.
- `--netlag=<ms>` adds simulated latency to the lobby's links for manual tests.

## Mobile

On a phone or tablet (Android, iOS, or `(pointer: coarse)` in a browser) the fight shows touch controls in the REDLINE HUD style: a floating stick on the
left half (left/right walk, up jump, down crouch), L M H S in an arc under the right thumb, THROW and BLOCK, and a pause button under the health bar.
Force them with `?touch=1` in the web build or `--touch` on desktop (the mouse then acts as a finger). Orientation is locked to landscape.

### Android APK

An `Android` preset is in `export_presets.cfg` (arm64, debug keystore, prebuilt template, no Gradle). `.github/workflows/release.yml` builds it with the runner's JDK and Android SDK
and publishes `Redline-android-debug.apk` next to the Windows zip on the `latest` release: install it from there on the phone (allow installs from the browser/Files app).
Local build needs a JDK 17, the Android SDK, the 4.7.2 export templates and a debug keystore set in Godot's editor settings, then
`godot --headless --path . --export-debug "Android" build/android/Redline-android-debug.apk`.
