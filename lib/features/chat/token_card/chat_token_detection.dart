import 'package:loop_mobile/core/chain/loop_chain_ids.dart';

/// How many contract addresses one message may open a card for.
///
/// A message that pastes a list of contracts is still a message, not a market
/// page: past the third card the bubble would be taller than the screen and
/// the reader would lose what was actually said. The remaining addresses stay
/// in the text, where they were written.
const int loopChatTokenCardsPerMessage = 3;

/// A BSC contract address written inside a chat message.
///
/// Only a full 20-byte address is detected. A `$TICKER` is deliberately not:
/// two contracts may share a ticker, so a card opened from one would show the
/// facts of an asset the writer never named. The address is the identity, and
/// nothing else is.
///
/// The boundaries matter as much as the body. Without them the first 40 hex
/// characters of a 32-byte transaction hash would read as an address, and the
/// card would carry another asset's facts under a hash the writer pasted.
final RegExp loopChatTokenAddressPattern = RegExp(
  r'(?<![0-9A-Za-z])0x[0-9a-fA-F]{40}(?![0-9a-fA-F])',
);

/// The addresses [text] names, lower-cased, in the order they were written.
///
/// Repeats collapse: a message that names the same contract twice opens one
/// card. Detection reads the message; it never rewrites it, so the address the
/// writer typed — checksum capitals and all — stays in the bubble above.
List<String> loopDetectChatTokenAddresses(String text) {
  final seen = <String>{};
  final addresses = <String>[];
  for (final match in loopChatTokenAddressPattern.allMatches(text)) {
    final address = match.group(0)!.toLowerCase();
    if (!seen.add(address)) continue;
    addresses.add(address);
    if (addresses.length == loopChatTokenCardsPerMessage) break;
  }
  return List<String>.unmodifiable(addresses);
}

/// The canonical asset id one detected [address] resolves against.
///
/// Chat reads the primary chain and only the primary chain: the Launch slot's
/// testnet is reached from the Launch module, never from a pasted address.
String loopChatTokenAssetId(String address) =>
    '$loopPrimaryChainId:${address.toLowerCase()}';

/// `0x6982…1933` — the address as a card prints it.
String loopChatTokenShortAddress(String address) =>
    '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
