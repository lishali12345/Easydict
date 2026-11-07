## 2026-11-07 | 任务：修复 Chrome 多行输入框选区替换

**Links:** [执行计划](../../exec-plans/completed/2026-11/2026-11-07-medict-multiline-replacement.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.2 (27B52)`

### 用户请求

修复 Chrome WhatsApp Web 多行输入中的全选、单行局部及跨行局部翻译替换，保留未选中内容和换行，
补充回归测试、重新编译安装并验证，不影响官方 Easydict。

### 变更

- 新增 Chrome Text Marker 选区读取，用字段范围、选区范围及所属节点边界定位；将浏览器坐标映射到 AXValue。
- 新增可独立验证的文本快照，只允许浏览器表示中缺少的段落 LF，不清理空白、不归一化 Unicode，
  不搜索重复文字猜位置；缺少可靠边界信息时拒绝映射。
- 翻译请求使用映射后的原始选区子串，修复 Chrome 原生 AXSelectedText 省略段落换行的问题。
- 保留原应用、输入框、全文、数值选区校验，增加 Marker 身份和全文字节校验。
- Chrome 仍只对真实选区执行一次 Paste，并读取全文验证预期结果；不重写未选中内容。
- 自动全选的验证使用解析后的完整选区，不再假定浏览器选区长度等于 AXValue 长度。
- 新增 16 项文本快照回归测试及工程引用，覆盖三种选区、重复文字、空行、显式 LF、CRLF、
  Emoji、组合字符、歧义、越界、代理对切分和内容不匹配。

### 设计意图

真实诊断中，三行样例 AXValue 长度为 8，含两个 LF；AXSelectedText、选区长度和 Marker 全文长度为 6，
均不含这些段落 LF。旧实现把数值选区直接用于 AXValue 子串比较，导致校验失败并降级为只能复制。

使用 Marker 所属节点提供换行前后的实际边界，在原文坐标下生成预期结果，同时让 Chrome 自己向原选区粘贴。
这样可以保留网页未选中部分的 DOM 和空行，并避免通过放宽比较或重写全文产生错误覆盖。

接口区别参考 [Chromium BrowserAccessibilityCocoa 源码](https://chromium.googlesource.com/chromium/src/+/3692e9aaab4580817baea96d10b3ed4046f3aeac/ui/accessibility/platform/browser_accessibility_cocoa.mm)。
该来源不代表与本机 Chrome 157.0.8103.38 精确匹配，具体行为以本机诊断与实际验收为准。

### 验证

- 修改前使用失败日志结构回放旧比较条件，两例均被拒绝；第一行局部对照通过。
- 固定签名诊断版与用户实际快捷键确认上述 AX 坐标差异；诊断代码已从最终源码移除。
- 新模型原样在临时 Swift Package 中运行：16 tests 通过。
- `xcodebuild test`，`ME-Dict` Debug，限定 `ReplacementTextSnapshotTests`、`QueryModelTests`：
  19 tests / 2 suites 通过。包含原文保留及 Unicode 回归；未运行全库测试。
- `git diff --check`、工程 plist 校验通过。构建包含一条 `executeAction` 122 行超过 120 行的长度警告，
  没有编译或测试失败。
- 独立 review 完整审查六个代码/工程文件，未发现必须修复的 finding；最终测试及 Release 构建后摘要未漂移。
- `python3 scripts/update-medict.py --build-only`、`--install-only` 成功；团队 `LC4969GPTD`，
  满足原 designated requirement；安装包 318 项文件摘要为
  `a8ae9cb4d4cb084d7dadaf83b5508a1ed2e98841f68c7cfbd9262295438a7496`。
- 官方 Easydict 318 项文件摘要与任务前一致：
  `c410f3b2808ddec2d6ca6776383c05e5dc484f2484110dcf60b9f04b050b7a7e`。
- 全选实测：用户确认三行中文成功替换为英文且仍保持三行；17:22:56 捕获全文长度 8、数值选区 (0,6)，
  17:23:05 `preview=true` 替换后记录 `Replacement writeback verified`。
- 单行局部实测：17:25:34 捕获选区 (13,9)，17:25:39 确认写回；用户与 DOM 回读均确认仅目标句改变，
  `前缀：`、`：后缀`、`KEEP_HEAD`、`KEEP_TAIL` 和空行不变，渲染文本 LF 数量前后均为 10。
- 跨行局部实测：反向选中中间两句，17:36:04 捕获选区 (10,17)，17:36:09 确认写回。
  用户与 DOM 回读均确认只替换这两句，前后未选中部分逐字一致；上下标记、空行和两句分行保留，
  渲染文本 LF 数量前后均为 12。
- 三项实测结束后清空测试草稿，未发送消息；最终回读确认六文件审查摘要与两个已安装应用摘要均未漂移。
- 验证边界：未另行手测 Safari、原生 WhatsApp、TextEdit 或翻译等待期间修改选区；相关保护经代码审查。

### 受影响文件

- `Easydict/Swift/Feature/ActionManager/ActionManager.swift`
- `Easydict/Swift/Feature/ActionManager/ReplacementContext.swift`
- `Easydict/Swift/Feature/ActionManager/ChromeReplacementSelection.swift`
- `Easydict/Swift/Feature/ActionManager/ReplacementTextSnapshot.swift`
- `EasydictTests/Feature/ActionManager/ReplacementTextSnapshotTests.swift`
- `Easydict.xcodeproj/project.pbxproj`
- 本任务 plan/history。

### 后续事项

- 无；本次仅本地提交，不推送或分发。
