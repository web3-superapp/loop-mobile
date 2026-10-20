# 0214 · 邀请中心、头像可点进主页、邀请深链 `/i/{code}`、挖矿用词统一（S239-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` faaccbc7。依据：需求方 docs/42 第 3 条（a. 对方头像都可以点击查看；b. 行情 - 推广应显示邀请相关功能），
用户裁决「邀请奖励只有算力加成」；loop-api 决策 0162（S239-api：launch2 成交 `account`、邀请中心、`GET /v2/referral/invitees`、`/i/{code}` 落地页、AASA
`/i/*`）与 0166（`LAUNCH2_TRADER_ACCOUNT_EMIT` / `REFERRAL_CENTER_EMIT` 默认 `off`）；App 决策 0209（S249 已落可选键）。

不新增依赖、字体、颜色 token；`pubspec.lock`、`docs/product/routes-manifest.json` 与 `route_manifest.dart` 都不变。新增一条请求路径
`GET /v2/referral/invitees`（新路径，不受 0209「不改键集」约束）。

## Context

- 需求方 2026-10-19：「所有头像都能点进主页」；「行情 - 推广」改为邀请中心（邀请码、邀请链接与海报、我的邀请列表、五级人数、推广榜）。
- 后端 S239-api 已在 `integration/v2` 4cb7311 就绪；`inviteLink` / `stats` / 可用 `boost` 与 launch2 `account` 关在 0166 的两个默认 `off`
  开关后，S249（0209）已把这些键落成可选键。本单只做页面，不改既有键集；`GET /v2/referral/invitees` 是新路径，新增解码。
- 现有推广页只有邀请码、按状态计数、恒为 unavailable 的加成；情报「推广」chip 只有推广榜；launch2 成交 / 动态只有地址；
  多处列表头像没有手势。挖矿页面里「Mining Power」「推广算力」「邀请关系加成」「挖矿权重」混用。

## Decision

### A. 邀请中心（manifest `referral`，路由仍是 `/profile/referral`）

- 标题由 `Referral Boost` 改为「邀请中心」；archetype `record`、布局 `dashboard`。
- 自上而下：邀请码大字 hero（L1–L5 加成格在同一张卡里）→「复制邀请码」（主按钮）/「生成海报」→ 邀请链接（`inviteLink` 有：可点复制 +
  「分享邀请链接」走系统分享；无：一行说明只发邀请码）→「我的邀请」三格（直接邀请 / 有效成员 / 二至五级；`stats` 缺省全部为 `—` 并说明统计
  尚未开放；`validAsOf` 写「截至」）→「邀请加成」（`boostAvailable` 有：最近结算小时的 `referralPower` 与五级有效成员、NFT / 资产两轨，单位
  是算力；无：沿用 unavailable 卡）→「邀请列表」（`GET /v2/referral/invitees`，按「查看更多」翻页，行 = 头像（可点）、昵称、加入时间、
  有效 / 待生效 / 已失效）→「关系深度如何计算」（原有）→「推广榜」（独立读 `referrals` 榜第一页起，按「查看更多」翻页，行可点进主页）→
  「我的邀请人」与绑定（原有）→ 规则脚注。
- 0162 §5：真机验证前「分享邀请链接」不作主入口，所以主按钮是复制邀请码，链接分享是次按钮。
- 海报：360 × 640 布局、`pixelRatio 3` 导出 1080 × 1920 PNG；Ink 底、LOOP 字标、邀请码（黄色关键数字）、二维码（仓库自带 `LoopQrCode`
  编码 `inviteLink`；无链接时不画二维码只印码）。输出走既有 `chatMergeExportSinkProvider` 系统分享面板；仓库没有写相册的插件，保存到相册由
  系统分享面板（iOS「存储图像」等）完成，不新增依赖。
- 五态：总览读取 loading / empty / error / offline / permission / unavailable 用既有 `LaunchStateBlock`（`referral-state-*`）；邀请列表与推广榜
  各自有独立的状态块（`referral-invitees-state-*`、`referral-board-state-*`），失败不拖垮整页。

### B. 情报 ·「推广」页签 → 「邀请中心」

- 第三个 chip 的文字改为「邀请中心」；选中后在「我的名次」账本卡与 chip 下面先画邀请块（我的邀请码 + 复制 / 海报 / 链接 + 我的邀请三格 +
  「打开邀请中心」进 `/profile/referral`），再画原有推广榜（领奖台、比例条、来源行都不变）。
- 不新增路由：完整页面复用 `/profile/referral`。

### C. 头像可点进主页

统一组件 `lib/features/social/profile_face_link.dart`：`loopProfileFaceLocation(id, isSelf)` —— 自己 → `/profile`（我），别人 → `user-profile`
（`/profile/user?id=`），没有公开资料 id → `null`；`LoopProfileFaceLink` 在 `null` 时原样返回子组件（不加手势、不加按钮语义），否则包 ≥ 44 × 44
的点击区。`user-profile` 打开自己的 id 时本来就会交给「我」（决策 0112）。

| 位置 | 改动 |
| --- | --- |
| 情报 · 用户榜 / 推广榜行与领奖台 | 有 `publicProfileId` 的行 onTap → 主页；自己 → 我；匿名行不可点 |
| 情报 · 底部「我的名次」行（用户 / 推广榜） | → 我 |
| 邀请中心 · 邀请列表头像与行 | → 主页；被拉黑 / 未激活（三字段为 null）不可点 |
| 邀请中心 · 推广榜行 | 同情报 |
| 社区详情 · 成员头像条 | 自己由「不可点」改为 → 我 |
| 社区成员列表头像 | 头像单独 → 主页 / 我（行本身仍按原逻辑打开治理面板或主页） |
| 联系人（connections）头像 | 头像单独 → 主页（行仍打开操作面板） |
| 私聊申请头像 | 头像单独 → 主页（行仍打开操作面板） |
| launch2 详情 · 最新成交 | `account` 非空时显示昵称 + 头像，头像 → 主页；为空仍显示地址，不可点 |
| launch2 发射台 · 实时动态行 | `account` 非空时句子用昵称并在时间后画头像，头像 → 主页，其余部分仍进项目页；为空不变 |

已可点、未改：广场帖子作者、搜索用户结果、MEME 创建者 / 持有人 / 成交 / 最佳成交、聊天头像（决策 0112）。不改：广场语音房卡片上叠放的小头像
（整张卡进房间，叠放头像再分点击会和进房冲突）；launch2「我的外盘成交」（全是本人）。

### D. 邀请深链 `/i/{code}`

- `lib/core/navigation/invite_link.dart`：`inviteCodeFromLinkPath` 按服务端规则规范化（大小写、可省 `LOOP-`、Crockford `I/L→1`、`O→0`）并校验
  形状；`referralClaimLocation(code)` = `/profile/referral?code=…`（manifest 路由加 query，不新增路由）。
- 路由 redirect 与 `/u/`、`/c/` 同一套：已登录直接改写到邀请中心；未登录先暂存在 `LoopProfileLinkInbox`（内存），落地「聊天」后推上去。
- 邀请中心收到 `code`：总览读到且 `binding.canClaim` → 打开绑定表单并预填，仍需本人点「绑定」才提交；已绑定 / 窗口关闭 / 未激活 → Toast
  说明这个码没有提交，不发请求。
- Android：现有 App Link intent-filter（`api-dev` / `api-staging` 两个 host，`autoVerify`）加 `pathPrefix="/i/"`，`MainActivity` 增加
  `INVITE_LINK_PATH`（`^/i/[A-Za-z0-9-]{1,16}/?$`）交给 Flutter 路由。
- iOS：entitlements 已有 `applinks:api-dev…` / `applinks:api-staging…`；Flutter 默认深链开启，Universal Link 路径直接进 go_router，无需原生改动，
  只更新注释。
- 正式环境域名尚未确定（`config/release.example.json` 的 `LOOP_BACKEND_BASE_URL` 为空），和 `/u/`、`/c/` 一样等域名确定后再加 host。

### E. 挖矿用词（`lib/features/mining/**`，按 docs/38：算力 = Mining Power，权重 = 社区币权重，加成 = 邀请加成）

| 位置 | 旧 | 新 |
| --- | --- | --- |
| 推广页标题 | Referral Boost | 邀请中心 |
| 推广页说明按钮 / 面板标题 | Referral 说明 | 邀请说明 |
| 推广页加成卡标签 | Mining Power 加成 | 邀请加成 |
| 推广页提示条 | 只计入 Mining Power / 这是 Mining Power 加成… | 只计入挖矿算力 / 邀请加成只计入挖矿算力… |
| 推广页 hero caption | 加成只计入 Mining Power。 | 邀请加成只计入挖矿算力。 |
| 推广页说明面板正文 | 「有效」需要挖矿公式版本被批准… | 被邀请人本人在最近一个结算小时有算力，才算有效成员（0162 §B.1 的新口径） |
| 挖矿首页加成卡眉标 / 标题 | 推广算力 / 邀请关系加成 | 邀请加成 / 五级邀请加成 |
| 挖矿首页加成卡说明 | 你的加成在邀请页查看。 | 你的邀请加成在邀请中心查看。 |
| 挖矿首页说明 | 持仓与社区权重共同构成当前算力 | 持仓与社区币权重共同构成当前算力 |
| 挖矿首页发现入口副标题 | 社区币的权重由服务端审核结果授予 | 社区币权重由服务端审核结果授予 |
| 公式说明（`miningBaselineDetail`） | 持有数量 × 挖矿权重 | 持有数量 × 社区币权重 |
| 规则页邀请加成行 | 加成只计入 Mining Power | 邀请加成只计入算力 |

「社区权重」（社区卡、社区权重审核页）是 docs/38 的既有用词，保留。

## Consequences

- 两个开关都关时：邀请中心显示码、复制、海报（无二维码）、统计全 `—`、加成 unavailable 卡；邀请列表读新路径（服务端未配游标密钥时 503 →
  unavailable 块）；launch2 行与以前一样显示地址。
- 邀请列表行没有 LOOP ID：0162 的 invitees schema 只有 `publicProfileId / alias / avatarRef / boundAt / validationStatus`，任务单要求的 LOOP ID
  需后端在 invitees 行加 `loopId`（且须客户端先落可选键，见反馈规则「/v2 新增键必须客户端先行」）。
- 情报「邀请中心」chip 下推广榜由情报控制器读一次、邀请中心页面自己再读一次（两个页面各自的控制器），同一时刻只在一个页面上。
- 邀请深链在未登录时只存内存；冷启动注册过程中被杀进程会丢失（之后可手动输入码）。
- 涉及范围外的少量文件（为接线必需）：`lib/app.dart`（redirect 与 referral 路由 query）、`lib/app/loop_profile_link_inbox.dart`（暂存）、
  `android/app/src/main/kotlin/com/cywd/loop/MainActivity.kt`（路径白名单）、`lib/integrations/backend/v2/loop_v2_s7_gateways.dart`（网关转发
  `loadInvitees`）。

## Tests

`test/s239_referral_center_test.dart`：五态、链接有无、海报二维码有无与 1080 × 1920、统计有无、可用加成、邀请列表头像跳转 / 隐藏资料不可点 /
翻页游标、深链预填与已绑定提示、`/i/` 解析、头像链接组件 44 点击区、launch2 实时行头像跳转、情报 chip 邀请块、invitees 解码与拒绝形状。
既有测试按新文案 / 新 chip 名更新：`s7_referral_test`、`s197_4_type_test`、`s7_mining_pages_test`、`s106_v3_navigation_test`、
`s106b_nav_followups_test`、`s113_intel_market_token_test`、`s190_intel_rank_ledger_test`；`s97_share_loop_id_test` 加 `/i/` 已登录直达与未登录暂存两条。
