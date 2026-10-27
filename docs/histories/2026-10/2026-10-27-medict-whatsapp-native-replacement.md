## 2026-10-27 | 任务：适配 WhatsApp 原生应用候选替换

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-27-medict-whatsapp-native-replacement.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

暂停分发证书配置，修复 WhatsApp 原生 App 中候选窗口 Command+1 无法替换输入框的问题。

### 变更

- 原应用激活后再验证选区，并等待前台和焦点元素同时恢复，避免 WhatsApp 在候选窗口打开时
  报告不同焦点元素造成误判。
- 对 WhatsApp 文本区域使用应用自身的 Paste 动作，沿用既有剪贴板备份/恢复与写回校验。
- WhatsApp 粘贴菜单缺少 AXIdentifier 时，以角色、Command+V 和已有本地化标题匹配。
- 添加 WhatsApp Bundle ID 常量及不含正文的请求/写回日志，已删除临时诊断。

### 设计意图

将校验放在原应用焦点恢复之后，仍要求原应用、焦点元素、全文和 UTF-16 选区与捕获时一致。
通过应用自身的编辑动作写入，只执行一次 Paste；回读成功后且剪贴板未被其他操作改变时才恢复剪贴板。
菜单兼容查找仅限 WhatsApp，不改变快捷键或翻译服务配置。

### 验证

- 第一版菜单适配未解决问题；用户保留的错误提示与日志进一步确认问题发生在焦点校验。
- 两次诊断均显示激活前焦点元素不一致，原文和选区未变；激活后全部校验恢复一致。
- 用户确认 Command+1 成功替换为英文；14:12:22 和 14:12:47 日志均确认 WhatsApp Paste 写回成功。
- 原草稿恢复并通过输入框 AX 回读确认；Agent 未执行发送操作。
- 无现有自动化 suite 直接覆盖 WhatsApp 的系统焦点/菜单行为；未新增测试。
- 清理诊断后 `update-medict.py --build-only` 与 `--install-only` 均成功；团队 `LC4969GPTD`，
  新包满足原 designated requirement。构建与安装 318 项文件摘要一致：
  `84f301bbfe892309432bd074b3d6dcfee78bce1d585d9936f35e246004428d85`。
- 官方 Easydict 318 项文件摘要保持
  `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- `git diff --check` 通过。review 对照基线 `455134a9` 检查替换入口、焦点恢复、原文/选区保护、
  仅 WhatsApp 菜单回退、单次 Paste、取消及剪贴板恢复，未发现有证据的未解决 finding。
  当前局部方案足以满足需求，无需全局快捷键或通用 AX 框架重构。
- 最终包与实机验收包的代码差异仅为删除临时诊断及修正注释，最终源码摘要复核一致。
  未重复请求用户操作，也未将本次验证扩大为其他应用的全量回归。

### 受影响文件

- `Easydict/Swift/Feature/ActionManager/ReplacementContext.swift`
- `Easydict/Swift/Utility/Constants/AppBundleIDs.swift`
- 本任务 plan/history。

### 后续事项

- 分发证书与公证按用户要求保持暂停。
