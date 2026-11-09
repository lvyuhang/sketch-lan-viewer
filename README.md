# Sketch View 预览套件（Sketch → iPhone）

给 [宇航 / meme](https://github.com/lvyuhang) 用的 Sketch 真机预览：选中画板 → 手机高清全屏出图，支持 Wi‑Fi 与 **USB 线连**（不上架 App Store）。

当前运行时插件版本：**Sketch View 0.6.6**（2026-11-09 从本机同步）。

## 里面有什么

| 目录 | 作用 |
|------|------|
| `ios-app/` | iPhone 原生 App「Sketch View / LanViewer」（SwiftUI，3x 图全屏；Wi‑Fi / USB） |
| `mac-usb-helper/` | Mac 端 USB 小助手（Peertalk 反代到本机中继） |
| `plugin/` | Sketch View 0.6.6 插件源码快照（不含嵌入式 Node 二进制） |
| `vendor-sketch-lan-mirror/` | 上游 [sketch-lan-mirror](https://github.com/xuezx1999/sketch-lan-mirror) v0.5.3 源码快照 |
| `research.md` | 技术调研笔记 |
| `LICENSE-NOTES.md` | 授权说明（上游 LICENSE、Peertalk 等） |

Sketch 插件安装包在 `dist/Sketch-View-v0.6.6.zip`（约 72MB，内含 darwin Node，克隆后即可双击安装）。历史包 `dist/LAN-v0.5.3.zip`（览LAN 0.5.3）仍保留。插件导出按 **3x**；说明见 `ios-app/README.zh.md`。

## 快速用法

1. Mac 安装 `dist/Sketch-View-v0.6.6.zip` → 双击 `Sketch View.sketchplugin`  
2. Xcode 打开 `ios-app/LanViewer/LanViewer.xcodeproj`，个人 Team 签到真机  
3. **Wi‑Fi**：App 填 `http://Mac局域网IP:9777`  
4. **USB**：再 Run `mac-usb-helper/LanUSBHelper.xcodeproj`（My Mac）→ 插线 → App 点「USB 连接」

更细的中文步骤：`ios-app/README.zh.md`、`HOME-SETUP.md`。

## 说明

- 不上架；免费 Apple ID 约 7 天需重新 Run 签名  
- USB 不越狱，走 Peertalk 通道，不是 iproxy 反向  
- 动态岛 / Home Indicator 系统区去不干净  
- 本仓为个人使用打包；二次分发请先看 `LICENSE-NOTES.md` 并尊重上游作者
