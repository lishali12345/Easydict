## 2026-10-27 | 任务：建立 ME-Dict 独立签名公证与 DMG 分发流程

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-27-medict-distribution.md)

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

### 首次正式包交付

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

- 正式 DMG、SHA256SUMS.txt 与 manifest.json 位于本次 run 的 `artifacts/`；未发布远程下载链接。
- 后续在干净、已提交的 checkout 运行 `python3 scripts/package-medict.py release --version 2.24.0 --build 69`，
  按实际版本递增构建号；本机忽略的分发配置及 Keychain 凭据可复用。
- 由同事在另一台 Apple Silicon Mac 验证首次安装、服务配置、权限、实际替换与后续覆盖更新。
  公证无法代替隐私授权，不保证所有第三方输入框支持直接替换。
