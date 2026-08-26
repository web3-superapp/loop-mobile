import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/wallet_preview_activity.dart';
import 'package:loop_mobile/features/wallet/wallet_readiness.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:uuid/uuid.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  WalletPreviewActivityFilter filter = WalletPreviewActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final activities = WalletPreviewActivity.filteredBy(filter);
    final sections = <String>{
      for (final activity in activities) activity.section,
    };
    return LoopPage(
      title: 'Transaction history',
      eyebrow: '开发预览',
      subtitle: 'All activity below is 演示数据; no wallet history was read.',
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WalletPreviewActivityFilter.values
              .map((item) {
                return ChoiceChip(
                  label: Text(item.label),
                  selected: filter == item,
                  onSelected: (_) => setState(() => filter = item),
                );
              })
              .toList(growable: false),
        ),
        for (final section in sections) ...<Widget>[
          LoopSectionLabel(section),
          for (final activity in activities.where(
            (candidate) => candidate.section == section,
          ))
            _HistoryRow(activity: activity),
        ],
        const SizedBox(height: 12),
        const LoopStateCard(
          title: 'History behavior preview',
          message: 'Pending submissions stay on their transaction result screen until the network receipt is known.',
          icon: Icons.receipt_long_outlined,
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.activity});

  final WalletPreviewActivity activity;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (activity.kind) {
      WalletPreviewActivityKind.sent => (
        Icons.north_east_rounded,
        LoopTone.neutral,
      ),
      WalletPreviewActivityKind.received => (
        Icons.south_west_rounded,
        LoopTone.positive,
      ),
      WalletPreviewActivityKind.swap => (
        Icons.swap_horiz_rounded,
        LoopTone.market,
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 68,
      leading: CircleAvatar(
        backgroundColor: loopToneColor(tone).withValues(alpha: 0.12),
        child: Icon(icon, color: loopToneColor(tone)),
      ),
      title: Text(
        activity.title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        activity.meta,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: Text(activity.detail, style: context.dataStyle),
    );
  }
}

class WalletManagerScreen extends ConsumerWidget {
  const WalletManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = WalletReadiness.fromSession(
      ref.watch(loopSessionProvider),
    );
    return LoopPage(
      title: 'Manage wallets',
      eyebrow: readiness.canCopy
          ? 'Privy · Current session'
          : 'Wallet identity unavailable',
      subtitle: 'Only the first Embedded Ethereum wallet from the current Privy session can appear here.',
      children: <Widget>[
        if (readiness.canCopy)
          _WalletIdentity(
            title: 'Embedded Ethereum wallet',
            address: readiness.ethereumAddress!,
            label: 'Privy provider fact · current session',
          )
        else
          LoopStateCard(
            title: _managerUnavailableTitle(readiness.mode),
            message: _managerUnavailableMessage(readiness.mode),
            icon: Icons.account_balance_wallet_outlined,
            tone: readiness.mode == WalletReadinessMode.invalidAddress
                ? LoopTone.danger
                : LoopTone.warning,
            action: readiness.canCreate
                ? OutlinedButton(
                    onPressed: () => context.go('/wallet'),
                    child: const Text('Create from Wallet'),
                  )
                : null,
          ),
        const LoopSectionLabel('Wallet capabilities'),
        const LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'Signing policy',
                value: 'Unavailable · provider policy not verified',
              ),
              LoopKeyValueRow(label: 'Recovery', value: 'Not connected'),
              LoopKeyValueRow(
                label: 'Additional wallets',
                value: 'Unavailable in the first release',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Wallet identity is not signing authority',
          message: 'Showing a Privy address does not enable Send, Swap, approvals, recovery, or transaction signing.',
          icon: Icons.policy_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _WalletIdentity extends StatelessWidget {
  const _WalletIdentity({
    required this.title,
    required this.address,
    required this.label,
  });

  final String title;
  final String address;
  final String label;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: LoopTone.positive,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: LoopColors.mint.withValues(alpha: 0.12),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: LoopColors.mint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  address,
                  key: const ValueKey<String>('managed-wallet-address'),
                  style: context.dataStyle.copyWith(fontSize: 14),
                  softWrap: true,
                ),
                const SizedBox(height: 5),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: LoopColors.mint),
        ],
      ),
    );
  }
}

String _managerUnavailableTitle(WalletReadinessMode mode) => switch (mode) {
  WalletReadinessMode.needsWallet => 'No embedded wallet yet',
  WalletReadinessMode.preview => 'Unavailable in 开发预览',
  WalletReadinessMode.restricted => 'Verified session required',
  WalletReadinessMode.invalidAddress => 'Wallet address unavailable',
  WalletReadinessMode.ready => throw StateError('ready address handled above'),
};

String _managerUnavailableMessage(WalletReadinessMode mode) => switch (mode) {
  WalletReadinessMode.needsWallet =>
    'Create the first Embedded Ethereum wallet from the Wallet tab.',
  WalletReadinessMode.preview =>
    'Offline Preview does not invent embedded or external wallet identities.',
  WalletReadinessMode.restricted =>
    'Finish Privy verification before reading wallet identity.',
  WalletReadinessMode.invalidAddress =>
    'The provider value is not a complete Ethereum address and remains hidden.',
  WalletReadinessMode.ready => throw StateError('ready address handled above'),
};

class DappBrowserScreen extends ConsumerStatefulWidget {
  const DappBrowserScreen({super.key});

  @override
  ConsumerState<DappBrowserScreen> createState() => _DappBrowserScreenState();
}

class _DappBrowserScreenState extends ConsumerState<DappBrowserScreen> {
  final controller = TextEditingController(text: 'app.uniswap.org');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readiness = WalletReadiness.fromSession(
      ref.watch(loopSessionProvider),
    );
    final typedDomain = controller.text.trim();
    return LoopPage(
      title: 'DApp browser',
      eyebrow: '开发预览',
      subtitle: 'Local domain layout only. Embedded browsing and wallet injection remain disabled.',
      children: <Widget>[
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.lock_outline_rounded),
            suffixIcon: Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Browser and injection unavailable',
          message: 'The typed domain is not trusted, opened, resolved, or connected to a wallet.',
          icon: Icons.language_rounded,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('Before connecting'),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'Typed preview domain',
                value: typedDomain.isEmpty ? 'Unavailable' : typedDomain,
              ),
              LoopKeyValueRow(
                label: 'Current wallet identity',
                value: readiness.canCopy
                    ? readiness.ethereumAddress!
                    : 'Unavailable',
              ),
              const LoopKeyValueRow(
                label: 'Wallet injection',
                value: 'Unavailable',
              ),
              const LoopKeyValueRow(
                label: 'Granted permissions',
                value: 'None',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ApprovalInterceptScreen extends StatefulWidget {
  const ApprovalInterceptScreen({super.key});

  @override
  State<ApprovalInterceptScreen> createState() =>
      _ApprovalInterceptScreenState();
}

class _ApprovalInterceptScreenState extends State<ApprovalInterceptScreen> {
  bool unlimited = false;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Approval request',
      eyebrow: '开发预览 · Wallet protection',
      subtitle: 'This is a local layout draft. No DApp request or wallet fact was received.',
      bottom: LoopActionDock(
        child: FilledButton(
          onPressed: unlimited
              ? null
              : () {
                  final now = DateTime.now().toUtc();
                  context.push(
                    '/preview/signing-review',
                    extra: SigningIntent.approval(
                      revision: const Uuid().v4(),
                      app: 'app.uniswap.org',
                      asset: 'USDC',
                      allowance: '250.00 USDC',
                      network: 'Ethereum',
                      observedAt: now,
                      expiresAt: now.add(const Duration(seconds: 30)),
                    ),
                  );
                },
          child: Text(
            unlimited
                ? 'Choose a limited allowance'
                : 'Review limited approval',
          ),
        ),
      ),
      children: <Widget>[
        const LoopStateCard(
          title: '演示数据 · approval request',
          message: 'An approval is permission, not a payment. It remains active until you revoke it.',
          icon: Icons.policy_outlined,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('Allowance'),
        LoopCard(
          child: RadioGroup<bool>(
            groupValue: unlimited,
            onChanged: (value) => setState(() => unlimited = value ?? false),
            child: const Column(
              children: <Widget>[
                RadioListTile<bool>(
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Limited'),
                  subtitle: Text('Up to 250.00 USDC'),
                ),
                RadioListTile<bool>(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Unlimited'),
                  subtitle: Text(
                    'Not recommended · action disabled in preview',
                  ),
                ),
              ],
            ),
          ),
        ),
        const LoopSectionLabel('Request facts'),
        const LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'App', value: 'app.uniswap.org'),
              LoopKeyValueRow(label: 'Asset', value: 'USDC'),
              LoopKeyValueRow(label: 'Network', value: 'Ethereum'),
              LoopKeyValueRow(
                label: 'Current allowance',
                value: '0 USDC',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'App permissions',
      eyebrow: '开发预览',
      subtitle: 'Allowances below are 演示数据; no supported network was queried.',
      children: <Widget>[
        const LoopStateCard(
          title: '演示数据 · permission warning',
          message: 'This is a warning-layout example. No allowance or wallet balance was read.',
          icon: Icons.warning_amber_rounded,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('Ethereum'),
        LoopCard(
          accent: true,
          tone: LoopTone.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const LoopAssetMark(symbol: 'USDC'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Uniswap Router',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Unlimited USDC · last used Aug 20',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: const Text('Revocation unavailable'),
                ),
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Arbitrum'),
        const LoopStateCard(
          title: '演示数据 · empty allowance state',
          message: 'This preview is not evidence that the connected account has no allowances.',
          icon: Icons.visibility_outlined,
          tone: LoopTone.neutral,
        ),
      ],
    );
  }
}

class DappListScreen extends StatelessWidget {
  const DappListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoopPage(
      title: 'DApps',
      eyebrow: 'Later phase',
      subtitle: 'Bookmarks and recent apps will appear after browser isolation and permission controls are production-ready.',
      children: <Widget>[
        LoopStateCard(
          title: 'Deliberately deferred',
          message: 'The wallet can be completed without an embedded DApp directory. Direct domain connections remain the safer first release.',
          icon: Icons.apps_outlined,
        ),
      ],
    );
  }
}

class NetworksScreen extends StatefulWidget {
  const NetworksScreen({super.key});

  @override
  State<NetworksScreen> createState() => _NetworksScreenState();
}

class _NetworksScreenState extends State<NetworksScreen> {
  bool testnets = false;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Networks',
      eyebrow: '开发预览',
      subtitle: 'Network health rows below are 演示数据, not provider status.',
      children: <Widget>[
        const _NetworkRow(
          name: 'Ethereum',
          detail: '演示数据 · sample healthy state',
          tone: LoopTone.positive,
        ),
        const _NetworkRow(
          name: 'Arbitrum',
          detail: '演示数据 · sample healthy state',
          tone: LoopTone.positive,
        ),
        const _NetworkRow(
          name: 'Solana',
          detail: '演示数据 · sample delayed state',
          tone: LoopTone.warning,
        ),
        if (testnets)
          const _NetworkRow(
            name: 'Hyperliquid Testnet',
            detail: 'Market public reads only · not wallet network support',
            tone: LoopTone.neutral,
          ),
        const LoopSectionLabel('Developer access'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: testnets,
          onChanged: (value) => setState(() => testnets = value),
          title: const Text('Show testnets'),
          subtitle: const Text(
            'Display-only filter; it does not enable wallet support.',
          ),
        ),
      ],
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({
    required this.name,
    required this.detail,
    required this.tone,
  });

  final String name;
  final String detail;
  final LoopTone tone;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 66,
      leading: Icon(Icons.hub_outlined, color: loopToneColor(tone)),
      title: Text(name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(detail, style: Theme.of(context).textTheme.bodyMedium),
      trailing: LoopStatusPill(label: '演示数据', tone: LoopTone.neutral),
    );
  }
}

class ProtectionScreen extends StatelessWidget {
  const ProtectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoopPage(
      title: 'Transaction protection',
      eyebrow: 'Later phase',
      subtitle: 'Protection will explain concrete simulation findings without inventing a risk score.',
      children: <Widget>[
        LoopStateCard(
          title: 'No third-party protection configured',
          message: 'Privy policy and MFA protection require verified provider configuration. Contract simulation and malicious-domain detection require a separate trusted data source.',
          icon: Icons.shield_outlined,
          tone: LoopTone.warning,
        ),
        LoopSectionLabel('What remains protected'),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'High-value actions',
                value: 'Provider policy not verified',
              ),
              LoopKeyValueRow(
                label: 'Exact transaction facts',
                value: 'Backend canonical review required',
              ),
              LoopKeyValueRow(
                label: 'Provider result',
                value: 'Not connected',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
