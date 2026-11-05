# MeeTar 翻译插件

给本机 Magpie 的 `group/translate` 请求补充 MeeTar 术语与表达约束，并保存请求和结果供旁路分析。ME-Dict、沉浸式翻译继续使用原来的服务地址和模型，无须重装。

## 本机安装和更新

需要正在运行的 Magpie（本次验证版本 `0.1.3051`）与 Bun。以下命令从仓库根目录运行：

```bash
bun integrations/magpie-meetar-translation/cli.mjs install
```

命令在 `~/Library/Application Support/MeeTarTranslation/` 初始化个人配置，只给 `~/.config/magpie/plugins.json` 添加本插件的绝对路径，保留其他插件。修改前保存独立备份，原子写入后回读。Magpie 下一次请求自动重新加载插件宿主，已有流式请求有排空期；不重启或覆盖应用。

插件从当前 checkout 原地加载，请保留这个目录。修改插件源码后重新运行 `install` 触发加载；该命令不会覆盖已编辑的术语文件。没有 npm 依赖，也无须 Xcode 构建。

禁用只修改本插件的 `off` 字段，保留已有记录及其他插件：

```bash
bun integrations/magpie-meetar-translation/cli.mjs disable
```

再次运行 `install` 即可启用。备份位于个人数据目录的 `backups/`；日常回退优先使用 `disable`，不要整体恢复旧列表而覆盖其他插件的新配置。

## 编辑术语和风格

个人配置文件：`~/Library/Application Support/MeeTarTranslation/policy.json`。修改后**下一次请求生效**，无需重启。初始内容见 [policy.example.json](policy.example.json)。

```json
"terms": [
  { "source": "主播", "english": "Host", "meaning": "MeeTar 中的直播角色" },
  { "source": "代理", "english": "Agency", "meaning": "MeeTar 中管理主播的业务组织，不是网络代理或具体个人" }
]
```

- `source` 和 `english` 必填，`meaning` 可选；同一 `source` 不重复。
- `context` 是业务背景，`style` 是表达偏好，可用中文或英文填写。
- `version: 1` 是文件格式版本；实际内容及生成规则的 SHA-256 作为每条记录的 `policyId`。
- 英文输出使用指定术语及大小写，允许必要复数和所有格，如 `Hosts`、`Agencies`。
- 非英语输出在同次请求内以英文术语的业务含义为参考，使用目标语言的自然表达；原文已是英文时同样适用。
- 术语按上下文含义匹配，不做原文或译文的字符串替换；网络代理仍是 proxy。
- 保留原任务的目标语言、批量结构和输出格式。润色仍是润色，不会变为自动客服回复。

保存前后可以验证配置：

```bash
bun integrations/magpie-meetar-translation/cli.mjs validate
```

无效配置会在 Magpie 诊断中显示 `policy_error`，该请求回退到客户端原请求；因此编辑 JSON 后应执行验证。提示词不能保证每次模型输出绝对符合术语约束，也不能仅凭英文表固定所有目标语言的唯一词形。

## 查询和导出

数据库：`~/Library/Application Support/MeeTarTranslation/records.sqlite`。

```bash
# 查看路径与捕获状态统计
bun integrations/magpie-meetar-translation/cli.mjs paths
bun integrations/magpie-meetar-translation/cli.mjs stats

# 最近 20 条元数据，不输出私人正文
bun integrations/magpie-meetar-translation/cli.mjs list 20

# 显式查看一条完整记录
bun integrations/magpie-meetar-translation/cli.mjs show <record-id>

# 导出到一个尚不存在的文件，不覆盖旧文件
bun integrations/magpie-meetar-translation/cli.mjs export /path/to/translations.jsonl
```

首次翻译前尚未创建数据库，查询会提示数据库不存在。导出为每行一条记录的 JSONL，可用于独立分析。`show` 和导出包含完整原文；默认目录权限 `0700`、配置/数据库/导出文件权限 `0600`，插件不上传记录、不自动清理或回写术语。

每条记录包含：

| 字段 | 含义 |
|---|---|
| `id`、`createdAt`、`completedAt` | 同一请求的 UUID 和 UTC 时间 |
| `agent`、`origin`、`session` | Magpie 提供的来源标签；不是已验证的用户或联系人身份 |
| `model`、`protocol` | 客户端请求的组名和协议；不是实际命中的上游模型 |
| `policyId`、`policy` | 所用规则指纹与配置快照 |
| `originalRequest` | 插件收到的完整协议 JSON，保留原始消息 |
| `effectiveRequest` | 本插件添加规则后的 JSON，不代表后续网关/其他插件处理后的最终上游报文 |
| `reply`、`responseText` | Magpie 合并后的客户端响应及提取的文本 |
| `query` | Magpie 提取的查询文本，可能含客户端任务包装，不冒充精确抽取的原文 |
| `captureStatus` | `awaiting_response`、`complete` 或 `incomplete` |

`complete` 只说明响应捕获完整，不代表翻译质量正确、文本已替换或消息已发送。`incomplete` 也不必然说明模型失败；取消、捕获上限等情况都可能导致它。缺少回调继续保留 `awaiting_response`，不可在分析中当成成功记录。

ME-Dict 的提示词中有示例对话，沉浸式翻译可能一次请求包含多个段落。分析时应区分示例、实际输入、重复请求及多个目标语言；语言不能证明用户国籍或消息收发方向。

## 作用域和限制

- 仅处理 `model` 和 `ctx.model` 均为 `group/translate`、来源为 `local` 或 `magpie-key` 的 Chat Completions 请求；跳过其他模型、远端/未知来源及其他协议。
- 官方 Easydict 的标准来源标签 `Easydict` 被明确排除，不注入规则也不采集；ME-Dict 的来源标签为 `ME-Dict`。这是本机共存规则，来源标签不是认证边界；更改客户端 User-Agent 后需重新核对。
- 除上述排除项，同一本机翻译组的其他客户端也会使用规则并被记录。
- 不读取认证 headers 或客户端密钥，不额外调用模型，不自动把分析结果变成政策或术语。
- `originalRequest` 保留的是解析后的 JSON 内容，不是原始 HTTP 字节序列。
- Magpie 的 `onResponse` 是尽力投递，流式捕获上限为 8 MiB。宿主退出、队列容量等可能丢回调，不能承诺零丢失。
- 写库异常会留下固定诊断码，翻译及术语注入继续；因此统计只反映成功入库的请求，不是完整流量账本。
- 私人配置、记录及备份不在仓库内，不会随 Git 提交。安装支持 `--directory /absolute/path`，必须指定插件专属目录，因为该目录权限会收紧到 `0700`；随后所有 CLI 命令应使用同一参数。

## 实现依据

- [Magpie 异步 hooks 契约](https://github.com/yetone/magpie/blob/main/docs/subsystems/gateway-request-hooks.md)
- [插件配置与热加载实现](https://github.com/yetone/magpie/blob/main/internal/plugin/store.go)
- [插件宿主实现](https://github.com/yetone/magpie/blob/main/internal/plugin/host.js)
- [客户端来源标签解析](https://github.com/yetone/magpie/blob/main/internal/usage/usage.go)
