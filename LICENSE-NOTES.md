# 授权说明（务必看一眼）

## 上游：览LAN / sketch-lan-mirror

| 项 | 现状（截至 2026-10-27） |
|---|---|
| 仓库 | https://github.com/xuezx1999/sketch-lan-mirror |
| 版本 | v0.5.3（tag，2026-09-14） |
| LICENSE 文件 | **没有** |
| GitHub `license` 字段 | **null** |
| README / docs 内明确 SPDX | **未见到** |

含义（大白话）：

- 代码公开挂在 GitHub，作者欢迎你用；但**法律上不等于** MIT / Apache 那种「随便改、随便再分发」。
- **你自己 Mac 上装来预览设计** → 实务上通常没问题。
- **改完再公开发布、塞进公司内部工具平台、或商业出售** → 先发 Issue / 私信作者要个明确 LICENSE，别想当然。

本包做法：

1. `dist/LAN-v0.5.3.zip` = 直接下载的官方 Release 原件（保留校验和），不是我们重打包冒充。
2. `vendor-sketch-lan-mirror/` = 同 tag 源码快照，方便阅读与日后 fork；**未删作者署名、未改 identifier 冒充新品**。
3. 中文 README / research.md 是我们写的包装说明，不是上游正文。

## 依赖（在 server 里）

上游 `server/package.json` 用到：

- `ws`（WebSocket）
- `qrcode-generator`

各自遵循其 npm 包自带 LICENSE（常见 MIT 一类）。以 `node_modules` 内文件为准。

## 内嵌 Node 运行时

官方 Release zip 内含 darwin fat（arm64+x64）Node 二进制，版权归 Node.js / OpenJS。分发时请遵守 Node 的许可条款；我们未在 Linux 盒子上重新编译或替换该二进制。

## 我们改了啥

相对上游 v0.5.3：**业务代码零改动**。  
只增加了本目录的中文安装说明、调研笔记归档、授权说明，以及官方 Release 的本地镜像。

若以后要改「跟选手感 / PIN 鉴权 / 多设备」等，建议：

1. 先跟作者要 LICENSE 或谈好 fork 条款  
2. 再在 `vendor-sketch-lan-mirror` 上开分支，保留 ATTRIBUTION  

## USB 栈（本仓库新增）

| 组件 | 来源 | 许可 |
|------|------|------|
| peertalk | https://github.com/rsms/peertalk | MIT（`LICENSE.txt`） |
| CocoaAsyncSocket (GCDAsyncSocket) | https://github.com/robbiehanson/CocoaAsyncSocket | MIT |
| FKPortForwarding（摘录） | Facebook Flipper `iOS/FlipperKit/FKPortForwarding` | MIT |

用途：在无越狱前提下，把 iPhone `localhost` TCP **反向**转到 Mac 览LAN。  
源码 vendored 于 `ios-app/LanViewer/Vendor/` 与 `mac-usb-helper/Vendor/`，保留上游版权头。
