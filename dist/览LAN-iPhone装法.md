# 览LAN iPhone App + USB 装法（速查）

工程：`~/Documents/LanViewer-iOS/`

## Wi‑Fi
1. Xcode 打开 `LanViewer/LanViewer.xcodeproj` → 签到 iPhone → Run  
2. Sketch 开启预览 → App 填 `http://Mac局域网IP:9777` → 连接  

## USB（对标老 Mirror 有线）
1. Sketch 开启预览  
2. Xcode 打开 `mac-usb-helper/LanUSBHelper.xcodeproj` → My Mac → Run（窗口别关）  
3. 数据线插 iPhone  
4. App → **USB 线** → **USB 连接**  

不是 iproxy，不用越狱。细节见 `ios-app/README.zh.md`。

个人签约 7 天重签一次。动态岛/小黑条去不掉。
