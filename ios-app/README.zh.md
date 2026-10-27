# 览LAN · iPhone 原生预览 App（含 USB）

把 Sketch（览LAN 插件）推过来的画板，**全屏、高清（3×）**显示在 iPhone 上。  
不上架 App Store；用你自己的 Apple ID + Xcode 装到自己手机。

支持两种连法：

| 模式 | 要什么 | 适合 |
|------|--------|------|
| **Wi‑Fi** | 手机和 Mac 同一局域网（或手机热点） | 日常无线 |
| **USB 线** | 数据线 + Mac 上跑 **LanUSBHelper** | 公司网隔离、不想蹭 Wi‑Fi、对标老 Mirror 有线 |

---

## USB 怎么工作（大白话）

苹果不让手机直接连 Mac 上的端口；系统自带的 `iproxy` 也只是 **Mac → 手机**。  
我们用的是 **Peertalk + Flipper FKPortForwarding**（MIT，不开越狱）：

1. 手机 App 在本机开一个 `127.0.0.1:9777` 代理，再开一个 Peertalk 通道口 `19777`
2. Mac 上的 **LanUSBHelper** 通过 USB（usbmuxd）连上那个通道
3. 手机连 `http://127.0.0.1:9777` 时，流量被反向转到 Mac 上的览LAN（端口读自 `~/.sketch-lan-mirror/runtime.json`，默认 9777）

所以：**不是 iproxy 反向，也不用越狱。**

---

## 完整顺序

### 共同准备
1. 装好 **Xcode**（App Store），打开过一次并装好 iOS 平台组件  
2. 用 Xcode 把本 App 签到 iPhone（见下方「装到 iPhone」）  
3. Sketch：`插件 ▸ 📺 览LAN ▸ 开启预览`（插件已是 **3×** 导出）

### A. Wi‑Fi
1. 手机和 Mac 同一 Wi‑Fi（公司网禁互访 → 开手机热点）  
2. 打开 App → 选 **Wi‑Fi** → 填 `http://192.168.x.x:9777`（扫码页 `/qr` 能抄到）→ **连接**

### B. USB（对标老 Mirror 有线）
1. Sketch 已开启预览  
2. Mac 打开并 **Run** `~/Documents/LanViewer-iOS/mac-usb-helper/LanUSBHelper.xcodeproj`（选 My Mac）  
   - 或看 `mac-usb-helper/README.zh.md` 用 `xcodebuild`  
3. **数据线**插上 iPhone，手机点「信任」  
4. 手机 App → 选 **USB 线** → 点 **USB 连接**  
5. 助手窗口保持开着；拔线或退出助手就会断

**备选（USB 助手翻车时）**：把 iPhone 开成「个人热点」，Mac 连上热点，再用 App 的 Wi‑Fi 模式填 Mac 在热点下的地址。这是退路，不是主路径。

---

## 装到 iPhone（免费 Apple ID 就行）

### 0. 准备
- 做 Sketch 的那台 Mac（最好）
- iPhone + 数据线
- 同一个 Apple ID（免费即可）

### 1. 装 Xcode（只需一次）
1. App Store 搜 **Xcode** 安装  
2. 打开一次，同意协议；**Settings ▸ Platforms** 确认有 **iOS**

### 2. 打开工程
```
~/Documents/LanViewer-iOS/LanViewer/LanViewer.xcodeproj
```
桌面还有 `览LAN-iPhone装法.md`；压缩包可在 `~/Downloads/LanViewer-iOS.zip`。

### 3. Signing
1. Target **LanViewer** → **Signing & Capabilities**  
2. 勾 **Automatically manage signing**  
3. **Team** 选个人账号  
4. Bundle ID 默认 `com.meme.lanviewer`；冲突就改成 `com.你名字.lanviewer`

### 4. 插手机 → Run
选真机 iPhone → ▶。第一次在手机：**设置 ▸ 通用 ▸ VPN 与设备管理** 里信任开发者。

### 5. 再编 Mac USB 助手（要用 USB 时）
```
~/Documents/LanViewer-iOS/mac-usb-helper/LanUSBHelper.xcodeproj
```
选 **My Mac** → ▶。终端会打印转到的览LAN 端口。

---

## 免费账号限制（实话）

| 点 | 说明 |
|---|---|
| 个人签名 | 大约 **7 天** 要重新 Xcode Run 一次 |
| 动态岛 / 小黑条 | 系统安全区，去不干净 |
| App Store | 不需要 |
| USB 助手 | 插线期间必须在 Mac 上开着；第一次也要 Xcode 编出来 |

---

## 工程结构

```
ios-app/
  README.zh.md
  LanViewer/                 ← iPhone App
    LanViewer.xcodeproj
    LanViewer/               SwiftUI + USBTunnel
    Vendor/
      peertalk/              rsms/peertalk (MIT)
      CocoaAsyncSocket/      (MIT)
      FKPortForwarding/      Facebook Flipper 摘录 (MIT) — 仅 Server
mac-usb-helper/
  LanUSBHelper.xcodeproj     ← Mac 命令行助手
  LanUSBHelper/main.m
  Vendor/                    peertalk + CocoaAsyncSocket + FK Client
  README.zh.md
```

协议对齐览LAN：`/health`、`/info`、`/current`，WebSocket 先 JSON meta 再 PNG。

---

## 常见翻车

**USB 连不上**  
- 助手没开 / 线没插 / 没信任电脑  
- Sketch 没开预览（助手通了，健康检查仍会失败）  
- 手机 App 还在用旧版（没 USB 按钮）→ 重新 Xcode Run 装一次  

**Wi‑Fi 连不上**  
- 不同网 / 公司隔离 → 热点或改用 USB  

**很糊**  
- 确认插件 3×、Sketch ⌘Q 重开后再「开启预览」

**顶上还有电量、底下小黑条**  
- 正常；浏览器底栏不会再有。

---

## 我这边做不到的

- 你 Mac 若还没装好 **Xcode.app**，我没法替你编译签名、没法替你装到 iPhone / 编出助手二进制  
- 不越狱、不上架；USB 路径需要你本机 Xcode 编一次 App + 助手  

装好 Xcode、插上手机后跟我说，我可以继续在你 Mac 上帮点 Signing / 排错。
