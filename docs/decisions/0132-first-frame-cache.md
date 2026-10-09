# 0132 · 首屏与缓存：会话、冷启动列表、接收页、交易历史、本人头像（S123f）

## Status

Accepted 2026-10-09。主代理下单（S123f，审查 `docs/integration/review-2026-10-09/s123-interaction-audit.md`
的 M11、M12、m19 与 §五 规则 20「本地数据页首帧不出骨架」；截图 `docs/evidence/2026-10-09-s123/` 02、04→05、20、56→56b、
62→62b、81）。基线 `integration/v2` e6749fd。不新增依赖、`pubspec.lock` 不变、路由清单不变（slug 与 path 均未动）。
不改视觉 token。

## Context

真机走查里有三类「像网页」的首屏：

- 会话：从聊天列表点进社区群，标题先是「暂无名称」、正文先是骨架 1–2 秒——列表那一行用的 `Channel` 对象（含最近 25 条消息）
  明明已经在 Stream 客户端里，但会话页先等社区记录（HTTP），再等一次成员资格查询（`queryChannelsOnline`），才挂 Stream 界面。
- 冷启动聊天列表：`StreamChatPersistenceClient` 早已接上，但只有在 bootstrap → Stream token → WebSocket 全部完成后列表才挂载，
  之前是「正在连接会话」卡片，之后又是 Stream 的骨架；本机的离线副本首帧没用上。
- 钱包：接收页的地址与二维码对一个钱包是不变的，但每次进入都先出 2–3 秒通用列表骨架；交易历史的骨架是 44 圆角方块 + 两行，
  真实行是 36 圆形标记 + 两行 + 右侧金额/时间两行 + chevron，且骨架阶段没有筛选条，数据一到整页跳动。
- m19（minor 全表「头像首字母↔图片不一致（81/02/20）」）：冷启动顶栏是「CY」首字母、稍后变图片；「我」页同一个人又是首字母。
  原因有二：资料未读到前无可画之物；`LoopRemoteAvatar` 按槽位尺寸 `ResizeImage`，图片缓存以尺寸为键，40 与 56 是两份解码、
  两次下载，一处已是图片时另一处仍是首字母；且没有磁盘缓存，每次冷启动都重新下载。

## Decision

### 会话缓存优先（`LoopStreamMemberChannelBody`，私聊 / 群聊 / 社区群共用）

- 新增 `loopStreamCachedMemberChannel(client, cid, userId)`：只有客户端里已加载状态、且其 `membership`（或缺省时已加载的成员切片）
  点名本账号的 channel 才算；不读网络、不读磁盘。
- 有这样的 channel 时首帧直接画会话；成员资格查询照旧在后面跑（同一个 `Channel` 对象被原地更新，不重挂）。查询失败（离线等）
  保留已画的消息；查询明确答「不是成员」时仍然关闭会话、显示原有的阻断块。没有缓存时行为不变（「正在确认…」块）。
- `_LoopChannelBody` 挂 `GlobalKey`，置顶权限包装出现/消失或答复替换缓存时不丢输入框与列表位置；出站排序器对同一 channel 只挂一次。

### 会话标题随路由首帧就有（社区群）

- 新增 `LoopChatRouteHeading`（`lib/core/navigation/stream_channel_route.dart`），作为 typed extra 传递，不进 URL。
- 聊天列表点社区行时直接 push `loopChatLocationForCid(cid)`（`/community/chat?id=`）并带上该社区名——经 `/chat/channel/:cid`
  redirect 会丢 extra（go_router 17 `_getNewMatches` 不带 extra）。私聊行、无法命名的行保持原路径（harness R15-1 不变）。
- `communityChatTitle`：社区记录的名字 > 路由 heading > 本账号已读到的社区脸（`communityFacesProvider`）> 「社区群聊」。
  「暂无名称」不再出现在会话标题上。
- 社区记录未答复（loading）且客户端已持有该社区官方频道时，页面先挂 Stream 表面（同 key、同位置），记录到达后由记录决定
  去留（同步中 / 不可用照旧切到阻断块）。记录答复前置顶权限一律为否；搜索按钮用缓存 cid 即可出现。

### 冷启动聊天列表先画本机副本

- `StreamChatClientPort.openLocalHistory(identity)`：在拿 token、连 WebSocket 之前先为服务端下发的 Stream 身份打开本机持久化
  （`openPersistenceConnection`，之后 `connectUserWithProvider` 发现已打开即复用）。打不开不影响连接。
- `StreamChatSdkSessionAuthorizer.localHistoryUserId`（`ValueListenable`）：打开成功即发布该身份；换账号、登出、断开、失败、
  销毁时清空。它不授权任何操作。
- 聊天 Tab 在授权 loading 期间若有本机副本：挂同一个 `_StreamChannelListBody`（同 key `stream-chat-list-<id>`），控制器换成
  `LoopLocalChannelListController`——只用与线上列表相同的 filter/sort 读本机存储，不订阅事件、不翻页；行可点开会话，但没有横滑 /
  长按动作，下拉不重读。读到的行作为线上控制器的首值（`StreamChannelListController.fromValue`），连接完成切换时同一批行不经骨架。
  本机副本为空或读失败时保持加载形状，不显示「还没有会话」（只有服务端能这么说）。
- 什么都没有时（首次安装）：「正在连接会话」卡片换成与会话行同形的 `ChatInboxRowsSkeleton`（40 头像、名字 + 时间、预览行，
  与 Stream tile 的 4+12 内边距一致），`StreamChannelListView.loadingBuilder` 用同一个骨架。

### 接收页即时（M12）

- 新的快照资源 `wallet.receive.<walletId>`：接收答复由传输层原样记入快照（`DioLoopV2WalletApi.decodeReceive` 为线上与快照共用的
  严格解码器），`WalletReceiveController.snapshotResource` 指向它。
- 「稳定资源」：`LoopSnapshotResource.isStable`（接收地址、本人脸）。稳定资源的有效期 `stableMaxAge` 30 天（其余仍 10 分钟），
  且同一次运行内可重复还原——旧的一份地址仍是这个钱包的地址；线上读取照旧在后面确认并替换。快照上限 16 → 24 条。
- 本机从未拿到过接收答复时，加载态换成接收页同形骨架 `WalletReceiveSkeleton`（网络 chip、232 码板、地址胶囊、两个按钮）。

### 交易历史骨架同形（M12）

- 首页加载时先画真实的筛选条（不依赖答复），下面是 `WalletActivitySkeleton`：56 高、36 圆形标记、16/13 两行、右侧 16/11
  金额与时间、chevron 位；「继续加载」占位行用同一组件。key `tx-history-state-loading` / `tx-history-loading-more` 不变。

### 本人头像一致（m19）

- `ownerFaceProvider`：资料已答复用资料；未答复用上次运行记下的 `profile.face`（别名 + 头像引用，仅展示，资料编辑器从不以它为准）；
  每次资料答复都重新记下。聊天顶栏与情报榜「我」那一行改读它。生产经新的 `loopSnapshotRecorderProvider` 写入当前账号的快照会话。
- `LoopRemoteAvatar` 一律按 256 px（`loopMediaDecodeSide`，fit）解码：所有槽位共用一份图片缓存，一处画出后别处首帧即是图片。
- `LoopMediaImage`：媒体地址内容寻址且不可变，字节存到应用缓存目录（`loop_media_v1/`，文件名为地址的 FNV-1a，不含地址），
  冷启动直接从磁盘画；缺失或读写失败退回下载（与原 `NetworkImage` 相同的无凭据 GET，200 且 ≤4 MB 才算）。未加依赖。

### Harness（`check_first_frame_cache_contract`，规则 20）

- 会话体保留缓存优先分支与 `GlobalKey`；社区群标题经 `communityChatTitle` 且不得引用 `communityMissingName`；聊天列表保留本机副本
  模式、种子与同形 loadingBuilder，且不得再有「正在连接会话」；授权器保留 `openLocalHistory`；接收控制器保留快照资源；
  钱包页保留两种同形骨架；`LoopRemoteAvatar` 保留共用解码且不得回到 `resizeIfNeeded`；聊天顶栏读 `ownerFaceProvider`。
  `tests/test_check_harness.py::FirstFrameCacheContractTests` 覆盖通过与各失败路径。

## Consequences

- 冷启动时聊天列表在 bootstrap 身份到达后即画本机副本，token 与 WebSocket 的时间不再是空白；bootstrap 本身（一次 HTTP）
  仍在前面——要连它也省掉，需要把 Stream 身份落盘，属于身份存储决策，本单未做。
- 本机副本阶段，自己发的最后一条消息预览暂时不带「你:」前缀（Stream 的 `currentUser` 要到 token 之后才设置），连接后补上。
- 会话页在成员资格查询失败时保留已画消息而不再整页换成离线块；发送由 Stream 自己的发送队列处理。
- 接收页与本人脸的快照最长保留 30 天；登出清空快照存储的行为不变。媒体磁盘缓存不随登出清除（内容寻址的公开图片，无账号信息）。
- 未在模拟器 / 真机验证：冷启动列表、会话首帧、头像磁盘缓存、接收页需主代理在真机上核对（本单按要求只跑 widget 测试与 debug 构建）。
