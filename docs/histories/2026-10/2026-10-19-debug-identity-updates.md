## 2026-10-19 | 任务：区分 Debug 应用名称并关闭自动更新

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-19-debug-identity-updates.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

### 用户请求

将 Debug 的应用显示名称改为 Easydict-debug，禁用自动更新，不影响正式版。

### 变更

- Debug plist 使用 PRODUCT_NAME 生成 CFBundleName 与 CFBundleDisplayName，默认关闭自动检查和自动下载。
- 删除 InfoPlist String Catalog 中各语言一致的固定品牌名称，让系统回退到各配置的 plist 名称；保留权限说明等本地化。
- Debug 在 Sparkle 启动前将自动检查和自动下载设为 false，覆盖旧偏好；禁用设置中的自动检查开关。
- Release 保持原有 Sparkle 启动方式；手动检查更新入口保留。

### 设计意图

以现有 BuildConfig 区分构建，沿用 Sparkle 自身偏好 API，避免只改默认值而无法覆盖旧设置。
品牌名由构建配置决定，Release 仍显示 Easydict；Bundle ID、数据目录和正式安装包保持不变。

### 验证

- Debug `xcodebuild build`：通过；SwiftFormat、SwiftLint（0 violations）及 codesign 验证通过。
- Debug 产物：CFBundleName / CFBundleDisplayName 均为 Easydict-debug；本地化资源不再覆盖名称。
- Debug 重启后：macOS NSRunningApplication.localizedName 和 Bundle 解析名称均为 Easydict-debug；SUEnableAutomaticChecks、SUAutomaticallyUpdate 均回读为 0。
- Release `xcodebuild build`：以本地 ad hoc 签名构建 arm64 / x86_64，通过；SwiftFormat、SwiftLint 和 codesign 验证通过。产物名称仍为 Easydict，SUEnableAutomaticChecks 为 true，SUAutomaticallyUpdate 未新增。未启动此校验产物，并取消其 LaunchServices 注册，避免与正式安装包的入口竞争。
- 已安装正式版：可执行文件、Info.plist 的 SHA-256 与修改前一致；更新偏好未变化。
- `plutil -lint`、`jq -e .`、`git diff --check`：通过。
- Review：基于 af5b654f2890341a48f32237118ad2a686ea8f9d 的本任务四个产品文件差异，核对本地 Sparkle 2.8.1 源码、启动顺序、偏好作用域、Release 分支和名称回退；未发现有效 finding，现有最小实现足够。
- 未新增测试；现有测试未覆盖此次名称打包和 Sparkle 启动行为，未运行不相关的测试套件。未触发真实下载或更新安装。
- UI 自动化读取超时；名称和更新状态通过系统 API、产物及实际偏好回读验证。

### 受影响文件

- `Easydict/App/Info-debug.plist`
- `Easydict/App/InfoPlist.xcstrings`
- `Easydict/Swift/Utility/GlobalContext.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/GeneralTab.swift`
- `docs/exec-plans/completed/2026-10/2026-10-19-debug-identity-updates.md`
- `docs/histories/2026-10/2026-10-19-debug-identity-updates.md`

### 后续事项

- None
