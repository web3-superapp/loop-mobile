# 0175 · 「我的」主页改为 docs/35 设计稿版式（S187-5-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 3e49203（已含 0166 ~ 0172）。
来源：主仓库 `docs/35-代币列表与代币页设计稿-2026-10-15.md` 与 `body2.html` 里「我的」手机框（用户 2026-10-15「照设计稿做吧」），
家族规则照 `docs/33-全App对照原型一致性走查-2026-10-15.md` §1（同屏一个满 lime、字号走 `LoopType`、圆角走 `LoopRadius`、部件走 `lib/widgets`）。
路由数不变（113）；没有新增后端请求路径、依赖与字体。

## Context

0126 起「我」是 OKX 资产页式的平铺入口页：身份卡、三个 56 lime 圆键、账号 / 资产与挖矿 / 设置三组行、退出登录与版本号。
docs/35 把「我的」改成 fomo 版式：隐藏余额胶囊 + 齿轮、72 头像 + 奖励、名字 / ID / 简介、关注粉丝、元信息、持仓曲线、持仓列表 / 首购卡、底部充值。
设计稿上的数字有一半在 LOOP 没有来源，AGENTS 20 / 25 条不允许画没有来源的净值、走势与统计。

## Decision

### 1. 主页（`profile_v2_screens.dart · ProfileHomeScreen`）
| 设计稿 | 实现 | 数据来源 |
|---|---|---|
| `.me-top` 胶囊 | `profile-hide-balance`：「点一下隐藏余额」/「余额已隐藏，再点一次取消隐藏」，line2 描边 stadium，眼睛字形；本机保存不可用时尾部「仅本次」（`profile-hide-balance-run-local`） | 新偏好，见 §3 |
| `.me-gear` | `LoopIconButton('settings')`，key `profile-open-settings` → `settings` | — |
| `.me-avatar` 72 + ✎ | `LoopProfileAvatar` 72 + 22 chalk 圆角标（`profile-avatar-edit`），整块 `profile-open-edit` → `profile-edit`（头像编辑器就在资料编辑页） | profile 资源 |
| 🎁 奖励 | 描边 `LoopButton(icon: parachute)` `profile-open-rewards` → `mining-rewards`（LOOP 不画系统 Emoji，0117） | — |
| `h1` 名字 | `LoopType.displaySm`（24，设计稿 `--disp 24px`），无别名时「尚未设置别名」 | alias |
| `@… · LOOP-…` | `LoopIdCopyLine`（复制字形 + 长按复制，0104）；读不到时「LOOP ID 不可读」 | loopId |
| ＋ 添加个人简介 | lime 文字链接 `profile-add-bio` → `profile-edit`；有简介时直接显示正文（`profile-bio`，最多 4 行） | `ProfileValues.bio` |
| `.me-stats` | 「N 已关注」「N 粉丝」两个可点数字（`profile-following-count` / `profile-followers-count`）→ `connections` | `connectionsControllerProvider.counts`（`GET` 关注列表随页返回的计数）；未读到时整行不画 |
| `.me-meta` | 只有「2026 年 10 月加入」（`profile-joined`，`id` 字形） | `ProfileResource.activatedAt`（LOOP ID 激活时间；未激活不画） |
| `.me-chart` | 200 高，`LoopColors.card2` 14 px 点阵；右上四个 `LoopSeg(quiet)` 24 小时 / 7 天 / 30 天 / 全部；左上净值（隐藏时「****」）+ 一行说明；中央「暂无持仓」或「净值走势暂时读不到」 | 净值 = 当前钱包 `GET /v2/wallets/:id/balances` 的 `netWorth`（标「净值 · 不是可用余额」，partial 时写未计入项数，unavailable 时写服务端 reason） |
| `持仓 (N)` | `LoopLabel` + `WalletAssetLine`（钱包页同一个资产行，隐藏时金额与估值打码）→ 该资产钱包页 | 同一 balances 读；N = 链上读到且非零的行；读失败的行不算持仓，单列一行「N 项余额读不到，未列入」 |
| `.promo` | 余额读到且一行持仓都没有时：`LoopRecordCard`「获取你的第一个代币 / 领取测试币后首次买入 0 手续费 / 立即买入 →」`profile-first-buy` → `meme` Tab；右侧 `LoopRowIcon(launch, accent)` | — |
| `.bottombar` 充值 | `bottomBar` 满 lime 块按钮 `profile-deposit`：测试币水龙头对当前内嵌钱包开放时（0154 / 0158）打开领取测试币弹层，否则 → `wallet` Tab（接收 = 充值地址）。**本页唯一的满 lime** | `testnetFaucetVisible` |

钱包读取复用钱包 Tab 的门：`walletRead` 关 → 持仓区写服务端 reason；`bscRead` 关同理；没有钱包 →「还没有钱包，钱包页可以创建」；读取中骨架；失败一行 + 重试。

### 2. 原主页入口搬到齿轮的设置页
`ProfileAccountEntries`（同文件，公开类）原样承载：三个圆键（分享名片 / 扫一扫 / 挖矿）、账号组（我的钱包 / 关注与粉丝 / 陌生人请求 / 邀请好友）、
我的社区（`ProfileCommunitiesRow` + 我创建的 + 审核通知）、资产与挖矿组（总算力 / 挖矿资产 / 挖矿奖励 / 挖矿规则 / IDO 两行开关）、
隐私与安全组（隐私中心 / 安全中心 / 通知设置）。全部 key 与目的地不变。`GeneralSettingsScreen` 在「通用」之前画它，
退出登录（`settings-sign-out`，0133 的确认弹层）与版本号（`ProfileVersionFootnote`，key `profile-version`）在页尾。
原来的「通用设置」行去掉（就是当前页）；`ProfileHomeScreen` 去掉 `onSignOut` 参数，`profile-sign-out` 不再存在。
`app.dart · _profilePath` 增加 `wallet`、`meme`、`wallet-asset:<assetId>`（→ `MarketAssetRoute.walletAsset`）三个目的地 id，不是新路由。

### 3. 「隐藏余额」本机偏好（AGENTS 23 条扩展）
- 端口 `lib/app/loop_balance_visibility.dart`：`LoopBalanceVisibilityStore`（`readHideBalance` / `writeHideBalance`）、默认 `UnavailableLoopBalanceVisibilityStore`、
  `LoopBalanceVisibilityController`（非 autoDispose）：启动读一次、1 秒超时；读失败 / 超时 = **显示**（fail-open）并标 run-local；本次运行里先点过就不被晚到的读覆盖；
  写入按顺序串行、每次 1 秒超时，失败只改 persistence，不回滚可见状态。
- 适配器 `lib/integrations/personalization/shared_preferences_balance_visibility_store.dart`：`SharedPreferencesAsync` getBool / setBool，唯一 key `loop.display.v1.hide_balance`；
  `createSharedPreferencesBalanceVisibilityStore()` 构造失败回退不可用；只有 `lib/main.dart` 组装它（preview 入口不组装，仍是 run-local）。
- 偏好只作用于本页的净值与持仓金额，钱包 Tab 的眼睛仍是 0119 的进程内开关（没有并到一起）。
- AGENTS 23 条与 `implementation-constraints.md` 补一句；harness 新增 `check_balance_visibility_store_contract`（导入、唯一 key 字面量、只许 getBool/setBool、单一 `SharedPreferencesAsync()`、只由 main 组装、测试标记），并把该文件加入 Shared Preferences 允许导入名单（现为三个）。

## Consequences

- 没有来源、**没画**的东西：持有时长、交易笔数（钱包活动是分页流，没有总数）、净值历史曲线（loop-api 只有 `balances` 当前快照，没有任何历史 / 走势接口；
  `WALLET_NETWORTH_TREND_DEFERRED` 也说明了这一点）。四个时间段胶囊画出但不可选，点了 toast「净值走势暂时读不到，时间段还不能切换」，都不呈选中态。
- 设计稿里 `@Boo123133 · LOOP-…` 的 `@别名` 段没画：名字上一行已是别名，LOOP ID 是唯一可复制的标识。
- 首购卡右侧的六个头像堆换成一个 `LoopRowIcon(launch, accent)`：没有哪几个社区 / 代币可以诚实地放进去。
- 「我」不再有退出登录；以后它只在设置页。旧主页上的 key 全部还在（在设置页），测试改为从 `settings` 断言。
- 可见变化（待主代理真机验收）：整页版式；底部常驻充值条；设置页变长（入口在前，通用 / 关于 / 退出在后）。

## Verification

- `bin/dart format`（本批文件）、`bin/flutter analyze`、`python3 scripts/check_harness.py`、`python3 -m unittest discover -s tests -p 'test_*.py'`、
  profile / social / wallet 相关 `bin/flutter test`（含新 `test/s187_profile_home_test.dart`，结果见提交说明）。未起模拟器、未做真机验收。
