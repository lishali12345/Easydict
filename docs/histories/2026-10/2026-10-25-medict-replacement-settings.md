## 2026-10-25 | 任务：独立配置翻译并替换

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-25-medict-replacement-settings.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

在高级设置集中配置替换目标、翻译及润色服务、候选/即时模式；通用恢复完整语言，取消中文特例。
默认候选入口为 Command+Shift+T，即时目标快捷键默认 Command+Shift+数字。保留现有四个目标，支持排序。
完成后固定签名安装验证，不影响官方 Easydict。

### 变更

- 新增独立「翻译并替换」设置区，目标语言支持完整列表、勾选与上移/下移；保留原有目标顺序。
- 通用查询移除自定义语言筛选，查询菜单与第一/第二语言选择恢复完整选项。
- 翻译和润色分别按稳定服务实例 ID 保存选择，列出各窗口已启用服务的并集，不支持的能力置灰。
- 服务被停用或删除时明确提示，不回退其他服务；普通翻译与流式服务均等待完整结果再允许写回。
- 润色提示词为请求局部覆盖；目标语言使用隔离 QueryModel，不被通用查询语言异步覆盖。
- 候选适用于任意源语言：Command+数字替换，Option+数字复制，前九项绑定数字。
- 即时快捷键按语言身份保存，仅即时模式注册，支持录制、清空、冲突提示和删除目标后的注销。
- 旧默认候选入口一次迁移至 Command+Shift+T，保留自定义或已清空设置。
- 录制与候选窗口期间暂停全局快捷键，结束后恢复；保留已有选区、全文、焦点校验和 Chrome Paste 写回。

### 设计意图

替换场景的语言与服务独立于查词窗口。通过服务 ID 解析配置，保留用户已有模型和接口。
即时快捷键按语言绑定而非行号绑定，重排目标不会更改用户已设置的快捷键。
列表只读获取启用 ID 后创建请求实例，避免旧服务加载接口写回其他窗口的查询标记。

### 验证

- 17 个变更 Swift 文件严格 SwiftLint 0 违规，String Catalog JSON、`git diff --check` 通过。
- 最终 `python3 scripts/update-medict.py --build-only` 编译和固定签名成功，源码与审查快照一致。
- Review 发现并修复两个 P2：新目标默认键可能与保留语言键碰撞；读取服务列表可能回写其他窗口 enabledQuery。
- 现有 `OpenAIStreamTaskControlTests`：3/3 通过；覆盖服务任务取消生命周期，不覆盖新设置和快捷键 UI。
- 修复后增量 review 通过，源文件摘要与审查快照一致，无待修复 finding；安装和 TextEdit 实际交互验证完成。

- 固定签名安装至 `/Applications/ME-Dict.app`，团队 `LC4969GPTD`；318 项安装文件摘要为
  `a0353041f8187138c44a4d7cc688be1e2877c9e260b1707b5da63d9e30bfcad2`。
- 官方 Easydict 318 项文件摘要保持 `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- 安装后进程只读检查 `AXIsProcessTrusted() == YES`，检查后已解除调试附加。
- 持久化回读确认旧快捷键迁移完成，四个原目标默认即时键为 Command+Shift+1～4。
- 设置 UI 确认通用恢复完整语言列表，目标语言面板完整列表与上移/下移可用，保存后顺序正确。
- 用户在验收前已将目标改为英语、印尼语、马来语；保留该配置。即时模式展开三项录制控件，英语为 Command+Shift+5，原有印尼语和马来语仍为 Command+Shift+1/2，符合按语言保留绑定的设计。
- 当前仅启用 OpenAI Translate，服务菜单显示这一项；未在真实 UI 验证其他服务置灰状态。

- 用户实际按键确认 Command+Shift+T 对中文打开三语候选、Option+1 复制英语、Command+1 替换英语、Command+Shift+1 即时替换印尼语全部成功。
- TextEdit 最终回读为 “Halo, kami telah menerima umpan balik Anda dan akan segera menanganinya untuk Anda.”。运行日志确认中文到三语候选、英语到印尼语请求均使用 OpenAI Translate [OpenAI] 的 group/translate。
- 测试后已通过设置界面恢复候选模式，并回读持久化值 candidate；用户当前目标与服务配置保留。

### 受影响文件

- Configuration、ActionManager、Shortcut 模块与 QueryModel。
- OpenAI/StreamService 提示词处理、设置界面和原有语言菜单。
- Xcode 工程、String Catalog 和同任务 plan/history。

### 后续事项

- 其他服务组合和本轮 Chrome 端到端未实测；自动化无法可靠触发全局快捷键，本轮采用用户实际按键与文本、日志回读联合验收。
