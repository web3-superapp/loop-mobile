enum SigningAuthority { loopBackend, privyWallet }

enum IntentProvider { hyperliquidCore, wallet }

enum OrderDirection { buy, sell }

enum PerpOrderType { market, limit }

enum IntentKind { perpOrder, transfer, swap, approval }

enum IntentOrigin { localPreview, backendCanonical }

/// The exact object a backend-canonical intent hands to the wallet.
///
/// It is carried verbatim from the server response. The client never builds,
/// reorders or edits it: what the owner reads and what the wallet signs are
/// two halves of one canonical payload, bound by
/// [SigningIntent.payloadDigest].
sealed class SigningPayload {
  const SigningPayload();
}

/// Send, approve and revoke: the device broadcasts the transaction itself.
final class DeviceTransactionPayload extends SigningPayload {
  const DeviceTransactionPayload({
    required this.fromAddress,
    required this.transaction,
  });

  /// The embedded wallet the server built the payload for. A wallet whose
  /// address differs is a different wallet and must never sign this.
  final String fromAddress;

  /// The `eth_sendTransaction` parameter, exactly as the server sent it.
  final Map<String, Object?> transaction;
}

/// Swap: the device only authorizes the server's provider call.
final class AuthorizationSignaturePayload extends SigningPayload {
  const AuthorizationSignaturePayload({
    required this.version,
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  final int version;
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, Object?> body;
}

final class IntentField {
  const IntentField({required this.label, required this.value});

  final String label;
  final String value;
}

final class SigningIntent {
  SigningIntent._({
    required this.revision,
    required this.title,
    required this.kind,
    required this.authority,
    required this.provider,
    required this.origin,
    required this.observedAt,
    required this.expiresAt,
    required List<IntentField> fields,
    this.payloadDigest,
    this.payload,
  }) : fields = List<IntentField>.unmodifiable(fields);

  /// The only constructor that may produce a wallet-bound intent.
  ///
  /// [revision] is the server's opaque `intentId` and [payloadDigest] its
  /// `reviewSha256`: the SHA-256 of the canonical payload whose two halves are
  /// the [fields] shown here and the [payload] the wallet receives. A locally
  /// assembled object can never satisfy this constructor, so a preview draft
  /// can never reach a wallet.
  factory SigningIntent.backendCanonical({
    required String revision,
    required String payloadDigest,
    required String title,
    required IntentKind kind,
    required SigningPayload payload,
    required DateTime observedAt,
    required DateTime expiresAt,
    required List<IntentField> fields,
  }) {
    return SigningIntent._(
      revision: revision,
      title: title,
      kind: kind,
      authority: SigningAuthority.privyWallet,
      provider: IntentProvider.wallet,
      origin: IntentOrigin.backendCanonical,
      observedAt: observedAt,
      expiresAt: expiresAt,
      fields: fields,
      payloadDigest: payloadDigest,
      payload: payload,
    );
  }

  factory SigningIntent.perpOrder({
    required String revision,
    required String market,
    required OrderDirection direction,
    required PerpOrderType orderType,
    required String size,
    required int leverage,
    required String price,
    required String margin,
    required String fee,
    required String builderFee,
    required String liquidationEstimate,
    required DateTime observedAt,
    required DateTime expiresAt,
  }) {
    return SigningIntent._(
      revision: revision,
      title: '$market perpetual order',
      kind: IntentKind.perpOrder,
      authority: SigningAuthority.loopBackend,
      provider: IntentProvider.hyperliquidCore,
      origin: IntentOrigin.localPreview,
      observedAt: observedAt,
      expiresAt: expiresAt,
      fields: <IntentField>[
        IntentField(label: 'Market', value: market),
        IntentField(
          label: 'Direction',
          value: direction == OrderDirection.buy
              ? 'Buy / Long'
              : 'Sell / Short',
        ),
        IntentField(
          label: 'Order type',
          value: orderType == PerpOrderType.market ? 'Market' : 'Limit',
        ),
        IntentField(label: 'Price', value: price),
        IntentField(label: 'Size', value: size),
        IntentField(label: 'Leverage', value: '$leverage×'),
        IntentField(label: 'Margin', value: margin),
        IntentField(label: 'Fee', value: fee),
        IntentField(label: 'Builder fee', value: builderFee),
        IntentField(label: 'Liquidation estimate', value: liquidationEstimate),
      ],
    );
  }

  factory SigningIntent.transfer({
    required String revision,
    required String asset,
    required String amount,
    required String recipient,
    required String network,
    required String fee,
    required DateTime observedAt,
    required DateTime expiresAt,
  }) {
    return SigningIntent._(
      revision: revision,
      title: 'Send $asset',
      kind: IntentKind.transfer,
      authority: SigningAuthority.privyWallet,
      provider: IntentProvider.wallet,
      origin: IntentOrigin.localPreview,
      observedAt: observedAt,
      expiresAt: expiresAt,
      fields: <IntentField>[
        IntentField(label: 'Asset', value: asset),
        IntentField(label: 'Amount', value: amount),
        IntentField(label: 'Recipient', value: recipient),
        IntentField(label: 'Network', value: network),
        IntentField(label: 'Network fee', value: fee),
      ],
    );
  }

  factory SigningIntent.swap({
    required String revision,
    required String pay,
    required String receive,
    required String rate,
    required String fee,
    required DateTime observedAt,
    required DateTime expiresAt,
  }) {
    return SigningIntent._(
      revision: revision,
      title: 'Swap assets',
      kind: IntentKind.swap,
      authority: SigningAuthority.privyWallet,
      provider: IntentProvider.wallet,
      origin: IntentOrigin.localPreview,
      observedAt: observedAt,
      expiresAt: expiresAt,
      fields: <IntentField>[
        IntentField(label: 'You pay', value: pay),
        IntentField(label: 'You receive', value: receive),
        IntentField(label: 'Rate', value: rate),
        IntentField(label: 'Provider fee', value: fee),
      ],
    );
  }

  factory SigningIntent.approval({
    required String revision,
    required String app,
    required String asset,
    required String allowance,
    required String network,
    required DateTime observedAt,
    required DateTime expiresAt,
  }) {
    return SigningIntent._(
      revision: revision,
      title: 'Approve token access',
      kind: IntentKind.approval,
      authority: SigningAuthority.privyWallet,
      provider: IntentProvider.wallet,
      origin: IntentOrigin.localPreview,
      observedAt: observedAt,
      expiresAt: expiresAt,
      fields: <IntentField>[
        IntentField(label: 'App', value: app),
        IntentField(label: 'Asset', value: asset),
        IntentField(label: 'Allowance', value: allowance),
        IntentField(label: 'Network', value: network),
      ],
    );
  }

  final String revision;
  final String title;
  final IntentKind kind;
  final SigningAuthority authority;
  final IntentProvider provider;
  final IntentOrigin origin;
  final DateTime observedAt;
  final DateTime expiresAt;
  final List<IntentField> fields;

  /// The server's `reviewSha256`. Non-null exactly for a backend-canonical
  /// intent; it is what binds the displayed facts to the signed payload.
  final String? payloadDigest;

  /// The verbatim object handed to the wallet. Non-null exactly for a
  /// backend-canonical intent.
  final SigningPayload? payload;

  /// Hyperliquid account mutations are relayed by LOOP's backend. The mobile
  /// app must never send those intents to an embedded-wallet signing API.
  bool get requiresLoopBackend => authority == SigningAuthority.loopBackend;

  bool get isLocalPreview => origin == IntentOrigin.localPreview;

  bool get allowsWalletHandoff =>
      authority == SigningAuthority.privyWallet &&
      origin == IntentOrigin.backendCanonical &&
      payload != null &&
      payloadDigest != null;

  String? validateAt(DateTime now) {
    if (kind == IntentKind.perpOrder) {
      final market = fields
          .firstWhere((field) => field.label == 'Market')
          .value;
      if (!const <String>{'BTC', 'ETH', 'SOL'}.contains(market) ||
          market.contains(':')) {
        return 'market_not_core';
      }
      final builderFee = fields
          .firstWhere((field) => field.label == 'Builder fee')
          .value;
      if (builderFee != '0 USDC') {
        return 'builder_fee_forbidden';
      }
    }
    if (!expiresAt.isAfter(now)) {
      return 'intent_stale';
    }
    return null;
  }
}
