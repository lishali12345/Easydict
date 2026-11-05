## 2026-11-05 | 任务：迁出 Magpie 插件并建立独立工程

**Links:** [执行计划](../../exec-plans/completed/2026-11/2026-11-05-magpie-plugin-extraction.md)、[迁移指引](../../user-docs/zh/ME-Dict-magpie-plugin.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.2 (27B52)`

### 用户请求

将 Magpie 翻译插件迁到用户指定代码目录下的独立插件父工程，并建立独立会话持续迭代。

### 变更

- 插件移入独立 `magpie-plugins` 工程的 `meetar-translation/`；7 个源码与配置文件内容不变，使用说明适配新执行目录。
- 独立工程初始化 Git，保留原仓库许可证并添加工程指引、项目上下文和迁移记录。
- 备份后仅替换 Magpie 当前插件条目的源码路径，保留所有 options 和其他插件。
- 移除本仓库的旧集成源码，增加迁移指引，并修复原实现 history 的使用说明链接。
- Codex 本地工程由用户在侧栏添加，已回读对应目录并创建「MeeTar 翻译插件迭代」独立会话，传入交接文档和运行状态。

### 设计意图

运行实现和后续迭代从 ME-Dict 仓库解耦，个人术语和翻译记录仍由原独立数据目录保存。通过原子替换既有路径，避免新旧插件同时启用而产生双重注入、重复记录。

### 验证

- 迁移前后源码 SHA-256 比对：7 个源码/配置文件完全一致。
- Node 语法、JSON 校验、Magpie Bun 1.4.4 构建：通过。
- 新位置恰好一个启用条目，旧位置条目为零，其他三个插件不变。
- 术语文件摘要和数据库 inode 不变，迁移前 42 条记录全部保留。
- 真实网关验收：ME-Dict 标签的流式请求、Mozilla 标签的非流式请求均返回规范英文术语，各注入一次并仅生成一条完整记录；后者在旧目录移除后完成。
- 验收请求仅使用无隐私样例，是来源与网关验证，不冒充重新操作真实客户端 UI。
- 未改 ME-Dict 或官方 Easydict 应用源码、安装包、签名及偏好。
- 独立迁移审查与文档相对链接：通过；本仓库 `git diff --check` 通过。
- 新工程 LICENSE 逐字保留原文两处纯空白行，仅该文件按来源一致性及允许行尾空白检查；其他文件标准 diff 检查通过。
- 新工程已创建初始本地提交 `a907ea3bc518ba07443186c8169bee89101ea605`，分支 `main`，没有远端仓库。

### 受影响文件

- 移除 `integrations/magpie-meetar-translation/` 中 8 个文件。
- `docs/user-docs/zh/ME-Dict-magpie-plugin.md`
- `docs/histories/2026-11/2026-11-05-magpie-translation-plugin.md`
- 同任务 plan 与本记录。
- 独立工程中的 `meetar-translation/`、`README.md`、`AGENTS.md`、`.gitignore` 和 `docs/`。

### 后续事项

- 后续插件迭代在独立工程进行；本次不创建远端仓库、不推送。
