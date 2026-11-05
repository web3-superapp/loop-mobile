# 0287 · 单个项目接口的三个条款键（S363-mobile）

## Status

Accepted · 2026-11-05（S363-mobile）。补 0284：0284 只在 hooks-config 草稿 `config`、launch2 实例与签名请求里放开了三个条款键，漏了 `GET /v2/launch/projects/{id}`。

## Context

- 现象：TF 66（807f0d7f）连 staging，用户提交了带非默认条款的申请（项目 HI，nftPriceUsd1 150、walletCapPerMille 8）。「我的项目」列表正常，点进项目详情页报 chain_contractInvalidData「返回的数据不完整」；staging 日志里 `GET /v2/launch/projects/:projectId` 与 `…/hooks-config` 都是 200。
- 根因：loop-api 决策 0199，`LAUNCH2_PROJECT_TERMS_EMIT=on` 时单个项目的 `project` 对象多带 `nftPriceUsd1`（1…1000 整数或 null）、`walletCapPerMille`（1…1000 整数或 null）、`maxCumulativeBuyRaw`（正的 uint 十进制字符串）。App `loop_v2_launch_api.dart` 的 `_project()` 用严格键集解析，可选键只有 `rejection` / `communityId`，三个键被当成未知键 → invalidPayload。列表接口不带这三个键，所以列表没炸；项目详情页 `Launch2ProjectController.fetch` 并行读 project 与 config，project 先判无效。

## Decision

- `_project()` 的可选键集合加上 `LoopV2Launch2CreatorCodec.projectTermsKeys`，三个值直接复用 0284 的 `nftPriceUsd1` / `walletCapPerMille` / `maxCumulativeBuyRaw` 静态函数解析，规则只有一份。缺省或 null 视为未带；越界、类型不对、`"0"` 仍判无效。其余未知键照旧判无效。
- 列表接口与单个接口共用 `_project()`，所以列表项带这三个键也能解（契约允许，api 现在不带）。
- `LaunchProject` 加三个可空字段 `nftPriceUsd1` / `walletCapPerMille` / `maxCumulativeBuyRaw`（命名参数，默认 null，现有构造处不用改；该类没有 `==` / copyWith）。

## Consequences

- 页面不读这三个字段：项目详情页的条款展示仍从 hooks-config 草稿读（0284），不变。
- ≤ TF 66 的包在 `LAUNCH2_PROJECT_TERMS_EMIT=on` 时打不开 MEME 项目详情；须用带本修复的包，或 staging 暂关开关。
- 测试：新增 `test/s363_launch_project_terms_keys_test.dart`（单个项目带三键解码正确；三键缺省 / null 解码为 null；nftPriceUsd1 = 0 / 1001 / "150" / 1.5、walletCapPerMille = 0 / 1001 / "8"、maxCumulativeBuyRaw = "0" / "-1" / "01" / 8 / "1e24" 判无效；带三键时其他未知键仍判无效；列表项带三键也能解）。
