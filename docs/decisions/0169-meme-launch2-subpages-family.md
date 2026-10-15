# 0169 · MEME 与发射子页回到原型部件家族（S186-4-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` f9b271f（含 S186-1 / 0166、S186-2 / 0167）。只换视觉语汇：路由、状态合同、
请求路径、controller、轮询、签名出口、领取 / 交易 / 部署流程的行为与文案（除空态标题外）不变。不新增依赖、字体与颜色 token，
路由数不变。来源：主仓库 `docs/33-全App对照原型一致性走查-2026-10-15.md` §2 条目 M9、M10、L8、L9、L10、L11。
用户裁决：M1「经典」快打满横滑卡（`MemeHeroCard` / `MemeProgressRing`）保留 0122 原样，本批不动。

## Context

0164 / 0166 把发射台、铸造页、项目页换成冻结原型家族（docs/33 §1 五条：一张 folio、`LoopLabel` + 行容器、
三种胶囊、颜色字号圆角走 token、同屏一个满 lime）。从它们进入的子页仍是旧语汇：外盘奖励每轮与「本轮状态」是散的
key/value 行、空态是旧 `LoopEmpty` 条；我的项目的状态是自造 r999 胶囊（被拒用 fall 红）、行是自拼 `LoopPressable`；
MEME 代币页的内盘进度是自造 8 px 轨道，交易面板的 25/50/75/100 是描边 r999 pill、拒绝原因是 warning 黄字；
MEME 行情分段空态是旧 `LoopEmpty`；MEME 创建与 v2 发射创建 / 项目状态页各自手写了步进点与里程碑轨道（圆角字面量 4 / 2 / 12、
失败段 danger 粉红）；部署页失败事件点 danger 粉红。

## Decision

### 1. 外盘奖励与本轮状态（M9）
- `launch2_dynamic_rewards_screen.dart` 每轮：`Launch2SectionLabel('第 N 轮', trailing: LoopBadge)`（即 `LoopLabel`）
  下接一张 `LoopRecordCard`（key `launch2-dyn-round-{id}-card`），起止 / 权重 / 本轮奖金 / 可领 / 已领五行 `LoopKeyValue`
  （行 key 不变，card 内 vertical 6 内边距）放进卡里；失败行与「领取」按钮在卡下。
- 三处旧 `LoopEmpty`（路由无标识 / 没有外盘奖励 / 没有钱包）改 `LoopEmptyState(compact)`，key 不变；
  原 `message` 成为 title、`reason` 成为 message；插图分别 launchpad / history / profile。
- `launch2_dynamic_pool_widgets.dart`「本轮状态」：标签不变，未激活说明行与全部 `LoopKeyValue` 放进一张
  `LoopRecordCard`（key `launch2-dyn-round-card`），来源行在卡下。

### 2. 我的项目（M10）
- `Launch2StatusPill` 改为 `LoopBadge`（key `launch2-status-{wireName}` 不变）：active → `launch`，
  rejected / deployFailed → `down`，其余 → `mute`。不再有 r999、最小宽 72、fall 红；被拒由文字与页内 notice 说明。
- `launch2_projects_screen.dart`：`ListView.builder` + `_ProjectRow(LoopPressable)` 改为 `ListView` 内一个
  `LoopRecordGroup`，每行 `LoopRecordRow(leading: MemeLogo 36, title, subtitle, trailingBadge: Launch2StatusPill)`，
  行 key `launch2-project-row-{id}` 与 semantics 文案不变，点按仍先 `LoopHaptics.selection()` 再按 0142 续接；
  `LoopLoadMoreFooter` 在组下。列表不再惰性构建（项目方自己的项目数很小，分页仍由 footer 负责）。

### 3. MEME 代币页与交易面板（L8）
- `MemeProgressBar` 删除；代币页内盘进度改 `LoopProgressBar`（6 px，key `meme-token-progress-bar`，
  semantics「内盘进度 N%」，已毕业 = 1）。
- 交易面板 `_FillChip` 删除，25 / 50 / 75 / 100 改 `LoopSeg(block, selected: false)`（key `meme-trade-fill-N` 不变）；
  是动作不是选择，永不显示选中。
- `meme-trade-blocking` 由 warning 黄字改 `LoopNotice(icon: warn, tone: warn)`（limeSoft 底）。

### 4. MEME 行情空态（L9）
`meme_launchpad.dart` 行情分段 `meme-market-empty` 改 `LoopEmptyState(chartEmpty, '还没有 MEME 资产', compact)`，
原句作 message。

### 5. 共享步进部件（L10）
- 新增 `lib/widgets/loop_step_track.dart` · `LoopStepTrack`：
  - `.dots(labels, current)`：到达的步 lime 点、当前步 22 px lime 条、其余 line2，旁边「N / M · 名称」；
    MEME 创建（key `meme-create-step-N`）与 v2 发射创建（key `launch2-create-step-N`）共用。
  - `.milestones(labels, current, reachedCurrent, failed, semanticLabel)`：等宽 4 px 段 + 段名；
    项目状态页（key `launch2-milestones-{wireName}`）使用。失败的当前段为 chalk（原 danger 粉红），失败语义交页内 notice。
  - 圆角只用 `LoopRadius.pill`，间距走 `LoopSpacing`；不再有 4 / 2 字面量。
- `Launch2StepDots`、`Launch2MilestoneTrack`、`meme_create_screen.dart` 的 `_StepDots` 删除。
- `Launch2FixedRecipient` 容器 `Radius.circular(12)` 改 `LoopRadius.inner`。

### 6. 部署页失败点（L11）
`launch2_deployment_screen.dart` 事件点：失败 chalk、其余 lime（key `launch2-event-dot-failed|done`）；
失败原因仍由页顶 `LoopNotice`（`launch2-deployment-failure-{code}`）与事件下的说明行表达。

### 7. 收尾
- v2 发射创建页「发射需要一张方形头像」提示由 danger 改 chalk。
- `MemeProgressPill` 的 r10 与 `LoopChangePill` 同形：新增 `loopChangePillRadius`（`loop_quote_row.dart`）两者共用，
  外观不变；其 4 px 条圆角改 `LoopRadius.pill`。
- 范围检查：`lib/features/launch2/creator/` 与 `lib/features/meme/` 内不再有 `Radius.circular(字面量)` 与
  `LoopColors.warning / danger / chat / market / elevated`，唯一例外是 M1 的 `MemeHeroCard`（r16，按用户裁决不动）。

## Consequences

- 外盘奖励、我的项目、项目状态、部署进度、MEME 代币页与创建流与发射台 / 项目页同一部件家族；状态徽标只剩 `LoopBadge`，
  进度只剩 `LoopProgressBar` 与 `LoopStepTrack`，空态只用 `LoopEmptyState`。
- 两套创建流的步进点是一个部件，以后改步进样式只改 `loop_step_track.dart`。
- 代币页内盘进度条由 8 px 变 6 px，且不再有填充动画（`LoopProgressBar` 无动画）；列表进度胶囊动画不变。
- 被拒 / 部署失败不再以红色出现；它们的语义完全由文字、徽标与 `LoopNotice` 承担。
- `meme_token_screen.dart` 另有两处旧 `LoopEmpty`（230、1521）不在 docs/33 本批条目内，未动。

## Verification

- `test/s168_launch2_dynamic_pool_test.dart`：本轮状态的奖金池与未激活说明行在 `launch2-dyn-round-card`
  （`LoopRecordCard`）内；没有外盘奖励 / 无效路由为 `LoopEmptyState` 且页面无 `LoopEmpty`；「第 3 轮」在 `LoopLabel` 内，
  每轮 `launch2-dyn-round-{id}-card` 是 `LoopRecordCard` 并包含该轮「可领」行。
- `test/s135_launch2_creator_pages_test.dart`：我的项目状态是 `LoopBadge`（rejected = down、approved = mute、
  active = launch），行是 `LoopRecordRow`、一个 `LoopRecordGroup`；项目状态页 `launch2-milestones-rejected` 是
  `LoopStepTrack`，失败段 chalk、后续段 line2；创建页 `launch2-create-step-1` 是 `LoopStepTrack`；部署失败页失败事件点为 chalk，
  页面所有 `BoxDecoration` 不含 `LoopColors.danger`。
- `test/s117_meme_launchpad_test.dart`：代币页 `meme-token-progress-bar` 为 `LoopProgressBar`（33.27% → 0.3327、高 6；
  已毕业 = 1）；交易面板四个快捷键为 `LoopSeg`（block、未选中、可点）；`meme-trade-blocking` 为 warn `LoopNotice`；
  MEME 创建 `meme-create-step-1` 为 `LoopStepTrack.dots`（3 步）。
- 命令：`bin/dart format`（本批文件）、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
  meme / launch2 相关 `bin/flutter test`（见提交说明）。未跑全量测试、未起模拟器、未做真机验收。
