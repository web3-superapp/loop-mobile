# 0090 · 在 Launch 链槽位上签名：放行矩阵与 Privy 的真实链选择方式

## Status

Accepted 2026-09-25。S83e，客户端单侧，不改 loop-api。修订决策 0062 §8
（「Privy 不能切链，所以设备签名器失败关闭」）与 0089「已知限制」一节；0062 其余
条款（两个具名槽位、`chainIsPermitted`、主链资金动作三层锁）不变。93 条路由清单
不变，没有新增路由，没有新增依赖，`pubspec.lock` 不变。

## Context

S84 已把参考合约部署到 BSC 测试网（`eip155:97`）：LoopLaunchpad
`0x2b26fc1300311476cc3032bcfbcfb6cb1d953396`、MockUSD1
`0x17d554fd27345940e21d1d7328d038bd4049ce2b`。后端 `POST /v2/wallet-intents/approve`
（USD1 → Launch 合约）与 `POST /v2/launch/{id}/intents` 都返回 `chainId = 97` 的
unsigned transaction；S83c2（0089）已把两者标为 `IntentKind.launchApproval` /
`IntentKind.launchPurchase` 并让 `chainIsPermitted` 放行 Launch 槽位。唯一剩下的门是
`privy_device_signer.dart` 的 `privy_chain_switch_unsupported`。

0062 当时的理由是「SDK 没有切链调用，无法证明原生端尊重交易自带的 `chainId`」。
本决策先把 SDK 的真实行为读清楚，再定放行规则。

### SDK 原文（本机 `~/.pub-cache/hosted/pub.dev/privy_flutter-0.10.1` 与其原生依赖）

**Dart 层（privy_flutter 0.10.1）没有任何选链 API。**

`lib/src/modules/embedded_ethereum_wallet_provider/embedded_ethereum_wallet_provider.dart`：

```dart
/// Defines the Ethereum Wallet Provider interface for sending RPC requests.
abstract class EmbeddedEthereumWalletProvider {
  /// Sends an Ethereum JSON-RPC request
  Future<Result<EthereumRpcResponse>> request(EthereumRpcRequest request);
}
```

`real_embedded_ethereum_wallet_provider.dart` 只放行六个方法
（`eth_sign`、`personal_sign`、`secp256k1_sign`、`eth_signTypedData_v4`、
`eth_signTransaction`、`eth_sendTransaction`），其余返回
`Failure(PrivyException("Unsupported method: ${request.method}"))`，然后
`_channelHandler.invokeMethod('ethSendRpcRequest', {...request.toJson(), "walletAddress": walletAddress})`。

`lib/src/models/ethereum_rpc_request/ethereum_rpc_request.dart`：

```dart
class EthereumRpcRequest {
  final String method;
  final List<dynamic> params;
  EthereumRpcRequest({required this.method, required this.params});
  ...
  /// Creates an eth_sendTransaction RPC request
  factory EthereumRpcRequest.ethSendTransaction(String transactionJson) {
    return EthereumRpcRequest(
      method: "eth_sendTransaction",
      params: [transactionJson],
    );
  }
}
```

插件原生端把 `params` 当作**字符串列表**读：

- iOS `ios/privy_flutter/Sources/privy_flutter/channels/WalletHandler.swift`：
  `let params = args["params"] as? [String]`，否则
  `FlutterError(code: ErrorConstants.invalidArgument, message: "Missing or invalid parameters.")`；
  随后 `EthereumRpcRequest(method: method, params: params)` →
  `wallet.provider.request(rpcRequest)`。
- Android `android/src/main/kotlin/io/privy/privyflutter/channel/WalletHandler.kt`：
  `val params = call.argument<List<String>>("params") ?: emptyList()` →
  `EthereumRpcRequest(method, params)` → `wallet.provider.request(rpcRequest)`。

**原生 SDK 有 `switchChain`，但插件没有桥接它。**

- iOS `PrivySDK` 2.12.0（`Pods/PrivySDK/.../arm64-apple-ios.swiftinterface`）：

  ```swift
  public protocol EmbeddedEthereumWalletProvider : Swift.Sendable {
    var chainId: Swift.Int { get async }
    func request(_ request: PrivySDK.EthereumRpcRequest) async throws -> Swift.String
    func switchChain(chainId: Swift.Int, rpcUrl: Swift.String?) async
  }
  public struct EthereumRpcRequest : Swift.Sendable {
    public let method: Swift.String
    public let params: [Swift.String]
    public init(method: Swift.String, params: [Swift.String])
    public static func ethSendTransaction(transaction: PrivySDK.EthereumRpcRequest.UnsignedEthTransaction) throws -> PrivySDK.EthereumRpcRequest
  }
  public struct UnsignedEthTransaction {
    public init(from:to:nonce:gasLimit:gasPrice:data:value:chainId:type:maxFeePerGas:maxPriorityFeePerGas:)
    public typealias EIP2718TransactionType = Swift.Int
  }
  ```

  二进制里有 `WalletApiEthereumSendTransactionRpcParams`、`caip2`、
  `"Chain ID must be a valid CAIP-2 chain ID, e.g. 'eip155:1'"`。

- Android `io.privy:privy-core` 0.12.1（`kmp-embedded-wallet-*` 0.12.1，`javap` 反汇编）：

  ```
  public interface io.privy.wallet.ethereum.EmbeddedEthereumWalletProvider {
    public abstract java.lang.Object request-gIAlu-s(EthereumRpcRequest, Continuation<? super Result<EthereumRpcResponse>>);
    public abstract void switchChain(io.privy.wallet.ethereum.EthereumChain);
  }
  ```

  `RealWalletApiRpcExecutor` 处理 `eth_sendTransaction`：`params[0]` 必须是交易 JSON
  字符串（否则 `"eth_sendTransaction requires the transaction JSON string as its first parameter"`），
  以 `ignoreUnknownKeys` 解码为 `UnsignedEthereumTransaction`
  （字段 `from, to, nonce, gasLimit, gasPrice, data, value, chainId, type: Integer,
  maxFeePerGas, maxPriorityFeePerGas`；`Quantity` 接受整数或 `0x` 十六进制串），链取
  `transaction.chainId ?: walletDetails.chainId`，都没有则
  `"Chain ID is required for eth_sendTransaction"`，然后
  `WalletApiCAIP2.forEip155Chain(chainId)` →
  `WalletApiRpcRequest.EthereumSendTransaction(params, caip2)`，经 Privy wallet API 广播。
  `switchChain` 只改 `EmbeddedWalletManager` 的当前链，供 `performJsonRpc`（非钱包方法）
  使用，**不参与** `eth_sendTransaction`。

**官方文档**（<https://docs.privy.io/wallets/using-wallets/ethereum/send-a-transaction>，
2026-09-25 抓取）Flutter 示例原文：

```dart
final transactionMap = {
    'to': '0xE3070d3e4309afA3bC9a6b057685743CF42da77C',
    'value': '0x186a0', // 100000 in hex
    'chainId': '0x2105', // 8453 (Base) in hex
    'from': ethereumWallet.address
};
// Convert Map to JSON string
final transactionJson = jsonEncode(transactionMap);
final rpcRequest = EthereumRpcRequest(
    method: 'eth_sendTransaction',
    params: [transactionJson],
);
```

参数说明原文：Flutter / Android「The chain ID as a hexadecimal string. Defaults to
mainnet (0x1) if omitted.」；Swift「The chain ID as an integer or hexadecimal string.
Defaults to mainnet (0x1) if omitted.」

### 结论

1. 在 privy_flutter 0.10.1 上**选链的唯一方式是交易自带的 `chainId`**。没有
   `switchChain` 可调，也不需要：两端原生 SDK 都用 `eip155:<transaction.chainId>` 作为
   wallet API 的 `caip2`。于是也**没有「切回主链」这一步**——Flutter 路径上不存在会被
   后续 send/swap 继承的钱包级「当前链」状态。
2. 缺 `chainId` 的交易会被发往以太坊主网（文档：Defaults to mainnet）。所以「交易
   `chainId` 必须等于 Intent 的 `chainId`」这条检查是选链本身的保证，不只是一致性检查。
3. **发现既有缺陷**：改前的签名器把交易 Map 原样放进 `params`
   （`params: <Object?>[transaction]`）。iOS 端 `as? [String]` 失败 →
   `"Missing or invalid parameters."`；Android 端 `List<String>` 取出后按字符串解码失败。
   两者都会被映射为 `wallet_outcome_unknown` 并锁定——**包括主链的 send / approve**。
   主链真机广播从未取证（go-no-go #6），所以此前没有暴露。
4. **发现第二处形状不兼容**：loop-api 的 `UnsignedTransaction` 用 viem 拼写
   （`gas`、`type: "eip1559" | "legacy"`，并对不适用的费用字段给 `null`）；Privy 的
   `UnsignedEthereumTransaction` 读 `gasLimit` 与整数 `type`，并忽略未知键。原样发送时
   `gas` 被静默丢弃，`"eip1559"` 解码失败。

## Decision

### 1 放行矩阵（`privyChainRefusal`）

签名器现在接收 Intent 的 `kind`、`chainId`，以及当前会话 `GET /v2/chain/status`
发布的 `launchChain.chainId`（`launchChainId`；服务端省略 `launchChain` 时为 `null`，
即 Launch 槽位 = 主链）。

| kind \ chain | 主链 `eip155:56` | 已发布的 Launch 槽位（`launchChainId == chainId ≠ 主链`） | Launch 槽位未发布 / 读不到（`launchChainId` 为 `null` 或主链） | 未知链 |
| --- | --- | --- | --- | --- |
| `launchApproval` | 签 | 签 | `privy_chain_switch_unsupported` | `privy_chain_mismatch` |
| `launchPurchase` | 签 | 签 | `privy_chain_switch_unsupported` | `privy_chain_mismatch` |
| `transfer`（send） | 签 | `privy_chain_switch_unsupported` | `privy_chain_switch_unsupported` | `privy_chain_mismatch` |
| `approval` | 签 | `privy_chain_switch_unsupported` | `privy_chain_switch_unsupported` | `privy_chain_mismatch` |
| `swap` | 签 | `privy_chain_switch_unsupported` | `privy_chain_switch_unsupported` | `privy_chain_mismatch` |
| `perpOrder` | 签 | `privy_chain_switch_unsupported` | `privy_chain_switch_unsupported` | `privy_chain_mismatch` |

任一格之前先查：`transaction['chainId'] != loopChainReference(chainId)`（包括缺失、
字符串 `"0x61"`）→ `privy_chain_mismatch`。矩阵在查会话之前执行，所以拒绝不依赖登录
状态。这是在 0062 的三层锁（transport、`MoneyActionSigner`、`allowsWalletHandoff`）
之外的第四层；send / approval / swap 在 Launch 链上的 Intent 在更早的层就已被拒。

### 2 Launch 槽位的来源

`PrivyWalletSigningGateway` 新增可选 `readLaunchChain`（`Future<String?> Function()`），
`walletSigningGatewayProvider` 把它接到 `chainGatewayProvider.loadStatus()` 的
`launchChain?.chainId`。它**只在 Intent 不在主链时**被调用，所以主链的 send / approval /
swap 不多发一次请求、不等待它；读取失败（离线、`unavailable`）一律当作「未发布」，签名器
随即 `privy_chain_switch_unsupported`，钱包不会被打开。不缓存、不从 launch 记录或
capability 推断。

### 3 选链与「切回」

按 SDK 的真实方式：不调用任何切链方法，`eth_sendTransaction` 的唯一参数是交易 JSON
字符串，其 `chainId` 即广播链。因为 Flutter 路径不存在可变的「当前链」，所以没有
`finally` 切回，也**不引入** `privy_chain_switch_failed`：一个永远不会发生的切链步骤，
其失败码只会是死代码。若将来升级到桥接了 `switchChain` 的 SDK 版本，需要新决策重新
评估（那时 `finally` 切回与 `privy_chain_switch_failed` 才有意义）。

### 4 交给 SDK 的拼写（`privyTransactionJson`）

只改三处拼写，不改任何值，不增删字段：

- `gas` → `gasLimit`（同一个量）；`gas` 与 `gasLimit` 同时出现 → 拒绝；
- `type`：`eip1559` → `2`，`legacy` → `0`；其它值 → 拒绝；
- 值为 `null` 的键省略（JSON-RPC 语义相同）。

然后 `jsonEncode`，作为 `EthereumRpcRequest(method: 'eth_sendTransaction',
params: <String>[json])` 的唯一参数——与 SDK 自带的
`EthereumRpcRequest.ethSendTransaction(String)` 形状一致。拒绝码
`privy_payload_unencodable` 在打开钱包之前抛出，UI 走「没有提交任何交易」的兜底文案。
签名单展示的 review 与 `payloadDigest` 仍绑定服务端原对象；这里是同一对象的另一种拼写，
不是客户端构造的交易。

### 5 失败归类不变

钱包打开之后的任何失败（包括 Privy 对 `eip155:97` 返回「不支持的链」之类的错误）仍按
0059：只有能识别为用户拒绝的消息是 `privy_broadcast_rejected`，其余一律
`wallet_outcome_unknown` 并锁定。无法从消息区分「未广播」与「已广播」，所以不为 Launch
链开例外。

## 主链资金动作不受影响的证明（测试名）

- `test/s83e_sign_on_launch_chain_test.dart`
  - `the admission matrix (kind x chain) every kind signs on the primary chain, published slot or not`
  - `the admission matrix (kind x chain) send, approval, swap and perp are refused on the Launch slot`
  - `the signing exit reads the Launch slot a primary-chain send never waits on chain/status`
  - `the SDK call itself the chain is the payload's own, so nothing carries over: a purchase on 97 then a send on 56 each reach the SDK with their own chainId`
- `test/s9_dual_chain_test.dart`
  - `signing · only a Launch intent may leave the primary chain a money intent on the testnet never reaches a wallet`
  - `… a swap and an approval are locked to the primary chain too`
  - `… the primary chain still reaches the wallet with its chain`
  - `… a payload that disagrees with the intent chain is refused`
- `test/privy_adapter_test.dart`（整组，签名改动后仍全部通过）

Harness：`check_s9_dual_chain_contract` 的签名器守卫保留
`privy_chain_switch_unsupported` / `privy_chain_mismatch`，并新增
`String? privyChainRefusal(`、Launch kind 判定与 `launchChainId != null && launchChainId == chainId`
三个标记；`tests/test_check_harness.py::test_s9_device_signer_admits_only_the_published_launch_slot`
证明去掉「已发布槽位」条件会失败。

## Consequences

- 真机上 Launch 的授权与购买第一次有可能真正广播；主链 send / approve 也因为第 3、4
  条修正第一次有可能真正广播。二者都**尚无真机证据**，go-no-go #6 仍是待办。
- Privy 能否在 `eip155:97` 上广播取决于 Privy wallet API 是否支持该 `caip2`。
  官方文档的链支持页没有明确列出 BSC / BSC 测试网，也没有记载需要在 Dashboard 为
  嵌入式钱包开启某条 EVM 链的开关；这一点只能由真机取证回答。
- 0062 §8 的「非主链一律拒签」被本决策的矩阵取代；0089 的「已知限制」一节随之失效。

## Alternatives rejected

- **先 `switchChain(97)` 再发送、`finally` 切回。** privy_flutter 0.10.1 没有桥接
  `switchChain`；要做只能自写原生 MethodChannel 访问插件内部的 Privy 单例，而且 Android
  反汇编表明它根本不影响 `eth_sendTransaction`。为不存在的状态写切回逻辑没有意义。
- **把交易 `chainId` 改写为十六进制串。** Android 的 `Quantity` 同时接受整数与十六进制，
  Swift 文档写明接受整数；整数是服务端原值，保持不动。
- **要求 loop-api 改用 Privy 拼写。** 可行，但会让同一份 `unsignedTransaction` 在 viem 与
  Privy 两种拼写之间摇摆，并影响已冻结的 S83b 契约；客户端在 SDK 边界做无损拼写转换，
  范围更小。若主代理倾向后端改，本决策第 4 条可整体撤回。

## Main-agent rulings (2026-09-25)

1. **No switch-chain step, no `privy_chain_switch_failed`.** Accepted: the Flutter plugin bridges only `request`, and both native SDKs select the chain from the transaction's own `chainId`. The "chainId must equal the Intent's chainId" check is therefore the chain selection guarantee.
2. **§4 transaction encoding stays on the client** (`gas` → `gasLimit`, `type` `eip1559`/`legacy` → `2`/`0`, JSON string parameter). The backend keeps publishing the loop-api shape; this is a Provider adapter concern. First device evidence for a mainnet canary send is now owed (go/no-go #6).
3. Privy Dashboard: nothing to change until a device run says otherwise.
