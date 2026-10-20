# 0211 · 设计改版第二轮：保留 looplabs 配色，形态改回 App 规范（S241d-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` cb42d0cd。依据：用户看 build 31 的反馈「现在 UI 太丑了，主色可以用他们的，但是圆角、banner 这些再设计下」，
主代理裁决的九条新规则（S241d 任务单）。**本决策修订 0210 的形态规则**（0 圆角、满屏描边、Anton 大写标题、黄方块 kicker、底部横线式选中态）；
0210 的配色、字体文件、授权、Token 名称全部保留。不新增路由、不新增依赖、`pubspec.lock` 不变、不改 loop-api。

## Context

build 31 落地了 0210 的全套 looplabs 网站形态：0 圆角、每张卡 1px 描边、Anton 大写标题、黄方块 kicker、2px 底线选中态，活动横幅把封面切成右半边。
在手机上这些网站语汇显得生硬拥挤，用户要求保留配色、重新设计圆角与 banner。主代理据此下发九条 App 形态规则。

## Decision

1. **配色不变**：ink `#09090B`、card `#111114`、elevated/card2 `#1C1B22`、chalk `#F2F2F4`、黄 `#FFD600`（CTA / 标签 / 关键数字）、
   紫 `#9C36FF`（选中 / 聚焦 / 按下）、涨跌红绿、warning 橙。新增派生色：`purpleSelected`（紫 18 %，选中块底）、
   `yellowPressed` `#E0BC00`（主按钮按下）、`dangerSoft`（危险按钮按下）。
2. **圆角**（`LoopRadius`）：shell / Sheet 顶部（新增 `sheetTop`）/ 底部 Tab 栏 20；card 16；control / button / tool / wideButton 12；
   inner / tile 10；badge 6；pill 999；聊天气泡新增 `bubble` 16，尾角 `bubbleTail` 6。
3. **卡片去描边**：默认卡 `#111114` 无边框；分组用 `#1C1B22`；可点卡片按下时描 1px 紫边（`_PressedEdge` 对无边卡同样生效）；
   分割线保留 `#2A292F`。输入框 `#16111C` 底、无边框、聚焦 1px 紫边（主题 `InputDecorationTheme`、`LoopComposer`、搜索入口同改）。
   错误态 / 离线态 / 危险提示的底从 `#1C1B22` 改回 `#111114`，好让其上的 `#1C1B22` 次按钮可见（地面探针要求）。
4. **字体**：Anton 只留给 `heroDisplay` / `statFigure`；`display*` 与 `heading*` 台阶改为 Arimo 700 + Noto Sans SC，不负字距。
   台阶：displayXl 28 / display 26 / displaySm 24 / stepTitle 26 / headingLg 22 / flatTitle 20 / heading 18 / headingSm 17 / sectionTitle 16。
   正文 / 说明行高 1.5（原 1.7 / 1.6）。按钮字 `action` 14 / 700。
5. **kicker**：`LoopKicker` 去掉黄方块与大写 +0.15em；小号为 12 / 700 灰字，`large` 为 16 号 chalk 段落标题（`LoopLabel` 非 flat 形态即用它）。
   `LoopType.caps` 变为恒等函数。主要页面上的英文 eyebrow 改成中文（算力榜、发射台、社区索引、社区发现、挖矿算力、共识勋章、交易结果等）。
6. **选中态**：`LoopSeg`（quiet 为胶囊、framed 为 12 圆角块）、顶部分段 `LoopSegmentedTabPage`、`MarketTabBar`、底部 Tab 栏一律为紫 18 % 填充 + 黄字，
   去掉 2px 底线；未选中透明（framed 未选中为 `#1C1B22`）。底部 Tab 栏：选中 icon + 文字黄，紫 18 % 圆角 12 小块包住 icon；栏本身 `#1C1B22`、圆角 20、无边。
7. **活动 Banner**（`Launch2DeskCampaignCard`）：通栏图片卡，圆角 16；底部 60 % 叠黑色渐变（透明 → `#09090B` 90 %）；
   标题黄、说明 chalk、「去参与 ›」压在渐变上左下；倒计时为右上角黄底黑字胶囊；无封面或加载失败时用紫→深灰渐变底。
   翻页点移到卡片下方，为小圆点（当前为紫色短胶囊）。
8. **按钮**：主按钮黄底黑字圆角 12、高 48；次按钮 `#1C1B22` 底 chalk 字无边框（浅色地面上保留描边）；危险按钮描红边红字；
   按下态加深颜色，不再上移 2px。
9. **其他**：`LoopRoundKey` 圆角 12、填充无边；标签 / 阶段角标圆角 6 且为填充色；聊天气泡圆角 16（自己的紫 18 % 底，别人的 `#1C1B22`）；
   聊天浮动「+」圆形黄底；装饰圆环保持默认关。

## Consequences

- 测试期望随形态更新（圆角、描边、选中色、字族、按钮高度、kicker 文案）。
- `lib/features/chat/conversation_pages.dart` 受 Preview 指纹保护，本轮未改。
- 次要页面（系统页、旧 Launch IDO 页、安全页部分）仍有英文 kicker 字面量，以原大小写显示，留待后续逐页清理。
