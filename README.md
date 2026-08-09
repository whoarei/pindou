# 拼豆工坊（Bead Pattern Studio）

一款基于 Flutter 的跨平台拼豆图生成应用，当前适配 Android 与 Windows。

## 功能

- 导入 JPG、PNG 图片
- 可拖拽裁剪，支持自由、原图、1:1、4:3、3:4 比例
- 图片左/右旋转
- 自定义 8–200 颗的图案宽高，可锁定裁剪比例
- Perler、Hama、Artkal 三套品牌色库
- LAB 色彩空间匹配、最大颜色数限制
- 可选 Floyd–Steinberg 误差扩散抖动
- CustomPainter 高性能网格预览、缩放查看
- 颜色编号与用量统计
- 导出含/不含网格的高分辨率 JPG
- 跟随系统浅色/深色主题，响应式适配手机与桌面

## 开发环境

- Flutter 3.44.9 / Dart 3.12.2
- Android SDK：`E:\Android\sdk`
- Flutter SDK：`E:\Android\flutter`

```powershell
E:\Android\flutter\bin\flutter.bat pub get
E:\Android\flutter\bin\flutter.bat run -d windows
E:\Android\flutter\bin\flutter.bat run -d <android-device-id>
```

## 验证

```powershell
E:\Android\flutter\bin\flutter.bat analyze
E:\Android\flutter\bin\flutter.bat test
E:\Android\flutter\bin\flutter.bat build apk --release
E:\Android\flutter\bin\flutter.bat build windows --release
```

Windows 文件对话框通过 Runner 原生 C++ 异步通道实现，不依赖 Flutter 插件或开发人员模式。

## GitHub Actions 发布构建

`.github/workflows/release.yml` 支持两种触发方式：

- 推送 `v` 开头的标签，例如 `git tag v1.0.0 && git push origin v1.0.0`。构建完成后会自动创建 GitHub Release，并附加 Android APK 和 Windows x64 便携 ZIP。
- 在 GitHub 的 Actions 页面手动运行 **Build releases**。手动运行不会创建 Release，APK 和 Windows ZIP 可从该次运行的 Artifacts 下载。

Windows 产物是包含 DLL 和 `data` 目录的便携压缩包，解压后运行其中的 `bead_pattern_generator.exe`。
