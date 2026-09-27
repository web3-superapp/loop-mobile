# 0100 · 生态账本 onChain、严格解码器系统排查、后端标识、发射轨道手风琴重做、图标首用预热

## Status

Proposed 2026-09-27。S91，客户端单侧。基线 `integration/v2` 990e4fd。不新增依赖、`pubspec.lock`
不变、路由清单不变（93 条）。解码器只**放宽**到 OpenAPI 已声明的可选键，没有放宽任何已有校验。

## Context

四件事，来自主代理 S91 任务单：生态账本页在合约配置后整页报「返回的数据不完整」；App 里看不出连的是哪个
后端；发射轨道手风琴「R1 R2 太空、END 底部 padding 太大」；Launch 详情「我的资格」图标首次进入偶发空白。

## Decision

### 1 `GET /v2/launch/economy` → `onChain`（缺陷，真机与模拟器复现）

loop-api S83b.10 在合约键配置后给经济账本加了顶层可选键 `onChain`，客户端 `getEconomy` 仍用
`strictMap` 精确键集，整份响应被判为 invalidPayload，页面显示「返回的数据不完整」。0093 的教训再次
出现：后端可选字段对严格解码器就是线格式变更。

- 解码：根改为 `strictMapWithOptional(…, {'onChain'})`。`onChain` 三种形态：
  缺席（未配置合约，`LaunchEconomy.onChain == null`，页面不画）；
  `{status:"unavailable", reasonCode}`；
  `{status:"available", registeredSaleCount, totalRaisedUsd1, lockedLpCount, source:"loop_indexer",
  indexedBlockNumber, indexedBlockHash}`，逐键按 OpenAPI 校验（整数计数 ≥0、金额整数字符串、
  区块号十进制字符串、小写 32 字节哈希、source 枚举）。`null` 不等于缺席，仍是 invalid。
- 模型：`LaunchEconomyOnChain`（sealed：Available / Unavailable）。
- 页面：「Launch」卡之后加「链上账本」：累计募集（仅成功的发售，USD1）整行，已登记发售 / 已锁 LP 两格，
  页脚「读自区块 N · LOOP 链上事件索引」。unavailable 时一条 LoopEmpty：索引类 reasonCode
  （`LAUNCH_ONCHAIN_STATE_NOT_INDEXED/NOT_PROJECTED`）用账本自己的句子，其余走 `launchReasonCodeText`。
  全局映射里 NOT_INDEXED 的句子是给目录行写的（「列表不逐个读链」），放在账本上是错的。

### 2 系统排查：OpenAPI 响应键 vs 客户端严格键集

脚本对 `/v2/launch*`、`/v2/launches*`、`/v2/wallets*`、`/v2/market*`、`/v2/mining*` 全部 2xx 响应
schema 的**所有层级**对象（含 anyOf 分支、数组元素），与 `lib/integrations/backend/v2/` 下各解码器的
`strictMap / strictMapWithOptional` 键集逐一匹配（340 个对象）。基线上能确定的缺陷三处，均已修：

| 接口 | 位置 | 服务端会发的键 | 客户端基线行为 | 处理 |
| --- | --- | --- | --- | --- |
| `GET /v2/launch/economy` | 根 | `onChain` | 拒绝整份 | 见 §1 |
| `GET /v2/wallets/{id}/balances` | 根 | `launchUsd1`（0081：Launch 槽位即主链时的 `{balance, allowance}`） | 拒绝整份 → 钱包页整页失败 | 可选解码；与 `launchChain.usd1` 同时出现判 invalid（0081 说二者互斥）；存入 `LoopWalletBalances.launchUsd1` |
| `POST /v2/launch/{id}/intents`、`…/broadcast-report`（及未接的 GET intent） | `launchIntent` | `revertReason`（0080：仅 `reverted` 时出现，string ≤256 或 null） | 拒绝整份 → 回滚后的回报/重放读不出 | 可选解码到 `LaunchPurchaseIntent.revertReason`；不按 state 强约束（避免下一次放宽再整份失败） |

误报（人工核对后确认客户端正确）：`holders/myPosition/walletCap` 与 history `source` 的 available 分支
（`status` 由 `reading()` 以展开方式加入）、`unsignedTransaction` 可选键（来自 `LaunchUnsignedTransaction
.optionalKeys`）、行情 watchlist/trending 行（`if (trending)` 条件键）。反方向（客户端必需而服务端标可选）
零处。限制：脚本按键集相容匹配，不是按调用点绑定；未在排查范围内的模块（social、community 等）没有跑。

### 3 App 内显示连接的后端

- `lib/app/loop_backend_identity.dart`：`loopBackendHost`（从 `LOOP_BACKEND_BASE_URL` 取主机名）、
  `loopBackendTier`（api-dev → DEV，api-staging → STAGING，IP/localhost/.local → LOCAL，api/www → PROD，
  其余取首段去掉 `api-` 前缀的大写，≤10 字符）、`loopRuntimeBuildMode`。纯函数，不发请求。
- 关于页「本机构建」加「服务端」行（主机名 + 档位），「构建模式」行显示声明的 `LOOP_BUILD_MODE`、
  运行时 debug/profile/release 与一致性。读的是配置原值：即使构建模式不一致、网络层拿到空地址，也能看出
  这个包被指向哪里。`AppConfig` 新增 `declaredBuildModeName`（仅展示）。
- 钱包 hero：`LoopFolioPrimary.kickerTrailing`（新可选槽，null 时 kicker 行与之前逐像素相同）放
  `LoopEnvironmentTag`。release 二进制（`loopReleaseBinaryProvider` = `kReleaseMode`）与无后端的构建不画。
- **偏离任务单**：任务单写「6 px 高」。11 px 是屏幕字号下限（0092/typography harness），6 px 放不下任何
  字，实现为 16 px 高（11 px Plex Mono，行高 1，上下 2 + 1 px 边）。

### 4 发射轨道手风琴（0096 的视觉重做，运动规则与 fit/fallback 不变）

- **行高 = 打开条内容的自然高度，最少 160**（随字号放大）。每条的打开内容在打开宽度上做一次不绘制的
  排版（`_AccordionBody` 自定义 RenderBox：探针只 layout，不 paint、不命中、不进语义树；Element 覆盖
  `debugVisitOnstageChildren`，finder 看不到）。行高 = Σ openness_i · max(160, h_i) + (1 − Σ) · 160，
  所以切换条时高度与宽度走同一条 280 ms easeOutCubic；减弱动效一帧到位。全部收起回到 160。
- **收起条**：顶部 `R1` + 状态点；沿长边 `RotatedBox(quarterTurns: 1)` 的状态词（已结束 / 进行中 /
  未开始，END 为「毕业」，读屏仍听条的语义标签）；底部 4×40 竖向进度条（已募集 / 轮次上限，自底向上）。
  收起内容在打开条的明细开始淡入之前就淡出（阈值 = 1 − curve(0.4)），两者不同帧出现。该淡出用
  `FadeTransition`：它只在运动中介于 0 和 1 之间（渲染探针把静态 `Opacity` 当成稳态颜色判定）。
- **打开条**：标题行右侧状态徽标。进行中轮次用 `launchSaleStateLabel` 的词（销售进行中 / 已暂停…），
  其余用轮次相位（已结束 / 未开始）；END 用毕业投影（待触发 / …）。明细：`Round N · 公开轮/名单轮`、两张
  小卡（开始/结束 UTC；单价/轮次上限，单位写在标签里，数字 scaleDown 不截断）、已募集 + 进度条；底部细信息行
  （轮次：「钱包上限 X USD1」；END：「读自区块 N」，N = 详情 `onChain.snapshotBlockNumber`）。
  END 明细不再重复徽标。
- **色调**（`LoopAccordionTone`，只取 token）：进行中 = Lime 边 + `limeSoft` 底；已结束 = 灰阶
  （tint → fill 底、hairline → edge 边、auxiliary 字、灰色进度）；未开始 = 仅描边（edge 边、透明底 →
  tint）；END 待触发按「未开始」，有毕业投影按「进行中」。
- 纵向回退列表、`fits()`、132 dp 下限、key（`launch-track`、`launch-track-strip-*`、`-detail-*`）不变。
  `LoopProgressBar` 新增可选 `fillColor`（默认 Lime，旧调用方不变）。

### 5 「我的资格」图标首次进入偶发空白

- 查到的机制（非 key 复用）：`flutter_svg 2.3.0` 在 profile/release 下，每个 SVG **第一次**绘制时在新
  isolate（`foundation.compute`）里编译，编译完才进 `svg.cache`；在此之前 `VectorGraphic` 画空。
  `ticket` 只在 Launch 详情与资格页用，所以总是这两页第一次付这笔钱；重进走缓存，立即显示——与现象一致。
  `vector_graphics 1.2.3` 的 live-picture 引用计数逐路径看过，没有找到会让图片永久空白的竞态。
- 处理：`loopWarmIconCache()` 在首帧后逐个（一次一个 isolate）把 64 个 sprite 图标编译进 `svg.cache`，
  loader 与 `LoopIcon` 构造的相同（路径、默认 bundle、默认主题），缓存键一致；失败忽略，退回按需编译。
- 未复现：本次模拟器 profile 包首次进入时图标正常（详情读取较慢，图标在骨架期已编译完）。所以这是对已知
  机制的缓解，不是对复现问题的验证；真机若仍出现，需要抓一次 profile trace。

### Tests

- `test/s91_economy_onchain_test.dart`（14）：economy 旧响应 / available / unavailable / 缺席、十种畸形
  onChain、未知根键；账本页三种形态；balances `launchUsd1` 有/无/畸形/与 `launchChain.usd1` 同时出现；
  intent `revertReason` null / 字符串 / 非法。
- `test/s91_backend_identity_test.dart`（7）：主机→档位映射、release 不画、运行时模式名、钱包 hero 标签
  （STAGING、16 高、与 kicker 同行靠右）与 release 隐藏、关于页主机与声明模式、未配置文案。
- `test/s91_launch_track_visual_test.dart`（8）：行高 = 打开条高度且不是 224、页脚贴底、END 打开时收缩到
  END 内容、切换时高度处于两端之间、全收起回到 160、减弱动效一帧、收起条竖排状态词 + 竖向进度（满/空/无）、
  进行中 Lime 边与 limeSoft 底、已结束 hairline、未开始透明底、徽标文案、探针对 finder 与读屏不可见、
  160 下限与长明细撑高。
- `test/s91_icon_warmup_test.dart`（2）。
- 既有 `s89a_launch_track_accordion_test.dart` 只改断言不删：明细里的数字改为小卡格式（`0.01`、`40,000`，
  单位在标签）、钱包上限在条的页脚、END 徽标在条的标题行；独立挂载用例 `height:` → `minHeight:`。
  `test/support/s8_harness.dart` 增加可选 `overrides`。

## Consequences

待真机确认与后续：

1. 钱包页 `launchUsd1` 只解码未接入 Launch 授权门：共享槽位（主网）上 approve 仍是 422 CHAIN_MISMATCH，
   主网签名关闭。主网开启时需要把 `launchAllowanceView` 改成 `launchChain?.usd1 ?? launchUsd1`。
2. 竖排中文用 RotatedBox 是侧卧字形（任务单要求）；若需要竖直排列的汉字（每字一行）需另定。
3. 图标预热在冷启动后台约 64 次串行 isolate 编译，真机上耗时/耗电未测。
