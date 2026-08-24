import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class SigningReviewPage extends ConsumerWidget {
  const SigningReviewPage({required this.intent, super.key});

  final SigningIntent intent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Close review',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: LoopBackdrop()),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: SigningReviewSurface(intent: intent),
            ),
          ],
        ),
      ),
    );
  }
}

class SigningReviewSurface extends ConsumerStatefulWidget {
  const SigningReviewSurface({required this.intent, super.key});

  final SigningIntent intent;

  @override
  ConsumerState<SigningReviewSurface> createState() =>
      _SigningReviewSurfaceState();
}

class _SigningReviewSurfaceState extends ConsumerState<SigningReviewSurface> {
  bool acknowledged = false;
  bool submitting = false;
  String? result;

  @override
  Widget build(BuildContext context) {
    final gateway = ref.watch(walletSigningGatewayProvider);
    final validation = widget.intent.validateAt(DateTime.now().toUtc());
    final requiresBackend = widget.intent.requiresLoopBackend;
    final isLocalPreview = widget.intent.isLocalPreview;
    final canContinue =
        validation == null &&
        widget.intent.allowsWalletHandoff &&
        acknowledged &&
        gateway.availability == WalletGatewayAvailability.available &&
        !submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const LoopContextRail(stage: LoopStage.execute),
        const SizedBox(height: 20),
        Text(
          'Transaction intent review',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          requiresBackend
              ? 'Review this preview only. Hyperliquid orders require LOOP backend risk checks, idempotency and server-side signing.'
              : isLocalPreview
              ? 'This local draft is for layout review only. Backend canonicalization is required before wallet authorization.'
              : 'Review the complete canonical intent before a configured wallet provider performs final authorization.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        LoopCard(
          accent: true,
          tone: validation != null
              ? LoopTone.danger
              : requiresBackend || isLocalPreview
              ? LoopTone.warning
              : LoopTone.positive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    _iconForKind(widget.intent.kind),
                    color: validation == null
                        ? LoopColors.mint
                        : LoopColors.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.intent.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  LoopStatusPill(
                    label: validation != null
                        ? 'Blocked'
                        : requiresBackend
                        ? 'Backend required'
                        : isLocalPreview
                        ? 'Development preview'
                        : 'Local checks passed',
                    tone: validation != null
                        ? LoopTone.danger
                        : requiresBackend || isLocalPreview
                        ? LoopTone.warning
                        : LoopTone.positive,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...widget.intent.fields.indexed.map((entry) {
                return LoopKeyValueRow(
                  label: entry.$2.label,
                  value: entry.$2.value,
                  last: entry.$1 == widget.intent.fields.length - 1,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'Authority',
                value: requiresBackend
                    ? 'LOOP backend · not connected'
                    : isLocalPreview
                    ? 'Privy after backend canonical review'
                    : gateway.availability ==
                          WalletGatewayAvailability.fixtureReadOnly
                    ? 'Privy preview · read-only'
                    : gateway.label,
              ),
              LoopKeyValueRow(
                label: 'Intent revision',
                value: widget.intent.revision,
              ),
              LoopKeyValueRow(
                label: 'Observed',
                value: _time(widget.intent.observedAt),
              ),
              LoopKeyValueRow(
                label: 'Expires',
                value: _time(widget.intent.expiresAt),
                last: true,
              ),
            ],
          ),
        ),
        if (validation != null) ...<Widget>[
          const SizedBox(height: 14),
          LoopStateCard(
            title: 'Intent cannot be signed',
            message: _validationMessage(validation),
            icon: Icons.block_rounded,
            tone: LoopTone.danger,
          ),
        ] else if (requiresBackend) ...<Widget>[
          const SizedBox(height: 14),
          const LoopStateCard(
            title: 'Backend execution unavailable',
            message: 'This order will not be signed or submitted from the app. Connect the LOOP trading backend before enabling execution.',
            icon: Icons.dns_outlined,
            tone: LoopTone.warning,
          ),
        ] else if (isLocalPreview) ...<Widget>[
          const SizedBox(height: 14),
          const LoopStateCard(
            title: 'Canonical review unavailable',
            message: 'This locally constructed draft cannot be signed. The LOOP backend must return verified, immutable facts first.',
            icon: Icons.fact_check_outlined,
            tone: LoopTone.warning,
          ),
        ] else if (gateway.availability !=
            WalletGatewayAvailability.available) ...<Widget>[
          const SizedBox(height: 14),
          LoopStateCard(
            title: 'Wallet handoff unavailable',
            message:
                gateway.availability ==
                    WalletGatewayAvailability.fixtureReadOnly
                ? 'This preview is read-only. It will never submit an order or transfer.'
                : 'Wallet authorization is not connected to a backend canonical review yet.',
            icon: Icons.key_off_outlined,
            tone: LoopTone.warning,
          ),
        ],
        const SizedBox(height: 14),
        CheckboxListTile(
          value: acknowledged,
          enabled: validation == null,
          onChanged: (value) => setState(() => acknowledged = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I checked the exact asset, amount and destination',
          ),
          subtitle: const Text(
            'Values are not abbreviated inside the intent facts above.',
          ),
        ),
        if (result != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(result!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canContinue ? () => _handoff(gateway) : null,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_rounded),
            label: Text(
              submitting
                  ? 'Opening wallet…'
                  : requiresBackend
                  ? 'Backend execution unavailable'
                  : isLocalPreview
                  ? 'Canonical intent required'
                  : 'Continue to Privy',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: submitting ? null : () => context.pop(),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Future<void> _handoff(WalletSigningGateway gateway) async {
    if (!widget.intent.allowsWalletHandoff) {
      setState(() => result = 'This intent requires LOOP backend execution.');
      return;
    }
    setState(() {
      submitting = true;
      result = null;
    });
    final handoff = await gateway.handoff(
      widget.intent,
      now: DateTime.now().toUtc(),
    );
    if (!mounted) return;
    setState(() {
      submitting = false;
      result = handoff.accepted
          ? 'Wallet authorization opened.'
          : 'Wallet handoff stopped: ${handoff.code}.';
    });
  }

  static IconData _iconForKind(IntentKind kind) => switch (kind) {
    IntentKind.perpOrder => Icons.candlestick_chart_rounded,
    IntentKind.transfer => Icons.north_east_rounded,
    IntentKind.swap => Icons.swap_horiz_rounded,
    IntentKind.approval => Icons.policy_outlined,
  };

  static String _validationMessage(String code) => switch (code) {
    'market_not_core' => 'Only BTC, ETH and SOL Hyperliquid Core markets are permitted in this release.',
    'builder_fee_forbidden' =>
      'Builder fees are not enabled in the current product scope.',
    'intent_stale' => 'The quote expired. Return to the previous screen and request a fresh intent.',
    _ => 'The intent failed a local policy check.',
  };

  static String _time(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
  }
}
