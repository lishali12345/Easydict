## 2026-10-20 | 任务：实现 ME-Dict 独立应用与多语言替换流程

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-20-medict-custom-workflow.md)

### 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

保留本机官方 Easydict，创建独立的个人定制应用 ME-Dict。提供可配置的语言列表，
默认关注简体中文、英语、印尼语、马来语、菲律宾语和越南语。简体中文直接翻译替换为英文；
英文先展示可配置的多语言译文预览，选择后才替换，继续支持同语种润色。

### 变更

- Release 使用 ME-Dict / com.helihua.medict / medict URL Scheme，Debug 使用独立 debug 身份。
- 新增 ME 图标，菜单栏显示 ME 或 ME DEBUG；停用官方 Sparkle 更新入口与上游遥测、符号上传。
- 独立配置与数据目录；Codex 历史目录迁移不搬走官方共享目录。
- 新增启用语言与英文目标语言偏好、设置界面和查询语言菜单过滤，保留完整检测及服务能力表。
- 当前第一/第二语言保持启用，可先更换再关闭；目标列表可选其他已启用语言，排除英文源语言。
- Translate and Replace 根据实际检测语言分流；英文候选独立加载、展示失败和成功结果。
- 完整成功结果才写回，保存并核验原应用、元素、全文和 UTF-16 选区；取消与新任务使旧结果失效。
- 无法可靠定位原输入时提供显式复制；不向任意前台窗口模拟粘贴。
- 全局默认快捷键增加 Control，翻译替换为 Control+Option+T，润色替换为 Control+Option+P。
- 26 条新增 UI 文案覆盖现有六种界面语言；工程引用、Debug/Release 测试宿主与 scheme 同步。
- 内置服务密文保持原 Easydict 加密种子，避免 App 更名改变密钥；无效 UTF-8 解密结果返回空值。

### 设计意图

将定制应用身份与官方应用完全分开，语言筛选只控制用户选择界面，不改变自动检测或翻译商能力。
候选翻译与写回分离，原文在明确选择、完整请求成功且输入上下文仍有效时才改变。
保留原 BuiltInAI 翻译和 PolishingService 润色服务，其他源语言继续使用已有目标语言规则。

### 验证

- `xcodebuild test -workspace Easydict.xcworkspace -scheme ME-Dict -configuration Debug`，
  精确选择 `ReverseTranslationTests`、`AppleLanguageDetectorTests`：现有 38 项回归测试通过。
  AES 修复后另行运行现有 `UtilityFunctionsTests/testAES()`，1 项通过。
- `xcodebuild build -workspace Easydict.xcworkspace -scheme ME-Dict -configuration Release`：
  arm64 / x86_64 构建成功。构建与测试使用当前 checkout 的独立 DerivedData，未并发使用该目录。
- SwiftLint：432 个文件，0 项违规；`git diff --check`、两份 String Catalog JSON 与 plist 检查通过。
- `codesign --verify --deep --strict`：Release 产物与安装副本通过，副本逐文件内容与产物一致。
- 已安装并启动 ME-Dict；真实配置域自动检查、自动下载更新均为 0。
- 本机官方 Easydict 2.25.0 的 300 个安装文件在安装及启动后 SHA-256 全部保持一致，两应用同时运行。
- `review` 技能审查：修复异步取词前未冻结选区的问题，复审关闭该 finding；AES 修复增量审查通过。
  最终产品源码与已审查快照一致，目标语言映射与并行请求隔离窄查无确定缺陷。
- 真实查询发现旧 AES 算法从 `CFBundleName` 派生密钥，更名后错误明文在 UTF-8 强制解包时
  触发 SIGTRAP。固定兼容种子后重新构建、安装并执行查询，崩溃不再发生。
- 用户对重新安装的应用再次授权后，只读 LLDB 检查 Release 进程的 `AXIsProcessTrusted()`，
  明确返回 `true` 并立即分离，辅助功能权限生效。
- 用户在 TextEdit 选中中文样例并按真实 Control+Option+T 后完成直接替换；通过 CUA 回读同一
  文档确认正文为 `Hello, we have received your feedback and will handle it for you as soon as possible.`。
  原中文为“您好，我们已经收到您的反馈，会尽快为您处理。”。
- 用户实际确认英文四语预览、取消保留英文、选行替换均成功，并明确最后选择越南语。
  CUA 回读同一 TextEdit 文档的最终正文为
  `Chào bạn, chúng tôi đã nhận được phản hồi của bạn và sẽ xử lý nó cho bạn càng sớm càng tốt.`，
  与用户选择一致。
- 早前单次查询曾返回上游 API 1302（账户速率限制）；后续实际中文翻译和四语预览成功，
  该单次失败不再阻塞验收，但不构成服务持续可用性的保证。
- 未新增或扩写测试。现有自动化测试不覆盖新候选窗口及跨应用写回；这些路径由用户真实按键、
  用户确认窗口行为及 CUA 回读 TextEdit 共同验证。CUA 绑定 ME-Dict 窗口超时、合成全局快捷键
  无效，未将工具尝试标记为通过；Polish and Replace 本轮未单独进行真实交互验收。

### 受影响文件

- `Easydict.xcodeproj/project.pbxproj`、共享 scheme、App plist 与 String Catalog。
- `Easydict/App/EasydictApp.swift`、`Easydict/App/Icons/ME-Dict.icon/`。
- `Easydict/Swift/Feature/ActionManager/`、`Easydict/Swift/Feature/Configuration/`。
- `Easydict/Swift/Feature/Shortcut/Model/ShortcutManager+Default.swift`。
- `Easydict/Swift/View/SettingView/Tabs/TabView/`、菜单视图。
- `Easydict/Swift/Utility/Constants/AppConstants.swift`、`GlobalContext.swift`、
  `Logging/AnalyticsService.swift` 与 `AppPathManager/`。
- `Easydict/Swift/Utility/Extensions/String/String+EncryptAES.swift`。
- `Easydict/objc/Utility/EZLinkParser/EZSchemeParser.h` 与两个语言菜单按钮。

### 后续事项

- 不提供可靠 Accessibility 元素、全文及选区的输入框仅支持复制译文后手动粘贴。
- 翻译可用性与质量取决于沿用的翻译服务；本次不更换引擎或增加账号迁移。
- 本地开发包重新签名后可能需要重新授予辅助功能权限。
- 计划已归档；按项目规则创建本地提交，不 push。
