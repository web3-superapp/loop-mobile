import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';

/// Feature-facing port for the `meme` module (client decision 0120).
///
/// It exposes no transport type, no route literal and no idempotency detail.
/// Every failure is a [LoopChainException] carrying the server's own
/// `detailsSafe.reasonCode` when it named one, so a page explains a refusal
/// with the server's rule rather than a sentence of its own.
abstract interface class MemeGateway {
  LoopChainGatewayMode get mode;

  /// One page of one launchpad chip. A `503` is unavailable, never an empty
  /// list (contract §3).
  Future<MemeTokenPage> listTokens(MemeListTab tab, {String? cursor});

  Future<MemeTokenDetail> loadToken(String memeTokenId);

  Future<MemeTradePage> loadTrades(String memeTokenId, {String? cursor});

  Future<MemeHolderPage> loadHolders(String memeTokenId, {String? cursor});

  Future<MemeCandleSeries> loadCandles(
    String memeTokenId,
    MemeCandleInterval interval,
  );

  /// [amount] is a whole-unit decimal string: USD1 for a buy, tokens for a
  /// sell.
  Future<MemeQuote> quote({
    required String memeTokenId,
    required MemeTradeSide side,
    required String amount,
    String? walletId,
  });

  /// The square picture for a new token (`POST /v2/media/community-logos`).
  Future<MemeUploadedImage> uploadImage({
    required Uint8List bytes,
    required String contentType,
  });

  /// `POST /v2/meme/tokens`: a draft with its predicted address.
  Future<MemeTokenDetail> createToken(MemeCreateDraft draft);

  /// `POST /v2/meme/tokens/{id}/intents`. Exactly one of [usd1Amount] and
  /// [tokenAmount] is set for a buy or a sell; a create may carry a first
  /// buy in [usd1Amount].
  Future<MemeIntent> prepareIntent({
    required String memeTokenId,
    required MemeIntentKind kind,
    required String walletId,
    String? usd1Amount,
    String? tokenAmount,
    int? slippageBps,
  });

  /// Reports the main transaction's hash (never the approval's).
  Future<MemeIntent> reportBroadcast({
    required String memeTokenId,
    required String memeIntentId,
    required String txHash,
  });

  Future<MemeIntent> loadIntent(String memeIntentId);
}

/// Production default: every call fails closed with `unavailable`. No fixture
/// ever replaces a missing MEME fact.
final class UnavailableMemeGateway implements MemeGateway {
  const UnavailableMemeGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<MemeTokenPage> listTokens(MemeListTab tab, {String? cursor}) =>
      _unavailable();

  @override
  Future<MemeTokenDetail> loadToken(String memeTokenId) => _unavailable();

  @override
  Future<MemeTradePage> loadTrades(String memeTokenId, {String? cursor}) =>
      _unavailable();

  @override
  Future<MemeHolderPage> loadHolders(String memeTokenId, {String? cursor}) =>
      _unavailable();

  @override
  Future<MemeCandleSeries> loadCandles(
    String memeTokenId,
    MemeCandleInterval interval,
  ) => _unavailable();

  @override
  Future<MemeQuote> quote({
    required String memeTokenId,
    required MemeTradeSide side,
    required String amount,
    String? walletId,
  }) => _unavailable();

  @override
  Future<MemeUploadedImage> uploadImage({
    required Uint8List bytes,
    required String contentType,
  }) => _unavailable();

  @override
  Future<MemeTokenDetail> createToken(MemeCreateDraft draft) => _unavailable();

  @override
  Future<MemeIntent> prepareIntent({
    required String memeTokenId,
    required MemeIntentKind kind,
    required String walletId,
    String? usd1Amount,
    String? tokenAmount,
    int? slippageBps,
  }) => _unavailable();

  @override
  Future<MemeIntent> reportBroadcast({
    required String memeTokenId,
    required String memeIntentId,
    required String txHash,
  }) => _unavailable();

  @override
  Future<MemeIntent> loadIntent(String memeIntentId) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final memeGatewayProvider = Provider<MemeGateway>(
  (ref) => const UnavailableMemeGateway(),
);
