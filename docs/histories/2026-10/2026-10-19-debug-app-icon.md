## 2026-10-19 | 任务：为 Debug 应用图标添加醒目标识

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-19-debug-app-icon.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

为 Debug 应用图标增加明显的 DEBUG 标识，不影响正式版。

### 变更

- 新增 Easydict-debug.icon，复制 Easydict-27 的原生分层图标，在最前层分组增加橙色 DEBUG 标识。
- 标识采用矢量轮廓文字，构建和运行时不依赖字体安装状态。
- 增加工程 file reference、Icons group 与 Resources 引用；仅将 Debug 的 ASSETCATALOG_COMPILER_APPICON_NAME 改为 Easydict-debug。
- Release 继续选择 Easydict-27；不修改原图标、菜单栏图标、应用功能和数据。

### 设计意图

通过独立资源和按构建配置选择图标隔离开发版与正式版，保留原 Icon Composer 外观定义。
橙色横条与黑色 DEBUG 文字提供明显的视觉区分；原图层仅复制、不修改。

### 验证

- Debug `xcodebuild build`：通过；SwiftLint 0 violations，codesign 校验通过。
- 初次资源编译发现 Icon Composer 最多允许四个可见分组；将标识加入现有前景分组后重新构建通过。
- 图标视觉检查：编译产物的 256px 与 32px 图标均有明显橙色标识；从 macOS NSRunningApplication.icon 读回实际运行图标，确认 DEBUG 已显示。
- Debug 重启后名称仍为 Easydict-debug，CFBundleIconFile 为 Easydict-debug，自动检查/下载偏好仍为 0。
- Release `xcodebuild build`：通过（本地 ad hoc 签名）；SwiftLint 0 violations，codesign 验证通过。CFBundleIconFile 仍为 Easydict-27，重新生成的 icns SHA-256 与修改前一致。
- 正式版原始图标资源、已安装正式版 Info.plist / 可执行文件 / Assets.car / icns 哈希均未变化。Release 校验产物未启动，并已取消其 LaunchServices 注册。
- JSON、SVG XML、工程 plist 及 `git diff --check` 检查通过。
- 资源与工程差异检查：原图层保持一致；新资源引用完整；Release app icon 选择未变。本任务为资源与简单构建配置调整，无新增测试或业务代码。

### 受影响文件

- `Easydict/App/Icons/Easydict-debug.icon/icon.json`
- `Easydict/App/Icons/Easydict-debug.icon/Assets/`（五个原图层副本及 debug-badge.svg）
- `Easydict.xcodeproj/project.pbxproj`
- `docs/exec-plans/completed/2026-10/2026-10-19-debug-app-icon.md`
- `docs/histories/2026-10/2026-10-19-debug-app-icon.md`

### 后续事项

- None
