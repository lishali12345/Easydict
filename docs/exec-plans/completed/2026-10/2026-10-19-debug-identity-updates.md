# 区分 Debug 应用名称并关闭自动更新

- 状态：completed
- 创建日期：2026-10-19
- 负责人：Codex
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

Debug 与正式版显示同名，且 Debug 默认启用 Sparkle 自动更新，不便于并行开发。

## 目标与范围

- 目标结果：Debug 显示 Easydict-debug，关闭自动检查和自动下载；Release 保持原行为。
- 允许修改路径：Debug plist、InfoPlist String Catalog、GlobalContext、GeneralTab 及本任务文档。
- 同任务 history：`docs/histories/2026-10/2026-10-19-debug-identity-updates.md`
- 用户限制：不得影响正式版。
- 非目标：修改 Bundle ID、数据目录或手动检查更新能力。
- 验收标准：Debug 构建、实际 bundle 名称与偏好回读通过；Release 名称/更新配置和已安装正式版不变。

## 工作计划

1. 调整 Debug plist，并移除覆盖构建名称的品牌本地化项。
2. Debug 更新器启动前关闭自动检查/下载，禁用对应设置开关。
3. 构建并检查产物，重启 Debug 验证；核对 Release 边界。
4. 审查差异、更新 history、归档计划并本地提交。

## 风险与决策

- plist 默认值无法覆盖旧偏好，需在 Debug 启动时通过 Sparkle API 设置。
- 应用名称是固定品牌，各语言采用 plist 构建值；其余本地化保留。
- 保留手动更新能力；不修改正式版配置和数据。

## 进度

- [x] 实现与构建验证。
- [x] 审查、运行回读和交付。

## 验证

- Debug 和 Release（arm64 / x86_64，本地 ad hoc 签名）构建通过；格式化、lint、签名校验通过。
- 产物名称分别为 Easydict-debug 和 Easydict，各语言名称回退正确。
- Debug 重启后系统解析名称正确；自动检查/下载偏好均为 0。
- 正式安装包可执行文件、Info.plist 哈希及更新偏好未变；Release 校验产物未运行且已取消 LaunchServices 注册。
- Review 未发现有效 finding；静态检查及审查快照复验通过。详细验证边界见同任务 history。

## 完成条件

- Debug 名称、自动更新关闭及 Release 边界验证通过，完成审查和 history。
