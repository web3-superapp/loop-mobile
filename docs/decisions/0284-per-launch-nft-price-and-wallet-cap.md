# 0284 · 申请发射时按项目填写勋章 NFT 售价与内盘单地址限额（S359-mobile）

## Status

Accepted · 2026-11-04（S359-mobile）。需求方 2026-11-04 提出、用户同日裁决「按千分之填整数做」；主代理同日补充裁决 NFT 售价上限 1000（回购单笔 = NFT 价，不能超本金 1%）。四仓接口按 S359 任务书 §1（loop-api 0199、contracts 0019、admin 0016）。

## Context

- 售价（100 USD1）与单地址累计上限（5,000,000 枚 = 5‰）以前是模板常量 / 工厂参数，项目方不能改。
- 读侧（实例模板 `perAddressCap` / `nftPriceUsd1`、`nftSale.priceUsd1`、报价 `quota.capMeme`、模板 `buybackOrderUsd1`）早已是服务端按实例给值，App 只格式化；缺的是申请时的写入口与草稿回显。

## Decision

- **字段**：`nftPriceUsd1` 整数 1–1000，默认 100；`walletCapPerMille` 整数 1–1000，默认 5（链上 `maxCumulativeBuy = n × 1e24`）。`Launch2ProjectTerms`（`launch2_creator_models.dart`）持常量与换算。
- **表单**：`launch2-create` 第 3 步「铸造开始时间」下方两个输入（`launch2-create-nftPrice` / `launch2-create-walletCap`），`TextInputType.number` + `digitsOnly`，占位是默认值 100 / 5，只有标签不加说明句（0248）。留空不传；非整数 → `Whole numbers only`，越界 → `Enter a whole number from {from} to {to}`，提交被拦。编辑时从草稿回填。模板卡按表单当前值显示单地址上限与铸造价（留空 = 草稿值，服务端已回显条款时留空 = 默认值），默认路径与改动前完全一致。
- **写**：`PUT …/hooks-config` 的 `config` 里可选 `nftPriceUsd1` / `walletCapPerMille`，只在填了时出现。
- **读（全部可选、缺省回落，`LAUNCH2_PROJECT_TERMS_EMIT` off 时与今天一致）**：
  - 草稿 `config`：`nftPriceUsd1`、`walletCapPerMille`、`maxCumulativeBuyRaw`（null = 缺省；越界 / 小数 / 类型错 = invalid）。`Launch2HooksDraft.projectEconomics` 把它们叠到 `fixedEconomics` 上（cap 优先于工厂 `maxCumulativeBuy`，回购单笔跟价格走），项目页与创建页模板卡都读它。
  - 实例详情：`instance` 根上与 `template` 里都可带三键；`template.nftPriceUsd1` 除原十进制字符串外也接受整数。叠加后 `perAddressCap` / `perAddressCapBps` / `nftPriceUsd1` / `buybackOrderUsd1` 用实例值，规则区、交易面板、NFT 页照旧读模型。
  - 签名请求（按 contracts 0019 定稿逐字对齐）：domain 必须是 `("LOOP Launch Factory", "2", chainId, factory)`；`request` 必带 `nftPrice`（wei）/ `maxCumulativeBuy`（raw）且非 0；`types.LaunchRequest` 必须按序逐字等于 `LaunchRequest(bytes32 configHash,address projectOwner,uint32 configVersion,string name,string ticker,uint64 nftSaleStart,address buybackRecipient,uint64 deadline,bytes32 memeSalt,uint256 nonce,bytes32 templateHash,uint256 nftPrice,uint256 maxCumulativeBuy)`，message 与 request 同值。域版本 "1" / 旧 11 字段请求一律 invalid（服务端同步升级）。App 不自算 digest，只校验结构后原样交给钱包；签名页多两行（NFT 售价 / 单地址上限）。
- 模板卡底部「Fixed by the platform template; can't be changed.」（zh 同）删除：0248 不要说明句，且条款已可按项目填写。
- 文案进 `lib/l10n/fragments/launch2Creator.json`（创建页所在目录的 fragment），`merge.py` 重生成。

## Consequences

- 测试：`test/s359_project_terms_test.dart`（表单规则、空 / 越界 / 合法提交、回填、草稿 / 实例 / 签名三处 codec 的缺键与带键与非法值、模板卡与 NFT 页显示）。
- 服务端开关 off 时编辑一个已存自定义条款的草稿，App 看不到旧值、留空提交会回到默认值——开关须在 App 发版后、项目方开始填写前打开。
- NFT 页价格读 `nftSale.priceUsd1`、回购说明读 `template.buybackOrderUsd1`：loop-api 须把这两个也改成实例值（今天是模板常量）。

0287 补：单个项目接口的三个条款键（`GET /v2/launch/projects/{id}` 的 `project` 对象，见 0287）。
