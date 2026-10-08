# 0112 · 真实身份进聊天、公开资料页 `user-profile`、注册改版与推荐社区 `onboarding-communities`（S109a）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S107-social-identity.md` §2–§5），S109a 实施。
基线 `integration/v2` a167b55。对接后端 S107（loop-api 决策 0095，前端契约
`docs/frontend-v2-social-api.md`）。新增一个直接依赖 `image_picker` 1.2.3（`pubspec.lock` 里只把它从
transitive 改为 direct main，版本不变）。路由清单 97 → 99。

## Context

1. 需求方 v3（`LOOP/docs/09` §2、§6.1 第 2/3 条、§6.2 第 6/7/8 节）取消匿名展示：每个人在聊天里显示
   真实头像与用户名，头像可点进公开资料页（持仓、交易、关系动作）；持仓与交易默认公开、可关；注册结束
   后只有一页推荐社区。
2. S109a 之前：社区群聊显示服务端化名（决策 0055 的 `viewerPersona`），小群显示群内昵称（决策 0107），
   没有「别人的资料页」路由，注册页是预设头像网格 + 兴趣多选，头像不能上传，隐私页四个可见性 facet 各自
   一个开关外加「匿名模式」开关。

## Decision

### 1. 路由与清单

- 新增 `user-profile`（7-profile，`/profile/user`，`?id={publicProfileId}` 或 `?loopId={LOOP ID}`，
  prototypeOrder 104，record / stream）与 `onboarding-communities`（0-global-account，
  `/auth/communities`，prototypeOrder 105，action / stream）。
- `docs/product/routes-manifest.json` 与 `LOOP/docs/routes-manifest.json` 同文件：count 99，
  canonical `sha256` = `6b6a3017f473697082b5d3b3efaf0f2a259959636511468f147cc7e1daee5f97`
  （文件本身 SHA-256 `75f8ef04dc4faf47dce72388212b33625073deab62d4081f3bcdad9d33a7df72`）。
  `lib/core/navigation/route_manifest.dart` 同步，`test/route_manifest_test.dart` 断言两者一致。
- 深链 `/u/{loopId}`（决策 0104）改为打开 `user-profile`（by-loop-id），不新增路由；账号未落地时先
  保留，落到聊天后再推入。
- 看自己的资料（LOOP ID 是本账号）→ `pushReplacement('/profile')`，即「我」。

### 2. 特性开关（`lib/core/config/loop_feature_switches.dart`）

| 开关 | 值 | 含义 |
| --- | --- | --- |
| `communityChatRealIdentity`（新） | `true` | 社区群聊以真实 Stream 用户（name / image，头像可点）展示；与后端 `COMMUNITY_CHAT_REAL_IDENTITY` 同名同义。为 `true` 时群聊顶部「你在这个社区显示为 …」不显示。改 `false` 回到化名展示。 |
| `anonymousModeVisible`（新） | `false` | 隐私页「匿名模式」开关 UI 下线；字段仍原值随保存回传（后端字段保留，排行榜 / 语音房的匿名分支不动）。改 `true` 即恢复。 |
| `groupAliasVisible`（既有） | `false` | 不变。 |

联动规则 `LoopFeatureSwitchValues.realIdentityFor(communityChannel:)`：社区官方群跟随
`communityChatRealIdentity`；小群跟随 `!groupAliasVisible`（群内昵称隐藏时唯一能画的就是账号自己的
名字）；私聊恒为真实身份。合并长图同一规则：真实身份会话里发送者显示 Stream 用户名、副标题「显示发送者
用户名」，其余会话仍是「匿名成员」 / 「默认匿名」。Stream 组件构建器没有 `ref`，经
`loopFeatureSwitchesOf(context)` 读取，无 ProviderScope 时回落到常量。

### 3. 头像媒体

- 引用解析：`avatar:media/{uuid}` 与 `logo:media/{uuid}` → `{baseUrl}/v2/media/{id}.webp`
  （`LoopV2MediaUrlResolver`，取 `loopBackendEndpointProvider` 的 origin）。公开、不可变资源，不走 Dio、
  不带 header，交给 Flutter 图片管线缓存；无后端端点时解析为 `null`，回落到首字母头像。
  `avatar:preset/*` 旧逻辑不变，旧预设头像用户照常显示。
- 社区 logo 校验放开接受 `logo:media/{uuid}`；资料写入的 `avatarRef` 放开接受 `avatar:media/{uuid}`。
- Stream 用户的 `image` 只接受绝对 `https`（非 release 构建另接受 loopback `http`），其它一律不画。
- 上传：`image_picker`（相册，`maxWidth` 2048，`imageQuality` 92）→ 客户端方形裁剪
  （`avatarCropOutputEdge` = 768，PNG）→ `POST /v2/media/avatars` multipart 单字段 `file`，带 bearer、
  `X-Loop-Contract-Version` 与 `Idempotency-Key`（写请求头）；客户端先拒 > 5 MiB。201 体严格解码，
  `ref` / `url` 必须与 `mediaId` 一致。失败按状态码归类：404 / 503 → 上传不可用，429 → 太频繁，
  400 / 413 / 415 / 422 → 图片被拒，连接 / 超时 → 离线。
- 新依赖：`image_picker` 1.2.3（设备适配器 `lib/integrations/device/image_picker_avatar_source.dart`，
  只在 `main.dart` 组合）。Preview 不组合上传与频道免打扰（没有服务端保存图片、没有 Stream 可免打扰），
  显示不可用。

### 4. 公开资料页 `user-profile`

- 头部：头像、别名、LOOP ID + 复制、简介、关注 / 粉丝 / 社区计数。动作行：加好友 / 已发申请 / 处理申请 /
  已是好友、私聊、关注 / 已关注；溢出菜单：删除好友（确认后 `DELETE /v2/friends/{id}` 再重读）、拉黑
  （已拉黑显示「你已拉黑对方」+「解除」）、举报并屏蔽（见偏离表）。
- 页面五态：loading / 404 `PROFILE_NOT_FOUND`（独立空态「账号不存在，或对方的资料对你不可见」）/
  unavailable（404 其它码与 503，不回退夹具）/ offline / permission。
- 页内三 Tab 各自三态：
  - **持仓**：`available` → 总额（全部有价才给，否则「暂无报价」）+ 列表（Logo / 符号 / 余额 / 美元值，
    无价显示「暂无报价」），空列表 =「还没有持仓」；`hidden` →「对方未公开持仓」（资料 `visibility.holdings`
    为 false 时不发请求）；`unavailable` → 按 `reasonCode`：`WALLET_NOT_BOUND` →「对方暂无钱包」，其它
    （`BSC_READ_UNAVAILABLE` / `WALLET_RUNTIME_UNAVAILABLE` / 未知）→「持仓暂时读不到 · 链上数据暂不可用，
    这里不会显示 0 代替」。
  - **交易**：同三态与同一 `reasonCode` 规则；列表买入 / 卖出 / 转入 / 转出，滚动分页（首页 `limit=20`，
    之后原样传 `nextCursor`，同游标回传即视为结束），追加失败给「重试」。`blockTimestamp` 为 `null` 时行副标题
    显示「区块 #{blockNumber}」。
  - **社区**：只显示「已加入 N 个社区 · 社区列表暂未开放查看」（见偏离表）。
- 入口统一：搜索结果、社区成员页、聊天头像都进此页；原底部弹层只保留给成员页的治理动作（任命 / 禁言 /
  封禁），弹层里加「查看资料」入口。

### 5. 注册改版与推荐社区

- `loop-id-setup`：首字母默认头像 +「上传头像」/「用默认头像」（与 `profile-edit` 共用 `LoopAvatarEditor`）、
  用户名（= 别名，1–40）、简介（可空，激活体不带 bio，激活成功后立刻一次资料 replace 写入；失败只标
  `bioSaveFailed`，不回滚激活）、LOOP ID 展示与复制。去掉预设头像网格与兴趣多选；`interests` 字段保留在
  激活体里，恒为空列表。
- 激活成功 → `context.go('/auth/communities')`。`onboarding-communities`：读
  `GET /v2/communities/recommended`（`defaultSelectedIds` 预勾选，必须是 `items` 子集），读完推荐后
  滚动接全部社区目录（目录接口自己的分页）；推荐为空也直接进目录。「进入 LOOP」按列表顺序逐个 join 已勾选
  社区并对其频道调用 Stream `mute()`；单条失败逐条提示（join 失败 / 已加入但免打扰失败），不阻塞其余；
  全部成功自动进入聊天，有失败时停在本页，按钮变「继续进入 LOOP」，点了直接进 `/chat`（不重试）。
  一个都没勾选时「进入 LOOP」直接离开。「跳过」直接进 `/chat`。页面标题「加入社区」。
- `profile-edit` 用同一头像组件，按 §6.2 第 7 节重排（标题 + 分组 + 底部固定主按钮）。

### 6. 隐私页

- 「可见性」组第一行是单开关「公开持仓与交易」：开 = `totalAssets` 与 `tradeHistory` 同时 `everyone`，
  关 = 同时 `self`，一次保存提交完整值。只有两者都是 `everyone` 时显示为开；两者不一致时显示为关，
  点一下两者都变 `everyone`。`miningPower` / `communities` 保留各自开关。
- 「匿名模式」开关隐藏（`anonymousModeVisible = false`），值原样回传。

## 与 S107 契约的偏离

| # | 项 | S107 §2–§5 | 本批实现 | 原因 / 后续 |
| --- | --- | --- | --- | --- |
| 1 | holdings / trades 响应体 | `{ status, totalUsd, items, observedAt }`；trade 有 `blockTimestamp` | 按后端 0095 实际交付解码：两个体都带 `reasonCode`（仅 `unavailable` 时非空），trade 多 `blockNumber`，`blockTimestamp` 可为 `null` | 后端是附加字段；客户端严格解码，不对齐会让每个真实响应都判无效 |
| 2 | 聊天头像 → 资料页 | 群聊头像可点 | 私聊头像可点（私聊投影自带 `publicProfileId`）；社区群 / 小群里头像画真实名字和图，但只有 Stream 用户带 `publicProfileId` 自定义字段时才可点 | 后端 0095 的 Stream 投影只有 `{ id, name, image }`。**需要后端在 Stream 用户上补 `publicProfileId`**（公开 ID，无隐私问题），客户端已按该字段名读取，无需再改 |
| 3 | 社区 Tab | 「公开时列已加入社区」 | 只显示计数 +「社区列表暂未开放查看」 | 契约没有「某人的社区列表」读接口 |
| 4 | 举报并屏蔽 | 复用 message-request 的 `report` 决策 | 显示「举报通道暂未开放；需要时可以先拉黑」，不调用接口 | `report` 只能作用于一条存在的消息请求，资料页上的陌生人没有；不假装已举报 |
| 5 | 不可用重试 | `BSC_READ_UNAVAILABLE` 可重试 | 分区 `unavailable`（服务端答复的，或 404 / 503 传输失败）不给重试按钮；离线 / 意外错误走共享状态块，有重试；重进页面即重读 | 待真机验收决定是否加 |
| 6 | 默认头像 | `avatar:preset/monogram` | 「用默认头像」把 `avatarRef` 置 `null`，客户端画首字母 | 后端对 `null` 同样显示首字母；不新增写入值 |
| 7 | 推荐页分页 | 每页 8 条 | 推荐整批一次画完，之后接社区目录接口的默认页大小 | 推荐接口不分页（≤ 50 条）；目录分页沿用既有实现 |
| 8 | 上传格式 | jpeg / png / webp / heic | 裁剪后统一 PNG 上传 | 客户端裁剪由 `dart:ui` 编码，只能出 PNG；后端统一转 WebP，HEIC 解码问题因此规避 |
| 9 | `interests` | 不传 | 激活体里恒为 `[]` | 激活体结构保持不变，空列表与不传等价 |

## Consequences

- 决策 0055 的社区化名展示、`docs/product/implementation-constraints.md` 里「合并只渲染 `匿名成员`」在
  `communityChatRealIdentity = true` 时被本决策取代；代码与表都不删，开关改回即恢复。
- `test/support/legacy_chat_identity.dart` 为钉死旧化名行为的既有测试提供关开关的 pump。
- 新测试：`test/s109a_chat_real_identity_test.dart`、`test/s109a_media_avatar_test.dart`、
  `test/s109a_onboarding_communities_test.dart`、`test/s109a_public_profile_test.dart`；
  `scripts/check_harness.py` 的隐私页必需证据改为「Preview flips 公开持仓与交易, then saves both facets
  once」。
- 待后端：Stream 用户补 `publicProfileId`（偏离 2）。待主代理：`LOOP/docs/00` §4.1「无 onboarding」按
  S107 §5 改为「注册后仅一页推荐社区」（不在本仓库）。
- 未验证：真机相册选图与裁剪、真实上传、真实 Stream 免打扰、真实链上持仓 / 交易分类（RPC 额度）。
