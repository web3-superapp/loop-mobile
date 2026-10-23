# 0244 · 扫码邀请直接打开；「我的项目」移到创建页；信息 tab 去外盘行、名单块改名（S294-mobile）

## Status

Accepted 2026-10-23。基线 `integration/v2` b7621b73。主代理下单 S294-mobile，对应需求方 2026-10-23《LOOP 产品问题整理》第 02 / 06 / 07 条，用户已裁决全部照做。
不新增依赖，`pubspec.lock` 不变；**路由清单不变（114）**，`routes-manifest.json` / `route_manifest.dart` 未动；不改 loop-api、不改 `/v2` 契约；不新增、不改全局设计 Token。

## Context

- 第 02 条：需求方以 OKX 海报为例，扫完邀请二维码应直接进页面。决策 0235 第 2 项在扫码页加了一道「LOOP 邀请码 … / 继续扫描 / 去填写邀请码」确认面板，这一步是我们自设的：真正的绑定确认本来就在邀请中心的填写页（0214），面板只是多点一次。
- 第 06 条：MEME 首页顶栏「我的项目」icon（0237）与「发射」胶囊并排，需求方要求移走，只留「发射」。
- 第 07 条：代币详情页（已毕业）信息 tab 在「费用累计」与名单块之间有一组外盘读数（外盘最新价、外盘成交、用户买入 / 卖出、24 小时成交额、最近成交），需求方要求去掉；名单块标题「名单已发布」改为「NFT名单公布」。

## Decision

1. **扫到邀请直接打开（撤销 0235 第 2 项）。** app 内扫码（相机帧或相册图片）识别为 `LoopScanInvite`（`/i/<code>` 链接或整串 `LOOP-XXXXX`，识别规则仍是 0235 第 1 项，不变）时，与名片 / 社区 / 地址码一样直接 `onOpen('/profile/referral?code=<code>')`（路由层 `pushReplacement`，扫码页被替换）。`_InviteCode` 面板与 `_openInvite` 删除。绑定仍只在填写页确认后发生，0214 的「已绑定则 Toast 说明」不变。
   - **防重复：** 页面的一次性 `_handled` 标志——第一次交出目的地即置位，之后 `_onCode` 与 `_dispatch`（相册路径也走这里）都直接返回；同一码的后续帧、其它码都不会再推页面。
   - 未识别 / 非 LOOP 内容仍显示「不是 LOOP 二维码」面板（复制 / 继续扫描）；发送页扫收款地址模式下邀请码仍按文本显示、不跳转。
   - 系统相机扫海报唤起 app（Universal Links）不在本批。
2. **「我的项目」移到创建页顶栏。** `Launch2CreatorActions` 只剩「发射」胶囊（0195 的经典 / v2 选择 sheet 逻辑不动）。新增 `Launch2MyProjectsAction`（同一个 `Launch2BoldIconButton`，`user` 粗笔 24 图标、44 触控、可访问名「我的项目」、key `launch2-my-projects-action`），放在 `/launch2/create` 的 `LoopFocusPage.actions`（顶栏右侧 trailing 槽），点击 `context.push('/launch2/projects/mine')`（push，不丢创建表单草稿）。
   - 只在新建发射时画（`projectId == null`）；「修改资料」表单是从我的项目进来的，不再画。
   - 门控：icon 自身仍走 `launch2CreatorEntryVisible`（构建开关 + 服务端 `launch2` available），与原首页行为一致。注意 `/launch2/create` 路由本身并不按此门控（深链可进，进去后提交由服务端裁决）；本批不改这一点。
3. **信息 tab 去掉外盘读数。** `Launch2PoolStats` 只含这五行及其池未同步时的「官方池成交还在同步」不可用态，且只在已毕业实例的信息 tab 挂载一处，因此**整个 widget 连同挂载点删除**；只为它服务的 `launch2PoolBuybackCount`（0200 D10）一并删除。「费用累计」（`Launch2DynamicFeeSummaryCard`）、已毕业信息、名单块、去外盘交易链接保留。池未同步时：价格头仍按 `pool == null` 显示无价格、成交 tab 仍有自己的「成交还在同步」，不可用信息不因删行而丢。codec 对 S151 用户成交键的校验不变（仍 fail closed）。
4. **名单块改名。** `Launch2SnapshotPublishedBlock` 的标题与 `launch2SnapshotPendingTitle` 的已发布分支都改为「NFT名单公布」；未同步分支「名单已上链，同步中」及其它状态文案不变。

## Consequences

- 测试：`test/s109b_qr_scan_manage_test.dart` 原「邀请码先显示、点去填写邀请码才打开」一例换成两例（`/i/` 链接直接打开 `/profile/referral?code=LOOP-1ZR9N`、无面板、后续同码 / 裸码 / 其它码帧不再打开；裸 `loop-1zr9n` 直接打开）。`test/s135_launch2_creator_pages_test.dart` entry 组新增 2 例（创建页右上角 44 的 `user` 图标、可访问名「我的项目」、点击回调；launch2 关闭时不画）。`test/s279_meme_tabs_and_plate_test.dart`、`test/s136_launch2_user_test.dart` 改为断言 MEME 顶栏没有「我的项目」。`test/s152_launch2_pool_user_trades_test.dart` 删去「官方池读数」widget 组（codec 组保留）；`test/s146_launch2_pool_trade_test.dart` 两例、`test/s285_instance_page_test.dart` 一例改为断言信息 tab 无这五行及无不可用态。`test/s182_launch2_desk_nft_test.dart` 名单块断言标题「NFT名单公布」，新增 `launch2SnapshotPendingTitle` 已发布分支一例。
- 0235 第 2 项作废，其余（识别规则、我的邀请三块布局、底色）仍有效。0237 中「我的项目」在 MEME 顶栏的位置作废，粗笔图标样式沿用。
- 真机需确认：扫邀请海报直接进邀请中心且绑定表单预填；创建页右上角图标点进我的项目后返回草稿仍在。
