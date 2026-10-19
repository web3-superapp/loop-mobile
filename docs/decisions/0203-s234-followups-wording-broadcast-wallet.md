# 0203 · S234 低级缺陷：铸造用词、名单状态标签、签名弹层停在已广播、钱包 Launch 链 tUSD1（S236-mobile）

## Status

Accepted 2026-10-19。基线 `integration/v2` ec1bb61。依据：S234 staging 复核报告（`LOOP/docs/integration/S234/report.md` ② 缺陷 S234-1…8，
截图 `shots/2-2`、`A2`、`C3–C6`、`D-project-4`、`D-qa-privy2-*`、`E-账号2-钱包`，日志 `logs/snapshot-poll.log`），客户端决策 0089、0139、0148、0163、0200、0202，
loop-api 决策 0038 / 0077（`launchChain` 与 `launchChain.usd1`）。
只改 App：不新增依赖、路由、字体、颜色 token，`pubspec.lock` 不变，无新请求路径，不改 loop-api。

## Context

S234 用 ec1bb61 包复核 0202，0202 各条通过，另记下四条低级缺陷（S234-1…4）和两条观察（S234-7、S234-8）。S234-5、S234-6 是 docs/22 的写法问题，已由主代理改文档，App 不动。

## Decision

### A. 创建者一侧统一成「铸造」（S234-1）

0200 第 6 条把用户侧改成了铸造用词，当时创建者一侧（发起第 3 步、签名页、项目页）因 S223 在改同文件而留下。本批按 0200 的口径补齐：

| 位置 | 原文 | 现文 |
|---|---|---|
| 发起第 3 步标签、时间选择弹层标题 | NFT 开售时间 | 铸造开始时间 |
| 第 3 步按钮 | 选择开售时间 | 选择铸造开始时间 |
| 第 3 步未选提示 | 请先选择 NFT 开售时间。 | 请先选择铸造开始时间。 |
| 时间选择提示 | 平台要求至少提前 N 开售 | 平台要求至少提前 N 开始铸造 |
| 太早提示 | 开售时间太早：… | 铸造开始时间太早：… |
| 发射模板卡（第 3 步与项目页） | NFT 价格 / NFT 发售期 | 铸造价格 / 铸造期 |
| 项目页「发射配置」、签名页「签名内容」 | NFT 开售 | 铸造开始（与用户侧项目页「勋章铸造」小节同词） |
| 我的项目行副标题 | 开售 10-19 12:30 | 10-19 12:30 开始铸造（0200 的预告句式） |
| 「修改开售时间」按钮（项目页、部署进度） | 修改开售时间 | 修改铸造开始时间 |
| 服务端拒绝 / 部署失败说明 | NFT 开售时间太早；距开售太近…修改开售时间… | 铸造开始时间太早；距铸造开始太近…修改铸造开始时间… |
| 用户侧项目页「勋章铸造」小节 | NFT 价格 | 铸造价格（与同节「铸造开始 / 铸造时长」一致） |

全仓 `grep 开售|发售` 后保留的：

- **发起步骤条第 3 步名**（`launch2CreateSteps`）：这一步除了铸造开始时间，还有回购收币地址和整套发射模板，改成「铸造」会名不副实。
  **主代理裁决（2026-10-19）**：改为「发射」，与页面标题「发起 v2 发射」一致，去掉「售」。步骤条现为「资料 / 链接 / 发射」（0202 §D 的「发售」作废）。
- **旧 IDO Launch（`lib/features/launch/`）**：已隐藏（0195），不在本批范围。
- 代码注释里的历史描述（如 `launch2_nft_mint.dart`「不再混用购买 NFT / 发售」）不是界面文字，不改。
- App 里没有「公开内盘开售」一类另有含义的用法。

### B. 项目页铸造中「已售」→「已铸」（S234-2）

- 顶部卡说明 `launch2InstanceFolioCaption` 铸造中：「每地址 1 枚 · 已售 N 枚」→「每地址 1 枚 · 已铸 N 枚」。
- 「项目 NFT」统计格：「已售」→「已铸」。与勋章页、列表的「已铸」一致。「内盘已售 x%」是曲线的卖出进度，不是 NFT，保留。

### C. 快照期顶部卡标签与正文同一个状态（S234-3）

- 根因：项目页顶部卡 kicker 用的是 `launch2StageLabel(stage)`，`snapshot_pending` 固定为「名单生成中」；正文用的是 0202 §A 的
  `launch2SnapshotPendingTitle(snapshot)`，会随 `publication` 变成「名单发布中」等。
- 修法：新函数 `launch2InstanceStageLabel(detail)`——`snapshot_pending` 时返回 `launch2SnapshotPendingTitle(detail.snapshot)`，其余阶段仍是 `launch2StageLabel`。
  顶部卡 kicker 改用它，标签与正文出自同一个函数。
- 列表行与发射台卡片的「名单生成中」不改：列表接口的行里没有 `snapshot.publication`，没有可依据的数据。

### D. 签名弹层停在「已广播」（S234-4）

- **弹层等的是什么信号**：什么都不等。MEME v2 没有 report / tx-result 路由（0139、合约 §3.4），签名出口 `Launch2SignSheet` 在钱包返回交易哈希后
  进入 `complete`，徽章「已广播」，说明「已广播（0x…）。广播不代表已成交，链上确认后这里会更新。」，之后**没有任何读取或监听**，只能手动「关闭」。
  「这里会更新」实际指的是关闭后的页面：页面在 `showLaunch2SignSheet` 返回后才记下这笔广播（`_record` / `Launch2NftMintSigned`），
  再按 `viewer` 变化判定「已在链上确认」。
- **为什么页面其它部分已更新而弹层没变**：弹层下面的项目页 / 勋章页一直按自己的定时器在读实例（项目页铸造期 15 s、提前购 5 s），读到的新数据画在弹层后面；
  弹层不订阅这份数据。S234 的 50–70 秒就是测试者看着弹层、直到手动关闭的时间，不是在等什么。
- **老问题还是新问题**：老问题。「已广播」作为签名出口的终态始于 0089（8b9c0b9，2026-09-25，`LoopSignSheet` 的 `complete => '已广播'`，
  注释「the sheet closes on a broadcast, never on a result」）；MEME v2 弹层这句「链上确认后这里会更新」始于 0139（74c2af0，2026-10-10）。0200 / 0202 没有碰这条路径。
  S227 没记，是因为当时测试者签完直接关了弹层。
- **根因不在后端**：实例详情的 `viewer`（`nft.held`、`curve.bought/sold`、自己的外盘计数）已能反映这笔交易，页面就是靠它判定的；弹层没用上而已。无需后端配合。
- **修法**：
  - `launch2OwnConfirmationSignature(detail, intent)`：只取「自己」的信号——铸造看 `viewer.nftHeld`，内盘买卖看 `viewer.curve` 的 bought/sold，
    外盘看自己的外盘计数（0148 的 `viewer.holding`）；外盘没有自己的计数、领取奖励、`viewer` 为空或钱包不是这笔意图的钱包时返回 `null`（不自动判定，
    不用全池成交数，免得别人的成交被当成自己的确认）。
  - `launch2ReadModelConfirmation(ref, detail, intent)`（`launch2_nft_mint.dart`）：以发起时页面上的 detail 为基线；广播后弹层启动监听，
    订阅页面在读的同一个 `launch2InstanceControllerProvider(instanceId)`，并在弹层打开期间每 `tradingInterval`（5 s）自己再读一次，最多 36 次
    （与页面的 `_settleLimit` 相同），所以不必等勋章页铸造期的 15 s。信号与基线不同即确认。
  - 弹层收到确认：徽章「已广播」→「已确认」，说明换成「铸造已在链上确认。」（与项目页同句，`launch2ConfirmedText`），步骤条该步「已广播」→「已确认」，
    2 秒后（`launch2SignConfirmedCloseDelay`）自己关闭并把原 outcome 交回页面。始终可以手动「关闭」。只有拿到哈希的 `submitted` 才监听，
    `locked`（钱包结果未知）不会被宣布成功。
  - 项目页与勋章页在记下广播时，先用屏幕上已有的读数结算一次（弹层期间可能已经读到了），再照旧重读，避免关闭后还停在「已广播…」。
  - 共享部件只加可选参数：`LoopSignSheet.completeLabel`（默认「已广播」）、`withStepUpStrip(signCaption:)`、`Launch2SignStepStrip.mainConfirmed`；
    其它签名出口不传，行为不变。
- **没有信号时的兜底**：保持「已广播」，可手动关闭；监听在 36 次读取后停止，弹层关闭时取消。不做「无条件 N 秒自动收起」——没有确认就收起，
  会把「广播」说成「完成」（AGENTS 29）。

### E. 钱包 Launch 链卡片加 tUSD1（S234-8）

- 根因：`WalletLaunchChainCard` 按 0038 时的契约只画原生币一行（当时 `launchChain` 只有 `nativeBalance`）；loop-api 0077 / 客户端 0088 加了
  `launchChain.usd1 {balance, allowance}`，解码一直在，但卡片从没画它（数据只给旧 IDO 的授权判断用）。
- 修法：tBNB 一行之下加一行 USD1（键 `wallet-launch-chain-usd1-row`）：测试网写「tUSD1」（与水龙头同名）并带测试网徽章，主网槽写「USD1」；
  数值为 18 位精度整数换算、两位小数、千分位；没有行情、不估值、不计入总资产。`usd1` 缺省表示「未读取」，不画这一行，也不画 0；
  原生币读失败时仍画已读到的 USD1。
- 主资产区与总资产仍只读主网（0038），不改。测试网槽时卡片下加一句（键 `wallet-launch-chain-total-note`）：
  「Launch 链是 BSC 测试网余额，不计入总资产；总资产只统计 BNB Smart Chain 主网。」（**主代理裁决**：去掉初稿里的「没有真实价值」。）
- **主代理裁决：Launch 链卡片跟随「隐藏余额」**（0175 / 0188）。`WalletLaunchChainCard(hidden:)` 由钱包页传入同一个 `hidden`：
  tBNB 余额、「可动用」与 tUSD1 余额一起显示 `walletMaskedFigure`（`****`），读屏标签同样不念数；「手续费保留」是策略值，与主资产区一样不遮；说明句不遮。

### F. 提前购开始后项目页没有勋章页入口（S234-7）——不改，产品待定

- 现状：项目页只在铸造中的「项目 NFT」卡里有「铸造页」入口（`launch2-nft-open`）；进入快照期 / 提前购 / 公开内盘 / 已毕业后，只能从钱包里点这枚 NFT 进勋章页。
- **主代理裁决：不改代码，待需求方定**。位置建议（任选其一，**待需求方**）：
  1. 「名单已发布」区块（0202 §A）下方加文字按钮「查看我的勋章」，仅持有者显示——最贴近「名单 ↔ 勋章」的语义；
  2. 提前购买入面板「名单内」状态行旁加「我的勋章」链接——持有者在提前购最常看的位置；
  3. 顶部卡 caption 下的 footer（与地址复制同一行）放「勋章」小链接，所有阶段通用。
- 本批不加入口，docs/22 已写明「要从钱包点这枚 NFT 进勋章页」。

## 主代理裁决（2026-10-19，追加提交）

1. 第 3 步步骤名「发售」→「发射」（与页面标题一致），测试断言同步。
2. 钱包 Launch 链说明句去掉「没有真实价值」。
3. Launch 链卡片跟随「隐藏余额」，tBNB / tUSD1 一起遮。
4. S234-7 不改代码，三个入口建议保留，标「待需求方」。

## Consequences

- 创建者一侧与用户侧只剩「铸造」一套词；发起步骤条为「资料 / 链接 / 发射」，App 的 MEME v2 界面里不再有「开售 / 发售」。
- 快照期项目页的标签与正文一致；列表行仍是「名单生成中」（无数据）。
- 铸造 / 内盘买卖 / 有自己外盘计数的外盘买卖：弹层在读数反映后约 5 秒内变「已确认」并在 2 秒后自己关闭；弹层打开期间每 5 秒多一次实例读取，最多 36 次。
  外盘无自己计数与领取奖励维持原样（手动关闭）。
- 钱包页能看到测试网 tUSD1；总资产口径不变，并在卡片上说明；「隐藏余额」时整张 Launch 链卡片的余额一起遮。

## Tests

- `test/fixtures/s236/`（每个文件 `_derived` 写明）：S234 只留了界面截图与 UI dump、没有原始响应，所以把 S234 的事实（项目 d88f89f5…、S234 Walk / S234W、
  代币 0xe84c…6666、v8、12:30–13:30、已铸 2、截止块 137,646,108、名单 2 人、账号 2 约 4,850 tUSD1）写到已抓包的形状上：
  `instance_snapshot_pending_broadcast`、`instance_nft_sale_before_mint`、`instance_nft_sale_after_mint`（派生自 s233 / S171 抓包），
  `wallet_balances_launch_chain`（`launchChain` 块，形状同 s83c2 `_launchChainWire`）。
- `test/s135_launch2_creator_pages_test.dart` 组 `S236 · decision 0203`：第 3 步「铸造开始时间 / 选择铸造开始时间 / 铸造价格 / 铸造期」、未选提示与时间弹层标题，
  页面无「NFT 开售 / NFT 发售 / NFT 价格 / 开售时间」；0202 组的步骤条断言改为「资料 / 链接 / 发射」；项目页「铸造开始」与模板卡；签名页「铸造开始」；部署失败说明。原两处断言改为新词。
- `test/s182_launch2_desk_nft_test.dart` 组 `S236 · decision 0203`：名单发布中时顶部卡 kicker 与正文同为「名单发布中」、无「名单生成中」；
  铸造中顶部卡「已铸 2 枚」、统计格「已铸」、无「已售」；勋章页与项目页铸造：广播后「已广播」→ 读到 `after` →「已确认」+「铸造已在链上确认。」→ 2 秒后弹层自行关闭，
  勋章页显示 #2、已持有与 toast；读数不变时停在「已广播」、读取不超过上限、「关闭」可关；`launch2OwnConfirmationSignature` 只认自己的信号。
- `test/s236_s234_followups_test.dart`：fixture 解码；钱包页 Launch 链卡 tBNB 下有 tUSD1「4,850」与测试网徽章、说明句；无 `usd1` 不画行；原生币不可用仍画 USD1；
  主网槽写「USD1」、无说明句；`hidden: true` 时 tBNB、可动用、tUSD1 都是 `****`，说明句仍在。
