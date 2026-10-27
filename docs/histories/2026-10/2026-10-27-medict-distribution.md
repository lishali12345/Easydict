## 2026-10-27 | 任务：建立 ME-Dict 独立签名公证与 DMG 分发流程

**Links:** [执行计划（首次真实公证待凭据）](../../exec-plans/active/2026-10-27-medict-distribution.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

提供可重复的 Apple Silicon Developer ID 签名、公证、DMG 流程；同事自行配置服务，
不影响开发者本机 ME-Dict 与官方 Easydict。

### 变更

- 新增 `check`、`build-check`、`release`、`resume` 命令，独立签名配置和构建目录。
- 显式 arm64 Release archive/export、内到外签名、固定证书核验、Hardened Runtime 和安全时间戳检查。
- App 与 DMG 分别公证、附加票据、校验 Gatekeeper；保存 submission ID、原文件哈希和结果。
- 失败保留现场，等待中断复用公证 ID；仅通过验证后生成交付目录、校验和与 manifest。
- DMG 包含拖拽入口、安装说明、许可证和对应 commit 源码；不读取/复制个人服务偏好、密钥。
- 新增分发与同事安装文档，并与原本机更新文档互相链接。

### 设计意图

分发与本机更新共享源码但不共享安装过程及签名配置；固定 Bundle ID 与分发签名身份，
支持持续发包。采用 Apple Developer ID / notarytool 流程，不调用官方仓库 Release 自动发布。
隐私权限仍由同事按所用功能授权，不绕过 Gatekeeper 或修改 TCC。

### 验证

- `python3 -m py_compile scripts/package-medict.py scripts/medict_distribution.py`：通过。
- `python3 scripts/package-medict.py build-check --version 2.24.0 --build 67`：成功，
  14 个 Mach-O 支持 arm64，主程序仅 arm64，macOS 13.0 起，版本及关闭更新配置正确。
- 临时副本的分层签名：用现有 Apple Development 身份验证，深度严格签名校验通过；
  15 个签名对象的团队与时间戳正确，主 App 与 Sparkle helper entitlement 保留。
  该验证只证明签名顺序可执行，不证明 Developer ID 或公证结果。
- DMG 制作与只读挂载验证通过；205 项 App 文件哈希一致，Applications 链接正确，
  许可证及安装说明存在，源码归档未包含本机签名配置。
- 缺失配置、无效版本、并发打包均安全停止；文档相对链接、`git diff --check` 通过。
- 按 review 技能审查脚本及调用边界：修复嵌套 ad hoc 签名和公证等待期间源码漂移问题，
  复核无未解决的有证据 finding。未新增测试。
- 操作前后两份已安装 App 均为 318 项且哈希一致：ME-Dict `ec297b96bc00f9730db7395a3584bfc51c9a0d8f25fa354dac44c8b5ac57a556`，
  官方 Easydict `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。

### 受影响文件

- `scripts/package-medict.py`
- `scripts/medict_distribution.py`
- `.gitignore`
- `docs/agents/build-and-test.md`
- `docs/user-docs/zh/ME-Dict-local-development.md`
- `docs/user-docs/zh/ME-Dict-distribution.md`
- `docs/user-docs/zh/ME-Dict-installation.md`
- 本任务 plan/history。

### 后续事项

- 本机尚无有效 Developer ID Application 证书，`ME-Dict-notary` Keychain profile 不存在。
  用户完成两项配置后，填写独立 JSON 配置并执行正式 release。
- 真实 Developer ID archive/export、Apple 公证、票据、Gatekeeper 与另一台 Mac 安装/更新验收尚未完成。
  当前没有可对外分发的正式 DMG；验证包明确标为 NOT-FOR-DISTRIBUTION，未上传或发布。
- 保留 active plan，后续在本任务中补齐真实签名、公证证据后归档。
