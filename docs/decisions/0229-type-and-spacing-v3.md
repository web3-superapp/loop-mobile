# 0229 · 字体与间距规范 v3（S269-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` b2e789ac。依据：用户 2026-10-21 18:4x「字体优化一下，有完整字体规范；所有页面的布局结构间隔都要设计一下；信息输出要有主次……目前字体信息多、字体小、没重点。参考 OKX」，同晚 19:35 补发 5 张 OKX 真机截图作校准基准。规范全文在 `LOOP/docs/46-字体与间距规范v3-2026-10-21.md`。

取代 docs/42 附C §2 的字号阶梯与 §3 的间距数值（决策 0210 / 0212 的 16 / 28 / 16、22 / 16 / 15 / 14 / 12）；色板、圆角、组件形态、Banner、禁用项不变。不加字体文件，`pubspec.lock` 与 route manifest 不变。

## Context

v2 的阶梯是页标题 22、区块 16、行标题 15、正文 14、说明 12、按钮 14，且有 162 处 11 号（`captionSm`）、52 处 11 号副数字（`figureXs`）。页边距 16、区块 28，列表行 64–76 且每行一条 1px 线；一行里常堆三个数字（MEME 列表行「进度条 · 62% · 价格」，钱包代币行三行加一行按钮），390 宽下价格被截成「$0.0₄…」。

OKX 真机截图按墨迹反推（1 pt ≈ 2.37 显示 px）：区块标题 ≈ 20、行标题 16–19、正文 16–17（行高 1.5）、副标 / 列名 14、行距 ≈ 68 pt、页边距 16–24、无分割线、每行一个主信息。

## Decision

1. **字阶（`LoopType` 新增 v3 名，旧名改为别名、值换成对应档）**：`title1` 28 / 700（页标题，旧 `headingLg displayXl display displaySm stepTitle`）；`title2` 22 / 700（带返回键或带小字的导航栏标题、卡片大标题、弹层标题，旧 `flatTitle heading`）；`headline` 18 / 700（区块标题，旧 `sectionTitle headingSm`）；`body1` 17 / 600（行主标题，旧 `title titleLg`）；`figure` 17 / 600 tabular（行右侧主数字，旧 `figureMd`）；`figureBody` 16 / 600 tabular（键值表的值、记录行金额，旧 `tickerFigure`）；`body2` 16 / 400 / 1.5（正文，旧 `body bodyLg bodySm message`）；`caption` 14 / 400 Text3（副标，旧 `captionSm kicker eyebrow label titleSm figureSm figureXs`）；`button` 16 / 700（旧 `action`）；`tag` 12 / 600（只给角标）；`figureCompact` 13 / 700（只给 Token Card 窄格）。Anton 40 / 30 与 `keyFigure` 32、`figureXl` 28、`statFigure` 28、`figureLg` 22 保留。除 `tag` 外无 13 以下的字。
2. **间距（`LoopSpacing`）**：`page` 20；`section`/`sectionTop` 36；`headingGap`/`sectionBottom` 16；`group` 24；`card` 16；新增 `rowGap` 12、`rowMin` 72、`rowMinWithSub` 80、`bannerGap` 28、`segmentGap` 16。30 个文件里写死的 16 页边距 `margin` 换成 `LoopSpacing.page`。
3. **分割线二选一：不画**。`LoopAtmoBoard` 默认 `dividers: false`，`LoopRecordRow` 去掉首行上线与每行下线并取 72 / 80 最小行高，情报榜单行、钱包代币行去掉底线。
4. **共享件**：`LoopTopbar` 无返回键时标题 title1，有返回键或带 kicker / 副标时 title2；分段页（广场、情报）的段名 title1、首字落在 20 页边距；`LoopLabel` / `LoopSprayHeading` 上 36 下 16；`LoopKeyValue` 标签 body2 Text2、值 figureBody；`LoopQuoteRow` 副行 caption、行高 80；`LoopRecordRow` 右侧数字放不下时缩放不溢出；Stream 收件箱行 `channelListItemTheme` 取 body1 / body2 Text2 / caption。
5. **逐页主次**（详见 docs/46 §5）：MEME 列表行价格移到右侧作主数字、阶段胶囊在其下、左副行只留进度条与百分比；项目页内盘进度卡只留「0%」一个数，供应量移到条下说明；最新成交行左「买入 / 卖出 + 名字」、右「USD1 主数字 + MEME 副数字」；钱包代币行从三行收成两行（24h 美元变动额删去，涨跌百分比并入估值行）；情报榜单的权重徽章并入副行、表头去中点串与大写；广场社区副标、情报牌说明去中点串。

## Consequences

- 全量 `flutter test` 5592 通过（9 跳过：基线 3 + S269 截图 6，截图只在 `--dart-define=LOOP_SHOTS=true` 下跑）；约 40 个测试文件里断言具体字号 / 行高 / 页边距的按新值更新，几个在 800×600 或 390 宽下因字变大需要滚动的测试补了 `ensureVisible` 或改了测试窗口。
- `check_harness` 中 `chat_preview_message_requests_test.dart` 的已审指纹更新一次：该测试在 `ensureVisible` 后未 pump 就点按钮，v3 字号让按钮落出首屏后暴露；只补了 `pumpAndSettle()`。待主代理确认。
- `python3 -m unittest` 的 `test_rejects_ungated_meme_tab` 在基线即失败（`meme_screen.dart` 里早已没有它要改写的 `if (launch2SurfaceVisible(ref))` 字样），与本批无关。
- 未改：`SquareFeedPostRow` 头部一行（S268 在改）；K 线画布坐标 7–9 px（画布豁免）；`LoopProvenanceLine`、Banner 底行等其余中点串；遗留的 v1 页面（IDO Launch、挖矿二级页等）只随 token 变化，没有逐页核主次。
- 待定：钱包代币行的「发送 / 兑换」小胶囊（决策 0188）建议删除，本批未删。
