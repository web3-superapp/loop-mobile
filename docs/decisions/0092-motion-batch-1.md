# 0092 · 动效第一批：头像堆叠、进度填充、托盘展开

## Status

Accepted 2026-09-27。S87，客户端单侧。需求方 2026-09-27 提出四个动效，用户裁决先做
1（头像堆叠）、2（进度填充）、4（托盘展开），落地页面按主代理建议。不新增依赖、不改
路由清单（93 条不变）、不改任何接口契约、不改冻结原型的文案。`lib/features/launch/`
未触碰。

## Context

冻结原型的交互几乎都是瞬时切换。需求方要三个可复用的动效组件，让「一组人」「一个
进度」「一张卡的明细」在不跳页的前提下有连续的变化。约束有三条：

1. 动效不能携带信息：每个组件的终态必须独立成立，关掉动效后信息一样完整；
2. 系统「减弱动态效果」或 App 自己的 `reduceMotion`（`LoopApp` 已把它折进
   `MediaQuery.disableAnimations`）开启时，全部退化为瞬时切换；
3. 颜色只取 `LoopTheme` token；浅色底上不得出现半透明浅色（S16 教训：渲染探针会报，
   而且真机上确实看不见）。探针逐帧读树，过渡帧同样受检。

## Decision

### 1 参数集中在 `lib/core/theme/loop_motion.dart`

| 组件 | 常量 | 值 |
| --- | --- | --- |
| LoopAvatarStack | `avatarSpread` | 280 ms（单枚散开/收回） |
| | `avatarStagger` | 35 ms/枚 |
| | `avatarCurve` | `Curves.easeInOutCubic`（散开、收回同一条，收回沿原路返回） |
| | `avatarStackStep` | 2/3（相邻偏移 = 尺寸 × 2/3，即压住三分之一） |
| LoopProgressFill | `progressFill` / `progressCurve` | 260 ms / `Curves.easeOutCubic` |
| | `progressComplete` | 600 ms |
| | `progressCompletePeak` | 0.12（高亮层透明度 0 → 0.12 → 0） |
| LoopTrayDisclosure | `trayExpand` / `trayCurve` | 280 ms / `Curves.easeOutCubic` |
| | `trayFadeStart` | 0.35（明细在同一控制器的 35%–100% 区间淡入） |

`LoopMotion.reduced(context)` 读 `MediaQuery.disableAnimations`；三个组件都用它决定
是 `forward/reverse` 还是直接把控制器置到终值。

### 2 三个组件（`lib/widgets/`，各一个文件）

**`LoopAvatarStack`**（`loop_avatar_stack.dart`）

- 默认尺寸 32，环宽 2；堆叠时第 i 枚左移 `i × size × 2/3`，后一枚压住前一枚；
- `total` 大于已画枚数时末尾画一枚「+N」，N = `total − entries.length`，数字原样，
  过长时在圆内缩放，不截断、不改写成「99+」；`total` 为空时不画「+N」；
- 每枚脸画在一枚不透明底盘（`ringColor`，默认取所在底的反色：Ink 页为 Ink，浅卡为
  Chalk）上，重叠处是真正的遮挡，而不是两层半透明混成第三种颜色；
- 点击后按 35 ms 错峰逐枚散开到 60 宽的格子（间距 8），每枚下方淡入名称，行变为可
  横向滚动；再点收回，横向滚动先归零；
- 名称一律由调用方给出真实数据（别名、LOOP ID，或调用方按自己的匿名规则给出的
  「匿名成员」），组件不生成、不缩写。收起时名称不构建，读屏读到的是
  「<语义标签>，名1、名2…，另外 N 人」；
- 触控高度不低于 44。

**`LoopProgressFill`**（`loop_progress_fill.dart`）

- `progress ∈ [0,1]` 决定填充宽度；值变化时从当前位置推进到新值；
- `from` 让组件在出现时从上一个值推进到当前值（每一步都是新页面的场景）；
- 从小于 1 推进到 1 时播放一次提亮：`highlightColor`（默认 `LoopColors.limeHighlight`）
  一层，经 `FadeTransition` 0 → 0.12 → 0，只在播放期间挂载；
- 默认填充色为 `LoopGround.fillOf(context)`，在 Ink 页上是 Chalk 10%，在浅卡上是
  Ink 10%，两种底上都可见；调用方传入的颜色必须是在该底上成立的 token；
- 减弱动效时直接落到终值，不播放提亮。

**`LoopTrayDisclosure`**（`loop_tray_disclosure.dart`）

- 主卡按原样全宽布局，位置和尺寸在整个展开/收回过程中不变；
- 托盘为 `LoopColors.graphite`，比主卡每侧窄 `trayInset`（默认 10），圆角
  `LoopRadius.shellValue`（24，比卡片 20 大一级），顶边伸到主卡下沿之上 `overlap`
  （默认 20，等于卡片圆角），先画托盘再画主卡，所以只露出下半截；
- 收起时只露一行摘要，点托盘向下展开：高度用 `SizeTransition`（顶对齐）随控制器
  增长，明细在 35%–100% 区间淡入；再点收回沿同一条曲线；
- 用 `SizeTransition` 而不是 `AnimatedSize`：`AnimatedSize` 收回时明细会在第一帧
  直接消失，只剩空框缩小；同一控制器驱动的 `SizeTransition` 收回与展开对称；
- 托盘向内容声明深色底（`DefaultTextStyle` Chalk + `IconTheme`），明细里用
  `LoopGround` 派生的颜色自动正确；
- 收起时明细不构建：读屏、查找和测试读到的只有屏幕上那一行；
- 主卡保留自己的点击，托盘是独立的点击目标（露出部分不低于 44）。

两者都靠一个自定义 `RenderBox`（`_RenderTrayUnderlay`）排版：托盘在主卡下沿减去
`overlap` 处开始，组件高度 = 主卡与托盘可见部分之和，页面随之顺延。

### 3 落地页面

| 组件 | 路由 | 位置 | 数据 |
| --- | --- | --- | --- |
| LoopAvatarStack | `community-members` | 列表顶部、在线人数说明之上 | 目录第一页前 5 位成员的 `displayName`（别名，否则 LOOP ID）与 `avatarRef`（`LoopProfileAvatar`）；「+N」= 服务端 `counts.all` − 5。筛选 Owner/Admin/已封禁、搜索中、键盘弹起时不显示，与同页算力卡的收窄规则一致 |
| LoopProgressFill | 开户五步（`auth-otp` / `wallet-create` / `wallet-recovery` / `security-setup` / `loop-id-setup`，以及两步的 `auth-wallet`） | `IdentityProgress` 的 4px 轨道（Lime 填充、`line2` 轨道，与原 `LinearProgressIndicator` 同色同高） | `step / total`，从 `(step−1)/total` 推进进来；第 5 步到满格后提亮一次 |
| LoopProgressFill | `community-profile`（S79a 的申请状态卡，仅所有者、仅 `pending`） | 卡片自身背景 | 申请有两个服务端记录的里程碑（提交、裁决），`pending` 已过第一个，填充 1/2，出现时从 0 推进；`LoopColors.limeSoft` 填充（卡片在 Ink 页上）。`rejected` 不画填充；`verified` 按 0081 不画卡片，所以这张卡永远到不了满格 |
| LoopTrayDisclosure | `token` | 行情头下方四格（24h 高/低/成交额/市值）为主卡，`trayInset = 16 + 6`，`overlap = 8`（四格本身无底色，托盘不能伸到数字下面） | 摘要「主交易对 {dex} · 报价币 {quote} · 合约事实 N 项」；明细为主交易对一行加每条合约事实（带来源与观察时间，与「简介」页签同句），不可用时给服务端原因 |
| LoopTrayDisclosure | `wallet`（Wallet Assets 列表） | 每个资产行为主卡，`trayInset = 16 + 10` | 摘要「可动用 X · 算力 Y」（原来在行副标题里的两项）；明细三行：可动用、算力（调用方原句，含其自身的破折号）、手续费保留（该行 `balance.gasReserve`）；读不到余额时两项给服务端原因，不写 0 |

`wallet` 的资产行因此从「一张分组卡」变成「每个资产一张卡 + 托盘」：托盘必须垫在
单张卡下面。行的 key、点击去向、标题、右侧数值不变；副标题去掉了移入托盘的两项。

**`group-info` 未落地。** 该页的成员目录仍是 `GROUP_MEMBER_DIRECTORY_DEFERRED`
（没有经过审核的数据源），头像堆叠要求名称一律真实数据，这里没有任何可以画的名字。
等小群成员目录有来源后，按社区成员页同样的方式接入。

### 4 测试

- `test/loop_motion_components_test.dart`：三个组件的初始态、`pump(Duration)` 中间帧、
  终态、减弱动效瞬时切换、点击往返；文件级 `loopWatchGround()`，过渡帧同样过探针；
- 落地页面：`community_pages_test`（成员预览的「+N」、散开后的名称、收窄时不显示）、
  `identity_pages_test`（第 3 步从 0.4 推进到 0.6；第 5 步满格并提亮一次后消失）、
  `s79_community_application_progress_test`（审核中填充恰为一半、不提亮）、
  `s5_market_pages_test`（token 托盘摘要、展开明细、收回）、
  `s5_wallet_pages_test`（资产托盘摘要、明细三项、收回）；
- `s28b_collapsing_hero_test` 的 `_rows` 改为取列表下第一个 `Scrollable`：成员预览
  散开后自带一个横向滚动容器。

## Consequences

- 以后新的动效组件先在 `LoopMotion` 加常量，再引用；组件里不写字面量时长。
- 真机验收（用户负责，本单未验证）：
  1. 成员页头像散开/收回在 120Hz 与 60Hz 机型上是否掉帧（错峰 + 每帧重排 Stack）；
  2. 散开后横向滚动与页面纵向滚动的手势是否互相抢；
  3. 开户五步每一步进入时轨道推进是否与页面转场叠在一起显得拖沓；第 5 步提亮在
     Lime 轨道上是否可见但不刺眼；
  4. 申请卡的 Lime 软填充在 OLED 与 LCD 上是否可辨；
  5. token 托盘与钱包托盘展开时下方内容顺延是否平滑、主卡是否纹丝不动；
     托盘露出的下半截在浅色模式截图里是否仍是深灰；
  6. 系统「减弱动态效果」与「我的 → 显示 → 减弱动态效果」两条路径分别打开时，三处全部
     瞬时切换。
- 待主代理裁决：申请卡「两个里程碑、审核中填到一半」是否可接受；若认为半格会被读成
  「审核进行到一半」，可改为只在出现时推进到一个更小的固定值，或撤掉该处落地。

## Main-agent rulings (2026-09-27)

1. Application card: the half fill stands (two milestones: submitted, decided); the card's own label says 审核中, so the fill is not read as review progress.
2. group-info: wire the avatar stack once the group member directory has a source; not before.
3. token tray: the overlap with the 成交 / 简介 tabs is accepted until the device round says otherwise.
4. Wallet asset list split into one card per asset is a visual change to the frozen prototype made for the tray; it goes to the user for device acceptance, and reverts if they refuse it.
