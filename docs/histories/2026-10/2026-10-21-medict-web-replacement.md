## 2026-10-21 | 任务：兼容 Chrome 网页输入框替换

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-21-medict-web-replacement.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

修复 WhatsApp Web 中 Translate and Replace 翻译成功但只能复制、替换按钮及 Control+数字禁用的问题。

### 变更

- Chrome 的 AXTextArea 在完整捕获和验证原选区后，使用该应用的 Paste 菜单；其他输入框保留 AX 写入。
- 粘贴前再次核对原应用、元素、全文、选区及剪贴板版本，无异步间隙地发出一次 Paste。
- 通过有界回读确认预期全文；发出 Paste 后的回读不随外层请求取消而提前恢复剪贴板。
- 成功时恢复原剪贴板，包括原剪贴板为空；若剪贴板已经变化则不覆盖新内容。
  Paste 未确认时保留译文，避免延迟的 Paste 读取被过早恢复的旧内容。
- 添加仅包含应用标识、捕获状态和写入方式的诊断日志，不记录正文。

### 设计意图

Chrome 网页编辑器可以宣称 AX 属性可写却不更新真实编辑状态。预先为 Chrome 文本框选择正常粘贴路径，
可让网页编辑器处理输入，同时避免先尝试 AX 再粘贴产生重复写入。仍要求可靠的全文和 UTF-16 选区快照，
不会向未验证的输入位置盲目粘贴，也不发送消息。

### 验证

- 修改前：实际 WhatsApp 空输入框的 AXValue 设置未生效，网页输入 API 可写；用户实际快捷键复现
  翻译成功、仅复制、中文保留。
- SwiftLint：两个变更文件 0 违规；`git diff --check` 通过。
- 现有 OpenAIStreamTaskControlTests：3/3 通过，不覆盖网页粘贴；之后 review 收紧未确认粘贴的
  剪贴板恢复条件，最终版本以 Release 构建和真实交互验证为准。
- Review：基于 `8c47913ce383ade88cba55174f765d028ec90569` 核对完整差异及菜单、剪贴板依赖。
  已修复未确认粘贴时过早恢复旧剪贴板的时序风险，复核原文保护、取消、空剪贴板和只发出一次动作。
- `python3 scripts/update-medict.py --build-only`：最终 Release 构建及签名验证通过，源码与审查快照一致。
- `python3 scripts/update-medict.py --install-only`：安装成功，签名团队保持 `LC4969GPTD`，
  满足原 designated requirement；构建与安装包 318 项文件哈希一致：
  `2107e30fa245520aff7036bf9b5f32306e97e555bc2f3b005c5dcfbbd65e6779`。
- 官方 Easydict 318 项文件摘要不变：
  `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- 新安装进程 `AXIsProcessTrusted() == true`，只读检查后已解除调试附加。
- WhatsApp 实际验收：用户确认中文经 ⌃⌥T 直接替换为英文，英文经预览 Control+1 替换为印尼语，两步均成功。
- 11:23:33.440、11:23:45.984 均记录 `Replacement writeback verified: pasteMenu=true`；
  中文转英文及四语预览共 5 个请求通过 `group/translate` 返回 HTTP 200。
- 剪贴板与测试前基线一致。页面最终回读时草稿为空，译文写回结论来自用户现场确认及应用精确全文校验日志。
- 验证边界：本次未重新手测输入变更、取消、剪贴板竞争和 TextEdit；相应保护已审查，原生 AX 分支未改变。

### 受影响文件

- `Easydict/Swift/Feature/ActionManager/ReplacementContext.swift`
- `Easydict/Swift/Feature/ActionManager/ActionManager.swift`
- 同任务 plan/history。

### 后续事项

- None。
