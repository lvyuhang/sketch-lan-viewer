# Sketch View 0.6 · Performance architecture

## Problem (measured 2026-11-05 Asia/Shanghai)

- Sketch main thread dominated by `COSInterval` → CocoaScript `setInterval` → `mirrorTick` → `runFrameCheck('poll')` → `resolveTargetArtboard()`.
- Even with “idle skip” (no `sketch.export`), walking the doc through Mocha boxing burned CPU (sample: ~100% of main-thread samples in COSInterval; Sketch 170–590% CPU, 6–9 GB).
- Disabling the plugin in `plugins.plist` **does not** clear an already-running `setInterval`. Restart Sketch is required.
- 3× PNG export + in-plugin SHA-256 on ~1.4 MB frames: export ~150 ms + hash ~200–370 ms on main thread.

## Target (user-agreed)

1. Event-driven dirty flags — **no** Sketch-main-thread `setInterval` that exports or resolves artboards.
2. Heavy work off Sketch: daemon hashes / optional WebP / WS broadcast; plugin only produces pixels when dirty.
3. Incremental + budget: current board only; drop frames if busy; lo-res then hi-res when idle (not longer poll).
4. Hard main-thread budget for plugin JS.
5. LayerPilot stays isolated (no shared timers).

## Constraint (honest)

Live **unsaved** pixels can only be produced inside Sketch via `sketch.export`. `sketchtool` reads on-disk `.sketch` and cannot see unsaved edits. So “export off process” means:

- **When** export runs: dirty/event/phone only — never poll.
- **What** leaves Sketch: raw PNG POST; hash + broadcast (+ future WebP) on Node daemon.
- Future optional: saved-file `sketchtool` path for offline/batch — not live mirror.

## 0.6 design

```
Selection/Artboard/Text/Layers* ──► mark dirty + rev++ ──► debounce ──► export(scale)
Phone /select JSON (light file poll) ──► if changed only ──► same export path
Idle hi-res: setTimeout once after quiet window (same rev) — not setInterval
Daemon: SHA-256 dedupe + WS; plugin skips hash
```

- Remove `setInterval(mirrorTick)`.
- Keep a **light** phone-select file poll (read tiny JSON only; no DOM walk unless changed).
- Default preview scale **1x**; schedule **2x** once after idle if rev unchanged and last export under budget.
- `EXPORT_BUDGET_MS` / drop if `sending`; write `export-queue.json` job meta for observability.

## Meme diagnosis incorporated (2026-11-05)

1. `plugins.plist` disabled ≠ unload — running Sketch keeps COSInterval until ⌘Q.
2. Two intervals burned main thread: MIRROR (~1.2s) + PHONE_SELECT (~0.25–0.35s), even if :9777 is dead.
3. Idle skip still costs CPU (timer + `resolveTargetArtboard` Mocha boxing); 3x+hash on selection = hundreds ms–1s+.
4. ~201MB / 16-page doc amplifies; LayerPilot is not the main cause.
5. 0.6 must: Stop/disable clears **both** intervals; **no** phone poll when phone disconnected; light dirty before export; catalog throttle; hash/broadcast off-process.

