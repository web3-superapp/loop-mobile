import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' show Message;

/// The schema tag the backend's `community_member_buy_feed` lane writes on
/// every member-buy message (S108 §1.2, loop-api decision 0097).
const String loopMemberBuySchema = 'member_buy.v1';

/// The Stream custom field that carries [loopMemberBuySchema].
const String loopMemberBuySchemaField = 'loop_schema';

/// The Stream user the backend sends community feed messages as.
const String loopFeedBotUserId = 'loop_feed_bot';

/// The custom field the backend sets to `true` on that Stream user.
const String loopFeedBotFlagField = 'loop_bot';

/// The custom field that carries the bought token's symbol.
const String loopMemberBuySymbolField = 'symbol';

/// What a buyer reads as when LOOP could not name them.
const String loopMemberBuyNeutralBuyer = '群友';

/// The one character the neutral buyer avatar draws.
const String loopMemberBuyNeutralInitial = '群';

/// The preview line when the message carries no usable symbol.
const String loopMemberBuyPreviewLabel = '群友买入';

/// Every quote asset on BSC LOOP classifies swaps against (WBNB, USDT, USDC,
/// USD1) is an 18-decimal token. The v1 payload carries no quote decimals, so
/// this is the scale unless a later payload states its own `quoteDecimals`.
const int loopMemberBuyDefaultQuoteDecimals = 18;

/// Whether [message] is a member-buy feed message, however well formed.
///
/// Two facts decide it: the schema tag, and that LOOP's feed bot sent it —
/// the Stream user `loop_feed_bot` carrying `loop_bot: true`. Any member can
/// put custom fields on their own message, so a tag from anybody else is just
/// a message: it renders as an ordinary bubble with its text untouched. A bot
/// message that claims the schema and then fails validation renders the
/// incomplete card, never a bubble that prints the fallback text as if a
/// member had typed it.
bool loopIsMemberBuyMessage(Message message) {
  final user = message.user;
  return message.extraData[loopMemberBuySchemaField] == loopMemberBuySchema &&
      user != null &&
      user.id == loopFeedBotUserId &&
      user.extraData[loopFeedBotFlagField] == true;
}

final RegExp _symbolCharacters = RegExp(
  r'^[\p{L}\p{N}\p{M}$._-]+$',
  unicode: true,
);
final RegExp _combiningMark = RegExp(r'^\p{M}$', unicode: true);

/// The longest symbol, in user-perceived characters.
const int loopMemberBuySymbolMaxLength = 20;

/// Whether [symbol] is a token symbol a card may print.
///
/// Letters and digits of any script (`PEPE`, `狗狗币`, `ПЕПЕ`), their
/// combining marks, and `$ . _ -`; at most [loopMemberBuySymbolMaxLength]
/// characters. Everything else — whitespace, control characters, bidi
/// overrides and isolates, zero-width joiners — is refused, so a symbol can
/// never reorder or hide the text around it. A character is a base code point
/// with the marks that follow it, which is what a reader counts.
bool loopMemberBuySymbolIsValid(String symbol) {
  if (symbol.isEmpty || !_symbolCharacters.hasMatch(symbol)) return false;
  var characters = 0;
  for (final rune in symbol.runes) {
    final mark = _combiningMark.hasMatch(String.fromCharCode(rune));
    if (mark && characters == 0) return false;
    if (!mark) characters += 1;
  }
  return characters <= loopMemberBuySymbolMaxLength;
}

/// One validated `member_buy.v1` payload.
///
/// Amounts stay as exact on-chain integers; the scaled figures are computed
/// with [Decimal], never with `double`.
@immutable
final class LoopMemberBuyEvent {
  const LoopMemberBuyEvent({
    required this.publicProfileId,
    required this.symbol,
    required this.decimals,
    required this.amountRaw,
    required this.quoteAmountRaw,
    required this.quoteIsStable,
    required this.quoteDecimals,
    required this.quoteSymbol,
    required this.txHash,
    required this.occurredAt,
  });

  final String publicProfileId;
  final String symbol;
  final int decimals;
  final BigInt amountRaw;
  final BigInt quoteAmountRaw;
  final bool quoteIsStable;
  final int quoteDecimals;

  /// The non-stable quote's own name; the v1 lane only ever quotes against
  /// WBNB on the non-stable side.
  final String quoteSymbol;
  final String txHash;

  /// The block's timestamp when the payload states one, else the moment
  /// Stream filed the message.
  final DateTime occurredAt;

  Decimal get amount => _scaled(amountRaw, decimals);
  Decimal get quoteAmount => _scaled(quoteAmountRaw, quoteDecimals);

  /// `0x1234…abcd`: the first six and the last four characters.
  String get shortTxHash =>
      '${txHash.substring(0, 6)}…${txHash.substring(txHash.length - 4)}';

  static Decimal _scaled(BigInt raw, int decimals) =>
      (Decimal.fromBigInt(raw) /
              Decimal.fromBigInt(BigInt.from(10).pow(decimals)))
          .toDecimal(scaleOnInfinitePrecision: decimals);

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _txHash = RegExp(r'^0x[0-9a-fA-F]{64}$');
  static final RegExp _raw = RegExp(r'^(0|[1-9][0-9]{0,77})$');

  /// The symbol a preview may print, or `null` when the payload has none LOOP
  /// accepts. Read on its own so a payload broken elsewhere still previews
  /// with its token.
  static String? previewSymbolOf(Message message) {
    final raw = message.extraData[loopMemberBuySymbolField];
    if (raw is! String) return null;
    final symbol = raw.trim();
    return loopMemberBuySymbolIsValid(symbol) ? symbol : null;
  }

  /// The validated event, or `null` when any required field is missing or
  /// malformed. `null` renders 「动态数据不完整」 — never a zero.
  static LoopMemberBuyEvent? tryParse(Message message) {
    final data = message.extraData;
    if (!loopIsMemberBuyMessage(message)) return null;
    final profile = data['publicProfileId'];
    if (profile is! String || !_uuid.hasMatch(profile)) return null;
    final symbol = previewSymbolOf(message);
    if (symbol == null) return null;
    final decimals = _int(data['decimals']);
    if (decimals == null || decimals < 0 || decimals > 36) return null;
    final amount = _bigInt(data['amountRaw']);
    if (amount == null || amount == BigInt.zero) return null;
    final quoteAmount = _bigInt(data['quoteAmountRaw']);
    if (quoteAmount == null) return null;
    final stable = data['quoteIsStable'];
    if (stable is! bool) return null;
    final tx = data['txHash'];
    if (tx is! String || !_txHash.hasMatch(tx)) return null;
    final quoteDecimals = switch (data['quoteDecimals']) {
      null => loopMemberBuyDefaultQuoteDecimals,
      final Object value => _int(value),
    };
    if (quoteDecimals == null || quoteDecimals < 0 || quoteDecimals > 36) {
      return null;
    }
    final quoteSymbol = switch (data['quoteSymbol']) {
      final String value when loopMemberBuySymbolIsValid(value.trim()) =>
        value.trim(),
      _ => 'WBNB',
    };
    return LoopMemberBuyEvent(
      publicProfileId: profile,
      symbol: symbol,
      decimals: decimals,
      amountRaw: amount,
      quoteAmountRaw: quoteAmount,
      quoteIsStable: stable,
      quoteDecimals: quoteDecimals,
      quoteSymbol: quoteSymbol,
      txHash: tx,
      occurredAt: _timestamp(data['blockTimestamp']) ?? message.createdAt,
    );
  }

  static int? _int(Object? raw) => switch (raw) {
    final int value => value,
    final String value when RegExp(r'^[0-9]{1,2}$').hasMatch(value) =>
      int.parse(value),
    _ => null,
  };

  static BigInt? _bigInt(Object? raw) => switch (raw) {
    final String value when _raw.hasMatch(value) => BigInt.parse(value),
    final int value when value >= 0 => BigInt.from(value),
    _ => null,
  };

  static DateTime? _timestamp(Object? raw) => switch (raw) {
    final String value => DateTime.tryParse(value)?.toLocal(),
    // Seconds since the epoch, the way a block header states it.
    final int value when value > 0 => DateTime.fromMillisecondsSinceEpoch(
      value * 1000,
      isUtc: true,
    ).toLocal(),
    _ => null,
  };
}

final Decimal _tenThousand = Decimal.fromInt(10000);
final Decimal _hundredMillion = Decimal.fromInt(100000000);

/// A token amount the way the card prints it.
///
/// From 1 万 up it is compact (`1.23万`, `4.5亿`); below that it is grouped
/// with two fraction digits, and an amount under one keeps up to six so a
/// small buy does not round to `0`. The tier is chosen after rounding to the
/// digits that will be shown, so `9,999.995` reads `1万`, not `10,000`, and
/// `99,999,999.5` reads `1亿`, not `10,000万`.
String loopFormatMemberBuyAmount(Decimal value) {
  if (value <= Decimal.zero) return '0';
  if (value < Decimal.one) {
    final text = loopFormatDecimal(value, maxFractionDigits: 6);
    // A positive amount that still rounds away reads as "under the floor",
    // not as zero.
    return text == '0' ? '<0.000001' : text;
  }
  final plain = value.round(scale: 2);
  if (plain < _tenThousand) {
    return loopFormatDecimal(plain, maxFractionDigits: 2);
  }
  final wan = _scaledTo(value, _tenThousand);
  if (wan < _tenThousand) {
    return '${loopFormatDecimal(wan, maxFractionDigits: 2)}万';
  }
  return '${loopFormatDecimal(_scaledTo(value, _hundredMillion), maxFractionDigits: 2)}亿';
}

Decimal _scaledTo(Decimal value, Decimal unit) =>
    (value / unit).toDecimal(scaleOnInfinitePrecision: 8).round(scale: 2);

/// The secondary line: `≈ $12.34` for a stable quote, `0.05 WBNB` otherwise.
String loopFormatMemberBuyQuote(LoopMemberBuyEvent event) {
  final quote = event.quoteAmount;
  if (event.quoteIsStable) {
    return '≈ \$${loopFormatMemberBuyAmount(quote)}';
  }
  return '${loopFormatMemberBuyAmount(quote)} ${event.quoteSymbol}';
}

/// The conversation-list preview: `群友买入 · PEPE`.
String loopMemberBuyPreviewText(Message message) {
  final symbol = LoopMemberBuyEvent.previewSymbolOf(message);
  return symbol == null
      ? loopMemberBuyPreviewLabel
      : '$loopMemberBuyPreviewLabel · $symbol';
}
