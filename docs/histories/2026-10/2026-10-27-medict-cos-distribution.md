## 2026-10-27 | 任务：上传 ME-Dict 到 MeeTar COS 提供下载

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-27-medict-cos-distribution.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

飞书附件接收后的应用被 AppSandbox 下载隔离标记阻止启动，改用 MeeTar COS 提供自己的下载链接。

### 变更

- 使用现有 meetar-res-admin COS 直传脚本上传原始 `ME-Dict-2.24.0-68-arm64.dmg`。
- 目标为 file bucket，路径包含版本和完整 SHA-256，保留安装文件原名。
- 没有修改应用代码、签名、系统安全策略或本机已安装 App。

### 设计意图

用户提供的接收端证据显示 codesign 验证通过，但 spctl 报告 AppSandbox 禁止执行；
App 和可执行文件均带有 `0187;…;Feishu;` 隔离标记。
提供独立 HTTPS 链接供同事在 Safari 下载，保留系统正常下载检查。
通用 simple 上传接口不支持 dmg，复用现有 COS 直传实现；凭据不进入回执或 Git。

### 验证

- dry-run 确认 `file` bucket：`juno-file-1321483621`，region `ap-singapore`。
- 对象 key：`medict/releases/2.24.0-68/0aaebe5f0ca32d0e55e88202dd261fc14ce8e6f763b55ed7c7242a51c1ca0378/ME-Dict-2.24.0-68-arm64.dmg`；上传前 HEAD 返回 404 NoSuchResource，上传后脚本状态 success。
- [公开 DMG 下载](https://file.meetarapp.com/medict/releases/2.24.0-68/0aaebe5f0ca32d0e55e88202dd261fc14ce8e6f763b55ed7c7242a51c1ca0378/ME-Dict-2.24.0-68-arm64.dmg)，无临时签名参数。
- 匿名完整 GET 返回 HTTP 200，Content-Type `application/x-apple-diskimage`，字节数 `63279325`。
- SHA-256 `0aaebe5f0ca32d0e55e88202dd261fc14ce8e6f763b55ed7c7242a51c1ca0378` 与原始已公证包 manifest 一致；没有重新打包或修改签名。
- 上传与下载回执保存在 ignored 的 `.tmp/medict-distribution/cos-*.json`。
- 文档差异与相对链接检查通过；同事经 Safari 下载、重新安装后的启动结果仍待验收。

### 受影响文件

- 本任务 plan/history；COS 中新增一个 DMG 对象。

### 后续事项

- 同事应复制链接到 Safari 下载，用新下载的 DMG 重新安装，避免继续使用飞书内置下载器。
- 匿名下载和哈希校验通过，不等于同事设备首次启动已验收；仍需回报实际结果。
