# 0.6.7 — 切换 Sketch 文件后手机跟选

## 根因（用户：「切换文件后手机无法跟随选中；貌似只会更新第一个文件」）

1. **删除抑制（ADR-011）误判跨文档选中**：上一文件的 `currentArtboardId` 不在新文件当前 Page 上时，被当成「画板已删 → Sketch 自动跳选」，`suppressedArtboardId` 吃掉新选中，**不推帧**，手机停在第一文件最后一帧。
2. **M3-C 跨 Page 修复不完整**：虽在 Page 变化时清空 `suppressedArtboardId`，但紧接着仍用 `artboardExistsOnPage(新页, 旧id)` 再判删除并重新抑制——跨文档 / 跨页主动选中同样中招。
3. **`onOpenDocument` 只武装、不重置粘性状态**：切到已打开的另一文档时甚至不一定进 OpenDocument；即使进入也不清 lock / suppress / artboard id。

## 改动（插件）

- 增加 `SLM.currentDocumentId` + **`applyDocumentContext`**：文档 id 变化时清手机锁、删除抑制、粘性画板与 catalog/hash 缓存。
- **`runFrameCheck`**：先做跨文档重置；删除检测改为 `findArtboardById(整份文档)`；仅当旧板从文档消失时抑制首次自动跳选；用户再选其它 id 则恢复推送。
- **`onOpenDocument` / `maybeClearPhoneLockFromSketchSelection`**：切文档时重置并 `scheduleFrameCheck`。
- `resolveTargetArtboard` 返回 `document` / `documentId`。
- 版本：`0.6.7` / bundleVersion `18`。

## 验证

1. 文件 A 选中画板 → 手机显示 A。
2. 切到文件 B，选中画板 → 手机应立刻跟到 B（无需点「自动预览已开启」）。
3. 在 B 内换画板 / 改样式仍实时更新。
4. 同文件内删画板：手机应保持删前最后一帧，再手动选其它板才切换。
