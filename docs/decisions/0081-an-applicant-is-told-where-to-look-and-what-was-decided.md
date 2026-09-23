# 0081 · 申请人知道去哪里看，也知道被决定了什么

## Status

Accepted 2026-09-23。S79a，客户端。不新增路由，93 条路由清单不变。对齐已定稿的
后端 S79b（loop-api 决策 **0073**，契约见 `loop-api/docs/frontend-v2-community-api.md`
§3 / §4.1 / §4.2 / §4.3c / §4.4 与 `docs/frontend-v2-notifications-api.md`
§7.2–7.3）：`GET /v2/community/home` 必带 `owned` 分组、
`GET /v2/communities/{id}` 必带 `application`（owner 为对象、其他人为 `null`）、
`POST /v2/communities/{id}/resubmit`、两个新 feed 事件
`community.application.verified` / `community.application.rejected`，以及两个新
推送事件 `community_application_verified` / `community_application_rejected`。
另受后端决策 0072（token logo）牵连一处：见 §8。

## Context

2026-09-23 需求方裁决：创建社区的入口保持现状（`community-discover` 底部的
「申请入驻」），缺的是**申请之后的那一半**。在此之前，申请提交成功只留下一条
会自己消失的 Toast，「我的 → 我的社区」是一行不区分身份的计数，而社区详情对
它的所有者和对一个陌生人说的是同一句话。一个提交了申请的人没有任何地方可以
看到它的下落，被驳回时也不知道为什么，更不知道还能不能再提交。

后端决策 0073 补齐了事实：社区按当前 owner 分成 `joined` 与 `owned` 两组，同一
个社区只会出现在其中一组；review 事实（`submittedAt` / `reviewedAt` /
`rejectedReason`）只投给当前 owner；驳回后 owner 可以先改资料再重新提交；两种
结果都写一条 feed 行并可选推送。这份决策是设备这一侧怎么把它读出来。

## Decision

### 1 · 「我的社区」是两组，而且第二组可以不存在

`profile` 的 `我的社区` 从一行变成：

- **我加入的** —— 还是原来那一行导航（key `profile-open-communities` 未变），
  计数与副标题仍然只读 `joined`；它不再把自己创建的社区算进去，因为服务端已经
  不把它们放在那里了。
- **我创建的** —— 每个 `owned` 行一条：logo + 名称 + 状态胶囊，副行是
  「提交于 <本地时间>」，被驳回的行改印「驳回：<原因前 30 个码点>…」，因为对
  那一行的所有者来说，原因才是他能动手的东西。点击进这个社区的详情。

**没有创建过就完全不画这一组**，连标题都不画。一个空的「我创建的」会把每个从
来没申请过的账号都教成正在排队的人。

状态胶囊用 `CommunityApplicationBadge`：审核中是中性对，已通过是 Lime 对，
已驳回是这套配色里唯一的非 Lime 强调色（`LoopColors.danger`，16% 底 + 实色
字），几何与字体与 `LoopBadge` 完全一致。理由写在类文档里：「已驳回」放进中性
对会读成又一条元数据，放进 Lime 会读成一件好事。

措辞上 `communityApplicationStatusLabel`（审核中 / 已通过 / 已驳回）与既有的
`communityVerificationLabel`（已验证 / 审核中 / 未通过）是两件事，没有合并：
前者是申请人被告知的**对他的提交所作的决定**，后者是一个读者被告知的**这个社区
的属性**。

`owned` 行必带 `application`（0073），所以行不需要退路；模型仍把它留成可空，
因为 `OwnedCommunity` 也被本地/预览适配器构造，而解码器对线上载荷是严格的
（缺块、或 `application.status` 与 `community.verificationStatus` 不一致，都是
`invalidPayload`）。

### 2 · 社区 Tab 把两组读在一起

`community` 这一页是读者自己的社区索引。服务端一旦开始分两组，只读 `joined`
会让所有者自己创建的社区从这个 Tab 里消失。所以这一页把 `joined + owned` 读在
一起（分组仍按「带币社区 · 可挖矿」/「其他社区」），「查看全部」按
`joinedTruncated || ownedTruncated` 出现。**一行来自哪一组是「我的 → 我的社区」
要回答的问题，不是这一页的。**

### 3 · 社区详情只对 owner 多说两句

`application` 块是 owner-only，所以卡片也是：`CommunityApplicationStatusCard`
在 `review == null || !viewer.isOwner` 时画 `SizedBox.shrink()`，并且**从不**从
社区自己的 `verificationStatus` 推出状态——那是关于社区的事实，不是关于任何人
申请的事实。

- `pending`：hero 下第一张卡，「审核中 · 提交于 X」+「通过后开放挖矿权重与官方
  群。运维核验前，这个社区不带验证标记。」
- `rejected`：danger 语气，原因**完整印出**（列表行才省略），附「修改资料后
  重新提交」。
- `verified`：不画卡片。社区已经验证，记录本身已经说了。

### 4 · 重新提交是两条命令，而且保持两条

按钮走既有的「编辑社区资料」sheet → 确认 → `PATCH`（资料）→ `POST …/resubmit`
（审核）。`PATCH` 不碰审核状态，所以两步不能合并：**编辑失败就不提交审核**。
编辑内容为空时跳过 `PATCH` 直接重新提交——所有者可能认定驳回理由与他写的东西
无关，是否接受这份原样的申请是运维的判断，不是这一页的。服务端从非 `rejected`
状态回 `DATA_STALE`，页面据此刷新并说明，不假装成功。

顺带修掉一个既有缺陷：`showCommunityProfileEditSheet` 原来在 `whenComplete` 里
`dispose()` 两个 `TextEditingController`，而那是路由 pop 的时刻，退出动画还在
重建它拥有的 `TextField`。串起两个 sheet 的这个流程立刻撞上
「A TextEditingController was used after being disposed」。控制器移进一个
`State`，和申请表单同形。

### 5 · 申请成功后是一张 sheet，不是一条 Toast

`community-apply-submitted-sheet`：「申请已提交 · 审核中」，正文里写死一句
`communityApplicationProgressHint` =「可以在「我的 → 我的社区 → 我创建的」查看
审核进度。」，按钮「查看社区」关闭后才导航。它带的是一条指令，而会自己消失的
指令不是指令（决策 0079 §1）。

### 6 · 通知：一句中文、一个去处、一个更宽的载荷

- **应用内**：`CommunityApplicationNotification` 把一条
  `community.announcement` 行按 `payload.event` 读成两句话之一：「你的社区「X」
  已通过审核」/「你的社区「X」未通过审核」+「原因：…」。它是应用内、已登录、
  读的是本账号自己的 feed，所以可以指名社区、可以引用原因——这正是推送不能做的
  事。没有 `communityId` 的行不当作结果渲染（打不开的结果不是结果），没有名字
  的行说「你的社区」而不是把一个不透明 ID 印给人看。
- **画在哪里**：LOOP 没有、也不会有独立通知中心（红线 1），所以通知住在它所
  关于的那一页。这两条住在 `profile` 的「我创建的」正下方——裁决正是把申请人
  指到那里去等答案，而它们所关于的行就在上面。**只有 owned 非空才读 feed**，
  没申请过的账号不为一个永远看不到的区块付一次请求。读失败就什么都不画：上面
  那一组已经带着每个申请的权威状态，再报一次「通知读不到」是在为一个读者已经
  看得见的事实报错。
- **推送**：`LoopPushNotificationType` 加两个事件，共用
  `LoopNotificationContextRoute.communityProfile`；确认后的去处是
  `/community/profile?id=<feed 给的 communityId>`，未确认（feed 读失败、或这个
  账号没有这条通知）退到 `/community`——它不指名任何社区。loc-key 文案两种拼写
  都补齐（`push.communityApplicationVerified.*` 与 Android 的下划线写法），并且
  **一个字都不提社区名与驳回原因**：推送走在能授权读它们的会话之外。
- **载荷上界**：feed `payload` 的单值上界从 256 提到 512，并且**按码点计**。
  服务端的 280 码点原因若含星体字符就是 560 个 UTF-16 单元，按 `String.length`
  设的界会否掉它、并连带废掉整页 feed。

### 7 · 严格解码：缺失是契约破坏，半个事实也是

- `application` 在记录上**必带**；`null` 是非 owner 的答案，缺键是契约破坏。
- `owned` 分组**必带**；缺失是契约破坏，空 `items` 才是「没有创建过」。
- `owned` 行的 `application` **必带**，且 `status` 必须与同一行
  `community.verificationStatus` 同值（0073 明说两者同值）。
- 有块的时候按 0073 的配对严格校验：`pending` 不得带 `reviewedAt` 或原因，
  `verified` 必须带 `reviewedAt` 且不得带原因，`rejected` 必须带 `reviewedAt`；
  原因按 280 **码点**与 alias 字符规则校验。半个 review 无法被这一页叙述，
  所以是 `invalidPayload`，不是可以将就渲染的值。
- feed `payload` 单值按码点计到 512。

### 8 · 被 token logo（后端决策 0072）连带的一处

`GET /v2/search` 的 `displaySnapshot` 从这一步起**每个域都多一个必填 `logo`**
（资产行是 logo 投影，用户与社区行是 `null`）。搜索属于社区模块，严格 codec
不放行这个键会让整页搜索失败，所以这里把键加进 `loop_v2_search_api.dart` 的
键集合。**投影本身不在这里读**：它的主机白名单、monogram 回退与「每行每屏只试
一次」是 token logo 那条线的规则，那条线拥有每一个画 logo 的界面；在这里读一半
会变成同一条规则的第二份、更弱的副本。

## Consequences

- `profile` 在「我创建的」非空时多一次 `GET /v2/notifications/feed`；其余账号
  为零。
- `community` Tab 的行数不变（两组合读），但一个所有者的社区现在总是带着
  「审核中」/「未通过」的强调字，因为它不再被 `joined` 的「已验证」筛掉。
- 新增的 `LoopColors.danger` 用法是这套配色里第二处非 Lime 强调；
  `docs/ground-inventory.md` 的复查项照旧适用。
- 推送允许清单（`check_harness.py`）从三事件 / 三 contextRoute / 四 intent /
  两 route 字面量扩到五 / 四 / 六 / 四，每一处都写了为什么。

## 接线点与边界

1. `GET /v2/communities?membership=owned` **未接**：`CommunityMembershipFilter`
   没有加 `owned`，「我创建的」只读聚合（各 50 条）。`ownedTruncated` 为真时
   页面印一行说明而不是「查看全部」。契约里这一条存在（每行的 `application`
   挂在社区对象上），要接是一页目录 + 一个 seg 的活，不在本次裁决里。
2. `POST …/resubmit` 按 `200` + §4.4 社区记录实现，与 `join`/`leave` 同形。
3. feed 行的 `contextParams.communityId` 是打开记录的唯一依据；`payload` 里的
   `communityId` 只作兜底。`payload.reviewedAt` 不渲染：这一组行不印时间。

## Not done here

- 目录页的 `membership=owned`（见上）。
- 没有申请人与审核人之间的消息线程；驳回原因是单向的。
- 「我加入的」仍是一行导航而不是逐行列表——它不是这次裁决的内容，原型的
  `lists.communities` 逐行还原留给后续。
