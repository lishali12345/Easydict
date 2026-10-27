# ME-Dict 一条命令发布

- 状态：completed
- 创建日期：2026-10-27
- 负责人：/root
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

已有独立签名公证与 DMG 命令，COS 上传仍需手动运行另一个工具。用户要求合并为一条命令，
最终输出已验证的下载链接，便于持续迭代发布。

## 目标与范围

- 目标结果：publish 完成构建、签名、公证、COS 上传和匿名回读；resume 保留发布意图。
- 允许修改路径：scripts 下相关打包/COS 适配代码、忽略规则、分发说明和本任务 plan/history。
- 同任务 history：`docs/histories/2026-10/2026-10-27-medict-publish-command.md`
- 用户限制：保留本机安装与官方 Easydict，复用既有签名和凭据。
- 非目标：自动更新、版本号自动推断、全局安装依赖、改造外部 skill、新增测试。
- 验收标准：命令与失败状态清晰；只发布已公证原包；已存在对象可验证复用；公开下载哈希一致才输出链接。

## 工作计划

1. 新增 publish 入口、现有产物 upload 入口和发布续跑。
2. 复用现有 MeeTar COS 工具，凭据路径与解释器使用本机忽略配置。
3. 检查 Python 语法、CLI 失败边界，使用现有正式包执行真实上传复用与回读验证。
4. 按 review 技能审查修复，更新文档记录并本地提交。

## 风险与决策

- 初始 HEAD eccf7d973fe0cacd2c159aa13efcf2c1316b76e4，工作树与索引干净。
- 原 release/build-check 保持本地打包语义；仅 publish/upload 启用 COS。
- 已完成产物上传不要求 checkout 回到旧源码，但必须复核 manifest、哈希、签名和票据。
- 内容不同的同名 COS 对象拒绝覆盖，版本与 SHA-256 组成隔离路径。
- 无新增测试授权；采用真实 CLI 和既有产物检查，不制造 mock/harness。

## 进度

- [x] 核对现有流程与规则。
- [x] 实现与配置。
- [x] 验证与审查。
- [x] 记录完成，归档并纳入本任务本地提交。

## 验证

- Python 语法、CLI 参数边界与 diff whitespace 检查通过。
- `check-publish` 实际验证 Developer ID、公证 profile 与 COS bucket 访问通过。
- 对既有 `20261027T062540Z-d5ac5900` 执行 `upload` 与 `resume`，均重验签名/票据，
  复用已有 COS 对象并完整匿名下载 63,279,325 字节；SHA-256 与原 DMG 一致，输出下载链接。
- 修复虚拟环境 Python 路径 resolve 导致脱离 venv 的问题，实际预检重跑通过。
- 独立 review 无可确认 P0–P3 finding；审查后两个源码文件摘要未变化。
- 两个已安装 App 的 318 项文件摘要分别与任务前基线一致。
- 本轮未重新构建、公证或首次 PUT 新版本；新 publish 复用已实际验证的原打包流程，
  当前实测覆盖新增预检、正式包上传复用、下载验证及发布续跑。

## 完成条件

- 命令可执行，公开下载校验成功才返回链接，失败可续跑。
- 文档、审查和适用验证完成。
