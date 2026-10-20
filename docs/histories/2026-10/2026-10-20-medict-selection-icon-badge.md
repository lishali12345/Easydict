## 2026-10-20 | 任务：为 ME-Dict 划词悬浮图标添加 ME 标识

**Links:** None

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

保留鼠标悬停到划词悬浮图标即翻译的交互，为 ME-Dict 的悬浮图标增加明显 ME 标识，
方便与本机官方 Easydict 区分，不影响官方版。

### 变更

- 在划词悬浮按钮创建时，用 AppKit 叠加深蓝底、白字和白描边的 ME 徽标。
- 通过 `normalImage` 同步正常、悬停、按下和选中状态的图像。
- 保留原有 23×23 点按钮、圆角、位置和悬停回调，不修改共享图片资源或查询设置。

### 设计意图

只在 ME-Dict 的悬浮按钮渲染处组合标识，避免改变其他界面的原始图片。
使用原生绘制适配屏幕缩放，同时保持原按钮的触发范围。

### 验证

- 初始工作区干净，基线 `dc7d5c777b84c13262a83dbb6d399a5b6280dba4`。
- `ME-Dict` scheme 的 Release 构建成功，SwiftLint 检查 432 个文件无违规，`git diff --check` 通过。
- 使用生产绘制表达式生成 1x、2x 和放大预览，确认 ME 标识可辨认且无裁切。
- `review` 审查通过，无需修复的 finding；审查后的产品源码与构建时一致。
- 新包签名校验通过，已安装并重新启动；安装包 300 个文件与构建产物逐一匹配。
- 官方 Easydict 应用的 300 个文件与安装前哈希基线一致。
- 从运行中进程导出浮标图像，确认含有 ME 标识；尺寸为 23×23 点，四种状态共享图像，
  `mouseEnterBlock` 仍非空。未重新进行鼠标悬停的端到端操作。
- 新包首次启动时辅助功能授权为 false；用户重新启用后，运行进程内
  `AXIsProcessTrusted()` 回读为 true。
- 不新增或扩写测试；本次为独立图标绘制改动，使用构建及视觉检查验证。

### 受影响文件

- `Easydict/objc/ViewController/Window/PopButtonWindow/EZPopButtonViewController.m`
- `docs/histories/2026-10/2026-10-20-medict-selection-icon-badge.md`

### 后续事项

- 无。
