import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';

/// Strict decoders for the projections shared by the S3 modules.
///
/// Every decoder goes through [LoopV2Contract.strictMap], so an unknown or a
/// missing field is an invalid payload rather than a partially trusted value.
abstract final class LoopV2ProjectionCodec {
  static final RegExp loopIdPattern = RegExp(r'^LOOP-[0-9A-HJKMNP-TV-Z]{8}$');
  static final RegExp aliasPattern = RegExp(
    r'^[^\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]+$',
    unicode: true,
  );
  static final RegExp avatarRefPattern = RegExp(
    r'^avatar:[A-Za-z0-9][A-Za-z0-9._/-]{0,126}$',
  );
  static final RegExp communityLogoPattern = RegExp(
    r'^avatar:preset/community-(0[1-9]|1[0-2])$',
  );
  static final RegExp slugPattern = RegExp(r'^[a-z0-9-]{3,32}$');
  static final RegExp boundAssetKeyPattern = RegExp(
    r'^eip155:[1-9][0-9]{0,9}:0x[0-9a-f]{40}$',
  );
  static final RegExp blockReasonPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  static final RegExp cursorPattern = RegExp(
    r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
  );
  static final RegExp boostPercentPattern = RegExp(r'^[0-9]+(\.[0-9]+)?$');
  static final RegExp miningDecimalPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,60})?$',
  );
  static final RegExp miningFormulaVersionPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$',
  );

  static const contractVersion = '2.0';
  static const maximumCursorLength = 1536;
  static const maximumTextLength = 1024;

  static Never invalid() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);

  static void requireContractVersion(Map<String, Object?> root) {
    if (root['contractVersion'] != contractVersion) invalid();
  }

  static bool requireBool(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! bool) invalid();
    return value;
  }

  static int requireCount(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! int || value < 0) invalid();
    return value;
  }

  static DateTime requireTimestamp(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String || value.length > 64) invalid();
    final parsed = DateTime.tryParse(value);
    if (parsed == null) invalid();
    return parsed.toUtc();
  }

  static String requireText(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String ||
        value.isEmpty ||
        value.length > maximumTextLength ||
        !aliasPattern.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  static String? optionalText(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value == null) return null;
    return requireText(source, key);
  }

  static String? optionalPattern(
    Map<String, Object?> source,
    String key,
    RegExp pattern,
  ) {
    final value = source[key];
    if (value == null) return null;
    if (value is! String || !pattern.hasMatch(value)) invalid();
    return value;
  }

  /// The cursor is opaque: it is shape-checked and then echoed verbatim.
  static String? cursor(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is! String ||
        value.length < 3 ||
        value.length > maximumCursorLength ||
        !cursorPattern.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  static LoopUnavailableFact unavailable(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'reasonCode',
    });
    if (map['status'] != 'unavailable') invalid();
    final reasonCode = map['reasonCode'];
    if (reasonCode is! String ||
        reasonCode.length > 64 ||
        !LoopV2Contract.reasonCodePattern.hasMatch(reasonCode)) {
      invalid();
    }
    return LoopUnavailableFact(reasonCode);
  }

  /// The `miningPower` projection shared by the community record, the member
  /// directory and the connection list. The settled branch must carry the
  /// snapshot and the version that produced the number; a bare power would be
  /// a figure with no source.
  ///
  /// `subject` decides the rest: a community's number carries the weight and
  /// the head count that explain it, an account's number carries neither,
  /// because no single community weight explains a total summed across
  /// assets. Either shape holding the other's fields is refused.
  static LoopMiningPowerFact miningPowerFact(Object? raw) {
    if (raw is! Map) invalid();
    if (raw['status'] != 'available') {
      return LoopMiningPowerUnavailable(unavailable(raw).reasonCode);
    }
    final subject = raw['subject'];
    if (subject == 'community') {
      final map = LoopV2Contract.strictMapWithOptional(raw, const <String>{
        'status',
        'subject',
        'power',
        'snapshotId',
        'formulaVersion',
        'computedAt',
        'scope',
        'weight',
        'participants',
      }, _miningStaleKey);
      return LoopCommunityMiningPower(
        power: _miningPower(map),
        snapshotId: _miningSnapshotId(map),
        formulaVersion: _miningFormulaVersion(map),
        computedAt: requireTimestamp(map, 'computedAt'),
        scope: LoopV2S7Codec.formulaScope(map),
        stale: _miningStale(map),
        weight: LoopV2S7Codec.communityWeight(map['weight']),
        participants: LoopV2S7Codec.participants(map['participants']),
      );
    }
    if (subject != 'account') invalid();
    final map = LoopV2Contract.strictMapWithOptional(raw, const <String>{
      'status',
      'subject',
      'power',
      'snapshotId',
      'formulaVersion',
      'computedAt',
      'scope',
    }, _miningStaleKey);
    return LoopAccountMiningPower(
      power: _miningPower(map),
      snapshotId: _miningSnapshotId(map),
      formulaVersion: _miningFormulaVersion(map),
      computedAt: requireTimestamp(map, 'computedAt'),
      scope: LoopV2S7Codec.formulaScope(map),
      stale: _miningStale(map),
    );
  }

  /// Added by Decision 0057 on both settled shapes. A deployment that does
  /// not send it is read exactly as before: no later run is known, so the
  /// number is not dated against one.
  static const Set<String> _miningStaleKey = <String>{'stale'};

  static bool _miningStale(Map<String, Object?> map) {
    if (!map.containsKey('stale')) return false;
    return LoopV2S7Codec.requireBool(map, 'stale');
  }

  static String _miningPower(Map<String, Object?> map) =>
      LoopV2Contract.requiredString(
        map,
        'power',
        pattern: miningDecimalPattern,
        maxLength: 140,
      );

  static String _miningSnapshotId(Map<String, Object?> map) =>
      LoopV2Contract.requiredString(
        map,
        'snapshotId',
        pattern: LoopV2Contract.uuidPattern,
      );

  static String _miningFormulaVersion(Map<String, Object?> map) =>
      LoopV2Contract.requiredString(
        map,
        'formulaVersion',
        pattern: miningFormulaVersionPattern,
        maxLength: 128,
      );

  /// [allowMissingId] is true only for the member directory, where a member
  /// without a profile row is listed but can never be a command target.
  static LoopPublicProfile profile(Object? raw, {bool allowMissingId = false}) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'publicProfileId',
      'loopId',
      'alias',
      'avatarRef',
    });
    final rawId = map['publicProfileId'];
    String? publicProfileId;
    if (rawId == null) {
      if (!allowMissingId) invalid();
    } else {
      if (rawId is! String || !LoopV2Contract.uuidPattern.hasMatch(rawId)) {
        invalid();
      }
      publicProfileId = rawId;
    }
    return LoopPublicProfile(
      publicProfileId: publicProfileId,
      loopId: LoopV2Contract.requiredString(
        map,
        'loopId',
        pattern: loopIdPattern,
      ),
      alias: optionalText(map, 'alias'),
      avatarRef: optionalPattern(map, 'avatarRef', avatarRefPattern),
    );
  }

  static const _communityKeys = <String>{
    'communityId',
    'name',
    'slug',
    'description',
    'logoRef',
    'verificationStatus',
    'boundAssetKey',
    'memberCount',
    'createdAt',
    'configVersion',
  };

  static CommunitySummary community(Object? raw) =>
      _community(LoopV2Contract.strictMap(raw, _communityKeys));

  /// One row of `GET /v2/communities`, which carries the fact the page was
  /// ordered by and nothing else (decision 0061).
  ///
  /// [sort] is the order the **response** declared, not the one the request
  /// asked for: a row carrying the other sort's fact, or a stored sort's row
  /// carrying either, is a projection whose provenance the page cannot state,
  /// so it is refused rather than half-read.
  static CommunitySummary communityRow(
    Object? raw, {
    required CommunityDirectorySort sort,
  }) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      _communityKeys,
      const <String>{'miningPower', 'activity'},
    );
    final power = map.containsKey('miningPower')
        ? miningPowerFact(map['miningPower'])
        : null;
    final activityFact = map.containsKey('activity')
        ? communityActivity(map['activity'])
        : null;
    switch (sort) {
      case CommunityDirectorySort.miningPower:
        if (power == null || activityFact != null) invalid();
      case CommunityDirectorySort.activity:
        if (activityFact == null || power != null) invalid();
      case CommunityDirectorySort.members:
      case CommunityDirectorySort.newest:
        if (power != null || activityFact != null) invalid();
    }
    // A community's power is a sum over its bound asset; an account's is not
    // a fact about the community, so a row carrying one cannot be ranked.
    if (power is LoopAccountMiningPower) invalid();
    return _community(map, miningPower: power, activity: activityFact);
  }

  /// `activity` on a discover row: a counted window, or the reason the
  /// channel was not read. A row without a fresh reading is never a zero.
  static CommunityActivityFact communityActivity(Object? raw) {
    if (raw is! Map) invalid();
    if (raw['status'] != 'available') {
      return CommunityActivityUnavailable(unavailable(raw).reasonCode);
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'messageCount',
      'windowDays',
      'bounded',
      'observedAt',
    });
    final windowDays = requireCount(map, 'windowDays');
    if (windowDays < 1 || windowDays > 365) invalid();
    return CommunityActivityCount(
      messageCount: requireCount(map, 'messageCount'),
      windowDays: windowDays,
      bounded: requireBool(map, 'bounded'),
      observedAt: requireTimestamp(map, 'observedAt'),
    );
  }

  /// `ordering` on `GET /v2/communities`: what the page was ordered by, and
  /// on which measured fact.
  ///
  /// [requested] is the sort the request carried. A deployment predating
  /// decision 0061 sends no `ordering` at all, and its only two sorts are the
  /// stored columns, so the absent key is read as exactly that — the reading
  /// this client already made of those responses. It can be tightened to a
  /// required key once every deployment answers it.
  static CommunityOrdering communityOrdering(
    Object? raw, {
    required CommunityDirectorySort requested,
  }) {
    if (raw == null) {
      return CommunityOrderingApplied(
        sort: requested,
        basis: const CommunityStoredBasis(),
      );
    }
    if (raw is! Map) invalid();
    final rawSort = raw['sort'];
    if (rawSort is! String) invalid();
    final sort = CommunityDirectorySort.tryParse(rawSort);
    // The page states the order it applied; a page ordered by something else
    // than what was asked for would be silently answering another question.
    if (sort == null || sort != requested) invalid();
    if (raw['status'] != 'available') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'sort',
        'reasonCode',
      });
      if (map['status'] != 'unavailable') invalid();
      final reasonCode = map['reasonCode'];
      if (reasonCode is! String ||
          reasonCode.length > 64 ||
          !LoopV2Contract.reasonCodePattern.hasMatch(reasonCode)) {
        invalid();
      }
      return CommunityOrderingUnavailable(sort: sort, reasonCode: reasonCode);
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'sort',
      'basis',
    });
    return CommunityOrderingApplied(
      sort: sort,
      basis: _orderingBasis(map['basis'], sort: sort),
    );
  }

  static CommunityOrderingBasis _orderingBasis(
    Object? raw, {
    required CommunityDirectorySort sort,
  }) {
    if (raw is! Map) invalid();
    final kind = raw['kind'];
    switch (kind) {
      case 'stored':
        LoopV2Contract.strictMap(raw, const <String>{'kind'});
        if (sort.carriesRowFact) invalid();
        return const CommunityStoredBasis();
      case 'miningSnapshot':
        if (sort != CommunityDirectorySort.miningPower) invalid();
        final map = LoopV2Contract.strictMap(raw, const <String>{
          'kind',
          'snapshotId',
          'formulaVersion',
          'computedAt',
          'scope',
          'stale',
        });
        return CommunityMiningBasis(
          snapshotId: LoopV2Contract.requiredString(
            map,
            'snapshotId',
            pattern: LoopV2Contract.uuidPattern,
          ),
          formulaVersion: LoopV2Contract.requiredString(
            map,
            'formulaVersion',
            pattern: miningFormulaVersionPattern,
            maxLength: 128,
          ),
          computedAt: requireTimestamp(map, 'computedAt'),
          scope: LoopV2S7Codec.formulaScope(map),
          stale: requireBool(map, 'stale'),
        );
      case 'channelActivity':
        if (sort != CommunityDirectorySort.activity) invalid();
        final map = LoopV2Contract.strictMap(raw, const <String>{
          'kind',
          'windowDays',
          'observedCommunityCount',
          'observedAt',
        });
        final windowDays = requireCount(map, 'windowDays');
        if (windowDays < 1 || windowDays > 365) invalid();
        return CommunityActivityBasis(
          windowDays: windowDays,
          observedCommunityCount: requireCount(map, 'observedCommunityCount'),
          observedAt: requireTimestamp(map, 'observedAt'),
        );
      default:
        invalid();
    }
  }

  static CommunitySummary _community(
    Map<String, Object?> map, {
    LoopMiningPowerFact? miningPower,
    CommunityActivityFact? activity,
  }) {
    final verification = map['verificationStatus'];
    final configVersion = map['configVersion'];
    if (verification is! String || configVersion != 'communityV1') invalid();
    final status = CommunityVerification.tryParse(verification);
    if (status == null) invalid();
    return CommunitySummary(
      communityId: LoopV2Contract.requiredString(
        map,
        'communityId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      name: requireText(map, 'name'),
      slug: LoopV2Contract.requiredString(map, 'slug', pattern: slugPattern),
      description: optionalText(map, 'description'),
      logoRef: optionalPattern(map, 'logoRef', communityLogoPattern),
      verificationStatus: status,
      boundAssetKey: optionalPattern(
        map,
        'boundAssetKey',
        boundAssetKeyPattern,
      ),
      memberCount: requireCount(map, 'memberCount'),
      createdAt: requireTimestamp(map, 'createdAt'),
      configVersion: configVersion as String,
      miningPower: miningPower,
      activity: activity,
    );
  }

  static CommunityMembership membership(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'role',
      'status',
      'joinedAt',
    });
    final rawRole = map['role'];
    final rawStatus = map['status'];
    if (rawRole is! String || rawStatus is! String) invalid();
    final role = CommunityRole.tryParse(rawRole);
    final status = CommunityMemberStatus.tryParse(rawStatus);
    if (role == null || status == null) invalid();
    return CommunityMembership(
      role: role,
      status: status,
      joinedAt: requireTimestamp(map, 'joinedAt'),
    );
  }

  static CommunityViewer viewer(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'membership',
      'canInviteAdmin',
      'canMute',
      'canBan',
    });
    final rawMembership = map['membership'];
    return CommunityViewer(
      membership: rawMembership == null ? null : membership(rawMembership),
      canInviteAdmin: requireBool(map, 'canInviteAdmin'),
      canMute: requireBool(map, 'canMute'),
      canBan: requireBool(map, 'canBan'),
    );
  }

  static CommunityRecommendation recommendation(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'recommendationId',
      'ruleVersion',
    });
    final ruleVersion = map['ruleVersion'];
    if (ruleVersion != 'rule:verified-members-v1') invalid();
    return CommunityRecommendation(
      recommendationId: LoopV2Contract.requiredString(
        map,
        'recommendationId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      ruleVersion: ruleVersion! as String,
    );
  }

  static List<Object?> requireList(Object? raw, {int maximum = 200}) {
    if (raw is! List || raw.length > maximum) invalid();
    return raw;
  }

  static final RegExp communityChannelCidPattern = RegExp(
    r'^messaging:loop_community_[0-9a-f]{32}$',
  );

  /// The `chat` section of a community record.
  ///
  /// Only `available` may carry a channel CID, and it must carry one. Any other
  /// pairing is a contract break rather than a partially trusted projection.
  static CommunityChatSection chatSection(Object? raw) {
    // `viewerPersona` (decision 0055) is stated on all three chat statuses by
    // a current server. It is read as optional only so the recorded responses
    // this client is replayed against — captured before the field existed —
    // still decode; an absent key carries the same meaning as the explicit
    // `null` the server sends for a non-member, and nothing else about the
    // section is relaxed.
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'status', 'channelCid', 'memberState', 'reasonCode'},
      const <String>{'viewerPersona'},
    );
    final rawStatus = map['status'];
    if (rawStatus is! String) invalid();
    final status = CommunityChatStatus.tryParse(rawStatus);
    if (status == null) invalid();
    final channelCid = optionalPattern(
      map,
      'channelCid',
      communityChannelCidPattern,
    );
    if ((status == CommunityChatStatus.available) != (channelCid != null)) {
      invalid();
    }
    final rawMemberState = map['memberState'];
    CommunityChatMemberState? memberState;
    if (rawMemberState != null) {
      if (rawMemberState is! String) invalid();
      memberState = CommunityChatMemberState.tryParse(rawMemberState);
      if (memberState == null) invalid();
    }
    return CommunityChatSection(
      status: status,
      channelCid: channelCid,
      memberState: memberState,
      reasonCode: reasonCode(map, 'reasonCode'),
      viewerPersona: chatViewerPersona(map['viewerPersona']),
    );
  }

  /// The reader's own name in one community's official group (decision 0055).
  ///
  /// `null` is a stated absence — not yet issued, or not a member — and is
  /// decoded as such. Anything else must be the exact pair the contract
  /// names; a persona LOOP cannot read is not replaced by a guess.
  static CommunityChatPersona? chatViewerPersona(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'alias',
      'projectionState',
    });
    final alias = map['alias'];
    if (alias is! String ||
        alias.isEmpty ||
        alias.length > 64 ||
        alias != alias.trim() ||
        !aliasPattern.hasMatch(alias)) {
      invalid();
    }
    final rawProjection = map['projectionState'];
    if (rawProjection is! String) invalid();
    final projectionState = CommunityChatPersonaProjection.tryParse(
      rawProjection,
    );
    if (projectionState == null) invalid();
    return CommunityChatPersona(alias: alias, projectionState: projectionState);
  }

  static CommunityVoiceSection voiceSection(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'currentRoomId',
      'reasonCode',
    });
    final rawStatus = map['status'];
    if (rawStatus is! String) invalid();
    final status = CommunityVoiceStatus.tryParse(rawStatus);
    if (status == null) invalid();
    final currentRoomId = optionalPattern(
      map,
      'currentRoomId',
      LoopV2Contract.uuidPattern,
    );
    if ((status == CommunityVoiceStatus.available) != (currentRoomId != null)) {
      invalid();
    }
    return CommunityVoiceSection(
      status: status,
      currentRoomId: currentRoomId,
      reasonCode: reasonCode(map, 'reasonCode'),
    );
  }

  /// A nullable server `reasonCode`. It is shape-checked and then rendered
  /// verbatim; the client never invents one of its own.
  static String? reasonCode(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is! String ||
        value.length > 64 ||
        !LoopV2Contract.reasonCodePattern.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  /// `onlineCount`: an observation, or the server's reason for not having one.
  ///
  /// The available branch is only produced by the detail read; every write
  /// answers the unavailable branch with `STREAM_PRESENCE_NOT_OBSERVED`, and
  /// a failed or timed-out read answers its own code. A zero here is a real
  /// reading — nobody was connected — and is never used to stand in for an
  /// absent one.
  static CommunityOnlineCount onlineCount(Object? raw) {
    if (raw is! Map) invalid();
    if (raw['status'] != 'available') {
      return CommunityOnlineCountUnavailable(unavailable(raw).reasonCode);
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'count',
      'observedAt',
      'source',
    });
    final rawSource = map['source'];
    if (rawSource is! String) invalid();
    final source = CommunityPresenceSource.tryParse(rawSource);
    // A source the client does not know is a different fact under the same
    // name, so the page states none at all.
    if (source == null) invalid();
    return CommunityOnlineCountObserved(
      count: requireCount(map, 'count'),
      observedAt: requireTimestamp(map, 'observedAt'),
      source: source,
    );
  }

  /// An announcement identifier. It is opaque: the client keys a row with it
  /// and never parses it.
  static final RegExp announcementIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$',
  );

  /// The server's own name for the sort of announcement a row is. It picks a
  /// glyph and nothing else, so it is shape-checked rather than enumerated.
  static final RegExp announcementKindPattern = RegExp(
    r'^[a-z][A-Za-z0-9_]{0,31}$',
  );

  /// An official link. `https://` only, and never one carrying credentials.
  static final RegExp officialLinkUrlPattern = RegExp(r'^https://[^\s]+$');

  /// `announcements`: the community's own published list, or the server's
  /// reason for having none.
  ///
  /// The available branch is strict on every axis a row is read by: a missing
  /// field, a malformed identifier, a repeated one, an unreadable time or a
  /// list longer than a page can carry is a contract break rather than a
  /// partially rendered board.
  static CommunityAnnouncementFeed announcements(Object? raw) {
    if (raw is! Map) invalid();
    if (raw['status'] != 'available') {
      return CommunityAnnouncementFeedUnavailable(unavailable(raw).reasonCode);
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'items',
    });
    final items = <CommunityAnnouncement>[];
    final seen = <String>{};
    for (final entry in requireList(map['items'], maximum: 50)) {
      final item = LoopV2Contract.strictMap(entry, const <String>{
        'announcementId',
        'kind',
        'title',
        'byline',
        'publishedAt',
        'pinned',
      });
      final announcementId = item['announcementId'];
      if (announcementId is! String ||
          !announcementIdPattern.hasMatch(announcementId) ||
          !seen.add(announcementId)) {
        invalid();
      }
      final kind = item['kind'];
      if (kind is! String || !announcementKindPattern.hasMatch(kind)) {
        invalid();
      }
      items.add(
        CommunityAnnouncement(
          announcementId: announcementId,
          kind: kind,
          title: requireText(item, 'title'),
          byline: optionalText(item, 'byline'),
          publishedAt: requireTimestamp(item, 'publishedAt'),
          pinned: requireBool(item, 'pinned'),
        ),
      );
    }
    return CommunityAnnouncementFeedPublished(items);
  }

  /// `officialLinks`: the links the community publishes, or the server's
  /// reason for publishing none. A link that is not `https://`, or that
  /// carries credentials, is refused rather than shown.
  static CommunityOfficialLinkList officialLinks(Object? raw) {
    if (raw is! Map) invalid();
    if (raw['status'] != 'available') {
      return CommunityOfficialLinksUnavailable(unavailable(raw).reasonCode);
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'items',
    });
    final items = <CommunityOfficialLink>[];
    final seen = <String>{};
    for (final entry in requireList(map['items'], maximum: 12)) {
      final item = LoopV2Contract.strictMap(entry, const <String>{
        'label',
        'url',
      });
      final label = requireText(item, 'label');
      final url = item['url'];
      if (label.length > 32 ||
          url is! String ||
          url.length < 9 ||
          url.length > 512 ||
          url.contains('@') ||
          !officialLinkUrlPattern.hasMatch(url) ||
          !aliasPattern.hasMatch(url) ||
          !seen.add(url)) {
        invalid();
      }
      items.add(CommunityOfficialLink(label: label, url: url));
    }
    return CommunityOfficialLinksPublished(items);
  }

  static CommunityDetail detail(Map<String, Object?> root) {
    return CommunityDetail(
      community: community(root['community']),
      viewer: viewer(root['viewer']),
      miningPower: miningPowerFact(root['miningPower']),
      onlineCount: onlineCount(root['onlineCount']),
      announcements: announcements(root['announcements']),
      officialLinks: officialLinks(root['officialLinks']),
      chat: chatSection(root['chat']),
      voice: voiceSection(root['voice']),
    );
  }

  static const detailKeys = <String>{
    'community',
    'viewer',
    'miningPower',
    'onlineCount',
    'announcements',
    'officialLinks',
    'chat',
    'voice',
    'contractVersion',
  };

  static const memberDirectoryKeys = <String>{
    'community',
    'viewer',
    'counts',
    'items',
    'nextCursor',
    'contractVersion',
  };

  /// A member row's published governance commands.
  ///
  /// The list is taken verbatim, in the server's order. It is strict on every
  /// axis: a missing field, a non-list, a non-string element, a name this
  /// build does not know, a repeat, or more entries than commands exist is a
  /// contract break, not a value to be salvaged. Rendering a half-understood
  /// governance list is exactly the drift this field exists to stop.
  static List<CommunityGovernanceAction> governanceActions(Object? raw) {
    if (raw is! List || raw.length > CommunityGovernanceAction.values.length) {
      invalid();
    }
    final actions = <CommunityGovernanceAction>[];
    for (final Object? entry in raw) {
      if (entry is! String) invalid();
      final action = CommunityGovernanceAction.tryParse(entry);
      if (action == null || actions.contains(action)) invalid();
      actions.add(action);
    }
    return List<CommunityGovernanceAction>.unmodifiable(actions);
  }

  static CommunityMemberDirectory memberDirectory(Map<String, Object?> root) {
    final counts = LoopV2Contract.strictMap(root['counts'], const <String>{
      'all',
      'owner',
      'admin',
      'online',
    });
    final items = <CommunityMemberEntry>[];
    final seen = <String>{};
    for (final raw in requireList(root['items'], maximum: 50)) {
      final item = LoopV2Contract.strictMap(raw, const <String>{
        'profile',
        'role',
        'status',
        'joinedAt',
        'isSelf',
        'actions',
        'miningPower',
      });
      final rawRole = item['role'];
      final rawStatus = item['status'];
      if (rawRole is! String || rawStatus is! String) invalid();
      final role = CommunityRole.tryParse(rawRole);
      final status = CommunityMemberStatus.tryParse(rawStatus);
      if (role == null || status == null) invalid();
      final entryProfile = profile(item['profile'], allowMissingId: true);
      final identity = entryProfile.publicProfileId ?? entryProfile.loopId;
      if (!seen.add(identity)) invalid();
      items.add(
        CommunityMemberEntry(
          profile: entryProfile,
          role: role,
          status: status,
          joinedAt: requireTimestamp(item, 'joinedAt'),
          isSelf: requireBool(item, 'isSelf'),
          actions: governanceActions(item['actions']),
          miningPower: miningPowerFact(item['miningPower']),
        ),
      );
    }
    return CommunityMemberDirectory(
      community: community(root['community']),
      viewer: viewer(root['viewer']),
      counts: CommunityMemberCounts(
        all: requireCount(counts, 'all'),
        owner: requireCount(counts, 'owner'),
        admin: requireCount(counts, 'admin'),
        online: unavailable(counts['online']),
      ),
      items: List<CommunityMemberEntry>.unmodifiable(items),
      nextCursor: cursor(root, 'nextCursor'),
    );
  }
}
