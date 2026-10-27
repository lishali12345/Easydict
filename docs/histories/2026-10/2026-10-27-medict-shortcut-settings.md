## 2026-10-27 | 任务：统一候选与即时替换设置入口

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-27-medict-shortcut-settings.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

候选入口始终可用，以开关控制目标语言的即时替换快捷键。在高级设置复制翻译及润色快捷键入口，保留原快捷键页。
恢复 Beta 为高级页首项，替换 Section 排第二。

### 变更

- 用「启用目标语言即时替换快捷键」开关替代模式选择；候选窗口说明始终展示，开启后展开各语言录制项。
- 兼容现有 replacementMode 存储与语言快捷键，不重置用户配置。
- 高级页复用 KeyHolderRowView 和相同 ShortcutAction，使用同一配置及冲突提示。
- KeyHolderWrapper 观察相应 Defaults key，使跨入口修改或清空同步显示，录制期间不覆盖输入。
- Beta Section 移至第一、替换 Section 第二；更新六语言文案并删除不再使用的模式标签。

### 设计意图

候选及即时行为原已独立，仅调整设置表达。共享现有录制流程和持久化键，避免维护两套快捷键。
KeyHolder 的 keyCombo setter 只刷新显示，不调用录制 delegate，因此配置观察不会产生写回循环或重复注册。

### 验证

- 独立 review 无有效 finding；核对观察生命周期、全局注册路径、兼容存储和六种 locale 文案。
- String Catalog JSON 与 git diff --check 通过。
- Release 构建与固定签名安装通过；项目无针对本次快捷键设置的现有测试，未新增测试。
- 安装后目标语言、即时开关、翻译及润色快捷键和中文语言偏好与安装前一致。
- 安装包摘要 ec297b96bc00f9730db7395a3584bfc51c9a0d8f25fa354dac44c8b5ac57a556；官方应用摘要仍为 c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e。

- 中文 UI 确认 Beta 第一、替换 Section 第二；开关关闭时收起语言快捷键，候选说明及翻译/润色快捷键始终可用，开启后重新展开。
- 实测高级页清空翻译键后原页为空、原页录制后高级页同步；高级页修改润色键后原页同步、原页清空后高级页为空。
- 测试后通过 UI 恢复翻译 ⌘⇧T、润色 ⌃⌥P；规范化持久化回读确认相关偏好与测试前完全一致，包括即时开关开启和简体中文。

### 受影响文件

- AdvancedTab.swift、ReplacementSettingsSection.swift、KeyHolderWrapper.swift。
- Localizable.xcstrings 和同任务 plan/history。

### 后续事项

- 未重跑翻译服务与外部输入框端到端；本次未修改请求路由或替换实现。
