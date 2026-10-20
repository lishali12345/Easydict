# ME-Dict 本地签名与更新

日用 ME-Dict 使用固定 Apple 签名身份，Bundle ID 为 `com.helihua.medict`，
安装路径为 `/Applications/ME-Dict.app`。官方 `/Applications/Easydict.app` 保持独立。

## 首次配置

在钥匙串中保留有效的 Apple Development 证书及对应私钥。读取可用身份：

```sh
security find-identity -v -p codesigning
```

在仓库根目录创建 `ME-Dict.local.xcconfig`，填写选定证书的团队 ID 和 40 位 SHA-1 指纹：

```xcconfig
DEVELOPMENT_TEAM = YOURTEAMID
CODE_SIGN_IDENTITY = YOUR_CERTIFICATE_SHA1
CODE_SIGN_STYLE = Manual
```

该文件已被 Git 忽略，不提交个人配置或任何私钥。团队 ID 来自证书 Subject 的 OU 字段，
证书名称括号中的标识不一定是团队 ID。Release 由 `Easydict.xcconfig` 引入本地配置，
也适用于在 Xcode 中直接构建 Release。

首次从过去的 ad hoc 安装切换：

```sh
python3 scripts/update-medict.py --migrate-from-adhoc
```

首次迁移改变了应用身份，可能需要在「系统设置 → 隐私与安全性 → 辅助功能」中重新启用
ME-Dict。若开关无效，移除旧条目后重新添加 `/Applications/ME-Dict.app`。
此操作由用户在系统设置中完成，脚本不会修改系统权限数据库。

## 后续更新

```sh
python3 scripts/update-medict.py
```

脚本在独立 DerivedData 中构建 Release，验证证书、团队、Bundle ID、签名及关闭自动更新的配置。
安装前要求新包满足已安装包的 designated requirement；检查失败会停止，不会退回 ad hoc。
安装仅停止并替换 ME-Dict，失败时恢复旧包，同时核对官方 Easydict 文件未变。

只构建或安装已经构建的产物：

```sh
python3 scripts/update-medict.py --build-only
python3 scripts/update-medict.py --install-only
```

安装既有产物仍会进行签名和身份检查。Debug 的 Bundle ID 为 `com.helihua.medict.debug`，
其签名与辅助功能权限独立，原有 `scripts/setup-team.sh` 只配置 Debug。

## 为什么能保留权限

macOS 使用 designated requirement 识别更新前后是否为同一个应用。ad hoc 签名的 requirement
绑定特定构建；证书签名可以在代码更新后保持同一身份。
参见 Apple [TN3127: Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。

同一身份的正常更新应保留权限；换团队、Bundle ID 或签名类型、系统重置权限等情况仍可能
要求重新授权。证书过期或撤销时需更新本地配置，脚本仍会检查新包是否兼容原身份。
这套流程用于本机开发，不包含对外分发、公证或远端发布。
