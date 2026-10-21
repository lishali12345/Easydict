# Polish and Replace 使用已配置的翻译服务

- 状态：completed
- 创建日期：2026-10-21
- 负责人：Codex
- 关联 Issue/PR：None

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

中文转英文与英文多语言预览已经使用默认 OpenAI 配置的 `group/translate`，但 Polish and Replace
仍实例化继承内置 AI 的 PolishingService，因此绕过用户配置。

## 目标与范围

- 目标结果：Polish and Replace 复用默认 OpenAI 的 endpoint、model 和 API key，保留现有润色提示词。
- 允许修改路径：`Easydict/Swift/Feature/ActionManager/ActionManager.swift`、
  `Easydict/Swift/Service/OpenAI/OpenAIService.swift`、
  `Easydict/Swift/Service/AITool/PolishingService.swift` 及同任务 plan/history。
- 同任务 history：`docs/histories/2026-10/2026-10-21-medict-polish-configured-service.md`
- 用户限制：只解决本机使用，固定证书签名更新 ME-Dict；不影响官方 Easydict，不新增测试。
- 非目标：其他 AI 工具的服务选择、用户持久化提示词配置、应用分发与自动更新。
- 验收标准：现有相关测试和 Release 构建通过；实际润色请求进入 `group/translate` 并成功写回英文；
  安装包保持签名身份、辅助功能授权和官方应用文件不变。

## 工作计划

1. 将润色消息构造变成可复用的纯静态方法；通过 OpenAIService 的实例开关选择润色提示词，
   仅在 Polish and Replace 启用，避免注册新服务或修改持久化配置。
2. 运行静态检查、现有流取消测试和 Release 构建；使用 review 技能审查最终源码快照。
3. 使用现有本机更新脚本安装，核验签名、官方应用哈希、进程及 AX 权限。
4. 用 TextEdit 实际快捷键执行润色，分别回读请求路由、完成日志和编辑器结果。
5. 更新 history、归档计划、创建本地中文提交。

## 风险与决策

- 不能把润色变成同语言翻译；保留原 system prompt、few-shot 和检测语言。
- 不写入 OpenAI 的 systemPrompt、userPrompt 或 enableCustomPrompt，避免污染翻译配置。
- 不通过创建 PolishingService 实例获取提示词，避免其内置服务初始化写入模型偏好。
- 继续复用 StreamService 输出清理、取消和 ActionManager 的原文安全校验。
- 初始 HEAD：`ff8563289cdb35af85b60998d2c90ac84ade188e`；初始工作区干净。

## 进度

- [x] 定位现有服务调用、配置和提示词边界。
- [x] 完成最小实现、静态检查和现有取消测试（3/3）。
- [x] review 无 finding，最终源码快照一致。
- [x] Release 构建及固定签名安装通过，官方应用哈希不变，运行中 AX 权限为 true。
- [x] 完成实际润色请求和写回验收。
- [x] 归档，随本次实现创建本地提交。

## 验证

- `git diff --check`、三个 Swift 文件 SwiftLint strict 通过（0 违规）。
- 现有 `OpenAIStreamTaskControlTests` 3/3 通过；`python3 scripts/update-medict.py --build-only` 成功。
- `python3 scripts/update-medict.py --install-only` 成功，签名团队保持 `LC4969GPTD`，新包满足旧包
  designated requirement；构建和安装包 318 项文件哈希一致。
- 官方 Easydict 的 318 项文件哈希不变：
  `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- 新安装进程只读核验 `AXIsProcessTrusted() == true`，随后已解除调试附加。
- 用户确认 ⌃⌥P 成功润色并替换；TextEdit 回读为：
  `We have received your feedback and will reply to you as soon as possible.`，修正了样例中的
  `We has` 和 `reply you`，保留英文和原意。
- 10:35:05 与 10:35:20 的应用日志均记录 `service=OpenAI, model=group/translate`，
  `from=English, to=English` 并完成；对应本机路由 `1792546352330`、`1792546352331` 均为 HTTP 200，
  实际由配置组当时选用的 `workbuddy/deepseek-v4.1-flash` 响应。
- 现有测试未直接覆盖润色提示词，功能正确性通过保留提示词的代码核验和本机实际请求验证。

## 完成条件

- 用户请求的本机功能验证通过，无有效 review finding 未处理。
- 记录真实检查结果和边界，归档计划并创建本地提交。
