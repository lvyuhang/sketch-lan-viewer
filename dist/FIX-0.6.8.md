# 0.6.8 — 切换 Sketch 文件后手机仍不更新（续）

## 为何 0.6.7「装了」却仍失败

1. **Sketch 进程未重启**：磁盘已是 0.6.7，但 `Sketch` 自 2026-11-06 起一直在跑，JS 上下文仍是 **arch=0.6.6**（Plugin Log 可证）。CocoaScript 不会在覆盖插件文件后自动热加载。
2. **现场日志仍是 0.6.6 误杀**：切到另一文件的 Page（如 `v2.0.2 · 架构设计交付`）时反复出现 `previous artboard deleted; keeping last phone frame (suppressed …)`，正是 ADR-011 + `artboardExistsOnPage` 跨文档误判。
3. **切已打开文件的 tab 不发 `OpenDocument`**：0.6.7 虽在 OpenDocument 里清状态，但用户只切换窗口/tab 时常常走不到该 handler，只能靠 frame-check / stale。

## 0.6.8 改动

- 保留 0.6.7 的 `applyDocumentContext` / 整文档 `findArtboardById` 删除判断。
- **`probeSelectedDocumentContext`**：`stale` 心跳与 `runFrameCheck` 在 resolve **之前**探 `getSelectedDocument().id`（不依赖 OpenDocument）。
- 切文档后 **`forceNextFrame`**（`x-force-frame`）+ 强制 `maybePostCatalog(true)`，避免 daemon 去重 / 旧 catalog。
- 删除抑制抽成 **`shouldSuppressArtboardSwitch`**（可单测）。
- 写入 `~/.sketch-lan-mirror/plugin-arch.json`，便于确认内存里是否已是新版本。

## 验证（必须先完全退出再开 Sketch）

1. 看 Plugin Log / `plugin-arch.json` 是否为 `arch=0.6.8`（若仍是 0.6.6/0.6.7 说明没重启成功）。
2. 文件 A 选画板 → 手机显示 A。
3. 切到已打开的文件 B，选画板 → ≤2s 内手机跟到 B（无需点菜单）。
4. 同文件删画板：仍保持删前最后一帧。
