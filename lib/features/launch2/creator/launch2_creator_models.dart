import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';

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
    this.officialPoolHookKind,
    this.loopDynamic,
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

  /// `officialTax` / `loopDynamic`; null when the server predates the field.
  final String? officialPoolHookKind;

  /// Immutable LoopDynamic parameters; null for an OfficialTax template.
  final Launch2LoopDynamicEconomics? loopDynamic;

  /// The per-address curve cap this template's Factory enforces: the
  /// LoopDynamic Factory's own `maxCumulativeBuy` (decision 0198, loop-api
  /// 0152) when it states a positive one, otherwise the template constant.
  BigInt get curveCapRaw {
    final factoryCap = loopDynamic?.maxCumulativeBuyRaw;
    return factoryCap != null && factoryCap > BigInt.zero
        ? factoryCap
        : perAddressLifetimeBuyCapRaw;
  }

  /// The per-address cap as basis points of the total supply.
  int? get perAddressCapBps => memeTotalSupplyRaw == BigInt.zero
      ? null
      : (curveCapRaw * BigInt.from(10000) ~/ memeTotalSupplyRaw).toInt();
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

  /// The platform's fixed buyback recipient as the requirer named it
  /// (answer 9). A project that does not exist yet has no `hooks-config` to
  /// read, so the form shows this one; every save sends the server's own
  /// `fixedBuybackRecipient` read just before it (decision 0144).
  static const String defaultBuybackRecipient =
      '0x28816c4C4792467390C90e5B426F198570E29307';

  /// The contract's own floor for the sale lead: the activation buffer
  /// (3,600 s) plus the executor margin (600 s). The server's configured lead
  /// (`hooks-config.minSaleLeadSeconds`, loop-api decision 0120) is never
  /// below it. A project that does not exist yet has no config to read, so
  /// its picker starts from this floor and the save reads the real lead
  /// before it writes the draft (decision 0142).
  static const Duration contractMinimumSaleLead = Duration(seconds: 4200);

  /// What the picker proposes first: two days out, comfortably past every
  /// configured lead.
  static const Duration suggestedSaleLead = Duration(days: 2);
}

/// `422 HOOKS_BUYBACK_RECIPIENT_FIXED` (loop-api decision 0122): the
/// configuration names another recipient than the platform's fixed one.
const String launch2RecipientFixedCode = 'HOOKS_BUYBACK_RECIPIENT_FIXED';

/// `422 HOOKS_CONFIG_VERSION_USED` (loop-api decision 0127, client decision
/// 0150): signing preparation only — this wallet already deployed a project
/// with this config version. The owner saves the config again.
const String launch2ConfigVersionUsedCode = 'HOOKS_CONFIG_VERSION_USED';

/// The refusals the owner answers by editing and saving a new version.
bool launch2FailureNeedsResave(String? reasonCode) =>
    reasonCode == launch2RecipientFixedCode ||
    reasonCode == launch2ConfigVersionUsedCode;

/// `503 HOOKS_BUYBACK_RECIPIENT_UNAVAILABLE`: the platform has not configured
/// its fixed recipient; nothing can be saved, signed or submitted.
const String launch2RecipientUnavailableCode =
    'HOOKS_BUYBACK_RECIPIENT_UNAVAILABLE';

/// The earliest sale start the picker offers: [now] plus the server's
/// [lead], rounded up to the next whole minute (decision 0142). The server's
/// `400` on save stays the final word.
DateTime launch2EarliestSaleStart(DateTime now, Duration lead) {
  final at = now.toUtc().add(lead);
  final floor = DateTime.utc(at.year, at.month, at.day, at.hour, at.minute);
  return floor == at ? floor : floor.add(const Duration(minutes: 1));
}

/// One saved Hooks draft (`GET`/`PUT …/hooks-config`).
@immutable
final class Launch2HooksDraft {
  const Launch2HooksDraft({
    required this.projectId,
    required this.version,
    required this.templateVersion,
    required this.templateHash,
    this.poolHookKind,
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

  /// `loopDynamic` when the project was created on a LoopDynamic template; null for OfficialTax.
  final String? poolHookKind;
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

/// The platform's approval of the latest draft (`hooks-config.approval`,
/// loop-api decision 0120; `rejected` since 0122).
enum Launch2ApprovalStatus {
  awaitingApproval('awaiting_approval'),
  approved('approved'),

  /// A reviewer rejected this version (see [Launch2HooksApproval.rejection]);
  /// saving a new version resubmits it as awaiting approval.
  rejected('rejected');

  const Launch2ApprovalStatus(this.wireName);

  final String wireName;

  static Launch2ApprovalStatus? tryParse(Object? value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

@immutable
final class Launch2HooksApproval {
  const Launch2HooksApproval({
    required this.configVersion,
    required this.status,
    required this.approvedAt,
    this.rejection,
  });

  /// Always the draft's own version: a newer save is awaiting approval again.
  final int configVersion;
  final Launch2ApprovalStatus status;

  /// `null` until approved.
  final DateTime? approvedAt;

  /// Non-null exactly when [status] is rejected (loop-api decision 0122).
  final LaunchRejection? rejection;

  bool get approved => status == Launch2ApprovalStatus.approved;

  bool get rejected => status == Launch2ApprovalStatus.rejected;
}

/// Everything `GET …/hooks-config` answers (loop-api decision 0120): the
/// draft, its approval, the project's newest deployment task and the
/// server's sale lead. Together they say where the owner left off.
@immutable
final class Launch2HooksConfig {
  const Launch2HooksConfig({
    required this.draft,
    required this.approval,
    required this.latestDeployment,
    required this.minSaleLead,
    this.fixedBuybackRecipient,
  });

  /// `null` when no draft was saved yet (and then [approval] is `null` too).
  final Launch2HooksDraft? draft;
  final Launch2HooksApproval? approval;

  /// The newest task of any config version and any status; `null` when none.
  final Launch2DeploymentJob? latestDeployment;

  /// `HOOKS_LAUNCH_MIN_SALE_LEAD_SECONDS`: a save accepts a sale start at
  /// least this far after the server's now.
  final Duration minSaleLead;

  /// `LAUNCH2_BUYBACK_RECIPIENT` in lower case (loop-api decision 0122): the
  /// one recipient a save, a signing request and a submission accept. The
  /// owner never types it. `null` = the platform has not configured it, and
  /// every save is refused (`503 HOOKS_BUYBACK_RECIPIENT_UNAVAILABLE`).
  final String? fixedBuybackRecipient;

  /// The saved draft names another recipient than the fixed one (a version
  /// saved before decision 0122): it can no longer be signed or submitted;
  /// the owner saves a new version, which needs approval again.
  bool get recipientOutdated {
    final fixed = fixedBuybackRecipient;
    final saved = draft?.buybackRecipient;
    return fixed != null &&
        saved != null &&
        saved.toLowerCase() != fixed.toLowerCase();
  }

  /// The task that still describes the project. A cancelled task never does;
  /// a finally failed task of an older version does not once a newer draft
  /// was saved (the owner changed the configuration to fix it).
  Launch2DeploymentJob? get currentJob {
    final job = latestDeployment;
    if (job == null || job.status == Launch2JobStatus.cancelled) return null;
    final version = draft?.version;
    if (job.status == Launch2JobStatus.failed &&
        job.failure?.retryable != true &&
        version != null &&
        version > job.configVersion) {
      return null;
    }
    return job;
  }
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

  /// The same input naming [recipient] (the platform's fixed address).
  Launch2ConfigInput withBuybackRecipient(String recipient) =>
      Launch2ConfigInput(
        name: name,
        ticker: ticker,
        logoAssetUrl: logoAssetUrl,
        description: description,
        links: links,
        nftSaleStart: nftSaleStart,
        buybackRecipient: recipient,
      );

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
    required this.config,
    this.instance,
  });

  final LaunchProject project;

  /// The Hooks draft, its approval, the newest task and the sale lead.
  final Launch2HooksConfig config;

  /// The activated instance the read model lists for this project, when it
  /// lists one.
  final Launch2InstanceRef? instance;

  String get projectId => project.projectId;

  /// `null` when no Hooks draft was saved yet.
  Launch2HooksDraft? get draft => config.draft;

  Launch2HooksApproval? get approval => config.approval;

  /// The task that still describes the project ([Launch2HooksConfig.currentJob]).
  Launch2DeploymentJob? get job => config.currentJob;

  Launch2CreatorStatus get status => launch2CreatorStatusOf(
    reviewStatus: project.reviewStatus,
    config: config,
    instanceListed: instance != null,
  );

  Launch2CreatorResume get resume => launch2CreatorResumeOf(
    status: status,
    projectId: projectId,
    job: job,
    instance: instance,
    recipientOutdated: config.recipientOutdated,
  );

  /// The rejection the owner answers now (decision 0144): the catalogue
  /// project's while it is rejected, otherwise the launch configuration's.
  /// `null` for a returned project (it has its reason sentence only) and for
  /// a rejection made before loop-api decision 0122.
  LaunchRejection? get rejection {
    if (project.reviewStatus == LaunchReviewStatus.rejected) {
      return project.rejection;
    }
    if (project.reviewStatus == LaunchReviewStatus.returned) return null;
    final approval = config.approval;
    return approval != null && approval.rejected ? approval.rejection : null;
  }
}

/// Projects the server facts onto the ten design states (decision 0142;
/// 0138 §2 before `hooks-config` carried approval and the newest task).
///
/// | fact                                              | state             |
/// | ------------------------------------------------- | ----------------- |
/// | the read model lists the instance                 | active            |
/// | current task `activated`                          | active            |
/// | current task `verified`                           | verified          |
/// | current task `confirmed`                          | deployed          |
/// | current task queued / claimed / broadcast / reorg | deploying         |
/// | current task `failed`, retryable                  | deploying (重试中) |
/// | current task `failed`, final                      | deploy_failed     |
/// | catalogue review `returned` / `rejected`          | rejected          |
/// | no Hooks draft                                    | draft             |
/// | `approval.status = approved`                      | approved          |
/// | `approval.status = rejected` (0122, client 0144)  | rejected          |
/// | catalogue review `draft` (never submitted)        | draft             |
/// | otherwise (`awaiting_approval`)                   | awaiting_approval |
Launch2CreatorStatus launch2CreatorStatusOf({
  required LaunchReviewStatus reviewStatus,
  required Launch2HooksConfig config,
  bool instanceListed = false,
}) {
  if (instanceListed) return Launch2CreatorStatus.active;
  final job = config.currentJob;
  if (job != null) {
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
  if (reviewStatus == LaunchReviewStatus.returned ||
      reviewStatus == LaunchReviewStatus.rejected) {
    return Launch2CreatorStatus.rejected;
  }
  if (config.draft == null) return Launch2CreatorStatus.draft;
  if (config.approval?.approved == true) return Launch2CreatorStatus.approved;
  if (config.approval?.rejected == true) return Launch2CreatorStatus.rejected;
  if (reviewStatus == LaunchReviewStatus.draft) {
    return Launch2CreatorStatus.draft;
  }
  return Launch2CreatorStatus.awaitingApproval;
}

/// Where 我的项目 sends the owner for one project (decision 0142).
enum Launch2ResumeTarget {
  /// 资料 / 配置页: nothing submitted yet.
  edit,

  /// 项目状态页: 审核中 / 已批准 / 审核意见, or activated while the read
  /// model has not listed the instance yet.
  status,

  /// 签名部署页: approved, no task.
  sign,

  /// 部署进度页: a task exists and is not activated.
  deployment,

  /// 用户侧项目页 (with 「你是项目方」).
  instance,
}

@immutable
final class Launch2CreatorResume {
  const Launch2CreatorResume(this.target, {this.jobId, this.instanceId});

  final Launch2ResumeTarget target;

  /// Set for [Launch2ResumeTarget.deployment].
  final String? jobId;

  /// Set for [Launch2ResumeTarget.instance].
  final String? instanceId;

  @override
  bool operator ==(Object other) =>
      other is Launch2CreatorResume &&
      other.target == target &&
      other.jobId == jobId &&
      other.instanceId == instanceId;

  @override
  int get hashCode => Object.hash(target, jobId, instanceId);

  @override
  String toString() => 'Launch2CreatorResume($target, $jobId, $instanceId)';
}

/// The resume decision table (decision 0142 §1).
///
/// | status                                   | page                       |
/// | ---------------------------------------- | -------------------------- |
/// | draft (no draft, or never submitted)     | 资料 / 配置页               |
/// | awaiting_approval, rejected              | 项目状态页（等审核 / 意见） |
/// | approved                                 | 签名部署页                  |
/// | approved, recipient outdated (0144)      | 项目状态页（改资料重存）    |
/// | deploying / deployed / verified / failed | 部署进度页（该任务）        |
/// | active, instance listed                  | 用户侧项目页                |
/// | active, instance not listed yet          | 项目状态页                  |
Launch2CreatorResume launch2CreatorResumeOf({
  required Launch2CreatorStatus status,
  required String projectId,
  required Launch2DeploymentJob? job,
  required Launch2InstanceRef? instance,
  bool recipientOutdated = false,
}) {
  switch (status) {
    case Launch2CreatorStatus.draft:
      return const Launch2CreatorResume(Launch2ResumeTarget.edit);
    case Launch2CreatorStatus.awaitingApproval:
    case Launch2CreatorStatus.rejected:
      return const Launch2CreatorResume(Launch2ResumeTarget.status);
    case Launch2CreatorStatus.approved:
    case Launch2CreatorStatus.signing:
      // An approved version with another recipient can never be signed
      // (loop-api decision 0122): the status page says why and how to fix it.
      return recipientOutdated
          ? const Launch2CreatorResume(Launch2ResumeTarget.status)
          : const Launch2CreatorResume(Launch2ResumeTarget.sign);
    case Launch2CreatorStatus.deploying:
    case Launch2CreatorStatus.deployed:
    case Launch2CreatorStatus.verified:
    case Launch2CreatorStatus.deployFailed:
      return job == null
          ? const Launch2CreatorResume(Launch2ResumeTarget.status)
          : Launch2CreatorResume(
              Launch2ResumeTarget.deployment,
              jobId: job.jobId,
            );
    case Launch2CreatorStatus.active:
      return instance == null
          ? const Launch2CreatorResume(Launch2ResumeTarget.status)
          : Launch2CreatorResume(
              Launch2ResumeTarget.instance,
              instanceId: instance.instanceId,
            );
  }
}

/// One row of 我的项目: the same three reads as the status page, so the row's
/// state and where a tap lands agree with it.
typedef Launch2CreatorRow = Launch2CreatorProject;

/// One page of 我的项目.
@immutable
/// One project of 我的项目, in the catalogue's order (decision 0198): either
/// read in full, or a catalogue project whose own `hooks-config` answer this
/// build could not read. One unreadable project no longer fails the page.
sealed class Launch2CreatorListEntry {
  const Launch2CreatorListEntry();

  LaunchProject get project;
}

final class Launch2CreatorReadableListEntry extends Launch2CreatorListEntry {
  const Launch2CreatorReadableListEntry(this.row);

  final Launch2CreatorRow row;

  @override
  LaunchProject get project => row.project;
}

/// The catalogue project is known; its launch configuration is not, so no
/// state is claimed for it.
final class Launch2CreatorUnreadableListEntry extends Launch2CreatorListEntry {
  const Launch2CreatorUnreadableListEntry(this.project);

  @override
  final LaunchProject project;
}

final class Launch2CreatorPage {
  const Launch2CreatorPage({required this.entries, required this.nextCursor});

  final List<Launch2CreatorListEntry> entries;
  final String? nextCursor;

  /// The projects read in full.
  List<Launch2CreatorRow> get rows => <Launch2CreatorRow>[
    for (final entry in entries)
      if (entry is Launch2CreatorReadableListEntry) entry.row,
  ];

  Launch2CreatorPage append(Launch2CreatorPage next) => Launch2CreatorPage(
    entries: <Launch2CreatorListEntry>[...entries, ...next.entries],
    nextCursor: next.nextCursor,
  );
}

/// The LoopDynamic template's immutable Hook parameters (Decision 0131/0132),
/// echoed inside `fixedEconomics.loopDynamic`.
final class Launch2LoopDynamicEconomics {
  const Launch2LoopDynamicEconomics({
    required this.router,
    required this.buyFeePpm,
    required this.baseSellFeePpm,
    required this.baseFeeRecipient,
    required this.priceTiming,
    required this.routingPolicy,
    required this.routerRegistryAdmin,
    required this.excludeBuybackFromRewards,
    this.maxDynamicFeeWad,
    this.maxCumulativeBuyRaw,
    this.buyFeeToken,
  });

  final String router;
  final int buyFeePpm;
  final int baseSellFeePpm;
  final String baseFeeRecipient;
  final String priceTiming;
  final String routingPolicy;
  final String routerRegistryAdmin;
  final bool excludeBuybackFromRewards;

  /// loop-api 0144: the Factory's dynamic sell-rate cap, a raw 18-decimal
  /// integer (0 = uncapped). Null on a pre-S193 Factory's template.
  final BigInt? maxDynamicFeeWad;

  /// loop-api 0152: the Factory's per-address curve purchase cap, raw MEME.
  /// Null on a pre-S209 Factory's template ([Launch2FixedEconomics.curveCapRaw]
  /// then falls back to the template constant).
  final BigInt? maxCumulativeBuyRaw;

  /// loop-api 0152: which side the buy fee is taken from. Null when the
  /// template does not say — the page then says nothing about the side.
  final Launch2BuyFeeToken? buyFeeToken;
}
