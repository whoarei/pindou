# 拼豆工坊（Pindou Studio）

一款基于 Flutter 的跨平台拼豆图生成应用，当前适配 Android 与 Windows。

- 产品名：拼豆工坊（Pindou Studio）
- Android 应用标识：`top.mossmoss.pindoustudio`
- Dart 包名：`pindou_studio`

## 功能

- 导入 JPG、PNG 图片
- 可拖拽裁剪，支持自由、原图、1:1、4:3、3:4 比例
- 图片左/右旋转
- 自定义 8–200 颗的图案宽高，可锁定裁剪比例
- Perler、Hama、Artkal 三套品牌色库
- LAB 色彩空间匹配、最大颜色数限制
- 可选 Floyd–Steinberg 误差扩散抖动
- CustomPainter 高性能网格预览，支持双指缩放及悬浮加减按钮，可开关色号图层
- 单格/多格选择、选择同色及自适应全色对比表替色；多个当前色号可同时标注
- 颜色编号与用量统计
- 导出含/不含网格及色号的高分辨率 JPG
- `.pindou` 工程文件保存和恢复，启动时自动恢复上次编辑
- 跟随系统浅色/深色主题，响应式适配手机与桌面

## 工程文件与自动恢复

工具栏的工程菜单支持保存和打开 `.pindou` 文件。工程文件包含原图、裁剪区域、生成参数、色号图层开关、生成结果、手工替色结果和当前选区，可复制到其他 Android 或 Windows 设备继续编辑。

应用会在编辑后约 600 毫秒自动保存当前状态，并在下次启动时恢复：

- Android：应用私有 `files/pindou-studio/autosave.pindou`。
- Windows：`%APPDATA%\PindouStudio\autosave.pindou`。

卸载 Android 应用或清除应用数据会删除自动恢复文件；手动保存的 `.pindou` 工程文件不受影响。工程文件内嵌原图，因此文件大小通常会略大于原图。

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

## 本地配置 Android 签名

正式签名 keystore 默认存放在：

```text
E:\Android\libb.keystore
```

如需在本地生成正式签名 APK，请创建 `android/key.properties`（该文件已加入 `.gitignore`）：

```properties
storePassword=你的 keystore 密码
keyPassword=你的 key 密码
keyAlias=pindou
storeFile=E:/Android/libb.keystore
```

然后执行：

```powershell
E:\Android\flutter\bin\flutter.bat build apk --release
```

Release 构建必须提供上述正式签名配置；缺少 `key.properties` 时构建会失败，不会回退生成 Debug 签名 APK。

请勿将 `key.properties`、keystore 文件或密码提交到 Git 仓库。GitHub Actions 使用仓库 Secrets 自动恢复相同的签名配置。

## GitHub Actions 发布构建

`.github/workflows/release.yml` 支持两种触发方式：

- 推送 `v` 开头的标签，例如 `git tag v1.2.2 && git push origin v1.2.2`。构建完成后会自动创建 GitHub Release，并附加 Android APK 和 Windows x64 便携 ZIP。
- 在 GitHub 的 Actions 页面手动运行 **Build releases**。手动运行不会创建 Release，APK 和 Windows ZIP 可从该次运行的 Artifacts 下载。

以标签 `v1.2.2` 为例，发布文件名为：

- Android：`PindouStudio-v1.2.2-android.apk`
- Windows：`PindouStudio-v1.2.2-windows-x64.zip`

Windows 产物是包含 DLL 和 `data` 目录的便携压缩包，解压后运行其中的 `PindouStudio.exe`。
