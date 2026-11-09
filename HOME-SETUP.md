# 回家另一台电脑继续调试

```bash
git clone https://github.com/lvyuhang/sketch-lan-viewer.git
cd sketch-lan-viewer
```

1. **装 Sketch 插件**：首次解压 `dist/Sketch-View-v0.6.7.zip` 双击安装，再覆盖 `dist/Sketch-View-v0.6.8.zip`（当前 **0.6.8**；装完须完全退出再开 Sketch。旧 `0.6.6` / `LAN-v0.5.3` 仅作历史）
2. **装 Xcode**（若还没有）
3. **iPhone App**：打开 `ios-app/LanViewer/LanViewer.xcodeproj` → 个人 Team → 真机 Run
4. **USB 助手**：打开 `mac-usb-helper/LanUSBHelper.xcodeproj` → My Mac → Run（USB 时用）
5. Sketch 开启预览 → App 用 Wi‑Fi 填地址，或点 USB 连接

详细步骤：`ios-app/README.zh.md`、`mac-usb-helper/README.zh.md`。
