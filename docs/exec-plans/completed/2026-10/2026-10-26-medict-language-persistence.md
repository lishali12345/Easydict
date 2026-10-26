# 保留 ME-Dict 的 macOS 首选语言

- 状态：completed
- 创建日期：2026-10-26
- 负责人：Codex
- 关联 Issue/PR：None

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

用户在 macOS Language & Region 中选择简体中文，重启或更新 ME-Dict 后又恢复英语。
发现 EZLanguageManager.setup 每次启动删除 AppleLanguages；当前应用偏好中该键已不存在。

## 目标与范围

- 目标结果：保留 macOS 的应用语言选择，默认界面语言采用应用支持的首选本地化。
- 允许修改路径：EZLanguageManager.m、I18nHelper.swift 及同任务文档。
- 同任务 history：`docs/histories/2026-10/2026-10-26-medict-language-persistence.md`
- 用户限制：仅更新 ME-Dict，不影响官方 Easydict。
- 非目标：重构应用内语言选择、分发、推送、新增测试。
- 验收标准：固定签名编译安装；简体中文在冷启动及覆盖安装后保留；官方应用不变。

## 工作计划

1. 核对语言配置的读写路径，移除启动时清理系统偏好的代码。
2. 编译并运行相关现有测试，review 修改范围。
3. 设置简体中文，核对重启及覆盖安装后的偏好与可见界面。
4. 记录边界、归档并本地提交。

## 风险与决策

- 基线 HEAD 为 37d61d2505dd8c12ebc289d97c8e9034cdc2fc48；初始索引、工作树干净。
- 保留原有应用内显式语言选择的优先级；当前用户没有此覆盖值。
- 使用 Bundle.main.preferredLocalizations 解析受支持的本地化，而非地区格式 Locale.current。
- Apple API 依据：[preferredLocalizations](https://developer.apple.com/documentation/foundation/bundle/preferredlocalizations)。

## 进度

- [x] 定位与最小修复。
- [x] 编译、现有测试与 review。
- [x] 安装、重启验收与归档；本地提交为最终交付步骤。

## 验证

- Release 构建和固定签名安装通过；现有中英文检测测试实际执行 2/2 通过。
- review 无有效 finding；git diff --check 通过；SwiftLint 本机不可用。
- 用户确认设置显示中文；冷启动和覆盖安装后新进程均回读 AppleLanguages=zh-Hans-CN、Bundle 与 I18nHelper=zh-Hans。
- 官方 Easydict 摘要不变；未重启整台 Mac，未新增测试。

## 完成条件

- 必要验证通过，真实界面与持久化偏好一致；如实记录未验证边界。
