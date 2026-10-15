# 0170 · 语音房媒体区与社区 / 社交二级页回到原型家族（S186-5-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` f9b271f（0166 之上）。只换视觉语汇：Stream SDK 的接入、通话状态读取、
加入 / 静音 / 发言 / 离开 / 重连 / 输出切换的命令与文案、社区与社交的 controller、请求路径、状态合同与路由全部不变
（路由数不变）。不新增依赖、不新增字体与颜色 token。
来源：主仓库 `docs/33-全App对照原型一致性走查-2026-10-15.md` §4 批次 S186-5（条目 M3、M2、M17、M14、L25）。

## Context

docs/33 §1 的家族五条（一张 folio、`.label` + 行容器、三种胶囊徽标、颜色字号只走 token、同屏一个满 lime）在三处还没落地：

- **M3** 嵌入的 Stream 媒体区（`chat/calls/`）自成一套：大厅琥珀 `LoopColors.chat` 圆图标、`Color(0xFF182C2B)` 径向渐变、
  Material `FilledButton / OutlinedButton / IconButton.filled / Icons.*`、v1 `LoopStateCard` 与 `LoopStatusPill`、
  `danger` 粉红断开键与错误句、琥珀描边参与者卡。
- **M2** community-profile 挖矿块是 `LoopSurfaceCard` + 17 号 lime 权重 + 自造三栏（lime 我的算力），段标题是
  `LoopSectionTitle` ×5，但页面没有包 `LoopFlat`。
- **M17** 用了 OKX `LoopPersonRow` / `LoopSectionTitle` 的五个二级页（community-members / -manage / -profile、
  social connections / dm-requests）都没包 `LoopFlat`，同屏 mono 10 大写 `.label` 下面接 OKX 行。
- **M14** 全局搜索主筛选是自造描边全圆 `LoopSubChip`。**L25** community-manage「尚无已注册池子」是 warning 黄字。

## Decision

### 1. 语音房媒体区（M3）
- 新增 `VoiceMediaStateCard`（`chat/calls/voice_media_state_card.dart`）：`.record-card` 底（card 填充、line 描边、
  `LoopRadius.card`）+ 精灵图标 + chalk 标题 + text2 句 + 至多一个下一步。tone 只决定图标色：positive / warning = lime
  （原型 `--amber` = lime）、danger = chalk（`--red` = chalk）、其它 text2。替换大厅状态卡、恢复后静音提示
  （key `voiceroom-media-restored` 不变）与成员区四张状态卡。
- `_StreamVoiceContent.icon`、`_LobbyFact.icon` 由 `IconData` 改精灵名（refresh / offline / voice-off / voice / lock /
  warn / cloud / community / shield / back / phone）。三条大厅事实改 card 底 + `LoopHairline`，图标 text2。
- 按钮：连接语音 = `LoopButton(primary, block, icon: voice)`（新 key `voiceroom-media-join`，满 lime 只此一个）；
  重新连接语音 = 同款（key `voiceroom-media-reconnect` 不变）；重试会话 / 重试读取语音房 / 重试收尾 = 次级
  `LoopButton(icon: refresh)`（key `voiceroom-media-retry-session` 不变，另两颗新加 key）。连接中不再画转圈，
  文字「正在静音连接」本身说明状态（按钮禁用）。
- 独立页：AppBar 返回改 `LoopIconButton('arrow-down', label: 返回)`；背景径向渐变删除，改 ink 平涂；
  大厅圆标改 card2 圆 + line 描边 + lime `voice` 图标（key `voiceroom-lobby-mark`）。
- 通话视图（`stream_foreground_call_view.dart`）：状态 `LoopStatusPill` → `LoopBadge`（key `voiceroom-media-status`），
  新增 `StreamCallStatusPresentation.badgeKind`：已连接 = up、连接 / 重连中 = mining、断开 / 重连失败 = down、其它 = mute；
  删除只为 pill 存在的 `icon()`。「系统已暂停音频」= mining badge。错误句 danger → chalk。
  发言 / 静音 / 仅收听、重新连接后发言、声音输出三颗改次级 `LoopButton`（key `voiceroom-media-microphone` 新加，
  `voiceroom-media-speak-again` / `voiceroom-media-output` 不变）。断开键 = 新的 `LoopButtonTone.danger`
  （原型 `.btn-danger`：chalk 平涂、ink 字形，图标 `phone`，语义标签与 tooltip 仍为「断开语音连接」，
  key `voiceroom-media-disconnect`）。参与者卡改 card 底 + `LoopRadius.card`，发言中只用 lime 描边与 lime 麦克风图标，
  头像圆 card2 + chalk 首字母，静音图标 text3。
  无底栏时那一行里的声音输出键包 `Flexible`（`LoopButton` 在没有宽度上限的 Row 子位里量不出标签宽度）。

### 2. community-profile 挖矿块（M2）
- `CommunityMiningSummaryCard` 改一张 `LoopRecordCard`（可点开社区挖矿面板，外层 key `community-mining-summary` 不变）：
  头行「社区挖矿」+ chevron；`LoopKeyValue` 五行——权重 · Mining Weight（`community-mining-weight`）、社区总算力
  （新 key `community-mining-power`，基线结算时值后接 ` · ${miningBaselineLabel}`）、`LoopHairline`、我的持仓 / 我的算力 / 预估/日
  （`community-mining-cell-*` 不变）。数字全部 chalk mono；lime 17 号权重与 lime 我的算力去掉。下方原因句不变。
  `_MiningColumn` 删除。
- `LoopKeyValue` 新增可选 `valueKey`（落在值 `Text` 上，缺省 null 像素不变），供测试读单个数字。
- 页面包 `LoopFlat`；`LoopSectionTitle` 五处 → `LoopLabel`（挖矿 / 公告 / 官方链接 / 绑定代币 / 成员）；
  「成员 N」的「查看全部」放在 `LoopLabel` 行尾（key `community-profile-open-members` 不变）。OKX 头部（0127）保留。
- 申请状态徽标「已驳回」由 danger 粉红自绘胶囊改 `LoopBadge(kind: down)`。
- 「审核中」申请卡是画在进度填充上的 `LoopNotice`；`LoopFlat` 会把 normal notice 收成一行灰字，所以 `LoopNotice`
  新增可选 `keepCard`（缺省 false，行为不变），这张卡传 true 保留卡片。

### 3. 二级页统一 `LoopFlat` + harness 守卫（M17）
- community-members、community-manage、community-profile、social connections、social dm-requests 的页面根包 `LoopFlat`。
  效果按 0126：标题 20 粗、`LoopLabel` 变 17 粗中文段标题、`LoopRecordRow` 平铺、normal `LoopNotice` 收成一行 11 灰字
  （成员目录的「没有权限查看成员目录」因此与原因合成一行）、block 按钮变宽按钮。
- community-manage 三处 `LoopSectionTitle`（资料 / 成员 / 语音房）→ `LoopLabel`（flat 内同为 17 粗）。
- `scripts/check_harness.py` 新增 `check_flat_family_contract`：
  1. `lib/features/**` 里出现 `LoopPersonRow(` 或 `LoopSectionTitle(` 的文件必须同时出现 `LoopFlat(`，
     例外只能写进 `FLAT_PAGE_ALLOWLIST`（文件 → 原因；目前为空）。
  2. `lib/features/chat/calls`、`lib/features/community`、`lib/features/social` 内禁止 `Color(0x…)`、
     `LoopColors.warning / danger / chat / market / elevated`、`FilledButton / OutlinedButton`、`Icons.`、
     `LoopStatusPill`、`LoopSubChip`（注释不计）。
  `tests/test_check_harness.py` 新增 `FlatFamilyContractTests` 7 例。

### 4. 搜索筛选与提示句（M14 / L25）
- 全局搜索主筛选 `LoopSubChip` → `LoopSeg(quiet: true)`（OKX 深灰实心胶囊；key `search-seg-{domain}` 不变，
  仍按域单独加 key 所以没有换成 `LoopSegBar`），`LoopSubChip` 类删除。搜索框后缀与成员搜索清除键由
  Material `IconButton + Icons` 改 `LoopIconButton`（search / close，key 与 tooltip 文字不变）。
- community-manage「尚无已注册池子，群友买入动态不会出现。」warning 黄 → text3。

### 5. 社区头像底色
- `community_logo.dart` 的四个混色底原是 `Color(0x…)` 字面量；改为由 token 现算（`Color.lerp(lime, chalk, .5)`、
  `Color.alphaBlend(lime 55% / chalk 75% / muted 60%, ink)`），列表由 `const` 改 `final`。数值与旧值相同（逐通道误差 ≤ 1）。

## Consequences

- 语音房媒体区与社区 / 社交二级页与其它 flat 二级页同一部件家族；`chat/calls/`、`community/`、`social/` 内不再有
  `Color(0x`、v1 accent、Material 按钮与 `Icons.*`，harness 守住。`test/loop_theme_test.dart` 的 legacy accent
  名单去掉两个 calls 文件（名单只减不增）。
- 连接中的按钮不再有转圈；断开键从粉红圆键变成 chalk 平涂按钮（高 53，旧 48）。
- `LoopButtonTone.danger`、`LoopKeyValue.valueKey`、`LoopNotice.keepCard` 三个公共参数全部可选，缺省像素不变。
- 未改：`lib/features/chat/voice_room_page.dart`（外层 LOOP 语音房页，仍有 `LoopRadius.medium` 等，非本批条目）、
  `community_widgets.dart` 申请表单的「取消」`TextButton`（不在本批禁用清单，属 S186-7 收尾）、
  `LoopStateCard` / `LoopStatusPill` 本身（别处仍在用，S186-7 加全局守卫）。

## Verification

- `test/s186_5_voice_community_family_test.dart` 新增 10 例：五个二级页在 `LoopFlat` 内、无 `LoopSectionTitle`、
  段标题是 `LoopLabel`、全页 Text / LoopIcon 无 chat / danger / warning / market / elevated；挖矿块是一张
  `LoopRecordCard` + 五行 `LoopKeyValue`（标签顺序）且五个数字为 chalk；「已驳回」为 down badge；
  语音大厅无 `Icon` / `FilledButton` / `OutlinedButton` / `LoopStateCard`、一张 `VoiceMediaStateCard`、重试为次级
  `LoopButton(refresh)`、连接为 primary `LoopButton(voice)`、圆标 card2、无径向渐变；`badgeKind` 四态映射；
  状态卡图标色只取 lime / chalk / text2；`.btn-danger` 为 chalk 底 ink 图标且语义标签「断开语音连接」。
- 跟着改：`stream_voice_room_page_test`（连接按钮改按 key 读 `LoopButton`）、`community_pages_test`（社区总算力改读
  `community-mining-power` 值；权限页文字改 `textContaining`）、`s121a_copy_search_security_test` /
  `community_social_pages_test` / `s97_share_loop_id_test`（`LoopSubChip` → quiet `LoopSeg`）、
  `s121f_secondary_pages_test`（段标题为 `LoopLabel`）、`s109b_qr_scan_manage_test`（无池句为 text3）、
  `loop_theme_test`（legacy 名单收缩）。
- 命令：`bin/dart format`（本批文件）、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
  `python3 -m unittest discover -s tests -p 'test_*.py'`、community / social / calls / 语音房相关 81 个测试文件的
  `bin/flutter test`。未跑全量、未起模拟器、未做真机验收：语音房在设备上的观感（尤其连接中无转圈、断开键尺寸）待主代理验收。
