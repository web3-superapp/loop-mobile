# 0138 · MEME v2 项目方侧：发起 → 审核 → 签名部署 → 部署进度 → 激活（S135）

## Status

Accepted 2026-10-10。主代理下单（S135-mobile），基线 `integration/v2` 24695c0，分支 `feat/S135-mobile`。
设计稿 `LOOP/docs/modules/S134-S137-meme-v2-app.md` §1、§3；后端合同 loop-api
`docs/frontend-v2-hooks-launch-api.md`（S125 / S132，决策 0108 / 0112 / 0117）与
`docs/frontend-v2-launch2-api.md`（决策 0114）、`openapi/loop-api.v2.json`。不新增依赖；路由清单 105 → 110。

## Context

loop-api 没有 `/v2/launch2/projects`：0114 明确项目方流程留在 S125 的路由上。实际可用的服务端事实是三样：

1. **目录项目** `POST/GET/PUT /v2/launch/projects`、`POST …/submit`（`reviewStatus` = 平台审核，
   `reviewReasonText` = 审核意见原句）。App 已有 `LaunchGateway` 覆盖这五个调用（S7 / 决策 0058）。
2. **Hooks 草稿** `GET/PUT …/hooks-config`（CAS，`expectedVersion`；经济参数由服务端按 `hooks_launch_v1` 推导）。
3. **部署任务** `GET …/signing-request` → EIP-712 → `POST …/hooks-deployments` → `GET …/{jobId}`（9 个状态、`events[]`）。

设计稿的 10 个项目状态（draft / awaiting_approval / approved / signing / deploying / deployed / verified /
active / rejected / deploy_failed）因此是**投影**，不是服务端字段。

## Decision

### 1. 路由（manifest 105 → 110，模块 `4-launch`，step 7，prototypeOrder 120–124）

| slug | path | archetype · layout |
| --- | --- | --- |
| `launch2-create` | `/launch2/create`（`?project=<id>` 编辑） | action · focus |
| `launch2-projects` | `/launch2/projects/mine` | index · stream |
| `launch2-project` | `/launch2/project?id=` | record · stream |
| `launch2-project-sign` | `/launch2/project/sign?id=` | action · focus |
| `launch2-project-deployment` | `/launch2/project/deployment?id=&job=` | state · stream |

清单禁止路径里出现 `:`，所以设计稿的 `/launch2/projects/:id` 落成 `/launch2/project?id=`（与 MEME
`/meme/token?id=` 同法）。路由表由 `lib/features/launch2/creator/launch2_creator_routes.dart` 的
`launch2CreatorRoutes()` 生成，`lib/app.dart` 只追加一行展开。

### 2. 状态投影（`launch2CreatorStatusOf`）

| 服务端事实 | 状态 |
| --- | --- |
| 实例列表里有本项目（`GET /v2/launch2/instances` 按 `projectId` 找到） | active |
| job `activated` / `verified` / `confirmed` | active / verified / deployed |
| job `awaiting_executor` · `claimed` · `broadcast` · `reorged`，或 `failed` 且 `retryable` | deploying |
| job `failed` 且不可重试 | deploy_failed |
| `reviewStatus` `draft`，或已通过但还没有 Hooks 草稿 | draft |
| `submitted` / `in_review`；或已通过但提交答 `403 HOOKS_CONFIG_NOT_APPROVED` | awaiting_approval |
| `returned` / `rejected` | rejected（returned 可改资料重提，rejected 只能重新发起） |
| `approved`（无 job，或 job `cancelled`） | approved |
| 签名页打开、钱包签名中 | signing（页面本地态） |

### 3. 资料页三步

① 头像（必填，`logoAssetUrl` 必须 https，复用 MEME 的 `POST /v2/media/community-logos` 上传）、名称（1–64）、
代码（2–12 位字母数字，转大写）、简介（≤ 2000，可空）；② 社区：X / Telegram / 官网 / Discord（https，可空）——
同时写入目录项目 `officialLinks` 与 Hooks `links`；③ NFT 开售时间（底部抽屉 `CupertinoDatePicker`，不用对话框）、
回购收币地址（默认 `0x28816c4C4792467390C90e5B426F198570E29307`，可改，提示「部署后不能再改」，地址框关
autocorrect / suggestions）、固定模板只读卡（总量 10 亿为本页唯一 figureXl；8 亿 / 133,333.332 USD1 / 10% /
2% / 0.5% / NFT 100 USD1 / 发售期「由实例决定」，存过草稿后改显示服务端 `fixedEconomics`，发售期显示 7 天）。

「提交审核」依次：`POST /v2/launch/projects`（编辑时 CAS `PUT`）→ `PUT hooks-config`（`expectedVersion` 0 或
当前版本；`409` 读一次最新版本再存一次，不循环）→ `POST …/submit`。已落地的步骤重试时不重做（不会建第二个项目）。
已通过审核的项目再编辑只存 Hooks 草稿（目录项目已不可编辑），保存新版本会让旧审批失效，由服务端决定。

**开售提前量**：服务端 `HOOKS_LAUNCH_MIN_SALE_LEAD_SECONDS` 不通过任何接口下发，所以选择器的最早时间是合约下限
4,200 s（激活缓冲 3,600 + 执行器余量 600）+ 1 分钟，默认建议两天后整点；不足服务端配置时 `400 INVALID_REQUEST`，
页面一行说明「最常见原因是开售时间太早」。不写死 24 小时。

### 4. 签名部署

`GET signing-request?walletId=`（钱包目录的活跃钱包，不传地址）。codec 校验：`request` 十键、`typedData.domain`
四键、`primaryType = LaunchRequest`、`types.LaunchRequest` 正好 11 个字段、`message` 与 `request` 的每个重复字段相等
（不等即 invalidPayload，保证「展示的就是签的」）、`memeAddress` 以 `6666` 结尾。页面：代币地址（尾号 Lime，本页记忆点）、
Hook、网络（domain.chainId → `BSC 测试网`）、EIP-712 摘要（名称 / 代码 / 开售 / 收币地址 / nonce / 有效期倒计时，
倒计时独立 widget 每秒只重绘自己）。

签名经共享 `LoopSignSheet`（标题「授权部署」、测试网徽标、事实行：操作 / 代币地址 / 签名钱包 / 有效期至 / 花费「无」）→
`launch2TypedDataSignerProvider`（生产 = Privy `eth_signTypedData_v4`，绑定 `request.projectOwner` 对应的内嵌钱包，
domain.chainId 必须等于请求的链）→ `POST hooks-deployments`（UUIDv4，一个签名一个 key；仅结果未决的重试复用 key）。

- 过期：倒计时到 0 或签名前判定过期 → 主按钮换成「续期签名请求」，重新 GET，不签旧请求。
- `409 VERSION_CONFLICT`：自动重读签名请求，提示「配置或 nonce 已变化，已刷新」，用户重新签（新签名 = 新 key）。
- `403 POLICY_BLOCKED / HOOKS_CONFIG_NOT_APPROVED`：提示等审批，并在本次运行内把项目标成 awaiting_approval。
- `503 HOOKS_LAUNCH_DISABLED` / `HOOKS_LAUNCH_FACTORY_UNAVAILABLE`：一行原因 + 重试，无签名按钮。
- 钱包拒签 / 钱包不符 / 会话不在：一行原因，不提交。

**EIP712Domain 补齐**：服务端 `types` 只有 `LaunchRequest`。有的签名实现把缺失的 `EIP712Domain` 当空结构哈希，
得到不同的域分隔符、签名被 Factory 拒。`launch2TypedDataJson` 在缺失时按 EIP-712 规定顺序补
`EIP712Domain`（只列 domain 里实际出现的字段），哈希不变，其余键不动。这是对「payload 原样交给钱包」的唯一例外，
记录在此；真机首签时需验证 Privy 的签名能被后端恢复出同一地址（见未决项）。

### 5. 部署进度

每 5 s 读一次 job（`activated` / 不可重试的 `failed` / `cancelled` 后停；读失败继续轮询）。顶部是状态一句话
（§9.1 文案，figureLg），下面预测/实际 MEME 地址，然后 `events[]` 时间线（按 `sequence` 升序；7 个成功事件有专用文案，
`included` 等可选 kind 有文案但不依赖，未知 kind 显示「状态更新」）。部署 / 激活交易一行，右侧图标复制 BscScan
测试网链接（App 不开浏览器，沿用钱包交易详情的做法）。失败按 §9.2：可重试显示「平台处理中，会自动重试」不给按钮；
`HOOKS_ACTIVATION_WINDOW_CLOSED` 给「修改开售时间」；其余给「重新签名」。`activated` 后按 `projectId` 轮询实例列表
（最多 10 次），找到即「查看项目页」。

### 6. 入口与开关

`LoopFeatureSwitches.launch2Visible` 仍为 false。新增 `Launch2CreatorEntry` / `Launch2MyProjectsEntry`：开关关时
`SizedBox.shrink()`，开且 `launch2 == available` 才画。MEME Tab 的「发起」选择抽屉（v2 / 经典）由 S136 统一做时放入
这两个组件；本批不改 MEME Tab。用户侧实例页（S136）尚未挂载，`openInstance` 暂时 `go('/meme')`。

### 7. 只在本次运行内记住的事

服务端没有「项目的部署任务列表」，也不下发 Hooks 草稿的审批状态。`Launch2CreatorMemory`（Riverpod，内存，换账号清空，
不持久化——AGENTS 第 23 条不允许把这类数据放进 SharedPreferences）记住本次运行提交过的 job 与被拒为「未审批」的项目。
冷启动后：已激活的项目靠实例列表找回；部署中的项目在状态页显示为 approved（可再签，服务端对同一已登记任务会续期或答 409）。

### 8. 页面计划（S121 §1.2 自检）

- 资料页：focus，步进点 + 表单，唯一大数字在模板卡「10 亿」；无 folio（规则 19）；PopScope 一步一退；放弃先确认。
- 我的项目：stream，OKX 行（Logo 36 + 名称 16 / 副行 12 + 右侧状态胶囊）；空态 = launchpad 线稿 + 标题 + 一个主按钮。
- 项目状态：stream，五段里程碑条是记忆点；一个下一步主按钮；配置 3 行 + 模板卡。
- 签名部署：focus，地址尾号 Lime 是记忆点；摘要 6 行；所有说明降为一行 11px。
- 部署进度：stream，状态一句（figureLg）+ 时间线；无卡片堆叠。

## 与下单描述的偏离

- 下单写 `POST /v2/launch2/projects` 与 `/launch2/projects/:id`：后端没有前者，项目资料走目录项目 + Hooks 草稿；
  后者因清单禁止 `:` 改为 `/launch2/project?id=`。
- 下单写「服务端 `minSaleLeadSeconds` 决定最早可选」：该值不下发，最早可选取合约下限 4,200 s，以服务端 400 为准。
- 入口选择抽屉不在本批（S136 统一），本批交付受开关控制的入口组件与直达路由。
- 激活后的「用户侧实例页」尚未挂载，暂时进入 MEME Tab。

## Consequences

- 清单 105 → 110：`docs/product/routes-manifest.json`、`route_manifest.dart`、`test/route_manifest_test.dart`、
  `scripts/check_harness.py` 与 `tests/test_check_harness.py` 的条数一起改；与 S136 合并时 `count` / `sha256` 需重算。
- 新增 `launch2CreatorGatewayProvider` 与 `launch2TypedDataSignerProvider` 两个端口，生产默认不可用，只在
  `lib/main.dart` 覆盖；`lib/features/` 内无 Dio、无路由字面量。
- 第一次在 App 内做 EIP-712 签名（不发交易、不花费资产），经共享签名单；Privy 调用在
  `lib/integrations/privy/privy_typed_data_signer.dart`，不改 `PrivyDeviceSigner` 接口。
- 冷启动后看不到部署中的任务，直到后端补「最新任务」读。

## 未决项（需后端 / 主代理决策）

1. 后端没有 `GET …/hooks-deployments`（项目的任务列表 / 最新任务），App 冷启动后看不到部署中的任务；建议 loop-api
   加「最新 job」读或把 `latestDeployment` 放进 `hooks-config` 响应。
2. Hooks 草稿审批状态不可读（只能在提交时被 403 告知）；建议 `hooks-config` 带 `approval: {status, reviewedAt}`。
3. `HOOKS_LAUNCH_MIN_SALE_LEAD_SECONDS` 不下发；建议 `hooks-config`（或 capability evidence）带 `minSaleLeadSeconds`。
4. 「社区绑定」在合同里只有 `links`（≤ 8 条 https），没有绑定 LOOP 社区的字段；本批按四个链接实现。
5. `GET /v2/launch/projects` 返回账号的全部目录项目（含旧 IDO 申请），无法只列 v2；IDO 隐藏后存量很少，暂全列。
6. EIP712Domain 补齐与 Privy 原生签名的一致性需真机 + dev 后端首签验证（签名被 400「签名人不符」即说明需调整）。
7. `LOOP/docs/routes-manifest.json`（主仓镜像）未在本 worktree 内，需主代理同步 110 条；S136 若也加路由，合并时
   `count` / `sha256` / prototypeOrder 需重算一次（本批用 120–124 避开 112+）。
