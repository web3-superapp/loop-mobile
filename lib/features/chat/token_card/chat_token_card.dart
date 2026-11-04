import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_card_cache.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_card_view.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_detection.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

/// The line above every recognised card. The reader is told the card was not
/// written by the sender: LOOP read the address out of the message.
String get loopChatTokenCardKicker =>
    LoopL10n.current.chatTokenCard_cardLoopChatTokenCardKicker;

/// How many contract facts one chat card prints before it points at the
/// token page. A bubble is not a fact list.
const int loopChatTokenCardRiskFactLimit = 3;

/// The facts a chat card states about the contract, in the order they were
/// read.
///
/// Only the facts that say a mechanism **is** present are carried, plus a
/// contract whose source was never verified. A list of "未检测到…" lines would
/// bury the two that matter and would read as a clearance the card is not
/// entitled to give. Nothing here is a verdict: each line is one observation
/// with its source and its observation time, and the full list lives on the
/// token page.
List<LoopTokenRiskFact> chatTokenCardRiskFacts(MarketSecurityBlock block) {
  if (block is! MarketSecurityAvailable) return const <LoopTokenRiskFact>[];
  final facts = <LoopTokenRiskFact>[];
  for (final fact in block.facts) {
    if (!_statesAMechanism(fact)) continue;
    facts.add(
      LoopTokenRiskFact(
        fact: marketSecurityFactText(fact),
        source: loopFactSourceLabel(fact.source),
        observedLabel: loopRelativeTime(fact.observedAt),
      ),
    );
    if (facts.length == loopChatTokenCardRiskFactLimit) break;
  }
  return List<LoopTokenRiskFact>.unmodifiable(facts);
}

/// How many of [block]'s facts [chatTokenCardRiskFacts] would carry.
int chatTokenCardRiskFactCount(MarketSecurityBlock block) =>
    block is MarketSecurityAvailable
    ? block.facts.where(_statesAMechanism).length
    : 0;

bool _statesAMechanism(MarketSecurityFact fact) {
  if (fact.fact == 'openSource') return fact.value == 'false';
  if (fact.fact == 'buyTax' || fact.fact == 'sellTax') {
    final rate = Decimal.tryParse(fact.value);
    return rate != null && rate > Decimal.zero;
  }
  return fact.value == 'true';
}

/// The Token Card a message earns by naming a contract address.
///
/// The bubble above keeps the address exactly as it was typed; this card is
/// LOOP reading that address against the registry. It shows identity, quote,
/// the 1H line, three metrics, the LOOP community, the contract facts it read,
/// and four actions — two of which state why they cannot be taken rather than
/// disappearing. S326 · decision 0256 (UX-014): drawn by
/// [ChatTokenCardView] — fewer colour blocks, larger figures, the actions as
/// [LoopButton]s.
class ChatTokenCard extends ConsumerStatefulWidget {
  const ChatTokenCard({required this.address, super.key, this.onNavigate});

  /// The lower-cased address [loopDetectChatTokenAddresses] found.
  final String address;

  /// Where the card's own destinations open. A test passes one; in the app
  /// the router does it.
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<ChatTokenCard> createState() => _ChatTokenCardState();
}

/// The words of a card whose read failed while the device has a network
/// (S253). It is a failed load, not an offline device, and a tap retries it.
String get loopChatTokenCardFailedMessage =>
    LoopL10n.current.chatTokenCard_cardLoopChatTokenCardFailedMessage;

class _ChatTokenCardState extends ConsumerState<ChatTokenCard> {
  String get address => widget.address;

  @override
  void initState() {
    super.initState();
    // S253: a card scrolled back into view after a transient failure asks
    // once more by itself; the cache keeps that to one retry per failure.
    scheduleMicrotask(() {
      if (!mounted) return;
      unawaited(
        ref.read(chatTokenCardCacheProvider.notifier).retryOnce(address),
      );
    });
  }

  void _open(BuildContext context, String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(chatTokenCardCacheProvider.notifier);
    final held = ref.watch(
      chatTokenCardCacheProvider.select((entries) => entries[address]),
    );
    final entry = held ?? cache.entryFor(address);
    final now = ref.read(chatTokenCardClockProvider)();
    if (entry.readAt == null || entry.isStale(now)) {
      scheduleMicrotask(() => unawaited(cache.resolve(address)));
    }
    final body = _body(context, ref, entry, cache);
    // S326 · decision 0256 (UX-014): a card carries the line inside its own
    // top; an inline answer keeps it above.
    if (body is ChatTokenCardView) {
      return Semantics(container: true, child: body);
    }
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              loopChatTokenCardKicker,
              key: _kickerKey,
              style: LoopType.captionSm,
            ),
          ),
          body,
        ],
      ),
    );
  }

  Key get _kickerKey => ValueKey<String>('chat-token-card-kicker-$address');

  /// The 1H block's content: the line, or the one sentence that says why
  /// there is none, centred in the block.
  Widget _chart(ChatTokenCardEntry entry) {
    final keyPrefix = 'chat-token-card-chart-$address';
    final absence = tokenCardSparklineAbsence(entry.candles);
    if (absence == null) {
      return TokenCardSparklineView(state: entry.candles, keyPrefix: keyPrefix);
    }
    return Center(
      key: ValueKey<String>('$keyPrefix-${absence.keySuffix}'),
      child: Text(
        absence.text,
        maxLines: 3,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: LoopType.captionSm.copyWith(color: LoopColors.text2),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    ChatTokenCardEntry entry,
    ChatTokenCardCache cache,
  ) {
    final detail = entry.asset.value;
    if (detail != null) {
      // Two answers carry a document and still have nothing to show, and they
      // are not the same answer. No provider could describe the address for
      // this request — the payload has no identity in it at all — or the
      // registry carries the asset and will not let it be shown. Each states
      // its own reason instead of printing an identity nobody reported.
      if (detail.asset case final MarketAssetIdentityUnavailable identity) {
        return _unreadableCard(
          context,
          entry,
          cache,
          reason: marketAssetUnavailableSentence(identity),
          // Asking again while the provider's quota is spent buys the same
          // sentence and one fewer request.
          holdRetry: identity.reasonCode == 'MARKET_PROVIDER_RATE_LIMITED',
        );
      }
      if (detail.capability.blocksEntirePage) {
        return _unreadableCard(
          context,
          entry,
          cache,
          reason: loopReasonCodeText(
            detail.capability.reasonCode ?? 'ASSET_NOT_READABLE',
          ),
        );
      }
      return _readCard(context, ref, entry, detail);
    }
    return switch (entry.asset.failureKind) {
      // The registry has never carried this contract. That is an answer, not
      // a failure: there is nothing to retry and no figure to wait for.
      LoopChainFailureKind.notFound => LoopInlineUnavailable(
        key: ValueKey<String>('chat-token-card-unlisted-$address'),
        icon: 'info',
        message: context.l10n.chatTokenCard_cardMessage(
          loopChatTokenShortAddress(address),
        ),
        detail: context.l10n.chatTokenCard_cardDetail,
        maxLines: 2,
        detailMaxLines: 4,
      ),
      // The device reports no network at all: only this is 「离线」.
      LoopChainFailureKind.offline => LoopInlineUnavailable(
        key: ValueKey<String>('chat-token-card-offline-$address'),
        icon: 'offline',
        message: context.l10n.chatTokenCard_cardMessage2,
        detail: loopChainFailureReason(entry.asset.failureKind),
        maxLines: 2,
        detailMaxLines: 4,
        onRetry: () => unawaited(cache.resolve(address, force: true)),
      ),
      // S253: the request failed or ran out of time while the device had a
      // network. That is a failed load, and the whole line retries it.
      LoopChainFailureKind.timedOut ||
      LoopChainFailureKind.readFailed => Semantics(
        button: true,
        label: loopChatTokenCardFailedMessage,
        child: LoopPressable(
          scale: false,
          onTap: () => unawaited(cache.resolve(address, force: true)),
          child: LoopInlineUnavailable(
            key: ValueKey<String>('chat-token-card-failed-$address'),
            icon: 'warn',
            message: loopChatTokenCardFailedMessage,
            detail: entry.asset.failureKind == LoopChainFailureKind.timedOut
                ? context.l10n.chatTokenCard_cardDetail2(
                    loopChatTokenShortAddress(address),
                  )
                : context.l10n.chatTokenCard_cardDetail3(
                    loopChatTokenShortAddress(address),
                  ),
            maxLines: 2,
            detailMaxLines: 2,
            onRetry: () => unawaited(cache.resolve(address, force: true)),
          ),
        ),
      ),
      // Nothing has failed and nothing has answered yet.
      null => ChatTokenCardView(
        key: ValueKey<String>('chat-token-card-loading-$address'),
        kicker: loopChatTokenCardKicker,
        kickerKey: _kickerKey,
        state: LoopTokenCardState.loading,
        model: LoopTokenCardModel(
          symbol: loopChatTokenShortAddress(address),
          identifier: loopChatTokenShortAddress(address),
          metrics: <LoopTokenMetric>[
            LoopTokenMetric(
              context.l10n.common_marketCap,
              context.l10n.common_waitingForData,
            ),
            LoopTokenMetric(
              context.l10n.common_liquidity,
              context.l10n.common_waitingForData,
            ),
            LoopTokenMetric(
              context.l10n.common_holders,
              context.l10n.common_waitingForData,
            ),
          ],
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction(context.l10n.common_buy, buy: true),
          LoopTokenCardAction(context.l10n.common_sell),
          LoopTokenCardAction(context.l10n.common_chart),
          LoopTokenCardAction(context.l10n.common_community),
        ],
      ),
      // Everything else is LOOP not answering for this contract: the card
      // keeps the prototype's 数据缺失 shape and states the reason, so the
      // reader still sees which address was named.
      _ => _unreadableCard(context, entry, cache),
    };
  }

  /// The card for a contract LOOP could not read, or read and cannot show.
  Widget _unreadableCard(
    BuildContext context,
    ChatTokenCardEntry entry,
    ChatTokenCardCache cache, {
    String? reason,
    bool holdRetry = false,
  }) {
    final blockedReasonCode = cache.blockedReasonCode;
    final sentence =
        reason ??
        (blockedReasonCode != null
            ? loopReasonCodeText(blockedReasonCode)
            : loopChainFailureReason(entry.asset.failureKind));
    // The server said the asks are coming too fast. A retry button next to
    // that sentence invites the next one, so the card states the wait and
    // offers no way to spend it. A 429 envelope and a 200 whose reason is the
    // provider's spent quota are the same cooldown.
    final rateLimited =
        holdRetry ||
        entry.asset.failureKind == LoopChainFailureKind.rateLimited;
    return ChatTokenCardView(
      key: ValueKey<String>('chat-token-card-unavailable-$address'),
      kicker: loopChatTokenCardKicker,
      kickerKey: _kickerKey,
      state: LoopTokenCardState.partial,
      model: LoopTokenCardModel(
        symbol: loopChatTokenShortAddress(address),
        identifier: loopChatTokenShortAddress(address),
        priceReason: context.l10n.chatTokenCard_cardPriceReason,
        metrics: <LoopTokenMetric>[
          LoopTokenMetric(
            context.l10n.common_marketCap,
            context.l10n.common_dataUnavailable,
          ),
          LoopTokenMetric(
            context.l10n.common_liquidity,
            context.l10n.common_dataUnavailable,
          ),
          LoopTokenMetric(
            context.l10n.common_holders,
            context.l10n.common_dataUnavailable,
          ),
        ],
        footnotes: <String>[sentence],
      ),
      actions: <LoopTokenCardAction>[
        LoopTokenCardAction(
          context.l10n.common_retry,
          onTap: rateLimited
              ? null
              : () => unawaited(cache.resolve(address, force: true)),
        ),
        LoopTokenCardAction(
          context.l10n.chatTokenCard_cardLoopTokenCardAction,
          onTap: () => _open(context, MarketAssetRoute.token(entry.assetId)),
        ),
      ],
    );
  }

  Widget _readCard(
    BuildContext context,
    WidgetRef ref,
    ChatTokenCardEntry entry,
    MarketAssetDetail detail,
  ) {
    // 买入 and 卖出 are one gate, and it is the same one the wallet's funds
    // row reads. The buttons stay on the card and stay unpressable: hiding
    // them would answer "this asset cannot be traded", which is not what the
    // gate says.
    final swapGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.privySwap),
    );
    final tradeReason = loopReasonCodeText(
      swapGate.reasonCode ?? 'SWAP_MODULE_NOT_DELIVERED',
    );
    final community = detail.community;
    final riskFacts = chatTokenCardRiskFacts(detail.security);
    final riskFactCount = chatTokenCardRiskFactCount(detail.security);
    // Reached only through the settled branch above: an answer with no
    // identity never gets here.
    final asset = detail.asset.settled!;
    final source = asset.source;
    final unregistered =
        asset.status == LoopAssetStatus.unregistered ||
        source.kind == LoopAssetSourceKind.providerLookup;
    final footnotes = <String>[
      // A contract the registry does not carry is still answered, and the
      // card says so rather than letting a reader take the card itself as a
      // listing.
      if (asset.status != LoopAssetStatus.verified)
        context.l10n.chatTokenCard_cardReadCard(asset.status.label),
      // The provider could not be reached this time; the identity on the
      // card is the last one it gave.
      if (source.quality == LoopFactQuality.stale)
        loopFactQualityMarker(LoopFactQuality.stale)!,
      if (riskFactCount > riskFacts.length)
        context.l10n.chatTokenCard_cardReadCard2(
          riskFactCount - riskFacts.length,
        ),
      context.l10n.chatTokenCard_cardReadCard3(tradeReason),
    ];
    // S278 · decision 0236: where the identity and the quote came from is
    // behind the strip's (i), not printed. A provider's own answer is not a
    // chain call LOOP made, and the sheet says which it was.
    final provenance = <String>[
      if (asset.status != LoopAssetStatus.verified &&
          (source.provider != null || source.fetchedAt != null))
        <String>[
          if (source.provider != null)
            context.l10n.chatTokenCard_cardReadCard4(
              loopFactSourceLabel(source.provider!),
            ),
          if (source.fetchedAt != null)
            context.l10n.chatTokenCard_cardReadCard5(
              loopRelativeTime(source.fetchedAt!),
            ),
        ].join(' · '),
      if (detail.price.isAvailable)
        context.l10n.chatTokenCard_cardReadCard6(
          loopFactProvenance(detail.price),
        ),
    ];
    return ChatTokenCardView(
      key: ValueKey<String>('chat-token-card-$address'),
      kicker: loopChatTokenCardKicker,
      kickerKey: _kickerKey,
      state: LoopTokenCardState.normal,
      model: LoopTokenCardModel(
        symbol: loopAssetSymbolLabel(asset),
        logoUrl: detail.logoUrl,
        // With no ticker the heading is already the address, so the line
        // under it names the chain instead of printing the same string
        // twice in a second typeface.
        identifier: asset.symbol == null
            ? loopChainName(asset.chainId)
            : loopChatTokenShortAddress(address),
        price: detail.price.isAvailable
            ? loopFormatUsd(detail.price.value!)
            : null,
        priceReason: detail.price.isAvailable
            ? null
            : loopReasonCodeText(detail.price.reasonCode),
        change: detail.priceChange24h.isAvailable
            ? loopFormatPercent(detail.priceChange24h.value!)
            : null,
        move: LoopPriceMove.of(
          detail.priceChange24h.isAvailable
              ? detail.priceChange24h.value
              : null,
        ),
        metrics: <LoopTokenMetric>[
          _metric(context.l10n.common_marketCap, detail.marketCap),
          _metric(context.l10n.common_liquidity, detail.liquidityUsd),
          // An address outside the registry has no holder page to open and
          // no holder count to read; the cell says which of the two gaps it
          // is instead of the generic one.
          if (unregistered && !detail.holderCount.isAvailable)
            LoopTokenMetric(
              context.l10n.common_holders,
              context.l10n.chatTokenCard_cardLoopTokenMetric,
            )
          else
            _metric(
              context.l10n.common_holders,
              detail.holderCount,
              usd: false,
            ),
        ],
        communityLine: switch (community) {
          MarketCommunityBound(:final name, :final memberCount) =>
            context.l10n.chatTokenCard_cardMarketCommunityBound(
              loopFormatCompactFigure(Decimal.fromInt(memberCount), usd: false),
              name,
            ),
          MarketCommunityUnavailable(reasonCode: 'COMMUNITY_NOT_BOUND') =>
            context.l10n.chatTokenCard_cardMarketCommunityUnavailable,
          MarketCommunityUnavailable(:final reasonCode) => loopReasonCodeText(
            reasonCode,
          ),
        },
        riskFacts: riskFacts,
        footnotes: footnotes,
        provenance: provenance,
        chartRangeLabel: context.l10n.chatTokenCard_cardChartRangeLabel(
          loopSparklineWindow,
        ),
        chart: _chart(entry),
      ),
      actions: <LoopTokenCardAction>[
        LoopTokenCardAction(context.l10n.common_buy, buy: true),
        LoopTokenCardAction(context.l10n.common_sell),
        LoopTokenCardAction(
          context.l10n.common_chart,
          onTap: () => _open(context, MarketAssetRoute.token(entry.assetId)),
        ),
        LoopTokenCardAction(
          context.l10n.common_community,
          onTap: switch (community) {
            MarketCommunityBound(:final communityId) => () => _open(
              context,
              '/community/profile?id=$communityId',
            ),
            MarketCommunityUnavailable() => null,
          },
        ),
      ],
    );
  }

  LoopTokenMetric _metric(String label, LoopFact fact, {bool usd = true}) =>
      LoopTokenMetric(
        label,
        fact.isAvailable
            ? loopFormatCompactFigure(fact.value!, usd: usd)
            : loopReasonCodeSummaryText(fact.reasonCode),
      );
}
