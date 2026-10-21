# WhatsApp Web 输入框替换兼容

- 状态：completed
- 创建日期：2026-10-21
- 负责人：Codex
- 关联 Issue/PR：None

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

用户在 Chrome 的 WhatsApp Web 输入中文并执行 Translate and Replace，翻译成功但进入仅复制预览，
替换按钮和 Control+数字不可用。应用日志确认快捷键已触发并成功使用 `group/translate`。
本机只读 DOM 显示消息编辑器为 contenteditable textbox；原生 AX 将其标为可写，但通过 AXValue
写入未发送样例未改变内容，普通网页输入则成功。当前 ReplacementContext 仅允许 AX 直接写入并立即回读。

## 目标与范围

- 目标结果：在可验证的网页输入框中完成中文转英文和预览选择替换，保留原文变化保护。
- 允许修改路径：`Easydict/Swift/Feature/ActionManager/ReplacementContext.swift`、必要时
  `ActionManager.swift`，以及同任务 plan/history。
- 同任务 history：`docs/histories/2026-10/2026-10-21-medict-web-replacement.md`
- 用户限制：本机快速迭代，固定签名更新 ME-Dict，不影响官方 Easydict，不新增测试。
- 非目标：发送 WhatsApp 消息、改变翻译服务、扩展无可验证选区的写回权限。
- 验收标准：真实 WhatsApp 草稿完成中文直替换和多语言预览替换；保留原文、取消及原生编辑器保护。
  正向流程实测，其余保护核对代码与原有验证记录，明确本次覆盖边界。

## 工作计划

1. 确认 Chrome 编辑器捕获及直接 AX 写入的实际失败位置。
2. 对可靠捕获的 Chrome 文本框预先选择有校验的粘贴路径，避免 AX 写入与粘贴叠加。
3. 运行静态检查、适用现有测试及 Release 构建，按 review 技能审查。
4. 固定签名安装，核验官方文件哈希及 AX 权限，实际验证 WhatsApp，审查原生编辑器路径保持不变。
5. 更新 history、归档计划并创建本地提交。

## 风险与决策

- 粘贴发出后只有确认写回且剪贴板版本未被其他操作改变时才恢复；未确认则保留译文，
  防止延迟处理的 Paste 读到旧剪贴板内容。必须覆盖失败、原剪贴板为空和取消路径。
- 发出写入前再次核对原应用、元素、全文与 UTF-16 选区；不能只凭浏览器进程或菜单可用就写入。
- Chrome 文本框在写入前直接选择 Paste 菜单，原生编辑器保留 AX 路径，单次请求只发出一次写入。
- 不使用回车或自动发送，不修改客户消息。
- 初始 HEAD：`8c47913ce383ade88cba55174f765d028ec90569`；初始工作区干净。

## 进度

- [x] 核对调用链、服务日志、浏览器及 contenteditable 编辑器的 AXValue 无操作现象。
- [x] 用户复现仅复制，原中文保留；实现 Chrome Paste 兼容和不记录正文的上下文日志。
- [x] 最终 Release 构建、review 复核和固定签名安装；官方文件哈希未变、AX 权限有效。
- [x] 用户实际交互验收通过，完成记录并归档；随本次修复创建本地提交。

## 验证

- 原输入框空白时，AXValue 设置未产生 DOM 文本；使用浏览器输入 API 则成功。
- 用户实际快捷键复现：仅复制，原中文保留。
- SwiftLint 2 文件 0 违规；现有 OpenAIStreamTaskControlTests 3/3 通过（不覆盖网页粘贴）。
- Review 识别并修复未确认粘贴时恢复旧剪贴板的时序风险；最终差异复核无未处理 finding。
- 最终 Release 构建通过，源码快照与审查一致；安装包与构建包 318 项文件哈希一致：
  `2107e30fa245520aff7036bf9b5f32306e97e555bc2f3b005c5dcfbbd65e6779`。
- 固定签名团队 `LC4969GPTD`，满足原 designated requirement，运行进程 AX 权限为 true。
- 官方 Easydict 318 项文件摘要不变：
  `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- 用户确认 WhatsApp 中文经 ⌃⌥T 直接替换为英文；英文再次触发预览并按 Control+1 成功替换为印尼语。
- 11:23:33.440 与 11:23:45.984 两次日志均记录 `Replacement writeback verified: pasteMenu=true`。
- 中文转英文及四语预览共 5 个请求均经 `group/translate` 成功返回 HTTP 200。
- 验收后剪贴板与测试前基线一致；页面回读时草稿已空，未将该状态作为最终译文证据。
- 本次未重新手测输入变更、取消、剪贴板竞争与 TextEdit；这些路径通过代码审查，原生 AX 分支保持不变。

## 完成条件

- 实际替换验收通过，安全拒绝和取消逻辑完成代码审查，无未处理有效 finding。
- 官方应用保持不变，记录真实结果和验证边界，归档并本地提交。
