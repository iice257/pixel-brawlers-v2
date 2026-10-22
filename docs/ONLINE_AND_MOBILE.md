# Online play and mobile

## Online (menu: ONLINE)

Peer-to-peer GGPO-style rollback over the deterministic 60 Hz sim: local input delay 2 frames, rollback window 8 frames (the match stalls
rather than predict further), redundant input packets, and a state checksum exchanged every few frames to detect desync. Code: `net/`.

| Platform | Transport | Room code |
|---|---|---|
| Windows / Android | UDP (`net/udp_transport.gd`) | 11 characters that encode the host's IPv4 address and port (default UDP 7777). Same network, or forward UDP 7777 on the host's router. |
| Web | WebRTC data channel (`net/rtc_transport.gd`) through the signalling relay | 4 letters from the relay |

The host is player 1, the guest player 2; the host's fighter pick, stage and RNG seed are sent in the handshake. Pause is an overlay only (the match keeps running).

### Signalling relay (web only)

`python tools/signal_server.py [port]` is a stdlib-only relay (rooms live 15 minutes, carries only connection setup). Browsers need an HTTPS host for it.
Point a build at it with, in order of precedence: `--signal=<url>`, `?signal=<url>` in the page address, `[online] signal_url` in `user://settings.cfg`,
or `signal_url` in `data/net.json`. Until one is set the web build shows "no signalling server" on HOST / JOIN. Desktop WebRTC would need the
webrtc-native extension, so desktop and Android use UDP instead.

### Testing

- `GODOT=<exe> sh tools/net_selftest.sh [latency_ms] [matches] [loss]` plays full matches between two headless processes over real UDP.
- `tests/test_netplay.gd` runs 3 matches in-process at 100 ms one-way latency, jitter plus loss, 200 ms stalls and a corrupted-state case.
- `--netlag=<ms>` adds simulated latency to the lobby's links for manual tests.

## Mobile

On a phone or tablet (Android, iOS, or `(pointer: coarse)` in a browser) the fight shows touch controls in the REDLINE HUD style: a floating stick on the
left half (left/right walk, up jump, down crouch), L M H S in an arc under the right thumb, THROW and BLOCK, and a pause button under the health bar.
Force them with `?touch=1` in the web build or `--touch` on desktop (the mouse then acts as a finger). Orientation is locked to landscape.

### Android APK

An `Android` preset is in `export_presets.cfg` (arm64, debug keystore, no Gradle). To build: install a JDK 17, the Android SDK (platform-tools, build-tools, platform 34),
set `export/android/java_sdk_path`, `android_sdk_path` and a debug keystore in Godot's editor settings, install the 4.7.2 export templates, then:

    godot --headless --path . --export-debug "Android" build/android/redline-debug.apk
