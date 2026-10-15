# 0187 · 广场「动态」改为紧凑帖 + 报价胶囊（S198）

## Status

Accepted 2026-10-15。基线 `integration/v2` 449ad64。来源：主仓库 `docs/35-代币列表与代币页设计稿-2026-10-15/body4.html`
「动态 A · 紧凑帖 + 报价胶囊」手机框（HTML 结构即规格），用户 TF 23 反馈：一条帖子占 180 dp 却只有一行信息、价格折行、
涨跌写 0.00% 没有信息。修订 0177 §3 的帖子版式；数据层、能力位、段序（0181）不变；不新增依赖、字体与图标。

## Context

0177 的帖子：头像 36、内距 14、报价行在正文之上且价格 `Flexible` 会折行；事件帖（买入 / 领奖 / 毕业）后端不给正文，
只剩徽标；点赞键 44 高。结果一条事件帖约 180 dp，只有徽标和一行数字。

## Decision

### 1. 顶部
- 不变：段标题行；下一行 `MarketTabBar` 全球 / 已关注，右侧次级 `LoopButton('发帖', icon: plus)` 同一行。

### 2. 帖子行 `SquareFeedPostRow`（`.feed-post`）
- 内距 12 / 16 / 4、底部 `LoopColors.line`；头行高 32：头像 32 圆（官方帖 card2 圆底 + 18 品牌标）+ 名字
  `LoopTypography.title(13)` 单行省略 + 徽标 + 右侧相对时间（figure 11 text3）。其下所有行缩进 40（头像 + 8）。
- 顺序照设计稿：正文 → 报价胶囊 → ♡。
- 正文：opinion / system 用帖子原文；事件帖用 `squareFeedPostSentence` 生成一句（§3）。system 帖仍在
  `LoopRecordCard` 里、超三行折叠、lime「展开」。
- 报价胶囊 `SquareFeedQuoteCapsule`：`Material(LoopColors.card, LoopRadius.control)`，高 40（`capsuleHeight`），
  内距 10：`MemeLogo` 24 圆 + ticker（title 13，单行省略）+ 「市值 $x」（caption 11 text2，单行省略）+ 右侧价格
  （figure 13，`loopFoldedZerosPrice(memePriceLabel(...))` 折零，`maxLines: 1`、`softWrap: false`）+ 1 h 涨跌（figure 11，
  `LoopPriceMove` 色）。价格与涨跌先排、不折行；手机过窄时整组按比例缩小（`FittedBox.scaleDown`），ticker 与说明先省略。
  点胶囊进 MEME 代币页或 MEME v2 实例页（同 0177）。
- null 不画：价格为 null 不画价格段，涨跌为 null **或恰为 0** 不画涨跌段（`squareFeedQuoteMove`），市值为 null 不画说明；
  不写 0、不写 0.00%。没有代币就没有胶囊。
- 底部 ♡：sprite `react-heart` + 计数，键高 32（原 44），横向内距 8；评论数后端没有字段，**不画**。
- 量出来的高度（测试字体）：纯文字一行帖 107 dp，一行正文 + 胶囊 155 dp（原约 180 dp 且只有一行信息）。

### 3. 事件帖文案（纯函数 `squareFeedPostSentence`，后端只给 kind + event）
- 有原文就用原文。
- graduation：「X 打满内盘，官方池已建，回购开始。」（无代币名时「这个代币打满内盘，…」）。
- claim：「在 X 第 N 轮领到 N USD1，权重 x%。」；缺哪个事实就省掉哪段（无轮次「在 X 领到 …」、无金额「…领到奖励」、
  无权重不写权重），从不写 0。
- buy：「买入 N USD1 的 X。」；无金额返回 null（不画正文）。
- 金额 / 权重用 `loopFormatDecimal(maxFractionDigits: 2)`。

### 4. 徽标
- opinion `mute`「观点」、buy `launch`「买入」、claim `up`「领奖」（金额移进正文，徽标不再带金额）、
  graduation `launch`「毕业」、system 仅置顶时 `mute`「置顶」。

### 5. 不变
- 列表尾部来源行（`LoopProvenanceLine(['LOOP'])`）、新鲜度条、骨架、空态、不可用、续读、轮询、发帖弹层、点赞乐观更新与回滚、
  长按删帖，逻辑与键名都不变。

## Consequences

- 可见变化（待主代理真机验收）：动态段每条帖子更矮，事件帖有一句话，报价是一条浅底胶囊，价格不折行，平盘不再写 0.00%。
- 点赞键从 44 高降到 32 高，触控面积小于 44 dp 的建议值；换来帖子高度接近设计稿。

### 未按清单做的点
- 胶囊说明只有「市值 $x」：「内盘 97% / 外盘」需要报价里有曲线阶段与进度，loop-api 0143 的 `token` 只有
  price / change1h / marketCap，本批不画，待后端补字段。
- 评论数：后端没有评论，只画 ♡。
- 高度目标 90–110 dp：纯文字帖 107 dp 达到；带胶囊的帖 155 dp（头 32 + 正文 + 胶囊 40 + ♡ 32 叠起来就超过 110），
  已按设计稿结构压到最小，未再删行。
- 涨跌恰为 0 也不画：按 TF 23「0.00% 无信息」的反馈处理，属于对「null 不画」的扩展。
- `loopFoldedZerosPrice` 只折 4 个及以上的前导零（共用函数的既有规则），设计稿的 `$0.0₃6697` 在本实现里写作 `$0.0006697`。

## Verification

- `bin/dart format --set-exit-if-changed lib test` 0 改动；`bin/flutter analyze` 0；`python3 scripts/check_harness.py` 通过
  （七档字号、涨跌色、无 emoji、feature 圆角只用 `LoopRadius` 等守卫）；`python3 -m unittest discover -s tests` 472 通过。
- `test/s187_4_square_feed_test.dart` 跟改并新增：平盘不画涨跌、帖子高度上限（纯文字 ≤ 110、带胶囊 ≤ 156、胶囊 = 40）、
  320 宽下价格单行折零且无溢出、事件文案函数（毕业 / 领奖全量与缺项 / 买入 / 无金额为 null / 原文优先）、徽标映射。
- 回归：广场、社区、语音房、导航与主题相关 9 个测试文件 231 例通过。未起模拟器、未做真机验收。

## 0191 修订（2026-10-16）

字体落到 0189 阶梯（docs/37 L14），帖子布局与高度目标不变：作者名 `title(13)` → `LoopType.title` 15；胶囊符号 `title(13)` → `caption` 12/600、
「市值」`caption(11)` → `caption` 12 text2、价格 `figure(13)` → `figure` 13、涨跌 `figure(11)` → `figureXs` 11/600；正文 `body(13)` → `bodySm` 13 chalk；
官方回顾标题 `title(13)` → `titleSm` 13/600；♡ 数 `figure(12)`/500 → `figureSm`/500；删除确认说明 `body(14)` → `bodySm` 13。
