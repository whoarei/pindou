# GitHub Actions Android 发布构建失败问题分析报告

## 1. 文档信息

| 项目 | 内容 |
| --- | --- |
| 应用 | 拼豆工坊（Bead Pattern Studio） |
| 影响范围 | GitHub Actions Android release APK 构建与 GitHub Release 发布 |
| 问题日期 | 2026-08-09 |
| Flutter | 3.44.9 stable |
| 应用版本 | 1.0.0+1 |
| 问题状态 | 已修复并完成 CI 回归 |

## 2. 问题概述

首次通过 `v1.0.0` 标签执行发布 workflow 时，Windows x64 便携包构建成功，但 Android job 在恢复签名文件时失败。修正 GitHub Secret 后进行手动回归，Android job 又因 Gradle 中的 keystore 相对路径重复拼接而失败。

由于 Release job 依赖 Android 和 Windows 两个构建 job，Android 失败导致 GitHub Release 被跳过，未产生不完整的正式发布。

## 3. 第一次失败：Base64 Secret 无效

失败运行：

```text
Run ID: 31293011291
Trigger: push tag v1.0.0
Failed step: Restore Android signing key
```

关键日志：

```text
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/app/upload-keystore.jks
base64: invalid input
Process completed with exit code 1
```

### 3.1 根因

写入 GitHub Secret 时使用了：

```powershell
$base64 | gh secret set ANDROID_KEYSTORE_BASE64 --body -
```

`gh secret set` 的 `--body -` 没有按预期从标准输入读取内容，导致 Secret 中保存的不是有效的 keystore Base64 数据。Linux runner 因此无法解码签名文件。

### 3.2 修复

去掉 `--body -`，直接通过标准输入写入 Secret：

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes('E:\Android\libb.keystore')
) | gh secret set ANDROID_KEYSTORE_BASE64 --repo whoarei/pindou
```

修复后，`Restore Android signing key` 步骤能够正常生成：

```text
android/app/upload-keystore.jks
```

## 4. 第二次失败：Gradle keystore 路径重复

失败运行：

```text
Run ID: 31293316507
Trigger: workflow_dispatch
Failed step: Build release APK
```

关键日志：

```text
Execution failed for task ':app:validateSigningRelease'.
Keystore file '.../android/app/app/upload-keystore.jks' not found
for signing config 'release'.
```

### 4.1 根因

CI 将 keystore 写入：

```text
android/app/upload-keystore.jks
```

但生成的 `android/key.properties` 使用了：

```properties
storeFile=app/upload-keystore.jks
```

`android/app/build.gradle.kts` 在 app 模块中通过 `file(storeFile)` 解析相对路径，其基准目录已经是 `android/app`。因此 `app/` 被再次拼接，最终错误地解析为：

```text
android/app/app/upload-keystore.jks
```

### 4.2 修复

将 CI 生成的配置改为相对于 app 模块的文件名：

```properties
storeFile=upload-keystore.jks
```

修复提交：

```text
eece9a2 ci: fix Android keystore path
```

## 5. Node.js 运行时警告

首次运行还出现了部分 action 仍声明 Node.js 20 的弃用警告。该警告不是 Android 构建失败的直接原因，但为避免后续兼容问题，已升级到使用 Node.js 24 的稳定主版本：

| Action | 原版本 | 新版本 |
| --- | --- | --- |
| `actions/checkout` | `v4` | `v7` |
| `actions/upload-artifact` | `v4` | `v7` |
| `actions/download-artifact` | `v4` | `v8` |
| `softprops/action-gh-release` | `v2` | `v3` |

升级提交：

```text
33033cb ci: upgrade actions to Node.js 24
```

## 6. 回归验证

修复后通过 `workflow_dispatch` 执行完整 CI：

```text
Run ID: 31293490740
Result: success
```

| 验证项 | 结果 |
| --- | --- |
| Flutter 依赖安装 | 通过 |
| GitHub Secret 注入 | 通过 |
| keystore Base64 解码 | 通过 |
| Gradle release 签名校验 | 通过 |
| Android release APK 构建 | 通过 |
| Android artifact 上传 | 通过 |
| Windows release 构建 | 通过 |
| Windows 便携 ZIP 打包与上传 | 通过 |

手动触发按设计不创建 GitHub Release，因此 Release job 被跳过属于正常行为。

## 7. 安全性检查

- keystore 文件未提交到 Git 仓库。
- `android/key.properties` 已被 `.gitignore` 忽略。
- keystore 内容、store password、key password 和 alias 均通过 GitHub Actions Secrets 注入。
- workflow 日志中的 Secret 值由 GitHub 自动遮蔽。
- 报告中未记录任何签名密码或 keystore 原始内容。

## 8. 后续预防措施

1. 修改签名恢复逻辑后，先用 `workflow_dispatch` 完整验证，再创建正式发布标签。
2. 明确记录 Gradle `file()` 的相对路径基准；app 模块内的路径默认相对于 `android/app`。
3. 写入二进制 Base64 Secret 后，应在 CI 中先校验解码，再进入 Gradle 构建。
4. 保持 GitHub action 使用受支持的 Node.js 运行时版本。
5. Release job 必须继续依赖所有平台构建成功，避免发布缺少 APK 或 Windows 包的不完整版本。

## 9. 结论

本次发布失败由两个相互独立的签名配置问题造成：第一次是 keystore Base64 Secret 写入方式错误，第二次是 Gradle app 模块的相对路径重复拼接。两个问题均已修复，Android 正式签名 APK 与 Windows 便携包已在同一次手动 CI 中构建成功，具备重新执行 `v1.0.0` 正式标签发布的条件。
