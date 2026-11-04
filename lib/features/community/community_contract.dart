import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// Narrow, feature-facing failure taxonomy shared by the S3 ports
/// (`community`, social graph and `search`).
///
/// It carries no transport detail: the adapters map the V2 error catalogue
/// onto these kinds so `lib/features/` never branches on an HTTP status or a
/// `/v2/` literal.
enum CommunityFailureKind {
  offline,

  /// A **read** that went out and got no answer in time. The same page phase
  /// as [offline]; only the wording differs (S88d). A write never carries it.
  timedOut,

  /// The request was cancelled in flight. A write may or may not have been
  /// applied, so its idempotency key must survive for an identical retry.
  cancelled,

  /// A 2xx (or an error envelope) the client could not parse. The server may
  /// already have applied the write, so this is an unresolved outcome too.
  outcomeUnknown,
  unavailable,
  permissionDenied,
  notFound,
  stale,
  activationRequired,
  bootstrapRequired,
  resourceConflict,

  /// The token is already bound by another community that was not rejected
  /// (loop-api decision 0182, 「一币一社区」). Create, profile edit and
  /// resubmit can answer with it; nothing was applied.
  boundAssetTaken,
  validationFailed,
  aliasReserved,
  aliasBlocked,
  rateLimited,
  idempotencyConflict,
  invalidData,
  unexpected,
}

/// The rule every bound-token field states beside itself (loop-api decision
/// 0182): a token belongs to one community at a time; a rejected community
/// does not hold it.
String get communityBoundAssetUniqueHint =>
    LoopL10n.current.community_contractCommunityBoundAssetUniqueHint;

final class CommunityGatewayException implements Exception {
  const CommunityGatewayException(this.kind, {this.reasonCode, this.scope});

  final CommunityFailureKind kind;

  /// The rule the server named in `detailsSafe.reasonCode`, when it named
  /// one. A kind says what class of refusal it was; this says which refusal,
  /// and it is the only way a page can answer 「为什么」 with the server's own
  /// answer instead of a sentence for the whole class.
  final String? reasonCode;

  /// Which budget a `rateLimited` refusal was measured against, when the
  /// server named one. The caller's own minute and the community's day are
  /// two different waits.
  final String? scope;

  @override
  String toString() => 'CommunityGatewayException(${kind.name})';
}

/// Thrown by a model when a value would break the frozen contract. It never
/// carries the offending value.
final class InvalidCommunityContractException implements Exception {
  const InvalidCommunityContractException();

  @override
  String toString() => 'The community payload broke the V2 contract.';
}

/// Delivery mode of one port implementation. `preview` is the only mode that
/// may render the visible `演示数据` label.
enum CommunityGatewayMode { production, preview, unavailable }

/// The `{ "status": "unavailable", "reasonCode": … }` projection.
///
/// A field carrying this object renders an unavailable explanation. It never
/// renders `0`, a placeholder figure, or a fixture.
@immutable
final class LoopUnavailableFact {
  const LoopUnavailableFact(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopUnavailableFact && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

/// How many of a community's members are connected to Stream right now.
///
/// It is an observation, not a stored fact (Decision 0047): the count is the
/// members of the community's official Stream channel that hold a live
/// connection at the moment the detail page was read. It is not "watching this
/// channel", not "active recently", and not the community's membership. A
/// failed, timed-out or unprovisioned read is unavailable — never a zero, and
/// a real zero is a reading of its own.
@immutable
sealed class CommunityOnlineCount {
  const CommunityOnlineCount();
}

@immutable
final class CommunityOnlineCountUnavailable extends CommunityOnlineCount {
  const CommunityOnlineCountUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityOnlineCountUnavailable &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

@immutable
final class CommunityOnlineCountObserved extends CommunityOnlineCount {
  const CommunityOnlineCountObserved({
    required this.count,
    required this.observedAt,
    required this.source,
  });

  final int count;

  /// When the observation was taken. The page prints it in UTC, because a
  /// reading of "now" that is a minute old is still a reading of that minute.
  final DateTime observedAt;

  /// What was counted. The client reads the meaning off this and never off
  /// the number alone.
  final CommunityPresenceSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityOnlineCountObserved &&
          other.count == count &&
          other.observedAt == observedAt &&
          other.source == source;

  @override
  int get hashCode => Object.hash(count, observedAt, source);
}

/// The only observation the contract publishes: Stream channel members holding
/// a connection. A second source would mean a second sentence, so the client
/// refuses one it does not know.
enum CommunityPresenceSource {
  streamMemberPresence('stream_member_presence');

  const CommunityPresenceSource(this.wireName);

  final String wireName;

  static CommunityPresenceSource? tryParse(String value) {
    for (final source in values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// A mining power reading on a community, a member row or a connection row.
///
/// Either a settled snapshot computed it under a named formula version, or it
/// did not and only the server's own `reasonCode` exists. A row never falls
/// back to `0`: an account with no balance in the snapshot and an account the
/// snapshot never reached are different facts.
@immutable
sealed class LoopMiningPowerFact {
  const LoopMiningPowerFact();
}

@immutable
final class LoopMiningPowerUnavailable extends LoopMiningPowerFact {
  const LoopMiningPowerUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopMiningPowerUnavailable && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

/// A reading the settlement produced. What it is a reading *of* decides what
/// it can explain: a community's number is the sum over one bound asset, so
/// the weight and the head count behind it exist; a member's number is one
/// person across every asset, and no single community weight explains it.
@immutable
sealed class LoopMiningPowerSettled extends LoopMiningPowerFact {
  const LoopMiningPowerSettled({
    required this.power,
    required this.snapshotId,
    required this.formulaVersion,
    required this.computedAt,
    required this.scope,
    this.stale = false,
  });

  /// The server's own unsigned decimal string, rendered verbatim.
  final String power;
  final String snapshotId;

  /// A backend identifier. It belongs in a LoopDisclosure, never in a
  /// sentence.
  final String formulaVersion;
  final DateTime computedAt;

  /// The version's own declaration about itself. It is the only thing that
  /// may put the development-baseline label on a row — the version string is
  /// never read for meaning.
  final MiningFormulaScope scope;

  /// True when a later run under the same version did not complete, so this
  /// number is the last complete snapshot's and is older than that run
  /// (Decision 0057). The card dates the number instead of withdrawing it;
  /// why the later run stopped is on the mining page, not on this row.
  final bool stale;

  bool get isBaseline => scope.isBaseline;
}

/// A community's power: every unbanned member's power on the bound asset.
@immutable
final class LoopCommunityMiningPower extends LoopMiningPowerSettled {
  const LoopCommunityMiningPower({
    required super.power,
    required super.snapshotId,
    required super.formulaVersion,
    required super.computedAt,
    required super.scope,
    required this.weight,
    required this.participants,
    super.stale,
  });

  /// The reviewed weight already inside [power], in the same shape the mining
  /// panel reads.
  final MiningCommunityWeight weight;

  /// Members whose power was above zero.
  final MiningParticipants participants;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopCommunityMiningPower &&
          other.power == power &&
          other.snapshotId == snapshotId &&
          other.formulaVersion == formulaVersion &&
          other.computedAt == computedAt &&
          other.scope == scope &&
          other.stale == stale &&
          other.weight == weight &&
          other.participants == participants;

  @override
  int get hashCode => Object.hash(
    power,
    snapshotId,
    formulaVersion,
    computedAt,
    scope,
    stale,
    weight,
    participants,
  );
}

/// One account's total power across every asset it holds. It carries no
/// weight and no head count: there is no single community weight that could
/// explain a number summed across assets.
@immutable
final class LoopAccountMiningPower extends LoopMiningPowerSettled {
  const LoopAccountMiningPower({
    required super.power,
    required super.snapshotId,
    required super.formulaVersion,
    required super.computedAt,
    required super.scope,
    super.stale,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopAccountMiningPower &&
          other.power == power &&
          other.snapshotId == snapshotId &&
          other.formulaVersion == formulaVersion &&
          other.computedAt == computedAt &&
          other.scope == scope &&
          other.stale == stale;

  @override
  int get hashCode =>
      Object.hash(power, snapshotId, formulaVersion, computedAt, scope, stale);
}

/// The fixed four-field identity projection. No `profile_code`, wallet
/// address, Privy ID or Stream ID is ever part of it.
@immutable
final class LoopPublicProfile {
  const LoopPublicProfile({
    required this.publicProfileId,
    required this.loopId,
    required this.alias,
    required this.avatarRef,
  });

  /// The only accepted command target. `null` for a directory row that has no
  /// profile row: such a row is listed and counted but can never be the target
  /// of a governance action.
  final String? publicProfileId;
  final String loopId;
  final String? alias;
  final String? avatarRef;

  /// Alias when present, otherwise the LOOP ID. Never an invented value.
  String get displayName => alias ?? loopId;

  bool get isCommandTarget => publicProfileId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopPublicProfile &&
          other.publicProfileId == publicProfileId &&
          other.loopId == loopId &&
          other.alias == alias &&
          other.avatarRef == avatarRef;

  @override
  int get hashCode => Object.hash(publicProfileId, loopId, alias, avatarRef);
}

/// zh-CN copy for a failed community/social/search operation. It states what
/// did not happen; it never claims a result the server did not confirm.
String communityFailureReason(CommunityFailureKind? kind) => switch (kind) {
  CommunityFailureKind.offline => LoopL10n.current.community_contractOffline,
  CommunityFailureKind.timedOut => LoopL10n.current.community_contractTimedOut,
  CommunityFailureKind.cancelled =>
    LoopL10n.current.community_contractCancelled,
  CommunityFailureKind.outcomeUnknown =>
    LoopL10n.current.community_contractOutcomeUnknown,
  CommunityFailureKind.unavailable =>
    LoopL10n.current.community_contractUnavailable,
  CommunityFailureKind.permissionDenied =>
    LoopL10n.current.community_contractPermissionDenied,
  CommunityFailureKind.notFound => LoopL10n.current.community_contractNotFound,
  CommunityFailureKind.stale => LoopL10n.current.community_contractStale,
  CommunityFailureKind.activationRequired =>
    LoopL10n.current.community_contractActivationRequired,
  CommunityFailureKind.bootstrapRequired =>
    LoopL10n.current.community_contractBootstrapRequired,
  CommunityFailureKind.resourceConflict =>
    LoopL10n.current.community_contractResourceConflict,
  CommunityFailureKind.boundAssetTaken =>
    LoopL10n.current.community_contractBoundAssetTaken,
  CommunityFailureKind.validationFailed =>
    LoopL10n.current.community_contractValidationFailed,
  CommunityFailureKind.aliasReserved =>
    LoopL10n.current.community_contractAliasReserved,
  CommunityFailureKind.aliasBlocked =>
    LoopL10n.current.community_contractAliasBlocked,
  CommunityFailureKind.rateLimited =>
    LoopL10n.current.community_contractRateLimited,
  CommunityFailureKind.idempotencyConflict =>
    LoopL10n.current.community_contractIdempotencyConflict,
  CommunityFailureKind.invalidData =>
    LoopL10n.current.community_contractInvalidData,
  CommunityFailureKind.unexpected =>
    LoopL10n.current.community_contractUnexpected,
  null => LoopL10n.current.common_actionIncomplete,
};

/// Whether the write's outcome is unknown, so its idempotency key must be
/// replayed rather than replaced. A timeout, a lost connection, a cancelled
/// request and an unparsable response all leave the server free to have
/// applied the command already.
bool communityOutcomeIsUnresolved(CommunityFailureKind kind) =>
    kind == CommunityFailureKind.offline ||
    kind == CommunityFailureKind.timedOut ||
    kind == CommunityFailureKind.cancelled ||
    kind == CommunityFailureKind.outcomeUnknown;

/// zh-CN copy for a refused community application.
///
/// The five codes the create endpoint can answer with are mapped one by one:
/// a reserved or blocked name, a taken slug, a length rejection and a missing
/// LOOP ID activation each need a different next step from the applicant.
String communityApplyFailureReason(CommunityFailureKind? kind) =>
    switch (kind) {
      CommunityFailureKind.aliasReserved =>
        LoopL10n.current.community_contractAliasReserved2,
      CommunityFailureKind.aliasBlocked =>
        LoopL10n.current.community_contractAliasBlocked2,
      CommunityFailureKind.resourceConflict =>
        LoopL10n.current.community_contractResourceConflict2,
      CommunityFailureKind.boundAssetTaken =>
        LoopL10n.current.community_contractBoundAssetTaken2,
      CommunityFailureKind.validationFailed =>
        LoopL10n.current.community_contractValidationFailed2,
      CommunityFailureKind.activationRequired =>
        LoopL10n.current.community_contractActivationRequired2,
      _ => communityFailureReason(kind),
    };

/// zh-CN explanation for one server `reasonCode`. An unknown code keeps a
/// neutral sentence rather than inventing a cause.
String communityUnavailableReason(String reasonCode) => switch (reasonCode) {
  'STREAM_UNREAD_NOT_CONNECTED' => LoopL10n.current.community_contractSwitch,
  'STREAM_VOICE_NOT_CONNECTED' => LoopL10n.current.community_contractSwitch2,
  'STREAM_PRESENCE_NOT_CONNECTED' => LoopL10n.current.community_contractSwitch3,
  // The presence read has its own failure modes (Decision 0047). Each says
  // what was not done, and none of them is a zero.
  'COMMUNITY_CHANNEL_NOT_PROVISIONED' =>
    LoopL10n.current.community_contractSwitch4,
  'COMMUNITY_CHANNEL_PROVISION_FAILED' =>
    LoopL10n.current.community_contractSwitch5,
  'STREAM_PRESENCE_READ_FAILED' => LoopL10n.current.community_contractSwitch6,
  'STREAM_PRESENCE_READ_TIMEOUT' => LoopL10n.current.community_contractSwitch7,
  'STREAM_PRESENCE_MEMBER_BOUND_EXCEEDED' =>
    LoopL10n.current.community_contractSwitch8,
  'STREAM_PRESENCE_NOT_OBSERVED' => LoopL10n.current.community_contractSwitch9,
  'COMMUNICATION_RUNTIME_UNAVAILABLE' =>
    LoopL10n.current.community_contractSwitch10,
  'MINING_FORMULA_BASELINE_PENDING' =>
    LoopL10n.current.community_contractSwitch11,
  // The two discover orders and the row facts behind them (decision 0061).
  // None of them ever becomes a zero: a community nobody counted and a
  // community with nothing to count are different answers.
  'MINING_SNAPSHOT_NOT_AVAILABLE' =>
    LoopL10n.current.community_contractSwitch12,
  'MINING_SNAPSHOT_INCOMPLETE' => LoopL10n.current.community_contractSwitch13,
  'MINING_SNAPSHOT_STALE' => LoopL10n.current.community_contractSwitch14,
  'MINING_RUNTIME_UNAVAILABLE' => LoopL10n.current.community_contractSwitch15,
  'COMMUNITY_ACTIVITY_NOT_OBSERVED' =>
    LoopL10n.current.community_contractSwitch16,
  'COMMUNITY_ACTIVITY_CHANNEL_NOT_OBSERVED' =>
    LoopL10n.current.community_contractSwitch17,
  'COMMUNITY_ASSET_NOT_BOUND' => LoopL10n.current.community_contractSwitch18,
  'COMMUNITY_WEIGHT_PENDING_REVIEW' =>
    LoopL10n.current.community_contractSwitch19,
  'COMMUNITY_ANNOUNCEMENTS_DEFERRED' =>
    LoopL10n.current.community_contractSwitch20,
  'COMMUNITY_LINKS_DEFERRED' => LoopL10n.current.community_contractSwitch21,
  'MESSAGE_PREVIEW_DEFERRED' => LoopL10n.current.community_contractSwitch22,
  'AI_MODERATION_DEFERRED' => LoopL10n.current.community_aiModelsSwitch4,
  // The two search domains that still answer nothing do so for different
  // reasons, and 「还没有开放」 said both (device walkthrough 2026-09-23 ·
  // a63–a65): the Launch module is here and has no project directory to
  // search, while no DApp directory has been integrated at all. Backend
  // decision 0071 gave each its own code and opened the asset domain.
  'ASSET_REGISTRY_NOT_COMPOSED' => LoopL10n.current.community_contractSwitch23,
  'LAUNCH_PROJECT_DIRECTORY_PENDING' =>
    LoopL10n.current.community_contractSwitch24,
  'DAPP_DIRECTORY_NOT_INTEGRATED' =>
    LoopL10n.current.community_contractSwitch25,
  'REFERRAL_GRAPH_DEFERRED' => LoopL10n.current.community_contractSwitch26,
  'INVITE_CODE_DEFERRED' => LoopL10n.current.community_contractSwitch27,
  'COMMUNITY_RUNTIME_UNAVAILABLE' =>
    LoopL10n.current.community_contractSwitch28,
  'SEARCH_RUNTIME_UNAVAILABLE' => LoopL10n.current.community_contractSwitch29,
  _ => LoopL10n.current.common_itemUnavailable,
};
