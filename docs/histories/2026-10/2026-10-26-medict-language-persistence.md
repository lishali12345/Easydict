## 2026-10-26 | 任务：保留 ME-Dict 的 macOS 首选语言

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-26-medict-language-persistence.md)、[Apple preferredLocalizations](https://developer.apple.com/documentation/foundation/bundle/preferredlocalizations)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

修复 macOS 为 ME-Dict 设置简体中文后，重启或重新安装又恢复英语的问题。

### 变更

- 删除 EZLanguageManager.setup 对 AppleLanguages 的无条件清理，保留系统的每应用语言设置。
- I18nHelper 默认语言读取 Bundle.main.preferredLocalizations，保留应用内显式语言覆盖的现有优先级。
- 恢复本机 ME-Dict 的 AppleLanguages 为 zh-Hans-CN，并固定签名安装修复版。

### 设计意图

根因是启动阶段删除 macOS 保存的应用语言键，更新后启动同样触发删除。移除这项副作用即可保留偏好。
应用资源语言通过 Bundle 解析，避免将地区格式 Locale 当作界面语言；不修改安装脚本或官方应用。

### 验证

- Release 构建与固定签名安装成功，团队 LC4969GPTD；再次覆盖安装验证通过。
- 两次不同进程的只读回读均为 AppleLanguages=[zh-Hans-CN]、Bundle.preferredLocalizations=[zh-Hans]、I18nHelper.localizeCode=zh-Hans，调试器均已解除附加。
- 用户确认设置窗口显示中文；自动化无法可靠读取无可见窗口的菜单栏应用，因此界面验收采用用户确认，覆盖安装后补充进程内回读。
- 安装包 318 项文件摘要 e35c8a77ea53b822eece55cfd71051a883e03c07abc4113cf785affccdb60a81。
- 官方 Easydict 318 项文件摘要仍为 c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e。
- Review：检查启动读写路径、语言覆盖优先级、受支持本地化回退及更新脚本边界，无有效 finding；最小修复已足够，生产文件摘要复核一致。
- git diff --check 通过；本机没有 SwiftLint 可执行文件，未声称 lint 通过。
- 现有中英文检测测试：首次筛选命中 0 项，不作为测试通过；纠正为 Swift Testing 带括号的方法标识后，中英文检测用例实际执行 2/2 通过。

### 受影响文件

- Easydict/objc/Service/Language/EZLanguageManager.m
- Easydict/Swift/Feature/Localization/I18nHelper.swift
- 同任务执行计划与 history。

### 后续事项

- 未重启整台 Mac；已验证应用冷启动和覆盖安装后的新进程。未新增测试。
