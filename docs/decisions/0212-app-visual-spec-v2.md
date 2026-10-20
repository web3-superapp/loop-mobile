# 0212 · 设计改版第三轮：App 视觉规范 v2（S241e-mobile）

## Status

Accepted 2026-10-20。基线 `feat/S241d-app-shape` 9940a631（决策 0211）。依据：LOOP `docs/42-附C-App视觉规范v2-2026-10-20.md`（执行稿）、
用户对 build 32 候选的反馈（按钮紫底太浅、Tab 栏紫色块、banner 文字截断、整体丑）、主代理追加的两条（钱包首页水平对齐、会话页恢复）。
**本决策修订 0211 的选中态、字体、间距与 banner 规则**；0210 / 0211 的配色、字体文件、圆角台阶保留。不新增路由、不新增依赖、`pubspec.lock` 不变、不改 loop-api。

## Context

S241d（0211）把形态改回 App 后，用户看 build 32 候选仍判「丑」：按钮紫底太浅（18 % 选中底）、Tab 栏紫色块多余、banner 封面自带文字又叠一层字且被截断、标签实心黄一排、实时区时间紫色。
主代理据此写了附 C（一个张扬点 + 其余安静），并追加两条：钱包首页水平对齐不一致；会话页「像 demo」，要求回到 S241a 之前的形态只换配色。

## Decision

1. **色彩用法**：黄只给主按钮、唯一 CTA、关键数字；紫只给选中态。`LoopColors.purpleSelected` 改为紫色实心（废弃 0211 的 18 % 底），
   新增 `onPurple`（纯白，紫底对比 4.79:1；Chalk 只有 4.28:1）与 `purpleTint`（紫 18 %，只用于「已毕业」阶段胶囊）。
   `LoopColors.input` 改为 card `#111114`。
2. **选中态**：`LoopSeg`、`LoopButton(selected:)`、`MarketTabBar`、`LoopRoundKey(quiet, active)`、推广等级格、社区工具开关一律紫实心白字；
   `LoopSeg` 两种形态都为胶囊。底部 Tab 栏去掉色块（栏底 card、无描边），选中只靠黄色 icon + 文字；Material 导航主题的 indicator 透明。
   顶部页签（`LoopSegmentedTabPage`：v2 发射 / 历史 / 已毕业、广场、情报）改为 20/700 文字，选中 chalk、未选 text3，选中下方 3 × 24 黄短线。
3. **标签**：`LoopBadge`（mining / launch / up）、`LoopTag`、MEME 阶段标签改为胶囊淡底（黄 13 % + 黄字 12/600；已毕业紫 18 % + 紫字；等待 raised + text2），
   不再有实心黄标签。列表行右侧阶段由 96×44 色块改为槽内右对齐的小胶囊。
4. **字体**：`statFigure` 改 Arimo 700 26；新增 `keyFigure`（Arimo 700 32，总资产、我的名次）与 `heroFigure`（Anton 30，只用于 MEME 项目页 hero，
   `MemeStatFigures(hero: true)`）。情报「我的名次」改为 chalk 灰标题 + 黄 32/700 名次；领奖台第一名徽章与皇冠改紫、徽章圆形。
5. **间距**：页边距 16、区块间距 28、卡片内边距 16（`LoopSpacing.page / section / card`）。
6. **按钮**：主按钮黄底高 48；次按钮仍为 48（附 C 要求 44，但测试集执行 Android 48 dp 触控目标准则，取无障碍）。
   钱包四个快捷键全部 raised 底 chalk 图标，「兑换」不再黄实心。广场社区行「加入」改黄色主按钮，「已加入」为次按钮。
7. **活动 Banner**（`Launch2DeskCampaignCard`）：高 200（只有活动页时；与发射卡同一 pager 时沿用 232）；封面 `BoxFit.cover` 居中，失败为黑→紫渐变；
   底部 55 % 黑色渐变；标题 22/700 黄单行，说明单行省略，底行「MM-dd 至 MM-dd · 剩 N 天」12 text2，「去参与」黄实心按钮高 36 在右下；
   去掉右上倒计时黄胶囊与「活动 · → 」eyebrow；页码点 6 px，当前紫。staging 活动封面同批换成无字图（数据变更，非代码）。
8. **实时成交行**：时间 text3；「买入」rise、「卖出」fall；金额 chalk 600；地址 text2。MEME 行的「N 小时」不再紫色。
9. **水平对齐**：`LoopRecordRow`（非 flat）去掉 12 内缩，图标与文字落在 16 页边距上、箭头落在右边距上，与区块标题、余额行对齐
   （钱包首页底部「跨链 / 代币授权 / 网络 / DApp 网址核对 / 设置」等所有记录分组同改）。
10. **会话页恢复**：`stream_chat_appearance.dart` 回到 S241a 之前（0a37ce8e）的结构——去掉全零 `StreamRadius`（输入栏、发送键、日期胶囊、反应胶囊恢复圆角）、
    恢复引用卡与头像描边——只替换配色：自己的气泡紫实心白字，别人的 raised `#1C1B22`，输入栏 card，发送键黄，聚焦紫，链接黄。反应胶囊恢复全圆。
11. **英文 eyebrow**：剩余大写英文 kicker / stamp（发射记录、服务状态、语音大厅、推广算力、每日产出、授权检查、最终确认、上次同步等）改中文。
    受指纹保护的 Spot Preview 卡（`SPOT PREVIEW`）与原型 `GLYPH / USDC` 不改。

## Consequences

- 测试期望随规则更新（选中色、Tab 栏、阶段标签、banner 结构、字族、间距、行内缩、会话页配色）。
- 次按钮高度与附 C 的 44 不一致，按无障碍准则保留 48。
