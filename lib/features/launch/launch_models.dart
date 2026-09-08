import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';

/// Presentation models for the `launch` module (loop-api decision 0036).
///
/// Every on-chain fact is absent by contract in this step: the four state
/// axes, the contract address, the caps, the fees and the pool evidence all
/// arrive as `unavailable` with the server's own `reasonCode`. The models keep
/// that absence explicit so no page can invent a figure.

// ---------------------------------------------------------------------------
// catalogue
// ---------------------------------------------------------------------------

/// Off-chain schedule of one launch. It is **not** a graduation signal: the
/// liquidity axis is the only thing that can prove graduation, and it stays
/// unavailable until the contract baseline lands.
enum LaunchScheduleStatus {
  unscheduled('unscheduled'),
  scheduled('scheduled'),
  live('live'),
  ended('ended');

  const LaunchScheduleStatus(this.wireName);

  final String wireName;

  static LaunchScheduleStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// The four-axis on-chain projection.
///
/// Each axis is the server's own enum value. In this step every axis reads
/// `unavailable`; the model keeps the raw value so a later contract baseline
/// does not need a new shape.
@immutable
final class LaunchOnChainState {
  const LaunchOnChainState({
    required this.saleState,
    required this.entitlementState,
    required this.liquidityState,
    required this.operationalState,
    required this.stateTupleDigest,
    required this.snapshotBlockNumber,
    required this.snapshotBlockHash,
    required this.source,
    required this.reasonCode,
  });

  static const unavailableValue = 'unavailable';

  final String saleState;
  final String entitlementState;
  final String liquidityState;
  final String operationalState;
  final String? stateTupleDigest;
  final String? snapshotBlockNumber;
  final String? snapshotBlockHash;
  final String source;
  final String reasonCode;

  bool get isProvable => source != unavailableValue;

  /// The four axes in the fixed order the detail page renders them.
  List<(String, String)> get axes => <(String, String)>[
    ('销售状态', saleState),
    ('权益状态', entitlementState),
    ('流动性状态', liquidityState),
    ('运营状态', operationalState),
  ];
}

@immutable
final class LaunchSummary {
  const LaunchSummary({
    required this.launchId,
    required this.projectId,
    required this.name,
    required this.ticker,
    required this.chainId,
    required this.contractAddress,
    required this.configDigest,
    required this.scheduleStatus,
    required this.onChainState,
    required this.configVersion,
    required this.createdAt,
  });

  final String launchId;
  final String projectId;
  final String name;
  final String ticker;
  final String chainId;

  /// `null` for the whole of step 7: there is no deployed contract.
  final String? contractAddress;
  final String? configDigest;
  final LaunchScheduleStatus scheduleStatus;
  final LaunchOnChainState onChainState;

  /// The confirmed configuration version, or `null` → "待确认".
  final String? configVersion;
  final DateTime createdAt;
}

@immutable
final class LaunchCatalogStamp {
  const LaunchCatalogStamp({
    required this.configVersion,
    required this.source,
    required this.observedAt,
  });

  final String configVersion;
  final String source;
  final DateTime observedAt;
}

/// The four catalogue segments. `awaitingSchedule` is its own segment by
/// server ruling: an approved launch without a schedule must never be shown
/// as "即将开始".
@immutable
final class LaunchSegments {
  const LaunchSegments({
    required this.live,
    required this.upcoming,
    required this.awaitingSchedule,
    required this.ended,
  });

  final List<LaunchSummary> live;
  final List<LaunchSummary> upcoming;
  final List<LaunchSummary> awaitingSchedule;
  final List<LaunchSummary> ended;

  int get total =>
      live.length + upcoming.length + awaitingSchedule.length + ended.length;
}

@immutable
final class LaunchOverview {
  const LaunchOverview({
    required this.segments,
    required this.graduated,
    required this.myEligibility,
    required this.staking,
    required this.catalog,
  });

  final LaunchSegments segments;

  /// "已毕业" is a liquidity-axis projection, never a schedule projection.
  final LaunchUnavailable graduated;
  final LaunchUnavailable myEligibility;
  final LaunchUnavailable staking;
  final LaunchCatalogStamp catalog;
}

// ---------------------------------------------------------------------------
// application (launch-apply)
// ---------------------------------------------------------------------------

enum LaunchReviewStatus {
  draft('draft'),
  submitted('submitted'),
  inReview('in_review'),
  returned('returned'),
  approved('approved'),
  rejected('rejected');

  const LaunchReviewStatus(this.wireName);

  final String wireName;

  /// Only these two states accept an edit or a submit; every other state is
  /// read-only and the server answers `409 DATA_STALE`.
  bool get isEditable =>
      this == LaunchReviewStatus.draft || this == LaunchReviewStatus.returned;

  static LaunchReviewStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

String launchReviewStatusLabel(LaunchReviewStatus status) => switch (status) {
  LaunchReviewStatus.draft => '草稿',
  LaunchReviewStatus.submitted => '审核中',
  LaunchReviewStatus.inReview => '审核中',
  LaunchReviewStatus.returned => '已退回',
  LaunchReviewStatus.approved => '已通过',
  LaunchReviewStatus.rejected => '未通过',
};

/// What the applicant may do next. It restates the server's own state machine
/// and never widens it.
String launchReviewStatusHint(LaunchReviewStatus status) => switch (status) {
  LaunchReviewStatus.draft => '可继续编辑并提交。',
  LaunchReviewStatus.submitted => '已提交，等待人工审核；提交不代表通过。',
  LaunchReviewStatus.inReview => '审核进行中，此期间资料只读。',
  LaunchReviewStatus.returned => '已退回，可以按退回原因修改后重新提交。',
  LaunchReviewStatus.approved => '已通过并进入目录；资料转为只读。',
  LaunchReviewStatus.rejected => '未通过，且不可重新提交这份申请。',
};

@immutable
final class LaunchOfficialLinks {
  const LaunchOfficialLinks({
    this.website,
    this.x,
    this.telegram,
    this.discord,
  });

  final String? website;
  final String? x;
  final String? telegram;
  final String? discord;

  bool get isEmpty =>
      website == null && x == null && telegram == null && discord == null;

  List<(String, String)> get entries => <(String, String)>[
    if (website != null) ('Website', website!),
    if (x != null) ('X', x!),
    if (telegram != null) ('Telegram', telegram!),
    if (discord != null) ('Discord', discord!),
  ];

  Map<String, Object?> toRequestJson() => <String, Object?>{
    'website': website,
    'x': x,
    'telegram': telegram,
    'discord': discord,
  };
}

/// KYB has no provider. `state` is the server's own value and is rendered as
/// "待接入"; the page never offers an upload or a verification action.
@immutable
final class LaunchKyb {
  const LaunchKyb({
    required this.status,
    required this.state,
    required this.reasonCode,
  });

  final String status;
  final String state;
  final String reasonCode;
}

@immutable
final class LaunchProject {
  const LaunchProject({
    required this.projectId,
    required this.name,
    required this.ticker,
    required this.narrative,
    required this.officialLinks,
    required this.materialVersion,
    required this.reviewStatus,
    required this.reviewReasonCode,
    required this.kyb,
    required this.attachments,
    required this.submittedAt,
    required this.reviewedAt,
    required this.launchId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.configVersion,
  });

  final String projectId;
  final String name;
  final String ticker;
  final String? narrative;
  final LaunchOfficialLinks officialLinks;
  final int materialVersion;
  final LaunchReviewStatus reviewStatus;
  final String? reviewReasonCode;
  final LaunchKyb kyb;
  final LaunchUnavailable attachments;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? launchId;

  /// The CAS version. `null` in a non-owner projection: the review trail and
  /// the version belong to the applicant alone.
  final int? version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String configVersion;

  /// Only the owner's projection carries a version, and only an editable state
  /// accepts a `PUT`.
  bool get canEdit => version != null && reviewStatus.isEditable;

  bool get canSubmit => canEdit;

  bool get isOwnerProjection => version != null;
}

@immutable
final class LaunchProjectPage {
  const LaunchProjectPage({required this.items, required this.nextCursor});

  final List<LaunchProject> items;
  final String? nextCursor;
}

/// A locally shape-checked application draft.
@immutable
final class LaunchProjectDraft {
  const LaunchProjectDraft({
    required this.name,
    required this.ticker,
    required this.narrative,
    required this.officialLinks,
  });

  static final RegExp tickerPattern = RegExp(r'^[A-Z0-9]{2,12}$');
  static final RegExp httpsPattern = RegExp(r'^https://[^\s@]{1,500}$');

  final String name;
  final String ticker;
  final String? narrative;
  final LaunchOfficialLinks officialLinks;

  /// The first field the local shape check rejects, or `null`.
  LaunchDraftField? get invalidField {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 80) {
      return LaunchDraftField.name;
    }
    if (!tickerPattern.hasMatch(ticker)) return LaunchDraftField.ticker;
    final story = narrative;
    if (story != null && (story.isEmpty || story.runes.length > 2000)) {
      return LaunchDraftField.narrative;
    }
    for (final link in <String?>[
      officialLinks.website,
      officialLinks.x,
      officialLinks.telegram,
      officialLinks.discord,
    ]) {
      if (link == null) continue;
      if (link.length > 512 || !httpsPattern.hasMatch(link)) {
        return LaunchDraftField.officialLinks;
      }
    }
    return null;
  }

  Map<String, Object?> toRequestJson() => <String, Object?>{
    'name': name.trim(),
    'ticker': ticker,
    'narrative': narrative,
    'officialLinks': officialLinks.toRequestJson(),
  };
}

enum LaunchDraftField { name, ticker, narrative, officialLinks }

String launchDraftFieldReason(LaunchDraftField field) => switch (field) {
  LaunchDraftField.name => '项目名称需要 1–80 个字符。',
  LaunchDraftField.ticker => 'Ticker 只能是 2–12 位大写字母或数字。',
  LaunchDraftField.narrative => '叙事最多 2000 个字符；留空表示不提交这一项。',
  LaunchDraftField.officialLinks => '官方链接必须是 https:// 开头且不超过 512 个字符。',
};

// ---------------------------------------------------------------------------
// detail · configuration slots and rounds
// ---------------------------------------------------------------------------

enum LaunchConfigStatus {
  pendingConfirmation('pending_confirmation'),
  confirmed('confirmed');

  const LaunchConfigStatus(this.wireName);

  final String wireName;

  static LaunchConfigStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// One configuration slot: either a confirmed string value, or an explanation.
///
/// Values are always strings on the wire. Nothing here is ever parsed into a
/// percentage, a rate or a cap by the client.
@immutable
sealed class LaunchConfigSlot {
  const LaunchConfigSlot();
}

@immutable
final class LaunchConfigSlotConfirmed extends LaunchConfigSlot {
  const LaunchConfigSlotConfirmed(this.value);

  final String value;
}

@immutable
final class LaunchConfigSlotPending extends LaunchConfigSlot {
  const LaunchConfigSlotPending(this.reasonCode);

  final String reasonCode;
}

@immutable
final class LaunchConfigSlots {
  const LaunchConfigSlots({
    required this.walletRoundCap,
    required this.walletProjectCap,
    required this.feeBps,
    required this.softCap,
    required this.hardCap,
    required this.tge,
    required this.vesting,
    required this.tierModeV1,
  });

  final LaunchConfigSlot walletRoundCap;
  final LaunchConfigSlot walletProjectCap;
  final LaunchConfigSlot feeBps;
  final LaunchConfigSlot softCap;
  final LaunchConfigSlot hardCap;
  final LaunchConfigSlot tge;
  final LaunchConfigSlot vesting;
  final LaunchConfigSlot tierModeV1;

  /// The slots in the fixed order the rules page renders them, with the label
  /// the prototype used for each.
  List<(String, LaunchConfigSlot)> get entries => <(String, LaunchConfigSlot)>[
    ('单钱包单轮上限', walletRoundCap),
    ('单钱包项目上限', walletProjectCap),
    ('手续费（bps）', feeBps),
    ('软顶', softCap),
    ('硬顶', hardCap),
    ('TGE', tge),
    ('Vesting', vesting),
    ('资格模式', tierModeV1),
  ];
}

@immutable
final class LaunchConfig {
  const LaunchConfig({
    required this.configVersion,
    required this.status,
    required this.effectiveAt,
    required this.slots,
  });

  final String configVersion;
  final LaunchConfigStatus status;
  final DateTime? effectiveAt;
  final LaunchConfigSlots slots;

  bool get isConfirmed => status == LaunchConfigStatus.confirmed;
}

enum LaunchEligibilityTier {
  priority('priority'),
  community('community'),
  public('public');

  const LaunchEligibilityTier(this.wireName);

  final String wireName;

  static LaunchEligibilityTier? tryParse(String value) {
    for (final tier in values) {
      if (tier.wireName == value) return tier;
    }
    return null;
  }
}

String launchTierLabel(LaunchEligibilityTier tier) => switch (tier) {
  LaunchEligibilityTier.priority => 'Priority',
  LaunchEligibilityTier.community => 'Community',
  LaunchEligibilityTier.public => 'Public',
};

/// One configured round slot. Every value may be `null` — that is "待确认",
/// not "zero" and not "no round".
@immutable
final class LaunchRound {
  const LaunchRound({
    required this.roundId,
    required this.roundIndex,
    required this.configVersion,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.priceUsd1,
    required this.eligibilityTier,
    required this.walletRoundCapRaw,
  });

  final String roundId;
  final int roundIndex;
  final String configVersion;
  final LaunchConfigStatus status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? priceUsd1;
  final LaunchEligibilityTier? eligibilityTier;
  final String? walletRoundCapRaw;

  bool get isConfirmed => status == LaunchConfigStatus.confirmed;
}

enum LaunchGraduationStepKind {
  stopInternalTrading('stop_internal_trading'),
  preparePool('prepare_pool'),
  addAndLockLiquidity('add_and_lock_liquidity'),
  openExternalTrading('open_external_trading');

  const LaunchGraduationStepKind(this.wireName);

  final String wireName;

  static LaunchGraduationStepKind? tryParse(String value) {
    for (final step in values) {
      if (step.wireName == value) return step;
    }
    return null;
  }
}

String launchGraduationStepLabel(LaunchGraduationStepKind step) =>
    switch (step) {
      LaunchGraduationStepKind.stopInternalTrading => '停止内盘交易',
      LaunchGraduationStepKind.preparePool => '归集并创建流动性池',
      LaunchGraduationStepKind.addAndLockLiquidity => '注入并锁定流动性',
      LaunchGraduationStepKind.openExternalTrading => '开放外盘交易',
    };

@immutable
final class LaunchGraduationStep {
  const LaunchGraduationStep({required this.step, required this.status});

  final LaunchGraduationStepKind step;

  /// `pending` for the whole of step 7.
  final String status;
}

@immutable
final class LaunchGraduation {
  const LaunchGraduation({required this.steps, required this.poolEvidence});

  final List<LaunchGraduationStep> steps;
  final LaunchUnavailable poolEvidence;
}

@immutable
final class LaunchProjectBrief {
  const LaunchProjectBrief({
    required this.projectId,
    required this.name,
    required this.ticker,
    required this.narrative,
    required this.officialLinks,
    required this.materialVersion,
  });

  final String projectId;
  final String name;
  final String ticker;
  final String? narrative;
  final LaunchOfficialLinks officialLinks;
  final int materialVersion;
}

@immutable
final class LaunchDetail {
  const LaunchDetail({
    required this.launch,
    required this.project,
    required this.config,
    required this.configPending,
    required this.rounds,
    required this.graduation,
    required this.market,
    required this.holders,
  });

  final LaunchSummary launch;
  final LaunchProjectBrief project;

  /// `null` when the launch has no configuration row at all.
  final LaunchConfig? config;

  /// Non-null when no confirmed version exists: every slot renders "待确认".
  final LaunchUnavailable? configPending;
  final List<LaunchRound> rounds;
  final LaunchGraduation graduation;
  final LaunchUnavailable market;
  final LaunchUnavailable holders;

  /// The version to name in "待确认（configVersion）".
  String? get pendingConfigVersion => config?.configVersion;

  bool get hasConfirmedConfig =>
      configPending == null && config?.isConfirmed == true;
}

// ---------------------------------------------------------------------------
// eligibility · stake · holders · history
// ---------------------------------------------------------------------------

enum LaunchEligibilityMode {
  whitelist('whitelist'),
  community('community'),
  activity('activity'),
  unavailable('unavailable');

  const LaunchEligibilityMode(this.wireName);

  final String wireName;

  static LaunchEligibilityMode? tryParse(String value) {
    for (final mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

String launchEligibilityModeLabel(LaunchEligibilityMode mode) => switch (mode) {
  LaunchEligibilityMode.whitelist => '白名单',
  LaunchEligibilityMode.community => '社区',
  LaunchEligibilityMode.activity => '活跃度',
  LaunchEligibilityMode.unavailable => '未配置',
};

String launchEligibilityModeDescription(LaunchEligibilityMode mode) =>
    switch (mode) {
      LaunchEligibilityMode.whitelist => '资格由运营维护的白名单快照决定。',
      LaunchEligibilityMode.community => '资格由社区成员关系决定。',
      LaunchEligibilityMode.activity => '资格由账号活跃度决定。',
      LaunchEligibilityMode.unavailable => '本次发射还没有配置资格模式，因此没有资格结论。',
    };

@immutable
final class LaunchEligibility {
  const LaunchEligibility({
    required this.launchId,
    required this.mode,
    required this.tier,
    required this.reasonCode,
    required this.snapshotBlock,
    required this.configVersion,
    required this.effectiveAt,
    required this.dependsOnStaking,
  });

  final String launchId;
  final LaunchEligibilityMode mode;

  /// `null` for the whole of step 7: there is no tier result yet.
  final String? tier;
  final String reasonCode;
  final String? snapshotBlock;
  final String? configVersion;
  final DateTime? effectiveAt;

  /// Always `false`: eligibility does not depend on staking.
  final bool dependsOnStaking;

  bool get hasResult => tier != null;
}

@immutable
final class LaunchStake {
  const LaunchStake({required this.stake, required this.executable});

  final LaunchUnavailable stake;

  /// Always `false`. The page renders no amount field and no signing entry.
  final bool executable;
}

@immutable
final class LaunchHolders {
  const LaunchHolders({
    required this.launchId,
    required this.holders,
    required this.myPosition,
    required this.walletCap,
  });

  final String launchId;
  final LaunchUnavailable holders;
  final LaunchUnavailable myPosition;
  final LaunchUnavailable walletCap;
}

/// An empty history with an `unavailable` source means "cannot be proven",
/// never "did not participate". The three collections are empty by contract in
/// this step, so the page renders the source explanation instead of a list.
@immutable
final class LaunchHistory {
  const LaunchHistory({required this.launchId, required this.source});

  final String launchId;
  final LaunchUnavailable source;
}

// ---------------------------------------------------------------------------
// venue milestones
// ---------------------------------------------------------------------------

enum LaunchVenue {
  lbank('lbank'),
  binance('binance'),
  bithumb('bithumb');

  const LaunchVenue(this.wireName);

  final String wireName;

  static LaunchVenue? tryParse(String value) {
    for (final venue in values) {
      if (venue.wireName == value) return venue;
    }
    return null;
  }
}

String launchVenueLabel(LaunchVenue venue) => switch (venue) {
  LaunchVenue.lbank => 'LBank',
  LaunchVenue.binance => 'Binance',
  LaunchVenue.bithumb => 'Bithumb',
};

enum LaunchMarketType {
  spot('spot'),
  alpha('alpha'),
  perpetual('perpetual');

  const LaunchMarketType(this.wireName);

  final String wireName;

  static LaunchMarketType? tryParse(String value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

/// Alpha is not spot. The two are rendered as distinct market types and one
/// never implies the other.
String launchMarketTypeLabel(LaunchMarketType type) => switch (type) {
  LaunchMarketType.spot => '现货',
  LaunchMarketType.alpha => 'Alpha',
  LaunchMarketType.perpetual => '永续',
};

enum LaunchMilestoneState {
  preparing('PREPARING'),
  applied('APPLIED'),
  evidencePending('EVIDENCE_PENDING'),
  listed('LISTED'),
  featured('FEATURED'),
  rejected('REJECTED'),
  deferred('DEFERRED'),
  evidenceInvalid('EVIDENCE_INVALID'),
  delisted('DELISTED');

  const LaunchMilestoneState(this.wireName);

  final String wireName;

  /// Only these two states carry reviewed evidence.
  bool get carriesEvidence =>
      this == LaunchMilestoneState.listed ||
      this == LaunchMilestoneState.featured;

  static LaunchMilestoneState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

String launchMilestoneStateLabel(LaunchMilestoneState state) => switch (state) {
  LaunchMilestoneState.preparing => '准备中',
  LaunchMilestoneState.applied => '已申请',
  LaunchMilestoneState.evidencePending => '待补证据',
  LaunchMilestoneState.listed => '已上线',
  LaunchMilestoneState.featured => '已获推荐位',
  LaunchMilestoneState.rejected => '已拒绝',
  LaunchMilestoneState.deferred => '已搁置',
  LaunchMilestoneState.evidenceInvalid => '证据无效',
  LaunchMilestoneState.delisted => '已下架',
};

/// `recordedAt` is the server clock when a reviewer filed the evidence;
/// `observedAt` is when the evidence was verifiable on the venue. They are two
/// different facts and are never derived from one another.
@immutable
final class LaunchMilestoneEvidence {
  const LaunchMilestoneEvidence({
    required this.digest,
    required this.recordedAt,
    required this.observedAt,
    required this.reviewer,
  });

  final String? digest;
  final DateTime? recordedAt;
  final DateTime? observedAt;
  final String? reviewer;

  bool get isEmpty =>
      digest == null &&
      recordedAt == null &&
      observedAt == null &&
      reviewer == null;
}

@immutable
final class LaunchMilestone {
  const LaunchMilestone({
    required this.venueMilestoneId,
    required this.venue,
    required this.marketType,
    required this.state,
    required this.evidence,
    required this.version,
    required this.updatedAt,
  });

  /// `null` for an implicit `PREPARING` row: the track is always listed, but
  /// nothing has been stored for it yet.
  final String? venueMilestoneId;
  final LaunchVenue venue;
  final LaunchMarketType marketType;
  final LaunchMilestoneState state;
  final LaunchMilestoneEvidence evidence;

  /// `0` for an implicit `PREPARING` row.
  final int version;

  /// `null` for an implicit `PREPARING` row.
  final DateTime? updatedAt;

  /// The track has no stored record. It is "尚无记录", not "准备中开始了".
  bool get isImplicit => venueMilestoneId == null;

  /// The track's stable identity. Two rows can share a venue only when they
  /// carry different market types, so the pair addresses a track even while
  /// the implicit row has no id of its own.
  String get trackKey => '${venue.wireName}/${marketType.wireName}';
}

/// The five tracks 03 §8.4 lists. The server always returns all five, so a
/// missing one is a contract break rather than an absent track.
const List<(LaunchVenue, LaunchMarketType)> launchMilestoneTracks =
    <(LaunchVenue, LaunchMarketType)>[
      (LaunchVenue.lbank, LaunchMarketType.spot),
      (LaunchVenue.binance, LaunchMarketType.alpha),
      (LaunchVenue.binance, LaunchMarketType.perpetual),
      (LaunchVenue.binance, LaunchMarketType.spot),
      (LaunchVenue.bithumb, LaunchMarketType.spot),
    ];

@immutable
final class LaunchMilestones {
  const LaunchMilestones({required this.projectId, required this.items});

  final String projectId;
  final List<LaunchMilestone> items;
}

// ---------------------------------------------------------------------------
// economy
// ---------------------------------------------------------------------------

@immutable
final class LaunchProjectCounts {
  const LaunchProjectCounts({
    required this.draft,
    required this.submitted,
    required this.inReview,
    required this.returned,
    required this.approved,
    required this.rejected,
  });

  final int draft;
  final int submitted;
  final int inReview;
  final int returned;
  final int approved;
  final int rejected;

  List<(String, int)> get entries => <(String, int)>[
    ('草稿', draft),
    ('已提交', submitted),
    ('审核中', inReview),
    ('已退回', returned),
    ('已通过', approved),
    ('未通过', rejected),
  ];
}

@immutable
final class LaunchScheduleCounts {
  const LaunchScheduleCounts({
    required this.unscheduled,
    required this.scheduled,
    required this.live,
    required this.ended,
  });

  final int unscheduled;
  final int scheduled;
  final int live;
  final int ended;

  List<(String, int)> get entries => <(String, int)>[
    ('待排期', unscheduled),
    ('已排期', scheduled),
    ('发射中', live),
    ('已结束', ended),
  ];
}

/// The public ledger page. Only counts that can be proven from the LOOP
/// database are numbers; supply, distribution and ecosystem tax stay
/// unavailable.
@immutable
final class LaunchEconomy {
  const LaunchEconomy({
    required this.projects,
    required this.launches,
    required this.confirmedRoundCount,
    required this.totalSupply,
    required this.distributed,
    required this.ecosystemTax,
    required this.source,
    required this.observedAt,
  });

  final LaunchProjectCounts projects;
  final LaunchScheduleCounts launches;
  final int confirmedRoundCount;
  final LaunchUnavailable totalSupply;
  final LaunchUnavailable distributed;
  final LaunchUnavailable ecosystemTax;
  final String source;
  final DateTime observedAt;
}
