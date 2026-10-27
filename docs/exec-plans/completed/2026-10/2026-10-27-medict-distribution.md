# ME-Dict Apple Silicon 分发流程

- 状态：completed
- 创建日期：2026-10-27
- 负责人：/root
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

当前日用 ME-Dict 使用 Apple Development 签名。同事需要独立配置服务并通过 DMG 安装；
需建立 Developer ID 签名、公证、打包流程，避免更改现有本机安装与签名配置。

## 目标与范围

- 目标结果：可重复执行的 arm64 Release 构建、签名、公证、DMG 与校验记录。
- 允许修改路径：`scripts/package-medict.py`、`scripts/medict_distribution.py`、
  `.gitignore`、相关构建/使用文档及本任务 plan/history。
- 同任务 history：`docs/histories/2026-10/2026-10-27-medict-distribution.md`
- 用户限制：不影响本机 ME-Dict 和官方 Easydict；同事自行配置翻译服务。
- 非目标：Intel、自动更新、远程发布、安装替换、权限数据库修改和服务共享。
- 验收标准：隔离构建成功，签名身份/包元信息/DMG 检查明确，未公证产物不标记可分发；
  证书与公证凭据可用后完成真实公证。两份已安装 App 文件哈希保持不变。

## 工作计划

1. 核对工具、签名身份和现有构建流程，保存本机安装基线。
2. 实现独立配置、预检、构建、签名、DMG、公证和恢复入口。
3. 验证实际 arm64 构建、失败边界与 DMG 内容；凭据齐全后执行正式流程。
4. 按 review 技能审查，修复有效问题；记录验证与环境阻塞，提交已验证代码。

## 风险与决策

- 用户已配置个人团队 LC4969GPTD 的 Developer ID Application 身份与公证凭据。
- 公证凭据只使用 Keychain profile；不读取或打包个人应用偏好/密钥。
- 构建使用独立 DerivedData、显式命令行覆盖签名；不改本机 xcconfig。
- 公证等待失败保留 submission ID，避免盲目重复上传；成功须检查 Accepted、staple 和 Gatekeeper。
- 初始 HEAD 为 `9e899cc1d8c3571d97d482759ee7b2249d3298b3`，工作树与索引干净。

## 进度

- [x] 核对环境和授权边界。
- [x] 完成脚本与使用文档。
- [x] 执行当前环境可完成的构建、签名顺序、DMG 内容验证与审查。
- [x] 记录脚本交付结果，准备本地提交。
- [x] 完成真实 Developer ID archive/export、App/DMG 公证、票据、Gatekeeper 与最终内容验证。

## 验证

- 初始只读检查：有效签名身份仅两份 Apple Development；Release 已启用 Hardened Runtime。
- `build-check --version 2.24.0 --build 67`：Release 构建成功，主程序为 arm64，
  14 个 Mach-O 文件均支持 arm64；最低 macOS 13.0，自动更新关闭。
- 对临时 App 副本使用现有 Apple Development 身份验证分层签名顺序：deep/strict/all-architectures
  通过，15 个签名检查对象具备团队与安全时间戳，主 App 和 Sparkle helper entitlement 保留。
  此结果不等于 Developer ID 签名或公证通过。
- 使用新构建生成 `NOT-FOR-DISTRIBUTION.dmg`：镜像校验、只读挂载、205 项 App 文件哈希、
  Applications 软链接、许可证、安装说明及源码归档检查通过；未安装、启动或公开该验证包。
- Python 语法、相对文档链接、`git diff --check`、无效版本和并发构建拒绝检查通过。
- review 修复两项：Sparkle ad hoc helper 分层签名；DMG 源码锁定原 commit，公证等待后再校验源码状态。
  复核无剩余有证据 finding。初次实现时未新增测试，也未执行真实 archive/export、公证与跨机器安装验收。
- 两份已安装 App 文件哈希与操作前完全一致；日用 ME-Dict 与官方 Easydict 均为 318 项。
- 初次实现时缺少分发证书与公证凭据；本次用户补齐后复用流程完成真实交付。

### 首次真实分发验证

- 版本 `2.24.0 (68)`，源码提交 `3c5210debfba17c8beef3c42353d1e414daa04e0`，
  run `20261027T062540Z-d5ac5900`；Developer ID 团队 `LC4969GPTD`。
- 独立 archive/export 成功；14 个 Mach-O 均支持 arm64，主程序仅 arm64，最低 macOS 13.0。
  固定证书、嵌套签名、Hardened Runtime、安全时间戳、无 get-task-allow、关闭自动更新均通过校验。
- App 公证 `8a7ae2dd-87ef-4c92-9805-f9c64e937bf8` 为 Accepted。
- DMG 首次提交在读取 Keychain profile 时失败；用户重新保存后，通过认证的历史记录确认
  只有 App 提交。备份失败状态及日志、验证原 DMG 哈希后，仅清除未上传 DMG 的提交意图并续跑。
  未重新编译、未重复提交 App，也未将未知提交结果当作失败直接重传。
- DMG 公证 `7e552a73-0b3e-4146-9afc-4c0fc30b6792` 为 Accepted；App/DMG
  staple、票据校验及 Gatekeeper 均通过，manifest 状态为 ready。
- 最终 `ME-Dict-2.24.0-68-arm64.dmg` 约 60.3 MiB，SHA-256：
  `0aaebe5f0ca32d0e55e88202dd261fc14ce8e6f763b55ed7c7242a51c1ca0378`。
- 最终 DMG 只读挂载：App 与已公证导出包逐文件一致，Applications 链接、安装说明、GPLv3
  许可证和源码归档正确；源码中的 WhatsApp 修复与构建 commit 一致。本机私有签名配置不在源码中。
- 未安装、启动或注册分发 App。前后本机 ME-Dict 318 项文件摘要均为
  `84f301bbfe892309432bd074b3d6dcfee78bce1d585d9936f35e246004428d85`，官方 Easydict 均为
  `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- 本次仅补充文档记录，未修改生产源码或打包脚本；未执行跨机器首次安装/覆盖更新验收，
  此项仍需同事在另一台 Apple Silicon Mac 完成。签名公证不代替辅助功能等首次隐私授权。

## 完成条件

- 脚本和文档完成，构建与适用检查通过，review 无未解决有效 finding。
- 真实签名/公证依赖若未提供，明确保留环境阻塞，不把未签名包交付为分发包。
- 对照哈希证明现有应用不变；完成 history 与本地提交。
