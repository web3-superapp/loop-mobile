import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

// ---------------------------------------------------------------------------
// MEME v2 project side · copy and shared pieces (S135, decision 0138)
// ---------------------------------------------------------------------------

final Decimal _unit = Decimal.fromBigInt(BigInt.from(10).pow(18));

Decimal launch2Units(BigInt raw) =>
    (Decimal.fromBigInt(raw) / _unit).toDecimal(scaleOnInfinitePrecision: 18);

/// 「10 亿」「8 亿」「500 万」 for a whole-token supply.
String launch2SupplyLabel(BigInt raw) {
  final units = launch2Units(raw);
  final yi = Decimal.fromInt(100000000);
  final wan = Decimal.fromInt(10000);
  if (units >= yi && (units % yi) == Decimal.zero) {
    return '${loopFormatDecimal((units / yi).toDecimal())} 亿';
  }
  if (units >= wan && (units % wan) == Decimal.zero) {
    return '${loopFormatDecimal((units / wan).toDecimal())} 万';
  }
  return loopFormatDecimal(units, maxFractionDigits: 2);
}

String launch2Usd1Label(BigInt raw) =>
    '${loopFormatDecimal(launch2Units(raw), maxFractionDigits: 3)} USD1';

String launch2BpsLabel(int bps) =>
    '${loopFormatDecimal(Decimal.fromInt(bps).shift(-2), maxFractionDigits: 2)}%';

String launch2DurationLabel(int seconds) {
  if (seconds % 86400 == 0) return '${seconds ~/ 86400} 天';
  if (seconds % 3600 == 0) return '${seconds ~/ 3600} 小时';
  return '${seconds ~/ 60} 分钟';
}

/// The BscScan testnet page for one transaction hash on the deployment chain.
String? launch2ExplorerTx(String? hash) =>
    hash == null ? null : 'https://testnet.bscscan.com/tx/$hash';

/// What a refusal of a project-side request means to the owner.
String launch2FailureText(LoopChainException failure) {
  switch (failure.reasonCode) {
    case 'HOOKS_LAUNCH_DISABLED':
      return 'v2 发射暂未开放，开放后这里可以继续。';
    case 'HOOKS_LAUNCH_FACTORY_UNAVAILABLE':
      return '发射工厂暂时不可用（或正在计算地址），稍后再试。';
    case 'HOOKS_CONFIG_NOT_APPROVED':
      return '配置还在等平台审批，审批通过后再签名。';
    case 'HOOKS_SIGNATURE_EXPIRED':
      return '签名请求已过期，续期后重新签名。';
  }
  return switch (failure.kind) {
    LoopChainFailureKind.invalidData =>
      '服务端没有接受这份资料。最常见的原因是 NFT 开售时间太早，'
          '需要给部署和激活留出时间，往后调整后再提交。',
    LoopChainFailureKind.versionConflict => '资料在别处被改过，已重新读取，请确认后再提交。',
    LoopChainFailureKind.idempotencyConflict => '这次提交和上一次内容不同，请重新签名。',
    LoopChainFailureKind.permissionDenied => '当前账号不能执行这一步。',
    LoopChainFailureKind.notFound => '找不到这个项目，它可能不属于当前账号。',
    LoopChainFailureKind.bootstrapRequired => '账号还在初始化，稍后再试。',
    _ => loopChainFailureReason(failure.kind),
  };
}

/// §9.2: one sentence per `failure.code`; an unknown code asks the owner to
/// contact the platform.
String launch2JobFailureText(String code) => switch (code) {
  'HOOKS_SIGNATURE_EXPIRED' => '签名已过期，请重新签名提交。',
  'HOOKS_CONFIG_SUPERSEDED' => '配置已更新，请重新签名。',
  'HOOKS_CONFIG_NOT_APPROVED' => '配置审批已失效，等待平台审批后重新签名。',
  'HOOKS_AUTHORIZATION_INVALID' => '签名无效，请重新签名。',
  'HOOKS_OWNER_NONCE_CONSUMED' => '钱包 nonce 已变化，请重新签名。',
  'HOOKS_LAUNCH_ALREADY_DEPLOYED' => '该版本已在链上部署，请联系平台。',
  'HOOKS_ACTIVATION_WINDOW_CLOSED' => '距开售太近无法激活，修改开售时间后重新提交。',
  'HOOKS_VERIFICATION_MISMATCH' => '部署核验不一致，项目未激活，请联系平台。',
  'HOOKS_EXECUTOR_FUNDS_INSUFFICIENT' ||
  'HOOKS_BROADCAST_REJECTED' ||
  'HOOKS_TX_DROPPED' ||
  'HOOKS_DEPLOY_REVERTED' => '平台处理中，会自动重试。',
  _ => '部署没有完成，请联系平台。',
};

/// The failures the owner answers by signing again (§9.2).
bool launch2JobFailureResignable(String code) => const <String>{
  'HOOKS_SIGNATURE_EXPIRED',
  'HOOKS_CONFIG_SUPERSEDED',
  'HOOKS_AUTHORIZATION_INVALID',
  'HOOKS_OWNER_NONCE_CONSUMED',
}.contains(code);

/// The failure the owner answers by editing the sale time.
bool launch2JobFailureNeedsEdit(String code) =>
    code == 'HOOKS_ACTIVATION_WINDOW_CLOSED';

/// §9.1: the job's own status, in the owner's words.
String launch2JobStatusText(Launch2DeploymentJob job) => switch (job.status) {
  Launch2JobStatus.awaitingExecutor => '排队中',
  Launch2JobStatus.claimed => '准备部署',
  Launch2JobStatus.broadcast =>
    job.confirmations == null ? '已上链，等待确认' : '已上链，${job.confirmations} 确认',
  Launch2JobStatus.confirmed => '核验中',
  Launch2JobStatus.verified => '激活中',
  Launch2JobStatus.activated => '已激活',
  Launch2JobStatus.failed => job.failure?.retryable == true ? '重试中' : '部署失败',
  Launch2JobStatus.reorged => '链上重组，重新确认中',
  Launch2JobStatus.cancelled => '已取消',
};

/// §9.3: the seven events of a successful run have their own line; every
/// other kind reads generically, and nothing depends on `included`.
String launch2EventTitle(Launch2JobEvent event) => switch (event.kind) {
  'created' => '已验签登记',
  'claimed' || 'retry_claimed' => '执行器已认领',
  'broadcast' || 'rebroadcast' => '部署交易已广播',
  'included' => '交易已打包',
  'confirmed' => '部署已确认',
  'verified' => '模块核验通过',
  'activation_broadcast' => '激活交易已广播',
  'activation_included' => '激活交易已打包',
  'activated' => '已激活',
  'reorg_detected' || 'reclaimed_after_reorg' => '链上重组，重新确认',
  'failed' => '部署失败',
  'cancelled' => '已取消',
  _ => '状态更新',
};

/// The 44 px step dots of a multi-step page.
class Launch2StepDots extends StatelessWidget {
  const Launch2StepDots({required this.index, required this.labels, super.key});

  final int index;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey<String>('launch2-create-step-${index + 1}'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        14,
      ),
      child: Semantics(
        label: '第 ${index + 1} 步，共 ${labels.length} 步，${labels[index]}',
        excludeSemantics: true,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < labels.length; i += 1) ...<Widget>[
              Container(
                width: i == index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= index ? LoopColors.lime : LoopColors.line2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 6),
            Text(
              '${index + 1} / ${labels.length} · ${labels[index]}',
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fixed template, read-only (S134–S137 §3.1): the page's one large
/// figure is the total supply.
class Launch2TemplateCard extends StatelessWidget {
  const Launch2TemplateCard({
    required this.economics,
    super.key,
    this.fromServer = false,
  });

  final Launch2FixedEconomics economics;

  /// The values are the saved draft's own; otherwise they are the platform
  /// template the server will derive.
  final bool fromServer;

  @override
  Widget build(BuildContext context) {
    final cap = economics.perAddressCapBps;
    final rows = <(String, String)>[
      ('内盘可售', launch2SupplyLabel(economics.curveSaleSupplyRaw)),
      ('毕业储备', launch2Usd1Label(economics.graduationReserveUsd1Raw)),
      ('内盘买卖税', launch2BpsLabel(economics.curveBuyTaxBps)),
      ('外盘买卖税', launch2BpsLabel(economics.officialPoolBuyTaxBps)),
      (
        '单地址累计上限',
        cap == null
            ? launch2SupplyLabel(economics.perAddressLifetimeBuyCapRaw)
            : launch2BpsLabel(cap),
      ),
      ('NFT 价格', launch2Usd1Label(economics.nftPriceUsd1Raw)),
      (
        'NFT 发售期',
        fromServer
            ? launch2DurationLabel(economics.nftSaleDurationSeconds)
            : '由实例决定',
      ),
    ];
    return LoopSurfaceCard(
      key: const ValueKey<String>('launch2-template-card'),
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('总量', style: LoopType.caption.copyWith(color: LoopColors.text3)),
          const SizedBox(height: 2),
          Text(
            launch2SupplyLabel(economics.memeTotalSupplyRaw),
            key: const ValueKey<String>('launch2-template-supply'),
            style: LoopType.figureXl,
          ),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            LoopKeyValue(
              label: label,
              value: value,
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          const SizedBox(height: 6),
          Text(
            '由平台模板固定，不能修改。',
            style: LoopType.captionSm.copyWith(color: LoopColors.text3),
          ),
        ],
      ),
    );
  }
}

/// The five milestones of one project, the status page's one memory point.
class Launch2MilestoneTrack extends StatelessWidget {
  const Launch2MilestoneTrack({required this.status, super.key});

  final Launch2CreatorStatus status;

  @override
  Widget build(BuildContext context) {
    final current = status.milestone;
    final failed = status.isFailure;
    return Semantics(
      label: '进度：${launch2CreatorMilestones[current]}，${status.label}',
      excludeSemantics: true,
      child: Padding(
        key: ValueKey<String>('launch2-milestones-${status.wireName}'),
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          4,
          LoopSpacing.page,
          20,
        ),
        child: Row(
          children: <Widget>[
            for (
              var i = 0;
              i < launch2CreatorMilestones.length;
              i += 1
            ) ...<Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            i < current ||
                                (i == current &&
                                    status == Launch2CreatorStatus.active)
                            ? LoopColors.lime
                            : i == current
                            ? (failed ? LoopColors.danger : LoopColors.lime)
                            : LoopColors.line2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      launch2CreatorMilestones[i],
                      style: LoopType.captionSm.copyWith(
                        color: i <= current
                            ? LoopColors.chalk
                            : LoopColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < launch2CreatorMilestones.length - 1)
                const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

/// A status pill for a row or a header.
class Launch2StatusPill extends StatelessWidget {
  const Launch2StatusPill({required this.status, super.key});

  final Launch2CreatorStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color ground, Color ink) = switch (status) {
      Launch2CreatorStatus.active => (LoopColors.limeSoft, LoopColors.lime),
      Launch2CreatorStatus.rejected || Launch2CreatorStatus.deployFailed => (
        LoopColors.fallSoft,
        LoopColors.fall,
      ),
      _ => (LoopColors.card2, LoopColors.chalk),
    };
    return Container(
      key: ValueKey<String>('launch2-status-${status.wireName}'),
      constraints: const BoxConstraints(minWidth: 72, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label, style: LoopType.label.copyWith(color: ink)),
    );
  }
}

/// A time on the reader's clock, plus how far away it is.
String launch2SaleStartLabel(DateTime start, DateTime now) {
  final local = loopLocalTimestampLabel(start);
  final delta = start.difference(now);
  if (delta.isNegative) return local;
  if (delta.inDays >= 1) return '$local（${delta.inDays} 天后）';
  if (delta.inHours >= 1) return '$local（${delta.inHours} 小时后）';
  return '$local（${delta.inMinutes} 分钟后）';
}
