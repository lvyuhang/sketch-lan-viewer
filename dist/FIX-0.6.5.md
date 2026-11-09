# 0.6.5 — 打开即自动预览 + 手机标题小黑标签

## 根因（用户：「还要再点一次自动预览，选中才实时预览」）

1. **`onStartup` 只起 daemon，不武装 Mirror**：`running` 仍为 false，Selection / DocumentChanged 进来只会再撞一次脆弱的 `tryAutoStart`。
2. **旧 `tryAutoStart` 把「首帧成功 + 已有 Artboard」当武装前提**：无选中画板或首帧失败就 `return`，**不设 `running`、不挂 keep-alive timer**。Sketch 插件 JS 上下文短命，没有 `setInterval` fiber 时状态丢光，等于从没开启自动预览。
3. **菜单 `onShowAutoStatus` 才强制 remount**：清 timer → `tryAutoStart` → `startPhoneSelectTimer`，所以「点一下就好了」——不是观测器坏了，是自动武装链没真正跑起来。
4. Action 路径常无 `context.scriptPath`：daemon 死后无法 spawn（依赖内存里的 `SLM_LAST_SCRIPT_PATH`）。

## 改动（插件）

- **`ensureMirrorArmed`**：Startup / OpenDocument / 菜单共用；起 server → `tryAutoStart` → remount phone-select / catalog。
- **`tryAutoStart`**：server 就绪即 **`running=true` + phone-select keep-alive**；无画板 / 首帧失败只记日志，等选中事件推帧，不再卡死。
- **`startBootstrapRetry`**：武装失败时 1s 重试，并用 interval 保活 JS fiber。
- **`rememberScriptPath` / 落盘** `~/.sketch-lan-mirror/last-script-path.txt`：Action 无 scriptPath 时仍能 spawn。
- 版本：`0.6.5` / bundleVersion `16`。
- 已装回：`~/Library/Application Support/com.bohemiancoding.sketch3/Plugins/Sketch View.sketchplugin/`

## 改动（iOS App）

- 真源：`/Users/tan/Documents/LanViewer-iOS/LanViewer/LanViewer/PreviewView.swift`
- 去掉顶栏 **LinearGradient** 通栏；左右滑 / 点击只闪 **左上角小黑圆角标题标签**（`titleChip`）；手势仍挂在 canvas 上，不挡滑动。
- 离线时旁挂同款「断开」小标签。
- 工作区副本已同步：`lan-feature-a/PreviewView.swift`、`sketch-live-preview/ios-app/.../PreviewView.swift`
- **Debug `xcodebuild` 已通过（CODE_SIGNING_ALLOWED=NO）**；**未签名安装到手机**——需在 Xcode 对真机 Run 才会看到新 UI。

## 未改

- LanUSBHelper remux / LayerPilot。

## 验证

1. 重启 Sketch 或打开文档：**不要**点「自动预览已开启」，选中画板 → 手机应跟选实时预览。
2. 改填充/文字仍自动刷（0.6.3/0.6.4 行为）。
3. Xcode Run 新 App 后：手机左右滑 / 点击 → 左上角小黑标签出标题，无通栏渐变条。
4. 菜单项仍可强制 remount（兜底）。
