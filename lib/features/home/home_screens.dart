import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/preview_conversation_identity.dart';
import 'package:loop_mobile/features/wallet/wallet_readiness.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateway = ref.watch(communicationGatewayProvider);
    final session = ref.watch(loopSessionProvider);
    final isSessionPreview = session.isPreview;
    final communicationPreview = gateway.mode == CommunicationMode.preview;
    final communicationStatus = communicationPreview
        ? 'Offline preview · not connected'
        : gateway.isConfigured
        ? 'Stream configured · open Chat to check authorization'
        : 'Stream not connected';
    return LoopPage(
      title: 'Home overview',
      eyebrow: isSessionPreview ? '开发预览 · gm, Voyager 7' : 'LOOP',
      subtitle: isSessionPreview
          ? 'Static portfolio and activity cards demonstrate layout; they are not account facts.'
          : 'Only current provider availability is shown. Missing portfolio and activity sources stay unavailable.',
      actions: <Widget>[
        IconButton(
          onPressed: () => context.push('/search'),
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          onPressed: () => context.push('/notifications'),
          tooltip: 'Notifications',
          icon: isSessionPreview
              ? const Badge(
                  key: ValueKey<String>('notifications-preview-badge'),
                  smallSize: 7,
                  backgroundColor: LoopColors.danger,
                  child: Icon(Icons.notifications_none_rounded),
                )
              : const Icon(
                  Icons.notifications_none_rounded,
                  key: ValueKey<String>('notifications-production-icon'),
                ),
        ),
        const SizedBox(width: 4),
      ],
      children: <Widget>[
        if (isSessionPreview)
          _HomePreviewContent(communicationStatus: communicationStatus)
        else
          _HomeProductionContent(
            walletReadiness: WalletReadiness.fromSession(session),
            communicationStatus: communicationStatus,
          ),
      ],
    );
  }
}

class _HomeProductionContent extends StatelessWidget {
  const _HomeProductionContent({
    required this.walletReadiness,
    required this.communicationStatus,
  });

  final WalletReadiness walletReadiness;
  final String communicationStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('home-production-truth-boundary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopStateCard(
          title: 'Provider facts only',
          message: 'LOOP has no connected portfolio or cross-product activity source. No balance, change, alert, unread count, approval, or all-clear state is inferred.',
          icon: Icons.verified_outlined,
          tone: LoopTone.warning,
        ),
        const SizedBox(height: 16),
        _PortfolioUnavailableHero(
          readiness: walletReadiness,
          onTap: () => context.push('/home/net-worth'),
        ),
        const LoopSectionLabel('Pay'),
        _PayComingSoonCard(onTap: () => context.push('/pay')),
        const LoopSectionLabel('Continue the loop'),
        _LoopStep(
          key: const ValueKey<String>('home-open-public-market'),
          number: '01',
          icon: Icons.radar_rounded,
          title: 'Discover',
          body: 'Browse public Hyperliquid Testnet Spot markets.',
          meta: 'Public read-only',
          tone: LoopTone.market,
          onTap: () => context.go('/market'),
        ),
        const SizedBox(height: 10),
        _LoopStep(
          number: '02',
          icon: Icons.forum_outlined,
          title: 'Discuss',
          body: 'Open Chat to check the current Stream authorization state.',
          meta: 'Check status',
          tone: LoopTone.conversation,
          onTap: () => context.go('/chat'),
        ),
        const SizedBox(height: 10),
        _LoopStep(
          number: '03',
          icon: Icons.account_balance_wallet_outlined,
          title: 'Wallet',
          body: 'Review the current Privy embedded-wallet identity state.',
          meta: 'Check status',
          tone: LoopTone.positive,
          onTap: () => context.go('/wallet'),
        ),
        const LoopSectionLabel('Communication'),
        _CommunicationStatusCard(
          preview: false,
          status: communicationStatus,
          onTap: () => context.push('/chat/voice'),
        ),
        const LoopSectionLabel('Activity'),
        const LoopStateCard(
          key: ValueKey<String>('home-production-activity-unavailable'),
          title: 'Activity not connected',
          message: 'No portfolio, notification, wallet approval, or conversation activity source was loaded. Open each destination to inspect its own current status.',
          icon: Icons.inbox_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _HomePreviewContent extends StatelessWidget {
  const _HomePreviewContent({required this.communicationStatus});

  final String communicationStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('home-preview-fixtures'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopStateCard(
          title: '开发预览',
          message: 'Balances, alerts, unread counts and activity below are 演示数据. Provider-backed sections identify their own connection state.',
          icon: Icons.visibility_outlined,
          tone: LoopTone.warning,
        ),
        const SizedBox(height: 14),
        const SingleChildScrollView(
          key: ValueKey<String>('home-preview-loop-stage-scroll'),
          scrollDirection: Axis.horizontal,
          child: Align(
            alignment: Alignment.centerLeft,
            child: LoopContextRail(stage: LoopStage.discover),
          ),
        ),
        const SizedBox(height: 24),
        _PortfolioHero(onTap: () => context.push('/home/net-worth')),
        const LoopSectionLabel('Pay'),
        _PayComingSoonCard(onTap: () => context.push('/pay')),
        const LoopSectionLabel('Continue the loop'),
        _LoopStep(
          number: '01',
          icon: Icons.radar_rounded,
          title: 'Discover',
          body: 'ETH spot volume rose while BTC held its weekly range.',
          meta: '3 watchlist moves',
          tone: LoopTone.market,
          onTap: () => context.go('/market'),
        ),
        const SizedBox(height: 10),
        _LoopStep(
          number: '02',
          icon: Icons.forum_outlined,
          title: 'Discuss',
          body: 'Glyph Hunters is comparing this week’s spot market structure.',
          meta: '18 unread',
          tone: LoopTone.conversation,
          onTap: () => context.go('/chat'),
        ),
        const SizedBox(height: 10),
        _LoopStep(
          number: '03',
          icon: Icons.account_balance_wallet_outlined,
          title: 'Execute',
          body: 'Your wallet has one approval worth reviewing.',
          meta: 'Wallet ready',
          tone: LoopTone.positive,
          onTap: () => context.go('/wallet'),
        ),
        const LoopSectionLabel('Communication preview'),
        _CommunicationStatusCard(
          preview: true,
          status: communicationStatus,
          onTap: () => context.push('/chat/voice'),
        ),
        const LoopSectionLabel('Today · 演示数据'),
        _ActivityRow(
          icon: Icons.show_chart_rounded,
          color: LoopColors.market,
          title: 'ETH moved above your alert',
          subtitle: r'$4,630.50 · source refreshed 12s ago',
          time: '2m',
          onTap: () => context.go('/market'),
        ),
        _ActivityRow(
          icon: Icons.shield_outlined,
          color: LoopColors.warning,
          title: 'One approval can spend your USDC',
          subtitle: 'Review the app and exact allowance',
          time: '1h',
          onTap: () => context.push('/home/security'),
        ),
      ],
    );
  }
}

class _PortfolioUnavailableHero extends StatelessWidget {
  const _PortfolioUnavailableHero({
    required this.readiness,
    required this.onTap,
  });

  final WalletReadiness readiness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = readiness.mode == WalletReadinessMode.restricted
        ? 'Portfolio unavailable in restricted session'
        : 'Portfolio data not connected';
    final identityLabel = switch (readiness.mode) {
      WalletReadinessMode.ready => 'Wallet identity available',
      WalletReadinessMode.needsWallet => 'No wallet identity',
      WalletReadinessMode.restricted => 'Restricted session',
      WalletReadinessMode.invalidAddress => 'Wallet identity invalid',
      WalletReadinessMode.preview => 'Preview unavailable',
    };
    final message = switch (readiness.mode) {
      WalletReadinessMode.ready => 'A verified Privy wallet identity exists for this session, but no balance or asset source is connected. LOOP cannot calculate net worth.',
      WalletReadinessMode.needsWallet => 'This verified Privy session has no embedded wallet identity. No balance or portfolio request was made.',
      WalletReadinessMode.restricted => 'The cached session is not verified for provider-backed wallet identity. No balance or portfolio request was made.',
      WalletReadinessMode.invalidAddress => 'The current wallet identity is incomplete or invalid. No balance or portfolio request was made.',
      WalletReadinessMode.preview =>
        'Preview identity cannot authorize a production portfolio request.',
    };
    return LoopCard(
      key: const ValueKey<String>('home-open-net-worth'),
      onTap: onTap,
      semanticLabel: '$title. $message. Open net worth availability.',
      accent: true,
      tone: LoopTone.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              _HomeStatusLabel(
                key: const ValueKey<String>('home-wallet-identity-status'),
                label: identityLabel,
                tone: LoopTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.chevron_right_rounded, color: LoopColors.vapor),
          ),
        ],
      ),
    );
  }
}

class _PayComingSoonCard extends StatelessWidget {
  const _PayComingSoonCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      key: const ValueKey<String>('home-pay-coming-soon'),
      onTap: onTap,
      semanticLabel: 'Open the Pay coming soon notice',
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LoopColors.vapor.withValues(alpha: 0.08),
              borderRadius: LoopRadius.small,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: LoopColors.vapor,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text('Pay', style: Theme.of(context).textTheme.titleMedium),
                    const _HomeStatusLabel(label: 'Coming soon'),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'A priority · Delivery status: Deferred',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: LoopColors.vapor),
        ],
      ),
    );
  }
}

class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      key: const ValueKey<String>('home-open-net-worth'),
      onTap: onTap,
      semanticLabel: 'Open net worth details',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'TOTAL NET WORTH',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const _HomeStatusLabel(
                label: '+2.6% today',
                tone: LoopTone.positive,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(r'$46,806.55', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 16),
          const LoopMiniChart(
            points: <double>[18, 19, 17.8, 20.3, 21, 20.5, 23, 22.7, 24.8, 26],
            height: 62,
            semanticLabel: 'Net worth increased 2.6 percent today',
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 24,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 132,
                child: LoopMetric(label: 'WALLET', value: r'$31,240'),
              ),
              SizedBox(
                width: 150,
                child: LoopMetric(label: 'STABLECOINS', value: r'$15,566'),
              ),
              Icon(Icons.chevron_right_rounded, color: LoopColors.vapor),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopStep extends StatelessWidget {
  const _LoopStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    required this.meta,
    required this.tone,
    required this.onTap,
    super.key,
  });

  final String number;
  final IconData icon;
  final String title;
  final String body;
  final String meta;
  final LoopTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = loopToneColor(tone);
    return LoopCard(
      onTap: onTap,
      tone: tone,
      accent: true,
      semanticLabel: '$title. $body',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 35,
            child: Column(
              children: <Widget>[
                Text(
                  number,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: color),
                ),
                const SizedBox(height: 8),
                Icon(icon, size: 20, color: color),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeStatusLabel extends StatelessWidget {
  const _HomeStatusLabel({
    required this.label,
    super.key,
    this.tone = LoopTone.neutral,
  });

  final String label;
  final LoopTone tone;

  @override
  Widget build(BuildContext context) {
    final color = loopToneColor(tone);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: LoopRadius.pill,
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

class _CommunicationStatusCard extends StatelessWidget {
  const _CommunicationStatusCard({
    required this.preview,
    required this.status,
    required this.onTap,
  });

  final bool preview;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = preview ? 'ETH Macro Room' : 'Audio Room';
    return LoopCard(
      accent: true,
      tone: LoopTone.conversation,
      onTap: onTap,
      semanticLabel: preview
          ? 'Open the offline ETH Macro Room voice preview'
          : 'Open Audio Room connection status',
      child: Row(
        children: <Widget>[
          const _VoicePreviewGlyph(),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(status, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: LoopColors.vapor),
        ],
      ),
    );
  }
}

class _VoicePreviewGlyph extends StatelessWidget {
  const _VoicePreviewGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.chat.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.graphic_eq_rounded, color: LoopColors.chat),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: LoopRadius.small,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: LoopRadius.small,
                  color: color.withValues(alpha: 0.1),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(time, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(loopSessionProvider);
    if (!session.isPreview) {
      final readiness = WalletReadiness.fromSession(session);
      return LoopPage(
        title: 'Net worth',
        eyebrow: 'Portfolio',
        subtitle: 'No balance, asset, allocation, history, or PnL source is connected.',
        children: <Widget>[
          LoopStateCard(
            key: const ValueKey<String>('net-worth-production-unavailable'),
            title: 'Net worth not connected',
            message: _netWorthUnavailableMessage(readiness),
            icon: Icons.account_balance_wallet_outlined,
            tone: LoopTone.warning,
          ),
          const SizedBox(height: 14),
          const LoopStateCard(
            key: ValueKey<String>('net-worth-production-content-end'),
            title: 'No portfolio request was made',
            message: 'LOOP will not synthesize a total from wallet identity, public market prices, Preview assets, or another account. A future owner-scoped portfolio source must provide its own freshness and attribution.',
            icon: Icons.data_usage_outlined,
          ),
        ],
      );
    }

    return LoopPage(
      title: 'Net worth',
      eyebrow: '开发预览 · Portfolio',
      subtitle: 'The static allocation below is 演示数据 and is not a provider-backed account total.',
      children: <Widget>[
        const LoopStateCard(
          key: ValueKey<String>('net-worth-preview-fixtures'),
          title: '开发预览 · 演示数据',
          message: 'No wallet balance, trading account, allocation, history, or PnL request produced these values.',
          icon: Icons.visibility_outlined,
          tone: LoopTone.warning,
        ),
        const SizedBox(height: 14),
        const LoopCard(
          accent: true,
          tone: LoopTone.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LoopMetric(
                label: 'TOTAL',
                value: r'$46,806.55',
                detail: r'+$1,186.40 today',
                tone: LoopTone.positive,
              ),
              SizedBox(height: 18),
              LoopMiniChart(
                points: <double>[12, 16, 14, 19, 22, 21, 25, 24, 29, 31],
                height: 130,
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Allocation · 演示数据'),
        const LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'Ethereum wallets', value: r'$24,844.20'),
              LoopKeyValueRow(label: 'Solana wallets', value: r'$6,396.10'),
              LoopKeyValueRow(
                label: 'Stablecoin assets',
                value: r'$15,566.25',
                last: true,
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Data status'),
        const LoopStateCard(
          key: ValueKey<String>('net-worth-preview-content-end'),
          title: 'Development preview only',
          message: 'All values on this development preview are static wallet fixtures, not refreshed provider facts.',
          icon: Icons.cloud_off_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

String _netWorthUnavailableMessage(WalletReadiness readiness) {
  return switch (readiness.mode) {
    WalletReadinessMode.ready => 'A verified Privy wallet identity is available for this session, but identity alone cannot prove balances or calculate a portfolio total.',
    WalletReadinessMode.needsWallet => 'This verified Privy session has no embedded wallet identity. It also has no connected balance or asset source.',
    WalletReadinessMode.restricted => 'The current cached session is restricted and cannot establish provider-backed wallet identity or portfolio facts.',
    WalletReadinessMode.invalidAddress => 'The current wallet identity is incomplete or invalid, and no portfolio facts are available.',
    WalletReadinessMode.preview =>
      'Preview identity cannot authorize a production portfolio request.',
  };
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPreview = ref.watch(
      loopSessionProvider.select((session) => session.isPreview),
    );
    if (!isPreview) {
      return const LoopPage(
        title: 'Notifications',
        subtitle: 'Provider-backed updates will appear here after notification delivery is configured.',
        children: <Widget>[
          LoopStateCard(
            key: ValueKey<String>('notifications-provider-unavailable'),
            title: 'Notifications not connected',
            message: 'The centralized Firebase and Stream ingress is not connected yet. LOOP is not showing fixture alerts, badges, or read state in this production session.',
            icon: Icons.notifications_off_outlined,
            tone: LoopTone.warning,
          ),
        ],
      );
    }

    return LoopPage(
      title: 'Notifications',
      eyebrow: '开发预览',
      subtitle: 'The cards below are 演示数据. They do not represent provider delivery, read state, or account activity.',
      children: <Widget>[
        const LoopStateCard(
          key: ValueKey<String>('notifications-preview-fixtures'),
          title: '开发预览',
          message: 'Notification fixtures are local and have no effect on Stream, Firebase, wallets, or trading.',
          icon: Icons.visibility_outlined,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('New · 演示数据'),
        _NotificationCard(
          tone: LoopTone.market,
          icon: Icons.show_chart_rounded,
          title: r'ETH crossed $4,600',
          body: 'Your price alert triggered once. The alert is now paused.',
          time: '8m',
          onTap: () => context.go('/market'),
        ),
        const LoopSectionLabel('Earlier · 演示数据'),
        _NotificationCard(
          tone: LoopTone.conversation,
          icon: Icons.alternate_email_rounded,
          title: 'Mentioned in Glyph Hunters',
          body: 'NightOwl mentioned your alias in a reply.',
          time: '2h',
          onTap: () => context.push(PreviewConversationIdentity.group.location),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.onTap,
  });

  final LoopTone tone;
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      onTap: onTap,
      accent: true,
      tone: tone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: loopToneColor(tone), size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(time, style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 5),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPreview = ref.watch(
      loopSessionProvider.select(
        (session) => session.mode == LoopSessionMode.preview,
      ),
    );
    if (!isPreview) {
      return const LoopPage(
        title: 'Search',
        subtitle: 'Provider-backed search will appear here after its asset, community and account sources are connected.',
        children: <Widget>[
          LoopStateCard(
            key: ValueKey<String>('global-search-provider-unavailable'),
            title: 'Search not connected',
            message: 'LOOP has no production cross-product search index yet. Preview assets, groups and people are not shown in this session.',
            icon: Icons.search_off_rounded,
            tone: LoopTone.warning,
          ),
        ],
      );
    }

    final targets = <_PreviewSearchTarget>[
      const _PreviewSearchTarget(
        key: ValueKey<String>('global-search-preview-eth'),
        icon: Icons.currency_bitcoin,
        tone: LoopTone.market,
        title: 'ETH',
        subtitle: 'Spot asset example · opens public Testnet markets',
        searchTerms: <String>[
          'eth',
          'ethereum',
          'spot',
          'asset',
          'token',
          'market',
        ],
        location: '/market',
        replacesLocation: true,
      ),
      _PreviewSearchTarget(
        key: const ValueKey<String>('global-search-preview-group'),
        icon: Icons.forum_outlined,
        tone: LoopTone.conversation,
        title: PreviewConversationIdentity.group.title,
        subtitle: 'Group · offline conversation preview · 演示数据',
        searchTerms: const <String>['glyph', 'hunters', 'group', 'community'],
        location: PreviewConversationIdentity.group.location,
      ),
      _PreviewSearchTarget(
        key: const ValueKey<String>('global-search-preview-person'),
        icon: Icons.person_outline_rounded,
        tone: LoopTone.conversation,
        title: PreviewConversationIdentity.direct.title,
        subtitle: 'Person · offline conversation preview · 演示数据',
        searchTerms: const <String>['0xsable', 'sable', 'person', 'direct'],
        location: PreviewConversationIdentity.direct.location,
      ),
    ];
    final queryTokens = controller.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final matches = targets
        .where((target) => target.matchesEvery(queryTokens))
        .toList(growable: false);

    return LoopPage(
      title: 'Search',
      eyebrow: '开发预览',
      subtitle: 'Filter a bounded set of local 演示数据 for spot assets, groups and people. No provider or account search runs here.',
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('global-search-preview-input'),
          controller: controller,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Try ETH or Glyph Hunters',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(controller.clear),
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const LoopStateCard(
          key: ValueKey<String>('global-search-preview-fixtures'),
          title: '开发预览',
          message: 'These local suggestions are 演示数据. They do not come from Stream, a user directory, an account index or a live asset search.',
          icon: Icons.science_outlined,
          tone: LoopTone.warning,
        ),
        LoopSectionLabel(
          queryTokens.isEmpty ? 'Suggested · 演示数据' : 'Results · 演示数据',
        ),
        if (matches.isEmpty)
          const LoopStateCard(
            key: ValueKey<String>('global-search-preview-empty'),
            title: 'No local preview matches',
            message: 'Try ETH, Glyph Hunters or 0xSable. No provider search was performed.',
            icon: Icons.search_off_rounded,
          )
        else
          for (final target in matches)
            _SearchResult(
              key: target.key,
              icon: target.icon,
              tone: target.tone,
              title: target.title,
              subtitle: target.subtitle,
              onTap: () => target.replacesLocation
                  ? context.go(target.location)
                  : context.push(target.location),
            ),
      ],
    );
  }
}

class _PreviewSearchTarget {
  const _PreviewSearchTarget({
    required this.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.searchTerms,
    required this.location,
    this.replacesLocation = false,
  });

  final Key key;
  final IconData icon;
  final LoopTone tone;
  final String title;
  final String subtitle;
  final List<String> searchTerms;
  final String location;
  final bool replacesLocation;

  bool matchesEvery(List<String> queryTokens) {
    if (queryTokens.isEmpty) return true;
    final searchable = <String>[title, ...searchTerms].join(' ').toLowerCase();
    return queryTokens.every(searchable.contains);
  }
}

class _SearchResult extends StatelessWidget {
  const _SearchResult({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final LoopTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minTileHeight: 62,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: loopToneColor(tone).withValues(alpha: 0.1),
          borderRadius: LoopRadius.small,
        ),
        child: Icon(icon, color: loopToneColor(tone), size: 20),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: LoopColors.vapor,
      ),
    );
  }
}

class SecurityActivityScreen extends ConsumerWidget {
  const SecurityActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPreview = ref.watch(
      loopSessionProvider.select(
        (session) => session.mode == LoopSessionMode.preview,
      ),
    );
    if (!isPreview) {
      return const LoopPage(
        title: 'Security activity',
        subtitle: 'Verified wallet policy and account events will appear here after a source is connected.',
        children: <Widget>[
          LoopStateCard(
            key: ValueKey<String>('security-activity-provider-unavailable'),
            title: 'Security activity not connected',
            message: 'LOOP has no verified account or wallet event source for this page. It will not infer MFA, device, approval or risk status from missing data.',
            icon: Icons.shield_outlined,
            tone: LoopTone.warning,
          ),
        ],
      );
    }

    return const LoopPage(
      title: 'Security activity',
      eyebrow: '开发预览',
      subtitle: 'The examples below are 演示数据 for layout only. They are not wallet, Privy, device or account facts.',
      children: <Widget>[
        LoopStateCard(
          key: ValueKey<String>('security-activity-preview-fixtures'),
          title: '开发预览',
          message: 'No provider was queried and no risk score, safety conclusion or account action is available.',
          icon: Icons.visibility_outlined,
          tone: LoopTone.warning,
        ),
        LoopStateCard(
          title: 'Example summary · 演示数据',
          message: 'Sample layout only. The placeholder policy and device rows below are not your account status.',
          icon: Icons.verified_user_outlined,
          tone: LoopTone.warning,
        ),
        LoopSectionLabel('Example week · 演示数据'),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'Unlimited approval blocked',
                value: '1',
                tone: LoopTone.warning,
              ),
              LoopKeyValueRow(label: 'New recipients reviewed', value: '2'),
              LoopKeyValueRow(
                label: 'New device sessions',
                value: '0',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
