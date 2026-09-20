import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_detection.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

/// How long one address's answer stays good inside an open conversation.
///
/// A quote is a fact with an observation time, and a minute-old one is still
/// the minute-old one the card labels it as. Re-reading it every time a bubble
/// scrolls back into view would spend a request per pixel and still print the
/// same figure, so the answer is kept for this long and the card states when
/// it was observed.
const Duration loopChatTokenCardFreshness = Duration(seconds: 60);

/// The device clock the freshness window is measured against.
///
/// It is a provider so a test can hold time still; product code never reads
/// another clock for this.
final chatTokenCardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// One address's answer, as the conversation currently holds it.
///
/// It carries the two reads a card draws from — the asset and its 1H series —
/// in the same shape every other S5 surface consumes, so the card's five
/// states are decided by the same vocabulary as a page's.
@immutable
final class ChatTokenCardEntry {
  const ChatTokenCardEntry({
    required this.address,
    required this.assetId,
    required this.asset,
    required this.candles,
    this.readAt,
  });

  final String address;
  final String assetId;
  final LoopChainResourceState<MarketAssetDetail> asset;
  final LoopChainResourceState<MarketCandleSeries> candles;

  /// When the last read settled. `null` while nothing has settled yet.
  final DateTime? readAt;

  /// Whether a card asking now would be asking for a fact this entry no
  /// longer vouches for.
  bool isStale(DateTime now) {
    final settled = readAt;
    if (settled == null) return false;
    return now.difference(settled) >= loopChatTokenCardFreshness;
  }

  ChatTokenCardEntry copyWith({
    LoopChainResourceState<MarketAssetDetail>? asset,
    LoopChainResourceState<MarketCandleSeries>? candles,
    DateTime? readAt,
  }) => ChatTokenCardEntry(
    address: address,
    assetId: assetId,
    asset: asset ?? this.asset,
    candles: candles ?? this.candles,
    readAt: readAt ?? this.readAt,
  );
}

/// The conversation's own answers for the addresses its messages name.
///
/// One address is read once for the whole conversation, however many bubbles
/// name it, and the answer survives the bubble being scrolled out of the list
/// — the cards are rebuilt constantly while a long history scrolls, and a read
/// per rebuild would be a request per frame.
///
/// The cache lives exactly as long as the open conversation: the surface
/// watches it, so leaving the channel disposes it and nothing about another
/// channel's addresses is carried over.
final class ChatTokenCardCache
    extends Notifier<Map<String, ChatTokenCardEntry>> {
  final Set<String> _reading = <String>{};
  int _generation = 0;

  late LoopChainGatewayMode _mode;
  late bool _blocked;
  late String? _blockedReasonCode;

  @override
  Map<String, ChatTokenCardEntry> build() {
    final gateway = ref.watch(marketReadGatewayProvider);
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.marketRead),
    );
    _mode = gateway.mode;
    _blocked = loopChainCapabilityBlocks(gateway.mode, capability);
    _blockedReasonCode = capability.reasonCode;
    // A different port or a different capability document is a different set
    // of answers. The old ones are dropped rather than relabelled, and reads
    // still in flight under the old one are discarded when they land.
    _generation += 1;
    _reading.clear();
    return const <String, ChatTokenCardEntry>{};
  }

  /// What the conversation currently holds for [address], without asking for
  /// anything. A card renders this; [resolve] is what makes it move.
  ChatTokenCardEntry entryFor(String address) =>
      state[address] ?? _initial(address);

  ChatTokenCardEntry _initial(String address) {
    final assetId = loopChatTokenAssetId(address);
    if (_blocked) {
      return ChatTokenCardEntry(
        address: address,
        assetId: assetId,
        asset: LoopChainResourceState<MarketAssetDetail>(
          mode: _mode,
          phase: LoopChainViewPhase.unavailable,
          failureKind: LoopChainFailureKind.unavailable,
        ),
        candles: LoopChainResourceState<MarketCandleSeries>(
          mode: _mode,
          phase: LoopChainViewPhase.unavailable,
          failureKind: LoopChainFailureKind.unavailable,
        ),
      );
    }
    return ChatTokenCardEntry(
      address: address,
      assetId: assetId,
      asset: LoopChainResourceState<MarketAssetDetail>.initial(_mode),
      candles: LoopChainResourceState<MarketCandleSeries>.initial(_mode),
    );
  }

  /// The server's own sentence for a capability that closed this card, when
  /// it published one.
  String? get blockedReasonCode => _blocked ? _blockedReasonCode : null;

  /// Reads [address] unless this conversation already holds a fresh answer or
  /// is already reading it.
  Future<void> resolve(String address) async {
    if (_blocked) {
      // The capability is closed, so there is nothing to ask and nothing that
      // could change until the document itself changes. The entry is written
      // once; rewriting an identical one on every rebuild would publish a new
      // object each frame and the card would rebuild forever.
      if (state.containsKey(address)) return;
      state = <String, ChatTokenCardEntry>{
        ...state,
        address: _initial(address),
      };
      return;
    }
    if (_reading.contains(address)) return;
    final held = state[address];
    final now = ref.read(chatTokenCardClockProvider)();
    if (held != null && held.readAt != null && !held.isStale(now)) return;

    final generation = _generation;
    _reading.add(address);
    final started = held ?? _initial(address);
    _write(generation, started.copyWith(asset: started.asset.loading()));

    final gateway = ref.read(marketReadGatewayProvider);
    try {
      late final ChatTokenCardEntry afterAsset;
      try {
        final detail = await gateway.loadAsset(started.assetId);
        afterAsset = started.copyWith(asset: started.asset.ready(detail));
      } on LoopChainException catch (error) {
        _settle(
          generation,
          started.copyWith(asset: started.asset.failed(error.kind)),
        );
        return;
      } catch (_) {
        _settle(
          generation,
          started.copyWith(
            asset: started.asset.failed(LoopChainFailureKind.readFailed),
          ),
        );
        return;
      }
      if (generation != _generation) return;
      _write(
        generation,
        afterAsset.copyWith(candles: afterAsset.candles.loading()),
      );
      // The line is the asset's own 1H series. It is read only after the
      // asset answered: an address the registry does not carry has no series
      // to draw, and asking for one would spend a second request to be told
      // the same thing twice.
      try {
        final series = await gateway.loadCandles(
          afterAsset.assetId,
          interval: LoopCandleInterval.oneHour,
        );
        _settle(
          generation,
          afterAsset.copyWith(candles: afterAsset.candles.ready(series)),
        );
      } on LoopChainException catch (error) {
        _settle(
          generation,
          afterAsset.copyWith(candles: afterAsset.candles.failed(error.kind)),
        );
      } catch (_) {
        _settle(
          generation,
          afterAsset.copyWith(
            candles: afterAsset.candles.failed(LoopChainFailureKind.readFailed),
          ),
        );
      }
    } finally {
      _reading.remove(address);
    }
  }

  void _write(int generation, ChatTokenCardEntry entry) {
    if (generation != _generation) return;
    state = <String, ChatTokenCardEntry>{...state, entry.address: entry};
  }

  void _settle(int generation, ChatTokenCardEntry entry) {
    _write(
      generation,
      entry.copyWith(readAt: ref.read(chatTokenCardClockProvider)()),
    );
  }
}

final chatTokenCardCacheProvider =
    NotifierProvider.autoDispose<
      ChatTokenCardCache,
      Map<String, ChatTokenCardEntry>
    >(ChatTokenCardCache.new);
