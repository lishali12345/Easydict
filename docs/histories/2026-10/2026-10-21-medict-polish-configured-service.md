## 2026-10-21 | 任务：Polish and Replace 使用用户配置的服务

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-21-medict-polish-configured-service.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

让 Polish and Replace 使用已配置的 `group/translate` 服务，重新编译、安装和验证本机 ME-Dict，
不影响官方 Easydict。

### 变更

- ActionManager 的润色替换改为创建默认 OpenAIService，读取与翻译替换相同的 endpoint、model 和 API key。
- OpenAIService 增加默认关闭的实例内润色提示词开关，仅润色替换入口启用，不写入持久化配置。
- PolishingService 原提示词构造提取为静态方法，原服务继续委托它，避免复制提示词或实例化内置服务。

### 设计意图

服务配置和润色意图区分处理：复用已经可用的 OpenAI 请求与取消链路，保留原 system prompt、
few-shot、检测语言及输出清理。普通翻译继续使用原提示词选择规则，其他 AI 工具和服务注册保持原状。
不新增服务、配置项或测试代码。

### 验证

- `git diff --check`：通过。
- 对三个变更 Swift 文件执行 SwiftLint strict：0 违规。
- ME-Dict Debug 的现有 `OpenAIStreamTaskControlTests`：3/3 通过，覆盖请求取消，不作为润色内容验证。
- `review`：审查基于 `ff8563289cdb35af85b60998d2c90ac84ade188e` 的三个源码文件，无 finding；
  原润色提示词逐段一致，最终源码快照未变化。
- `python3 scripts/update-medict.py --build-only`：Release 构建及 deep/strict 签名校验通过。
- `python3 scripts/update-medict.py --install-only`：安装并启动成功，签名团队保持 `LC4969GPTD`，
  新包满足原 designated requirement；构建和安装包均为 318 项，摘要一致：
  `1650895d672edea29c31139dab1c5104512660d6586c7081a872a7394be8f1cc`。
- 官方应用 318 项文件更新前后无变化，摘要为
  `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- 安装后的运行进程 `AXIsProcessTrusted() == true`，读取后解除调试附加。
- 用户确认实际 ⌃⌥P 润色并替换成功。TextEdit 样例从
  `We has received your feedback and we will reply you as soon as possible.` 变为
  `We have received your feedback and will reply to you as soon as possible.`。
- 10:35:05、10:35:20 的应用日志均显示 `service=OpenAI, model=group/translate`，
  英文到英文请求完成；对应路由 `1792546352330`、`1792546352331` 均返回 HTTP 200，
  usage 与成功尝试均指向当时配置组选择的 `workbuddy/deepseek-v4.1-flash`。
- 路由组内部候选由用户配置决定；本次只切换客户端使用的服务配置，不固定或修改组内 provider。

### 受影响文件

- `Easydict/Swift/Feature/ActionManager/ActionManager.swift`
- `Easydict/Swift/Service/OpenAI/OpenAIService.swift`
- `Easydict/Swift/Service/AITool/PolishingService.swift`
- 同任务 plan/history。

### 后续事项

- None
