import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class LaunchpadScreen extends StatelessWidget {
  const LaunchpadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compactContextRail = MediaQuery.textScalerOf(context).scale(10) > 15;
    return LoopPage(
      title: 'Launchpad',
      eyebrow: 'Reserved destination',
      subtitle: 'Launchpad remains a primary LOOP destination, while project discovery and participation stay outside this release.',
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: LoopContextRail(
            stage: LoopStage.discover,
            compact: compactContextRail,
          ),
        ),
        const SizedBox(height: 22),
        LoopCard(
          accent: true,
          tone: LoopTone.market,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LoopColors.market.withValues(alpha: 0.12),
                  borderRadius: LoopRadius.small,
                ),
                child: const Icon(
                  Icons.rocket_launch_outlined,
                  color: LoopColors.market,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Coming later',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This tab keeps the planned product position visible. No project source, eligibility service or wallet participation flow is connected.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Required before launch data can appear'),
        const _LaunchGate(
          number: '01',
          title: 'Issuer and contract facts',
          detail: 'Ownership, vesting and source timestamps need a reviewed authority and freshness policy.',
        ),
        const _LaunchGate(
          number: '02',
          title: 'Eligibility controls',
          detail: 'Region and account checks need an explicit policy source and a fail-closed result.',
        ),
        const _LaunchGate(
          number: '03',
          title: 'Participation review',
          detail: 'Amount, allocation and settlement would require one backend-mediated canonical intent.',
        ),
        const SizedBox(height: 18),
        const LoopStateCard(
          key: ValueKey<String>('launchpad-unavailable'),
          title: 'Launchpad not connected',
          message: 'Project lists, details, applications, allocations, funding, signing and claims are unavailable in this release. This page does not accept funds or submit any request.',
          icon: Icons.lock_clock_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _LaunchGate extends StatelessWidget {
  const _LaunchGate({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LoopColors.elevated,
              shape: BoxShape.circle,
              border: Border.all(color: LoopColors.line),
            ),
            child: Text(
              number,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: LoopColors.vapor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  'NOT CONNECTED',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: LoopColors.warning, letterSpacing: 0.9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
