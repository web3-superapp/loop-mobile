# 0117 · 行情涨跌色 rise / fall；紧凑不可用行与一行来源脚注；全库无 Emoji（S112）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S112-S114-intel-wallet-visual.md` §1），S112-mobile 实施。
基线 `integration/v2` 6864e0c。客户端单侧：不新增依赖、`pubspec.lock` 不变、路由清单不变、`lib/app.dart` 只改
`loopStreamChatConfiguration` 的 `reactionIconResolver`（及其 import）。修订决策 0086 的涨跌配色。S113 / S114
在本单合并后据此替换行情、情报、钱包页面里的大卡与脚注。

## Context

1. 需求方 v3（`LOOP/docs/09` §6.2.1、裁决 D3）：行情涨跌色不受品牌三色限制，默认绿涨红跌。决策 0086 用
   Lime 表示涨、`danger`（#FF6B82）表示跌，于是 Lime 同时是「LOOP」与「涨」，`danger` 同时是「出错」与「跌」。
2. 行情、钱包等数据密集页上，每个读不到的块都是一张 `LoopUnavailableCard`（`LoopEmpty` 条带 + 原因第二行），
   每个块下都有一行 `LoopProvenanceFooter` 和若干「数据诚实」说明卡，占掉的屏幕比数字还多（§0 原则：数字仍带
   来源与时间，但合并成一处弱化显示）。
3. Stream 的 `DefaultReactionIconResolver` 把五个快捷反应画成系统 Emoji，「+」打开 Stream 的整张 Emoji
   目录；Preview 夹具 `chat_content.dart` 的反应键也是 Emoji。产品规则：无 Emoji。

## Decision

### 1. 涨跌色

- `LoopColors` 新增 `rise = #22C55E`、`fall = #EF4444`、`riseSoft = 0x2122C55E`、`fallSoft = 0x21EF4444`。
  类注释改为「Lime 是唯一品牌强调色；行情涨跌用 rise/fall，不计入品牌三色。」
- `LoopPriceMove`：`up → rise`、`down → fall`、`flat / unread → muted`（三色不变）；`ground` 同 `color`
  （Ink 字在 #22C55E 上约 8.9:1、在 #EF4444 上约 4.8:1）；新增 `soft`（13% 底）与 `ofSeries(closes)`
  （首尾收盘价定方向，少于两点为 `unread`）。所有经它取色的位置（行情行色块、Token Card 24h、记录行尾注、
  K 线 OHLC 的 C 值）随之变色。
- `LoopSparkline.color` 改为可空：调用方不传时按 `LoopPriceMove.ofSeries(closes).color`（涨绿、跌红、
  平 / 单点 muted）。组件样例页改传 `LoopPriceMove.up.color`。
- `LoopCandleChart` 只改方向常量：`_upBody = rise`、`_downFill / _downStroke = fall`（0.24 / 0.86）、
  `_upVolume = rise @0.24`、`_downVolume = fall @0.28`。MA7（Lime）与最新价虚线（Lime）不表示方向，保留，
  K 线重做归 S113。
- perp（不在产品导航内的遗留切片）四处 `mint / danger` 涨跌改为 `rise / fall`，免得新规则对它开白名单。
- **红涨绿跌偏好本批不做**：AGENTS 第 23 条把本机持久化限定为 `reduceMotion` 一个布尔值，偏好需要账号资源或
  新的持久化裁决，记待办。

### 2. `LoopInlineUnavailable`（`lib/widgets/loop_inline_states.dart`）

一行最小高 44：15px 图标 + 一句原因（11px、单行省略、地面辅助色）+ 可选「重试」文字按钮（44×44 触控）；
`retrying: true` 时显示「重试中」且不接受点按。不渲染数字、0 或破折号。`LoopUnavailableCard` 保留，
S113 / S114 在数据密集页逐页替换。

### 3. `LoopProvenanceLine`（同文件）

一行 11px 灰字「{prefix · }来源 A · B · 观察于 HH:mm」（本机时区；非当天带 `MM-dd`），来源去重保序，末尾 12px
`info` 图标，整行 44 触控。点按弹 `showLoopSheet`：「数据来源」标题、范围（prefix）、来源、观察于
`yyyy-MM-dd HH:mm`、调用方 `detail` 全文、「知道了」。无来源、无时间、无 prefix 时不渲染。它替代页内多处
`LoopProvenanceFooter` 与「数据诚实」说明卡，仍满足 AGENTS 第 25 条（来源与时间在页面上）。组件只收字符串与
时间，不依赖 `features/chain`；由页面从 `LoopFact` 汇总来源与最早观察时间（同 `MarketFactProvenance` 的口径）。

### 4. 无 Emoji 的表情回应

- `lib/integrations/communication/loop_reactions.dart`：类型 → 字 `like 赞 / haha 哈 / love 心 / wow 哇 /
  sad 叹`，其它类型画「表态」。
- `LoopStreamReactionIconResolver`（同目录）：`defaultReactions` 为上述五个（沿用 Stream 的类型名，已有反应
  含义不变）；`resolve` 返回 `StreamUnicodeEmoji(字)`（Stream 的内容模型是封闭的 Unicode / 图片两种，字作为
  普通文本由平台中文字体排版）；`supportedReactions` 为空集（「+」按它过滤 Stream 的 Emoji 目录，空集即不给出
  任何 Emoji）；`emojiCode` 恒为 `null`（LOOP 发出的反应不带 Emoji 码）。
- `loopStreamChatConfiguration.reactionIconResolver = const LoopStreamReactionIconResolver()`。
- `_loopStreamComponentBuilders.reactionPicker = loopStreamReactionPickerBuilder`：长按弹层表情条只画五个字，
  不画「+」（`supportedReactions` 非空时回到 Stream 默认 picker）。
- Preview 夹具 `ChatContent.groupMessages` 的反应键改为类型名（`like / wow / sad / love / haha`），
  `ChatMessageTile` 经 `loopReactionLabel` 画字（「赞 18」）。

### 5. harness

- `check_spot_candle_contract`：K 线必需串改为 `_upBody = LoopColors.rise`、`_downFill / _downStroke /
  _downVolume = LoopColors.fall.withValues`、`_upVolume = LoopColors.rise.withValues`；禁止
  `Colors.red / Colors.green / LoopColors.mint / LoopColors.vapor` 不变，新增禁止 `LoopColors.danger` 与旧的
  `Color(0x3DB8FF20)`（去注释后匹配）。
- 新增 `check_price_move_colour_contract`：主题必须发布四个 token 与新注释句、不得再写「Lime is the only
  accent;」；`LoopPriceMove` 的三条映射与 sparkline 默认色被钉住；扫描 `lib/**.dart`（去注释），
  `LoopColors.lime / mint / danger` 前后三行内出现方向线索（`涨`、`跌`、`isUp`、`isDown`、`isPositive`、
  `isNegative`、`rising`、`falling`、`bid`、`ask`、`change24h`、`priceChange`、`LoopPriceMove`）即报错。
  白名单 `PRICE_MOVE_COLOUR_ALLOWLIST`：
  - `lib/core/theme/loop_theme.dart`（调色板本身）；
  - `lib/features/market/market_widgets.dart`（**过渡**：`MarketStatsLine` 的「涨 N」Lime /「跌 N」danger，
    L700 / L705；S113 删除统计行时一并移出白名单）。
- 新增 `check_no_emoji`：扫描 `lib/**.dart` 去注释后的源码（即字符串字面量），命中 Emoji 码位即报错——
  U+1F000–1FAFF、区旗、U+20E3、U+FE0F，以及 BMP 内默认 Emoji 呈现或只会作 Emoji 用的符号（☀–☄、☎、☔☕、
  ⚠⚡、✅、✈–✍、✨、❌、❤ 等）；箭头、✓、✦、●、▲▼ 是文本符号，不算。白名单为空。同时钉住 resolver 的三条
  规则与 `app.dart` 的注入。
- Chat Preview 夹具指纹 `CHAT_SPOT_SNAPSHOT_SOURCE_FINGERPRINTS["content"]` 随反应键更新。

## 与契约的偏离

| # | 项 | S112 §1 | 本批实现 | 原因 / 后续 |
| --- | --- | --- | --- | --- |
| 1 | 反应图标 | `LoopIcon` 的 like / laugh / heart / wow / sad，没有的用字 | 五个全部用字「赞 / 哈 / 心 / 哇 / 叹」 | 现有 65 个 sprite 里没有拇指、笑脸、心形、惊讶、难过任何一个；混用图标与字会让一排五个大小、基线都不一致。补图标后只改 `resolve` 一处 |
| 2 | 「+」更多表情 | 未写 | 长按弹层的表情条不画「+」：`app.dart` 的 `StreamComponentBuilders.reactionPicker = loopStreamReactionPickerBuilder`，解析器 `supportedReactions` 为空时画 `LoopStreamReactionBar`（Stream 同款外形，五个字，按钮 48px 满足 44 触控），否则回到 Stream 默认 picker | 主代理 2026-10-08 裁定（原「+」打开空表）。表态详情弹层（`reaction_detail_sheet.dart` 的 `StreamEmojiChip.addEmoji`）不是组件工厂可替换的部件，里有一个打开空表的「+」；主代理 2026-10-08 裁定私聊与群聊一致，`_directDisplayProps` 也置 `onReactionTap: (_, _) {}`，详情弹层两处都不弹，「+」不可达 |
| 3 | sparkline 文件位置 | 任务单写 `lib/widgets/loop_sparkline.dart:43` | 实际文件是 `lib/features/market/loop_sparkline.dart`；只改默认色（`color` 可空 + `resolvedColor`）与一行 import | 文件不在 widgets；改动面与 §1 意图一致，不触碰行情页面 |
| 4 | K 线「四个」常量 | `_upBody`、`_down*` | 改五个：多 `_upVolume`（原写死 Lime 24% 的 `0x3DB8FF20`） | 不改则上涨成交量仍是 Lime，与绿色实体不一致 |
| 5 | perp 切片 | 未提 | 四处 `mint / danger` 涨跌改 `rise / fall` | perp 不在导航内，但新规则会扫到；改色比开白名单干净 |
| 6 | Lime 的 MA7 线 / 最新价虚线 | 未提 | 保留 Lime | 不表示方向，属品牌强调；K 线重做在 S113 |
| 7 | `LoopKeyValue.valueUp`（Lime） | 未提 | 不动 | 三个调用方表示「模拟通过 / 价格影响可接受 / 签名事实」，不是涨跌 |

## Consequences

- 决策 0086 中「涨 lime、跌 danger」与「K 线两色：涨 lime、跌 danger」被本决策修订为 rise / fall；0086 的
  其余内容（logo 一处来源、代币页交易所化、契约收紧）不变。决策 0084 §2「涨跌只有两色」仍成立。
- `danger` 只剩错误 / 未读 / 静音等含义；`lime` 只剩品牌强调（买入按钮、群友买入卡、徽标、选中态）。
- 测试：新增 `test/s112_price_tokens_global_components_test.dart`（token 值与 rise/fall 映射、`ofSeries`、
  sparkline 默认色涨 / 跌 / 平与显式色优先、inline unavailable 三态 + 单行省略、provenance line 文案 / 跨日 /
  空 / 弹出与关闭、resolver 五字无 Emoji / 未知类型 /`emojiCode` 空 / `supportedReactions` 空 / app 注入 /
  Preview 夹具键与渲染）；`test/s112_reaction_picker_test.dart`（长按弹层：五个字、无 `add_reaction`、
  按钮 ≥ 44；对照组用 Stream 默认解析器时「+」存在；`app.dart` 安装了 builder）。改写的既有测试：`loop_components_test.dart`、`loop_token_card_test.dart`、
  `s82_logos_discover_and_token_test.dart`（期望值 lime/danger → rise/fall，组名同步）、`s16f_probe_test.dart`
  （行情页的亮地面从 Lime 色块变为 rise 色块，测试名改为 `the Market page renders a light change ground`）。
- `docs/00` §4.7 的补句由主代理负责。
- 未验证（需模拟器 / 真机）：长按消息反应条五个字的字号与基线（`StreamUnicodeEmoji` 把 `fontFamily` 钉为
  Apple Color Emoji / Noto Color Emoji，中文走系统回退字体）、绿 / 红在
  OLED 上的观感。
