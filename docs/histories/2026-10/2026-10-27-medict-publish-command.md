## 2026-10-27 | 任务：整合 ME-Dict 一条命令发布

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-27-medict-publish-command.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

整合打包、Developer ID 签名、公证与 MeeTar COS 上传，成功后直接输出下载链接，
方便后续迭代，不影响本机 ME-Dict 与官方 Easydict。

### 变更

- 新增 `publish`、`check-publish` 与已有正式产物的 `upload` 入口。
- 复用原构建、公证状态机；`resume` 保存并恢复发布意图。
- COS 适配器复用本机 MeeTar 上传工具；忽略配置只记录工具、解释器和凭据文件路径。
- 上传前重验原包，按版本与 SHA-256 隔离对象；同内容复用，内容不同拒绝覆盖。
- 完整匿名下载核对类型、大小与 SHA 后输出 `DOWNLOAD_URL`，写入 publication/manifest。
- 更新分发说明及构建入口文档；原 `release` 保留本地打包行为。

### 设计意图

在现有单机流程上增加最小发布编排，不引入 CI、自动更新或版本自动推断。
凭据由本机原工具读取，分发产物不安装、不启动；网络失败可续跑并复用已有对象。

### 验证

- `python3 -m py_compile scripts/package-medict.py scripts/medict_cos.py`：通过。
- `check-publish`：实际签名身份、公证历史与 COS bucket 只读验证通过。
- 非法版本、构建号参数：CLI 返回退出码 2。
- `upload 20261027T062540Z-d5ac5900`：通过，复用已发布 2.24.0 (68) 对象。
- `resume 20261027T062540Z-d5ac5900`：通过，恢复发布意图并再次输出已验证链接。
- 两次完整匿名下载均为 HTTP 200，63,279,325 字节，SHA-256 为
  `0aaebe5f0ca32d0e55e88202dd261fc14ce8e6f763b55ed7c7242a51c1ca0378`。
- 修复 venv interpreter symlink 被 resolve 后丢失依赖的问题，预检重跑通过。
- 独立只读 review：无可确认 P0–P3 finding，最终源码与审查快照一致。
- 本机两个已安装应用各 318 项文件摘要均与任务前一致；未安装或启动分发版。
- `git diff --check` 与文档相对链接检查通过。

### 受影响文件

- `.gitignore`
- `scripts/package-medict.py`
- `scripts/medict_cos.py`
- `docs/agents/build-and-test.md`
- `docs/user-docs/zh/ME-Dict-distribution.md`
- 本任务 plan/history。

### 后续事项

- 本轮复用既有 68 号包验证新增流程，未发布 69 号包，也未重复构建、公证或首次 PUT。
- 后续新版本在代码提交、工作树干净后运行 `publish`，按实际迭代递增 build。
- 同事通过 Safari 重新下载后的启动结果尚待实际确认。
