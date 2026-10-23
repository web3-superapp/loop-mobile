# 0242 · 通知中心：发射审核 / 部署进度四种通知（S292-mobile）

## Status

Accepted 2026-10-23。基线 `integration/v2` 1a41a0b6。主代理下单 S292-mobile，与 loop-api S291（四种收件箱事件写入方，开关 `LAUNCH_REVIEW_INBOX_EMIT` 默认关）并行，契约以本文第一节为准，两边不各改各的。
不新增依赖，`pubspec.lock` 不变。不改十个偏好类别（AGENTS 规则 18）。**路由清单不变（114）**，`routes-manifest.json` / `route_manifest.dart` 未动。

## Context

项目方提交发射后，审核结果、上链、部署失败目前只能自己回「我的项目」看。S287（决策 0241）建好了通知中心与推送四键路由，本批把这四种进度接进去。

## Decision

### 一、契约（与 loop-api S291 共用）

feed 行 `type` = 下表 eventType（与 0241 的细分类型同一方式；所在偏好类别 `launch.round`「Launch · 资格快照与开始提醒」，只用于展示，不增开关）。推送四键 payload 的 `type` 是下划线线名，`eventVersion: "1"`。

| feed `type`（eventType） | 推送 `type` | `contextRoute` | `entityRef` | 文案（payload `title` / `body`，缺省时客户端用同句） | 点击目的地（feed 确认后） | 未确认 / 缺参数 |
|---|---|---|---|---|---|---|
| `launch.review_approved` | `launch_review_approved` | `launch2-project-sign` | `launchProject:<projectId>`（或 `launchTask:<taskId>`） | 「{项目名} 审核已通过」/「请完成签名，发射才会部署」 | `/launch2/project/sign?id=<projectId>` | `/launch2/projects/mine` |
| `launch.review_rejected` | `launch_review_rejected` | `launch2-projects-mine` | 同上 | 「{项目名} 审核未通过」/ 驳回原因 | `/launch2/projects/mine` | 同左 |
| `launch.activated` | `launch_activated` | `launch2-instance` | `launch2Instance:<instanceId>` | 「{项目名} 已上链」/ 开售时间 | `/launch2/instance?id=<instanceId>` | 推送：`/launch2/projects/mine`；通知中心行缺 instanceId：`/meme`（与 0241 同一 `launch2-instance` 规则） |
| `launch.deploy_failed` | `launch_deploy_failed` | `launch2-projects-mine` | 同第一行 | 「{项目名} 部署失败」/ 原因 | `/launch2/projects/mine` | 同左 |

- 所有 id 为小写 UUID（与 `Launch2CreatorRoute.isId` 同形）。`entityRef` 的 `<kind>` 前缀：项目三类认 `launchProject` 与 `launchTask` 两种（契约写的是「task/project id」，后端二选一即可）；`launch_activated` 只认 `launch2Instance`。
- `contextParams`：`launch.review_approved` 建议带 `projectId`；`launch.activated` 必须带 `instanceId`（与 0241 同键）。客户端取签名页项目 id 的顺序：feed 记录 `contextParams.projectId` → 记录自身 `entityRef` 为 `launchProject:<uuid>` 时取其 UUID → 都没有则落「我的项目」。**推送 payload 永远不提供 id**。
- payload 其它可选键：`projectName`、`symbol`、`taskId`、`instanceId`、`reasonText`、`saleStartAt`（RFC3339）。客户端缺省文案只用 `projectName`（无则 `symbol`）、`reasonText`、`saleStartAt`（按设备时区格式化为 `YYYY-MM-DD HH:mm`，解析失败不显示）。没有项目名时标题为「发射审核已通过 / 发射审核未通过 / 你的发射已上链 / 发射部署失败」。
- 注意 `launch2-projects-mine` 是契约里的线名，清单 slug 是 `launch2-projects`；两者不必一致（contextRoute 名的是目的地家族，不是清单条目）。线名 `launch2-projects` 不被接受（测试覆盖）。
- 设备侧推送文案（规则：不点名任何对象）：`push.launchReviewApproved.*`「发射审核已通过 / 点开完成签名」、`push.launchReviewRejected.*`「发射审核未通过 / 点开查看原因」、`push.launchActivated.*`「发射已上链 / 点开查看项目」、`push.launchDeployFailed.*`「发射部署失败 / 点开查看原因」（iOS `Localizable.strings` 点号键；Android `push_launchReviewApproved_title` 等）。后端 `titleLocKey` / `bodyLocKey` 用这四组键。

### 二、路由规则（照 0067）

- `LoopPushNotificationType` 加 `launchReviewApproved` / `launchReviewRejected` / `launchActivated` / `launchDeployFailed`，各带 `feedType`；`LoopNotificationContextRoute` 加 `launch2ProjectSign`（`launch2-project-sign`）、`launch2ProjectsMine`（`launch2-projects-mine`）。新增 `alternateEntityPrefix`（只项目三类用 `launchTask`）。
- 推送只产生指针；点击后 `lib/app.dart` 重读 feed，按 `entityRef` **加** `feedType` 匹配行（审核通过与部署失败可能共用同一 `launchProject:` 引用，激活与毕业 / 勋章共用 `launch2Instance:`）。记录的 `contextRoute` 与指针家族不一致视为未确认。
- type / contextRoute 不配对、前缀不对、非 UUID、点号形式的 type、未知 type、多一个键，一律 fail closed（`malformed`）。老九种规则不变。
- 新增两个 intent：`LoopLaunchProjectSignNotificationIntent`（`/launch2/project/sign?id=…`，id 先过 UUID 校验）与 `LoopLaunchProjectsNotificationIntent`（`/launch2/projects/mine`，不带任何标识）。签名页按 `?id=<projectId>` 接收（`Launch2CreatorRoute.sign`），进页后自己读项目与审核状态，通知不携带任何状态。
- `LoopNotificationRouter.resolveRecord` 同步认两个新 contextRoute，通知中心点击与推送点击走同一套校验；`_notificationContextOf` 增加 `projectId`（`contextParams.projectId` ?? `LoopNotificationRouter.launchProjectIdOf(entityRef)`）。
- `check_harness.py` 白名单同步：kind +4、contextRoute +2、intent +2、路由字面量 +2、`PUSH_COPY_EVENTS` +4。

### 三、通知中心行

图标：审核通过 `key`（待签名）、审核未通过 `blocked`、已上链 `launch`、部署失败 `warn`。payload `title` / `body` 优先，缺省按第一节文案；未读点、粗体、分组、点击先标已读等沿用 0241。未知 eventType 照 0241 以 `bell` 平铺，不影响列表。

### 四、通知设置

四种归 `launch.round`。该行补说明「含共识勋章、发射审核结果与上链进度」，`deliversToday` 仍为 `false`、行尾照旧「暂不生效」：后端 `LAUNCH_REVIEW_INBOX_EMIT`（以及 0241 的 `NOTIFICATION_INBOX_EMIT`）默认关，今天不会真的发。开关在 staging 打开并真机见到后，再单独改这一行与顶部汇总句。关闭确认弹窗原本拿 `detail` 当正文，这一行改为专门一句「关闭后不会再收到共识勋章、发射审核结果与上链进度通知。」（`notificationDisableBody`，`test/s99_chat_feedback_test.dart` 同步）。

## Consequences

- 测试：新增 `test/s292_launch_review_inbox_test.dart`（33 例：kind / codec 四种 + 未知类型；行的呈现——服务端文案优先、缺省文案、无项目名、坏 `saleStartAt`；页面四行 + 未知行；四种点击目的地与未知行只标已读；签名页 id 取法与 `launchTask` 回退；推送四对配对通过、每种与其它 contextRoute 错配 fail closed、`launchTask` 前缀、错前缀 / 非 UUID / 点号 / 未知 / 第五键 fail closed、未确认回退、老规则不变；设置行文案与「暂不生效」）。
- 发布顺序：本版客户端发出且所有受支持版本能解码后，后端才把 `LAUNCH_REVIEW_INBOX_EMIT` 切 on。旧客户端遇到这四种 feed 行按 0241 当未知类型平铺（`bell`，点击只标已读）；遇到这四种推送 fail closed，不跳转。
- 未覆盖：真机推送送达、`lib/app.dart` 的 feed 回读匹配只经现有 coordinator 测试间接覆盖。
