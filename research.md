# Sketch 实时预览（DIY Mirror）技术调研

调研时间：2026-10-27（Asia/Shanghai）  
范围：只调研、不写代码。目标 = 手机端实时看到 Sketch 画板改动。

---

## 1. 官方 Sketch Mirror 现状与痛点

### 现状（两条线）

| 产品 | 状态 | 要点 |
|------|------|------|
| **Legacy Mirror App** | **已停维** | 官方明确：Mirror support has ended，仍可装，但随 Sketch / macOS / iOS 升级会越来越不稳。[官方文档](https://www.sketch.com/support/troubleshooting/mirror-app-legacy/)（Last updated 12 Mar 2024） |
| **Sketch — View & Mirror（新 iOS App）** | **现行官方方案** | 通过 **Workspace 云端**镜像，不要求同 Wi-Fi；需 Sketch 账号 + Workspace + **订阅**；Mac-only 许可证不支持手机端。[官方文档](https://www.sketch.com/docs/getting-started/sketch-for-ios/)（Last updated 22 Jun 2026） |
| **Android 官方** | **没有** | 官方只点名第三方 Crystal。[同上 legacy 页](https://www.sketch.com/support/troubleshooting/mirror-app-legacy/) |

### 新 iOS App 怎么用 Mirror

1. 文档必须先 **Save to Workspace**（本地文件不能直接 Mirror）  
2. Mac 打开该文档 → iPhone/iPad 同账号打开同一文档 → 点右上角 mirror 图标  
3. 需要：iOS 15+ / iPadOS 16+、联网、订阅  

来源：[iOS troubleshooting](https://www.sketch.com/support/troubleshooting/ios-app/)（Last updated 20 May 2026）、[Sketch for iOS](https://www.sketch.com/docs/getting-started/sketch-for-ios/)

### 已知痛点（官方 + 社区）

- **连不上 / 发现不了**（主要针对旧 Mirror）：要同 Wi-Fi；Bonjour/mDNS、UPnP、TCP **58005**、WebSocket；公司网常拦设备互访；可用 USB。来源：[legacy Mirror 排障](https://www.sketch.com/support/troubleshooting/mirror-app-legacy/)
- **本地文件不能镜像**：新 App「Why can’t I mirror local files?」——必须进 Workspace。来源：[iOS app 排障](https://www.sketch.com/support/troubleshooting/ios-app/)
- **绑定订阅 / 云**：Mac-only 许可证用不了手机端；Guest/Member 权限问题也会卡。来源：[Sketch for iOS](https://www.sketch.com/docs/getting-started/sketch-for-ios/)
- **体感卡、更新慢、息屏**：社区 2025-10 反馈「Mirror 越来越没用」、文件打开慢、改完不刷新、息屏烦人；官方建议更新 View & Mirror、重装；息屏在真正进入 mirror 模式时应保持亮屏。来源：[论坛帖](https://forum.sketch.com/t/sketch-mirror-ios-app-is-getting-useless/5665)
- **无 Android**：只能碰第三方。

**一句话**：官方现方案 =「云 Workspace + 订阅 + iOS」；本地、离线、Android、不想上云，官方基本不管。这正是 DIY / 第三方的空间。

---

## 2. 开源 / 第三方方案对照

> 「是否还能用现代 Sketch」= 相对 Sketch 2025.x–2026.x 的公开证据；未实测处标「存疑」。

### Live Preview for Sketch（Kyle Halevi）— **最像成品的第三方**

- **形态**：Sketch 插件 + Mac 小助手 + **iOS App**（App Store：`Live Preview – View Artboards`）  
- **平台**：iPhone / iPad；**无 Android**  
- **实时**：有 Automatic Updates；也可快捷键手动推；@3x 无损偏手动档  
- **本地 vs 云**：宣传本地/云文档都行，**不要求互联网**（走类似 AirDrop / Multipeer 的近场无线）  
- **最近更新**：App Store 显示 **1.0.2，2025-09-15**（仍在维护）  
- **授权 / 价格**：闭源商业；约付费 App（多地区价不同，约几美元级）  
- **安装摩擦**：买 App + 装插件 + 配对 Trusted Devices  
- **现代 Sketch**：2025 仍有更新，**相对乐观**；未公开是否覆盖 Sketch 2026 Frames  
- 链接：[产品页](https://apps.kylehalevi.com/live-preview/) · [插件目录提交](https://github.com/sketchplugins/plugin-directory/commit/bf88c72ba6d7ca581d9d88438c13c25559e5e792)

### Crystal（Android Mirror）

- **形态**：Android App + 可选 Mac USB companion  
- **平台**：**仅 Android**；Wi-Fi / USB；支持 prototype、离线下载宣传  
- **实时**：宣称 realtime + 跟选画板  
- **最近更新**：Google Play **Updated on Oct 21, 2020**（停更约 6 年）  
- **授权**：免费 + 订阅解锁部分功能  
- **现代 Sketch**：**高风险不可用或半残**（Sketch 协议/插件生态大变后无证据仍兼容）；官方仍口头推荐，但不等于还能用  
- 链接：[官网](https://crystal.smithy.productions/) · [Play](https://play.google.com/store/apps/details?id=com.smithyproductions.crystal)

### SketchPlay

- **形态**：老 Sketch 插件 + iOS companion  
- **平台**：iOS；USB；手动 ⌘P + 宣称 realtime  
- **年代**：约 2015，面向 **Sketch 3.3+**  
- **开源**：曾挂 [cute/SketchPlay](https://github.com/cute/SketchPlay)（Apache-2.0），**现仓库 404**  
- **现代 Sketch**：**基本可判死**  
- 链接：[作者旧页](https://liguangming.com/SketchPlay)

### Browser Preview（lukasoppermann）

- **形态**：纯 Sketch 插件，把选中画板 **2x 打开进浏览器**  
- **平台**：桌面浏览器；**非手机 App、非 live**  
- **最近 push**：约 **2023-03**；~31★  
- **授权**：开源（仓库可见）  
- **现代 Sketch**：小插件，可能还能装，但只是「导出预览一次」，不是 Mirror  
- 链接：[GitHub](https://github.com/lukasoppermann/browser-preview)

### sketch-liveserver + Skala Preview 生态

- **ofstudio/sketch-liveserver**：把 Skala Preview 的图用 BrowserSync 挂到 HTTP；**仓库已 archived**，最后 push ~2018  
- **Skala Preview（Bjango）**：**on hold / 停更**；Homebrew cask 也曾 deprecate  
- **marcisme/sketch-preview**：给 Skala 喂图的插件，最后 ~2018，~608★，依赖死链  
- **现代 Sketch**：**不可作为路线**  
- 链接：[liveserver](https://github.com/ofstudio/sketch-liveserver) · [Skala](https://bjango.com/mac/skalapreview/) · [sketch-preview](https://github.com/marcisme/sketch-preview)

### 览LAN / sketch-lan-mirror（xuezx1999）— **最接近「自己 vib 一个」且已有成品**

- **形态**：Sketch 插件（内嵌 Node）+ 本机 HTTP/WS + **手机浏览器 / PWA**（可「添加到主屏幕」）  
- **平台**：iPhone / Android 浏览器均可扫码；测过 iPhone Safari / PWA；Changelog 写 Android 浏览器也可用  
- **实时**：编辑事件加速（约 100–400ms）+ 1s 轮询兜底；PNG SHA-256 去重  
- **本地**：纯局域网，无云、无登录  
- **最近发布**：**v0.5.3（2026-09-14）**  
- **实测兼容**：作者写明 **Sketch 2025.3.4**；架构文档目标写过 2026.2；ADR 里有 Sketch 2026.2 实测  
- **授权**：公开 GitHub，未见明确 LICENSE 文件（用前需自行确认）  
- **安装摩擦**：下 Release zip → 双击 `.sketchplugin` → Start LAN → 扫码；**Mac 不必预装 Node**（包内嵌 arm64/x64 node）  
- **已知限制**：全量导出仍每 tick 做；仅顶层 `Artboard` 类型标记；LAN 内无鉴权，同网可看；公共 Wi-Fi 慎用  
- 链接：[GitHub](https://github.com/xuezx1999/sketch-lan-mirror) · 有完整 [ARCHITECTURE](https://github.com/xuezx1999/sketch-lan-mirror/blob/main/docs/ARCHITECTURE.md) / [DECISIONS ADR](https://github.com/xuezx1999/sketch-lan-mirror/blob/main/docs/DECISIONS.md)

### 官方浏览器 Preview（非第三方）

- Sketch 自带 Prototype Preview 窗口、Workspace 分享链接、浏览器预览；**不是「手机跟手 Mirror」**。Changelog（Edinburgh 2026.2）在改进桌面 Preview Follow Selection 等。[changelog](https://www.sketch.com/changelog/edinburgh/)

---

## 3. DIY 技术卡点

### 3.1 Sketch 插件：变化检测 + 导出 PNG

**变化检测**

- 官方有 `onDocumentChanged`（Sketch 59+）：属性改 / 增删；可能 batch；文档仍标 early feedback。[Document changes](https://developer.sketch.com/plugins/document-changes)
- Actions 里有 `SelectionChanged`、`ArtboardChanged` 等细粒度；**没有可靠的「任意内容变了」万能事件**（览LAN 架构写明旧 `ContentsChanged` 不可依赖）
- **实务共识**：**事件加速 + 低频轮询兜底 + PNG 哈希去重**（览LAN：80ms debounce + 1s poll + SHA-256）
- **坑**：只认「选中了 Artboard 本体」会漏——用户改的是内层图层；必须沿 `.parent` 找所属画板（览LAN ADR-012）

**导出**

- `sketch.export(layer, { formats: 'png', scales: '1'|'2', output: false })` 可拿 Buffer（不落盘）  
- 实测坑（览LAN ADR-001）：文档说返回数组，Sketch 2026.2 单图层时可能直接返回单个 Buffer → 要做形态归一  
- 2025.1+ **Artboard 已被 Frames/Graphics 取代**；`type === Artboard` 仍是顶层 Frame 的标记；DIY 必须兼容新容器语义。[API Reference / Artboard legacy](https://developer.sketch.com/reference/api/)

**性能**

- 导出本身常是瓶颈（览LAN 实测约 18–307ms），比 loopback POST（1–5ms）重得多  
- 必须 debounce / 丢中间帧 / 静止时跳过 POST  
- 定时器回调里导出可能读到陈旧渲染缓存 → 需要 flush 手段或正确解析目标（ADR-010/012）

### 3.2 「Realtime」像素通路

推荐链路（已被览LAN 验证）：

```
Sketch 插件 → export PNG → POST localhost → Node HTTP+WS → 手机 <img>/blob
```

- 插件 **JavaScriptCore**，有 `fetch`/`fs` 等 polyfill，但 **没有 Node `http`/`ws`**；异步 Cocoa 回调在插件里大量封死（JS block 不能 copy、`defineClass` 没了）→ MVP 常用 **主线程同步 loopback POST**（ADR-004）  
- 插件内起 TCP/WS 服务不划算；**独立 Node 进程**持有服务更稳  
- 「真 realtime」（拖动每一帧）成本极高；产品上 **100–400ms 延迟的近实时** 更现实

### 3.3 手机客户端形态

| 方案 | 优点 | 缺点 | 对中国大陆用户 |
|------|------|------|----------------|
| **PWA / Safari「添加到主屏幕」** | 无上架、迭代快、Android/iOS 都能扫码打开 | iOS PWA 视口/白屏坑多（览LAN ADR-014~016, v0.5.3 修白屏）；不如原生稳 | **最省事**；微信内置浏览器可能别扭，建议系统浏览器 |
| **Expo Go / 壳 App** | 像 App、好做手势 | 仍要装 Expo Go 或打测试包；上架另说 | 国内 Expo Go 分发一般；TestFlight/企业签更麻烦 |
| **原生 App Store / 各应用商店** | 体验最好、可做近场（如 Live Preview 的 Multipeer） | 审核、证书、周期长；Android 国内多渠道 | **vib 第一版别走这条** |

结论：DIY 第一版用 **局域网网页 + 可选 PWA** 性价比最高；「装一个 App」可用 Add to Home Screen 冒充，或后期再壳。

### 3.4 局域网发现

- **Bonjour/mDNS**：旧 Mirror 依赖；公司网常挂；实现成本不低  
- **扫码（QR 含 http://IP:port）**：最稳、最常见（览LAN / 多数局域网工具）  
- **USB**：旧 Mirror / Crystal / SketchPlay 有；DIY 要另做 companion 或 usbmux，**第一版别碰**  
- macOS 会弹「允许传入连接」；iOS 14+ 访问局域网要「本地网络」权限

### 3.5 安全

- 纯 HTTP LAN：**同网任何人可打开 Viewer**（览LAN README 明文警告）  
- 公共 Wi-Fi / 公司访客网：危险或不连  
- 自签 HTTPS 对手机信任成本高，一般不值得  
- 可选加强：随机 token 路径、一次性 PIN、仅绑已扫设备——第二阶段再做

### 3.6 Mac 沙箱 / 插件网络

- Sketch 插件能访问网络（`fetch`、NSURLConnection）；loopback 通常 OK  
- **JS 环境短命**：异步要用 fiber；常驻靠 timer / 独立进程（[JS environment](https://developer.sketch.com/plugins/javascript-environment)）  
- 插件里起 server、复杂 async Cocoa：**坑很多**（见览LAN ADR-004/008）  
- 内嵌 Node 二进制：要注意 Gatekeeper quarantine（览LAN v0.5.0 专门处理）

---

## 4. 推荐路线（按 vib 优先级）

### 🥇 A. 先试用现成「览LAN」+ 可选 Live Preview（低投入验需求）

- **做法**：装 [sketch-lan-mirror](https://github.com/xuezx1999/sketch-lan-mirror) Release；iPhone/Android 扫码；不够再买 [Live Preview](https://apps.kylehalevi.com/live-preview/)（仅 iOS）  
- **保真度**：LAN ≈ 官方旧 Mirror 的「看画板图」；无 prototype 交互动画  
- **风险**：LAN 个人项目、LICENSE 不清、安全无鉴权；Live Preview 闭源收费、无 Android  
- **工作量**：半天体验级  

### 🥈 B. Fork / 复用览LAN 架构自己 vib（中投入，最高 ROI）

- **做法**：插件 export + Node WS + 手机 PWA；直接吃透其 DECISIONS，避免重踩 Cocoa/异步/PWA 坑  
- **保真度**：可做到近实时画板图；可加 PIN、多设备、跟选优化  
- **风险**：维护成本在自己；Sketch 大版本（Frames）要跟  
- **工作量**：有现成参考 ≈ 1–2 周打磨；从零 ≈ 数周  

### 🥉 C. 只做「快捷键导出 + 本机网页刷新」（最低保真）

- **做法**：类似 Browser Preview：⌘⇧P 出图，手机开同一局域网页手动/半自动刷  
- **何时**：只想确认真机尺寸，不要跟手  

### ❌ 明确不建议

1. **复活 SketchPlay / Skala / sketch-liveserver** — 生态已死  
2. **指望 Crystal 在 2025–2026 Sketch 上开箱即用** — 2020 停更，先当不可用  
3. **第一版就做 App Store 原生 Mirror App** — 审核与分发拖死 vib  
4. **插件进程内手写 WebSocket 服务 / 依赖已死 Mocha.defineClass 异步** — 已证实坑  
5. **追求拖动 60fps 真实时** — PNG 全量导出做不到；除非改向量/差分大方案  
6. **绑云 / 仿官方 Workspace Mirror** — 和「本地 Mirror」目标相反，且要账号体系  

---

## 5. 需要用户确认的开放问题

1. **Mac / Sketch 版本**：Sketch 是 2025.x 还是 2026.x？Intel 还是 Apple Silicon？（览LAN 写 2025.3.4 实测；架构瞄过 2026.2）  
2. **手机系统**：主要是 **iPhone** 还是 **Android**？还是双端？Android 国内是原版还是厂商 ROM、能否用系统浏览器扫局域网 IP？  
3. **网络环境**：家里同 Wi-Fi，还是公司网（常禁设备互访）？能否接受「仅可信局域网」？  
4. **文档形态**：是否必须 **本地 .sketch 不上 Workspace**？（官方新 Mirror 做不到）  
5. **要不要 prototype 可点**？还是只要 **静态画板实时图**？（后者 DIY 简单一个数量级）  
6. **「装 App」硬需求**：能接受 Safari/Chrome + 添加到主屏幕吗？还是必须图标级独立 App？  
7. **是否已试过**：官方 View & Mirror、Live Preview、览LAN？哪条踩过坑？  
8. **许可**：若 fork 览LAN，能否接受其暂无明确 LICENSE / 与作者协商？

---

## 6. 给决策者的三句话

1. **官方新 Mirror = 云 Workspace + 订阅 + iOS**；旧 Mirror 已停维；Android 官方不管。  
2. **开源里真正还能跟现代 Sketch 对话的，几乎就是「览LAN / sketch-lan-mirror」**；Live Preview 是唯一像样的商业 iOS 成品；其余多为 2015–2018 遗骸。  
3. **自己 vib 的正确姿势**：别从零发明协议——先试用/fork「插件导出 PNG + 本机 WS + 手机 PWA」；别一上来做商店 App，也别追 60fps。

---

## 主要来源（便于复查）

- https://www.sketch.com/support/troubleshooting/mirror-app-legacy/  
- https://www.sketch.com/docs/getting-started/sketch-for-ios/  
- https://www.sketch.com/support/troubleshooting/ios-app/  
- https://forum.sketch.com/t/sketch-mirror-ios-app-is-getting-useless/5665  
- https://apps.kylehalevi.com/live-preview/  
- https://crystal.smithy.productions/  
- https://github.com/xuezx1999/sketch-lan-mirror  
- https://github.com/xuezx1999/sketch-lan-mirror/blob/main/docs/DECISIONS.md  
- https://developer.sketch.com/plugins/document-changes  
- https://developer.sketch.com/plugins/javascript-environment  
- https://developer.sketch.com/reference/api/  
- https://bjango.com/mac/skalapreview/  
- https://github.com/lukasoppermann/browser-preview  
- https://github.com/ofstudio/sketch-liveserver  
