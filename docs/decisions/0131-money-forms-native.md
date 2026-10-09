# 0131 · 资金表单原生化：发送 / 兑换 / 买卖面板 / 工具页去 hero（S123e）

## Status

Accepted 2026-10-09。主代理下单（S123e，审查 `docs/integration/review-2026-10-09/s123-interaction-audit.md`
的 M8、M9、M10、M16、m18 与 §五 规则 6、16、19；截图 `docs/evidence/2026-10-09-s123/` 51、52、59、60、70b、73b）。
基线 `integration/v2` bd52fd1。不新增依赖、`pubspec.lock` 不变、路由清单不变（slug 与 path 均未动）。
资金语义不变：收款地址仍只由服务端 preflight 认定，金额仍是用户输入的精确十进制字符串（`TransferAmount`，`Decimal`），
意图仍由服务端准备，签名仍只经共享签名弹层（`showMoneySignSheet` / `showMemeSignSheet`）。

## Context

真机走查把发送、兑换、买卖面板读成「网页表单」：发送 STEP 1 是整屏说明卡 + 全部资产（含 0 余额）；STEP 2 地址与金额同屏，
没有扫码、要点「校验地址」、没有「全部」；兑换要点「获取报价」、没有互换、资产抽屉无搜索无余额且用 chevron；
MEME 买卖面板报价出来后「确认买入」被键盘挡住一半——`showLoopSheet` 已经包了一层 `LoopSheet`，面板自己又返回一层，
两层都让出键盘高度，于是底部多出一整块键盘高的空白；代币页的周期选择正好落在底部买卖栏下面。
发送、兑换、消息搜索、自选管理、提醒页的首屏 20–25% 是 `LoopFolioPrimary` 说明卡。

## Decision

### 发送（`send` / `send-to` / `send-confirm`）

- 三步：1 收款地址 → 2 金额与资产 → 3 确认并签名，进度点复用 `LoopStepDots`（total 3）。1、2 两步是同一个
  `SendFlowScreen` 的两种状态（`_step` + `PopScope`：第 2 步系统返回回到第 1 步）；`send` 与 `send-to` 两条路由都进它，
  `SendAssetScreen` / `SendRecipientScreen` 保留类名作为入口（路由表不动）。`send-to` 带来的 draft 只预选资产，
  其中的地址同样只是预填、重新校验。
- 地址框：`autocorrect` / `enableSuggestions` 关，尾部两个 44 图标「粘贴」「扫码」。粘贴、扫码回填、失焦、键盘完成、
  以及输入满 42 位后静止 400 ms，都会自动请求 preflight；同一地址只问一次，旧请求的回答被丢弃。校验结果
  （`_RecipientChecks` 折叠行、合约地址强制展开、离线 / 拒绝 / 错误三种状态）照旧。没有「校验地址」按钮。
  格式不对的地址在离开输入框后才提示一行 11px。下一步上方一行说明还缺什么。
- 扫码：第 1 步 `push('/scan', extra: SendScanForRecipient())`，`ScanScreen` 在这种 extra（或 `returnsRecipient: true`）下
  识别到钱包地址时 `pop(address)` 把地址交回；非地址的码当文本显示，不打开任何页面。钱包页 / 我页的扫码行为不变
  （地址仍 `pushReplacement('/wallet/send', SendRecipientPrefill)`，此时地址进第 1 步并自动校验）。
  go_router 的 `pushReplacement` 不会完成被替换路由的 Future，所以没有沿用「替换」做回填。
- 第 2 步：已校验地址一行（点按回第 1 步）、资产选择行（只有一个可动用资产时自动选中）、金额框（decimal 键盘 +
  `[0-9.]` 过滤）尾部「全部」= 该资产 `spendableBalance`（服务端已扣 gas 保留，客户端不自算）。资产抽屉见下。
- 第 3 步：去掉 folio，其余（服务端意图、倒计时、待处理意图、签名出口）不变。

### 共享资产抽屉 `showMoneyAssetPicker`（`lib/features/wallet/money_asset_picker.dart`）

- 顶部搜索（代号 / 名称），每行显示可动用余额与总额，已选行用勾（`LoopRecordRow.selected`，`chevron: false`）。
- `requireBalance`（发送、兑换支付侧）：可动用为 0 的资产折叠到「余额为 0 的资产 · N 个」且不可选；链上读不到的行
  照旧显示「读不到」且不可选（不隐藏、不显示 0）。兑换获得侧列出全部资产。

### 兑换（`swap` / `swap-route`）

- 数量、资产、滑点任一变化后 400 ms 自动报价（MEME 面板同一做法），只保留最新一次请求的回答；没有「获取报价」按钮，
  报价前主按钮是状态说明（不可点），报价失败时变「重新报价」。
- 支付与获得之间一个 44 互换键（`swap-vert`），互换后数量仍是支付数量并重新报价；在一侧选了另一侧的资产即互换。
- 两页都去掉 folio。

### 买卖面板与双层抽屉（M16）

- `MemeTradePanel` 不再返回 `LoopSheet`；标题改用新共用件 `LoopSheetHeading`（`lib/widgets/loop_sheet_heading.dart`）。
  报价到达后 `Scrollable.ensureVisible(keepVisibleAtEnd)` 把「确认买入 / 卖出」滚到键盘上方。数量与自定义滑点框加 `[0-9.]` 过滤。
- 同样去掉内层 `LoopSheet`：MEME 分享、交易详情、钱包「添加钱包」与「移除钱包」确认、提醒编辑 / 资产选择 / 删除确认、
  自选新建分组 / 移除确认。原来用裸 `showModalBottomSheet` + 透明底 + `LoopSheet` 的 5 处改为 `showLoopSheet`
  （同一外观，补上焦点归还、减弱动效与键盘让位）。

### MEME 代币页周期选择（m18）

- 页面底部本来已按买卖栏实测高度留白；被盖住的是首屏：周期条在图表下方，恰好落在固定栏的位置。周期条移到图表上方
  （「曲线成交 / K线」行与图表之间）。这是相对原型的布局偏离，单独标出。

### 工具页去 hero（M8）

- 发送、兑换、消息搜索、自选管理、提醒不再有 `LoopFolioPrimary`。必要的一句降为顶栏 11px 副标题：搜索「范围 · N 条」、
  自选「N 个自选资产 · 未保存」、提醒「N 个提醒正在监听 · 触发一次即停」。资讯型页面不在本单范围。

### Harness（`check_money_forms_native_contract`）

- 规则 6：`lib/features/**` 中带 `numberWithOptions` 的输入框必须有 `inputFormatters`；key 含 amount / quantity / first-buy 的输入框
  必须 `numberWithOptions(decimal: true)` + `inputFormatters`；key 含 address / recipient / spender 的输入框必须关 autocorrect 与
  suggestions。为此 `launch-trade-amount`、`meme-create-first-buy` 补了过滤器。
- 规则 16：`lib/widgets/loop_sheet.dart` 以外不得构造 `LoopSheet`。
- 规则 19：发送 / 兑换 / 资产抽屉 / 消息搜索 / 自选管理 / 提醒 / MEME 创建页不得出现 `LoopFolioPrimary`。

## Consequences

- 发送少了一个「选资产」整页；从资产页进入的发送仍预选该资产。
- 自动校验与自动报价会比以前多发请求：校验按地址去重，报价有 400 ms 防抖且丢弃过期回答。
- 未在模拟器 / 真机验证（本单按要求只跑 widget 测试与 `build apk --profile`）：键盘上方的确认按钮、扫码回填、
  粘贴读剪贴板权限提示、周期条位置需主代理在模拟器上核对。
