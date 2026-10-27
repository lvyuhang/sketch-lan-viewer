# 回家另一台电脑继续调试

```bash
git clone https://github.com/lvyuhang/sketch-lan-viewer.git
cd sketch-lan-viewer
```

1. **装 Sketch 插件**：解压 `dist/LAN-v0.5.3.zip` → 双击 `览LAN.sketchplugin`（已含 **3x 导出** + Node 查找修复）
2. **装 Xcode**（若还没有）
3. **iPhone App**：打开 `ios-app/LanViewer/LanViewer.xcodeproj` → 个人 Team → 真机 Run
4. **USB 助手**：打开 `mac-usb-helper/LanUSBHelper.xcodeproj` → My Mac → Run（USB 时用）
5. Sketch 开启预览 → App 用 Wi‑Fi 填地址，或点 USB 连接

详细步骤：`ios-app/README.zh.md`、`mac-usb-helper/README.zh.md`。
