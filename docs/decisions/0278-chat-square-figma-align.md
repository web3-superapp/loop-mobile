# 0278 · 聊天 + 广场动态 + 广场社区按 Figma 稿逐页对齐（S353a）

## Status

Accepted · 2026-11-04（S353a-mobile）。依据：用户 11-04 裁决「视觉一律按稿，结构不回退」，数值见 `docs/58-Figma设计规范-需求方稿-2026-11-04.md` §5.1 §5.3 §5.6–§5.9 §5.20 与 §9；底座见 0277。基线 integration/v2 622e67ca（App 默认英文）。

## Context

S352（0277）换了字体、token 与共享组件，三页（稿 2001:180 / 277 / 368）仍是 TF 64 的结构与 S350a（0274）的卡片化：聊天把搜索框塞进标题栏、会话行 80 高无分割线、置顶行 Chalk 5 %；动态一帖一张 r20 卡、作者 15、标签紫 / 黄 LoopBadge、点赞紫、`MarketTabBar` 紫胶囊 + 喷点；社区一社区一张 r20 卡、头像 60、成员「N members」挤掉 `$代币` 标签。英文下广场分段头「Feed Community Voice rooms」在 360 宽挤出屏幕。

## Decision

### 聊天（`stream_chat_inbox_page.dart`、`chat_inbox_row_actions.dart`、`friends/chat_create_menu_button.dart`、`group_alias/group_alias_stream_message_identity.dart`、`stream_chat_appearance.dart`）

- 标题栏回到页标题「Chat」28 / 700 + 紫色涂鸦（`LoopTopbar` 自带）；右侧只有黄色方键 32 × 32 r4、加号 22 onYellow（44 触控）。**铃铛不画**：docs/56 §四已把通知移到「我的」，结构不回退。
- 搜索框 44 移到标题下 8、页边距 20 通栏。
- 会话行 67 高：头像 48、头像→文字 12、名→预览 2、内容在页边距内。做法是在 `ChatInboxRowMetrics` 里改 Stream `StreamTheme.spacing`（xxs 2 / sm 7.5 / md 12），不改 Stream 组件。名 `rowTitleLg` 16 / 500、预览 `captionMd` 14 / 300 次字、时间 `caption` 12 / 300 三级字；「成员: 」前缀改为继承预览字重（原固定 w400，在 300 的预览里显粗）。
- 行直接落在页面上，去掉 0221 / 0224 的半透明卡板；行间 1px 白 5 % 分割线，左右各缩 20；最后一行不画。置顶行底色 = 稿的面色阶 `card #121318` 92 %（`loopChatBoardPinnedFill`），滑动中的行也用这一层盖住操作键；静止的普通行无底色。
- 未读数黄圆 20、10 / 700（`LoopUnreadBadge` 新可选参数 `height`）。
- 群 / 社区会话名后加人数小标（18 高 r4、10 / 600 次字）；稿底色 `#131417` 落在置顶行的卡底上看不见，改白 8 %。单聊不画。
- 单列表混排不回退（稿的「全部 / 社区 / 好友」分段与「置顶 / 最近消息」小节不恢复）。

### 广场分段头（`lib/widgets/loop_tab_segments.dart`，共享件，无 API 变化）

- 新增 `loopSegmentFitScale`：整行在稿值（选中 28 / 未选 24 / 间距 14）放不下时，按比例缩小全部段名（下限 0.72），缩放走 `TextScaler`，不写 `fontSize`；仍放不下才横滚。放得下的页面（情报等）结果是 1，不受影响。

### 动态（`square_feed_view.dart`）

- 「Global / Following」改 `LoopFilterChips`（54 × 32 r8），右端「＋ Post」黄字 16 / 600 + 加号 18；`MarketTabBar` 不再用于动态，360 宽的溢出随之消失。
- 帖子不再是卡：页边距 20、头像 48、作者 `postAuthor` 18 / 600、时间放到名字下 `caption`、正文 `body2` 16 / 400 / 25；帖子底部 1px 白 5 % 线，下一帖上方 12。
- 标签改 `LoopStatusTag`（22 高 r5 12 / 600）：置顶黄、毕业绿、观点紫、领取绿、买入 rise。
- 代币引用卡 64 高 r11、底 `cardInset`、1px `cardEdge`；头像 44、名 14 / 600、价 16 / 600（稿 15，阶梯无 15 / 600，取最近档）；右侧上 1 h 涨跌、下市值 12 / 500。**稿的紫色走势线不画**：帖子数据只有 1 h 涨跌，没有序列，画装饰线等于编数据。
- 官方公告去掉 Card2 内嵌块，直接 14 / 400 正文，「展开」14 / 500 次字。
- 点赞移到右下：心 22、数 14 / 500 次字；已赞黄（原紫）。

### 社区（`square_community_list.dart`）

- 搜索框与「全部 / 我加入的」同一行吸顶的 S350a 结构保留，左右边距 16 → 20。
- 社区行不再是卡：86 高、头像 56 方 r12、名 14 / 500、描述 12 / 300 次字、元信息「人形图标 12 + 数字 10 / 400」+ `$代币` 标签（16 高、1px 白 8 %、圆角 12、logo 10、10 / 400）；行底 1px 白 5 %。成员数按稿只画数字（读屏仍读「N members」），英文下 `$代币` 不再被挤成「$FR…」。
- 「加入」= 稿的小按钮 54 × 28 r6 白 8 % 底黄字 12 / 600；「已加入 / 我的 / 审核中」同尺寸次字。
- 「发现社区」16 / 700；「规则与入驻」「成员最多」12 / 500 次字。
- **热门社区大卡不加回**：S335（0264，需求方 11-02 要求）已删除，且没有「热门」数据来源；稿只作视觉参考。

### 其他

- `LoopButton` 选中态与 `MarketTabBar` 选中胶囊的黄喷点去掉（0277 遗留项），`MarketTabBar` 选中底改 `chipActive` 白 10 %。

## Consequences

- 共享件改动：`LoopUnreadBadge` 加可选 `height`（默认 16）；`loop_tab_segments.dart` 段名自适应（无 API 变化）；`LoopButton._chosenSplat` 不再贴喷点；`market_widgets.dart` `MarketTabBar` 去喷点。路由、view model、gateway、codec 未动；无新文案键。
- 旧断言改到稿值（s350a / s335 / s268 / s265 等），无删除、无 skip。新增 `test/s353a_shots_test.dart`（英文 390 / 360，有数据 + 空态，改前 / 改后）、`test/s353a_figma_align_test.dart`。
- 未做 / 待定：聊天行时间「昨天 / 周一」在英文下仍是中文（`stream_chat_localizations_zh.dart` 的日期阶梯写死中文，不在本批）；社区搜索占位「Search communities」在 360 宽与两颗胶囊同行时尾部渐隐。
