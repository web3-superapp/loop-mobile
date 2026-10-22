import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

/// Strict codec for `GET /v2/profiles/{publicProfileId}/communities`
/// (decision 0218, loop-api S260).
///
/// Two exact shapes and nothing else:
///
/// * `{status: "available", items, nextCursor, contractVersion}`;
/// * `{status: "unavailable", reasonCode: "PROFILE_COMMUNITIES_HIDDEN",
///   contractVersion}` — the account keeps its list to itself.
///
/// Every row carries all seven keys; an extra or missing key, a repeated
/// community or a verification state other than the two the route states is
/// a broken page, never a half-shown one.
abstract final class LoopV2ProfileCommunitiesCodec {
  static const availableKeys = <String>{
    'status',
    'items',
    'nextCursor',
    'contractVersion',
  };
  static const unavailableKeys = <String>{
    'status',
    'reasonCode',
    'contractVersion',
  };
  static const itemKeys = <String>{
    'communityId',
    'name',
    'slug',
    'logoRef',
    'memberCount',
    'verificationStatus',
    'joinedAt',
  };

  /// Client-first tail (decision 0239): absent, `null` and `""` are no label.
  static const itemOptionalKeys = <String>{'label'};

  static const hiddenReasonCode = 'PROFILE_COMMUNITIES_HIDDEN';
  static final RegExp reasonCodePattern = RegExp(r'^[A-Z][A-Z0-9_]{0,63}$');
  static const maximumItems = 200;

  static ProfileCommunitiesPage page(Object? raw) {
    if (raw is! Map) LoopV2ProjectionCodec.invalid();
    switch (raw['status']) {
      case 'available':
        final map = LoopV2Contract.strictMap(raw, availableKeys);
        LoopV2ProjectionCodec.requireContractVersion(map);
        final items = LoopV2ProjectionCodec.requireList(
          map['items'],
          maximum: maximumItems,
        );
        final rows = <ProfileCommunity>[for (final item in items) row(item)];
        final ids = rows.map((item) => item.communityId).toSet();
        if (ids.length != rows.length) LoopV2ProjectionCodec.invalid();
        return ProfileCommunitiesPage.available(
          items: List<ProfileCommunity>.unmodifiable(rows),
          nextCursor: LoopV2ProjectionCodec.cursor(map, 'nextCursor'),
        );
      case 'unavailable':
        final map = LoopV2Contract.strictMap(raw, unavailableKeys);
        LoopV2ProjectionCodec.requireContractVersion(map);
        final reason = map['reasonCode'];
        if (reason is! String || !reasonCodePattern.hasMatch(reason)) {
          LoopV2ProjectionCodec.invalid();
        }
        // Any stated reason reads as "not shown to you"; the page has one
        // sentence for it whichever code a later server picks.
        return ProfileCommunitiesPage.hidden(reason);
      default:
        LoopV2ProjectionCodec.invalid();
    }
  }

  static ProfileCommunity row(Object? raw) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      itemKeys,
      itemOptionalKeys,
    );
    final verification = ProfileCommunityVerification.tryParse(
      map['verificationStatus'],
    );
    if (verification == null) LoopV2ProjectionCodec.invalid();
    return ProfileCommunity(
      communityId: LoopV2Contract.requiredString(
        map,
        'communityId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      name: LoopV2ProjectionCodec.requireText(map, 'name'),
      slug: LoopV2Contract.requiredString(
        map,
        'slug',
        pattern: LoopV2ProjectionCodec.slugPattern,
      ),
      logoRef: LoopV2ProjectionCodec.optionalPattern(
        map,
        'logoRef',
        LoopV2ProjectionCodec.communityLogoPattern,
      ),
      memberCount: LoopV2ProjectionCodec.requireCount(map, 'memberCount'),
      verificationStatus: verification,
      joinedAt: LoopV2ProjectionCodec.requireTimestamp(map, 'joinedAt'),
      label: communityLabelFromWire(map['label']),
    );
  }
}
