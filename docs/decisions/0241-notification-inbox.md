# 0241 · 通知中心（聊天下的子页）+ 铃铛角标 + 推送四种新类型（S287-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 8d997bfd。主代理下单 S287-mobile，与 loop-api S286（eb02385，loop-api 决策 0177：写入方、未读数、全部已读接口，开关 `NOTIFICATION_INBOX_EMIT` 默认关）并行，已按 0177 定稿对齐。
不新增依赖，`pubspec.lock` 不变。不改 `lib/features/launch2/`（S285 在改）。不改十个偏好类别（AGENTS 规则 18）。不改 token 页与「我」页现有的通知读取。
**路由清单 113 → 114**（新增 `notifications`）。

## Context

需求方 2026-10-22 反馈第 10 条：「目前没有统一的通知页面或通知栏，无法集中查看代币毕业、勋章铸造完成、好友申请历史等通知。」

现状：通知 feed（`GET /v2/notifications/feed`）只有两个上下文读者——`alerts` 页 / token 页只读价格提醒，「我」页只读社区审核结果；推送点击由 `LoopNotificationCoordinator` 回读 feed 定位。没有一个页面列出全部通知。

## Decision

### 一、路由：`notifications` → `/chat/notifications`（偏离派单的 `/notifications`）

派单写的路径是 `/notifications`。这个字面量是决策 0050 / 0057 退役的 Home 时代独立通知中心，至今有四道护栏把它钉死：`LoopRouteManifest.retiredPaths` 与 `informationalRetiredPaths`、`scripts/check_harness.py` 的 `ROUTE_MANIFEST_RETIRED_LITERALS`（「None may be mounted, redirected or pushed」）、`test/route_manifest_test.dart` 三处断言（含「retired Home surfaces」组）。新页面是聊天 Tab 的子页，所以挂在 `/chat/notifications`：slug 照派单为 `notifications`，模块 `2-community`，`prototypeOrder` 127，`step` 4，标题「通知中心」。旧 `/notifications` 继续退役（记 info、落 MEME），已装旧客户端发出的这个地址也不会误入新页。若主代理仍要 `/notifications`，需要同时拆掉上述四道护栏，单独改即可。

清单变化：`docs/product/routes-manifest.json` count 113 → 114，sha256 重算为 `34c97032…f76f`；`route_manifest.dart` 同步（头注释、`2-community (21)`、sha256）；`check_harness.py` 与 `tests/test_check_harness.py`、`test/route_manifest_test.dart` 的 113 改 114。`LOOP/docs/routes-manifest.json`（主仓之外的镜像）未改，由主代理同步。

### 二、codec（`loop_v2_notifications_api.dart`）

1. feed 行 `type` 不再限于十个类别：类别照旧解析为 `LoopNotificationEntry.type`；`launch.graduated` / `launch.badge_minted` / `social.friend_request` / `social.friend_accepted` 解析为新的 `LoopNotificationKind`（各自归到一个现有类别，与 loop-api 0177 §A 一致：毕业 → `launch.graduation`，勋章 → `launch.round`，好友两种 → `community.mention`；只用于展示，不增加偏好开关）；其它未知 type 保留原串（`rawType`，形如 `^[a-z][A-Za-z0-9_.-]{0,63}$`，不符合则记 `unknown`），**不再让整页失败**。`type` 因此变为可空：按类别过滤的读者（价格提醒、社区审核、安全事件）看不到新类型的行，行为不变。
2. `readAt` 改为可选键：`null` = 未读；缺键 = 当已读（`readStateKnown = false`），不报错。其它键仍严格（多一个未知键仍是无效行）。
3. 新接口：`GET /v2/notifications/unread-count` → `{unread, observedAt}`；`POST /v2/notifications/read-all`（带 `Idempotency-Key`，keyring 签名 `notification:read-all`）→ `{marked}`。0177 定稿两者都不带 `contractVersion`；codec 容忍有无，有则必须是 `2.0`。read-all 的 `Idempotency-Key` 由 `LoopV2CommandKeyring` 生成（小写 UUIDv4）。**404 = 接口不存在 → 返回 `null`**（角标不画 / 全部已读改为逐条），其它失败照常抛。
4. 端口 `NotificationsGateway` 加 `loadUnreadCount()` / `markAllRead()`；生产适配器 `DioLoopV2NotificationsGateway`；Preview 内存网关两者都答 `null`（没有生产者，不画数字）；默认不可用网关照旧抛 unavailable。

### 三、推送 router（`loop_notification_router.dart`）

四种新类型加入 `LoopPushNotificationType`。按 loop-api 0177 §E，**推送 `type` 用下划线线名**，feed 行 `type` 用点号细分值，两者经 `feedType` 对应；四键 payload 与配对校验不变：

| type | entityRef 前缀 | contextRoute | feed 确认后 | 未确认 |
|---|---|---|---|---|
| `launch_graduated`（feed `launch.graduated`） | `launch2Instance:<uuid>` | `launch2-instance` | `/launch2/instance?id=<contextParams.instanceId>` | `/meme` |
| `launch_badge_minted`（feed `launch.badge_minted`） | `launch2Instance:<uuid>` | `launch2-instance` | 同上 | `/meme` |
| `social_friend_request`（feed `social.friend_request`） | `friendRequest:<uuid>` | `dm-requests`（contextParams `friendRequestId`，页面不用） | `/chat/requests` | 同左 |
| `social_friend_accepted`（feed `social.friend_accepted`） | `friendRequest:<uuid>` | `user-profile` | `/profile/user?id=<contextParams.publicProfileId>` | `/chat` |

`contextRoute` 只认上表的三个新 slug（加原有四个）；类型与 contextRoute 不配对、entityRef 前缀不对、未知类型仍一律 fail-closed。新增 `LoopNotificationRouter.resolveRecord(context)`：从一条 feed 记录（不经推送）解析目的地，与推送点击走同一套参数校验；contextRoute 不认识 → `null`。`lib/app.dart` 抽出 `_notificationContextOf(entry)`，推送回读 feed 与通知中心点击共用，保证同一条记录两边解析一致。毕业与勋章共享 entityRef，推送回读 feed 时按 entityRef **加** `feedType` 匹配行（旧四类 `feedType` 为空，仍只按 entityRef）。协调器加可选 `onNotificationObserved`：前台 / 后台 / 点击三种被接受的 LOOP 通知都触发一次角标刷新（不带 payload）。`check_harness.py` 的 kind / contextRoute / intent / 路由字面量白名单同步扩展（5 个新 intent：实例页、MEME、陌生人请求、个人主页、聊天）。

设备侧推送文案：按 0177 §E 补 `push.launchGraduated.*`、`push.launchBadgeMinted.*`、`push.socialFriendRequest.*`、`push.socialFriendAccepted.*`（`ios/Runner/Localizable.strings` 点号键；`android/.../values/strings.xml` 下划线键 `push_launchGraduated_title` 等），文案不点名任何对象，与既有五组同模式。

### 四、通知中心页（`notification_inbox_screen.dart`，index / stream）

- 顶栏：返回、标题「通知」、副标题「未读 N 条」（来自 feed `unreadCount`）、右侧「全部已读」（check glyph，只在有未读时出现）。
- 列表首行「通知设置」入口 → `notif-settings`。
- 按设备本地日历分「今天 / 更早」两组（空组不画），组内保持 feed 顺序。
- 行：左侧 8 dp 未读点（黄色 Lime，已读留空位对齐）、40 圆形 glyph、标题（未读 w700 Chalk / 已读 w400 text2）、正文一行省略、右侧相对时间。glyph：毕业 `graduate`、勋章 `crown`、好友申请 `user`、好友通过 `users`、价格 `chart`、安全 `shield`、社区 `community`、Launch `launch`、挖矿 `mine`、成交 `swap-vert`、未知 `bell`。文案只取行内事实：payload `title` / `body` 优先（0177 §B 四种新类型都带）；否则按类型拼（`symbol`/`ticker`/`projectName`、`tokenId`、`alias`/`displayName`/`nickname`/`loopId`、`threshold`/`observedValue`、社区审核沿用 `CommunityApplicationNotification`）。
- 点击：先 `POST …/read`（已读的不重写；失败不阻断跳转），刷新角标，再按 `resolveRecord` 跳转（Tab 路径 `go`，其它 `push`）；解析不到只标已读不跳。
- 全部已读：先调 read-all；返回 `null`（404）则本会话记住，逐条标已读当前已加载的未读行。成功 toast「已全部标为已读」，失败「没有标记成功，请稍后再试」。
- 下拉刷新、`LoopLoadMoreFooter` 沿用 feed 游标分页；五态走 `LoopChainStateBlock`（加载骨架 / 空态「还没有通知」/ 错误带重试 / 离线 / 无权限 / 不可用），Preview 显示「演示数据」。
- 独立 `NotificationInboxController`，不复用、不改 `NotificationFeedController`（token 页、alerts 页、「我」页读取不变）。

### 五、入口与角标

- 聊天 Tab 顶栏搜索框右侧加铃铛（`NotificationBellButton`），未读 > 0 右上角红色计数胶囊（复用 `LoopUnreadBadge`，> 99 显示 `99+`）；`null`（无适配器 / Preview / 接口 404 / 未读到）只画铃铛。
- 未读数（`NotificationUnreadCountController`，按账号作用域重建）刷新时机：铃铛首次出现、App 回到前台（`AppLifecycleListener`，**60 秒内只读一次**）、收到 LOOP 推送（强制）、通知中心标已读 / 全部已读 / 下拉刷新后（强制）。没有定时轮询。
- 「我」页「隐私与安全」组「通知设置」上方加「通知中心」行（`mail` glyph）。

## Consequences

- 截图：`docs/integration/S287/shots/`（`notification-centre.png`、`notification-centre-empty.png`、`chat-head-bell.png`），由 `test/s287_shots_test.dart` 生成（`--dart-define=LOOP_SHOTS=true`）。
- 测试：新增 `test/s287_notification_inbox_test.dart`（codec：新类型 / 未知类型 / readAt 三种 / 未知键仍拒 / unread-count 两种形态 / 404 容错 / 500 仍失败 / read-all 幂等键 / 负数拒；router：四种新类型各一例正例 + 一例 contextRoute 不配对反例、未确认回退、错前缀与未知类型、`resolveRecord`；页面：分组 + 未读点 + 粗体、点击已读 + 跳转、未知目的地只标已读、全部已读两条路径、设置入口、空态、错误重试、离线 / 无权限 / 不可用、加载、Preview、分页；角标：0 / 5 / 120→99+ / 404、点击、60 秒节流、Preview 不读），共享夹具 `test/support/s287_notifications.dart`。更新：`route_manifest_test`（114）、`profile_v2_pages_test`（通知中心行）、`s5_idempotency_test` 与 `s5_page_harness` 的假网关（新端口方法）。
- 发布顺序（0177 §4）：本版客户端发出且所有受支持版本能解码后，API 与 worker 才同时把 `NOTIFICATION_INBOX_EMIT` 切 on。
- 未覆盖 / 待定：`NOTIFICATION_INBOX_EMIT` 关闭时 feed 不出现新类型，页面仍可列出价格 / 安全 / 社区通知。token 页 `token_screen.dart:1463` 的「There is no standalone notification centre」注释按「不改 token 页」未动。
