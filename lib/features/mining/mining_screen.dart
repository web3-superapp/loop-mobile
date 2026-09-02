import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// Truthful UI-first Mining destination.
///
/// Mining is backend delivery D19. Until D10, D12, D18, and D19 provide
/// versioned facts, the app must not estimate power, rank, reward, or claims.
class MiningScreen extends StatelessWidget {
  const MiningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('mining-screen'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: LoopColors.lime,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 9),
            ),
            const SizedBox(width: 8),
            Text(
              'LOOP',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: LoopColors.chalk, letterSpacing: 1.1),
            ),
          ],
        ),
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: ColoredBox(color: LoopColors.ink)),
          SafeArea(
            top: false,
            bottom: false,
            child: CustomScrollView(
              key: const ValueKey<String>('mining-scroll'),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                  sliver: SliverList.list(
                    children: <Widget>[
                      Text(
                        'MINING / D19',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: LoopColors.lime,
                              letterSpacing: 1.7,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        header: true,
                        child: Text(
                          '我的挖矿',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '算力、排行、奖励与五级邀请属于后端 D19。权威公式和快照未交付前，客户端不进行本地估算。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      const _MiningUnavailableHero(),
                      const SizedBox(height: 30),
                      Text(
                        'DELIVERY DEPENDENCIES',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      const _DependencyLedger(),
                      const SizedBox(height: 16),
                      const _MiningTruthNotice(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiningUnavailableHero extends StatelessWidget {
  const _MiningUnavailableHero();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '挖矿功能未开放，没有算力、排行或奖励数据',
      child: DecoratedBox(
        key: const ValueKey<String>('mining-unavailable'),
        decoration: const BoxDecoration(
          color: LoopColors.lime,
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    'MINING POWER',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: LoopColors.ink.withValues(alpha: 0.68),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const _MiningStatusPill(),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '尚未开放',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: LoopColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '当前没有可验证的算力、收益、待领取奖励、排名或邀请加成。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: LoopColors.ink.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0x33050604)),
              const SizedBox(height: 14),
              Text(
                'NO POWER · NO REWARD · NO CLAIM',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: LoopColors.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiningStatusPill extends StatelessWidget {
  const _MiningStatusPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LoopColors.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'D19 · UNAVAILABLE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: LoopColors.lime,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _DependencyLedger extends StatelessWidget {
  const _DependencyLedger();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('mining-dependency-ledger'),
      decoration: BoxDecoration(
        color: LoopColors.graphite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LoopColors.chalk.withValues(alpha: 0.12)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        child: Column(
          children: <Widget>[
            _DependencyRow(step: '01', module: 'D10', title: 'BSC 资产注册与索引'),
            _DependencyRow(step: '02', module: 'D12', title: '钱包余额与快照证据'),
            _DependencyRow(
              step: '03',
              module: 'D18',
              title: 'Launch 链上参与与奖励依据',
            ),
            _DependencyRow(
              step: '04',
              module: 'D19',
              title: '算力、排行、奖励与邀请公式',
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _DependencyRow extends StatelessWidget {
  const _DependencyRow({
    required this.step,
    required this.module,
    required this.title,
    this.showDivider = true,
  });

  final String step;
  final String module;
  final String title;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 26,
                child: Text(
                  step,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: LoopColors.muted, letterSpacing: 0.8),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      module,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: LoopColors.lime,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '待交付',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: LoopColors.chalk.withValues(alpha: 0.48)),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(color: LoopColors.chalk.withValues(alpha: 0.1), height: 1),
      ],
    );
  }
}

class _MiningTruthNotice extends StatelessWidget {
  const _MiningTruthNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LoopColors.lime.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LoopColors.lime.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.lock_outline_rounded, color: LoopColors.lime),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '此页面不会发起请求，也不会在本地累计积分、估算收益或创建领取操作。缺少或过期的价格与快照必须保持不可用。',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: LoopColors.chalk.withValues(alpha: 0.72)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
