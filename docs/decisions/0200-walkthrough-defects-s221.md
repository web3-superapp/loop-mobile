# 0200 · S221 走查缺陷七条（S224-mobile）

## Status

Accepted 2026-10-17。基线 `integration/v2` 65d9a2d。依据：S221 在 staging 用 build 27 的真人走查
（`LOOP/docs/integration/S221/notes.md` 与 `shots/2-2 … 5-1`），loop-api `openapi/loop-api.v2.json`（861031d）、
loop-api 决策 0120 / 0122 / 0114，客户端决策 0137 / 0139 / 0142 / 0144 / 0161 / 0163。
不新增依赖、路由、字体、颜色 token；`pubspec.lock` 不变；无新请求路径（只多了对已有 `POST hooks-deployments` 的一次幂等重放与一次 `GET hooks-config`）。
发起表单第 1 步的字符校验与格式化函数（`launch2FieldError`、ticker 大写、`$` 前缀）归 S223，本批未动。

## Context

S221 按走查流程用 App 真人自验 staging（build 27 代码），发现七条 App 缺陷：拒绝理由不可见、重提后提交时间不更新、首次部署提交误报、
项目页相对时间不刷新、内盘面板无滑点说明、发售 / 铸造两套词混用、「测试网合约还在核对」常驻。下面逐条写现象 / 根因 / 修法，测试见 Tests。

## Decision

### 1. 被拒绝后看不到拒绝理由

- **现象**：审核人拒绝配置 v2 后，我的项目仍是「草稿 · 开售 13:56」（v1 的时间），点进去是编辑表单、没有理由。
- **根因**：不是解码问题——`hooks-config.approval.rejection` 早已解码（0144），状态投影也会给 `rejected`。
  我的项目在 13:26 读过一次后一直挂在路由栈底：行 → 编辑 → 提交（`pushReplacement` 项目页）→ 返回，回到的是 13:26 那份答案
  （当时 v1、项目 `draft`，投影为「草稿」，点开即 `edit`）。列表控制器 `autoDispose` 但页面一直被 watch，不会重读；
  保存成功也没有作废列表与项目页的答案。编辑表单本身从不显示拒绝。
- **修法**：
  - 新部件 `Launch2RefreshOnReturn`（`launch2_creator_widgets.dart`）：被别的页盖住后重新回到栈顶时调用一次 `onReturn`
    （与 `launch2_list.dart` 同一判据 `ModalRoute.isCurrentOf`）。我的项目与项目状态页都包上，回到页面即 `reload()`（已有答案、未在读时）。
  - `Launch2SaveController.save` 成功后 `invalidate` 该项目的 `launch2ProjectControllerProvider` 与 `launch2CreatorListControllerProvider`。
  - 列表行：拒绝时副标题「已拒绝 · 原因类别」（`launch2RejectedRowText`，如「已拒绝 · 其他原因」），徽章仍是「未通过」；老后端无结构化拒绝时用服务端原句，缺省「已拒绝」。
  - 编辑表单：状态为 `rejected` 时，步骤条下方每一步都显示 `Launch2RejectionNotice`（类别标题 + 「审核意见：审核人原话」+ 时间与是配置还是资料被拒）；
    退回而无结构化拒绝时显示服务端原句。重提后新版本是 `awaiting_approval`，`rejection` 为空，横幅不再出现（项目页、列表同理）。

### 2. 重提后「提交时间」不更新

- **根因**：项目页「审核中」取目录项目的 `submittedAt`，那是第一次提交；配置被拒后重提只保存新配置版本（项目审核状态未变），`submittedAt` 不动。
  列表「开售」取最新草稿的 `nftSaleStart`，本来就是最新版本——显示旧值是第 1 条的陈旧答案。
- **修法**：`launch2LatestSubmission` = `submittedAt` 与最新配置版本 `draft.updatedAt` 中较晚者（`submittedAt` 为空则仍为空，不推断提交）。
  第一次提交前存的版本早于 `submittedAt`，所以首提显示不变。

### 3. 首次「签名并提交部署」误报

- **现象**：服务端日志只有 received、没有 completed；App 显示「操作没有完成，请稍后再试。」（= `unexpected`），再点一次 200 进进度页。
- **根因（App 侧）**：Dio 把对端中途关掉的连接报为 `DioExceptionType.unknown` → 写操作的 `unexpected`（同 `chain_controllers.dart` 首读重试注释里记的掉线 socket；
  签名在钱包里停留较久，复用的空闲连接最容易遇到）。网关对 `offline / cancelled / outcomeUnknown / unexpected` 已保留幂等键（0124 / S6 写规则），
  所以第二次点击（EIP-712 签名确定性，同一签名 → 同一键）是幂等重放、拿到 200。但签名控制器把这类「没有答案」当失败直接报错，
  没有自己重查——机制在网关层覆盖了，在页面层没生效。后端为何没有 completed 另有人查。
- **修法**：`Launch2SignController.signAndSubmit` 遇到 `launch2SubmissionUnanswered`（offline / timedOut / cancelled / outcomeUnknown / unexpected）时：
  等 `Launch2CreatorPolling.submitRecheckDelay`（默认 2 s）→ 用同一签名再提交一次（网关复用同一幂等键）→ 仍无答案或被拒时读一次 `hooks-config`，
  `latestDeployment` 是本次签名的 `configVersion`、且不是 `cancelled` / 终态 `failed`，就当作本签名建出的任务进进度页；都没有才显示原错误。
  服务端明确的拒绝（权限、校验、409 等）不重放；重放得到 `VERSION_CONFLICT` 且查不到任务时仍走原来的「重新读请求、重新签名」。

### 4. 项目页相对时间不刷新

- **根因**：`launch2SaleStartLabel(start, now)` 的 `now` 在 build 时取一次，页面不重建就一直是打开时的「1 小时后」。
- **修法**：「NFT 开售」行包在已有的 `Launch2CountdownBuilder`（实例页倒计时同一 ticker，读 `launch2ClockProvider`，到点自停）里，每次 tick 用页面时钟重算；
  过了开售时间只显示时刻。

### 5. 内盘交易面板没有滑点选项

- **结论**：按设计不加。0139 已定「内盘面板没有滑点选择（服务端默认 100 bps）」：曲线按合约公式定价，报价的 `minOut` 已含服务端容忍度，
  客户端带报价的 `minOut / deadline` 去 prepare（0148）；0157 / 0159 只把外盘（官方池）的 0.5 / 1 / 3% / 自定义 复用到 LoopDynamic，未改内盘。
- **修法**：「最少获得 / 最少到手」下加一行说明 `launch2CurveMinOutNote`：「按当前曲线价计算，已含 1% 滑点保护，成交以链上为准」（百分比取报价的 `slippageBps`）。

### 6. 文案统一成「铸造」

- 保持 App 的「共识勋章铸造中 / 铸造 1 枚 · 100 USD1 / 已持有 · 每地址 1 枚」。用户侧 MEME 列表、账本卡、记录卡、项目页、共识勋章页、签名弹层里
  「NFT 发售 / 开售 / 认购 / 购买 NFT / NFT 已售」统一改为铸造用词，例如：阶段「即将铸造」「铸造中」「无人铸造，已关闭」；
  「铸造倒计时」「距铸造」「铸造期 1 小时」「10-17 16:58 开始铸造」「后开始铸造」「已铸 N」；项目页小节「勋章铸造 · 铸造开始 · 铸造时长」、「铸造进度」「三段发射」；
  按钮「铸造勋章」「已持有勋章」。
- 0163 的两种入口命名（项目页「购买 NFT」、勋章页「铸造」）合一：`Launch2NftMintEntry.noun` 两个入口都是「铸造」，确认弹层「铸造 T 共识勋章」「继续铸造」，签名弹层「确认铸造」。
- 未改：创建者一侧（「NFT 开售」「NFT 发售期」与第 3 步「发售」步骤名，属发起表单，S223 正在改同文件）、旧 IDO Launch（已隐藏）、「NFT 价格」「项目 NFT」等不含发售/铸造对立的名词。

### 7. 「测试网合约还在核对，交易可能暂时不可用」常驻

- **根因**：不是 staging 配置，也没有后台 / env 开关。loop-api `launch2Capability()`（`src/features/meta/product-policy.ts`）在模块开着时把 evidence 写死为
  `{status: pending, reasonCode: LAUNCH2_TESTNET_EVIDENCE_PENDING}`，注释为「记录 BSC 测试网跑通前一直 pending」；客户端 0137 §3 还会把 `launch2` 上的 `confirmed` 判为无效载荷。
  App 把这个模块级常量当成每个实例的状态，于是每个项目页都常驻这句——判定过宽。
- **修法**：`launch2EvidenceNoticeShown`：只有 evidence pending 且原因码不是 `LAUNCH2_TESTNET_EVIDENCE_PENDING` 时才显示（其它原因码 = 运行时缺依赖，仍显示）。
  实例自己的交易护栏是 0161 的 trading hold，不受影响。
- **后端须知**：若以后要让 `launch2` 有「已核对」状态，需要 loop-api 改 `launch2Capability()`（新增配置项或按运行记录给 `confirmed`）并同时修订客户端 0137 §3 放行 `confirmed`；
  目前没有任何后台或 env 项可以改它。

### D10. 外盘成交缺「另有回购 M 笔」

- **现象**：实例页外盘成交只写「13 笔用户成交」，回购卡已显示「2 笔 200 USD1」，docs/22 的「另有回购 M 笔」没出现。
- **根因**：0150 的这一行只用池子自己的拆分 `pool.tradeCount - pool.userTradeCount`；S221 实例上两者相等（服务端池索引没把这两笔回购 swap 从用户成交里分出去），差为 0 就不画。
  回购笔数在现有响应里另有来源：实例详情 `buyback.executedCount`（回购卡用的同一字段），App 已解码，无需新字段、不改 loop-api。
- **修法**：`launch2PoolBuybackCount(detail)`：池子拆分 > 0 时用它，否则用 `buyback.executedCount`，> 0 才显示「另有回购 M 笔」。
- **后端须知**：若池子拆分为 0 是因为回购 swap 被算进了 `userTradeCount`，那「13 笔用户成交」本身多算了回购，需要后端让 `userTradeCount` 排除回购执行器 / 适配器的 swap；App 不从两个来源相减推断。

## Consequences

- 我的项目与项目状态页回到栈顶即重读，保存成功作废两者旧答案；审核结果、新版本、新开售时间不再需要手动下拉才看到。
- 部署提交「没有答案」时最多多一次同键重放和一次 `GET hooks-config`；服务端明确拒绝的行为不变。后端 received-without-completed 另查。
- 用户侧 MEME 页面只剩「铸造」一套词；创建者侧与旧 IDO 未改（见第 6 条）。
- `launch2` 的 evidence 横幅在当前后端上不再出现；要恢复「已核对」语义须后端与 0137 §3 同改。

## Tests

- `test/s135_launch2_creator_pages_test.dart` 新组 `S224 · decision 0200`（10 例）：我的项目被盖住时不读、回到栈顶重读并显示「已拒绝 · 其他原因」；
  编辑表单显示类别 + 审核人原话 + 「发射配置未通过审核」，且翻到第 2 步仍在；等待审核的新版本无横幅；`launch2LatestSubmission` 三种情形；
  项目页显示重提时间而非首提时间；「（1 小时后）」随时钟变为「（59 分钟后）」、过点只剩时刻；
  部署提交 `unexpected` 后同签名重放成功进进度页、无报错；两次 `offline` 后读到同版本任务即进进度页；
  重放与读配置都无果才显示「操作没有完成」、`permissionDenied` 不重放不读配置；无答案判定表。原「审核未通过：其他原因」行断言改为「已拒绝 · 其他原因」。
  `_pump` 的轮询覆盖加 `submitRecheckDelay: Duration.zero`。
- `test/s224_walkthrough_defects_test.dart`：内盘说明文案；阶段标签 / 说明不含「发售 / 开售 / 认购」、两种铸造入口同名；evidence 横幅判定（模块常量不显示、其它原因与无原因显示、无 pending 不显示）。
- `test/s152_launch2_pool_user_trades_test.dart`（D10）：池子拆分为 0、回购台账 2 笔 →「13 笔用户成交 · 另有回购 2 笔」；池子拆分有值时以它为准；原「没有回购」「只有回购」用例把台账固定为 0。
  `test/support/launch2_fixtures.dart` 的 `l2Detail` / `l2DetailJson` / `l2BuybackSummaryJson` 加可选 `buybacksExecuted` / `executedCount`。
- `test/s177_launch2_trading_hold_test.dart`：内盘报价块内有「最少获得」说明行。
- `test/s136_launch2_user_test.dart`、`test/s182_launch2_desk_nft_test.dart`：文案断言随第 6 条改为铸造用词；「项目页入口」签名流程改为与勋章页同名（「铸造 FROG 共识勋章」「继续铸造」「确认铸造」，弹层不出现「购买」）。
