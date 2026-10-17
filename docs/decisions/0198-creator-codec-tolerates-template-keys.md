# 0198 · 创建者编解码容忍模板新键 + 严格解码器全仓对账（S222-mobile）

## Status

Accepted 2026-10-17。基线 `integration/v2` 87a06b6（TF build 26）。依据：loop-api 决策 0144 / 0146 / 0152 / 0163，
`loop-api/openapi/loop-api.v2.json`（loop-api `integration/v2` 861031d）。修订 0160 §2 / §3、0197 Consequences 第三条（原文处加「0198 修订」注）。
不新增依赖、路由、字体、颜色 token；`pubspec.lock` 不变；无新请求。

## Context

S221 在 staging 用 build 26 复现：

1. MEME → 发起 → 填资料 → 第 3 步选时间 → 「提交审核」→ 按钮变「重试提交」，红字「返回的数据不完整，结果未确认。请刷新查看最新状态，不要重复提交」。
   服务端：`POST /v2/launch/projects` 201、`GET` / `PUT hooks-config` 200，`submit` 从未发出，项目停在 draft。
2. MEME → 我的项目整页「返回的数据不完整」：列表逐个 `GET hooks-config`，账号下只要有一个新工厂（0x5725…，S209）草稿，`Future.wait` 整页失败。

根因：loop-api 861031d 让 `fixedEconomics.loopDynamic` 带上工厂参数 `maxDynamicFeeWad`（0144）、`maxCumulativeBuy`、`buyFeeToken`（0152）。
创建者解码器对 `loopDynamic` 是严格八键（0160），多一个键即 `invalidPayload`；`PUT` 是写，于是映射成 `outcomeUnknown`。重试先 `GET hooks-config` 再解析，同样失败，App 内无路可绕。

这是同一类缺陷的第四次（0180 能力位、0197 dynamic-pool、本次 hooks-config）：服务端随合约代际 additive 地加字段，客户端严格解码器整页失败。

## Decision

### 1. 创建者 `fixedEconomics.loopDynamic` 收下三个新键，并建模

| 键 | 校验 | 模型 | 展示 |
|---|---|---|---|
| `maxCumulativeBuy` | 可选；非负整数串（`^(0\|[1-9][0-9]{0,77})$`），raw MEME | `Launch2LoopDynamicEconomics.maxCumulativeBuyRaw` | `Launch2FixedEconomics.curveCapRaw`：> 0 时取它，否则模板常量 `perAddressLifetimeBuyCapRaw` |
| `buyFeeToken` | 可选；只认小写 `meme` / `usd1`，其它值或 `null` 无效 | `buyFeeToken`（复用 0197 的 `Launch2BuyFeeToken`） | 有值才多一行「外盘买入税 2%（从付出的 USD1 扣 / 从到手的 MEME 扣）」；缺键不推断、不显示 |
| `maxDynamicFeeWad` | 可选；非负整数串 | `maxDynamicFeeWad` | 本批不展示 |

模板卡（创建第 3 步、项目状态页）的上限行改成 0197 发射规则同一写法：「单地址上限 3,000,000 枚（0.3%）」（旧模板「5,000,000 枚（0.5%）」）。
数字用 0197 的 `launch2CurveCapFigure`，买入税方向用新提取的 `launch2BuyFeeSideText`（报价行与模板卡共用一套文案，没有第二套）。

### 2. 宽松策略：只给「模板 / 经济参数」对象，已知键严格、未知键忽略

新增 `LoopV2Contract.knownKeysMap(value, required, [optional])`：必需键必须在、非字符串键与重复键仍无效、已知键照常逐个校验；
**未知键从结果里删掉**，调用方读不到。适用对象（全部是「按工厂代际固定、只用于展示、不参与签名或金额计算」的参数块）：

- 创建者 `hooks-config` 的 `draft.config.fixedEconomics`；
- 创建者 `fixedEconomics.loopDynamic`；
- launch2 实例详情 `instance.template`（0197 刚给它加过 `perAddressCap`）。

理由（同 0180）：这些对象每次合约代际都会 additive 地加参数，旧包看不到新参数只是少显示一行，而整页失败让需求方第一步就卡死；
它们不进签名（签名走 `signing-request` 的 typed data，仍严格）、不进 PUT 体（PUT 只送七个 owner 字段），也不参与任何金额推导。
其余对象**保持严格**：`draft.config`（owner 字段，多一个键可能意味着 owner 侧语义变化）、签名请求、部署任务、报价、成交、dynamic-pool、
钱包等带金额或状态语义的读面——这些对象新增键可能改变已有键的含义（例如 0152 的 `buyFeeToken` 改变了 `buyFeesMeme` 的含义），
静默忽略会把错误的结论画到屏幕上；它们的新键仍按本决策 §3 的清单逐个放行。

### 3. 全仓对账清单

方法：脚本把 `lib/integrations/backend/v2/**` 里 549 处 `strictMap` / `strictMapWithOptional` 调用的键集（含 `...` 展开与可选集）解析出来，
与 OpenAPI v2 全部 2xx 响应里的 3134 个对象 schema 比对，列出「客户端键集是某个服务端对象的真子集」的位置，再逐个人工核对它实际解码的路由。

| 位置 | 服务端已发、客户端未收 | 来源 | 影响（build 26） | 处理 |
|---|---|---|---|---|
| 创建者 `fixedEconomics.loopDynamic` | `maxDynamicFeeWad`、`maxCumulativeBuy`、`buyFeeToken` | 0144 / 0152 | 提交审核、我的项目、项目状态页整页失败 | §1 建模；对象改宽松 |
| 创建者 `GET /v2/launch2/instances` 行（`instancePage`） | `summary`、`links`（服务端为必需键） | 0163（S180） | 激活后找实例的解码失败被 best effort 吞掉：「已激活」项目点开落不到实例页 | 作为可选键接受、显式忽略（复用 `LoopV2Launch2Codec.rowOptionalKeys`） |
| `dynamic-pool` 的 `dynamicPool.viewer` | `indexedCurrentRoundWeightUsd1`、`weightReconciled` | 0146 | 登录且有钱包时外盘池卡整块失败 | 可选键接受并按 schema 校验类型（金额串或 null / 布尔或 null），不建模 |
| `dynamic-pool/rewards` 的 `rounds[]` | `creditedUsd1`、`movedInUsd1`、`movedOutUsd1`、`credits` | 0146 | 有轮次时外盘奖励页整页失败 | 可选键接受并校验类型（金额串 / ≤ 20 条对象列表），不建模 |
| `GET /v2/communities` 行 | `application` | 0073 | 不可达：只在 `membership=owned` 页出现，本客户端只请求 `all` / `joined` | 可选键接受、显式忽略 |
| launch2 实例详情 `template` | 无（当前一致） | — | — | 改宽松（§2），预防下一代参数 |

核对后排除的脚本命中（误报）：`community()`（社区首页的 10 键对象，非目录行）、Launch 交易 `unsignedTransaction`（可选键在模型常量里）、
挖矿 summary 不可用分支 / 排行 `me.communityId`（已在可选集）、本地激活存储、钱包余额根（`launchChain` / `launchUsd1` 已在可选集，注释含花括号干扰解析）、
K 线 `pool.origin`（已可选）、launch2 意图（与 MEME 意图同形误配）。dynamic-pool 顶层 0144 / 0146 六键与 `buyFeeToken` 已由 0197 放行。

### 4. 我的项目：一个读不到的项目不再拖垮整页

`Launch2CreatorPage` 改为按目录顺序的 `entries`：`Launch2CreatorReadableListEntry`（照旧）或 `Launch2CreatorUnreadableListEntry`。
某个项目的 `hooks-config` 返回 `invalidData`（本构建解不了的载荷）时，该项目单独成一行：项目名 + logo 占位 +「发射配置暂时读不到，下拉刷新或点开重试」，
**不画状态徽章**（不推断状态），点开进项目状态页（它自己再读一次并给出自己的错误态与重试）。
离线、无权限、不可用等其它失败仍是整页的，与之前相同。`rows` 保留为「读到的行」的便捷 getter。

## Consequences

- S209 新工厂项目可以提交审核、出现在我的项目里、打开项目状态页；模板卡显示工厂自己的上限与买入税方向。旧工厂项目显示与之前一致（上限行文案由「0.5%」改为「5,000,000 枚（0.5%）」）。
- 以后服务端给模板 / 经济参数加键，旧包不再整页失败；给其它对象加键仍需按 §3 的方法对账。建议后端发版前跑同一脚本（客户端键集 vs OpenAPI）。
- 0146 的 viewer / rounds 字段与 0144 的 `maxDynamicFeeWad` 仍未展示，另批。

## Tests

- `test/s135_launch2_creator_codec_test.dart` 新组 `S222 · decision 0198 template keys`：S209 形状读出三键与 `curveCapRaw` / 0.3%；
  旧 LoopDynamic 与 OfficialTax 形状三键皆空、上限回退常量；模板与参数块里的未来键被忽略；八种坏值 + 缺必需键（`router` / `perAddressLifetimeBuyCapRaw`）仍无效；
  经网关 `GET` + `PUT hooks-config`（S209 形状）走通；实例列表带 `summary` / `links` 可读、其它未知行键仍无效。
  新 fixture：`hooks_config_draft_loop_dynamic_0152.json`、`launch2_instances_summary_links.json`（均手写，标 `_handwritten`）。
- `test/s135_launch2_creator_pages_test.dart` 新组 `S222 · decision 0198`：S209 配置下「提交审核」创建 → 读 → 保存 → 提交走通、无「重试提交」；
  项目状态页显示「单地址上限」「3,000,000 枚（0.3%）」「外盘买入税」「2%（从付出的 USD1 扣）」，旧模板「5,000,000 枚（0.5%）」且无买入税行；
  我的项目一个 `invalidData` 项目成单独一行、只有一个徽章、点开进项目页；离线仍整页失败。原「0.5%」断言改为新文案。
- `test/s168_launch2_dynamic_pool_test.dart` 新组 `decision 0198`：viewer 两键（含 null）接受、坏类型与未知键拒绝；rounds 四键接受、六种坏值拒绝。
- `test/s222_codec_tolerance_test.dart`：`knownKeysMap` 语义；实例 `template` 未来键忽略、缺键与错版本仍无效；社区目录行 `application` 接受、其它未知键仍无效。
