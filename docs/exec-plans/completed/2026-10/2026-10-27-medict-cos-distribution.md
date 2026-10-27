# ME-Dict COS 下载分发

- 状态：completed
- 创建日期：2026-10-27
- 负责人：/root
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

同事通过飞书接收并安装 DMG 后无法启动。接收端 codesign 验证通过，但 spctl 提示
`File created by an AppSandbox, exec/open not allowed`，App 与主程序的 quarantine
均为 `0187;…;Feishu;`。用户要求将已公证 DMG 上传 MeeTar COS，提供自己的下载链接。

## 目标与范围

- 目标结果：原始 DMG 的公开 HTTPS 下载地址，匿名完整下载与原包哈希一致。
- 允许修改路径：本任务 plan/history；临时上传回执放在 ignored 输出目录。
- 同任务 history：`docs/histories/2026-10/2026-10-27-medict-cos-distribution.md`
- 用户限制：保持已签名公证的文件不变，不影响本机 ME-Dict 和官方 Easydict。
- 非目标：修改程序、覆盖其他 COS 文件、更改安全策略、自动更新或网站页面。
- 验收标准：COS 上传成功，公开下载返回完整 DMG，与既有 manifest 的大小和 SHA-256 一致。

## 工作计划

1. 核对上传工具、目标 bucket/key、文件摘要和对象是否已存在。
2. 上传至版本及内容摘要隔离的 COS 路径。
3. 完整匿名回读，核对大小、SHA-256 和响应类型。
4. 记录链接与验证边界，归档计划并提交文档。

## 风险与决策

- 通用 simple 接口不接受 dmg，使用现有 meetar-res-admin COS 直传脚本。
- COS 凭据只由本机配置读取；不输出、上传或提交凭据。
- 新建版本路径，上传前只读检查对象；不覆盖内容不同的对象。
- 公开链接验证不等于同事已完成 Safari 下载后的首次启动验收。

## 进度

- [x] 核对工具与上传范围。
- [x] dry-run 与对象检查。
- [x] 上传和公开完整下载验证。
- [x] 交付记录与本地提交。

## 验证

- dry-run 确认 `file` bucket：`juno-file-1321483621`，region `ap-singapore`。
- 对象 key：`medict/releases/2.24.0-68/0aaebe5f0ca32d0e55e88202dd261fc14ce8e6f763b55ed7c7242a51c1ca0378/ME-Dict-2.24.0-68-arm64.dmg`；上传前 HEAD 返回 404 NoSuchResource，上传后脚本状态 success。
- [公开 DMG 下载](https://file.meetarapp.com/medict/releases/2.24.0-68/0aaebe5f0ca32d0e55e88202dd261fc14ce8e6f763b55ed7c7242a51c1ca0378/ME-Dict-2.24.0-68-arm64.dmg)，无临时签名参数。
- 匿名完整 GET 返回 HTTP 200，Content-Type `application/x-apple-diskimage`，字节数 `63279325`。
- SHA-256 `0aaebe5f0ca32d0e55e88202dd261fc14ce8e6f763b55ed7c7242a51c1ca0378` 与原始已公证包 manifest 一致；没有重新打包或修改签名。
- 上传与下载回执保存在 ignored 的 `.tmp/medict-distribution/cos-*.json`。
- 文档差异与相对链接检查通过；同事经 Safari 下载、重新安装后的启动结果仍待验收。

## 完成条件

- 链接可下载且内容与已公证原包一致。
- 记录同事首次启动仍待验收，计划归档。
