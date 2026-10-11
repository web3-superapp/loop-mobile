# 0144 · MEME v2 接 2026-10-10 需求方答复：审核拒绝、收币地址固定、零持有人直接公开（S145-mobile）

## Status

Accepted 2026-10-11。主代理下单（S145-mobile），基线 `integration/v2` 04cf716（已含 0142、0143），分支 `feat/S145-mobile`。
依据：loop-api 决策 0122（S145-api，已合入 loop-api `integration/v2`，当前 1b2b426，dev 已在 37c7321 之上）、
`docs/frontend-v2-hooks-launch-api.md` §11 / §12、`docs/frontend-v2-launch-api.md` §3.3 / §3.6 / §3.7、
`docs/frontend-v2-launch2-api.md` §2 / §3.2 / §3.6、`openapi/loop-api.v2.json`；`LOOP/docs/17` §四答复 7 / 9 / 10。
不新增依赖、`pubspec.lock` 不变、路由清单不变、视觉 token 不变。

## Context

0122 在服务端做了三件事：审核人可以拒绝（五类理由 + 审核意见），被拒的目录项目与被拒的发射配置都可以改后重提；回购收币地址
由平台固定（`hooks-config` 下发 `fixedBuybackRecipient`，别的地址一律 `422 HOOKS_BUYBACK_RECIPIENT_FIXED`）；第三版工厂实例
NFT 零认购时不再关闭，由发布器直接开公开内盘（`snapshot.status = opened_without_holders`），`closed_no_holders` 只留给旧工厂实例。
同时回购账本的三个价格保护字段可为 `null`，`nextOrderBlockedReason` 重定义。

另外，0121（S143）给回购摘要加的 `buyback.keeper`「schema 可选、总是返回」，本仓的严格 codec 没跟上：dev 自 2026-10-11 00:10
起每个 v2 项目详情都带这个键，04cf716 的包会把详情判成 invalid。本批一并补上。

## Decision

### 1. 审核拒绝（答复 7）

- 模型：`LaunchRejectionReason`（`incomplete_materials` 材料不完整 / `name_or_ticker_conflict` 名称或代码与已有项目冲突 /
  `buyback_recipient_invalid` 回购收币地址不符合要求 / `community_binding_mismatch` 绑定的社区与项目不一致 / `other` 其他原因）与
  `LaunchRejection {reason, note, at}`，放在 `features/launch`，目录项目与发射配置共用。五个码是封闭集合，中文由客户端给；
  `note` 是审核员原话，原样展示。
- 目录项目 codec：`project.rejection` 作为可选键读（老服务端省略 = 无）；`reasonCode` 枚举外、`other` 无 `note`、`note` 为空白
  或超 500 字、多键、非 `rejected` 状态带 `rejection` 都判 invalid。`LaunchReviewStatus.isEditable` 加上 `rejected`（服务端
  `draft | returned | rejected → submitted`）；经典申请页 `rejected` 的提示改为「未通过，可以按审核意见修改后重新提交。」，按钮
  「重新提交」。
- `hooks-config.approval`：`status` 增 `rejected`，`rejection` 作为可选键读；`rejected` 与 `rejection` 必须同时出现。
- 状态投影（`launch2CreatorStatusOf`，在 0142 表中 `approved` 之后插一行）：`approval.status = rejected` → `rejected`。
  目录 `returned / rejected` 仍先于 Hooks 审批判断。`Launch2CreatorProject.rejection`：目录 `rejected` 时取目录的；目录 `returned`
  无（只有 `reviewReasonText` 一句）；否则取发射配置的。
- 项目状态页 `rejected`：有 `rejection` → 警示条「审核未通过：<理由>」+「审核意见：<原话>」+「<时间> 项目资料 / 发射配置未通过审核，
  修改后可以重新提交。」；没有（旧脚本拒绝、退回）→ 原来的 `reviewReasonText` 一句。唯一动作「修改后重新提交」→ 编辑页。
  0142 的「重新发起」按钮删除（被拒项目现在可以原地改）。
- 编辑页沿用 0142 的三步写入：目录 `rejected` 时 PUT 资料 + 写配置 + 提交审核；目录已批准、只有配置被拒时只写一版新配置
  （`expectedVersion` = 被拒版本，服务端置为 `awaiting_approval`），不 PUT、不 submit。
- 我的项目：被拒行副标题「审核未通过：<理由>」，胶囊仍是「未通过」（红）。

### 2. 收币地址只读（答复 9）

- `hooks-config` 读 `buybackRecipientFixed`（只能是 `true`）与 `fixedBuybackRecipient`（小写地址或 `null`），两者可选键
  （老服务端省略 = 不知道固定地址）。
- 创建 / 编辑表单第三步：收币地址输入框删除，改为只读块 `Launch2FixedRecipient`（地址 + 「平台固定」徽标 + 「回购买到的代币转入
  这个地址。地址由平台固定，不能修改。」）。显示值：保存流程或编辑项目读到的服务端地址；新建项目还没有 `hooks-config` 可读时显示
  需求方给的 `0x28816c4C…9307`。`Launch2Field.recipient` 与本地地址校验删除。
- 保存：写草稿前那次 `hooks-config` 读（0142 已有）同时拿 `fixedBuybackRecipient`，草稿的 `buybackRecipient` **一律用它**，不用
  页面上显示的值；为 `null` 时不写草稿，页内「平台回购收币地址暂未配置，暂时不能保存或签名，稍后再试。」。
- 422：`PUT hooks-config`、`GET signing-request`、`POST hooks-deployments` 的允许错误表加 `422 VALIDATION_FAILED`；
  `HOOKS_BUYBACK_RECIPIENT_FIXED` 文案「回购收币地址必须是平台固定地址。这一版配置用的是其他地址，请修改资料重新保存一版（需要
  重新审核）。」；签名页遇到它时把「重试」换成「修改资料」（跳编辑页）。
- 已批准但收币地址不是固定地址的旧版本（主代理裁决 ②：作废）：`Launch2HooksConfig.recipientOutdated`。续走落到项目状态页而不是
  签名页；状态页显示「回购收币地址需要更新」+ 说明 +「修改资料」；我的项目副标题同句。

### 3. 零持有人直接公开（答复 10）

- `snapshot.status` 增 `opened_without_holders`；`snapshot.openedWithoutHolders {openedAt, blockNumber, transactionHash}` 作为
  可选键读（老服务端省略 = 无）。一致性：状态与记录必须同时出现；有记录时 `root / publication / closure` 必须为空；有记录的阶段只能是
  `public / graduated / paused`。
- 项目页 `public` 阶段有记录时，曲线块上方一条信息条「无 NFT 持有人，已直接开放公开内盘，没有提前购，人人可买可卖。」；交易面板照常
  （`public` 不需要 proof，`viewer.eligibleNow = true`）。
- `closed_no_holders` 保留（OpenAPI 阶段枚举仍有，旧工厂实例），模型注释标「deprecated，旧工厂」；灰态说明改为「NFT 发售结束时没有人
  认购。这个项目使用旧版合约，名单无法生成，提前购和公开内盘不会开始。」。阶段条、列表胶囊、列表沉底规则不变。
  八个阶段（`upcoming / nft_sale / snapshot_pending / closed_no_holders / priority / public / graduated / paused`）的名称与说明都有，
  测试逐个断言。

### 4. 回购字段（0122 / 0121 跟进）

- 账本 `minMemeOut / referencePriceUsd1 / spotPriceUsd1` 改为可空，三者必须同为空（v3）或同有值（v2）。页面本来不展示它们。
- `nextOrderBlockedReason` 中文按新集合：`BUYBACK_TOO_SOON` 距上一笔不到 10 秒，稍后执行 / `BUYBACK_PRINCIPAL_INSUFFICIENT`
  官方池本金保护：本金不足 10,000 USD1 或单笔超过 1% / `BUYBACK_QUOTE_UNAVAILABLE` 合约报价暂时读不到，暂不执行 /
  `BUYBACK_LEGACY_PRICE_PROTECTION` 旧版合约价格保护生效，暂不执行；`BUYBACK_PROTECTION_BLOCKED`、
  `BUYBACK_PRICE_SOURCE_UNAVAILABLE` 删除（落到「暂不执行」）。
- 回购说明抽屉「价格保护生效时不执行」改为「官方池 USD1 本金不足 10,000 或单笔超过本金 1% 时不执行」。
- `buyback.keeper`（0121）作为可选键读进 `Launch2BuybackSummary.keeper`（`lastResult` 五值枚举外 invalid）；本批只解析不展示。

### 5. 社区绑定（任务 4）

OpenAPI 的 `/v2/launch/projects*` 与 `/v2/launch2/**` 没有项目的 `communityId`（loop-api 0122 Open 3，主代理裁决留 S148），本批不做。

## Fixtures

`test/fixtures/s135-launch2-creator/`：5 份 `hooks_config_*` 补 `buybackRecipientFixed / fixedBuybackRecipient / approval.rejection`；
新增 `hooks_config_rejected.json`、`hooks_config_recipient_outdated.json`、`error_recipient_fixed.json`（422）、
`error_recipient_unavailable.json`（503）。全部手写（`_handwritten` 注明来源），dev 上还没有真实拒绝可抓。
`test/support/launch2_fixtures.dart`：`openedWithoutHolders`、`keeper`、v3 回购（`legacy: false`），默认阻塞原因改为
`BUYBACK_PRINCIPAL_INSUFFICIENT`；`s7Project` 加 `rejection`。

## Consequences

- 新键全部按「schema 可选」读，老服务端（dev 37c7321 之前）不受影响；新服务端（已上 dev）的 `keeper` 不再让详情判 invalid。
- `isEditable` 改动同时作用于经典 Launch 申请页（服务端规则对两类项目相同）。
- 新建项目时表单显示的收币地址是常量，保存用服务端值；两者不同时以服务端为准，项目状态页显示已保存的地址。

## 未决项（需后端 / 主代理决策）

1. 项目社区绑定字段缺失（`communityId`），`community_binding_mismatch` 理由目前只能靠审核意见说明——S148。
2. `buyback.keeper` 要不要在回购面板展示（合同 §3.2 给了「回购暂缓：<原因>」一类的文案）——本批未做，待主代理定。
3. 新建项目在创建目录项目之前读不到 `fixedBuybackRecipient`（`hooks-config` 需要项目 id）；若希望新建页也显示服务端地址，
   需要后端在能力或模板接口下发它。
4. 本批 fixture 均为手写，dev 有真实拒绝 / 零持有人开盘后需重抓。
