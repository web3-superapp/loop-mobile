import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:uuid/uuid.dart';

String _newPreviewRevision() => const Uuid().v4();

DateTime _currentUtcTime() => DateTime.now().toUtc();

@immutable
final class TransferDraft {
  const TransferDraft({
    required this.asset,
    required this.network,
    this.recipient = '',
  });

  final String asset;
  final String network;
  final String recipient;

  TransferDraft copyWith({String? recipient}) => TransferDraft(
    asset: asset,
    network: network,
    recipient: recipient ?? this.recipient,
  );
}

class SendAssetScreen extends StatelessWidget {
  const SendAssetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Choose asset',
      eyebrow: '开发预览 · Send · 1 of 3',
      subtitle: 'Balances below are layout fixtures. A wallet provider is not connected.',
      children: <Widget>[
        const TextField(
          decoration: InputDecoration(
            hintText: 'Search assets',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const LoopSectionLabel('Available · 演示数据'),
        _SendAssetRow(
          symbol: 'ETH',
          name: 'Ethereum',
          balance: '4.82 ETH',
          value: r'$22,319.01',
          onTap: () => context.push(
            '/wallet/send/to',
            extra: const TransferDraft(asset: 'ETH', network: 'Ethereum'),
          ),
        ),
        _SendAssetRow(
          symbol: 'USDC',
          name: 'USD Coin',
          balance: '6,810.20 USDC',
          value: r'$6,810.20',
          onTap: () => context.push(
            '/wallet/send/to',
            extra: const TransferDraft(asset: 'USDC', network: 'Ethereum'),
          ),
        ),
        _SendAssetRow(
          symbol: 'SOL',
          name: 'Solana',
          balance: '13.44 SOL',
          value: r'$2,110.79',
          onTap: () => context.push(
            '/wallet/send/to',
            extra: const TransferDraft(asset: 'SOL', network: 'Solana'),
          ),
        ),
        const LoopSectionLabel('Unavailable · 演示数据'),
        const LoopStateCard(
          title: '演示数据 · ARB zero-balance state',
          message: 'The asset remains visible so a zero balance is not confused with a loading error.',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }
}

class _SendAssetRow extends StatelessWidget {
  const _SendAssetRow({
    required this.symbol,
    required this.name,
    required this.balance,
    required this.value,
    required this.onTap,
  });

  final String symbol;
  final String name;
  final String balance;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minTileHeight: 68,
      contentPadding: EdgeInsets.zero,
      leading: LoopAssetMark(symbol: symbol),
      title: Text(name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(balance, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(value, style: context.dataStyle),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: LoopColors.vapor),
        ],
      ),
    );
  }
}

class SendRecipientScreen extends StatefulWidget {
  const SendRecipientScreen({required this.draft, super.key});

  final TransferDraft draft;

  @override
  State<SendRecipientScreen> createState() => _SendRecipientScreenState();
}

class _SendRecipientScreenState extends State<SendRecipientScreen> {
  late final controller = TextEditingController(text: widget.draft.recipient);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Choose recipient',
      eyebrow: '开发预览 · Send ${widget.draft.asset} · 2 of 3',
      subtitle: 'Enter the complete raw address. LOOP has not validated or screened it.',
      bottom: LoopActionDock(
        child: FilledButton(
          onPressed: controller.text.trim().isEmpty
              ? null
              : () => context.push(
                  '/wallet/send/confirm',
                  extra: widget.draft.copyWith(
                    recipient: controller.text.trim(),
                  ),
                ),
          child: const Text('Continue'),
        ),
      ),
      children: <Widget>[
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Complete recipient address',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            suffixIcon: IconButton(
              onPressed: null,
              tooltip: 'Scanner not connected',
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Recipient history unavailable',
          message: 'LOOP cannot determine whether this wallet has used the address before. Check every character in the final review.',
          icon: Icons.person_search_outlined,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('Recent'),
        const LoopStateCard(
          title: 'No verified recipient history',
          message: 'Recent recipients will appear only after the wallet backend supplies complete addresses.',
          icon: Icons.history_toggle_off_rounded,
        ),
        const LoopSectionLabel('Recipient facts'),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'Asset', value: widget.draft.asset),
              LoopKeyValueRow(label: 'Network', value: widget.draft.network),
              const LoopKeyValueRow(
                label: 'Format and screening',
                value: 'Not verified · backend unavailable',
                tone: LoopTone.warning,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SendConfirmScreen extends StatefulWidget {
  const SendConfirmScreen({
    required this.draft,
    this.revisionFactory,
    this.clock,
    super.key,
  });

  final TransferDraft draft;
  final String Function()? revisionFactory;
  final DateTime Function()? clock;

  @override
  State<SendConfirmScreen> createState() => _SendConfirmScreenState();
}

class _SendConfirmScreenState extends State<SendConfirmScreen> {
  final controller = TextEditingController();
  bool reviewOpening = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = TransferAmount.tryParse(controller.text);
    return LoopPage(
      title: 'Confirm transfer',
      eyebrow: '开发预览 · Send ${widget.draft.asset} · 3 of 3',
      subtitle: 'Draft review only. No quote, simulation, signing or submission has run.',
      bottom: LoopActionDock(
        child: FilledButton(
          onPressed:
              amount == null ||
                  widget.draft.recipient.trim().isEmpty ||
                  reviewOpening
              ? null
              : () => _openReview(amount),
          child: Text(reviewOpening ? 'Opening review…' : 'Review draft'),
        ),
      ),
      children: <Widget>[
        LoopCard(
          accent: true,
          tone: LoopTone.warning,
          child: Column(
            children: <Widget>[
              LoopAssetMark(symbol: widget.draft.asset, size: 52),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: Theme.of(context).textTheme.displayMedium,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  suffixText: widget.draft.asset,
                  helperText: controller.text.isEmpty
                      ? 'Exact positive decimal · spendable balance unavailable'
                      : amount == null
                      ? null
                      : 'Exact local amount · backend checks unavailable',
                  errorText: controller.text.isNotEmpty && amount == null
                      ? 'Use canonical positive decimal syntax (max 128 characters)'
                      : null,
                  counterText: '',
                ),
                maxLength: TransferAmount.maxWireLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Transfer details'),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'To', value: widget.draft.recipient),
              LoopKeyValueRow(
                label: 'Draft amount',
                value: amount == null
                    ? 'Unavailable'
                    : amount.displayWithAsset(widget.draft.asset),
              ),
              LoopKeyValueRow(label: 'Network', value: widget.draft.network),
              const LoopKeyValueRow(label: 'Network fee', value: 'Unavailable'),
              const LoopKeyValueRow(
                label: 'Recipient screening',
                value: 'Not performed',
                tone: LoopTone.warning,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Provider facts unavailable',
          message: 'The LOOP backend must validate the full recipient, screen policy, quote fees and return a canonical intent before signing can be enabled.',
          icon: Icons.policy_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }

  Future<void> _openReview(TransferAmount amount) async {
    if (reviewOpening) return;
    setState(() => reviewOpening = true);
    try {
      final now = (widget.clock ?? _currentUtcTime)().toUtc();
      final intent = SigningIntent.transfer(
        revision: (widget.revisionFactory ?? _newPreviewRevision)(),
        asset: widget.draft.asset,
        amount: amount.displayWithAsset(widget.draft.asset),
        recipient: widget.draft.recipient,
        network: widget.draft.network,
        fee: 'Unavailable · backend quote required',
        observedAt: now,
        expiresAt: now.add(const Duration(seconds: 30)),
      );
      await context.push('/preview/signing-review', extra: intent);
    } finally {
      if (mounted) setState(() => reviewOpening = false);
    }
  }
}

enum TransactionPreviewState { pending, succeeded, failed, unknown }

class TransactionResultScreen extends StatefulWidget {
  const TransactionResultScreen({super.key});

  @override
  State<TransactionResultScreen> createState() =>
      _TransactionResultScreenState();
}

class _TransactionResultScreenState extends State<TransactionResultScreen> {
  TransactionPreviewState state = TransactionPreviewState.pending;

  @override
  Widget build(BuildContext context) {
    final view = switch (state) {
      TransactionPreviewState.pending => (
        Icons.hourglass_top_rounded,
        LoopTone.warning,
        'Pending state example',
        'No request was sent or submitted. No pending receipt exists.',
      ),
      TransactionPreviewState.succeeded => (
        Icons.check_circle_rounded,
        LoopTone.positive,
        'Success state example',
        'No transfer occurred or was submitted. No success receipt exists.',
      ),
      TransactionPreviewState.failed => (
        Icons.error_outline_rounded,
        LoopTone.danger,
        'Failure state example',
        'No request was sent or submitted. No verified failure receipt exists.',
      ),
      TransactionPreviewState.unknown => (
        Icons.help_outline_rounded,
        LoopTone.warning,
        'Unknown state example',
        'No request was sent or submitted. No reconciliation is running.',
      ),
    };
    return LoopPage(
      title: 'Transaction result',
      eyebrow: '开发预览',
      subtitle:
          'Preview each terminal state without claiming a live transaction.',
      children: <Widget>[
        SegmentedButton<TransactionPreviewState>(
          segments: const <ButtonSegment<TransactionPreviewState>>[
            ButtonSegment<TransactionPreviewState>(
              value: TransactionPreviewState.pending,
              label: Text('Pending'),
            ),
            ButtonSegment<TransactionPreviewState>(
              value: TransactionPreviewState.succeeded,
              label: Text('Done'),
            ),
            ButtonSegment<TransactionPreviewState>(
              value: TransactionPreviewState.failed,
              label: Text('Failed'),
            ),
            ButtonSegment<TransactionPreviewState>(
              value: TransactionPreviewState.unknown,
              label: Text('Unknown'),
            ),
          ],
          selected: <TransactionPreviewState>{state},
          onSelectionChanged: (value) => setState(() => state = value.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 22),
        LoopCard(
          accent: true,
          tone: view.$2,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              Icon(view.$1, color: loopToneColor(view.$2), size: 50),
              const SizedBox(height: 16),
              Text(
                view.$3,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                view.$4,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'Asset', value: '演示数据 · 0.25 ETH'),
              LoopKeyValueRow(label: 'Network', value: '演示数据 · Ethereum'),
              LoopKeyValueRow(label: 'Recipient', value: 'Unavailable'),
              LoopKeyValueRow(
                label: 'Transaction',
                value: 'Not submitted',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => context.go('/wallet'),
          child: const Text('Return to wallet'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('No transaction to inspect'),
        ),
      ],
    );
  }
}
