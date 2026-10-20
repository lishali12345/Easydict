# 替换流程使用已配置的翻译服务

- 状态：completed
- 创建日期：2026-10-20
- 负责人：/root
- 关联 Issue/PR：None

## 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

用户已配置 OpenAI 服务的 `group/translate` 模型并停用内置 AI，
但中文转英文和英文多语言预览仍显式构造 `BuiltInAIService`，
导致请求绕过用户配置并显示内置服务的速率限制错误。

## 目标与范围

- 目标结果：两条翻译替换路径使用现有 OpenAI 配置，失败时标明服务和模型。
- 允许修改路径：`ActionManager.swift`、`scripts/update-medict.py`、
  `docs/user-docs/zh/ME-Dict-local-development.md`、本任务 plan/history。
- 同任务 history：`docs/histories/2026-10/2026-10-20-medict-configured-replacement-service.md`
- 用户限制：重新编译安装并验证；官方 Easydict 不受影响。
- 非目标：修改本机接口/密钥/路由配置、Polish 服务选择、替换安全校验、预览布局。
- 验收标准：中文到英文及四语请求均到达已配置的 `group/translate`，返回可用译文；
  无内置 AI 回退；固定签名安装后权限有效，官方应用摘要保持不变。

## 工作计划

1. 核对 OpenAI 配置读取、提示词语言变量和请求取消边界。
2. 修改两条服务构造路径，补充失败来源和必要请求诊断。
3. 运行现有相关测试、Release 构建和正式 review。
4. 固定签名安装，以应用日志及本机路由记录核验实际请求，完成真实替换验收。
5. 记录结果、归档本计划并创建本地提交。

## 风险与决策

- 使用 `OpenAIService` 默认实例读取现有端点、密钥、模型和自定义提示词，不将本机地址写入源码。
- 自定义提示词取语言变量自 `queryModel`，请求前显式同步本次源/目标语言。
- 保留每种语言独立 service 实例，取消操作及写回校验保持原有语义。
- 不新增测试文件、用例、fixture 或生产测试 hook；运行现有测试并验收实际路由。
- 诊断记录仅包含服务、模型、语言和结果长度，不记录文本或凭据。
- 用户补充本机优先、快速迭代：本地更新入口仅构建 arm64，保留增量缓存和稳定签名，
  不引入分发、公证或发布流程。

## 进度

- [x] 确认硬编码内置服务与当前配置不一致。
- [x] 修改路由及失败来源。
- [x] 测试、构建与审查。
- [x] 安装、权限与实际请求核验。
- [x] 记录和提交（实现提交 `21b1c5ef`，本次补齐验收记录）。

## 验证

- 初始工作区干净，HEAD 为 `5d55c6cd1e22c5e7a0d05771c953853c60790946`。
- 当前三个窗口配置均为 OpenAI 启用、BuiltInAI 停用；模型为 `group/translate`。
- 用户截图的四个错误直接来自内置服务；现有代码两个翻译入口均构造 `BuiltInAIService`。
- 现有 `OpenAIStreamTaskControlTests` 的 3 项测试通过，测试仅覆盖流取消边界。
- 正式只读 review 无 finding；源码 SHA256 为
  `321d82a3805cf060598f3c2ae5929e23c67bd8b63ca0126e3afa30c1b1c78821`。
- 本机路由日志已记录验收前基线，后续按请求 ID 关联实际 provider 和模型；
  不以普通翻译查询成功代替替换流程验收。
- 本机 arm64 Release 构建通过，`lipo -archs` 为 `arm64`，固定团队签名检查通过。
- 安装后应用包与产物摘要一致；官方 Easydict 318 个条目摘要不变。
- 安装后 `AXIsProcessTrusted()` 为 true，无需再次授权。
- 用户确认中文转英文、四语预览、Control+1 替换均成功。
- 21:36:42 至 21:36:59（UTC+8）的应用日志记录中文到英文及英文到四个目标语言均完成；
  对照安装后基线新增的 5 个路由请求全部为 `group/translate`、HTTP 200。
  成功尝试及 usage 记录确认实际提供方为 `codex`、模型为 `gpt-6-luna`，无回退。
- TextEdit 原输入框回读为印尼语：
  `Halo, kami telah menerima masukan Anda dan akan menindaklanjutinya sesegera mungkin.`

## 完成条件

- 代码、测试、安装和实际路由证据一致；记录真实写回验证结果或明确边界。
- 官方应用保持独立，代码审查通过，本地提交范围受控。
