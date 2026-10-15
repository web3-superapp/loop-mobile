# 0166 · 发射项目页改为原型 folio 家族（S186-1-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 25a7e4c（0165 之上）。只换视觉语汇：路由、状态合同、请求路径、
controller、轮询、签名出口、两块交易面板的行为与文案不变。不新增依赖、不新增字体与颜色 token，路由数不变（113）。
来源：主仓库 `docs/33-全App对照原型一致性走查-2026-10-15.md` §4 批次 S186-1（条目 H1、M7、M8、L32、L33）。

## Context

0164 把发射台与共识勋章铸造页换成了冻结原型的部件家族（quiet 账本卡、`.label`、`.record-card` + `.bar`、`.kv`），
但从发射台点进去的项目页 `launch2-instance` 仍是被 0164 推翻的 0163 语汇：`_Identity` 行 + `_StageBar` 深灰 card
（`Radius.circular(16)` 字面量、状态点、20 号粗倒计时）、`_SectionHeading` 20 / 700 自造标题（0149 的
`launch2PanelHeadingStyle`，两块交易面板也用它）、`_CurveBlock` / `_NftSaleBlock` 的 figureXl 大数字、
`LoopColors.warning` 黄色警示行、Brass 的「铸造页」链接（0164 起 Brass 只在铸造页）、阶段胶囊暂停态黄字。
docs/33 §1 家族特征五条要求：每页顶部至多一张 folio；分组只用 `LoopLabel` + 行容器；颜色只走 ink / lime / chalk 档；
字号走 `LoopType` / `LoopTypography`、圆角走 `LoopRadius`；同屏一个满 lime。

## Decision

### 1. 顶部 folio（H1）
`_Identity` 与 `_StageBar` 删除，合成 `_InstanceFolio` =
`LoopFolioPrimary(variant: quiet, archetype: record, ring: false)`（key `launch2-instance-folio`）：
- kicker = 阶段名（`launch2StageLabel`：即将开售 / NFT 发售中 / 名单生成中 / 已关闭 / 提前购 / 公开内盘 / 已毕业 / 已暂停）。
- heading = ticker（`launch2HeroTicker`，> 8 字符省略，单行），右侧 `trailing` = `MemeLogo`。
  `launch2InstanceHeadingLit`：NFT 发售中 / 提前购 / 公开内盘 / 已毕业 为 lime，其余（等待、关闭、暂停）`headingTone: neutral`。
- caption = `{name} · {阶段句}`（`launch2InstanceFolioCaption`，最多 3 行）：即将开售「100 USD1 / 枚 · 发售 7 天」、
  NFT 发售中「每地址 1 枚 · 已售 N 枚」、提前购「持有人优先」，其余沿用 `launch2StageCaption`（去掉了交给 stamp 的「剩余 / 开售倒计时」字样）。
- footer = 代币短地址（codeSm text2）+ 复制按钮（key 仍为 `launch2-copy-address`，行 key `launch2-identity`）。
- stamp = 倒计时：`Launch2CountdownBuilder` 每秒只重建 folio，前缀即将开售「距开售 」、其它「剩 」
  （`launch2InstanceStampPrefix`）；到点 `reload()` 不变。有倒计时时外面包 `KeyedSubtree(key: launch2-countdown)`，
  无 `nextChangeAt` 时无 stamp。

### 2. 分组标题（H1 / M7）
- `launch2PanelHeadingStyle` 与只为它存在的 `launch2PanelTopGap` 删除。新增 `Launch2SectionLabel`（`launch2_widgets.dart`）：
  就是 `LoopLabel`，可在行尾带一个安静的 `trailing`（徽标 / 税率 / 计数）和一个 (i) `info`。
  (i) 放在 48 dp 的 `MergeSemantics` 盒里（按钮本身仍是 44 的 `LoopIconButton`），满足 Android 点击目标指引；
  有 (i) 时标签上抬 9 px 让字心对齐盒心。
- 项目页：NFT 发售（新增「NFT 发售」标签）、项目 NFT、内盘、发射规则、最新成交、我的外盘成交（尾部「共 N 笔」）、官方池、回购。
- 交易面板：「提前购 / 公开内盘」「外盘交易」改为 `Launch2SectionLabel`，名单徽标 / 官方池徽标与税率放在标签行尾；
  面板正文去掉原 24 的顶距（标签自带 `.label` 的 30）。
- 同一样式还被 `launch2_dynamic_pool_widgets.dart`（「本轮状态」，项目页已毕业阶段）与
  `launch2_dynamic_rewards_screen.dart`（「第 N 轮」）使用，样式删除后两处同样改为 `Launch2SectionLabel`；
  这两处的其余整改（`LoopEmpty` 空态、record-card）属 docs/33 M9 / S186-4，本批不动。

### 3. 曲线块与 NFT 块（H1）
- `_CurveBlock`：`LoopLabel('内盘')` → `LoopStatGrid`（当前价 · USD1，key `launch2-curve-price`；
  有内盘持仓时第二格「我的内盘持仓」key `launch2-curve-holding`，否则「内盘已售」）→ `LoopRecordCard`
  （「内盘进度」+ mono 13 进度 key `launch2-curve-progress`、6 px `LoopProgressBar`、底句「卖满 8 亿 自动建官方池毕业」）。
- `_NftSaleBlock`：`Launch2SectionLabel('项目 NFT', info: …)` → `LoopStatGrid`（价格 / 枚 key `launch2-nft-price`、
  已售 key `launch2-nft-sold`）→ `LoopRecordCard`（key `launch2-nft-progress`：「发售进度 · 已过 N%」+ `LoopProgressBar`
  （发售时间已过比例，与发射台 record-card 同一个 `launch2HeroFuse`）+ 「截止 …」与「铸造页」）→ `LoopKeyValue('我的持有')`。
- figureXl 大数字全部去掉。满 lime 同屏只剩底栏主按钮「购买 NFT」/ 交易确认键。

### 4. 链接与警示色（L32 / M8 / L33）
- 「铸造页」（key `launch2-nft-open`）改为 Text2 文字 + chevron 的 44 dp `LoopPressable`；Brass 只留在铸造页。
  `check_harness.py` 的 `MEDAL_COLOUR_ALLOWLIST` 去掉 `launch2_instance_screen.dart`。
- 新增 `Launch2WarnLine`：warn 图标 lime（原型 `--amber` = lime）+ Text2 文字。替换：`Launch2ActionFailureLine` 的
  黄图标黄字、公开 / 提前购面板的 `launch2-trade-notice` 与 `launch2-trade-exceeds`、外盘面板的 `launch2-pool-notice`、
  `launch2-pool-balance-short` 与超出持仓时的 `launch2-pool-quote-empty`（未超出时仍是 text3 占位句）。key 不变。
- `Launch2StagePill` 暂停态文字由 warning 改 text2（与其它等待阶段同灰）；圆角字面量 10 改 `LoopRadius.inner`。

### 5. 范围说明
launch2 顶层文件（项目页、两块交易面板、widgets、dynamic pool / rewards）内不再有 `Radius.circular(字面量)`、
`LoopColors.warning / danger / chat / market / elevated`、20 号粗自造标题。`lib/features/launch2/creator/`
仍有 `BorderRadius.circular(4 / 2 / 999)`、`Radius.circular(12)` 与 `LoopColors.danger`，它们是 docs/33 的 M10 / L10 / L11，
排在 S186-4（创建流步进点合一、项目列表徽标、部署页失败点），本批不动以免与该批冲突。

## Consequences

- 项目页与发射台、铸造页回到同一部件家族：顶部一张 quiet record folio，分组全是 `.label`，进度全是 6 px `.bar`。
- 阶段与倒计时从深灰条移进 folio stamp；倒计时仍只重绘 folio 本身，页面其它部分不随秒重建。
- 两块交易面板的标题、徽标、税率位置变化，但输入、报价、MAX、确认、锁定与失败行为不变。
- `Launch2SectionLabel` / `Launch2WarnLine` 成为 launch2 的分组标题与警示行的唯一写法。

## Verification

- `test/s182_launch2_desk_nft_test.dart` 新增 group「project page folio (0166)」10 例：nft_sale 顶部唯一
  `LoopFolioPrimary`（quiet / record / 无环 / kicker 阶段 / heading ticker / lime / caption 以名称开头 / stamp「剩 」）且在
  NFT 块之上、「项目 NFT」是 `LoopLabel`、有 `LoopStatGrid`、record-card 里有 `LoopProgressBar`、「铸造页」为 text2；
  public 无 stamp 无倒计时、「内盘」「公开内盘」两个 `LoopLabel`、曲线块有 bar；upcoming / paused heading 为 neutral、
  stamp「距开售 」、kicker「已暂停」；五个阶段（upcoming / nft_sale / public / graduated / paused）页面所有 `Text` 与
  `LoopIcon` 颜色不含 `LoopColors.warning` 与 `LoopColors.brass`、无 20 / 700 文字；暂停阶段胶囊为 text2；
  360 dp 长名称 public 页滚到交易面板无溢出。
- `test/s136_launch2_user_test.dart`：upcoming 例原断言 `launch2-stage-label` 改为 `launch2-instance-folio`；
  `launch2-countdown` 断言保持（folio 外的 KeyedSubtree）。
- `test/s151_ui_polish_test.dart`：删除断言 `launch2PanelHeadingStyle` 20 / 700 与 `launch2PanelTopGap` 的一例（样式已删除）。
- 命令：`bin/dart format --output=none --set-exit-if-changed lib test`、`bin/flutter analyze`、
  `python3 scripts/check_harness.py`、`python3 -m unittest discover -s tests -p 'test_*.py'`、launch2 目录全部测试与全量 `bin/flutter test`。
  未起模拟器、未做真机验收：视觉在设备上的效果仍待主代理验收。
