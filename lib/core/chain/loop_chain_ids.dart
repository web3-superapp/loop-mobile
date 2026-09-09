/// The chain identities the client accepts, and nothing else.
///
/// LOOP has exactly two named chain slots (loop-api decision 0038): the
/// `primary` slot, which every wallet, registry, market, Swap, Send, approval,
/// indexer and watchlist fact is bound to, and the `launch` slot, which the
/// Launch module alone may point at while the Launch contract lives on the BSC
/// testnet. There is no chain list and no generic multi-chain support, so an
/// unknown chain id is an invalid payload rather than a network the client
/// silently adopts.
library;

/// The primary chain slot. It never moves.
const String loopPrimaryChainId = 'eip155:56';

/// The only other chain the backend may publish: the Launch slot's testnet.
const String loopLaunchTestnetChainId = 'eip155:97';

/// The closed set of chain ids a V2 payload may carry.
const Set<String> loopKnownChainIds = <String>{
  loopPrimaryChainId,
  loopLaunchTestnetChainId,
};

/// zh-CN network name for one published chain id. It is only ever called with
/// a value a strict parser already accepted.
String loopChainName(String chainId) => switch (chainId) {
  loopLaunchTestnetChainId => 'BSC 测试网',
  _ => 'BNB Smart Chain',
};

/// True when the value is the Launch testnet slot. This is the single
/// condition for the "BSC 测试网" badge and its one-time explanation, and it
/// never closes a surface.
bool loopIsTestnetChainId(String chainId) =>
    chainId == loopLaunchTestnetChainId;

/// The numeric EIP-155 reference of one known chain id, e.g. `56`. It is the
/// value an `eth_sendTransaction` payload carries, so the two can be compared
/// without either side parsing a string at a call site.
int loopChainReference(String chainId) => switch (chainId) {
  loopLaunchTestnetChainId => 97,
  _ => 56,
};
