import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';

// ---------------------------------------------------------------------------
// MEME v2 · project side (S135, client decision 0138)
// ---------------------------------------------------------------------------
//
// The project side has no route of its own in `launch2` (loop-api decision
// 0114 keeps 资料 → 审核 → 签名 → 部署 → 激活 on the S125 Hooks routes):
//
// - the project itself is the Launch catalogue project (`/v2/launch/projects`,
//   its `reviewStatus` is the platform review);
// - the launch configuration is the Hooks draft on that project
//   (`hooks-config`, a CAS-versioned, server-derived template);
// - signing is `hooks-config/signing-request` → EIP-712 → `hooks-deployments`;
// - the deployment job carries the executor's progress.
//
// [Launch2CreatorStatus] is projected from those three server facts and
// nothing else; the App never advances it on its own.

/// The ten project states the design names (S134–S137 §1).
enum Launch2CreatorStatus {
  draft('draft', '草稿'),
  awaitingApproval('awaiting_approval', '审核中'),
  approved('approved', '待签名'),
  signing('signing', '签名中'),
  deploying('deploying', '部署中'),
  deployed('deployed', '已上链'),
  verified('verified', '激活中'),
  active('active', '已激活'),
  rejected('rejected', '未通过'),
  deployFailed('deploy_failed', '部署失败');

  const Launch2CreatorStatus(this.wireName, this.label);

  /// The design document's own name for the state.
  final String wireName;
  final String label;

  /// The five milestones the status page draws, and where this state sits.
  int get milestone => switch (this) {
    Launch2CreatorStatus.draft => 0,
    Launch2CreatorStatus.awaitingApproval || Launch2CreatorStatus.rejected => 1,
    Launch2CreatorStatus.approved || Launch2CreatorStatus.signing => 2,
    Launch2CreatorStatus.deploying ||
    Launch2CreatorStatus.deployed ||
    Launch2CreatorStatus.verified ||
    Launch2CreatorStatus.deployFailed => 3,
    Launch2CreatorStatus.active => 4,
  };

  bool get isFailure =>
      this == Launch2CreatorStatus.rejected ||
      this == Launch2CreatorStatus.deployFailed;
}

/// The milestone names, in order.
const List<String> launch2CreatorMilestones = <String>[
  '资料',
  '审核',
  '签名',
  '部署',
  '激活',
];

/// The fixed economics of one Hooks draft (`config.fixedEconomics`).
///
/// Every value is the server's; the App only formats it. `*Raw` amounts are
/// 18-decimal integers.
@immutable
final class Launch2FixedEconomics {
  const Launch2FixedEconomics({
    required this.templateChainId,
    required this.memeTotalSupplyRaw,
    required this.curveSaleSupplyRaw,
    required this.initialLiquiditySupplyRaw,
    required this.graduationReserveUsd1Raw,
    required this.nftPriceUsd1Raw,
    required this.nftSaleDurationSeconds,
    required this.earlyRoundDurationSeconds,
    required this.perAddressLifetimeBuyCapRaw,
    required this.curveBuyTaxBps,
    required this.curveSellTaxBps,
    required this.officialPoolBuyTaxBps,
    required this.officialPoolSellTaxBps,
    required this.lpFee,
    required this.tickSpacing,
    required this.buybackOrderUsd1Raw,
    required this.buybackMinIntervalSeconds,
  });

  /// The template's own `chainId` (always `56`, part of the config hash). It
  /// is **not** the deployment chain (decision 0117) and is never shown as
  /// one.
  final String templateChainId;
  final BigInt memeTotalSupplyRaw;
  final BigInt curveSaleSupplyRaw;
  final BigInt initialLiquiditySupplyRaw;
  final BigInt graduationReserveUsd1Raw;
  final BigInt nftPriceUsd1Raw;
  final int nftSaleDurationSeconds;
  final int earlyRoundDurationSeconds;
  final BigInt perAddressLifetimeBuyCapRaw;
  final int curveBuyTaxBps;
  final int curveSellTaxBps;
  final int officialPoolBuyTaxBps;
  final int officialPoolSellTaxBps;
  final int lpFee;
  final int tickSpacing;
  final BigInt buybackOrderUsd1Raw;
  final int buybackMinIntervalSeconds;

  /// The per-address cap as basis points of the total supply.
  int? get perAddressCapBps => memeTotalSupplyRaw == BigInt.zero
      ? null
      : (perAddressLifetimeBuyCapRaw * BigInt.from(10000) ~/ memeTotalSupplyRaw)
            .toInt();
}

/// The template the create page shows before a draft exists.
///
/// `hooks_launch_v1` is fixed by the platform (loop-api decision 0108); the
/// server derives the same numbers when the draft is saved, and once a draft
/// exists the page shows the server's own values instead of these.
abstract final class Launch2Template {
  static const String version = 'hooks_launch_v1';
  static final BigInt _unit = BigInt.from(10).pow(18);

  static final Launch2FixedEconomics v1 = Launch2FixedEconomics(
    templateChainId: '56',
    memeTotalSupplyRaw: BigInt.from(1000000000) * _unit,
    curveSaleSupplyRaw: BigInt.from(800000000) * _unit,
    initialLiquiditySupplyRaw: BigInt.from(200000000) * _unit,
    graduationReserveUsd1Raw:
        BigInt.from(133333332) * _unit ~/ BigInt.from(1000),
    nftPriceUsd1Raw: BigInt.from(100) * _unit,
    nftSaleDurationSeconds: 604800,
    earlyRoundDurationSeconds: 3600,
    perAddressLifetimeBuyCapRaw: BigInt.from(5000000) * _unit,
    curveBuyTaxBps: 1000,
    curveSellTaxBps: 1000,
    officialPoolBuyTaxBps: 200,
    officialPoolSellTaxBps: 200,
    lpFee: 2500,
    tickSpacing: 60,
    buybackOrderUsd1Raw: BigInt.from(100) * _unit,
    buybackMinIntervalSeconds: 10,
  );

  /// The address the requirer's plan names as the default buyback recipient.
  static const String defaultBuybackRecipient =
      '0x28816c4C4792467390C90e5B426F198570E29307';

  /// The contract's own floor for the sale lead: the activation buffer
  /// (3,600 s) plus the executor margin (600 s). The server's configured lead
  /// is at least this and usually far more (production 86,400 s); it is not
  /// published, so the page offers nothing earlier than this floor and lets
  /// the server's `400` decide the rest (decision 0138).
  static const Duration contractMinimumSaleLead = Duration(seconds: 4200);

  /// What the picker proposes first: two days out, comfortably past every
  /// configured lead.
  static const Duration suggestedSaleLead = Duration(days: 2);
}

/// One saved Hooks draft (`GET`/`PUT …/hooks-config`).
@immutable
final class Launch2HooksDraft {
  const Launch2HooksDraft({
    required this.projectId,
    required this.version,
    required this.templateVersion,
    required this.templateHash,
    required this.name,
    required this.ticker,
    required this.logoAssetUrl,
    required this.description,
    required this.links,
    required this.nftSaleStartAt,
    required this.buybackRecipient,
    required this.economics,
    required this.configHash,
    required this.updatedAt,
  });

  final String projectId;
  final int version;
  final String templateVersion;
  final String templateHash;
  final String name;
  final String ticker;
  final String logoAssetUrl;
  final String description;
  final List<String> links;

  /// Unix seconds, as the server stores it.
  final BigInt nftSaleStartAt;
  final String buybackRecipient;
  final Launch2FixedEconomics economics;
  final String configHash;
  final DateTime updatedAt;

  DateTime get nftSaleStart => DateTime.fromMillisecondsSinceEpoch(
    nftSaleStartAt.toInt() * 1000,
    isUtc: true,
  );
}

/// What the owner typed for one Hooks draft (`PUT …/hooks-config` `config`).
@immutable
final class Launch2ConfigInput {
  const Launch2ConfigInput({
    required this.name,
    required this.ticker,
    required this.logoAssetUrl,
    required this.description,
    required this.links,
    required this.nftSaleStart,
    required this.buybackRecipient,
  });

  final String name;
  final String ticker;
  final String logoAssetUrl;
  final String description;
  final List<String> links;
  final DateTime nftSaleStart;
  final String buybackRecipient;

  /// Unix seconds as the decimal string the contract wants.
  String get nftSaleStartAt =>
      (nftSaleStart.toUtc().millisecondsSinceEpoch ~/ 1000).toString();
}

/// The EIP-712 request the owner signs (`…/signing-request`).
@immutable
final class Launch2SigningRequest {
  const Launch2SigningRequest({
    required this.request,
    required this.typedData,
    required this.projectOwner,
    required this.configVersion,
    required this.configHash,
    required this.name,
    required this.ticker,
    required this.nftSaleStart,
    required this.buybackRecipient,
    required this.deadline,
    required this.nonce,
    required this.domainChainId,
    required this.verifyingContract,
    required this.hookSalt,
    required this.hookAddress,
    required this.memeAddress,
  });

  /// The `request` object exactly as the server sent it: it is posted back
  /// unchanged with the signature.
  final Map<String, Object?> request;

  /// The `typedData` object exactly as the server sent it: it is what the
  /// wallet signs.
  final Map<String, Object?> typedData;

  final String projectOwner;
  final int configVersion;
  final String configHash;
  final String name;
  final String ticker;
  final BigInt nftSaleStart;
  final String buybackRecipient;

  /// Unix seconds after which the signature is refused (about 15 minutes).
  final BigInt deadline;
  final String nonce;

  /// `typedData.domain.chainId`: the chain the Factory lives on.
  final int domainChainId;
  final String verifyingContract;
  final String hookSalt;
  final String hookAddress;
  final String memeAddress;

  DateTime get deadlineAt =>
      DateTime.fromMillisecondsSinceEpoch(deadline.toInt() * 1000, isUtc: true);

  DateTime get nftSaleStartAt => DateTime.fromMillisecondsSinceEpoch(
    nftSaleStart.toInt() * 1000,
    isUtc: true,
  );

  bool expiredAt(DateTime now) => !deadlineAt.isAfter(now.toUtc());
}

/// The executor's job status (`hooks-deployments` §9.1).
enum Launch2JobStatus {
  awaitingExecutor('awaiting_executor'),
  claimed('claimed'),
  broadcast('broadcast'),
  confirmed('confirmed'),
  verified('verified'),
  activated('activated'),
  failed('failed'),
  reorged('reorged'),
  cancelled('cancelled');

  const Launch2JobStatus(this.wireName);

  final String wireName;

  static Launch2JobStatus? tryParse(Object? value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

@immutable
final class Launch2JobFailure {
  const Launch2JobFailure({required this.code, required this.retryable});

  final String code;
  final bool retryable;
}

@immutable
final class Launch2JobEvent {
  const Launch2JobEvent({
    required this.sequence,
    required this.fromStatus,
    required this.toStatus,
    required this.kind,
    required this.txHash,
    required this.blockNumber,
    required this.confirmations,
    required this.errorCode,
    required this.createdAt,
  });

  final int sequence;
  final Launch2JobStatus? fromStatus;
  final Launch2JobStatus toStatus;

  /// Open vocabulary: an unknown kind is shown with a generic line.
  final String kind;
  final String? txHash;
  final String? blockNumber;
  final int? confirmations;
  final String? errorCode;
  final DateTime createdAt;
}

/// One deployment job (`hooks-deployments/{jobId}`).
@immutable
final class Launch2DeploymentJob {
  const Launch2DeploymentJob({
    required this.jobId,
    required this.projectId,
    required this.configVersion,
    required this.chainId,
    required this.factoryAddress,
    required this.status,
    required this.memeAddress,
    required this.hookAddress,
    required this.txHash,
    required this.confirmations,
    required this.activationTxHash,
    required this.deployedLaunchId,
    required this.deployedMeme,
    required this.failure,
    required this.attemptCount,
    required this.events,
    required this.createdAt,
    required this.updatedAt,
  });

  final String jobId;
  final String projectId;
  final int configVersion;

  /// The deployment chain's EIP-155 reference (`97`).
  final int chainId;
  final String factoryAddress;
  final Launch2JobStatus status;

  /// The signed CREATE2 predictions.
  final String memeAddress;
  final String hookAddress;
  final String? txHash;
  final int? confirmations;
  final String? activationTxHash;

  /// `addresses.deployed.launchId` / `.meme`, present from `verified` on.
  final String? deployedLaunchId;
  final String? deployedMeme;
  final Launch2JobFailure? failure;
  final int attemptCount;

  /// Ascending by `sequence` (the codec checks it).
  final List<Launch2JobEvent> events;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether the progress page stops polling (§6: activated, a final failure,
  /// cancelled).
  bool get settled =>
      status == Launch2JobStatus.activated ||
      status == Launch2JobStatus.cancelled ||
      (status == Launch2JobStatus.failed && failure?.retryable != true);

  /// Only a job no executor has claimed may be cancelled (§6).
  bool get cancellable => status == Launch2JobStatus.awaitingExecutor;
}

/// The activated instance this project became (`GET /v2/launch2/instances`).
@immutable
final class Launch2InstanceRef {
  const Launch2InstanceRef({
    required this.instanceId,
    required this.projectId,
    required this.stage,
  });

  final String instanceId;
  final String projectId;
  final String stage;
}

/// Everything the status page reads for one project.
@immutable
final class Launch2CreatorProject {
  const Launch2CreatorProject({
    required this.project,
    required this.draft,
    this.job,
    this.instance,
    this.configAwaitingApproval = false,
  });

  final LaunchProject project;

  /// `null` when no Hooks draft was saved yet.
  final Launch2HooksDraft? draft;

  /// The deployment job this device submitted during this run, when there is
  /// one. The server publishes no job list (decision 0138), so a job from an
  /// earlier run is not known here.
  final Launch2DeploymentJob? job;

  /// The activated instance the read model lists for this project, when it
  /// lists one.
  final Launch2InstanceRef? instance;

  /// The submit answered `403 HOOKS_CONFIG_NOT_APPROVED`: the platform has
  /// not approved the latest configuration yet.
  final bool configAwaitingApproval;

  String get projectId => project.projectId;

  Launch2CreatorStatus get status => instance != null
      ? Launch2CreatorStatus.active
      : launch2CreatorStatusOf(
          reviewStatus: project.reviewStatus,
          hasDraft: draft != null,
          job: job,
          configAwaitingApproval: configAwaitingApproval,
        );
}

/// Projects the three server facts onto the ten design states.
///
/// | fact                                        | state              |
/// | ------------------------------------------- | ------------------ |
/// | job `activated`                             | active             |
/// | job `verified`                              | verified           |
/// | job `confirmed`                             | deployed           |
/// | job queued / claimed / broadcast / reorged  | deploying          |
/// | job `failed`, retryable                     | deploying (重试中) |
/// | job `failed`, final                         | deploy_failed      |
/// | review `draft`, or approved without config  | draft              |
/// | review `submitted` / `in_review`            | awaiting_approval  |
/// | approved, config refused as not approved    | awaiting_approval  |
/// | review `returned` / `rejected`              | rejected           |
/// | review `approved` (no job, or cancelled)    | approved           |
Launch2CreatorStatus launch2CreatorStatusOf({
  required LaunchReviewStatus reviewStatus,
  required bool hasDraft,
  required Launch2DeploymentJob? job,
  bool configAwaitingApproval = false,
}) {
  if (job != null && job.status != Launch2JobStatus.cancelled) {
    return switch (job.status) {
      Launch2JobStatus.activated => Launch2CreatorStatus.active,
      Launch2JobStatus.verified => Launch2CreatorStatus.verified,
      Launch2JobStatus.confirmed => Launch2CreatorStatus.deployed,
      Launch2JobStatus.failed =>
        job.failure?.retryable == true
            ? Launch2CreatorStatus.deploying
            : Launch2CreatorStatus.deployFailed,
      _ => Launch2CreatorStatus.deploying,
    };
  }
  return switch (reviewStatus) {
    LaunchReviewStatus.draft => Launch2CreatorStatus.draft,
    LaunchReviewStatus.submitted ||
    LaunchReviewStatus.inReview => Launch2CreatorStatus.awaitingApproval,
    LaunchReviewStatus.returned ||
    LaunchReviewStatus.rejected => Launch2CreatorStatus.rejected,
    LaunchReviewStatus.approved =>
      !hasDraft
          ? Launch2CreatorStatus.draft
          : configAwaitingApproval
          ? Launch2CreatorStatus.awaitingApproval
          : Launch2CreatorStatus.approved,
  };
}

/// One row of 我的项目.
@immutable
final class Launch2CreatorRow {
  const Launch2CreatorRow({required this.project, required this.draft});

  final LaunchProject project;

  /// `null` when no Hooks draft exists yet.
  final Launch2HooksDraft? draft;
}

/// One page of 我的项目.
@immutable
final class Launch2CreatorPage {
  const Launch2CreatorPage({required this.rows, required this.nextCursor});

  final List<Launch2CreatorRow> rows;
  final String? nextCursor;

  Launch2CreatorPage append(Launch2CreatorPage next) => Launch2CreatorPage(
    rows: <Launch2CreatorRow>[...rows, ...next.rows],
    nextCursor: next.nextCursor,
  );
}
