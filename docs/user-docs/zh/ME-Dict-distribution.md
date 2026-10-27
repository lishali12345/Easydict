# ME-Dict Apple Silicon 签名、公证与 DMG

该流程只生成分发产物，不安装、不启动、不注册应用，不读取个人服务偏好或密钥。
日用版仍使用 [本机更新流程](ME-Dict-local-development.md)；不改 `ME-Dict.local.xcconfig`。
同事使用说明见 [安装说明](ME-Dict-installation.md)。`publish` 可将 DMG 上传 MeeTar COS；不包含自动更新。

## 一次性配置

需要 Xcode、已安装且与锁文件一致的项目依赖、Apple Developer Program 会员，以及：

1. **Developer ID Application** 证书和对应私钥。Xcode → Settings → Accounts，
   选择个人账号与正确团队 → Manage Certificates → ＋ → Developer ID Application。
   不要撤销现有 Apple Development 证书；多账号可以并存。
2. 公证凭据保存到本机 Keychain，不能写入仓库或命令行的明文密码参数：

   ```sh
   xcrun notarytool store-credentials ME-Dict-notary
   ```

   按交互提示输入 Apple ID、团队 ID、App 专用密码；也可按工具帮助配置 App Store Connect API key。
   工具会在线验证凭据。密码和私钥不要粘贴到聊天、日志或配置文件。
3. 读取有效签名身份：

   ```sh
   security find-identity -v -p codesigning
   ```

4. 在仓库根目录创建被 Git 忽略的 `ME-Dict.distribution.local.json`：

   ```json
   {
     "team_id": "YOURTEAMID",
     "certificate_sha1": "REPLACE_WITH_40_CHARACTER_DEVELOPER_ID_SHA1",
     "notary_profile": "ME-Dict-notary"
   }
   ```

   团队使用个人团队 `LC4969GPTD` 时，将 `YOURTEAMID` 替换为该值。指纹必须来自
   **Developer ID Application**，不能使用 Apple Development 或 Developer ID Installer。
   配置只保存证书指纹与 Keychain profile 名，不保存密码或私钥。

预检（会向 Apple 发起只读公证历史查询，但不上传软件）：

```sh
python3 scripts/package-medict.py check
```

## 一条命令发布到 COS

本机签名、公证配置完成后，再一次性配置 COS 工具。复用本机安装的 `meetar-res-admin`
技能中的上传脚本与本地 `config.yaml`，无需把 COS 密钥复制到本仓库。
在仓库根目录准备隔离 Python 环境：

```sh
python3 -m venv .tmp/medict-cos-venv
.tmp/medict-cos-venv/bin/python -m pip install cos-python-sdk-v5 PyYAML
```

创建被 Git 忽略的 `ME-Dict.publish.local.json`，只保存工具与凭据文件的路径：

```json
{
  "python": ".tmp/medict-cos-venv/bin/python",
  "uploader": "~/.codex/skills/meetar-res-admin/scripts/upload_to_cos.py",
  "config": "~/.codex/skills/meetar-res-admin/config.yaml"
}
```

路径支持 `~`，相对路径从仓库根目录解析；如本机技能安装位置不同，填写实际路径。
Python 环境需要有 `cos-python-sdk-v5` 和 `PyYAML`；清理 `.tmp` 后需重新创建环境。
COS 配置由原工具读取，也沿用其 `TENCENT_COS_*` 环境变量覆盖规则。

只读预检（验证签名身份、公证凭据、COS 依赖与 bucket 访问）：

```sh
python3 scripts/package-medict.py check-publish
```

代码提交且工作树干净后，每次迭代只需运行：

```sh
python3 scripts/package-medict.py publish --version 2.24.0 --build 69
```

该命令依次构建、Developer ID 签名、App 公证、DMG 打包与公证，然后上传 COS。
目标固定使用原上传工具的 `file` bucket，保留文件名；对象路径为
`medict/releases/<version>-<build>/<SHA-256>/ME-Dict-<version>-<build>-arm64.dmg`。
同一对象已存在时校验并复用，内容不同则报错，绝不覆盖。
匿名完整下载得到 HTTP 200、正确文件类型及一致的大小和 SHA-256 后，最后输出：

```text
DOWNLOAD_URL: https://file.meetarapp.com/medict/releases/…/ME-Dict-…-arm64.dmg
```

链接无临时签名参数，长期可用依赖 COS/CDN 的域名和保留策略。
运行目录中 `cos-plan.json`、`cos-upload.json`（实际上传时）、`cos-publish.log` 保存上传阶段证据，
`artifacts/publication.json` 和 `manifest.json` 保存已验证下载链接。
失败时命令返回非零，不输出成功下载链接；日志/旧回执不能替代本次退出状态。

发布过程的公证、上传或下载校验中断后，执行：

```sh
python3 scripts/package-medict.py resume <run-id>
```

`publish` 会保存上传意图，`resume` 在完成公证后自动继续 COS；已有对象只校验复用。
尚未生成正式包时仍要求原 commit 和干净工作树；DMG 已处于 ready 状态时，可在代码迭代后
续传原产物，上传前重新核对原签名、票据、Gatekeeper 和哈希。构建尚未完成的失败需重新 publish。

已有通过原 `release` 命令生成的正式包，也可补上传：

```sh
python3 scripts/package-medict.py upload <run-id>
```

`upload` 不重编译，不重新提交公证；不能上传 unsigned build-check 产物。
同事请复制链接到 Safari 下载，再用新下载的 DMG 安装，避免飞书内置下载器添加禁止执行标记。

## 重复打包

先提交需要分发的代码，确保工作树干净。为每次交付选择明确的版本号与递增构建号，例如：

```sh
python3 scripts/package-medict.py release --version 2.24.0 --build 68
```

版本只通过构建参数设置，不写回工程文件。每次生成独立 run 目录并打印位置：

```text
.tmp/medict-distribution/<run-id>/
  archive.log / export.log        构建与导出日志
  state.json                     commit、签名身份、公证 ID 与阶段
  app-*.json / dmg-*.json         公证结果及失败详情
  artifacts/                     只有通过验证的交付文件
    ME-Dict-2.24.0-68-arm64.dmg
    SHA256SUMS.txt
    manifest.json
```

脚本依次执行：

1. 检查固定 Developer ID 身份及公证凭据。
2. 使用独立 DerivedData 构建 arm64 Release archive，由内到外签名嵌套组件（包括 Sparkle
   辅助进程），保留各自 entitlement，再导出 Developer ID 应用。
3. 检查 Bundle ID、版本、自动更新关闭、arm64、嵌套代码签名、时间戳及 Hardened Runtime。
4. 公证 App，确认 Accepted，附加并校验票据，通过 Gatekeeper 检查。
5. 将 App、Applications 快捷入口、安装说明、GPLv3 许可证和对应 commit 源码放入 DMG。
6. 签名并公证 DMG，确认 Accepted，附加并校验票据、磁盘镜像和 Gatekeeper。
7. 输出 SHA-256 与 manifest。只有显示 `READY` 且 manifest 状态为 `ready` 才可分发。

分发 DerivedData 使用项目规定的 `Easydict-Agent` 目录，checkout 名后追加
`-medict-distribution`；与日用构建隔离。脚本加进程锁，拒绝并发使用分发构建目录。
构建跳过会修改源码的 SwiftFormat phase，使用仓库锁定依赖，不自动更新依赖。

## 失败恢复

公证等待超时、网络中断或附加票据失败时，保留 run 目录并运行：

```sh
python3 scripts/package-medict.py resume <run-id>
```

脚本复用原始文件和 submission ID，校验文件哈希，不会因等待超时重新上传。
未完成打包时，恢复要求原签名配置、原 commit 和干净工作树；如代码已变更，先保存当前工作再恢复原提交，
或为新代码重新 `release`。构建/导出未完成时修复原因后重新运行 `release`。

极少数情况下，上传已开始但进程未收到 submission ID：查看本次 `*-submit.json`、
`*-submit.log`，并通过 Apple 公证历史确认该文件对应的 ID，再执行：

```sh
xcrun notarytool history --keychain-profile ME-Dict-notary
python3 scripts/package-medict.py resume <run-id> --submission-id <UUID>
```

不要猜测 ID 或盲目重复上传。最终 App/DMG 的票据和 Gatekeeper 检查仍必须通过。
Apple 返回 Invalid 时查看 `*-issues.json`，修复签名或依赖后创建新的 run。
脚本不会绕过公证，也不自动删除失败现场。

## 没有证书时的构建验证

```sh
python3 scripts/package-medict.py build-check --version 2.24.0 --build 68
```

此命令仅验证 unsigned arm64 构建和包结构，不需要签名配置，不生成可分发 DMG，
也不能通过 `resume` 升级成正式包。它不代表签名、公证或其他电脑运行验证通过。

## 分发前验收与更新边界

- 在另一台 Apple Silicon Mac 上使用实际下载的 DMG 验证拖拽安装、首次打开和权限申请。
- 同事自行配置服务，再验证 TextEdit 以及实际浏览器输入框中的翻译、润色、候选复制和替换。
- 以第二个分发版本验证覆盖更新后设置与权限保留；正常分发应保持 Bundle ID、团队及签名类型稳定。
- 不把此分发包覆盖开发者正在使用的 Apple Development 日用版；两条流程使用相同 Bundle ID，
  在同一台 Mac 上切换签名类型可能触发重新授权。
- 公证不代替辅助功能、屏幕录制或自动化权限，也不保证所有第三方输入框支持直接替换。
- 本流程不禁用 Gatekeeper、不修改 TCC，也不复制个人服务密钥和偏好。

## Apple 参考

- [Developer ID 证书](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
- [在 Mac App Store 之外分发](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html)
- [自定义公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
