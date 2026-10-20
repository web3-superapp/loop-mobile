# 0209 · v2 codec 可选键：launch2 成交 `account` 与邀请中心字段；推广页 L1 卡片缺「10%」（S249-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` 0a37ce8e（build 30）。依据：loop-api 决策 0162（S239，launch2 成交 `account`、邀请中心）、
0166（S248，`LAUNCH2_TRADER_ACCOUNT_EMIT` / `REFERRAL_CENTER_EMIT` 默认 `off`），loop-api `ab9f70d` 的 `openapi/loop-api.v2.json`。
只改 App：不新增依赖、路由、字体、颜色 token，`pubspec.lock` 不变，无新请求路径，不改 loop-api。

## Context

App 的 V2 解码器严格（`LoopV2Contract.strictMap`：键集必须完全相等）。0162 给已有响应加了键，build 30 的 launch2 详情页与推广页整页判
`invalidPayload`，后端以 0166 把这些键关在默认 `off` 的开关后。0166 §C：移动端把这些键落成**可选键**并随 build ≥ 31 发版后，后端才可开开关。

用 `40921be` 与 `ab9f70d` 的 OpenAPI 逐条比对既有路径 2xx 响应属性，新增键只有下表这些（新路径 `GET /v2/referral/invitees` 与非 `/v2` 的
`GET /i/{code}` 不受此限，本单不接）。

## Decision

### A. 键集对照

| 后端键（路径） | 形状 | Model 字段 | 可选策略 |
| --- | --- | --- | --- |
| `instance.recentTrades[].account`（`GET /v2/launch2/instances/{id}`） | `{publicProfileId, displayName, avatarRef} \| null` | `Launch2Trade.account: MemeAccountRef?` | `strictMapWithOptional`；缺省 / null → null；对象内多键、缺键、类型错 → `invalidPayload` |
| `trades[].account`（`GET …/pool/trades`） | 同上 | `Launch2PoolTrade.account: MemeAccountRef?` | 同上 |
| `activity[].account`（`GET /v2/launch2/overview`） | 同上 | `Launch2Activity.account: MemeAccountRef?` | 总览本就宽松：缺省 / null / 读不懂 → null，条目保留；不进 `identity` |
| `inviteLink`（`GET /v2/referral`） | `string(uri)`，`{PUBLIC_BASE_URL}/i/{code}` | `ReferralOverview.inviteLink: String?` | 可选键；出现时必须是 http(s)、无凭据、无 query / fragment、路径以 `/i/{本账号邀请码}` 结尾；null 拒绝（schema 不可空） |
| `stats {directCount, validCount, level2to5Count, validAsOf}` | 计数 ≥ 0，`validAsOf` 时间或 null | `ReferralOverview.stats: ReferralStats?` | 可选键；内部严格；`validCount > directCount` 拒绝；null 拒绝 |
| `boost` 的 `available` 分支 | `{status, referralPower, nftReferralPower, assetReferralPower, levels[5]{level, effectiveMembers, nftPower, assetPower}, epochId, hourStart, hourEnd}` | `ReferralOverview.boostAvailable: ReferralBoostAvailable?`；`boost` 改为 `LaunchUnavailable?` | `status == available` 走新分支（严格、五级齐全不重复、算力 ≤ 18 位小数、`hourEnd > hourStart`），否则仍按 `{status: unavailable, reasonCode}` 严格读；两者恰有一个非 null |

`account` 形状直接复用 MEME 成交（决策 0101）的 `LoopV2MemeCodec.account` 与 `MemeAccountRef`（loop-api 0162 §A 明说复用 `accountSchema`；
字段名是 `displayName`，不是 `alias`）。

### B. 缺省时行为不变

开关 `off`（键不存在）时三个 launch2 读与推广页的解析结果与 build 30 逐字段相同；新增字段全为 null，`boost` 仍是 unavailable。
**未知键仍拒绝**：可选集合之外的任何键（包括 `account` 对象里的多余键、`stats` / available `boost` 里的多余键）照旧 `invalidPayload`。

### C. 只解析不展示

头像可点、邀请链接分享、有效人数、可用加成的画法属于 S239 前端批。本单唯一的画面变化：`boost` 为 `available` 时不再画「Mining Power 加成 ·
不可用」卡片（那会与事实相反），其余不变。开关打开前不会出现这种情况。

### D. 推广页 L1 卡片只显示「L1 ·」

**根因**：`referral` 页 hero 里五格等宽的等级条，标签是 `Text('L$n · $p%', maxLines: 1, overflow: TextOverflow.clip)`，`softWrap` 默认开。
后端 `boostPercent` 为 `10 / 5 / 3 / 2 / 1`，只有 L1 是两位数；五分之一宽度放不下「L1 · 10%」，文本在空格处软换行，第二行「10%」被
`maxLines: 1` 裁掉，只剩「L1 ·」。其他等级一位数放得下，所以看起来像「选中态（填充 Lime 的 L1）出错」，其实与选中态样式无关，也不是 null 兜底
（`boostPercent` 在 codec 里是必填、按 `^(0|[1-9][0-9]?)$` 校验）。

**修法**：标签改为 `softWrap: false` 单行，外包 `FittedBox(fit: scaleDown, alignment: centerStart)`；放得下时原样，放不下时整体等比缩小，
不再丢字。格子加 key `referral-level-cell-{n}`。

**测试**：`s7_referral_test.dart`「every level cell shows its whole label at 320 / 390」——五格标签都找得到、`didExceedMaxLines == false`、
不越出格子右边界。修前在 320 与 390 两个宽度都以「Expected: false, Actual: true · L1」失败，只有 L1 失败；修后通过。

## Consequences

- build ≥ 31 可安全面对两个开关的任一状态；后端开开关仍须等全部受支持版本 ≥ 31（0166 §C）。
- `ReferralOverview.boost` 变为可空，调用方须判空（已改 `referral_screen.dart`、`mining_controllers.dart` 的认领后拷贝、合同测试）。
- 测试：新增 `test/s249_codec_optional_keys_test.dart`（15 条：三处 `account` 的无键 / 有键 / null / 未知键；referral 的开关关、开、开但未结算、
  null 拒绝、未知键拒绝、链接校验、数值一致性），`s7_referral_test.dart` 增 3 条（L1 标签两宽度、available boost 不画不可用卡）。
- 未接：`GET /v2/referral/invitees`、`/i/{code}` 的 App Link / Universal Link（0162 §5 待办，属 S239 前端批）。
