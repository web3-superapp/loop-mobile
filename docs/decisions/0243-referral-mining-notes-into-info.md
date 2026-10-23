# 0243 · 邀请中心 / 我的邀请 / 我的挖矿：说明收进 ⓘ，绑定按钮禁用态一行说明（S293-mobile）

## Status

Accepted 2026-10-23。基线 `integration/v2` b7621b73（S292 合入后）。主代理下单 S293-mobile。
不新增依赖，`pubspec.lock` 不变。不改 loop-api、不改 /v2 契约。**路由清单不变（114）**，`routes-manifest.json` / `route_manifest.dart` 未动。

## Context

需求方 2026-10-23《LOOP 产品问题整理》第 01 / 03 / 04 / 05 条（截图圈出）：邀请中心、情报 · 算力榜顶部「我的邀请」、我的挖矿三处的说明文字常驻页面；邀请中心「我的邀请人」块在窗口开着时堆了窗口卡、按钮、规则行三层。用户裁决全部照做。
做法照决策 0236（S278）：解释与出处收进 ⓘ，点开才看；fail-closed 的不可用 / 读不到状态行保留。

## Decision

### 01 · 邀请中心（`lib/features/mining/referral_screen.dart` `ReferralScreen`）

页面主体删去：

- 顶部 kicker「邀请好友 · 只计入挖矿算力」（标题只留「邀请中心」）。
- 邀请码卡 caption「N 个有效关系 · N 个待验证；邀请加成只计入挖矿算力。」——有效 / 待验证总数进 ⓘ。
- 「我的邀请」三格下的「有效成员截至 … UTC：被邀请人本人在这一小时有算力。」与「还没有结算过的小时，有效成员暂为 0。」两种说明行（进 ⓘ「有效成员」）。`stats` 缺席时的「邀请统计还没有开放，开放后显示在这里。」是不可用态，保留。
- 「关系深度如何计算」整段（L1–L5 行 + 「『有效』只统计已验证的关系…」）——进 ⓘ。
- 「推广榜」整段（`LoopLabel('推广榜')` + `IntelReferralBoardSection`）；下拉刷新不再重读推广榜。情报 · 算力榜里的推广榜不动。
- 规则行「生效于 … · 最大深度 L5 · 绑定窗口 7 天 · 作用于 miningPower」（`_RulesFooter`，删除）。
- 「返回挖矿」按钮（`ReferralScreen.onOpenMining` 参数一并删除，`app.dart` 同步）与底部「只计入挖矿算力」说明卡。
- 邀请加成卡下「结算小时 … – …；只计入挖矿算力。」去掉后半句，只留结算小时（出处，不是说明）。

右上角已有的 ⓘ（`referral-explain-action`）原来打开一段话加「知道了」按钮的自建 sheet，改为共用的 `showLoopInfoSheet`（sheetKey 不变 `referral-explain-sheet`），内容由新函数 `referralInfoNotes(overview)` 给出，一段一事、各带小标题：

| 小标题 | 正文（有数据时） | 无 overview 时 |
|---|---|---|
| 只计入挖矿算力 | 邀请加成只计入挖矿算力，不是收入、佣金或返佣。 | 同左 |
| 关系怎样成立 | 每个账号只有一个邀请码。分享完成不代表关系成立，还需要验证；「有效」只统计已验证的关系，其余一律显示为待验证，不计入任何加成。<br>当前 N 个有效关系 · M 个待验证。 | 去掉第二行 |
| 关系深度如何计算 | 你直接邀请并已验证的人是 L1，L1 再邀请的人是 L2，依此类推，最深到 L{maximumDepth}。每一级的加成比例以服务端公布的为准，只按该级的有效关系计入。 | 去掉「最深到」 |
| L1 · 加成 10% … L5 · 加成 1%（每级一段，比例为服务端原值） | `referralLevelDescription` 一句<br>各验证状态计数（如「待绑定钱包 2 · 待挖矿生效 1 …」） | 不出现 |
| 有效成员 | 被邀请人本人在最近一个结算小时有算力，才算有效成员。<br>当前数字截至 {validAsOf}。／还没有结算过的小时，有效成员暂为 0。 | 只留第一句；`stats` 缺席时也只留第一句 |
| 绑定邀请码 | 被邀请人激活 LOOP ID 后 {claimWindowDays} 天内可以绑定；一个账号只能绑定一次，关系锁定后不可更换。不能绑定自己的邀请码，也不能绑定自己下级的邀请码。<br>（未绑定且窗口开着时）本账号的绑定窗口截止 {closesAt}。 | 「…后的绑定窗口内可以绑定」，不写天数 |
| 规则版本 | 生效于 {effectiveAt} · 最大深度 L{n} · 绑定窗口 {d} 天 · 作用于挖矿算力（`appliesTo` 为 `miningPower` 时译成「挖矿算力」，其它值原样） | 不出现 |

### 03 · 情报 · 算力榜「我的邀请」（同文件 `ReferralCenterCard`）

- 删邀请码块下「邀请加成只计入挖矿算力，不是收入、佣金或返佣。」与三格下「有效成员截至…」（两处共用 `_InviteStats`，01 的改动同时生效）。
- 「我的邀请」标题改为 `LoopInfoLabel`，行尾 ⓘ（`intel-referral-info`，sheet `intel-referral-info-sheet`），内容即上表同一份 `referralInfoNotes`。
- 「打开邀请中心」入口保留。

### 04 · 我的挖矿（`lib/features/mining/mining_screen.dart`）

- 页面主体删去「公式版本」整段（`MiningFormulaBlock`：挖矿公式 / 已生效 行 + 详情折叠）、「算力快照」整段（`_SnapshotBlock`，删除）、「不做本地估算」说明卡（`mining-truth-notice`）。「Increase Power」两行、hero 下的出处行 / 过期提示 / 构成 / 持有即算力 / 邀请加成卡不动。
- 右上角 ⓘ（`mining-rules-action`）原来直接跳挖矿规则页，改为打开「挖矿说明」sheet（`mining-info-sheet`，新函数 `miningInfoNotes(summary)`，读页面同一份摘要），末尾一个「查看挖矿规则」按钮（`mining-info-open-rules`，先关 sheet 再跳 `mining-rules`，规则页入口不丢）。`showLoopInfoSheet` 为此加了可选 `footer`。
  - **公式版本**：已生效「挖矿公式已生效（当前算力公式）· 生效于 {effectiveAt}」+ 换行「已生效的公式版本 {configVersion}」（括号只在开发基线时出现）；待批准且有版本「挖矿公式待批准。批准后，页面上的数字才会有来源。」+ 换行「待批准的公式版本 {v}」；没有批准版本「挖矿公式还没有批准的版本：{服务端原因}」（check_harness 锁定的句子保留在本文件）；摘要未读到「还没有读到挖矿摘要，公式版本读到之后显示在这里。」
    版本标识单独一行、不嵌进中文句子，与原「详情」折叠里 `'$detail $identifier'` 的拼法相同（check_harness「user-visible copy」规则：标识只在点开后出现，不进句子）；ⓘ 与折叠一样是点开才见。
  - **最近一次算力快照**：「区块 {n} · {computedAt} · 这是算出算力的时间」；快照不可用时沿用原口径 `miningSnapshotAbsenceMessage` + `miningSnapshotAbsenceReason`（「还没有算力快照 / 还没有完整的算力快照 / 暂时读不到算力快照」+ 原因）；摘要未读到「还没有读到算力快照。」
  - **不做本地估算**：已生效「LOOP 不会在这台设备上累计积分或估算收益，页面上的数字都来自最近一次算力快照。」；其它「LOOP 不会在这台设备上累计积分或估算收益。读不到不等于『算力为零』。」

### 05 · 我的邀请人（同文件 `_BindingBlock`）

- 一个「绑定邀请码」按钮（`referral-claim`）始终在。未绑定且窗口开着：只有这个按钮，可点（提交中禁用）；「绑定窗口开放中 / 截止 … 一个账号只能绑定一次 …」卡与规则行删除，内容在 ⓘ。
- 不能绑定时按钮禁用，下面**一行**短说明（captionSm、辅助墨色，最多两行折行）：
  - 窗口已关：「绑定窗口已于 {closesAt} 关闭」（key `referral-claim-closed`）
  - 已绑定：「已绑定邀请人，关系锁定后不能更换」（key `referral-claim-bound-note`）；已绑定邀请人行（深度 / 验证状态 / 锁定时间，不含身份）照旧显示在按钮上方。接口不下发邀请人身份，所以不写「已绑定 @xxx」。
  - 账号还没有窗口（`ReferralClaimWindowUnavailable`）：「还不能绑定：{服务端原因}」（key `referral-claim-unavailable`）。
- 邀请链接带码进来而不能绑定时的 Toast、绑定弹层 `_ClaimForm`、格式错 / 失败 / 成功三张提示卡均不变。

## Consequences

- 测试：新增 `test/s293_referral_mining_notes_test.dart`（7 例：邀请中心主体不含任何被删句子、开窗时只有可点按钮；ⓘ 七类小标题与数据；读取失败时错误态照常、ⓘ 只说规则不编数字；窗口已关 / 已绑定的禁用按钮与一行说明；情报卡无两句、ⓘ 有；我的挖矿主体无三段、ⓘ 有三段；摘要读不到时 ⓘ 的未读口径）。
  既有用例迁移：`s7_referral_test.dart`（层级计数与「不是收入…」改为点开 ⓘ 断言；三种不能绑定的状态改为断言按钮禁用 + 一行说明）、`s7_mining_pages_test.dart`（公式版本 / 快照四例改为点开 ⓘ 断言，并覆盖「查看挖矿规则」跳转）、`s59_mining_structure_test.dart`（我的挖矿标签只剩 Power Composition / Increase Power）、`s197_4_type_test.dart`（邀请说明 sheet 的正文字号断言换成「只计入挖矿算力」一段）。
- 页面变矮：邀请中心少了深度、推广榜、窗口卡、规则行、返回按钮、说明卡；我的挖矿少了三段。
- 真机需确认：两处 ⓘ sheet 的长度（邀请说明含五级共 11 段，sheet 可滚动）；禁用按钮与一行说明的对比度。

## 验收补丁 S293b

- 邀请中心邀请码卡：删 caption 后 `LoopFolioPrimary`（record）仍按 178 最小高度撑开，邀请码行下留空；`LoopFolioPrimary` 加可选 `minHeight`（默认不变），邀请中心传 0，卡片在邀请码行下一个卡片内边距（16）后直接接分隔线与 L1–L5 分级。
- ⓘ「邀请说明」L1–L5 每级只留标题「Ln · 加成 x%」与一句描述（`referralLevelDescription` 去掉重复的「Ln ·」前缀），删掉每级的状态计数行；总数仍在「关系怎样成立」。
