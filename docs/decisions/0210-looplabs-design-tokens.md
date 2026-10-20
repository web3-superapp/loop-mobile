# 0210 · 设计改版第一阶段：looplabs.meme 设计 Token 与基础组件换皮（S241a-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` 0a37ce8e。依据：需求方 2026-10-19「页面设计按照 https://looplabs.meme/ 设计过一遍」，
`LOOP/docs/42-附A-looplabs设计Token对照-2026-10-19.md`（§8 实施清单），主代理裁决（Tab 栏与 Sheet 也 0 圆角；warning 改橙 `#FF9F1C`；
涨跌红绿保留；区块间距 40；字体 Anton + Arimo + Noto Sans SC，不内嵌 Impact / Arial）。

**本决策推翻 0080（比例字体 = 平台系统无衬线）**，以及 0069 第 2 节之后历次的字号梯子取值（0189 的「每个角色一个台阶」结构保留，台阶数值改写）。
0069 第 1 节（打包 Noto Sans SC 三个静态字重）继续有效。不新增路由（93 条路由清单不变），不新增 Dart 依赖，`pubspec.lock` 不变，不改 loop-api。

## Context

App 现状是深色 + 大圆角 + 单一 Lime 强调 + 系统 UI 字体（0080）；需求方指出「主色还是绿色和黑色，不对」，要求按 looplabs.meme：
黑底 `#09090B`、主强调黄 `#FFD600`、第二强调紫 `#9C36FF`、0 圆角、扁平描边、窄体大写标题。附A 已逐项抓取站点 CSS 取值。
本阶段只换 Token 与共享组件，保证全部页面能编译、能跑、不溢出；逐页版式归 S241b。

## Decision

### 1 · 字体

| 家族 | 文件 | 授权 | 用途 |
| --- | --- | --- | --- |
| `Anton` | `assets/fonts/Anton-Regular.ttf` | SIL OFL 1.1（`OFL-Anton.txt`） | display / heading 两个 band（Impact 的开源替身） |
| `Arimo` | `assets/fonts/Arimo-Regular.ttf`、`Arimo-Bold.ttf` | SIL OFL 1.1（`OFL-Arimo.txt`） | title / body / caption / label / figure（Arial 度量兼容） |
| `Noto Sans SC Display` | 复用 `NotoSansSC-Bold.ttf`（同一资源，不增包体） | SIL OFL 1.1 | Anton 标题里的中文回退：Anton 只有 400，单独注册一个只含 Bold 的家族，让中文标题落在粗体 |
| `Noto Sans SC` | 现有三档 | SIL OFL 1.1 | 正文中文回退 |
| `IBM Plex Mono` | 现有三档 | SIL OFL 1.1 | 地址 / 哈希 / 代码（不变） |

- Arimo 上游 google/fonts 已从 `apache/arimo` 移到 `ofl/arimo`，授权由 Apache 2.0 改为 **SIL OFL 1.1**（2026 版 `OFL.txt`）。
  只有可变字体 `Arimo[wght].ttf`，用 fontTools 4.60.2 `varLib.instancer` 实例化出 400 / 700 两个静态文件。
- 不内嵌 Impact / Arial（Monotype 商用，App 内嵌需另购授权）。
- 金额、价格、百分比仍是**比例字体的等宽数字**（`tabularFigures`），只是比例字体从系统字体换成 Arimo；**没有**改成 IBM Plex Mono。
  0080 起数字就不是 Plex（Plex 只留给地址 / 哈希）；任务单「金额 / 地址仍用 IBM Plex Mono」按「金额不改 Anton、地址仍 Plex」理解。
- Anton 标题**不强制大写**：页面标题、Sheet 标题、folio 标题里大量是用户名 / 社区名 / 代币名，不是我们能改大小写的字。
  `LoopType.caps()` 只用在 Kicker / 分组小标签（`LoopKicker`、`LoopLabel` 非 flat 形态、folio kicker，原本就是大写）。逐页是否把固定英文标题改大写留给 S241b。

### 2 · Token 映射表

| Token | 旧值 | 新值 |
| --- | --- | --- |
| `LoopColors.ink` | `#050604` | `#09090B` |
| `LoopColors.yellow`（新） | — | `#FFD600` |
| `LoopColors.yellowHighlight`（新） | — | `#FFE34D` |
| `LoopColors.yellowSoft`（新） | — | `#FFD600` 13 % |
| `LoopColors.lime` / `limeSoft` / `limeHighlight` / `mint` | `#B8FF20` / 13 % / `#C6FF45` / lime | **别名** → `yellow` / `yellowSoft` / `yellowHighlight` / `yellow` |
| `LoopColors.purple` / `purpleSoft` / `purpleLine`（新） | — | `#9C36FF` / `#9C36FF18` / `#9C36FF70` |
| `LoopColors.input` / `inputLine`（新） | — | `#16111C` / `#3B3045` |
| `LoopColors.chalk` | `#F3F5EF` | `#F2F2F4` |
| `LoopColors.graphite` / `card` / `panel` | `#171A16` / Chalk 6 % / Chalk 5.5 % | `#111114`（三者同值，实色） |
| `LoopColors.card2` / `elevated` | Chalk 10 % / `#1D1E1C` | `#1C1B22` |
| `LoopColors.bg2` | Chalk 2.5 % | `#0E0E12` |
| `LoopColors.line` / `hairline` | Chalk 13 % / `#242523` | `#2A292F` |
| `LoopColors.line2` | Chalk 22 % | `#38333E` |
| `LoopColors.line3`（新） | — | `#4A4754`（描边按钮） |
| `LoopColors.text2` / `text3` / `muted` | Chalk 68 % / 58 % / `#7F897B` | `#B8B4C0` / `#AEACB6` / `#8E8A98` |
| `LoopColors.warning` | `#FFC75F` | `#FF9F1C` |
| `LoopColors.rise` / `fall` / `danger` / `brass` / `copper` | — | 不变 |
| `LoopSpacing.page` / `card` / `section` | 16 / 14 / 30 | 20 / 20 / 40；新增 `headingGap` 18 |
| `LoopRadius.*Value`（shell/card/control/inner/tabBar/bubbleTail/tile/button/tool/badge/wideButton） | 24/20/16/12/23/5/15/14/13/7/26 | 全部 0；`pill` 保留 999（新增别名 `round`），只给头像 / 圆点 / 圆环 |
| `LoopDepth.lift*` / `tabBar` / `tabSelected` | 多层暗投影 | 空列表；边缘色透明；新增 `glowPurple`（blur 24，紫 13 %）、`glowYellow`（blur 17，黄 21 %） |
| `LoopTouch.primaryButton` | 53 | 52 |
| `LoopMotion` | — | 新增 `enter` = `Cubic(.23,1,.32,1)`、`exit`、`transition` 150 ms `Cubic(.4,0,.2,1)`、`cardPress` 180 ms、`buttonLift` 2 |
| ColorScheme | primary lime / secondary chalk / tertiary lime | primary 黄 / secondary 紫 / tertiary 紫；输入框焦点边紫、底 `input`、边 `inputLine` |

字号阶梯（`LoopType`）：

| 台阶 | 旧 | 新 |
| --- | --- | --- |
| `heroDisplay`（新） | — | Anton 56 / 1.0 / −0.035em |
| `displayXl` / `display` / `displaySm` | 系统 28 / 26 / 24 · 600 · 1.2 | Anton 36 / 32 / 28 · 1.1 · −0.02em |
| `statFigure`（新） | — | Anton 30 / 1.1 / −0.025em |
| `stepTitle` / `headingLg` / `flatTitle` / `heading` / `headingSm` | 24·700 / 22 / 20·700 / 20 / 17 | Anton 28 / 24 / 22 / 22 / 18 · 1.15 · −0.01em |
| `titleLg` / `title` / `titleSm` | 16 / 15 / 13 · 600/500 · 1.3 | Arimo 16 / 15 / 13 · 700 · 1.35 |
| `bodyLg` / `body` / `bodySm` | 15 / 14 / 13 · 1.4 | Arimo 15·1.6 / 14·1.7 / 13·1.7 |
| `message`（新） | — | Arimo 14 / 1.45（聊天气泡，避免 1.7 行高让会话过松） |
| `caption` / `captionSm` | 12 / 11 · 1.35 | 12 / 11 · 1.6 |
| `action` | 14 · 600 | 13 · 800 |
| `label` | 12 · 500 | 12 · 700 |
| `eyebrow` / `kicker` | 12 / 11 · 500 · 0 | 12 / 11 · 800 · +0.15em |
| `figure*` | 系统 tnum · 600 | Arimo tnum · 700（`figureSm` / `figureXs` 仍 400） |
| `code` / `codeSm` | Plex Mono | 不变 |

### 3 · 别名策略

旧 Token 名一律保留，值换成新色：`lime*` → 黄，`card`/`panel` → `#111114`，`elevated`/`card2` → `#1C1B22`，`LoopRadius.*` → 0，`LoopDepth.lift*` → 空。
全仓 700+ 处引用因此不必一次改完就能编译、能跑、色板正确。新代码写新名（`yellow`、`purple`、`line3`、`input`、`LoopRadius.round`）。
`LoopFolioVariant.lime`、`LoopButtonTone.lime` 枚举名不改（改名牵连面大），语义上就是「主强调黄」。

`LoopGround`：`text2` / `text3` / `line` / `card` 从「Chalk 带透明度」改成实色后，派生规则改为——环境墨色是浅色（亮度 > 0.3）时直接返回实色 Token，
是深色（落在 Chalk / 黄底上）时用该墨色乘原来的权重（10 % / 6 % / 13 % / 22 % / 68 % / 58 %）。`inkOf` 把任何浅色环境墨（包括实色 text2）归一为 Chalk。

### 4 · 基础组件换形（docs/42 附A §5）

- 主按钮：平涂黄 + 墨字 13/800，高 52，0 圆角；按下 `#FFE34D` + 上移 2px（减少动态时只变色不位移）。不再渐变、不再投影。
- 次按钮：透明底 + 1px `#4A4754`（浅底上用 `LoopGround.edgeOf`），按下边框紫；边框画在 `foregroundDecoration`，不占布局，描边按钮与实心按钮同高。
- 卡片（`LoopSurfaceCard` / `LoopRecordCard` / `LoopLedgerCard(quiet)` / folio quiet）：`#111114` + 1px `#38333E`，无投影无光晕；可点卡片按下边框变紫。
- `LoopLedgerCard` 主形态、folio lime 形态：平涂黄（别名），去投影；点阵纹理保留。
- 列表（`LoopRecordRow`）：分割线列表——首行上方、每行下方 1px `#2A292F`，无底色无投影；选中行紫 9 % 底 + 3px 紫竖条。
- `LoopBadge` mining/launch/up：黄底墨字（HOT 角标形态），0 圆角；倾斜留给 S241b。
- `LoopKicker`（新）：6px 黄方块 + 黄 11/800/+0.15em 大写。`LoopTopbar.kicker` 与 `LoopLabel`（非 flat）改用它。
- `LoopSeg`：quiet 形态选中 = 紫 9 % 底 + 2px 紫下划线 + 黄字；框形态 0 圆角，选中黄。`LoopTabSegments` 下划线改紫。
- 底部 Tab 栏：`#111114` 方形浮条 + 1px `#38333E`（前景描边），去投影；选中格紫 9 % 底 + 2px 紫下划线，图标与字变黄，未选 text3。
- Sheet：0 圆角，去光晕层与投影，抓手方形 `#4A4754`，标题左右 20。签名单卡片 0 圆角、`line2` 边、内边距 20。
- 输入框：底 `#16111C`、边 `#3B3045`、0 圆角、内边距 12×14、焦点紫 1px（主题 + `LoopPersonRow` 搜索框 + 聊天输入条焦点）。
- `LoopNotice` warn：橙 13 % 底 + 橙 44 % 边。
- `LoopTrayDisclosure`：方形，左右下 1px `line2`；`LoopTokenCard`：去投影与光晕层，`line2` 边，已毕业紫边，左侧黄信号条方形。
- 进度条、阶梯点之外的条形段、钱包分布段、搜索框、标签胶囊：pill → 0 圆角。头像、圆点、圆环保留圆形。
- 空态线稿 `assets/illustrations/*.svg`：主描边 `#B8FF20` → `#FFD600`，次描边 `#F3F5EF` → `#F2F2F4`（`check_harness.py` 的 `ILLUSTRATION_COLOURS` 同步）。
- 清理的硬编码：`loop_sign_sheet.dart`、`loop_sheet.dart`、`loop_blocks.dart`、`loop_token_card.dart`、`loop_toast.dart`、`market_widgets.dart` 的 `B8FF20` / `050604` 字面量；
  `meme_widgets.dart`（M1 快捷卡 r16，原 0169 用户裁决保留，本次按「全部 0 圆角」改掉）与 `community_home_widgets.dart`（r19）的字面圆角，
  两条 `FEATURE_RADIUS_LITERAL_ALLOWLIST` 条目随之删除。图表 K 线圆角（1 / 1.25 / 3 / 4 px）不动。
- 尺寸随之调整：`launch2DeskHeight` 220 → 256（Anton 标题 + 20 内边距 + 1.6 行高下 360dp 不溢出），`loopQuoteRowHeight` 72 → 74。

## 未做（留给 S241b 逐页）

- 逐页版式重排、Hero 大标题（`heroDisplay`）与 `statFigure` 的落点、跑马灯带、倾斜贴纸 / HOT 角标、Lucide 图标替换（附A §6）。
- 固定英文标题是否大写、`LoopFolioVariant.lime` 整块黄卡在各页是否保留（黄卡面积大，looplabs 只在 CTA 与小标签用黄）。
- `assets/tokens/*.svg`、`assets/networks/*.svg` 里原型画的 Lime 代币 / 网络徽标未改色。
- Preview-only 聊天页（`conversation_pages.dart` 受指纹守卫）未改。
- 各页仍在直接引用 `LoopColors.lime` 的地方语义上多是「品牌强调」，值已是黄；需要按页判断哪些应改紫（选中 / 焦点 / 按下）。

## Consequences

- 全仓沿用旧 Token 名即自动换色换形；新代码用新名。旧 Lime 语义的守卫（插图配色、价格色说明句）已同步改写。
- 包体增加约 0.8 MB（Anton 167 KB + Arimo 两档 约 630 KB）；`Noto Sans SC Display` 复用已有文件，不增包体。
- 行高 1.7 与页边 20 让列表与卡片略高：已知把 `launch2DeskHeight`、`loopQuoteRowHeight` 抬高；其它固定高度页面需 S241b 真机核对。
- 0169 M1 快捷卡 r16 的用户裁决被本次「全部 0 圆角」覆盖。

## Verification

`dart format`、`flutter analyze` 零问题、`flutter test` 全量通过、`scripts/check_harness.py` 通过、`tests/` 482 条 Python 单测通过（结果见提交说明与回报）。
测试改动只更新被本决策改写的取值（字号、字重、圆角、颜色、页边 16 → 20、行高），断言意图不变；`stream_chat_message_layout_test` 改断言新增的 `LoopType.message` 台阶。
