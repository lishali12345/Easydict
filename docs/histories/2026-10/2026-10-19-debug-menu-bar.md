## 2026-10-19 | 任务：区分 Debug 菜单栏图标

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-19-debug-menu-bar.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

让 Debug 菜单栏图标明显区别于正式版，便于同时运行时识别，不影响正式版。

### 变更

- 在 Debug 菜单栏所选图标右侧绘制加粗 DEBUG 标识，按文字实际宽度生成 NSImage。
- 使用模板图渲染，使图标和文字随菜单栏外观适配；使用绘制回调支持分辨率无关渲染。
- 保留方形和圆形图标偏好，以及原有悬停提示的本地化路径。
- 通过编译条件隔离 Debug 图像合成；Release 仍使用原资源、模板渲染及原提示文本。

### 设计意图

将固定构建标识嵌入菜单栏图像，避免 icon-only 标签省略文字，也不改变菜单内容、设置入口或用户偏好。
只修改应用入口的菜单栏图像构造，不新增资源、通用绘制模块或业务逻辑。

### 验证

- 最终源码 Debug `xcodebuild build`：通过，SwiftLint 0 violations，codesign 校验通过；已重启最终产物。运行时图像检查后仅恢复了原悬停提示，图标绘制逻辑未变。
- 运行时检查：通过 LLDB 读取 NSStatusBarButton 实际图像，按钮为 66 × 22 点，图像为 50 × 18 点，isTemplate 为 true；导出 PNG 并检查透明度轮廓，右侧完整显示 DEBUG，未裁切。已解除调试器附加，Debug 正常运行。
- 最终源码 Release `xcodebuild build`：通过（本地 ad hoc 签名），SwiftLint 0 violations，codesign 验证通过。未启动 Release 校验产物，并已取消其 LaunchServices 注册。
- 正式安装包 Info.plist、可执行文件、Assets.car 和 icns 哈希与修改前一致。
- `git diff --check`：通过。
- Review：基线 ef61fc336a62bbe6739b7babca285f4a6514465d；检查单个产品文件的改动、图标偏好更新链路和编译分支，发现并修复了悬停提示改用动态 String 后改变 Release 本地化语义的问题，保留原 `.help` 调用；图像合成无需新增通用绘制抽象。修复后的产品源码快照复验通过，未发现剩余有效 finding。
- 未新增测试；现有测试未覆盖该菜单栏渲染，未运行不相关的测试套件。CUA 读取菜单栏超时，改为调试器读取实际运行对象；未验证菜单点击交互，菜单内容和动作未修改。

### 受影响文件

- `Easydict/App/EasydictApp.swift`
- `docs/exec-plans/completed/2026-10/2026-10-19-debug-menu-bar.md`
- `docs/histories/2026-10/2026-10-19-debug-menu-bar.md`

### 后续事项

- None
