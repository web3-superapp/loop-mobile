# 0223 · MEME 主页轮播的发射主事件卡也用默认艺术（S265c-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` 654216b2（S265b 合入后）。依据：用户看 build 38：「这第一个 banner 为什么没变呢」。
要求是轮播里**每一张**都用同一套默认艺术背景，只换内容。
不新增依赖与素材，`pubspec.lock` 不变；route manifest 不变；不改 loop-api。

## Context

决策 0220 第 4 条把活动卡改成了氛围 banner，但写明「事件页（发射主事件）保留 232 高」。所以轮播第一张「发射台主事件」卡仍是旧的纯 card 底 `LoopFolioPrimary`：黄 ticker 叠紫阶段词的双色标题，右下角是倒计时戳。
决策 0222 又把活动卡定成永远用默认艺术，于是同一个轮播里出现了两种卡。

## Decision

1. **共用背景组件**：默认艺术抽成 `Launch2BannerBackdrop`（`lib/features/launch2/launch2_launchpad.dart`），内容是：
   - 墙 90 %、紫雾、黄雾、左→右 Ink 渐隐
   - 镀铬手越出卡片右 14 / 下 16，6 s 高光，减少动效时不跑
   - 手上黄皇冠、右上「IN THE LOOP」tag

   标题与紫笔刷抽成 `Launch2BannerTitle`（26 / 700 Chalk，单行省略）。活动卡、事件卡、空发射台三种页都用这两个组件，不再各写一份。
2. **同高**：轮播所有页统一 220 高（`launch2DeskCampaignHeight`），16 圆角，同样越界。`launch2DeskHeight = 232` 删除。选 220 而不是 232，是因为事件卡改为左列文字后，内容在 220 内放得下；文本缩放时高度照旧按比例放大。
3. **事件卡内容**（`Launch2DeskEventFace`）放在左列，位置与活动卡一致（left 20 / top 24 / 宽 186），右侧留给镀铬手：
   - kicker：12，Text2，「发射台 · BSC TESTNET」
   - 标题：ticker，用 `Launch2BannerTitle`（Chalk + 紫笔刷）
   - 副标：阶段词，如「提前购进行中」，14 / 600，`purpleInk`
   - 数据行：12，Text2，最多两行，内容是 `launch2DeskCaption`（已铸 / 已售 / 价格）
   - 倒计时：「剩 38:04」放进左列底部的墨色小胶囊（left 20 / bottom 20，即活动卡黄按钮的位置），**不再放右下角**
4. **交互不变**：整卡可点进项目页，不加按钮。读屏标签不变（`launch2HeroSpokenLabel`）。
5. **空发射台**（无进行中的发射）同样画在默认艺术上：kicker + 「暂无进行中的发射」 + 「NFT 预售开始后会出现在这里」，不可点（同前）。
6. 翻页点、轮播排序与页数上限、倒计时到零重读列表，都不变。
7. 取代 0220 第 4 条的「事件页（发射主事件）保留 232 高」，以及事件卡沿用的 S241b 双色标题与右下角倒计时戳。

## Consequences

- 测试：
  - `test/s184_launch2_campaigns_test.dart` 新增一条：事件页有墙与镀铬手；与活动页同为 220 高；镀铬手同样越界；标题在左列内；倒计时在左列底部，不进镀铬手的范围。
  - `test/s264_meme_home_atmosphere_test.dart` 新增一条：MEME 主页的主事件页用 `Launch2BannerBackdrop`、有镀铬手、220 高，倒计时在左下。
  - `test/s182_launch2_desk_nft_test.dart` 的发射台用例改为读 `Launch2DeskEventFace`（kicker / heading / caption / stamp 不变），双色标题断言改为「Chalk ticker + purpleInk 阶段词」，空发射台断言改为「在 banner 背景上」。
  - `loop_ground_probe` 中渐隐层豁免键的 owner 由 `LoopPressable` 改为 `Launch2BannerBackdrop`。
- 事件卡的数据行由原来的四行说明压到两行。NFT 预售阶段的长说明会被省略号截断，全文在项目页。
- 对比度：文字都落在墙 + Ink 渐隐的左半边（与活动卡同一位置），需真机走查确认 ≥ 4.5:1。
