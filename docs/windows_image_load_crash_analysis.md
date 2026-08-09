# Windows 加载图片闪退问题分析报告

## 1. 文档信息

| 项目 | 内容 |
| --- | --- |
| 应用 | 拼豆工坊（Bead Pattern Studio） |
| 问题平台 | Windows x64 |
| 问题日期 | 2026-08-09 |
| Flutter | 3.44.9 stable |
| Dart | 3.12.2 |
| 应用版本 | 1.0.0+1 |
| 问题状态 | 已修复并完成回归 |

## 2. 问题描述

Windows 版本正常启动后，点击“选择一张图片”，在原生文件选择器中选择图片，文件选择器可以正常关闭，但应用随后闪退。没有 Flutter 错误提示或可见异常栈，进程直接退出。

用于稳定复现的文件为桌面上的 `bootlogo.png`：

- 文件大小：440,873 字节
- 图片尺寸：834 × 590
- 图片格式：PNG
- 像素格式：32 位 RGBA

Android 版本使用图片选择、解码、预览、转换和导出功能时未出现同类问题。

## 3. 复现步骤

1. 启动 Windows release：`bead_pattern_generator.exe`。
2. 点击“选择一张图片”。
3. 进入桌面目录。
4. 双击 `bootlogo.png`。
5. 文件选择器关闭。
6. 约 1～5 秒后应用窗口消失，进程退出。

该问题可以连续稳定复现。

## 4. 崩溃证据

Windows Application Error 事件记录如下：

```text
Faulting application: bead_pattern_generator.exe
Faulting module: flutter_windows.dll
Exception code: 0xc0000005
Fault offset: 0x000000000003a9fa
```

其中 `0xc0000005` 表示原生内存访问冲突。多次复现的模块、异常代码和偏移完全一致，说明这是确定性路径，并非随机内存不足或图片过大。

Flutter SDK 同时提供了与 release 引擎匹配的 PDB。使用 `llvm-symbolizer` 对 `flutter_windows.dll + 0x3a9fa` 解析，得到：

```text
ui::AXNode::id
flutter::AccessibilityBridge::CreateRemoveReparentedNodesUpdate()
accessibility_bridge.cc:229
```

因此，实际崩溃发生在 Flutter Windows 的 AccessibilityBridge 更新语义节点树时，而不是 PNG 解码器。

## 5. 排查过程

### 5.1 假设一：Win32 文件对话框阻塞 Flutter UI isolate

初始 Windows 文件选择器通过 Dart FFI 同步调用 `GetOpenFileNameW`。传统 Win32 对话框会运行自己的消息循环，存在 Flutter 引擎重入风险。

处理：

- 将文件选择调用移到独立 Dart isolate。
- 同时将保存对话框移到独立 isolate。

结果：

- 文件选择器正常工作。
- 应用仍在相同 `flutter_windows.dll + 0x3a9fa` 偏移崩溃。

结论：这不是主根因。

### 5.2 假设二：`win32 6.x` 的 `OPENFILENAMEW` ABI 不兼容

处理：

- 去除 `win32` 生成绑定。
- 使用独立的 `OPENFILENAMEW` 结构声明与显式内存分配、释放。

结果：

- 崩溃偏移没有变化。

结论：Dart FFI ABI 不是主根因。

### 5.3 假设三：`bootlogo.png` 的编码或元数据触发图片解码器崩溃

处理：

- 使用纯 Dart `image` 包解码原图。
- 将图片重新编码为标准 PNG 后再交给 Flutter 显示。
- 创建不经过文件选择器的最小 Flutter 渲染测试，分别显示原始 PNG 和重新编码后的 PNG。

结果：

- 原始 PNG 渲染测试通过。
- 重新编码 PNG 渲染测试通过。
- 纯 Dart 图片解码正常。
- 应用完整流程仍在相同偏移崩溃。

结论：图片文件有效，图片解码不是根因。

### 5.4 隔离文件对话框实现

为彻底排除 Dart FFI，Windows 文件选择和保存逻辑迁移到 Runner 原生 C++ 层：

- 工作线程调用 `GetOpenFileNameW` / `GetSaveFileNameW`。
- 通过 Flutter `MethodChannel` 异步返回路径。
- 自定义 Windows 完成消息在送入 Flutter 窗口过程前拦截。

结果：

- 原生文件通道工作正常。
- 未修改语义树前，加载图片仍在 AccessibilityBridge 的相同偏移崩溃。

该结果进一步证明文件对话框不是最终根因。

## 6. 根因分析

加载图片会使主预览区域从 `_EmptyView` 切换为 `_ReadyView`。原实现使用：

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 240),
  child: _body(context),
)
```

`AnimatedSwitcher` 在过渡期间会同时保留旧子树和新子树，并对语义节点执行移除、插入和重挂载。

当 Windows UI Automation、辅助功能客户端或 Narrator 激活 Flutter 语义树时，这次更新进入 Flutter 3.44 Windows 引擎的：

```text
AccessibilityBridge::CreateRemoveReparentedNodesUpdate
```

在处理节点移除/重挂关系时，引擎访问了无效节点，最终产生 `0xc0000005` 原生访问冲突。由于错误发生在 `flutter_windows.dll` 内部，Dart 层无法捕获异常或显示错误提示。

问题触发链路如下：

```text
选择图片
  → 更新 EditorState.sourceBytes
  → Workspace 从 EmptyView 切换为 ReadyView
  → AnimatedSwitcher 同时维护新旧语义子树
  → Windows AccessibilityBridge 移除/重挂语义节点
  → flutter_windows.dll 访问冲突
  → 进程退出
```

## 7. 修复方案

### 7.1 主修复：保持单一语义树

移除 Workspace 上的 `AnimatedSwitcher`，直接显示当前内容：

```dart
ColoredBox(
  color: Theme.of(context).colorScheme.surfaceContainerLowest,
  child: _body(context),
)
```

这样状态变化时只进行普通 Widget/语义树更新，不再通过过渡层同时重挂新旧语义子树。

修改文件：

- `lib/features/editor/editor_screen.dart`

### 7.2 Windows 文件通道加固

虽然文件对话框不是最终根因，但排查中发现 Dart FFI 方案会增加消息循环和 ABI 风险，因此保留了更稳健的原生实现：

- C++ 工作线程显示打开/保存对话框。
- 主窗口线程完成 MethodChannel 回调。
- 自定义完成消息优先于 Flutter embedder 消息处理。
- Dart 只接收文件路径，不持有 Win32 指针或结构体。
- 不依赖 Flutter 插件符号链接或 Windows 开发人员模式。

修改文件：

- `windows/runner/flutter_window.h`
- `windows/runner/flutter_window.cpp`
- `windows/runner/CMakeLists.txt`
- `lib/features/editor/editor_controller.dart`

同时移除了不再需要的直接 `win32` / `ffi` 依赖。

## 8. 回归验证

### 8.1 自动化验证

```text
flutter analyze: No issues found
flutter test: 4/4 passed
flutter build windows --release: success
```

### 8.2 Windows 实机交互验证

回归过程始终保持 Windows UI Automation 开启，以覆盖原问题的辅助功能触发条件。

| 测试项 | 结果 |
| --- | --- |
| 启动 Windows release | 通过 |
| 选择桌面 `bootlogo.png` | 通过 |
| 显示文件名与 834 × 590 尺寸 | 通过 |
| 加载后持续运行超过 10 秒 | 通过 |
| 生成 40 × 28 拼豆图 | 通过 |
| 统计 1120 颗、16 色 | 通过 |
| 生成后持续运行超过 10 秒 | 通过 |
| 打开 Windows JPG 保存框 | 通过 |
| 取消保存并返回应用 | 通过 |
| 应用窗口响应状态 | 正常 |
| 修复版启动后的 Application Error | 0 条 |

修复版测试进程在回归结束时仍正常运行，Windows 返回 `Responding = true`。

## 9. 产物

修复后的 Windows x64 release：

```text
build/packages/BeadPatternStudio-windows-x64-release.zip
```

SHA-256：

```text
BC224547A95E1A6E64894858CD034691A26380B05762EF9063F7480D0A0F8901
```

压缩包大小：12,863,612 字节。以上哈希已基于最终修复版本重新打包并计算；后续如再次打包，ZIP 哈希会随之改变。

## 10. 后续建议

1. Flutter SDK 升级后，继续在 Windows UI Automation 或 Narrator 开启条件下执行图片加载回归。
2. 对会整体替换复杂子树的区域，谨慎使用 `AnimatedSwitcher`、`Hero` 等会临时重挂节点的组件。
3. Windows 原生崩溃应保留事件日志中的模块、异常码和偏移，并优先使用 Flutter SDK 自带 PDB 进行符号解析。
4. Windows 交付回归至少覆盖：图片加载、裁剪、生成、颜色统计、打开/取消导出保存框。
5. 如果未来恢复过渡动画，需要单独验证 AccessibilityBridge 行为，不能只依赖无辅助功能客户端的手工测试。

## 11. 结论

本问题是 Flutter 3.44 Windows AccessibilityBridge 在处理 `AnimatedSwitcher` 造成的语义节点移除/重挂时发生的原生访问冲突。通过保持 Workspace 单一语义树解决了闪退，并使用原生 C++ 异步文件通道降低了 Windows 文件操作的额外风险。修复已在原始复现图片和原始辅助功能触发条件下完成端到端验证。
