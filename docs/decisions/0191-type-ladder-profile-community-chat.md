# 0191 · 个人 / 社区 / 社交 / 广场 / 聊天与弹层落到字体阶梯（S197-3-mobile）

## Status

Accepted 2026-10-16。基线 `feat/S197-3-mobile` bcc2ffd（0189）+ 主线测试修复 094bf64（单独一条，未并入本提交）。
来源：主仓库 `docs/37-全App字体一致性走查-2026-10-15.md` §1（R1–R31）、§2（本批条目）、0189 阶梯与 G1 / G2。
范围：`lib/features/{profile,social,community,square,chat,scan}/**`，加 `launch2/launch2_signing.dart` 与 `account/loop_id_setup_screen.dart`（只改 M19 那一处）。
不新增依赖、路由、字体、资产；`pubspec.lock` 不变；`lib/widgets/**` 与 `test/type_roles_test.dart` 未动。

## Context

0189 定了阶梯与守卫，features 里还有 374 处数字 builder 与 31 处别名记在 G1 白名单上。本批这几个目录占 184 处：镜像页（我的主页 / 他人主页、个人 / 社区主页）
名字与计数差一档还反着粗细，交易记录行与其它页不是一套尺寸，弹层标题 16 / 18 / 20 混用并绕开 `LoopSheetHeading`，弹层说明用不随地面变的 `muted`。

## Decision

只改字号档 / 字重 / 颜色档，以及为落档必须的部件替换；布局（间距、对齐、行结构）不动，例外见「布局细节」。

### 1. 逐条（docs/37 ID → 文件 → 前 → 后）

| ID | 文件 | 前 | 后 |
|---|---|---|---|
| H1 | `social/public_profile/user_profile_screen.dart` 名字 | `heading(22, w700)` | `LoopType.displaySm` 24/600（与我的主页同） |
| H2 | 同上 `_Count` | 数 `figure(16)`/600，词 `caption(13)` text2 | 数 `figure` 13/700，词 `bodySm` 13 text2（R28） |
| H7（本批部分） | 同上 交易行 | `LoopQuoteRow` 16 / 13 / 17 / 副值手写 `body(14)` | `LoopRecordRow` 默认：title 15 / caption 12 text2 / figure 13·600（买入 rise）/ figureXs 11；行外包 `LoopFlat`，保持原来无底色、页边距的形状 |
| M21 | 同上 | 副值传 `body(14)` style | 不再传 style（随 H7 换行部件） |
| L5 | 同上 持仓总额 | `figure(26)` | `figureLg` 20（二级页）；「持仓总额」`caption`、读取时间 `captionSm` |
| L25 | `profile/profile_v2_screens.dart` 简介 | `body` chalk | `body` text2（与他人主页同，R18） |
| M19 | LOOP ID 五处：`profile_v2_screens.dart` 主页行内、编辑页 LOOP ID 框；`user_profile_screen.dart`；`social/public_profile_sheet.dart`；`account/loop_id_setup_screen.dart` | 13 caption / 15 figure / 13·400 h1.5 / 12·500 muted / 18 | 前四处行内 `figure` 13/500 text2；设置页主值 `figureLg` 20 |
| M20 | `community/community_profile_screen.dart` 社区名 | `heading(22, w700)` | `displaySm` 24/600 |
| L12 | 同上 计数行 | `figure(14)` 400 / 在线 600 lime | `figure` 13（400 / 在线 600 lime） |
| M1 | `chat/v2/forward_target_sheet.dart` | `heading(18, w700)` | `LoopSheetHeading` |
| M2 | `chat/v2/group_screens.dart` 改群名 | 同上 | `LoopSheetHeading` |
| M3 | `chat/v2/voice_room_screens.dart` 成员操作；`voice_room_stage.dart` 房间说明、开播 | 同上 ×3 | `LoopSheetHeading` ×3 |
| M4 | `community/community_ai_screen.dart` 来源、举报 | 同上 ×2 | `LoopSheetHeading` ×2 |
| M5 | `community/community_widgets.dart` 在线说明、确认、申请已提交、编辑资料 | 同上 ×4 | `LoopSheetHeading` ×4 |
| M6 | 同上 创建社区 | `heading(20, w700)` 居中 | `LoopSheetHeading`（20/600，左对齐，与其它弹层同） |
| M8 | `social/qr/loop_qr_card.dart` | `heading(18, w700)` | `LoopSheetHeading` |
| M9 | `square/square_community_list.dart` 排序规则 | 同上 | `LoopSheetHeading` |
| M10 | `chat/chat_inbox_row_actions.dart` | `heading(16, w700)` | `LoopSheetHeading` |
| M12 | `profile/security/security_screens.dart` 撤销会话 | `titleLg` 16 | `LoopSheetHeading` |
| M15 | `profile/presentation/avatar_editor.dart` 裁剪头像 | `title(17)` | `LoopSheetHeading` |
| M17（本批部分） | `forward_target_sheet.dart`、`avatar_editor.dart` 说明 | `caption(12)` text3 / text2 | `bodySm` 13 text2 |
| M18（本批部分） | `square/square_feed_view.dart` 删除确认、`launch2/launch2_signing.dart` NFT 说明 | `body(14)` text2 | `bodySm` 13 text2 |
| L1（本批部分） | `voice_room_screens.dart`、`voice_room_stage.dart` ×2、`community_ai_screen.dart`、`community_widgets.dart` ×3、`square_community_list.dart` ×2 | `body(13)` muted | `bodySm` text2 |
| M39（本批部分） | `chat/friends/friend_screens.dart`、`chat/group_alias/group_alias_screen.dart` ×2、`profile_v2_screens.dart`（别名、简介） | `body(16)` / `body(15)` | `bodyLg` 15 |
| M40 | `chat/v2/chat_search_screen.dart` | `caption(13.5)` | `body` 14 |
| M41 | `square_community_list.dart` 搜索入口 | `caption(13)` text3 | `body` 14 text3 |
| M43 | `chat/calls/stream_foreground_call_view.dart`、`chat/calls/stream_voice_room_page.dart` 「语音房」 | `headlineLarge` 22 | `titleLg` 16（R31） |
| L2 | `community_widgets.dart`、`community_ai_screen.dart` 「观察于」 | `figure(12)`/600 | `captionSm` 11 |
| L3 | `community/community_home_widgets.dart` 数据观察于 | `eyebrow(11)` | `captionSm` |
| L26 | 同上 发现页 hero | kicker `eyebrow(11)` / 标题 `heading(18)` / 正文 `caption(11)` | `kicker` / `headingSm` 17 / `captionSm`（保留手写，未换 `LoopFolioPrimary`：它的 compact 卡高与 Lime 地面都和这块 72 高的入口不同，换了布局会变） |
| L8 | `chat/v2/chat_forward_screens.dart` 「n/m」 | `display(17)` | `figureMd` 17 |
| L18 | 同上 发送者 | `label(14)` | `title` 15 |
| L13 | `community_widgets.dart` 卡头「社区挖矿」 | `title(14)` | `title` 15 |
| L14 | `square/square_feed_view.dart` | 作者 `title(13)`、符号 `title(13)`、市值 `caption(11)`、价格 `figure(13)`、涨跌 `figure(11)` | 作者 `title` 15；胶囊文字 `caption` 12（符号 600）、价格 `figure` 13、涨跌 `figureXs`@600 |
| L15 | `community/search_screen.dart` 入口格 | `title(14, w700)` | `title` 15/600 |
| L16 | `voice_room_stage.dart` 主持人名 | `title(17)` | `headingSm` 17 |
| L17 | `public_profile_sheet.dart` 名字 | `title(17)` | `headingSm` 17 |
| L19 | `chat/member_buy/loop_member_buy_card.dart` 名字 | `label(13)` text2 | `caption` 12 text2。理由：卡里的主句是下一行「买入 数量 代币」（title 15），名字和右侧时间是这句之上的说明行，是 R5 副标题角色，不是行标题；给 15 会和主句抢层级 |
| L21（本批部分） | `community_widgets.dart` 「取消」、`profile_v2_screens.dart` 「立即买入 →」「＋ 添加个人简介」、`voice_room_screens.dart` 横幅动作 | `body(14)` / `label(13,700)` / `title(14)` / `body(12)`/600 | `label` 12/600（横幅动作不可点时 400 不变） |

### 2. 顺带落档（触及文件里剩余的数字 builder / 别名）

- 同像素换名：`caption(11)`→`captionSm`、`caption(12)`→`caption`、`body(14)`→`body`、`body(15|16)`→`bodyLg`、`title(15)`→`title`、`title(16)`→`titleLg`、
  `figure(13)`→`figure`、`eyebrow(11)`→`kicker`、`code(11)`→`codeSm`、`heading(20,w700)`（扫一扫页头、二维码海报名字）→`flatTitle`、`display(26)`→`display`、
  `label(13,600)`→`titleSm`@600、`title(13)`→`titleSm`@600、`body(13)`→`bodySm`（颜色照旧用 `copyWith` 写回 chalk / 地面色）。
- 离档收档：`figure(12)`→`figureSm`（字重照旧用 `withWeight`）、`figure(11)`→`figureXs`（涨跌 / 序号 600）、`body(12)`→`caption`、`caption(13)`→`bodySm`、
  `code(12)`→`code` 13（扫一扫未知文本、名片海报 LOOP ID）、`figure(14)`（邀请码）→`figure`@500、`figure(15)` 买入数量 → 与同句同为 `title` 15 lime。
- 别名：`LoopMono.label`→`eyebrow`（`support_screen.dart` ×2）、`LoopMono.stamp`→`figureXs`（`community_screen.dart`）、
  `LoopType.monoTitle`→`figureLg`（`chat_preview_pages.dart`）、`LoopType.monoStamp`→`figureXs`（`chat/widgets/chat_components.dart`）。
- 删死代码 `CommunityIdentityBlock`（docs/37 W11，无挂载、无测试引用，含 4 处离档）。
- 字母头像：`community/community_logo.dart`、`profile_v2_screens.dart` 的 `size / 4.5` 比例 builder 不是数字字面量，G1 本就不计，**白名单里没有它们的条目**，无需留例外。

### 3. 布局细节（落档带来的、刻意接受的）

- 弹层换 `LoopSheetHeading` 后，原来「整块 `Padding(16, 4, 16, b)` 包标题和内容」改成「标题（部件自带 16 / 0 / 16 / 12）+ 内容 `Padding(16, 0, 16, b)`」，
  标题下原来的 `SizedBox(8 / 12 / 14 / 4)` 由部件的 12 代替：标题与说明之间的距离统一成 12，顶上少 4。转发目标弹层的内容包 `Flexible`，保留原来的可滚列表。
- 头像裁剪（全屏对话框）标题上方保留 12，下方由 4 变 12；撤销会话弹层同理。
- 创建社区标题由居中改为左对齐（所有弹层同一位置）。
- 他人主页交易行由 OKX 报价行换成账本行的平铺形态：56 高、无底色，与原来同宽同边距；数字比原来小（17 → 13）。

### 4. 保留项（未落档）

- 无。本批范围内 `lib/features/{profile,social,community,square,chat,scan}/**` 与 `launch2_signing.dart` 已无数字 builder、`copyWith(fontSize:)` 与弃用别名；
  `loop_id_setup_screen.dart` 余 4 处（M39 输入、说明两处、占位）按任务单留给 S197-4。
- 部件缺口（未改 `lib/widgets`，供后批）：`LoopSheetHeading` 没有 `textAlign` / `maxLines`，长会话名会折行；没有「行内 LOOP ID」部件，五处各自写同一个 `withWeight(figure, 500)` text2。

### 5. 白名单变化（`TYPE_LADDER_FEATURE_ALLOWLIST`，(数字 builder, 别名)）

删除 38 条（合计 179 → 0）：profile ×5（avatar_editor 3、profile_v2 11、security 2、settings 1、support 1+2）、social ×5（connections 1、user_profile 10、public_profile_sheet 3、loop_qr_card 7）、
community ×8（ai 13、home_widgets 4、manage 2、member_faces 1、profile 6、screen 1+1、widgets 19、search 2）、square ×3（community_list 10、feed_view 13、screen 4）、
chat ×16（voice_media_state_card 2、inbox_row_actions 2、preview_pages 0+1、friend_screens 2、group_alias 2、member_buy 7、stream_chat_inbox 2、chat_token_card 1、chat_forward 9、chat_search 1、
forward_target_sheet 4、group_screens 1、channel_surface 3、voice_room_screens 6、voice_room_stage 11、chat_components 0+1）、scan 5、launch2_signing 2。
改小 1 条：`account/loop_id_setup_screen.dart` (5, 0) → (4, 0)。合计 184 → 4。`TYPE_FLOOR_FEATURE_ALLOWLIST` 本批文件原本就没有条目，未变。

### 6. 0187 / 0127 / 0175 / 0104 修订

- 0187（广场紧凑帖）：帖子结构不动；作者名 13 → 15、胶囊符号 13 → 12/600、市值 11 → 12、涨跌 11/600 不变；见 0187 文末「0191 修订」。
- 0127（他人主页 OKX 交易行）：交易行改为账本行（平铺）尺寸；0175 / 0104 的 LOOP ID 行改为统一的行内 figure 13/500 text2。

## Consequences

- 可见变化（待主代理真机验收）：他人主页名字变大变细（22/700 → 24/600）、计数变小（16 → 13）、交易行数字变小（17 → 13）、持仓总额 26 → 20；
  社区主页名字 22/700 → 24/600；十七个弹层标题统一 20/600（原 16 / 18 粗 / 20 粗），说明统一 13 text2；广场帖作者名 13 → 15；语音房居中态「语音房」22 → 16；
  聊天搜索输入 13.5 → 14；多个输入框正文 16 → 15。
- 这几个目录以后写数字 builder 或别名，`python3 scripts/check_harness.py` 直接失败（白名单条目已删）。
- 布局细节与保留项见上 §3 / §4。

## Verification

- 新增 `test/s197_3_type_test.dart`（13 例）：他人主页名字 / 计数 / LOOP ID / 简介色 / 持仓总额（H1、H2、M19、L25、L5）；交易行是 `LoopRecordRow` 且标题 15 / 金额 13·600 rise / 美元 11（H7、M21）；
  社区主页名字 24/600（M20）；十个弹层标题是 `LoopSheetHeading` 20/600（M2、M4 ×2、M5 ×3、M6、M8、M9、M10），说明 `bodySm` text2（L1）、观察于 `captionSm`（L2）；广场社区搜索入口 `body` 14 text3（M41）。
- 跟改既有测试：`test/s109a_public_profile_test.dart` 他人主页名字 22 → 24；`test/s121f_secondary_pages_test.dart` 社区主页名字 22 → 24。
- 门禁：`bin/dart format --set-exit-if-changed lib test` 0 改动；`bin/flutter analyze` 0 issue；`python3 scripts/check_harness.py` 通过；
  `python3 -m unittest discover -s tests -p 'test_*.py'` 与全量 `bin/flutter test` 结果见提交说明。未起模拟器、未做真机验收。
