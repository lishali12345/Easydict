## 2026-11-02 | 任务：保留翻译原文并修复特殊昵称检测崩溃

**Links:** [执行计划](../../exec-plans/completed/2026-11/2026-11-02-medict-original-text-detection.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.2 (27B52)`

### 用户请求

修复含 Emoji 与特殊字母的昵称触发 Command+D 后崩溃的问题；原文完整传给参与查询的服务，
不隐式清理或截断，无法确定语言时允许继续翻译。用户明确授权更新相关现有测试并补充回归测试。

### 变更

- AppleLanguageDetector 每次只对原文调用一次识别，移除混合文字的过滤重检递归；
  使用本地文字种类统计保留中日韩英混排判断，没有可识别语言时返回 auto。
- 选词捕获、浮窗及 QueryModel 保留原始内容；按 UTF-8 判断更新，避免 NFC/NFD 等值比较保留旧字节。
- 移除自动清理换行、注释、分词及 Books 摘录说明的入口，保留用户主动文本编辑功能。
- Google/Baidu 检测发送完整文本；Ali/Baidu/Bing/Google/NiuTrans 超出已有本地长度界限时明确报错，
  不再发送截断内容；Caiyun 以单个完整文本发送，保留换行上下文。
- 检测优化失败保留本地结果，翻译并替换允许 auto；默认翻译与润色提示词支持未知源语言。
  自定义提示词最后插入原文，防止原文中的模板标记被二次展开。
- 增加原昵称防崩溃、Unicode/空白/换行原文及模板字面值测试；更新无语言文本的旧英语兜底断言。

### 设计意图

语言检测只决定元数据，不改写待翻译文本。通过消除递归解决崩溃，而不是删除触发字符；
已有服务的本地长度界限仍生效，但用户可见的失败替代静默损失内容。
取消、过期结果及输入框写回校验继续保留，不改变启用服务列表、TTS 或 OCR 算法。

### 验证

- 锁定 Package.resolved 依赖后执行 Debug build-for-testing 与 test-without-building：
  AppleLanguageDetectorTests、QueryModelTests、StreamServicePromptTests 共 37 项通过。
- 首轮测试发现 7 个混排断言回归，改用原文文字种类判断后全部通过，未放宽原有混排断言。
- `python3 scripts/update-medict.py --build-only`：固定 Apple Development 身份 Release 构建及签名验证通过。
- `python3 scripts/update-medict.py --install-only`：本机安装通过，designated requirement 保持一致；
  官方 Easydict 的 318 个文件校验摘要未变化。
- `git diff --check`、xcstrings JSON 解析及工程引用检查通过；独立 review 对 24 个源码和测试文件
  完成快照复验，未发现确定缺陷。
- 新安装应用通过 URL 查询原昵称，检测返回 auto 并继续查询配置服务，未新增崩溃报告。
- 用户确认 Command+D 原昵称正常显示结果、没有崩溃；22:28:06 的 shortcut_query 日志回读
  显示完整原文进入查询，检测 auto 后继续翻译。后续另一特殊昵称也完整保留尾部空格进入查询。

### 受影响文件

- `Easydict/Swift/Service/Apple/AppleLanguageDetector/AppleLanguageDetector.swift`
- `Easydict/Swift/Model/{QueryModel,DetectManager,QueryError}.swift`
- `Easydict/Swift/Feature/ActionManager/ActionManager.swift`
- `Easydict/Swift/Utility/EventMonitor/{Core/EventMonitor,Workflow/SelectionWorkflow}.swift`
- `Easydict/Swift/Utility/Extensions/String/String+HandleInputText.swift`
- `Easydict/objc/ViewController/Window/WindowManager/EZWindowManager.m`
- `Easydict/Swift/Service/{AITool,Ali,Baidu,Bing,Caiyun,Google,NiuTrans,OpenAI}/`
- `Easydict/Swift/View/SettingView/Tabs/TabView/AdvancedTab.swift`
- `Easydict/App/Localizable.xcstrings`
- `EasydictTests/{Model/QueryModelTests,Service/AppleLanguageDetectorTests,Service/OpenAI/StreamServicePromptTests}.swift`
- `Easydict.xcodeproj/project.pbxproj`

### 后续事项

- 未逐一发起第三方服务真实网络请求；各适配器的完整原文 payload 已核对源码。
- 本次不推送、不重新公证打包或发布 COS。
