## 2026-10-20 | 任务：精简 ME-Dict 多语言替换预览

**Links:** [执行计划](../../exec-plans/active/2026-10-20-medict-compact-replacement-preview.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

按照用户标注截图，移除英文多语言替换预览的标准窗口标题栏和操作按钮，使大小适应内容；
紧凑展示译文，语言标签浮于右上角，支持 Control+数字替换，并在底部居中提供圆形关闭按钮。

### 变更

- 使用可接收键盘焦点的无边框 `NSPanel`，首选宽度为 480 pt，高度根据正文测量更新。
- 译文逐条完成时保持顶边稳定；总高度限制为 640 pt 或屏幕可见区域减去边距，
  超出的正文滚动，关闭按钮始终位于滚动区域外。
- 卡片使用紧凑正文和操作区域，语言胶囊浮于右上角，复制改为具有可访问性标签的图标按钮。
- 按配置语言顺序为前九行绑定 Control+1…9；仅完成且允许替换的行可以触发。
- 底部圆形 × 和 Escape 复用取消入口；保留原文本上下文检查、重复替换防护和失败提示。

### 设计意图

在现有预览控制器内完成表现与键盘操作调整，不改变翻译调度、配置语言顺序或安全写回流程。
浮窗不在失焦时取消，避免替换流程激活原编辑器时中断自身。固定紧凑宽度配合高度测量，
使短译文无需大量空白，也保证长译文和错误提示下关闭入口始终可达。

### 验证

- `python3 scripts/update-medict.py --build-only`：Release 构建成功，固定开发团队签名校验通过。
- 原生临时预览直接编译生产 UI 文件，浅/深色覆盖短文、长文、加载、失败、零目标提示、
  仅复制共 12 场景。短文为 480×454 pt；最终长文浅/深色为 480×640 pt，关闭入口完整可见。
- 异步回译原生采样：高度 270→316→362→408→454 pt；宽度 480 pt，顶边保持稳定。
  连续采样无尺寸跳动。小屏幕边界核对源码，未修改系统分辨率模拟。
- 正式只读 `review`：无 finding；检查前后源码 SHA256 一致：
  `7b1cb3d5a8339d333c240f24becf92e6a63b6c68f509b0c7f50c52b56e79f82b`。
- `python3 scripts/update-medict.py --install-only`：安装、签名兼容和启动通过，
  安装包与构建产物 318 个条目的摘要一致；官方 Easydict 318 个条目的摘要保持不变。
- 安装后运行时只读检查 `AXIsProcessTrusted()` 为 true，辅助功能授权保留。
- `git diff --check`：通过。
- 真实交互：自动化工具未能正确发送全局快捷键；已撤销样例变化并回读确认英文恢复。
  新窗口的人工关闭和数字快捷替换验收待用户反馈。

### 受影响文件

- `Easydict/Swift/Feature/ActionManager/ReplacementPreviewController.swift`
- `docs/exec-plans/active/2026-10-20-medict-compact-replacement-preview.md`
- `docs/histories/2026-10/2026-10-20-medict-compact-replacement-preview.md`

### 后续事项

- 确认本机真实 Control+数字事件触发替换，以及 × 关闭保留原文。
