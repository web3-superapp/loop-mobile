# 0127 · 二级页视觉统一：社区 / 语音房 / 社交（S121f）

## Status

Accepted 2026-10-09。主代理下单（S121f），本单设计兼实现。基线 `integration/v2` 5c08c8c。
不新增依赖、`pubspec.lock` 不变、路由清单不变。与 S121e（我的 / 账户 / 钱包二级页 / 挖矿）并行，文件不交叉；
共用件只加新文件，不改 `lib/widgets/**` 旧文件。

## Context

S121b / S121c（0122 / 0123）把一级页改成 OKX 的样子（`LoopQuoteRow`、`LoopEmptyState`、深灰胶囊 `LoopSegBar`、Lime 圆键）。
二级页还停在旧样子：社区主页是「COMMUNITY RECORD」大卡 + 88 Logo 身份卡 + 三个等宽按钮 + 一整张 Token Card（带 1H 线）
+ 说明卡；成员 / 关注 / 请求页顶部是带英文 eyebrow 的 hero 卡；管理中心是「MANAGE」卡 + 一组组描边卡片；
创建社区是带长段说明的标签输入框和编号 chips；语音房底栏是图标 + 字，空格是一行灰字。

对照：`docs/evidence/2026-10-09-reference-okx/`（社交 4910 的头像 + 帖子行与互动行、资产 4908 的四个圆键与资产行），
`docs/evidence/2026-10-08-reference-fomo/`（资料页头部与行），S121 §1.1.1 十条、§1.2 纪律。

## Decision

### 共用件（全部新文件）

- `lib/widgets/loop_round_key.dart`：`LoopRoundKey`（56 圆 + 24 图标 + 下方 13 字；`primary` 实心 Lime 黑图标、`quiet` card2 面
  Chalk 图标 / 开启态 Lime、`fall` 结束键；不可用为 card2 + text3；可带 Lime 角标）与 `LoopRoundKeyRow`（等分）。钱包四键（0122）
  是同一形状，它的私有实现没动。
- `lib/widgets/loop_person_row.dart`：`LoopPersonRow`（左图 + 16 名 + 可选小标 + 13 灰副行 + 右侧一件东西 / ›，无卡无分隔线，
  最小高 56–64）、`LoopEntryIcon`（40 圆 card2 + 20 图标，给没有脸的入口行）、`LoopTag`（20 高小标，Lime 只给治理角色 / 已验证）、
  `LoopPillAction`（32 胶囊 / 44 触控，Lime 为行内唯一前进动作）、`LoopSectionTitle`（17 粗 + 右侧最多一个控件）+ `LoopSeeAll`、
  `loopFormFieldDecoration`（52 高填充输入、圆角 12、聚焦 Lime 边）、`LoopWideButton`（52 整宽 Lime）。
- `lib/features/community/community_member_faces.dart`：`communityMemberFacesProvider`（成员目录首页，取前 12 张脸）+ `CommunityMemberStrip`。
- 插图 `assets/illustrations/members.svg`（名录框 + 两个人形 + 列表线）、`friends.svg`（两人 + 加号）；`LoopIllustration.members / friends`；
  harness `ILLUSTRATION_NAMES` 增两项。

### 逐页计划（色 / 字 / 布局 / 记忆点 / 删掉什么 / 对照）

**社区主页 `community-profile`**
- 色：底 Ink；圆键实心 Lime 黑图标；验证小标 limeSoft 底 Lime 字；在线人数 Lime；其余 Chalk / text2。
- 字：名 22 粗；计数行 14 tabular 灰；简介 14 灰两行；段标题 17；行 16 / 13。
- 布局：头部 Logo 72（圆角 20）+ 名 + 「已验证」+「N 成员 · M 在线 · $SYM」→ 简介；一排圆键 进群聊 / 语音房 / 分享 / 管理（管理员）；
  理由一行 11 灰居中；「绑定代币」一行 `LoopQuoteRow`（Logo 36 · 符号 / 名称 · 价格 / 24h · 涨跌胶囊）；「成员 N」+「查看全部 ›」+ 48 头像横滑；
  社区 AI 入口行；「挖矿」卡；公告 / 官方链接仅在有内容时；退出社区为一行 fall 字入口；未加入时底部整宽 Lime「加入社区」。
- 记忆点：一排四个 Lime 圆键。
- 删掉什么：COMMUNITY RECORD 大卡与英文 kicker、第二个 88 身份卡、顶栏三个图标（成员 / 分享 / 管理，分别进了段落与圆键）、Token Card 的
  1H 线与三格指标与说明句（以及为它读的 K 线）、「暂无公告 / 暂无官方链接」空行、「未绑定社区币」空行、底部「我的身份」与长段所有者说明（缩为一行 11）。
  自评再删一个：顶栏右侧不留任何图标。
- 对照：OKX 4908（圆键）+ 4910（头像 + 行）。

**成员 `community-members`**
- 色：治理角色小标 Lime，禁言 / 封禁小标灰；「管理」描边胶囊。
- 字：名 16 / LOOP ID 13；分组列头 12 灰。
- 布局：顶栏 成员 + 搜索（一个图标）；列表首行为社区 Logo 40 + 名 + 「N 名成员」（「这是谁的名录」，键盘弹起时收起）；
  chips 为深灰胶囊（`LoopSeg(quiet)`）；行 = 头像 36 + 名 + 角色小标 + LOOP ID + 右侧「管理」（仅当服务端给了命令）。
- 记忆点：每行左侧一张脸。
- 删掉什么：MEMBER DIRECTORY hero、头像叠放预览、「在线人数」说明条、「成员算力」卡、「三级权限」说明卡、「没有更多成员」。
- 对照：OKX 4910 行。

**管理中心 `community-manage`**
- 色：入口行 card2 圆图标；「仅所有者」灰小标；无池子提示一行 warning 字。
- 字：段标题 17；行 16 / 13；脚注 11。
- 布局：头部一行（Logo 48 + 名 + 角色 Lime 小标 + 成员数）；三段 资料（名称与简介 / 绑定代币 / 二维码名片 / 公告）、成员（成员与权限 / 转让所有者）、
  语音房（开启或进入）；末尾一行 11 灰。
- 记忆点：三段整齐的入口行。
- 删掉什么：MANAGE hero 与长说明、描边卡分组、「公告发布」说明卡（缩为一行灰副行、不可点）、单独的「分享」「所有权」两段。
- 对照：OKX 4912 资讯行（图标 + 字 + ›）。

**创建社区（申请入驻弹层）**
- 色：Logo 槽 card 面 + line2 边；选中预设 Lime 环；主按钮 Lime。
- 字：标题 20 粗；输入 15；一行 11 灰。
- 布局：标题居中 → 72 圆 Logo 槽（未选为「+」）→ 12 枚预设 44 圆横排（含「不设置」）→ 四个 52 输入（名称 / 短链接 / 简介 / 绑定代币，规则在提示与错误里）
  → 一行 11 灰 → 整宽 Lime「提交申请」→ 文字「取消」。
- 记忆点：顶部 72 圆 Logo。
- 删掉什么：两段说明、带长括号的浮动标签、编号 chips、「绑定地址只做登记」说明。
- 对照：OKX 表单（整宽主按钮）。

**创建群组 `/chat/groups/create`**
- 色 / 字 / 布局：52 输入（无前缀图标、无计数）→「选择好友 n/N」→ 行（头像 36 + 名 16 + LOOP # 13 + 右侧 24 圆勾，选中 Lime）→ 整宽 Lime「创建群组」→ 一行 11 灰。
- 记忆点：右侧 Lime 圆勾。
- 删掉什么：NEW GROUP eyebrow、副标题、卡片包裹与分隔线、Checkbox、FilledButton。预览构建仍显示「开发预览」。
- 对照：OKX 列表行。

**语音房（直播中）**
- 色：底栏 quiet 圆键，麦克风开 / 举手为 Lime，结束 / 离开为 fall；「主持」Lime 小标；说话环 Lime。
- 字：主持人名 17；网格名 12；顶栏灰行 11。
- 布局：顶栏 返回 + 社区 Logo + 房名 + 一个图标（分享），灰行「N 在听 · 开播 x 分钟」（沿用广场 `liveVoiceRoomElapsedLabel`）；主持人 88 居中 + 名 + 「主持」，
  房间说明 (i) 在主持人区右上；发言者 56 四列；听众 44 五列（满 15 收「+N」）；空格为 `LoopEmptyState.compact`（voice-room / holders）；底栏 56 圆键。
- 记忆点：中央 88 主持人与底部一排圆键。
- 删掉什么：底栏顶部分隔线、一行灰字空态、顶栏第二个图标。最小化横幅不动。
- 对照：DeBox 布局（0115）+ OKX 圆键。

**公开资料页 `user-profile`**
- 色：圆键 Lime；「关注」描边胶囊；交易入账副行 rise。
- 字：名 22 粗；LOOP ID 13 tabular 灰；计数 16 / 13。
- 布局：头像 72 + 名 + LOOP ID（可复制）+ 右侧「关注」胶囊 → 简介 → 计数 → 圆键 加好友（已是好友时没有这把）/ 私聊（好友为「聊天」）/ 分享 / 更多
  → 持仓 / 交易 / 社区 分段；持仓与交易为 `LoopQuoteRow`；空态 `LoopEmptyState.compact`。
- 记忆点：头像旁的名字与一排圆键（Fomo 资料页的层次）。
- 删掉什么：顶栏「更多」齿轮（进了圆键）、三个等宽文字按钮、「没有更多交易」、更多弹层里的「分享名片」（进了圆键）。
- 对照：Fomo 头部 + OKX 行。

**关注与粉丝 `connections`（好友列表）/ 陌生人请求 `dm-requests`（申请列表）**
- 色：未关注「关注」Lime 胶囊、已关注描边；「接受」Lime 胶囊。
- 字：名 16 / LOOP ID 13。
- 布局：行 56 高、头像 40；请求行 64 高，右侧「接受」，点行弹出 忽略 / 举报并屏蔽；数量在顶栏灰行「N 个待处理」；空态 friends 插图居中。
- 记忆点：右侧一列胶囊。
- 删掉什么：SOCIAL CONNECTIONS / MESSAGE REQUESTS hero 与 `N NEW` 印章（及 `messageRequestsStamp`）、「行内算力」卡、「想被别人找到」说明卡（缩为一行 11 灰）、
  请求行下的「消息正文 / AI 巡查」两张不可用卡、三个等宽决定按钮。
- 对照：OKX 4910。

**生成页通病自检**：没有全大写 eyebrow、没有中点串装饰标题、没有数字编号装饰；每页一个记忆点；Lime 只用在主按钮 / 圆键 / 选中 / 角标 / 在线数；
近黑 + 酸绿是品牌既定不改；无 Emoji（新测试逐页扫描所有 Text / RichText）。

## 偏离

| 设计要求 | 落地 | 原因 |
| --- | --- | --- |
| 顶栏标题 20 粗 | 仍是 `LoopTopbar` 的 22（headingLg） | `LoopTopbar` 是共用旧件，本单只许加新文件；改它影响全部页面。建议主代理统一时一起改。 |
| 段标题 22 粗（§1.1.1 · 4） | 17（headingSm） | 二级页头部已有 22 名字，段标题再 22 会和名字抢；与钱包「资产」段标题（16）同一档。 |
| 社区主页只有 绑定代币 / 成员 / 社区 AI 三段 | 另保留「挖矿」卡，公告 / 官方链接有内容时出现 | 挖矿是该页数据主体之一（多条测试锁定其五态）；公告与链接是社区自己发布的内容，空时完全不画。 |
| 简介一行 | 两行省略 | 一行常截断到半句，两行仍不超过头部高度。 |
| 公开资料页三键（加好友或聊天 / 分享 / 更多） | 陌生人四键（加好友 / 私聊 / 分享 / 更多），好友三键（聊天 / 分享 / 更多） | 陌生人也能私聊（会成为对方的陌生人请求），去掉会少一个现有入口；「关注」改为头部右侧胶囊而不是圆键。 |
| 「更多」图标 | 复用 `keypad`（点阵） | 图标集没有「更多」；新加图标要改 `LoopIconNames` 与图标计数测试，S121e 并行时易冲突。 |
| 语音房顶部最多一个图标 | 分享留在顶栏；(i) 移到主持人区右上 | (i) 在服务商未确认时变 warning 色，是唯一的提示载体，不能删。 |
| 申请列表 | `dm-requests`（陌生人请求）| 产品里路由到的「申请列表」就是这一页（`/chat/requests`）；`FriendRequestsPage` / `FriendListPage` 没有路由，未改。 |
| 好友列表 | `connections`（关注与粉丝） | 同上，`/profile/connections` 是路由到的好友类列表。 |

## Consequences

- 社区主页对成员多一次 `GET …/members`（首页一页，取 12 张脸）；不再读绑定代币的 1H K 线。`s26` 读数断言由 2 改 3，`s79` 写命令断言过滤掉这次读。
- 听众网格上限 18 → 15（五列三行），`voiceRoomListenerGridLimit` 测试同步。
- 删除 `messageRequestsStamp`（`N NEW`）；`CommunityMiningPowerCard` 已无页面使用，组件保留，测试改为单独挂载。
- 未做：预览专用 `lib/features/chat/voice_room_page.dart`（只在开发预览路由出现，生产走 `VoiceRoomScreen`）；群资料页 `GroupInfoScreen` 的成员段；
  `FriendListPage` / `FriendRequestsPage` / `AddFriendPage`（无路由）；社区 AI 页。
- 截图核对：未用模拟器（另一代理占用），主代理合并后截图。
