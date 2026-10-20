## 2026-10-20 | 任务：替换流程使用已配置的 OpenAI 翻译服务

**Links:** [执行计划](../../exec-plans/active/2026-10-20-medict-configured-replacement-service.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

修复中文转英文和多语言预览绕过配置调用内置 AI 的问题，使用用户已经配置的
`group/translate` 服务，重新编译、安装并验证，不影响官方 Easydict。
执行中用户进一步要求以本机可用和持续快速迭代为先，不扩展分发流程。

### 变更

- 两条翻译替换路径从 `BuiltInAIService()` 改为 `OpenAIService()`，读取现有默认 OpenAI
  实例的端点、APIKey、模型和自定义提示词，不写死本机地址或模型。
- 请求前同步本次源/目标语言，确保自定义提示词的语言变量对应当前译文目标。
- 服务失败提示补充服务名称和模型，保留原始错误；诊断日志记录服务、模型、语言及结果长度。
- 保留每个目标语言的独立请求实例、取消控制和原文本安全写回检查。
- 本地更新入口增加 `ONLY_ACTIVE_ARCH=YES`，仅构建本机 arm64，继续复用缓存和固定签名；
  本地开发说明同步更新。

### 设计意图

此次问题来自 ActionManager 显式构造内置服务，而不是用户设置的接口被限流。
用户指定的 `group/translate` 属于默认 OpenAI 服务配置域，直接复用该服务即可，
无需引入服务工厂、迁移配置或添加内置服务回退。Polish 的服务选择不变。

### 验证

- 当前 OpenAI 模型为 `group/translate` 且包含在有效模型列表；三个查询窗口均启用
  OpenAI、停用 BuiltInAI。只读核对，未修改本机服务配置。
- `xcodebuild test` 精确选择 `EasydictTests/OpenAIStreamTaskControlTests`：
  3 项通过，覆盖流取消控制；不将该结果视为实际路由或写回验收。
- 正式只读 `review` 无 finding，核对同步生成自定义提示词、独立流实例、取消和 Polish 边界；
  源码 SHA256 为 `321d82a3805cf060598f3c2ae5929e23c67bd8b63ca0126e3afa30c1b1c78821`。
- `git diff --check`：通过。
- Python 更新脚本 AST 语法检查通过。原双架构 Release 构建按用户最新要求主动停止，
  改为本机 arm64 构建；不计为通过或产品失败。
- `python3 scripts/update-medict.py --build-only`：本机 arm64 Release 构建成功；
  `lipo -archs` 确认为 `arm64`。固定签名与 designated requirement 校验通过。
- `--install-only`：安装、启动通过；安装包与产物摘要一致，官方 Easydict 318 个条目摘要不变。
- 安装后运行时只读 `AXIsProcessTrusted()` 为 true，无需再次授权。
- 本机更新脚本增量 review 无 finding，Python 源码 SHA256 为
  `5b5cc774c8aaff206195e8e78224603f00a6f1d40ad220c7191f1dd877c44ad3`。
- 真实替换：已准备独立 TextEdit 中文样例；因自动化工具无法可靠发送全局快捷键，
  待用户操作后与应用日志及本机路由记录交叉核验。

### 受影响文件

- `Easydict/Swift/Feature/ActionManager/ActionManager.swift`
- `scripts/update-medict.py`
- `docs/user-docs/zh/ME-Dict-local-development.md`
- `docs/exec-plans/active/2026-10-20-medict-configured-replacement-service.md`
- `docs/histories/2026-10/2026-10-20-medict-configured-replacement-service.md`

### 后续事项

- 安装后结合应用日志、路由记录及原输入框回读完成验收。
