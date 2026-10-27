# 览LAN 预览套件（Sketch → iPhone）

给 [宇航 / meme](https://github.com/lvyuhang) 用的 Sketch 真机预览：选中画板 → 手机高清全屏出图，支持 Wi‑Fi 与 **USB 线连**（不上架 App Store）。

## 里面有什么

| 目录 | 作用 |
|------|------|
| `ios-app/` | iPhone 原生 App「览LAN」（SwiftUI，3x 图全屏；Wi‑Fi / USB） |
| `mac-usb-helper/` | Mac 端 USB 小助手（Peertalk 反代到本机览LAN 中继） |
| `vendor-sketch-lan-mirror/` | 上游 [sketch-lan-mirror](https://github.com/xuezx1999/sketch-lan-mirror) v0.5.3 源码快照 |
| `research.md` | 技术调研笔记 |
| `LICENSE-NOTES.md` | 授权说明（上游 LICENSE、Peertalk 等） |

Sketch 插件安装包请用上游 Release 的 `LAN-*.zip`（内含 darwin Node，体积大，不放本仓）。插件侧导出已按 **3x** 改过的说明见 `ios-app/README.zh.md`。

## 快速用法

1. Mac 安装并开启 [览LAN](https://github.com/xuezx1999/sketch-lan-mirror) 插件预览  
2. Xcode 打开 `ios-app/LanViewer/LanViewer.xcodeproj`，个人 Team 签到真机  
3. **Wi‑Fi**：App 填 `http://Mac局域网IP:9777`  
4. **USB**：再 Run `mac-usb-helper/LanUSBHelper.xcodeproj`（My Mac）→ 插线 → App 点「USB 连接」

更细的中文步骤：`ios-app/README.zh.md`、桌面版装法同源文件在 `ios-app/` / 发布说明里。

## 说明

- 不上架；免费 Apple ID 约 7 天需重新 Run 签名  
- USB 不越狱，走 Peertalk 通道，不是 iproxy 反向  
- 动态岛 / Home Indicator 系统区去不干净  
- 本仓为个人使用打包；二次分发请先看 `LICENSE-NOTES.md` 并尊重上游作者
