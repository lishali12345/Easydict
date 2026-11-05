## 2026-11-05 | 任务：接入 Magpie 翻译术语与本机记录插件

**Links:** [执行计划](../../exec-plans/completed/2026-11/2026-11-05-magpie-translation-plugin.md)、[独立工程与使用说明](../../user-docs/zh/ME-Dict-magpie-plugin.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.2 (27B52)`

### 用户请求

在本机 Magpie 翻译服务中加入可编辑的中文到规范英文术语列表，允许必要语法变化；非英语翻译以英文术语为含义基准。完整保留请求和返回结果用于旁路分析，并通过 ME-Dict 与沉浸式翻译验证。

### 变更

- 新增独立 Bun hooks 插件，限定本机 `group/translate` 的 Chat Completions 请求；官方 Easydict 的标准来源标签被排除。
- 初始术语为主播→Host、代理→Agency，支持复数/所有格、业务含义消歧及自然日常表达。
- 每请求读取个人配置，原文保持完整，只追加场景和术语指令，保留客户端目标语言与批量输出契约。
- SQLite 保存原始请求、注入后请求、策略快照/指纹及响应；区分等待响应、完整与不完整捕获。
- 提供安装、禁用、配置验证、元数据列表、单条读取、状态统计及 JSONL 导出命令。
- 安装前备份 Magpie 插件列表，原子追加自己的条目并回读；保留原有三项插件，源码更新后可重复安装触发热加载。
- 私人配置、记录和备份在独立本机目录，未加入 Git；新增中文使用说明，未新增测试文件。

### 设计意图

通过 Magpie 的统一翻译入口覆盖两个现有客户端，避免分别修改应用和浏览器插件。英文作为术语级语义基准，不进行整段双重转译或机械字符串替换。采集与后续分析分离，不自动将历史内容升级为政策，也不把译文生成认定为消息已发送。

Magpie 的完成回调是尽力投递；记录状态反映捕获完整性，不推断模型调用一定成功或失败。存储故障会记录固定诊断码，翻译继续，因此不承诺完整流量账本。

### 验证

- `node --check`、JSON 格式检查、Magpie 实际 Bun 1.4.4 的 `bun build --target=bun`：通过。
- `git diff --check` 与文档相对链接检查：通过。
- 独立 review 核对插件源码、配置和本机 Magpie 宿主契约：未发现确定性缺陷。
- 直接通过现有翻译组请求：英文使用 `Hosts` / `Agencies`，网络代理仍为 `network proxy`，非流式结果完整入库。
- 沉浸式翻译 1.34.4：使用既有 magpie 服务完成英文→中文及英文→印尼语网页翻译，保留 `[[pN]]` 批量段落结构，4 条实际请求和结果均完整保存。验收后恢复原有简体中文目标语言。
- ME-Dict：用户打开并钉住主窗口后，实际中文→英文与英文→中文翻译成功。两次 `stream: true` 请求各含 28 条消息，原始正文消息和请求参数不变，术语指令已加入，流式聚合结果与界面一致并完整入库。
- 定向验收共 7 条样例请求全部为 `complete`；未将用户期间正常使用的请求正文用于报告。
- SQLite `integrity_check` 返回 `ok`；JSONL 导出可逐行读取；目录 `0700`，配置和数据库 `0600`。
- 其他模型及 remote/gateway-key 来源被跳过；原有三项 Magpie 插件配置保持一致。
- 收尾核对发现官方 Easydict 同样使用该翻译组，补充标准来源标签排除并重新热加载。以两种标准 User-Agent 发送相同术语样例：官方标签返回原有常见译法且未入库，ME-Dict 标签返回 Host/Agency 且完整入库；未启动或改动官方 App。
- ME-Dict 与官方 Easydict 的应用文件哈希前后一致。未修改应用源码、签名、安装包，因此未运行无关 Xcode 构建。

### 受影响文件

- `integrations/magpie-meetar-translation/package.json`
- `integrations/magpie-meetar-translation/translation.hooks.mjs`
- `integrations/magpie-meetar-translation/policy.mjs`
- `integrations/magpie-meetar-translation/policy.example.json`
- `integrations/magpie-meetar-translation/records.mjs`
- `integrations/magpie-meetar-translation/paths.mjs`
- `integrations/magpie-meetar-translation/cli.mjs`
- `integrations/magpie-meetar-translation/README.md`
- 同任务执行计划和本记录。

### 后续事项

- 提示词不能保证所有模型输出绝对遵守术语；旁路质量分析尚未实现。
- 首版仅处理当前两个客户端使用的 Chat Completions 协议；不涵盖远端共享请求。
- 除官方 Easydict 的标准来源标签外，同一本机翻译组的其他客户端也会经过规则与采集；来源标签不是认证边界，更改客户端 User-Agent 后需重新核对。
