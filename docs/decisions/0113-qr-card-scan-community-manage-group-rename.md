# 0113 · 二维码名片与海报、扫一扫 `scan`、`/c/{id}` 深链、社区管理中心 `community-manage`、小群改名（S109b）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S108-S110-social-batch2b.md` §3、§6），S109b-mobile 实施。
基线 `integration/v2` e1007fd。对接后端 S109b-api（loop-api 决策 0098：`PATCH /v2/chat/groups/{id}`、admin 可编辑
社区资料）与 S108-api（loop-api 决策 0097：社区资源 `boundAsset` 块）；两者与本单并行开发，前端按设计文档契约写，
未挂载时 fail-closed。新增一个直接依赖 `mobile_scanner` 7.4.2。路由清单 99 → 101。

## Context

1. 需求方 v3（`LOOP/docs/09` §6.2 第 3/4/6 节）要二维码名片与海报、扫一扫、社区管理入口集中、小群可改名；§2 裁决
   「扫码支付先做扫码转账」。
2. S109b 之前：我的页「分享」只把一段文字交给系统分享；聊天「＋」的「扫一扫」是「暂未开放」；`/c/{id}` 只认
   `/c/{id}/room`；社区资料编辑是社区页底部 owner 专属按钮，admin 没有入口；`group-info` 的「群名称与简介」是
   `GROUP_PROFILE_DEFERRED` 占位卡（后端触发器禁止改名）。

## Decision

### 1. 路由与清单

- 新增 `scan`（2-community，`/scan`，prototypeOrder 106，action / focus）与 `community-manage`（2-community，
  `/community/manage?id=`，prototypeOrder 107，action / dashboard）。
- `docs/product/routes-manifest.json`：count 101，frozenAt 2026-10-08，canonical `sha256` =
  `f6269762299ff2e7c6370511fe9808dcdac194ca77706cd84e393c82c9fc8abe`（文件本身 SHA-256
  `a2c0c996c08b95c398445b5031b56d50c4f6a0cdfc6b6205585d9e286f455b0c`）。`lib/core/navigation/route_manifest.dart`、
  `test/route_manifest_test.dart`、`scripts/check_harness.py`（101）、`AGENTS.md`、`docs/product-decisions.md` 同步。
  **`LOOP/docs/routes-manifest.json` 不在本仓库，需主代理同步为同一文件。**
- `app.dart` 只动三处：redirect（`/c/{id}` 解析 + hold）、`_deliverHeldProfileLink`（持有链接的落地）、新增两条
  路由；另有 `/wallet/send` 构建器多传一个 `recipientPrefill`（见偏离 6）。

### 2. 二维码名片与海报（§3.1）

- `lib/features/social/qr/loop_qr_card.dart`：`LoopQrCardSubject` = `LoopUserQrCard`（头像、用户名、LOOP ID）|
  `LoopCommunityQrCard`（logo、名称、成员数、简介）。`showLoopQrCardSheet` 打开名片弹层；弹层里**显示的就是海报本身**
  （`LoopSharePoster`，缩放到弹层宽度），下面是链接 + 复制、「分享海报」「复制邀请文字」。
- 链接：用户 `{backendBaseUrl}/u/{loopId}`（决策 0104 的 `loopIdProfileLink`）；社区 `{backendBaseUrl}/c/{communityId}`
  （`communityCardLink`）。二维码载荷 = 链接；无后端地址的构建里，用户退回裸 LOOP ID（扫码同样识别），社区没有可用
  地址，显示「二维码不可用」`QR_CARD_LINK_UNAVAILABLE`，不画码。
- 编码：既有 `LoopQrCode`（byte 模式、纠错 M、版本 1–10 自适应）；Ink 模块画在 Chalk 底板上（扫码器读对比度，反色码
  很多相机拒读），4 模块静区。
- 海报：Ink 底、Lime 强调（LOOP 胶囊与用户 LOOP ID）、顶部头像 / logo + 名称 + 一行（LOOP ID 或社区简介，无简介时
  「N 位成员」）、中间 236 的 Chalk 码板、底部「LOOP · 扫码加我 / 扫码加入」。布局 360×540 逻辑尺寸，
  `toImage(pixelRatio: 3)` 输出 1080×1620 PNG（见偏离 1）。
- 导出：沿用 `chatMergeExportSinkProvider`（`main.dart` / `main_preview.dart` 已组合 `SystemChatMergeExportSink`，
  内存 PNG → 系统分享面板）；文件名 `loop-card.png` / `loop-community-card.png`；结果文案「海报已生成，请在分享面板中
  选择去处」等四种，只陈述发生了什么。没有新建 `system_image_share.dart`：既有 sink 正是通用的 PNG 分享端口。
- 入口：我的身份卡右上分享（key 不变 `profile-share-loop-id`，读屏名改为「分享名片」；纯文本分享移入弹层的「复制
  邀请文字」）；`user-profile` 溢出菜单首项「分享名片」；`community-profile` 顶栏新增分享（所有读者）。资料编辑页不加。

### 3. 扫一扫 `scan`（§3.2）

- 端口 `lib/features/scan/loop_qr_scanner.dart`（`LoopQrScanner` / `LoopQrCameraSession`，相机五态
  starting / running / permissionDenied / unsupported / failed，手电筒 unavailable / off / on）；默认
  `UnavailableLoopQrScanner`。设备适配器 `lib/integrations/device/mobile_scanner_qr_scanner.dart`，只在 `main.dart`
  与 `main_preview.dart` 组合（预览也真扫：解码在本机，不碰任何服务，打开的页面仍是预览数据）。`lib/features/` 不
  import 相机插件。
- 页面：取景框（1:1 圆角，Lime 四角）+「从相册选图」（`image_picker` 选图 → `analyzeImage`，只认 QR）+ 手电筒。
  五态：loading = 相机打开中；error = 相机没打开（重试 / 改用相册）；permission = 系统拒绝相机，文案沿用
  `permission-notice` 的「扫码功能不可用；可在 系统设置 → LOOP → 相机 中重新开启。」；empty = 不认识的码（显示原文、
  复制、继续扫描）；offline 不适用（解码在本机，打开的页面各自有离线态）。无相机适配器的构建整页「扫码当前不可用」。
- 结果分发 `loopScanResultFor`（纯函数）：http(s) 链接的 `/u/{loopId}` → `user-profile?loopId=`；`/c/{id}/room` →
  既有语音房落地（`voiceRoomLinkLocation`）；`/c/{uuid}` → `community-profile`；整段文本恰为 `LOOP-XXXXXXXX` →
  `user-profile`；`0x` + 40 位十六进制，或 EIP-681 朴素形式 `ethereum:0x…`（可带 `@56` / `@97`）→ `/wallet/send`
  并以类型化状态 `SendRecipientPrefill` 预填收款地址；其它（含别的链、带函数 / 参数的 EIP-681 请求、别的网址）→
  「不是 LOOP 二维码」。链接不限主机（只取路径，打开的都是应用内页面，不打开浏览器）。识别成功后用
  `pushReplacement` 替换扫码页，返回回到扫码之前的页面；同一码的后续帧不重复打开。
- 发送预填：`SendDraft` 新增可选 `recipientPrefill`（`copyWith` 保留它，其它调用不变）；`SendAssetScreen` 新增
  `recipientPrefill` 参数并在顶部提示「收款地址来自扫码 … 选好资产后仍要点「校验地址」核对」；`SendRecipientScreen`
  地址框初值 = `recipientAddress ?? recipientPrefill`。预填只是输入框里的文字，服务端 preflight 与签名出口一步不少。
- 入口：聊天「＋」第四项「扫一扫」（副标题「扫名片、社区码或钱包地址」）→ `/scan`；钱包页 Pay 胶囊 → `/scan`（见
  偏离 5）。`send-to` 页原「扫码与最近联系人还没有开放」改为「最近联系人还没有开放…；扫码请用钱包页的 Pay」。
- 原生：iOS `NSCameraUsageDescription` =「用于在聊天中拍照发送图片，以及扫描二维码」，
  `NSPhotoLibraryUsageDescription` 补「识别二维码」；Android 不新增权限（`CAMERA` 已声明）。`ios/Podfile.lock` 只多
  `mobile_scanner (7.0.0)` 一个本地 pod（依赖 Flutter，Apple Vision，无 MLKit）。

### 4. `/c/{communityId}` 深链（§3.3）

- `lib/features/community/community_link.dart`：`communityIdFromLinkPath` 只认 `^/c/{UUID}/?$`（大小写不敏感，落地
  统一小写），`/c/{id}/room` 仍归语音房链接。redirect 解析 → `LoopProfileLinkInbox.holdCommunity` → 已登录直接
  `community-profile?id=`；未落地时持有，落到聊天后由 `_deliverHeldProfileLink` 推入（返回回到聊天），与 `/u/`、
  `/c/…/room` 同一机制。非法 `/c/…` 仍是未知路由回聊天并记录。
- Android `MainActivity.kt` 新增 `COMMUNITY_LINK_PATH = ^/c/[0-9a-f-]{36}/?$`；manifest 的 intent-filter 已有
  `pathPrefix="/c/"`，不改。iOS 不改（Universal Link 路径由服务端 AASA 决定）。

### 5. 社区管理中心 `community-manage`（§3.4）

- 入口：`community-profile` 顶栏对 `viewer.mayManage`（owner / admin 且未被封禁）显示「管理」（settings 图标）。
  原底部 `community-edit-profile-action` 移除；owner 在底部只剩「所有者不能直接退出…」说明，admin / 成员保留
  「退出社区」。驳回后「修改资料后重新提交」流程不变。
- 页面复用 `communityProfileControllerProvider`（同一份答复，从社区页进入不多读）。分组：
  - **资料**：「名称与简介」（所有管理者）→ `showCommunityProfileEditSheet`；「绑定代币」（仅 owner，`仅所有者` 徽标）
    显示 `boundAsset` 的 symbol / name / 是否已有注册池子，旧 API 无该块时显示截短地址 +「代币信息暂时读不到」；
    owner 且 `hasRegisteredPool = false` 时提示「尚无已注册池子，群友买入动态不会出现。」
  - **成员**：→ 成员页；副标题「Owner n · Admin n · 共 n 人」，取自 `GET …/members` 的 counts（一次读，失败显示
    「角色计数暂时读不到」）。
  - **语音房**：未开播 →「开启语音房」，与社区页共用 `openCommunityVoiceRoom`（从社区页 `_createVoiceRoom` 抽出到
    `community_voice_room_open.dart`，行为与文案不变，S110 加标题时只改这一处）；开播中 →「进入语音房」。
  - **公告**：「公告发布随运营后台开放」占位。
  - **分享**：社区二维码名片。
  - **所有权**（仅 owner）：「转让所有者」→ 成员页；「解散社区不提供。」
  - 五态：loading / offline / error / empty 用 `CommunityStateBlock`；成员身份 → permission 空态「只有社区所有者与
    管理员可以管理」；缺 id 不发请求。
- 编辑弹层：`showCommunityProfileEditSheet` 新增 `includeBoundAsset`（默认 false），管理中心对 owner 的「绑定代币」行
  传 true，admin 永远看不到该字段。`CommunityProfileEdit` 新增 `boundAssetKey` / `clearBoundAssetKey`（小写化、
  `eip155:{chain}:0x…` 校验，留空 = 解绑），Dio 写入体按同样的「null 表示清空」规则带上 `boundAssetKey`。失败文案：
  带绑定代币的 422 →「这个代币还没有在 LOOP 登记，不能绑定」，403 →「只有社区所有者可以修改绑定代币」。
- 解码：社区资源（单条与目录行）把 `boundAsset` 作为**可选尾键**接受，块内严格五键
  `{assetId, symbol, name, logoUrl, hasRegisteredPool}`；之前的严格键集会把带新键的每个社区响应判为无效。

### 6. 小群改名（§3.5）

- 端口 `lib/features/chat/v2/group_rename.dart`（`GroupProfileGateway`，默认 unavailable）；适配器
  `lib/integrations/backend/v2/communication/loop_v2_group_profile.dart`（独立文件，不改既有通信 API / 网关，避免与
  S110 冲突）：`PATCH /v2/chat/groups/{groupId}` body `{ name }`，bearer + `Idempotency-Key` + contract version；
  200 严格解码 `{groupId, name, nameVersion, updatedAt, contractVersion}`，且回显的 id / name 必须与请求一致。
- fail-closed：`groupRenameFailureKind` 把 404（有无 LOOP 信封都算）/ 405 / 501 一律映射为 unavailable，从不当成
  「结果未知」或成功；其余按社区写错误表（403 → permissionDenied）。只在 `main.dart` 组合；预览不组合 → 改名显示
  不可用。
- UI：「群名称与简介」占位卡改为真实行「群名称」：名称与是否创建者从 Stream 读（已加载的频道或一次按成员身份限定
  的查询，创建者 = `created_by`，与置顶同一事实）；创建者行尾「修改」→ 弹层（1–40 码点、拒控制 / 格式字符，与创建
  一致）；非创建者「仅群主可改」不可点。成功：toast「群名称已改为「…」」并在本页立即显示新名（乐观）；403 →
  「只有群主可以修改群名称；这次没有改动。」；不可用 →「改名暂时不可用，群名称没有改动。」；名称都不变。

### 7. 新依赖 `mobile_scanner` 7.4.2

- 理由：需要实时相机取景解码与相册图片解码两条路；`mobile_scanner` 是 Flutter 生态维护最活跃的扫码插件，iOS 用
  Apple Vision（无第三方二进制），Android 用 ML Kit 捆绑模型（离线、不依赖 Play 服务下载），7.x 支持
  `analyzeImage`、手电筒、生命周期自停。pub.dev 最新稳定版 7.4.2（`sdk ^3.7.0`、`flutter >=3.29.0`，满足本仓库）。
- 锁文件：`pubspec.lock` 只新增 `mobile_scanner` 一个包（其依赖 `collection` / `meta` / `plugin_platform_interface` /
  `web` 已在图中，传递依赖新增 0 个）；`scripts/check_harness.py` 的固定版本表加入 `mobile_scanner: 7.4.2`。
- 替代方案：(a) `qr_code_scanner`——已停止维护，不支持新 Flutter 嵌入；(b) `google_mlkit_barcode_scanning` + `camera`
  ——两个依赖 + 自己管相机生命周期，iOS 引入 MLKit pod 体积大；(c) 自写原生通道（AVFoundation / CameraX + ML Kit）
  ——工作量与维护成本最高。均不取。
- 代价：Android APK 增加 ML Kit 条码模型（约 2–3 MB）。

## 与契约的偏离

| # | 项 | 设计文档 §3 / §6 | 本批实现 | 原因 / 后续 |
| --- | --- | --- | --- | --- |
| 1 | 海报尺寸 | 「1080×1620 逻辑尺寸（pixelRatio 3 输出）」 | 360×540 逻辑尺寸 × pixelRatio 3 = 1080×1620 像素 | 1080×1620 逻辑 ×3 会是 3240×4860（约 63 MB 位图），按「输出 1080×1620」理解 |
| 2 | 名片弹层与海报 | 弹层（码 + 链接 + 分享海报）与海报两套布局 | 弹层里显示的就是海报本身（缩放），导出所见即所得 | 不维护一份看不见、可能漂移的第二布局；离屏截图在 Flutter 里不可靠 |
| 3 | 权限被拒「去设置」 | 现有文案 + 去设置按钮 | 只有现有文案「可在 系统设置 → LOOP → 相机 中重新开启」，无跳转按钮 | 锁文件里没有打开系统设置的插件（`loop_chat_camera.dart` 同样的约束）；原生通道两端都要写且无法在本机验证 iOS，待主代理决定是否加 |
| 4 | 社区 logo 编辑 | 资料分组含 logo | 管理中心只改名称 / 简介 /（owner）绑定代币；logo 显示但不可改，页内注明 | 社区 logo 上传端点不在契约里（0112 只有 `POST /v2/media/avatars`）；编辑弹层历来不含 logo |
| 5 | 钱包「扫码支付」入口 | 跳 `/scan` | 钱包页 Pay 胶囊（`wallet-pay-entry`，原 blocked「扫码支付还没有开放」）改为打开 `/scan`；`pay` 页本身仍 unavailable | 依据 09 §2「扫码支付先做扫码转账」；`00` 规则「Pay 只做 unavailable」指 `pay` 页，入口改道不让它可执行。主代理若认为冲突，回退这一行即可 |
| 6 | `app.dart` 改动范围 | 只改 redirect 与新路由 | 另改 `/wallet/send` 构建器一行（`recipientPrefill: SendRecipientPrefill.addressFrom(state.extra)`）与 `_deliverHeldProfileLink` | 预填地址以类型化导航状态进入发送第一步（资产仍须用户选，`/wallet/send/to` 需要完整 `SendDraft`，无法直达）；持有链接的落地在 `_deliverHeldProfileLink` |
| 7 | 扫地址直达 `/wallet/send/to` | 地址 → `/wallet/send/to` 预填 | 地址 → `/wallet/send`（选资产）→ `/wallet/send/to`（地址已填） | `send-to` 的路由守卫要求带 walletId / assetId 的 `SendDraft`，扫到的码没有资产 |
| 8 | EIP-681 | 只说「0x 40 位地址」 | 另认朴素 `ethereum:0x…(@56|@97)`；其它链或带函数 / 参数的请求一律「不是 LOOP 二维码」 | LOOP 自己的收款页画的就是 EIP-681；token transfer 请求里 `ethereum:` 后是合约地址，误读会把钱打给合约 |
| 9 | 小群改名后频道名 | 「本地 Stream 频道名随之更新（客户端乐观更新标题）」 | 只在 `group-info` 本页立即显示新名；会话列表 / 群聊顶栏等 Stream 的 `channel.updated` 事件（服务端同步后）自然刷新 | 客户端没有改 Stream 频道的权限，直接改本地 `ChannelState` 属于 SDK 内部状态，会与服务端同步互相覆盖；群聊页顶栏历来固定「群聊」 |
| 10 | 成员 Owner / Admin 计数 | 管理中心显示计数 | 额外一次 `GET …/members`（首页）取 counts | 社区记录本身不带角色计数 |
| 11 | admin 看绑定代币 | 「绑定代币仅 owner 可改」 | admin 的管理中心整行不显示（不只是弹层字段） | 测试要求「admin 看不到绑定代币字段」；只读显示留待需要时加 |
| 12 | 链接主机 | `{PUBLIC_BASE_URL}` | 用构建的 `LOOP_BACKEND_BASE_URL`（与 0104 `/u/` 链接同源）；扫码时不校验主机 | 仓库没有独立 `PUBLIC_BASE_URL` 配置；扫码只取路径打开应用内页，不访问该主机 |

## Consequences

- 新测试 `test/s109b_qr_scan_manage_test.dart`（名片两种 subject、无后端社区不画码、海报导出一次且为 PNG、扫码结果
  分发 user / community / room / address / EIP-681 / unknown、扫码页四种分发 + 相册 + 手电筒 + 三种相机态 + 无适配器、
  发送页预填、`/c/` 解析、深链已登录 / 未登录 hold / 非法、管理中心 owner / admin / member 可见性与 loading / offline /
  缺 id、`boundAsset` 解码、改名成功 / 403 / 不可用 / 非创建者、名称规则、404 映射）。改写的既有测试：
  `s97_share_loop_id_test.dart`（分享 → 名片弹层 + 复制邀请文字）、`community_pages_test.dart`（管理入口可见性）、
  `s106_v3_navigation_test.dart` 与 `stream_chat_inbox_page_test.dart`（扫一扫打开 `scan`）、`route_manifest_test.dart`
  （101）。
- 待后端：S109b-api 的改名路由与 admin 编辑、S108-api 的 `boundAsset` 块；未上线前改名显示不可用、管理中心绑定代币
  行显示「代币信息暂时读不到」，admin 提交资料会被旧后端 403（文案照实）。
- 待主代理：同步 `LOOP/docs/routes-manifest.json`；决定偏离 3（去设置按钮）与偏离 5（Pay 入口）。
- 未验证：真机相机取景、手电筒、相册解码、海报在系统分享中的实际图片、`/c/` App Link 自动验证（需各主机
  `assetlinks.json`）、iOS Universal Link（AASA 需加 `/c/*`）。
