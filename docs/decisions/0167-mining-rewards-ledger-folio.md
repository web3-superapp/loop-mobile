# 0167 · 挖矿奖励页回到原型账本语汇，挖矿主卡并入共享部件（S186-2-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 25a7e4c（0165 之上）。docs/33（全 App 对照原型一致性走查）的 H2 / M4 / M5 / M6 / L22 / L23。
只换视觉语汇：数据层（`mining_rewards_models` / controllers / signing / display、`miningMinuteProgress`、结算与领取文案函数、领取流程）不变。
不新增依赖、不新增字体与颜色 token、路由数不变、无新请求路径。

## Context

`mining-rewards`（挖矿奖励）是 docs/33 里唯一整页还停在 0163 语汇的挖矿页：主视觉是自造深灰卡（card 底、r16）+ figureXl lime
滚动数字，汇总是自造一行三格 r16 卡，领取区是自造卡 + figureLg + r999 状态胶囊（成功 / 失败用 rise / fall 绿红，越出 0117），
NFT / Meme 轨道与五级邀请是自造 r16 卡 + 手写事实行。原型 `screens/mining-rewards.html` 是 lime ledger folio 焊在 `.ledger-composite` 上。

挖矿主页一族（mining / mining-assets / mining-community / referral）外观已像原型，但 `MiningCompositePrimary` 是 `LoopLedgerComposite`
的逐像素复制（字面量 `Color(0x1AF3F5EF)`、r24），挖矿主卡的两个按钮（`_HeroAction`，r14）和印章（`_HeroStamp`，r999）是手写的；
referral 有两处 r14 / r12 字面量。

## Decision

### 1. 挖矿奖励页（`mining_rewards_screen.dart`）自上而下

| 块 | 部件 | 说明 |
| --- | --- | --- |
| 主视觉（H2） | `MiningMinuteHero` = `LoopLedgerComposite` + `LoopFolioPrimary(archetype: record, ring: false, margin: zero, squareBottom: true)` | 展示中 / 结算中：`variant: lime`（同屏唯一满 lime）；kicker「上一小时奖励」；heading「{n} LOOP」（ink，单行）；caption「n/60 · 下次 HH:mm」，结算中为「下一小时结算后更新」；stamp 结算中为「结算中」，展示中不画。细节条：`LoopProgressBar`（n/60）+ `LoopCompositeDetailNote`「上一小时 X LOOP」+ 结算时段句。滚动动画保留：folio 新增的 `headingBuilder` 把 heading 包进 `AnimatedSwitcher`（上滑 + 淡入，减少动画时直接换），键 `mining-minute-figure-{n}` 不变。首个小时未结算 / 读不到结算：`variant: quiet` + `headingTone: neutral`，heading 为原标题句，caption 为原原因句，无细节条。 |
| 奖励汇总（M4） | `LoopStatGrid` | 累计已结算 / 累计已领取 / 当前可领取（标签带「LOOP」）；可领取 > 0 用 `LoopStatTone.up`（lime 字），否则 neutral。三格时最后一格半宽（`LoopStatGrid` 本身的规则）。 |
| 领取（M5） | `LoopRecordCard` | 首行「领取状态」+ `LoopBadge`：成功 = up，提交中 / 链上确认中 = mining，失败 / 凭证过期 = down，可领取 = mining，暂无可领取 = mute（`miningClaimStatusBadge`）；「本次可领取」「最低领取」改 `LoopKeyValue`；按钮、说明句、交易链接行不变。领取按钮改非 primary 的 block 按钮（`LoopFlat` 内即深灰宽按钮）：同屏满 lime 只给 folio。 |
| NFT / Meme 轨道、五级邀请（M6） | `LoopRecordCard` + `LoopKeyValue` | 事实行全部为 `LoopKeyValue`（无自身水平内边距）；「上一小时奖励」前一条 `LoopHairline`；退出资产 = `LoopKeyValue(label, 已退出（原因）)`。邀请表保留五列表格，表头用 `LoopMono.label`（原型 `.label`），数字 mono 11、合计行 chalk 粗。 |

领取记录、来源行、状态块不变。删掉 `_SummaryCell`、`_StatusPill`、`_FactRow`、`_ExcludedRow` 与旧 `_MinuteFigure` 的 figureXl 文本。

### 2. 挖矿主卡一族（L22 / L23）
- `MiningCompositePrimary` 删除，五处调用（算力明细、算力榜、社区挖矿、社区面板、邀请）改用 `LoopLedgerComposite`（默认 graphite、外边距、细节内边距、
  顶线 chalk 10 % 与旧件逐值相同，无需新参数）。唯一差别：`detail` 为空时共享件不画细节条（旧件会画一条空的），现有调用都不传空。
- `MiningSummaryHero` 的两个按钮改 `LoopButton`：「领取奖励 / 查看奖励」= `primary: true, tone: LoopButtonTone.ink`（满 lime 卡上 ink 底 chalk 字），
  「算力明细」= 次级 `LoopButton`（在 lime 底上从 `LoopGround` 推出 ink 10 % 底、ink 22 % 边、ink 字，与旧描边一致）。
  高度随 `LoopButton` 为 53（旧 44），字重 700（旧 800）。
- 印章改 `LoopFolioStamp`（从 `LoopFolioPrimary` 抽出的公共 `.folio-stamp`），键 `mining-summary-hero-stamp` 不变。
- referral：L 级格 r14 → `LoopRadius.control`（16），L 级方块 r12 → `LoopRadius.inner`（12）。

### 3. 公共部件改动（全部可选，缺省时像素不变）
- `LoopFolioPrimary.headingBuilder`：拿到 folio 原样画出的 heading `Text`，返回替代它的组件（本页用来套滚动动画）。
- `LoopFolioStamp`：folio 的印章抽成公共部件，folio 自己也用它画；颜色缺省 = 所在底色的 ink × 68 %。
- `LoopButtonTone.ink`：primary 时 ink 实底、chalk 字、r14（同 brass 的平涂画法）。

## Consequences

- 挖矿奖励页与挖矿主页、发射台同一部件家族：一张 lime 账本 folio + composite，下面是 stat-grid、record-card、key-value、badge；
  `mining_rewards/` 与 `mining/` 目录内不再有 `Radius.circular(字面量)`、`BorderRadius.circular`、`Color(0x…)` 字面量，也没有 `rise / fall /
  warning / danger / chat / market / elevated`。
- 领取按钮从满 lime 降为深灰宽按钮；可领取的强调只剩汇总里的 lime 字与状态 badge。
- `LoopLedgerComposite` 成为全仓唯一的 composite 实现；以后要改顶线或圆角只改一处。
- 新加的三个公共参数 / 部件不影响现有调用（缺省像素不变）。

## 与原型 `mining-rewards.html` 的差异
- 原型 folio 是「CLAIMABLE REWARD / 164.8 LOOP / 可领取」；本页按需求方 §8.1 的分钟展示保留「上一小时奖励」与按分钟增长的数字，可领取放在下面的汇总与领取区。
- 原型细节条是「今日预估 / 累计已挖」两格；本页细节条是分钟进度条与上一小时合计（汇总三格另在 stat-grid）。
- 原型的结算公式 `.notice`、领取记录 `.row` 方块未在本批改动（领取记录已是 `LoopRecordGroup`）。
- 展示中不画印章（现有状态文案只有「结算中」，不编新词）。

## 测试
`test/s138_mining_rewards_test.dart`：新增「0167 the page speaks the ledger folio family」（composite + lime record folio、kicker / heading / caption 格式 / 无印章、
进度条在 composite 内、同屏满 lime folio 只有一张且领取按钮非 primary、stat-grid 三值与可领取 up tone、领取区 record-card + 一个 badge + 两个 key-value、
三块轨道 / 邀请为 record-card、奖励与退出行为 key-value、全页 Text 无 rise / fall 色）与「0167 awaiting and unavailable are quiet, neutral folios」；
状态五态测试补 badge kind 断言；结算中改为断言 folio stamp「结算中」与 caption；等待原因改读 folio caption；最低领取改读 key-value。
`test/s59_mining_structure_test.dart`：挖矿主卡两个按钮为 `LoopButton`（ink tone primary / 次级），印章为 `LoopFolioStamp`。
