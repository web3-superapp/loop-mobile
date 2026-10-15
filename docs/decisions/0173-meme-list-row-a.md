# 0173 · MEME「经典」代币列表改为设计稿「列表 A」（S187-1-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 3e49203（含决策 0172）。
来源：主仓库 `docs/35-代币列表与代币页设计稿-2026-10-15.md` 与 `body.html` 的「列表 A」手机框；用户 2026-10-15 裁决「列表用 A」。
「经典」快打满横滑卡（`MemeHeroCard` / `MemeProgressRing`，决策 0122）不动；行情 Tab 的 OKX 代币行（`MarketFomoRow`）不动。
路由、controller、请求路径、签名出口不变；不新增依赖与字体；路由数不变。

## Context

决策 0122 / 0123 把发射台行做成 OKX 报价行：36 圆 logo、ticker 上「市值」、右侧价格 + 1h 涨跌、最右固定 96 × 44 的进度胶囊（`MemeProgressPill`）。
设计稿 35 照 fomo 的信息密度重排：一行说完「市值 + 打满进度 + 交易量 + 上线多久」，进度用原型 `.bar`，已毕业行右侧换成 1h 涨跌。
HTML 结构即规格：`.row` / `.tile-img`（44、r15）/ `.row-t` + `.age`（mono 10 lime）/ `.row-s` / `.row-end .v`（13 粗）/ `.prog`（56 px `.bar` + lime mono 11 %）。
列表需要两个服务端字段 `volume24hUsd1` 与 `createdAt`；loop-api S187-api-a（api 0142）正在补，客户端不能依赖它们一定在。

## Decision

### 1. 行（`meme/meme_widgets.dart` · `MemeTokenCard`，新发 / 热门 / 快打满 / 已毕业 四个子段共用）
- 不再借 `LoopQuoteRow`。按 `.row` 画：左右 16、上下 14、gap 12，底部一条 Line 发丝线（`.row:last-child` 无线，列表给最后一行传 `divider: false`）；
  按下态 card2（`.row:active`）。行高按内容：14 + 44 + 14 = 72（即 `memeCardHeight`），不写别的固定高。
- 左：`MemeLogo` 44（新常量 `memeRowLogoSize`），圆角 `LoopRadius.tileValue`（15）。
- 中：ticker `LoopType.title`；其后上线时长（figure 10 / 600 / lime，key `meme-row-age`），由 `createdAt` 相对页面 `observedAt` 计算
  （新 `memeAgeLabel`：<1 分钟或时钟倒挂 =「刚刚」，<1 小时「n 分钟」，<1 天「n 小时」，其余「n 天」）；`createdAt` 缺则不画。
  副标题 `LoopType.caption` text2：「$1,980 交易量 · 名称」，`volume24hUsd1` 缺则只有名称。
- 右（`.row-end`，最宽为行宽 2/5，超出时市值缩字、原因省略号）：「市值 $x」figure 13 / 700（key `meme-row-cap`）；市值缺时写
  `memeQuoteUnavailableText(quoteUnavailableReason)`（key `meme-row-cap-unavailable`），不画 0。
  下方 `.prog`：56 px `LoopProgressBar`（key `meme-row-progress`，仍有 `LoopMotion.progressFill` 补间、已开始的曲线至少 4 %）+ 6 + lime figure 11 / 600 的短百分比（`memeRingLabel`，key `meme-progress-label`）。
- 已毕业：ticker 后 `LoopBadge('已毕业', kind: launch)`（key `meme-graduated-tag`，代替上线时长）；右下改为 1h 涨跌「+8.20% 1h」figure 11 / 700，`LoopPriceMove` 色（key `meme-change`）；未报告则不画。
- 价格不再出现在行上（在代币页）；读屏文案 = 原 `memeTokenSpokenLabel` + 「交易量 …」+「上线 …」。
- `MemeProgressPill` 只有这一处调用，**类删除**。`loopChangePillRadius` / `loopChangePillSize` 仍由 `LoopChangePill` 使用，保留。
  `memeCardLogoSize` / `memeCardHeight` 仍由 launch2 列表使用，保留。

### 2. 列表（`meme/meme_launchpad.dart`）
- 子段胶囊仍是 `LoopSegBar`（即一排 `LoopSeg(quiet)`），按设计稿去掉四个图标；`MemeListTab.icon` 已无调用方，删除。
- 行把 `page.observedAt` 作为 `now` 传入，列表的上线时长与尾部来源行说的是同一时刻。尾部 `MemeProvenance`、快打满横滑条、空态 / 不可用 / 加载更多不变。
- 骨架：`LoopSkeleton(priceRow)` 改 `leadingSize: memeRowLogoSize`、`leadingRadius: LoopRadius.tileValue`、`trailingPill: false`。
  `LoopSkeleton` 新增两个可选参数 `leadingRadius`（缺省 = 圆）与 `trailingPill`（缺省 true），其它调用方像素不变。

### 3. 数据（`MemeTokenRow` / `LoopV2MemeCodec`）
- `volume24hUsd1` 改为 `Decimal?`、`createdAt` 改为 `DateTime?`，构造参数变为可选。
- codec：两键从必需 `rowKeys` 移入新的 `rowListingKeys`（列表行与详情都作为可选键接收）。契约 = `createdAt` ISO 8601、`volume24hUsd1` 十进制字符串。
  宽松读取：缺键、`null`、格式不对、负的交易量一律为 `null`，**不算坏行**；其余键的严格校验不变。

## Consequences

- 可见变化（待主代理真机验收）：经典四个子段的行从 OKX 报价行变为列表 A 行——logo 36 圆 → 44 r15，ticker 18 → 15，
  右侧不再有价格与固定 96 × 44 胶囊，改为「市值」+ 56 px 进度条；行间多一条 Line 发丝线（设计稿 `.row`，与 0122「OKX 行无线」不同，按设计稿）；子段胶囊无图标。
- 在后端 S187-api-a 上线前，行只显示名称、不显示上线时长；上线后自动出现，无需客户端发版。
- `lib/features/meme/` 未新增 `Radius.circular(字面量)`、v1 色或 v1 部件；`MemeHeroCard` 的 r16 仍是守卫 1 白名单内的唯一字面量。

### 未按清单做的点
- 清单写「列表头上的 `LoopLabel` 保留」：发射台列表头上当前没有 `LoopLabel`（工具行 + 子段胶囊 + 快打满条），本批没有新增，也无可保留。
- 设计稿 `.segs .seg.quiet` 未选中也有 card2 底、选中带 line2 边，与共享 `LoopSeg(quiet)`（未选中透明、选中 line 底）不同；按清单用共享部件，未改 `LoopSeg`。
- 设计稿已毕业行副标题写「外盘 PancakeSwap」；按清单统一为「交易量 · 名称」。
- 字号沿用 figure 档（`LoopTypography.figure`，等宽数字的产品 sans），设计稿的 mono 即此档；未引入 IBM Plex Mono。

## Verification

- `test/s121b_visual_second_pass_test.dart`「发射台 row · 列表 A」：交易中行（ticker、上线 3 小时 lime、「$1,980 交易量 · Frog」、市值 13 / 700、进度条 56 × 6、
  百分比 lime 11 在条右侧、无价格与涨跌、logo 44 r15、行高 72 + 1 发丝线）；打满行填充 56 px；已毕业行（launch 徽标、无时长与进度条、+8.20% 1h rise 色、未报告不画）；
  缺字段（无交易量 / 时长 / 市值时只画名称与原因、不抛异常；`null` 与格式错误同样读成 `null`）；`memeAgeLabel` 分钟 / 小时 / 天 / 倒挂；320 宽长 ticker 让位。
- `test/s121c_visual_followups_test.dart`、`test/s117_meme_launchpad_test.dart` 跟随改键（`meme-row-progress`）与文案。`test/support/meme_fixtures.dart` 的 `memeRowJson` 新增 `volume` / `createdAt` / `listingFields`。
- 命令：`bin/dart format`（本批文件）、`bin/flutter analyze`、`python3 scripts/check_harness.py`、上述三个 MEME 测试文件 + `s117_meme_codec_test.dart`；
  另跑过一次全量 `bin/flutter test`（唯一失败为本批新用例的 finder，已修，修后 MEME 文件全过）。未起模拟器、未做真机验收。
