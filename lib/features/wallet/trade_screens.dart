import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/bridge_preview_snapshot.dart';
import 'package:loop_mobile/features/wallet/swap_preview_snapshot.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:uuid/uuid.dart';

String _newSwapPreviewRevision() => const Uuid().v4();

DateTime _currentSwapUtcTime() => DateTime.now().toUtc();

class SwapScreen extends StatefulWidget {
  const SwapScreen({this.revisionFactory, this.clock, super.key});

  final String Function()? revisionFactory;
  final DateTime Function()? clock;

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final payController = TextEditingController(
    text: SwapPreviewSnapshot.demo.payAmount,
  );
  SwapPreviewSnapshot? snapshot = SwapPreviewSnapshot.demo;
  bool reviewOpening = false;

  @override
  void dispose() {
    payController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSnapshot = snapshot;
    return LoopPage(
      title: 'Swap',
      eyebrow: '开发预览',
      subtitle: 'All amounts below are 演示数据. No provider quote or transaction is connected.',
      bottom: LoopActionDock(
        child: FilledButton(
          onPressed: currentSnapshot == null
              ? _restoreSnapshot
              : reviewOpening
              ? null
              : () => _openReview(currentSnapshot),
          child: Text(
            currentSnapshot == null
                ? 'Restore demo snapshot'
                : reviewOpening
                ? 'Opening review…'
                : 'Review demo draft',
          ),
        ),
      ),
      children: <Widget>[
        _AssetAmountCard(
          label: 'YOU PAY',
          symbol: 'ETH',
          controller: payController,
          balance: 'Balance 4.82 ETH',
          onChanged: (_) => _invalidateSnapshot(),
        ),
        Transform.translate(
          offset: const Offset(0, -7),
          child: Center(
            child: IconButton.filledTonal(
              onPressed: null,
              tooltip: 'Asset reversal not connected',
              icon: const Icon(Icons.swap_vert_rounded),
            ),
          ),
        ),
        _ReceiveAmountCard(snapshot: currentSnapshot),
        const SizedBox(height: 16),
        if (currentSnapshot != null)
          const LoopStateCard(
            title: '演示数据 · quote layout',
            message: 'Sample output, minimum and slippage values are not provider facts and cannot be signed.',
            icon: Icons.timer_outlined,
            tone: LoopTone.warning,
          )
        else
          const LoopStateCard(
            title: 'Demo snapshot invalidated',
            message: 'The amount changed. Restore the labelled fixture before reviewing it; no quote will be requested.',
            icon: Icons.refresh_rounded,
            tone: LoopTone.warning,
          ),
        if (currentSnapshot != null) ...<Widget>[
          const LoopSectionLabel('Quote · 演示数据'),
          LoopCard(
            onTap: () =>
                context.push('/wallet/swap/route', extra: currentSnapshot),
            semanticLabel: 'Open swap quote details',
            child: Column(
              children: <Widget>[
                LoopKeyValueRow(label: 'Rate', value: currentSnapshot.rate),
                LoopKeyValueRow(
                  label: 'Provider fee',
                  value: currentSnapshot.providerFee,
                ),
                LoopKeyValueRow(
                  label: 'Network fee',
                  value: currentSnapshot.networkFee,
                ),
                LoopKeyValueRow(
                  label: 'Price impact',
                  value: currentSnapshot.priceImpact,
                  tone: LoopTone.positive,
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _invalidateSnapshot() {
    if (snapshot == null) return;
    setState(() => snapshot = null);
  }

  void _restoreSnapshot() {
    const restored = SwapPreviewSnapshot.demo;
    setState(() {
      payController.value = TextEditingValue(
        text: restored.payAmount,
        selection: TextSelection.collapsed(offset: restored.payAmount.length),
      );
      snapshot = restored;
    });
  }

  Future<void> _openReview(SwapPreviewSnapshot currentSnapshot) async {
    if (reviewOpening || !identical(snapshot, currentSnapshot)) return;
    setState(() => reviewOpening = true);
    try {
      final now = (widget.clock ?? _currentSwapUtcTime)().toUtc();
      final intent = currentSnapshot.toLocalSigningIntent(
        revision: (widget.revisionFactory ?? _newSwapPreviewRevision)(),
        observedAt: now,
        expiresAt: now.add(const Duration(seconds: 20)),
      );
      await context.push('/preview/signing-review', extra: intent);
    } finally {
      if (mounted) setState(() => reviewOpening = false);
    }
  }
}

class _AssetAmountCard extends StatelessWidget {
  const _AssetAmountCard({
    required this.label,
    required this.symbol,
    required this.controller,
    required this.balance,
    required this.onChanged,
  });

  final String label;
  final String symbol;
  final TextEditingController controller;
  final String balance;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              const LoopAssetMark(symbol: 'ETH'),
              const SizedBox(width: 10),
              Text(symbol, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: context.dataStyle.copyWith(fontSize: 24),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(balance, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ReceiveAmountCard extends StatelessWidget {
  const _ReceiveAmountCard({required this.snapshot});

  final SwapPreviewSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: snapshot == null ? LoopTone.warning : LoopTone.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('YOU RECEIVE', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              const LoopAssetMark(symbol: 'USDC'),
              const SizedBox(width: 10),
              Text(
                snapshot?.receiveAsset ?? 'USDC',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                snapshot?.receiveAmount ?? 'Unavailable',
                style: context.dataStyle.copyWith(fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            snapshot == null
                ? 'Edit invalidated the demo snapshot'
                : '演示数据 · no executable quote',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class SwapRouteScreen extends StatelessWidget {
  const SwapRouteScreen({required this.snapshot, super.key});

  final SwapPreviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Quote details',
      eyebrow: '开发预览',
      subtitle: 'No provider quote exists. These values demonstrate the intended review layout only.',
      children: <Widget>[
        const LoopStateCard(
          title: '演示数据 · provider quote layout',
          message: 'A route comparison is not shown when the provider does not supply verifiable route legs.',
          icon: Icons.route_outlined,
          tone: LoopTone.market,
        ),
        const LoopSectionLabel('Final amounts'),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'Input', value: snapshot.payLabel),
              LoopKeyValueRow(
                label: 'Expected output',
                value: snapshot.receiveLabel,
              ),
              LoopKeyValueRow(
                label: 'Minimum output',
                value: snapshot.minimumReceiveLabel,
              ),
              LoopKeyValueRow(
                label: 'All estimated fees',
                value: snapshot.allFees,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BridgeScreen extends StatelessWidget {
  const BridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const snapshot = BridgePreviewSnapshot.demo;
    return LoopPage(
      title: 'Bridge',
      eyebrow: '开发预览',
      subtitle: 'Cross-chain routing will be supplied by the selected provider; LOOP does not operate a bridge.',
      bottom: LoopActionDock(
        child: FilledButton(
          onPressed: () =>
              context.push('/wallet/bridge/status', extra: snapshot),
          child: const Text('Preview route status'),
        ),
      ),
      children: <Widget>[
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'From', value: snapshot.sourceLabel),
              LoopKeyValueRow(label: 'To', value: snapshot.destinationLabel),
              LoopKeyValueRow(
                label: 'Estimated time',
                value: snapshot.estimatedTimeLabel,
              ),
              LoopKeyValueRow(
                label: 'Estimated fees',
                value: snapshot.estimatedFeesLabel,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Route preview only',
          message: 'Production routing credentials are not configured. No bridge request will be submitted.',
          icon: Icons.lock_outline_rounded,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class BridgeStatusScreen extends StatefulWidget {
  const BridgeStatusScreen({required this.snapshot, super.key});

  final BridgePreviewSnapshot snapshot;

  @override
  State<BridgeStatusScreen> createState() => _BridgeStatusScreenState();
}

class _BridgeStatusScreenState extends State<BridgeStatusScreen> {
  late BridgePreviewSnapshot snapshot;

  @override
  void initState() {
    super.initState();
    snapshot = widget.snapshot;
  }

  @override
  void didUpdateWidget(BridgeStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      snapshot = widget.snapshot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Bridge progress',
      eyebrow: '开发预览',
      subtitle: 'State transitions below are simulated. No provider reference exists.',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Preview state',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Switch(
              value: snapshot.needsClaim,
              onChanged: (value) =>
                  setState(() => snapshot = snapshot.withNeedsClaim(value)),
            ),
            Text('Needs claim', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 14),
        for (final step in snapshot.progressSteps)
          _BridgeStep(
            index: step.index,
            title: step.title,
            detail: step.detail,
            complete: step.complete,
            warning: step.warning,
          ),
        const SizedBox(height: 18),
        if (snapshot.needsClaim)
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Claim provider not connected'),
          )
        else
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('No provider status'),
          ),
      ],
    );
  }
}

class _BridgeStep extends StatelessWidget {
  const _BridgeStep({
    required this.index,
    required this.title,
    required this.detail,
    required this.complete,
    this.warning = false,
  });

  final String index;
  final String title;
  final String detail;
  final bool complete;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? LoopColors.warning
        : (complete ? LoopColors.mint : LoopColors.vapor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LoopCard(
        accent: complete || warning,
        tone: warning
            ? LoopTone.warning
            : (complete ? LoopTone.positive : LoopTone.neutral),
        child: Row(
          children: <Widget>[
            Text(index, style: context.dataStyle.copyWith(color: color)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(
              complete
                  ? Icons.check_circle_rounded
                  : (warning
                        ? Icons.warning_amber_rounded
                        : Icons.more_horiz_rounded),
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
