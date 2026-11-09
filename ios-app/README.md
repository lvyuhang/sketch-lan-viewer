# LanViewer (iOS)

Native fullscreen Sketch preview client for 览LAN / sketch-lan-mirror.

- Wi‑Fi: connect to Mac LAN URL
- USB: Peertalk reverse forward via `mac-usb-helper` (no jailbreak; not iproxy)

See **README.zh.md** for install / run order (Chinese).

## Session crash fix (1.1.1 / build 3)

`MirrorClient` uses `SessionLifetime` generation gating so catalog/poll workers never call `URLSession` after `invalidateAndCancel` (was SIGABRT). Unit tests: `cd ios-app/MirrorSessionKit && swift test`.
