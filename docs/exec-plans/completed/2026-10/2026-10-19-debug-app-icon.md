# 为 Debug 应用添加专用图标

- 状态：completed
- 创建日期：2026-10-19
- 负责人：Codex
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

Debug 已有独立名称，但应用图标仍与正式版相同，难以一眼区分。

## 目标与范围

- 目标结果：Debug 图标增加醒目的 DEBUG 标识，Release 继续使用原图标。
- 允许修改路径：新增 Debug Icon Composer 资源、Xcode 工程和本任务文档。
- 同任务 history：`docs/histories/2026-10/2026-10-19-debug-app-icon.md`
- 用户限制：不得影响正式版。
- 非目标：改变菜单栏图标、品牌原图、Bundle ID 或功能逻辑。
- 验收标准：Debug 图标标识清晰，构建及签名检查通过；Release 配置和图标不变。

## 工作计划

1. 复制原生分层图标，新增橙色 DEBUG 矢量标识。
2. 将新图标资源加入工程，仅更换 Debug 的 app icon 配置。
3. 构建 Debug / Release，检查图标产物并重启 Debug；比对正式版资源。
4. 更新 history、归档计划并创建本地提交。

## 风险与决策

- 沿用 Icon Composer 保留原有浅色、深色与着色支持；文字转换为路径，避免构建时字体依赖。
- 不修改原图标；本机正式版仅作只读哈希比对。
- 新图标需要工程 file reference、group 和 Resources 引用。

## 进度

- [x] 资源制作和工程绑定。
- [x] 构建、产物视觉检查和正式版边界验证。
- [x] 文档与提交。

## 验证

- Debug / Release 构建、SwiftLint（0 violations）、签名检查均通过。
- 修复初次 Icon Composer 四分组上限错误，最终在现有前景分组添加标识。
- 编译图标和 macOS 运行中应用图标均已视觉检查，DEBUG 明显可见。
- Release 配置未变，重新生成的图标哈希与原产物一致；正式安装包及原始图标资源未变。
- JSON、SVG、工程 plist、差异及资源引用检查通过；详细结果见同任务 history。

## 完成条件

- Debug 图标通过视觉检查、构建和签名验证；Release 未受影响，记录归档。
