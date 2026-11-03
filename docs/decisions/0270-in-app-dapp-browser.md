# 0270 · 内置 DApp 浏览器：WebView、EIP-1193 / EIP-6963 注入、连接确认、dApp 签名确认页、能力降级

## Status

Accepted · 2026-11-03（S342-mobile）。合同见 `LOOP/docs/55-内置DApp浏览器-2026-11-03.md` §一、§三；§二由 S342-api 并行实现，App 按合同编码、fixture 测试（真机 / staging 联调未做）。

## Context

用户 2026-11-03：以钱包页「DApp 网址核对」为入口做内置 DApp 浏览器。Privy Flutter SDK 不带浏览器，只有 `EmbeddedEthereumWalletProvider.request`，浏览器与注入层需自建。docs/00 规则 3（统一签名出口）与规则 8（BSC Mainnet 签名与广播关闭）不变。

## Decision

### 依赖

- `flutter_inappwebview: 6.1.5`（pub.dev 最新稳定版；锁定传递依赖 `flutter_inappwebview_android 1.1.3`、`_ios 1.1.2`、`_platform_interface 1.3.0+1` 等）。iOS `Podfile.lock` 新增 `flutter_inappwebview_ios (0.0.1)` 与 `OrderedSet (6.0.3)`。Android manifest、iOS Info.plist 无需改动：只开 `https`（ATS 默认即可），`INTERNET` 与 `https` VIEW 查询已在。`flutter build apk --debug`、`flutter build ios --simulator --debug --no-codesign` 均通过。
- WebView 加固：主框架只放行 `https` 且本地 `LoopUrlReview` 不阻止的地址（`http` toast「只能打开 HTTPS 网址」）；子框架只放行 `https / about / data / blob`；不开新窗口、无文件 / content 访问、mixed content 禁止、Safe Browsing 与欺诈站点提示开、页面申请的相机 / 麦克风 / 定位一律拒绝。

### 路由与入口

- `/wallet/dapp`（`dapp`）：`dappBrowser` 能力 available 且本构建有 WebView 时为浏览器首页（地址栏 + 收藏 + 最近访问 20 条，本地一个 SharedPreferences 键 `loop.dapp.v1.browser`），否则保持原「DApp 网址核对」页；钱包页同一行按能力显示「DApp 浏览器」/「DApp 网址核对」。
- 新路由 `dapp-web` → `/wallet/dapp/web`（清单 117 → 118，prototypeOrder 131）：只接 `extra: DappOpenRequest`，否则回 `/wallet/dapp`。地址被本地核对标记（非阻止）时，首页先弹发现再「仍要打开」；直接打开未确认的标记地址时页面内先展示发现。
- 能力 `dappBrowser`（camelCase，可省略，缺省读 unavailable，原因码 `DAPP_BROWSER_CAPABILITY_ABSENT`），能力 id 36 → 37。

### 注入与桥

- document-start、仅顶层框架注入 EIP-1193 `window.ethereum`（`isLoop: true`、`isMetaMask: false`、`request / on / removeListener / enable / send / sendAsync`），EIP-6963 announce（name `LOOP`、rdns `cc.quant-dinger.loop`、icon = Android mdpi 启动图标 PNG data URI），事件 `accountsChanged / chainChanged / connect / disconnect`。
- 页面 → App：`callHandler('loopEthereum', nonce, origin, isTopFrame, requestJson)`；App 只接受本页随机 nonce、顶层框架、且声明 origin 等于 WebView 报告的顶层 URL origin 的请求，否则 4100。App → 页面：`window["__loopEmit_" + nonce](event, json)`。

### 方法

- `eth_chainId / net_version / eth_accounts`（未连接 `[]`）本地答；`eth_requestAccounts` 弹连接确认（站点、图标、地址），按 origin 本地记住，菜单可断开（发 `accountsChanged []` + `disconnect`）；`wallet_switchEthereumChain` 只 56 / 97，其他 4902；`wallet_addEthereumChain`（S342 联调补）对 0x38 / 0x61 按切换处理，其他 4902。
- 读方法（`eth_blockNumber / eth_call / eth_getBalance / eth_getCode / eth_getTransactionReceipt / eth_getTransactionByHash / eth_estimateGas / eth_gasPrice / eth_getLogs`）走一个可替换接口 `DappRpcReader`，生产默认 `POST /v2/chain/rpc-read`。
- `eth_sendTransaction` → `POST /v2/wallet-intents/dapp-tx`；`personal_sign / eth_signTypedData_v4` → `POST /v2/wallet-intents/dapp-sign`；主网签名类本地先拒 4100 + toast「暂不支持在这个网络签名」（服务端 422 `CHAIN_SIGNING_DISABLED` 同样处理）；`eth_sign / eth_signTransaction` 与未知方法 4200。
- 确认页：站点 origin + 图标、解码内容（交易：方法、目标合约、数量、参数；消息：文本或 typedData 树）、风险条（仅在 `riskFlags` 非空时出现）。签名前核对服务端 intent 与页面请求同一笔（目标、data、value、from、链；消息 method 与 payload，typedData 按 JSON 语义比较），不一致拒签。签名经 `loopGuardedWalletSigningGatewayProvider` → Privy（交易 `eth_sendTransaction`；消息新增 `MessageSignaturePayload` + `PrivyMessageSigner`），之后 `broadcast-report` / `signature-report` 回报；hash / 签名不论回报成败都交回页面。拒绝 → 4001 并 cancel intent。签名类请求在页面内串行排队（服务端每钱包只留一个 open intent，新 prepare 顶替旧的且交易 nonce 相同），第二个请求等第一个签完 / 拒绝 / 被拒后才 prepare。
- `IntentKind.dappTransaction / dappMessage` 只在 Launch 槽可签，`SigningIntent.chainIsPermitted` 在主网对它们恒为 false。
- intent 列表 `includeKinds=send_nft,dapp_tx,dapp_sign`；两种 DApp 行由 `LoopV2DappCodec` 宽松读入 `LoopWalletIntentPage.dappIntents`，读不了的行跳过，不让整页失败。

## Consequences

- 与 S342-api 的线上形状未对齐前，codec 按含义读（已知键校验、未知键忽略），签名所依赖的字段严格。联调后若键名不同只需改 `LoopV2DappCodec`。
- dApp 交易成功后不进 `/wallet/tx/result`（该页解码 `LoopWalletIntent`），回执由 intent 生命周期在服务端对账。
- 测试网链名在浏览器里固定显示「BSC 测试网 / BSC 主网」，不随测试提示开关隐藏，因为这里要让用户在两条链之间选择。
