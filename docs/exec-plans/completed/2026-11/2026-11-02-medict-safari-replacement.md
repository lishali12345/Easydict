# 适配 Safari WhatsApp 翻译替换

- 状态：completed
- 创建日期：2026-11-02
- 负责人：/root
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.2 (27B52)`

## 背景

Safari WhatsApp Web 翻译结果已生成，但替换报无法确认成功且中文草稿保留。
真实按键复现和日志均确认 Safari 使用直接 AX 写入，尚未使用既有 Paste 路径。

## 目标与范围

- 目标结果：Safari 文本区域通过原应用 Paste 完成翻译替换并验证写回。
- 允许修改路径：ReplacementContext.swift 及本任务 plan/history。
- 同任务 history：`docs/histories/2026-11/2026-11-02-medict-safari-replacement.md`
- 用户限制：保留官方 Easydict，不发送聊天消息。
- 非目标：翻译服务、快捷键、浏览器 JavaScript 权限、COS 发布、新增测试。
- 验收标准：Release 构建通过；真实 Safari 写回成功，官方 App 摘要未变化。

## 工作计划

1. 用真实按键、日志与输入框读回建立失败信号。
2. Safari 文本区域复用 Paste 路径，保留全部输入校验与剪贴板保护。
3. 固定签名编译安装，用户实际按键验收并核对日志。
4. Review、记录、归档与本地提交。

## 风险与决策

- 基线 ff4d30e38bd5be0b788747a111d59608df3a070a，初始工作树与索引干净。
- Safari 菜单提供可用标准 Paste 标识，不需要新增菜单查找或 JavaScript 注入。
- 输入已变化时继续拒绝写入；发出 Paste 后只执行读回，不重试粘贴。
- 自动化全局快捷键未触发 ME-Dict，使用用户真实按键与日志/AX 读回核验。
- 不新增测试；现有 suite 不覆盖外部 Safari AX 写回行为。

## 进度

- [x] 原版失败复现：19:10:10 捕获，19:10:12 替换，pasteMenu=false，中文保留。
- [x] 最小修复、Release 构建及固定签名安装。
- [x] 用户真实快捷键验收与写回日志核对。
- [x] Review、记录与归档完成，纳入本次本地提交。

## 验证

- `update-medict.py --build-only` 与 `--install-only` 通过；首个受限环境无法读取签名身份，
  使用授权的完整本机环境后成功，未修改签名配置。
- 新包满足原 designated requirement；构建与安装各 318 项文件摘要一致：
  `588fadd1b47a58eb18c0e7628e7f05554158ec89ad67c87c35f06f2cf206474e`。
- 官方应用摘要与任务前一致：`c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- `git diff --check` 通过；review 核对共同调用链、限定 textArea、单次 Paste 与读回/剪贴板保护，
  无已确认 finding。验收后再次核对审查源码摘要，未变化。
- 用户确认原快捷键直接替换英文且无报错；19:21:42 日志记录 Safari `pasteMenu=true`，
  `Replacement writeback verified`，通过原应用全文读回校验。

## 完成条件

- Safari 真实写回成功且无不相关改动，审查与构建通过，更新 history 后归档。
