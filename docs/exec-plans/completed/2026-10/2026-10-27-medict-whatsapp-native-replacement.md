# WhatsApp 原生应用候选替换适配

- 状态：completed
- 创建日期：2026-10-27
- 负责人：/root
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.1 (27A9275)`

## 背景

用户报告 WhatsApp 原生应用中，候选弹窗 Command+1 无法替换输入框。当前捕获日志确认
`net.whatsapp.WhatsApp` 能取得完整选区并启用替换，但使用直接 AX 写入；Chrome 使用已验证的 Paste 路径。

## 目标与范围

- 目标结果：WhatsApp 原生输入框通过候选快捷键可靠替换，并保留原文/选区变化保护。
- 允许修改路径：替换操作相关 Swift 文件及本任务 plan/history；仅按诊断证据修改。
- 同任务 history：`docs/histories/2026-10/2026-10-27-medict-whatsapp-native-replacement.md`
- 用户限制：暂停证书配置；使用既有本机签名，不影响官方 Easydict。
- 非目标：消息发送、分发公证、通用快捷键重构、新增测试。
- 验收标准：实际 WhatsApp 草稿验证候选快捷键替换；签名/安装通过，官方包不变，验证后恢复原草稿。

## 工作计划

1. 结合实际候选窗口、草稿和日志区分快捷键未触发与写回失败。
2. 最小修改对应写回/焦点路径，保持输入与剪贴板保护。
3. 构建并安装本地签名版，使用真实快捷键与日志核验。
4. 使用 review 技能复核，记录结果并提交。

## 风险与决策

- 原聊天已有草稿，已保留；使用临时中文样例验证，不点击发送。
- 自动化按键在此 App 中不可靠，实际全局快捷键由用户触发；日志与 UI 回读分别记录。
- 初始 HEAD `455134a968829fda79b4dd9603cdeac717fe7124`，工作树干净。

## 进度

- [x] 读取替换入口和原生 App 状态，确认快捷键回调正常。
- [x] 接入应用粘贴路径，补齐无 AXIdentifier 的菜单查找。
- [x] 诊断并修复激活前焦点误判，保留最终写入保护。
- [x] 用户真实快捷键验收成功，日志确认两次写回，原草稿恢复。
- [x] 清理诊断后的最终构建安装与签名核验。
- [x] 完成审查，随本任务创建本地提交。

## 验证

- 首次菜单适配安装成功，但用户确认仍失败；候选窗口提示输入框/内容/选区变化。
  Command+1 已进入替换回调，因此继续检查焦点校验。
- 实际诊断两次均显示：激活前 sameElement=false，而 textUnchanged/rangeUnchanged=true；
  激活后前台、焦点元素、原文和选区均恢复一致。
- 第二版用户确认 Command+1 成功替换为英文；14:12:22 和 14:12:47 日志均记录
  `Replacement writeback verified: app=net.whatsapp.WhatsApp, pasteMenu=true`。
- WhatsApp 菜单缺少 AXIdentifier；本地依赖源码确认通用查找会跳过该菜单。
  兼容路径限定 WhatsApp，匹配 menuItem、V、仅 Command 修饰键及现有本地化 Paste 标题。
- 临时布尔诊断已删除，最终写入前仍验证原应用、焦点元素、全文和 UTF-16 选区。
- 原草稿已恢复，输入框 AX 回读与保存内容一致。Agent 未执行发送操作。
- 无现有 suite 直接覆盖 WhatsApp 系统焦点/菜单行为；未新增测试，使用实机交互与日志验收。
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

## 完成条件

- 修改通过构建与适用审查。
- 用户实际操作及回读确认 WhatsApp 替换成功。
- 原草稿恢复，官方 Easydict 不变，history 完成并归档计划。
