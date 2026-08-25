import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/perp/perp_models.dart';
import 'package:loop_mobile/features/perp/perp_widgets.dart';
import 'package:loop_mobile/features/perp/positions/perp_positions_controller.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// D4 — Current position projection.
class PerpPositionsScreen extends ConsumerWidget {
  const PerpPositionsScreen({
    super.key,
    this.snapshotState = PerpSnapshotState.preview,
  });

  final PerpSnapshotState snapshotState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(developmentPreviewEnabledProvider)) {
      return _PerpPositionsPreview(snapshotState: snapshotState);
    }
    return const _PerpPositionsLive();
  }
}

class _PerpPositionsPreview extends StatelessWidget {
  const _PerpPositionsPreview({required this.snapshotState});

  final PerpSnapshotState snapshotState;

  @override
  Widget build(BuildContext context) {
    final hasFacts = snapshotState == PerpSnapshotState.preview;
    return LoopPage(
      key: const ValueKey<String>('perp-preview-positions'),
      eyebrow: 'D4 · Provider positions · 开发预览',
      title: 'Positions',
      subtitle: 'PnL and liquidation values render only from a fresh, correlated Hyperliquid snapshot.',
      actions: <Widget>[
        IconButton(
          onPressed: () => context.push('/perp/orders'),
          tooltip: 'Open orders',
          icon: const Icon(Icons.receipt_long_outlined),
        ),
      ],
      children: <Widget>[
        PerpSnapshotBanner(state: snapshotState),
        const SizedBox(height: 15),
        const PerpQuickRoutes(),
        if (!hasFacts) ...<Widget>[
          const SizedBox(height: 18),
          PerpStatePanel(state: snapshotState),
        ] else ...<Widget>[
          const LoopSectionLabel(
            'Open positions',
            trailing: LoopStatusPill(
              label: '1 preview',
              tone: LoopTone.positive,
            ),
          ),
          _PositionCard(
            position: PerpPreviewData.ethPosition,
            onTap: () => context.push('/perp/position'),
          ),
          const LoopSectionLabel('Portfolio risk'),
          LoopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Margin usage',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '32.4%',
                      style: context.dataStyle.copyWith(
                        color: LoopColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: LoopRadius.pill,
                  child: const LinearProgressIndicator(
                    value: 0.324,
                    minHeight: 8,
                    color: LoopColors.warning,
                    backgroundColor: LoopColors.elevated,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Simulated portfolio ratio · not a live liquidation warning',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const PerpReadOnlyNotice(
            message: 'Close and reduce actions are disabled. Open the position to inspect management controls and their execution boundary.',
          ),
        ],
      ],
    );
  }
}

class _PerpPositionsLive extends ConsumerStatefulWidget {
  const _PerpPositionsLive();

  @override
  ConsumerState<_PerpPositionsLive> createState() => _PerpPositionsLiveState();
}

class _PerpPositionsLiveState extends ConsumerState<_PerpPositionsLive>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(perpPositionsControllerProvider.notifier).expireIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(loopSessionProvider);
    final state = ref.watch(perpPositionsControllerProvider);
    final controller = ref.read(perpPositionsControllerProvider.notifier);
    final wallet = session.account?.wallet?.address;
    final factsAreFresh = state.hasFreshFactsAt(
      ref.read(perpPositionsClockProvider)(),
    );
    if (state.phase == PerpPositionsPhase.ready && !factsAreFresh) {
      scheduleMicrotask(() {
        if (mounted) controller.expireIfNeeded();
      });
    }
    if (session.canUseProviderBackedFeatures &&
        wallet != null &&
        state.phase == PerpPositionsPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }

    return LoopPage(
      key: const ValueKey<String>('perp-live-positions'),
      eyebrow: 'D4 · Hyperliquid Testnet',
      title: 'Positions',
      subtitle: 'Short-lived Core Perp positions read through the LOOP backend. Continuation pages are live keyset reads, not one point-in-time snapshot.',
      actions: <Widget>[
        IconButton(
          key: const ValueKey<String>('perp-positions-refresh'),
          onPressed:
              state.isBusy ||
                  !session.canUseProviderBackedFeatures ||
                  wallet == null
              ? null
              : () => unawaited(controller.refresh()),
          tooltip: 'Refresh position projection',
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          onPressed: () => context.push('/perp/account'),
          tooltip: 'Open Perp account',
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
      ],
      children: <Widget>[
        const _PerpPositionsLiveBanner(),
        const SizedBox(height: 18),
        if (!session.canUseProviderBackedFeatures)
          const LoopStateCard(
            title: 'Verified Privy session required',
            message: 'Sign in online and complete verification before LOOP requests any private position fact.',
            icon: Icons.person_off_outlined,
            tone: LoopTone.warning,
          )
        else if (wallet == null)
          LoopStateCard(
            title: 'Perp account setup required',
            message: 'Create a Privy wallet from the Perp account page first. Wallet creation never binds it automatically.',
            icon: Icons.account_balance_wallet_outlined,
            tone: LoopTone.warning,
            action: FilledButton.icon(
              onPressed: () => context.push('/perp/account'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Open Perp account'),
            ),
          )
        else
          ..._stateContent(context, state, controller, factsAreFresh),
      ],
    );
  }

  List<Widget> _stateContent(
    BuildContext context,
    PerpPositionsState state,
    PerpPositionsController controller,
    bool factsAreFresh,
  ) {
    return switch (state.phase) {
      PerpPositionsPhase.initial ||
      PerpPositionsPhase.loading => const <Widget>[_LoadingPositionsCard()],
      PerpPositionsPhase.ready => <Widget>[
        if (factsAreFresh)
          ..._readyContent(context, state, controller)
        else
          _positionsFailureCard(
            title: 'Position projection expired',
            message: 'The backend freshness window ended, so LOOP will clear every position value before rendering another frame.',
            state: state,
            controller: controller,
            icon: Icons.history_toggle_off_rounded,
          ),
      ],
      PerpPositionsPhase.bindingRequired => <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('perp-positions-binding-required'),
          title: 'Wallet binding required',
          message: _appendRequestId(
            'The LOOP backend requires a freshly reviewed Privy wallet binding before private positions can be read. This page never binds automatically.',
            state.requestId,
          ),
          icon: Icons.link_rounded,
          tone: LoopTone.warning,
          action: FilledButton.icon(
            onPressed: () async {
              await context.push<void>('/perp/account');
              if (mounted) unawaited(controller.refresh());
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Review in Perp account'),
          ),
        ),
      ],
      PerpPositionsPhase.stale => <Widget>[
        _positionsFailureCard(
          title: 'Position projection expired',
          message: 'The backend freshness window ended, so LOOP cleared size, PnL, margin, and liquidation facts.',
          state: state,
          controller: controller,
          icon: Icons.history_toggle_off_rounded,
        ),
      ],
      PerpPositionsPhase.unavailable => <Widget>[
        _positionsFailureCard(
          title: 'Private positions unavailable',
          message: 'The secure backend session is unavailable. No preview position is substituted in production.',
          state: state,
          controller: controller,
          icon: Icons.cloud_off_outlined,
        ),
      ],
      PerpPositionsPhase.failure => <Widget>[
        _positionsFailureCard(
          title: 'Position projection unavailable',
          message: _positionsFailureMessage(state.failureKind),
          state: state,
          controller: controller,
          icon: Icons.cloud_off_outlined,
        ),
      ],
    };
  }

  List<Widget> _readyContent(
    BuildContext context,
    PerpPositionsState state,
    PerpPositionsController controller,
  ) {
    return <Widget>[
      LoopSectionLabel(
        'Open Core Perp positions',
        trailing: LoopStatusPill(
          label: state.items.isEmpty
              ? 'EMPTY · FRESH'
              : '${state.items.length} LOADED · FRESH',
          tone: state.items.isEmpty ? LoopTone.neutral : LoopTone.positive,
        ),
      ),
      if (state.items.isEmpty)
        LoopStateCard(
          key: const ValueKey<String>('perp-positions-empty'),
          title: 'No open Core Perp positions',
          message: 'The current fresh Testnet response contains no BTC, ETH, or SOL position.',
          icon: Icons.layers_clear_outlined,
          action: OutlinedButton.icon(
            onPressed: () => unawaited(controller.refresh()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        )
      else
        for (var index = 0; index < state.items.length; index++) ...<Widget>[
          _LivePositionCard(position: state.items[index]),
          if (index != state.items.length - 1) const SizedBox(height: 10),
        ],
      if (state.pageFailureKind != null) ...<Widget>[
        const SizedBox(height: 12),
        LoopStateCard(
          key: const ValueKey<String>('perp-positions-page-failure'),
          title: 'More positions could not be loaded',
          message: _appendRequestId(
            'The already displayed page remains fresh. LOOP did not hide it or claim the continuation is complete.',
            state.pageRequestId,
          ),
          icon: Icons.sync_problem_rounded,
          tone: LoopTone.warning,
          action: OutlinedButton.icon(
            key: const ValueKey<String>('perp-positions-retry-more'),
            onPressed: () => unawaited(controller.loadMore()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry more'),
          ),
        ),
      ] else if (state.isLoadingMore) ...<Widget>[
        const SizedBox(height: 12),
        const _LoadingMorePositionsCard(),
      ] else if (state.nextCursor != null) ...<Widget>[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey<String>('perp-positions-load-more'),
          onPressed: () => unawaited(controller.loadMore()),
          icon: const Icon(Icons.expand_more_rounded),
          label: const Text('Load more positions'),
        ),
      ],
      const LoopSectionLabel('Freshness'),
      LoopCard(
        key: const ValueKey<String>('perp-positions-freshness'),
        child: Column(
          children: <Widget>[
            LoopKeyValueRow(
              label: 'Last page fetched',
              value: _formatPositionTime(state.lastFetchedAt!),
            ),
            LoopKeyValueRow(
              label: 'Projection expires',
              value: _formatPositionTime(state.expiresAt!),
            ),
            LoopKeyValueRow(label: 'Pages loaded', value: '${state.pageCount}'),
            const LoopKeyValueRow(
              label: 'Pagination',
              value: 'Live keyset · not a frozen snapshot',
              last: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const PerpReadOnlyNotice(
        message: 'This screen reads positions only. Close, reduce, leverage, margin, TP/SL, transfer, withdrawal, signing, and every trading mutation remain unavailable.',
      ),
    ];
  }

  Widget _positionsFailureCard({
    required String title,
    required String message,
    required PerpPositionsState state,
    required PerpPositionsController controller,
    required IconData icon,
  }) {
    return Semantics(
      key: const ValueKey<String>('perp-positions-status-live-region'),
      liveRegion: true,
      child: LoopStateCard(
        title: title,
        message: _appendRequestId(message, state.requestId),
        icon: icon,
        tone: LoopTone.warning,
        action: OutlinedButton.icon(
          onPressed: state.isBusy
              ? null
              : () => unawaited(controller.refresh()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ),
    );
  }
}

class _PerpPositionsLiveBanner extends StatelessWidget {
  const _PerpPositionsLiveBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hyperliquid Testnet private positions, backend mediated and read-only',
      child: LoopCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.lock_outline_rounded, color: LoopColors.mint),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'BACKEND-MEDIATED · TESTNET',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: LoopColors.mint, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Private position facts expire quickly; trading writes stay locked.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPositionsCard extends StatelessWidget {
  const _LoadingPositionsCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey<String>('perp-live-positions-loading'),
      liveRegion: true,
      label: 'Loading fresh positions',
      child: LoopCard(
        child: Row(
          children: <Widget>[
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                'Loading fresh positions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingMorePositionsCard extends StatelessWidget {
  const _LoadingMorePositionsCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading more positions',
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _LivePositionCard extends StatelessWidget {
  const _LivePositionCard({required this.position});

  final PerpPosition position;

  @override
  Widget build(BuildContext context) {
    final symbol = position.coin.name.toUpperCase();
    final side = switch (position.side) {
      PerpPositionSide.long => 'Long',
      PerpPositionSide.short => 'Short',
    };
    final leverageMode = switch (position.leverage.mode) {
      PerpLeverageMode.cross => 'Cross',
      PerpLeverageMode.isolated => 'Isolated',
    };
    final pnlTone = _positionDecimalTone(position.unrealizedPnl);
    final roePercent = position.returnOnEquity * Decimal.fromInt(100);
    return LoopCard(
      key: ValueKey<String>('perp-live-position-${position.coin.name}'),
      accent: position.unrealizedPnl != Decimal.zero,
      tone: pnlTone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              LoopAssetMark(symbol: symbol, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$symbol-PERP',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$side · ${position.leverage.value}× $leverageMode · One-way',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LoopKeyValueRow(
            label: 'Unrealized PnL',
            value: '${_signedPositionDecimal(position.unrealizedPnl)} USDC',
            tone: pnlTone,
          ),
          LoopKeyValueRow(
            label: 'Return on equity',
            value: '${_signedPositionDecimal(roePercent)}%',
            tone: _positionDecimalTone(roePercent),
          ),
          LoopKeyValueRow(
            label: 'Position size',
            value: '${position.size} $symbol',
          ),
          LoopKeyValueRow(
            label: 'Entry price',
            value: position.entryPrice == null
                ? 'Unavailable'
                : '${position.entryPrice} USDC',
          ),
          LoopKeyValueRow(
            label: 'Liquidation estimate',
            value: position.liquidationPrice == null
                ? 'Unavailable'
                : '${position.liquidationPrice} USDC',
            tone: position.liquidationPrice == null
                ? LoopTone.neutral
                : LoopTone.warning,
          ),
          LoopKeyValueRow(
            label: 'Margin used',
            value: '${position.marginUsed} USDC',
          ),
          LoopKeyValueRow(
            label: 'Position value',
            value: '${position.positionValue} USDC',
          ),
          LoopKeyValueRow(
            label: 'Leverage raw USD',
            value: position.leverage.rawUsd == null
                ? 'Unavailable'
                : '${position.leverage.rawUsd} USDC',
            last: true,
          ),
        ],
      ),
    );
  }
}

LoopTone _positionDecimalTone(Decimal value) {
  final comparison = value.compareTo(Decimal.zero);
  if (comparison > 0) return LoopTone.positive;
  if (comparison < 0) return LoopTone.danger;
  return LoopTone.neutral;
}

String _signedPositionDecimal(Decimal value) {
  return value.compareTo(Decimal.zero) > 0 ? '+$value' : '$value';
}

String _appendRequestId(String message, String? requestId) {
  return requestId == null ? message : '$message\n\nRequest ID: $requestId';
}

String _positionsFailureMessage(PerpGatewayFailureKind? kind) => switch (kind) {
  PerpGatewayFailureKind.authentication ||
  PerpGatewayFailureKind.bootstrapRequired => 'The verified backend session ended. Sign in again or retry after Privy reconnects.',
  PerpGatewayFailureKind.walletBindingRequired =>
    'Review the wallet binding in Perp account before reading positions again.',
  PerpGatewayFailureKind.versionConflict => 'The wallet-binding version changed, so the previous projection was cleared.',
  PerpGatewayFailureKind.invalidRequest =>
    'The bounded position request or its continuation cursor was rejected.',
  PerpGatewayFailureKind.timeout || PerpGatewayFailureKind.connection => 'LOOP could not obtain a fresh response. Previous position values were cleared.',
  PerpGatewayFailureKind.cancelled => 'The request was retired because the active identity, wallet, or backend changed.',
  PerpGatewayFailureKind.invalidData => 'The response failed strict source, ordering, pagination, schema, or freshness validation.',
  PerpGatewayFailureKind.unavailable =>
    'The private-read backend is currently unavailable.',
  PerpGatewayFailureKind.unexpected ||
  null => 'The private position projection could not be completed safely.',
};

String _formatPositionTime(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  String three(int part) => part.toString().padLeft(3, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}.'
      '${three(utc.millisecond)} UTC';
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position, required this.onTap});

  final PerpPositionPreview position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: LoopTone.positive,
      onTap: onTap,
      semanticLabel: 'Open ${position.symbol} preview position details',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              LoopAssetMark(symbol: position.symbol),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${position.symbol}-PERP',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${position.side} · ${position.leverage} · isolated',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    position.pnl,
                    style: context.dataStyle.copyWith(color: LoopColors.mint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+17.28% preview',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: <Widget>[
              Expanded(
                child: LoopMetric(label: 'Size', value: position.size),
              ),
              Expanded(
                child: LoopMetric(label: 'Entry', value: position.entry),
              ),
              Expanded(
                child: LoopMetric(
                  label: 'Liq. estimate',
                  value: position.liquidation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              Text(
                'View management preview',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_rounded, size: 19),
            ],
          ),
        ],
      ),
    );
  }
}

/// D5 — Position detail and disabled management actions.
class PerpPositionScreen extends ConsumerWidget {
  const PerpPositionScreen({
    super.key,
    this.snapshotState = PerpSnapshotState.preview,
  });

  final PerpSnapshotState snapshotState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(developmentPreviewEnabledProvider)) {
      return const _PerpPositionLiveUnavailable();
    }
    final hasFacts = snapshotState == PerpSnapshotState.preview;
    const position = PerpPreviewData.ethPosition;
    return LoopPage(
      key: const ValueKey<String>('perp-preview-position-detail'),
      eyebrow: 'D5 · ${position.id} · 开发预览',
      title: '${position.symbol} position',
      subtitle: 'Inspect liquidation and margin facts without exposing a production mutation path.',
      children: <Widget>[
        PerpSnapshotBanner(state: snapshotState),
        if (!hasFacts) ...<Widget>[
          const SizedBox(height: 18),
          PerpStatePanel(state: snapshotState),
        ] else ...<Widget>[
          const SizedBox(height: 20),
          LoopCard(
            accent: true,
            tone: LoopTone.positive,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const LoopAssetMark(symbol: 'ETH', size: 48),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'ETH-PERP',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Long · isolated · preview',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          position.pnl,
                          style: context.dataStyle.copyWith(
                            color: LoopColors.mint,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Unrealized',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const LoopKeyValueRow(
                  label: 'Position size',
                  value: '1.25 ETH',
                ),
                const LoopKeyValueRow(label: 'Entry price', value: '4,580.20'),
                const LoopKeyValueRow(label: 'Mark price', value: '4,630.50'),
                const LoopKeyValueRow(label: 'Leverage', value: '20×'),
                const LoopKeyValueRow(label: 'Margin', value: '289.41 USDC'),
                const LoopKeyValueRow(
                  label: 'Liquidation estimate',
                  value: '4,410.00',
                  tone: LoopTone.warning,
                  last: true,
                ),
              ],
            ),
          ),
          const LoopSectionLabel('Liquidation distance'),
          LoopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      '4.76% preview',
                      style: context.dataStyle.copyWith(
                        color: LoopColors.warning,
                      ),
                    ),
                    const Spacer(),
                    const LoopStatusPill(
                      label: 'RECALCULATION REQUIRED',
                      tone: LoopTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                ClipRRect(
                  borderRadius: LoopRadius.pill,
                  child: const LinearProgressIndicator(
                    value: 0.476,
                    minHeight: 9,
                    color: LoopColors.warning,
                    backgroundColor: LoopColors.elevated,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  'Display-only preview. Live use requires a fresh market calculation and independent verification.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const LoopSectionLabel('Management controls'),
          const Row(
            children: <Widget>[
              Expanded(
                child: _DisabledPositionAction(
                  icon: Icons.tune_rounded,
                  label: 'Leverage',
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: _DisabledPositionAction(
                  icon: Icons.add_card_rounded,
                  label: 'Margin',
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Row(
            children: <Widget>[
              Expanded(
                child: _DisabledPositionAction(
                  icon: Icons.flag_outlined,
                  label: 'TP / SL',
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: _DisabledPositionAction(
                  icon: Icons.call_split_rounded,
                  label: 'Partial close',
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Close position unavailable'),
          ),
          const SizedBox(height: 12),
          const PerpReadOnlyNotice(
            message: 'TP/SL, leverage, margin, partial close, and full close are visible for product review but have no executable handler.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/perp/funding'),
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('Inspect funding history'),
          ),
        ],
      ],
    );
  }
}

class _PerpPositionLiveUnavailable extends StatelessWidget {
  const _PerpPositionLiveUnavailable();

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      key: const ValueKey<String>('perp-position-live-unavailable'),
      eyebrow: 'D5 · Hyperliquid Testnet',
      title: 'Position detail',
      subtitle: 'The production detail projection is intentionally unavailable until it can share a fresh D4 position without adding a second source of truth.',
      children: <Widget>[
        const _PerpPositionsLiveBanner(),
        const SizedBox(height: 18),
        LoopStateCard(
          title: 'Live position detail unavailable',
          message: 'No ETH fixture, mark price, liquidation distance, or management control is substituted here. Return to the fresh read-only Positions page.',
          icon: Icons.lock_outline_rounded,
          tone: LoopTone.warning,
          action: FilledButton.icon(
            onPressed: () => context.go('/perp/positions'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to Positions'),
          ),
        ),
      ],
    );
  }
}

class _DisabledPositionAction extends StatelessWidget {
  const _DisabledPositionAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: null,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// D6 — Current order and conditional order projection.
class PerpOrdersScreen extends StatelessWidget {
  const PerpOrdersScreen({
    super.key,
    this.snapshotState = PerpSnapshotState.preview,
  });

  final PerpSnapshotState snapshotState;

  @override
  Widget build(BuildContext context) {
    final hasFacts = snapshotState == PerpSnapshotState.preview;
    return LoopPage(
      eyebrow: 'D6 · Provider orders',
      title: 'Open orders',
      subtitle: 'Order controls are intentionally inert until production mutation gates are complete.',
      actions: <Widget>[
        IconButton(
          onPressed: () => context.push('/perp/history'),
          tooltip: 'Open fill history',
          icon: const Icon(Icons.history_rounded),
        ),
      ],
      children: <Widget>[
        PerpSnapshotBanner(state: snapshotState),
        const SizedBox(height: 15),
        const PerpQuickRoutes(),
        if (!hasFacts) ...<Widget>[
          const SizedBox(height: 18),
          PerpStatePanel(state: snapshotState),
        ] else ...<Widget>[
          const LoopSectionLabel(
            'Current orders',
            trailing: LoopStatusPill(
              label: '2 previews',
              tone: LoopTone.market,
            ),
          ),
          const _OrderCard(
            symbol: 'BTC',
            side: 'Buy / Long',
            kind: 'Limit',
            price: '114,800.00',
            size: '0.05 BTC',
            filled: '0%',
          ),
          const SizedBox(height: 10),
          const _OrderCard(
            symbol: 'SOL',
            side: 'Sell / Short',
            kind: 'Limit',
            price: '225.40',
            size: '25 SOL',
            filled: '0%',
          ),
          const LoopSectionLabel('Conditional orders'),
          const LoopStateCard(
            title: 'TP/SL execution disabled',
            message: 'No trigger orders are created, edited, or inferred in preview. This section remains empty by design.',
            icon: Icons.flag_outlined,
            tone: LoopTone.warning,
          ),
          const SizedBox(height: 12),
          const PerpReadOnlyNotice(
            message: 'Cancel and modify buttons are disabled. Preview order IDs cannot be submitted.',
          ),
        ],
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.symbol,
    required this.side,
    required this.kind,
    required this.price,
    required this.size,
    required this.filled,
  });

  final String symbol;
  final String side;
  final String kind;
  final String price;
  final String size;
  final String filled;

  @override
  Widget build(BuildContext context) {
    final isLong = side.contains('Long');
    return LoopCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              LoopAssetMark(symbol: symbol, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$symbol-PERP',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$kind · preview',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              LoopStatusPill(
                label: side.toUpperCase(),
                tone: isLong ? LoopTone.positive : LoopTone.danger,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: LoopMetric(label: 'Price', value: price),
              ),
              Expanded(
                child: LoopMetric(label: 'Size', value: size),
              ),
              Expanded(
                child: LoopMetric(label: 'Filled', value: filled),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(onPressed: null, child: Text('Modify')),
              ),
              SizedBox(width: 9),
              Expanded(
                child: OutlinedButton(onPressed: null, child: Text('Cancel')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// D7 — Fill and funding event history.
class PerpHistoryScreen extends StatelessWidget {
  const PerpHistoryScreen({
    super.key,
    this.snapshotState = PerpSnapshotState.preview,
  });

  final PerpSnapshotState snapshotState;

  @override
  Widget build(BuildContext context) {
    final hasFacts = snapshotState == PerpSnapshotState.preview;
    return LoopPage(
      eyebrow: 'D7 · Provider history',
      title: 'Trade history',
      subtitle: 'Preview fills and funding events demonstrate structure only; exports remain disabled.',
      actions: <Widget>[
        IconButton(
          onPressed: null,
          tooltip: 'Export is disabled in preview',
          icon: const Icon(Icons.file_download_outlined),
        ),
      ],
      children: <Widget>[
        PerpSnapshotBanner(state: snapshotState),
        if (!hasFacts) ...<Widget>[
          const SizedBox(height: 18),
          PerpStatePanel(state: snapshotState),
        ] else ...<Widget>[
          const SizedBox(height: 16),
          const _HistorySummary(),
          const LoopSectionLabel('24 Aug · preview events'),
          const _HistoryEvent(
            time: '08:31:14',
            symbol: 'ETH',
            title: 'Opened long',
            detail: '1.25 ETH @ 4,580.20 · Market',
            amount: '-2.89 USDC fee',
            tone: LoopTone.positive,
          ),
          const _HistoryEvent(
            time: '08:00:00',
            symbol: 'BTC',
            title: 'Funding settled',
            detail: '0.0100% · preview data',
            amount: '-0.84 USDC',
            tone: LoopTone.warning,
          ),
          const _HistoryEvent(
            time: '07:42:08',
            symbol: 'SOL',
            title: 'Closed short',
            detail: '12 SOL @ 218.40 · Reduce only',
            amount: '+18.26 USDC PnL',
            tone: LoopTone.positive,
            last: true,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => context.push('/perp/funding'),
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('Open funding details'),
          ),
          const SizedBox(height: 12),
          const PerpReadOnlyNotice(
            message: 'History rows are preview records, not account statements. Production export and tax reporting are unavailable.',
          ),
        ],
      ],
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary();

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: LoopTone.market,
      child: const Row(
        children: <Widget>[
          Expanded(
            child: LoopMetric(
              label: 'Realized PnL',
              value: '+18.26 USDC',
              tone: LoopTone.positive,
            ),
          ),
          Expanded(
            child: LoopMetric(label: 'Fees', value: '3.73 USDC'),
          ),
          Expanded(
            child: LoopMetric(label: 'Events', value: '3 preview'),
          ),
        ],
      ),
    );
  }
}

class _HistoryEvent extends StatelessWidget {
  const _HistoryEvent({
    required this.time,
    required this.symbol,
    required this.title,
    required this.detail,
    required this.amount,
    required this.tone,
    this.last = false,
  });

  final String time;
  final String symbol;
  final String title;
  final String detail;
  final String amount;
  final LoopTone tone;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(
              time,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          LoopAssetMark(symbol: symbol, size: 34),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            textAlign: TextAlign.right,
            style: context.dataStyle.copyWith(
              color: loopToneColor(tone),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
