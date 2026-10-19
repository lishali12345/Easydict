# 区分 Debug 菜单栏图标

- 状态：completed
- 创建日期：2026-10-19
- 负责人：Codex
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

Debug 已有独立名称和应用图标，菜单栏图标仍难以与正式版区分。

## 目标与范围

- 目标结果：Debug 菜单栏显示所选图标及明显的 DEBUG 标识，Release 保持原样。
- 允许修改路径：EasydictApp.swift 和本任务文档。
- 同任务 history：`docs/histories/2026-10/2026-10-19-debug-menu-bar.md`
- 用户限制：不得影响正式版。
- 非目标：改变图标偏好、菜单行为、快捷键或应用图标资源。
- 验收标准：Debug / Release 构建通过，Debug 实际菜单栏可辨识；原有圆形/方形选择继续生效。

## 工作计划

1. Debug 图标右侧加入加粗 DEBUG 标识，使用模板图适应深浅色菜单栏。
2. 构建并检查 Debug 运行时菜单栏图像与布局，核对菜单动作、Release 分支与正式版文件。
3. 执行 review，记录结果、归档计划并创建本地提交。

## 风险与决策

- 标识增加少量菜单栏宽度，按实际文字宽度绘制，避免挤压原图标。
- 使用 NSImage 绘制回调支持屏幕缩放，文字为固定构建标识 DEBUG。
- 使用编译条件隔离 Debug 绘制；Release 继续使用原图及模板渲染。

## 进度

- [x] 实现和构建。
- [x] 实机验证和审查。
- [x] 文档和提交。

## 验证

- 最终源码 Debug / Release 构建和签名校验通过，SwiftLint 均为 0 violations。
- 运行时 NSStatusBarButton 为 66 × 22 点，图像为 50 × 18 点且 isTemplate 为 true；导出图像中的 DEBUG 完整可见。
- CUA 菜单栏读取超时，改为 LLDB 只读检查；调试器已解除附加，最终 Debug 已重新启动。
- Review 发现悬停提示的本地化语义差异，恢复原调用后复验通过；菜单动作及原图标偏好保留。
- 正式安装包哈希与修改前一致；Release 校验产物未启动并已取消 LaunchServices 注册。
- `git diff --check` 和最终源码快照复验通过，详见同任务 history。

## 完成条件

- Debug 菜单栏区分生效，Release 未改变，适用验证和审查通过。
