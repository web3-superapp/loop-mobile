import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

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

  static CommunitySummary community(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
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
    });
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

  static CommunityDetail detail(Map<String, Object?> root) {
    return CommunityDetail(
      community: community(root['community']),
      viewer: viewer(root['viewer']),
      miningPower: unavailable(root['miningPower']),
      onlineCount: unavailable(root['onlineCount']),
      announcements: unavailable(root['announcements']),
      officialLinks: unavailable(root['officialLinks']),
    );
  }

  static const detailKeys = <String>{
    'community',
    'viewer',
    'miningPower',
    'onlineCount',
    'announcements',
    'officialLinks',
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
          miningPower: unavailable(item['miningPower']),
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
