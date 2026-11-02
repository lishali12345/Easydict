# 保留原文并修复语言检测递归崩溃

- 状态：completed
- 创建日期：2026-11-02
- 负责人：/root
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `/root`
- **Model:** `GPT-6`
- **Environment:** `macOS 26.6.2 / Xcode 27.2 (27B52)`

## 背景

Command+D 查询含特殊字母与 Emoji 的文本时，AppleLanguageDetector 对过滤后的相同文本重复递归，
21:49 与 21:50 两份本机崩溃报告均显示重复 mixed-content 检测栈与 stack guard 内存异常。
用户确认完整原文应传给实际参与查询的服务，不应静默清理或截断；检测不确定不应阻断翻译。

## 目标与范围

- 目标结果：检测无递归；从选区到服务请求保留原文；不确定使用 auto；长度超限明确报错。
- 允许修改路径：选词获取、QueryModel、AppleLanguageDetector、DetectManager、ActionManager、
  Google/Baidu/Bing/Ali/NiuTrans/Caiyun 翻译与检测适配、QueryError、StreamService prompt、
  本地化、高级设置、相关授权测试及工程引用、本任务记录。
- 同任务 history：`docs/histories/2026-11/2026-11-02-medict-original-text-detection.md`
- 用户限制：只调用本次查询参与的服务，不发送聊天消息，不影响官方 Easydict。
- 非目标：TTS、OCR 识别算法、用户主动编辑操作、发布 COS、新服务接入。
- 验收标准：原崩溃输入可查询；普通翻译与替换可用；原文保持完整；构建和适用现有测试通过。

## 工作计划

1. 按崩溃报告与调用链确认重复检测，审计原文获取和服务请求。
2. 去除递归及过滤后重检，保留不确定结果；检测优化完整发送输入。
3. 移除隐式清理/截断，已知长度超限改明确错误；模型支持 auto 识别提示。
4. 运行相关现有测试、固定签名 Release 构建安装，实机核验。
5. Review、更新 history、归档并本地提交，不推送或发布。

## 风险与决策

- 基线 c79e00eeb092a7d2d9546a8dba807b29d427f319，初始工作树和索引干净。
- 用户允许本地字符统计，服务请求不得使用加工后的字符串。
- 原生框架未返回候选时保持 auto，不将无法识别的内容强制设为英语。
- 保留取消、过期结果保护及原输入框全文/选区写回校验。
- 用户已明确允许同步更新相关现有测试，并补充本次特殊昵称及原文保留回归测试。
- 移除会与原文契约冲突的自动清理设置入口；保留用户主动的文本编辑按钮。
- 原文链路由 /root/raw_text_audit 负责，主Agent负责检测器与替换路由，禁止重叠编辑。

## 进度

- [x] 崩溃报告与原文链路确认。
- [x] 实现与检查。
- [x] 构建/相关测试及真实交互验收。
- [x] 审查通过、记录归档并交付本地提交。

## 验证

- 原版：两次同文本真实查询均崩溃；AppleLanguageDetector 混合处理连续递归，异常落在 stack guard。
- 三个相关 suite 共 37 项测试通过：AppleLanguageDetectorTests、QueryModelTests、StreamServicePromptTests。
- 首轮暴露 7 个日英/韩英/中英混排断言失败；修正为本地文字种类判断后，保留原断言全部通过。
- QueryModel 与提示词按 UTF-8 验证原文；包括 NFC/NFD 连续更新、Emoji、换行和模板标记字面值。
- 依赖使用 Package.resolved 锁定版本；初次默认解析停滞已中止，未变更依赖。

## 完成条件

- 原崩溃场景通过、原文契约检查完成、构建及适用验证通过，未影响官方应用。

- 固定签名 Release 构建与安装通过；官方 Easydict 318 个文件摘要未变。
- 用户实测 Command+D 原昵称正常；日志确认 shortcut_query、完整原文与 auto 后继续查询。
- 独立 review 未发现确定缺陷，24 个源码/测试文件快照复验一致。
