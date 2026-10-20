## 2026-10-20 | 任务：固定 ME-Dict 签名以保留更新后的辅助功能权限

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-20-medict-stable-signing.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

解决每次更新 ME-Dict 都需要重新开启辅助功能权限的问题。用户已有 Apple 开发者账号，
并明确选择个人团队的现有 Apple Development 证书，保留与官方 Easydict 的隔离。

### 变更

- 移除 Release 强制 ad hoc 和上游团队覆盖，通过 Git 忽略的本地 xcconfig 固定签名身份。
- 增加本地构建更新脚本，验证固定证书、Team、Bundle ID、全部架构签名和旧身份兼容性。
- 更新脚本只允许显式从 ad hoc 迁移；普通更新拒绝身份变化，安装暂存包并保留失败回滚。
- 增加本地开发说明和 Agent 构建入口，避免后续重新用 ad hoc 覆盖日用安装。

### 设计意图

macOS 使用 designated requirement 判断更新前后是否为同一应用。旧 ad hoc requirement
绑定构建哈希，新证书签名规则绑定证书身份和 Bundle ID，使正常更新可以复用已有授权。
使用用户现有证书及系统签名机制，不修改 TCC 数据库或构造宽松的身份规则。

### 验证

- 原安装包确认 `Signature=adhoc`，requirement 依赖两架构的构建哈希。
- 实际 Release build settings 已继承选定证书及团队；Release 构建成功。
- 新包全部架构的 deep/strict 签名校验通过，requirement 不再使用构建哈希。
- 项目文件语法、Python AST、脚本帮助、`git diff --check` 通过。
- 代码审查通过，无剩余 finding；修复了 `codesign` 可选参数与 requirement literal 的传参格式。
- 首次迁移安装成功；用户完成一次人工授权后，构建 67 的运行进程内
  `AXIsProcessTrusted()` 为 true。
- 仅通过命令行临时将构建编号设为 68，生成两架构 CDHash 均改变、designated requirement
  相同的新包。正常更新并重启后，`AXIsProcessTrusted()` 仍为 true，未再次人工授权。
- 使用 `python3 scripts/update-medict.py` 完整构建并安装正常的构建 67，再次重启后权限仍为
  true。临时构建编号没有写入仓库，当前安装与正常构建产物一致。
- 三次安装均通过签名与文件核验；官方 Easydict 的 300 个文件与本任务初始哈希一致。
- 未新增测试；未模拟文件系统故障。已验证真实构建、首次迁移、普通更新和运行时权限状态。

### 受影响文件

- `.gitignore`
- `Easydict.xcconfig`
- `Easydict.xcodeproj/project.pbxproj`
- `scripts/update-medict.py`
- `docs/agents/build-and-test.md`
- `docs/user-docs/zh/ME-Dict-local-development.md`
- `docs/exec-plans/completed/2026-10/2026-10-20-medict-stable-signing.md`
- `docs/histories/2026-10/2026-10-20-medict-stable-signing.md`

### 后续事项

- 后续日用更新使用固定更新入口。更换签名团队、Bundle ID、签名类型或系统重置权限时，
  仍可能需要重新授权；不将本次验证解释为永久免授权。
