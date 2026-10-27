# LanUSBHelper · Mac USB 助手

把 iPhone 上的 `127.0.0.1:9777` **反向**转到本机览LAN（通常也是 9777）。  
用的是 Peertalk + Flipper FKPortForwarding，**不用越狱**，也不是 `iproxy`（iproxy 只能 Mac→手机）。

## 跑起来（需要 Xcode）

### 方式 A：Xcode 里跑
1. 双击打开 `LanUSBHelper.xcodeproj`
2. 选 **My Mac**，点 ▶ Run  
3. 终端/输出区会打印「转到 Mac 览LAN: 127.0.0.1:xxxx」

### 方式 B：命令行（Xcode 装好后）
```bash
cd ~/Documents/LanViewer-iOS/mac-usb-helper
xcodebuild -scheme LanUSBHelper -configuration Debug -derivedDataPath build
./build/Build/Products/Debug/LanUSBHelper
```

可选：`--port 9778` 强制指定览LAN 端口（默认读 `~/.sketch-lan-mirror/runtime.json`）。

## 完整 USB 顺序
1. Sketch：开启预览  
2. **先开本助手**（本 README）  
3. 插上 iPhone 数据线并信任  
4. 手机 App → **USB 线** → **USB 连接**

Wi‑Fi 模式不受影响，照旧填局域网地址即可。
