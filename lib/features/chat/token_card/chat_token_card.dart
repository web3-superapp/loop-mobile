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
import 'package:loop_mobile/features/chat/token_card/chat_token_detection.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

/// The line above every recognised card. The reader is told the card was not
/// written by the sender: LOOP read the address out of the message.
const String loopChatTokenCardKicker = '自动识别到代币';

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
/// disappearing.
class ChatTokenCard extends ConsumerWidget {
  const ChatTokenCard({required this.address, super.key, this.onNavigate});

  /// The lower-cased address [loopDetectChatTokenAddresses] found.
  final String address;

  /// Where the card's own destinations open. A test passes one; in the app
  /// the router does it.
  final void Function(String location)? onNavigate;

  void _open(BuildContext context, String location) {
    final navigate = onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(chatTokenCardCacheProvider.notifier);
    final held = ref.watch(
      chatTokenCardCacheProvider.select((entries) => entries[address]),
    );
    final entry = held ?? cache.entryFor(address);
    final now = ref.read(chatTokenCardClockProvider)();
    if (entry.readAt == null || entry.isStale(now)) {
      scheduleMicrotask(() => unawaited(cache.resolve(address)));
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
              key: ValueKey<String>('chat-token-card-kicker-$address'),
              style: LoopTypography.caption(11, color: LoopColors.muted),
            ),
          ),
          _body(context, ref, entry, cache),
        ],
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
      // Two answers carry a document and still have nothing to show: the
      // registry blocked the asset, and no provider could describe the
      // address at all. Both state the server's own reason instead of
      // printing an identity nobody reported.
      if (detail.capability.blocksEntirePage ||
          detail.asset.status == LoopAssetStatus.unavailable) {
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
      LoopChainFailureKind.notFound => LoopEmpty(
        key: ValueKey<String>('chat-token-card-unlisted-$address'),
        icon: 'info',
        message: '未收录的代币 · ${loopChatTokenShortAddress(address)}',
        reason: '这个合约地址不在 LOOP 的资产目录里，没有可展示的行情。',
      ),
      LoopChainFailureKind.offline => LoopEmpty(
        key: ValueKey<String>('chat-token-card-offline-$address'),
        icon: 'offline',
        message: '设备离线，没有读这个合约',
        reason: loopChainFailureReason(LoopChainFailureKind.offline),
        action: LoopButton(
          label: '重试',
          onPressed: () => unawaited(cache.resolve(address)),
        ),
      ),
      // Nothing has failed and nothing has answered yet.
      null => LoopTokenCard(
        key: ValueKey<String>('chat-token-card-loading-$address'),
        state: LoopTokenCardState.loading,
        model: LoopTokenCardModel(
          symbol: loopChatTokenShortAddress(address),
          identifier: loopChatTokenShortAddress(address),
          metrics: const <LoopTokenMetric>[
            LoopTokenMetric('市值', '等待数据'),
            LoopTokenMetric('流动性', '等待数据'),
            LoopTokenMetric('持有人', '等待数据'),
          ],
        ),
        actions: const <LoopTokenCardAction>[
          LoopTokenCardAction('买入', buy: true),
          LoopTokenCardAction('卖出'),
          LoopTokenCardAction('图表'),
          LoopTokenCardAction('社区'),
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
  }) {
    final blockedReasonCode = cache.blockedReasonCode;
    final sentence =
        reason ??
        (blockedReasonCode != null
            ? loopReasonCodeText(blockedReasonCode)
            : loopChainFailureReason(entry.asset.failureKind));
    // The server said the asks are coming too fast. A retry button next to
    // that sentence invites the next one, so the card states the wait and
    // offers no way to spend it.
    final rateLimited =
        entry.asset.failureKind == LoopChainFailureKind.rateLimited;
    return LoopTokenCard(
      key: ValueKey<String>('chat-token-card-unavailable-$address'),
      state: LoopTokenCardState.partial,
      model: LoopTokenCardModel(
        symbol: loopChatTokenShortAddress(address),
        identifier: loopChatTokenShortAddress(address),
        priceReason: '没有读到报价',
        metrics: const <LoopTokenMetric>[
          LoopTokenMetric('市值', '数据不可得'),
          LoopTokenMetric('流动性', '数据不可得'),
          LoopTokenMetric('持有人', '数据不可得'),
        ],
        footnotes: <String>[sentence],
      ),
      actions: <LoopTokenCardAction>[
        LoopTokenCardAction(
          '重试',
          onTap: rateLimited ? null : () => unawaited(cache.resolve(address)),
        ),
        LoopTokenCardAction(
          '代币页',
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
    final source = detail.asset.source;
    final unregistered =
        detail.asset.status == LoopAssetStatus.unregistered ||
        source.kind == LoopAssetSourceKind.providerLookup;
    final footnotes = <String>[
      // A contract the registry does not carry is still answered, and the
      // card says so rather than letting a reader take the card itself as a
      // listing. Where the identity came from is part of that sentence: a
      // provider's own answer is not a chain call LOOP made.
      if (detail.asset.status != LoopAssetStatus.verified)
        <String>[
          '资产目录状态 · ${detail.asset.status.label}',
          if (source.provider != null)
            '身份来自 ${loopFactSourceLabel(source.provider!)}',
          if (source.fetchedAt != null)
            '观察于 ${loopRelativeTime(source.fetchedAt!)}',
        ].join(' · '),
      // The provider could not be reached this time; the identity on the
      // card is the last one it gave.
      if (source.quality == LoopFactQuality.stale)
        loopFactQualityMarker(LoopFactQuality.stale)!,
      if (detail.price.isAvailable) '报价 ${loopFactProvenance(detail.price)}',
      if (riskFactCount > riskFacts.length)
        '另有 ${riskFactCount - riskFacts.length} 条合约事实，在代币页',
      '买入与卖出现在不可用 · $tradeReason',
    ];
    return LoopTokenCard(
      key: ValueKey<String>('chat-token-card-$address'),
      state: LoopTokenCardState.normal,
      model: LoopTokenCardModel(
        symbol: loopAssetSymbolLabel(detail.asset),
        // With no ticker the heading is already the address, so the line
        // under it names the chain instead of printing the same string
        // twice in a second typeface.
        identifier: detail.asset.symbol == null
            ? loopChainName(detail.asset.chainId)
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
        changeUp: detail.priceChange24h.isAvailable
            ? detail.priceChange24h.value! >= Decimal.zero
            : null,
        metrics: <LoopTokenMetric>[
          _metric('市值', detail.marketCap),
          _metric('流动性', detail.liquidityUsd),
          // An address outside the registry has no holder page to open and
          // no holder count to read; the cell says which of the two gaps it
          // is instead of the generic one.
          if (unregistered && !detail.holderCount.isAvailable)
            const LoopTokenMetric('持有人', '未收录')
          else
            _metric('持有人', detail.holderCount, usd: false),
        ],
        communityLine: switch (community) {
          MarketCommunityBound(:final name, :final memberCount) =>
            'LOOP 社区 $name · '
                '${loopFormatCompactFigure(Decimal.fromInt(memberCount), usd: false)} 成员',
          MarketCommunityUnavailable(reasonCode: 'COMMUNITY_NOT_BOUND') =>
            '暂无 LOOP 社区',
          MarketCommunityUnavailable(:final reasonCode) => loopReasonCodeText(
            reasonCode,
          ),
        },
        riskFacts: riskFacts,
        footnotes: footnotes,
        chartRangeLabel: '1H · 最近 $loopSparklineWindow 根收盘价',
        chart: TokenCardSparklineView(
          state: entry.candles,
          keyPrefix: 'chat-token-card-chart-$address',
        ),
      ),
      actions: <LoopTokenCardAction>[
        const LoopTokenCardAction('买入', buy: true),
        const LoopTokenCardAction('卖出'),
        LoopTokenCardAction(
          '图表',
          onTap: () => _open(context, MarketAssetRoute.token(entry.assetId)),
        ),
        LoopTokenCardAction(
          '社区',
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
