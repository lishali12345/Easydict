# Magpie 翻译插件已迁至独立工程

MeeTar 翻译术语与记录插件已于 2026-11-05 从本仓库迁出，今后在独立的 **magpie-plugins** 工程中维护，插件子目录为 `meetar-translation/`。

这是一项 Magpie 插件，不是 ME-Dict 的应用内模块。ME-Dict 与沉浸式翻译继续通过现有 `group/translate` 服务使用它。

- 当前实现、使用命令和迭代上下文见独立工程的 `README.md`、`meetar-translation/README.md` 和 `docs/PROJECT_CONTEXT.md`。
- 个人术语、翻译记录和备份仍在 `~/Library/Application Support/MeeTarTranslation/`，本次没有迁移或重建数据库。
- Magpie 已切换到独立工程的插件路径。不要重新登记旧的 `integrations/magpie-meetar-translation/`，以免重复注入和重复记录。
- 原实现可在本仓库提交 `734626635ae53fabfe956f237248778006d57419` 中追溯。

详见[迁移记录](../../histories/2026-11/2026-11-05-magpie-plugin-extraction.md)。
