# 0142 · MEME v2 项目方侧接 S142-api：冷启动续走、开售提前量、项目类型、显式 EIP712Domain、`closed_no_holders`（S142）

## Status

Accepted 2026-10-10。主代理下单（S142-mobile），基线 `integration/v2` 714d752，分支 `feat/S142-mobile`。
后端 loop-api `integration/v2` 548066c（决策 0120）；合同 `docs/frontend-v2-hooks-launch-api.md` §2 / §4 / §10、
`docs/frontend-v2-launch2-api.md`（阶段表 `closed_no_holders`、§3.2 `snapshot.closure`、§3.3 报价表）、
`openapi/loop-api.v2.json`。承接本仓决策 0138「未决项」1、2、3、5、6 与 0139。不新增依赖，`pubspec.lock`、
路由清单、视觉 token 不变。

## Context

0138 时服务端不下发三样东西，App 只能把它们记在本次运行的内存里（`Launch2CreatorMemory`）：项目最新部署任务、
Hooks 草稿审批状态、开售提前量。loop-api 0120 把它们放进了 `GET hooks-config`（`approval`、`latestDeployment`、
`minSaleLeadSeconds`，三者必填，前两者可空），给目录项目加了 `kind`（`ido | launch2`）与 `?kind=` 过滤，
签名请求的 `typedData.types` 显式列出 `EIP712Domain`，并新增终态 `closed_no_holders`（NFT 零认购）与必填的
`snapshot.closure`。Development（:3100）还没升到 548066c，所以本批 fixture 全部按合同手写（`_handwritten` 注明来源）。

## Decision

### 1. 冷启动续走（0138 未决 1、2）

- `Launch2CreatorGateway.loadConfig` 改返回 `Launch2HooksConfig {draft, approval, latestDeployment, minSaleLead}`。
  `Launch2CreatorMemory`（内存记 job / 未审批）删除：同样的事实现在每次都从服务端读。
- **当前任务** `Launch2HooksConfig.currentJob`：`latestDeployment` 去掉 `cancelled`，以及「不可重试的 `failed` 且草稿版本
  已高于任务版本」（项目方改了配置来修它）；其余原样。
- **状态投影**（`launch2CreatorStatusOf`，取代 0138 §2）：实例已被读模型列出 → active；有当前任务 → 按任务状态
  （activated / verified / confirmed / 进行中或可重试失败 / 最终失败）；目录审核 `returned / rejected` → rejected；
  无草稿 → draft；`approval.status = approved` → approved；目录审核仍是 `draft`（从未提交）→ draft；其余 →
  awaiting_approval。签名闸门只看 Hooks 审批（loop-api `HOOKS_CONFIG_NOT_APPROVED`），所以「可签」以 `approval` 为准。
- **续走决策表**（`launch2CreatorResumeOf` + `Launch2CreatorRoute.resume`）——「我的项目」点行直接落页：

  | 状态 | 落到 |
  | --- | --- |
  | draft（无草稿，或已存未提交） | 资料 / 配置页 `/launch2/create?project=` |
  | awaiting_approval、rejected | 项目状态页（等审核页 / 审核意见）`/launch2/project?id=` |
  | approved（无任务） | 签名部署页 `/launch2/project/sign?id=` |
  | deploying / deployed / verified / deploy_failed | 部署进度页 `/launch2/project/deployment?id=&job=`（当前任务） |
  | active 且实例已列出 | 用户侧项目页 `/launch2/instance?id=`（「你是项目方」条，0139） |
  | active 但读模型还没列出 | 项目状态页（「项目页生成中」） |

  列表每行读一次 `hooks-config`；只对当前任务为 `activated` 的行查实例（失败当作未列出，不拖垮列表）。
- **等审核页**只有「审核中」与「已批准 · 时间」两种（主代理裁决：Hooks 配置的拒绝流程待需求方答复后另批）。
  目录项目自身的 `returned / rejected`（0138 已有，原句展示审核意见）保持不变。

### 2. 最早可选开售时间（0138 未决 3）

- 最早可选 = `launch2EarliestSaleStart(now, minSaleLead)`：现在 + 服务端提前量，向上取整到分钟；选择器
  `minimumDate` 用它，抽屉一行写「平台要求至少提前 N 小时开售，最早 …」。
- 新建项目在创建前没有 `hooks-config` 可读，选择器先用合约下限 4,200 s；「提交审核」在写草稿前先读一次
  `hooks-config`（同时拿 CAS 版本与提前量），所选时间早于「现在 + 提前量」就**不写**，页内一行
  「开售时间太早：平台要求至少提前 …，最早 …，请重新选择」，选择器随即按服务端提前量收紧。
- 服务端 `400 INVALID_REQUEST` 兜底仍保留（原「最常见原因是开售时间太早」一行）。

### 3. 项目类型（0138 未决 5）

- `LaunchProject.kind`（`LaunchProjectKind.ido | launch2`）进模型，codec 必填、枚举外即 invalid。
- `LaunchGateway.listProjects` 加可选 `kind`；「我的项目」请求 `?kind=launch2`，过滤列表里出现别的 kind 即 invalid。
  经典路径不传 `kind`（服务端默认 `all`），请求不变。
- `LaunchProjectDraft.kind` 只进 `toCreateRequestJson()`（`POST`）；`toRequestJson()`（`PUT`、经典创建）不带——
  经典创建 body 与幂等摘要与 0120 前逐字节相同。v2 发射创建带 `kind: "launch2"`。

### 4. 签名：显式 `EIP712Domain`（0138 未决 6 的前半）

- codec：`typedData.types` 必须恰好是 `EIP712Domain` + `LaunchRequest` 两个键，`EIP712Domain` 必须恰好是
  `name string / version string / chainId uint256 / verifyingContract address` 四项且按此顺序；缺失、乱序、多 `salt`、
  多类型都判 invalid。
- `launch2TypedDataJson` 不再补齐（0138 §4 的唯一例外撤销），把服务端对象原样 `jsonEncode` 交给 Privy
  `eth_signTypedData_v4`；万一没有 `EIP712Domain` 就拒签（`privy_payload_unencodable`），不再自行补。测试断言
  交给钱包的 JSON 与样例 `typedData` 的编码逐字节相同。

### 5. 终态 `closed_no_holders`

- `Launch2Stage.closedNoHolders`（`terminal`，非 `tradable`）；`snapshot.closure {reason: no_holders, cutoffBlock,
  closedAt}` 必填可空进 `Launch2Snapshot.closure`。一致性：该阶段必须有 closure；closure 只能出现在该阶段或
  `paused`（完整性挂起优先，合同 §2）；终态的 `nextChangeAt` 必须为 null。
- 项目页：阶段条「已关闭 / 无人认购，已关闭」，圆点灰；内容区整块灰度（`Launch2Greyed`）：线稿插画 + 标题
  「无人认购，已关闭」+ 一句说明 + NFT 已售 / 截止块 #N / 关闭时间；无底栏、无交易面板；终态不再轮询详情。
- 列表行：右侧只一行灰字「无人认购，已关闭」，胶囊灰底「已关闭」。
- **列表规则（S121 / 0139 §2 补充）**：「v2 发射」段按服务端顺序画，但 `closed_no_holders` 行沉到已读到的所有其他行
  之下（彼此保持服务端顺序）；翻页后新页的非终态行插在已显示的关闭行之上。「已毕业」段是 `stage=graduated`，
  不会出现关闭行。不另开分段——零认购项目极少，单开一段会长期是空态。
- **409 `LAUNCH2_STAGE_MISMATCH`**（报价、MAX 报价、交易 prepare、NFT prepare）：留在面板 / 页内一行
  「当前阶段不能交易，已重新读取项目状态」，同时立即重读详情（合同 §3.3「当作未开放、继续读详情」），不进错误页、
  不弹 toast。

## 与下单描述的偏离

- 「冷启动续走」落在「我的项目」的行点击；项目状态页仍保留（等审核 / 已批准 / 审核意见 / 生成中都在这页），
  其他入口（深链、通知）进状态页后由页内下一步按钮继续，不做自动跳转——自动跳转会让返回键在两页间来回。
- 新建项目时还没有 `hooks-config` 可读，最早可选时间先用合约下限，写草稿前再按服务端提前量拦一次（见 §2）；
  下单写的「用 `minSaleLeadSeconds` 限制选择器」对编辑中的项目与拦截之后成立。
- `closed_no_holders` 文案：胶囊放不下 8 个字，胶囊与阶段名用「已关闭」，整句「无人认购，已关闭」放在行右侧、
  阶段条说明与页内标题。

## Consequences

- 新字段全部按合同必填：`hooks-config` 三键、`project.kind`、`snapshot.closure`。**Development 升到 548066c 之前，
  本分支对 dev 的项目方页、经典 Launch 项目页与 v2 项目详情都会因缺键判 invalid**；合并顺序须是先升 dev 再上本批。
- 主仓 `LOOP/docs/integration/preflight-2026-09-16/responses/` 里旧的 `v2_launch_projects_*`（无 `kind`）与
  `v2_launch2_instance_*`（无 `closure`）样例在 `device_preflight_replay_test` 回放时会失败（本 worktree 找不到该目录，
  套件整体跳过）；dev 升级后需重抓。
- `Launch2CreatorMemory` 删除；签名页提交后由部署进度页与 `latestDeployment` 接续，`HOOKS_CONFIG_NOT_APPROVED`
  不再写本地标记（下一次读 `approval` 就是事实）。
- 新增 fixture：`hooks_config_approved.json`、`hooks_config_deploying.json`、`hooks_config_activated.json`；
  `hooks_config_empty / draft`、`hooks_signing_request` 补 0120 字段。

## 未决项（需后端 / 主代理决策）

1. Hooks 配置的「拒绝 / 审核意见」：后端审核模型没有拒绝状态、审核备注不下发（loop-api 0120 Open 1）；等需求方定规则后另批。
2. `closed_no_holders` 之后项目方能否再发起（同项目新配置版本，还是新目录项目）是产品问题（0120 Open 3）；
   本批项目方侧把它当作 active 的实例展示（状态页 → 用户侧项目页显示「已关闭」），没有「重新发起」按钮。
3. 「社区绑定」仍是四个链接（0138 未决 4 / 0120 Open 2）。
4. Privy 真机首签仍需验证（0138 未决 6 后半 / 0120 Open 5）；现在交给钱包的是服务端原对象。
5. Development 升 548066c 后需重抓本批 fixture 与主仓 preflight 样例（见 Consequences）。
