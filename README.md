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
