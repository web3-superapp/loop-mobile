import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/wallet_readiness.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _creatingWallet = false;
  String? _walletError;

  @override
  Widget build(BuildContext context) {
    final readiness = WalletReadiness.fromSession(
      ref.watch(loopSessionProvider),
    );
    return LoopPage(
      title: 'Wallet',
      eyebrow: readiness.mode == WalletReadinessMode.preview
          ? '开发预览 · Embedded wallet'
          : 'Privy · Embedded Ethereum wallet',
      subtitle: _walletSubtitle(readiness.mode),
      actions: <Widget>[
        IconButton(
          onPressed: () => context.push('/wallet/manage'),
          tooltip: 'Manage wallets',
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        IconButton(
          onPressed: () => context.push('/profile/security'),
          tooltip: 'Wallet security',
          icon: const Icon(Icons.shield_outlined),
        ),
        const SizedBox(width: 4),
      ],
      children: <Widget>[
        _WalletReadinessCard(
          readiness: readiness,
          creating: _creatingWallet,
          errorMessage: _walletError,
          onCreate: readiness.canCreate ? _createWallet : null,
          onCopy: readiness.canCopy
              ? () => _copyAddress(readiness.ethereumAddress!)
              : null,
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Portfolio remains 开发预览',
          message: 'Balances, assets and approval warnings on this page are 演示数据. No wallet read or transaction request was made.',
          icon: Icons.visibility_outlined,
          tone: LoopTone.warning,
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: LoopContextRail(stage: LoopStage.execute),
        ),
        const SizedBox(height: 22),
        const _WalletBalanceCard(),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: _WalletAction(
                label: 'Send preview',
                icon: Icons.north_east_rounded,
                onTap: () => context.push('/wallet/send'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _WalletAction(
                label: 'Wallet address',
                icon: Icons.south_west_rounded,
                onTap: () => context.push('/wallet/receive'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _WalletAction(
                label: 'Swap preview',
                icon: Icons.swap_vert_rounded,
                onTap: () => context.push('/wallet/swap'),
              ),
            ),
          ],
        ),
        const LoopSectionLabel('Assets'),
        _AssetRow(
          symbol: 'ETH',
          name: 'Ethereum',
          amount: '4.82 ETH',
          value: r'$22,319.01',
          change: '+3.8%',
          onTap: () => context.push('/wallet/asset'),
        ),
        _AssetRow(
          symbol: 'USDC',
          name: 'USD Coin',
          amount: '6,810.20 USDC',
          value: r'$6,810.20',
          change: '0.0%',
          onTap: () => context.push('/wallet/asset'),
        ),
        _AssetRow(
          symbol: 'SOL',
          name: 'Solana',
          amount: '13.44 SOL',
          value: r'$2,110.79',
          change: '-1.2%',
          onTap: () => context.push('/wallet/asset'),
        ),
        const LoopSectionLabel('Review'),
        LoopStateCard(
          title: '演示数据 · 1 app can spend USDC',
          message: 'Review the exact allowance and revoke it if you no longer use the app.',
          icon: Icons.policy_outlined,
          tone: LoopTone.warning,
          action: OutlinedButton(
            onPressed: () => context.push('/wallet/approvals'),
            child: const Text('Review permission'),
          ),
        ),
      ],
    );
  }

  Future<void> _createWallet() async {
    if (_creatingWallet) return;
    setState(() {
      _creatingWallet = true;
      _walletError = null;
    });
    try {
      await ref.read(loopSessionProvider.notifier).createWallet();
    } on PrivyGatewayException catch (error) {
      if (mounted) setState(() => _walletError = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _walletError =
              'Wallet creation could not be confirmed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _creatingWallet = false);
    }
  }

  Future<void> _copyAddress(String address) async {
    final current = WalletReadiness.fromSession(ref.read(loopSessionProvider));
    if (!current.canCopy || current.ethereumAddress != address) {
      _showMessage(
        'Wallet changed. Review the current address before copying.',
      );
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: address));
      if (!mounted) return;
      final latest = WalletReadiness.fromSession(ref.read(loopSessionProvider));
      _showMessage(
        latest.canCopy && latest.ethereumAddress == address
            ? 'Wallet address copied.'
            : 'Wallet changed while copying. Check the address before using it.',
      );
    } catch (_) {
      if (mounted) _showMessage('Wallet address was not copied. Try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _walletSubtitle(WalletReadinessMode mode) => switch (mode) {
  WalletReadinessMode.ready => 'Wallet identity is loaded from the current Privy session. Balances and signing remain unavailable.',
  WalletReadinessMode.needsWallet => 'Create the first embedded Ethereum wallet for this verified Privy account.',
  WalletReadinessMode.preview =>
    'Offline Preview does not create or expose a real wallet.',
  WalletReadinessMode.restricted =>
    'A fully verified Privy session is required for wallet actions.',
  WalletReadinessMode.invalidAddress =>
    'Privy wallet identity could not be verified from the current session.',
};

class _WalletReadinessCard extends StatelessWidget {
  const _WalletReadinessCard({
    required this.readiness,
    required this.creating,
    required this.errorMessage,
    required this.onCreate,
    required this.onCopy,
  });

  final WalletReadiness readiness;
  final bool creating;
  final String? errorMessage;
  final VoidCallback? onCreate;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    if (readiness.mode == WalletReadinessMode.ready) {
      return LoopCard(
        accent: true,
        tone: LoopTone.positive,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: LoopColors.mint,
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Wallet ready')),
                LoopStatusPill(label: 'PRIVY FACT', tone: LoopTone.positive),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              readiness.ethereumAddress!,
              key: const ValueKey<String>('wallet-ready-address'),
              style: context.dataStyle.copyWith(fontSize: 15),
              softWrap: true,
            ),
            const SizedBox(height: 10),
            Text(
              'This exact Embedded Ethereum wallet address belongs to the current session. It does not prove balances, deposits, or signing.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy wallet address'),
            ),
          ],
        ),
      );
    }

    final presentation = switch (readiness.mode) {
      WalletReadinessMode.needsWallet => (
        'Create embedded Ethereum wallet',
        'Privy will create at most the first embedded Ethereum wallet for this verified account. This does not enable Send, Swap, deposits, or signing.',
        Icons.add_card_rounded,
        LoopTone.market,
      ),
      WalletReadinessMode.preview => (
        'Wallet unavailable in 开发预览',
        'Offline Preview never creates a provider wallet or exposes a real address.',
        Icons.visibility_off_outlined,
        LoopTone.warning,
      ),
      WalletReadinessMode.restricted => (
        'Wallet requires a verified session',
        'Finish Privy verification before creating or reading an embedded wallet.',
        Icons.lock_outline_rounded,
        LoopTone.warning,
      ),
      WalletReadinessMode.invalidAddress => (
        'Wallet address unavailable',
        'The provider returned an address that does not match a complete Ethereum address. Nothing can be copied.',
        Icons.error_outline_rounded,
        LoopTone.danger,
      ),
      WalletReadinessMode.ready => throw StateError('handled above'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopStateCard(
          title: presentation.$1,
          message: presentation.$2,
          icon: presentation.$3,
          tone: presentation.$4,
          action: onCreate == null
              ? null
              : FilledButton.icon(
                  onPressed: creating ? null : onCreate,
                  icon: creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_card_rounded),
                  label: Text(
                    creating ? 'Creating wallet…' : 'Create embedded wallet',
                  ),
                ),
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: LoopStateCard(
              title: 'Wallet creation not confirmed',
              message: errorMessage!,
              icon: Icons.error_outline_rounded,
              tone: LoopTone.danger,
            ),
          ),
        ],
      ],
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard();

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: LoopTone.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'DEMO PORTFOLIO',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              const LoopStatusPill(label: '演示数据'),
            ],
          ),
          const SizedBox(height: 12),
          Text(r'$31,240.00', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 6),
          Text(
            r'+$844.18 today',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: LoopColors.mint),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              LoopStatusPill(label: 'Ethereum'),
              LoopStatusPill(label: 'Arbitrum'),
              LoopStatusPill(label: 'Solana'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(62),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 20, color: LoopColors.mint),
          const SizedBox(height: 5),
          Text(label),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.symbol,
    required this.name,
    required this.amount,
    required this.value,
    required this.change,
    required this.onTap,
  });

  final String symbol;
  final String name;
  final String amount;
  final String value;
  final String change;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = !change.startsWith('-');
    return ListTile(
      onTap: onTap,
      minTileHeight: 68,
      contentPadding: EdgeInsets.zero,
      leading: LoopAssetMark(symbol: symbol),
      title: Text(name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(amount, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(value, style: context.dataStyle),
          const SizedBox(height: 3),
          Text(
            change,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: positive ? LoopColors.mint : LoopColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Ethereum',
      eyebrow: '开发预览 · ETH · across 2 networks',
      subtitle:
          'Balances and activity below are 演示数据, not a provider projection.',
      children: <Widget>[
        const Row(
          children: <Widget>[
            LoopAssetMark(symbol: 'ETH', size: 52),
            SizedBox(width: 13),
            Expanded(
              child: LoopMetric(
                label: 'HOLDING',
                value: '4.82 ETH',
                detail: r'$22,319.01',
                tone: LoopTone.positive,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'Average cost', value: r'$3,844.20'),
              LoopKeyValueRow(
                label: 'Unrealized PnL',
                value: r'+$3,786.39',
                tone: LoopTone.positive,
              ),
              LoopKeyValueRow(label: 'Ethereum', value: '3.90 ETH'),
              LoopKeyValueRow(label: 'Arbitrum', value: '0.92 ETH', last: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/wallet/send'),
                icon: const Icon(Icons.north_east_rounded),
                label: const Text('Send'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/wallet/receive'),
                icon: const Icon(Icons.south_west_rounded),
                label: const Text('Receive'),
              ),
            ),
          ],
        ),
        const LoopSectionLabel('Activity'),
        const _AssetActivity(
          title: 'Received',
          detail: '+0.40 ETH',
          time: 'Today, 09:18',
          positive: true,
        ),
        const _AssetActivity(
          title: 'Swapped ETH to USDC',
          detail: '-0.12 ETH',
          time: 'Yesterday, 21:44',
        ),
        const _AssetActivity(
          title: 'Sent',
          detail: '-0.08 ETH',
          time: 'Aug 21, 15:02',
        ),
      ],
    );
  }
}

class _AssetActivity extends StatelessWidget {
  const _AssetActivity({
    required this.title,
    required this.detail,
    required this.time,
    this.positive = false,
  });

  final String title;
  final String detail;
  final String time;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 62,
      leading: Icon(
        positive ? Icons.south_west_rounded : Icons.north_east_rounded,
        color: positive ? LoopColors.mint : LoopColors.vapor,
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(time, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Text(
        detail,
        style: context.dataStyle.copyWith(
          color: positive ? LoopColors.mint : LoopColors.chalk,
        ),
      ),
    );
  }
}

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  bool _copying = false;

  @override
  Widget build(BuildContext context) {
    final readiness = WalletReadiness.fromSession(
      ref.watch(loopSessionProvider),
    );
    final address = readiness.ethereumAddress;
    return LoopPage(
      title: 'Receive',
      eyebrow: readiness.canCopy
          ? 'Privy · Embedded Ethereum wallet'
          : 'Wallet address unavailable',
      subtitle: 'This screen can expose the current wallet identity only. No deposit network, asset policy, or QR is enabled.',
      children: <Widget>[
        if (readiness.canCopy)
          LoopCard(
            accent: true,
            tone: LoopTone.positive,
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: LoopColors.mint,
                  size: 52,
                ),
                const SizedBox(height: 18),
                const LoopStatusPill(
                  label: 'PRIVY FACT',
                  tone: LoopTone.positive,
                ),
                const SizedBox(height: 8),
                Text(
                  'Embedded Ethereum wallet',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  address!,
                  key: const ValueKey<String>('receive-wallet-address'),
                  textAlign: TextAlign.center,
                  style: context.dataStyle.copyWith(fontSize: 16),
                  softWrap: true,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _copying ? null : () => _copyAddress(address),
                  icon: _copying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.copy_rounded),
                  label: const Text('Copy full Ethereum wallet address'),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopStateCard(
                title: _receiveUnavailableTitle(readiness.mode),
                message: _receiveUnavailableMessage(readiness.mode),
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('No wallet address to copy'),
              ),
            ],
          ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Receiving is not enabled',
          message: 'A complete wallet address does not prove that LOOP supports deposits on any network or for any asset. No QR code or funding instruction is generated.',
          icon: Icons.info_outline_rounded,
          tone: LoopTone.warning,
        ),
      ],
    );
  }

  Future<void> _copyAddress(String address) async {
    if (_copying) return;
    final current = WalletReadiness.fromSession(ref.read(loopSessionProvider));
    if (!current.canCopy || current.ethereumAddress != address) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: address));
      if (!mounted) return;
      final latest = WalletReadiness.fromSession(ref.read(loopSessionProvider));
      _showMessage(
        latest.canCopy && latest.ethereumAddress == address
            ? 'Wallet address copied.'
            : 'Wallet changed while copying. Check the address before using it.',
      );
    } catch (_) {
      if (mounted) _showMessage('Wallet address was not copied. Try again.');
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _receiveUnavailableTitle(WalletReadinessMode mode) => switch (mode) {
  WalletReadinessMode.needsWallet => 'No embedded wallet yet',
  WalletReadinessMode.preview => 'Unavailable in 开发预览',
  WalletReadinessMode.restricted => 'Verified session required',
  WalletReadinessMode.invalidAddress => 'Wallet address unavailable',
  WalletReadinessMode.ready => throw StateError('ready address handled above'),
};

String _receiveUnavailableMessage(WalletReadinessMode mode) => switch (mode) {
  WalletReadinessMode.needsWallet => 'Create the first Embedded Ethereum wallet from the Wallet tab before an exact address can be shown.',
  WalletReadinessMode.preview =>
    'Offline Preview never exposes a real provider wallet address.',
  WalletReadinessMode.restricted =>
    'Finish Privy verification before reading an embedded wallet address.',
  WalletReadinessMode.invalidAddress => 'The provider value is not a complete Ethereum address, so it remains hidden and cannot be copied.',
  WalletReadinessMode.ready => throw StateError('ready address handled above'),
};
