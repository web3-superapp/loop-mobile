import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';

enum GroupAliasGatewayMode { unavailable, preview, production }

enum GroupAliasGatewayFailureKind {
  unavailable,
  notFound,
  immutable,
  taken,
  invalidData,
  outcomeUnknown,
  unexpected,
}

final class GroupAliasGatewayException implements Exception {
  const GroupAliasGatewayException(this.kind);

  final GroupAliasGatewayFailureKind kind;

  String get code => switch (kind) {
    GroupAliasGatewayFailureKind.unavailable => 'group_alias_unavailable',
    GroupAliasGatewayFailureKind.notFound => 'group_alias_not_found',
    GroupAliasGatewayFailureKind.immutable => 'group_alias_immutable',
    GroupAliasGatewayFailureKind.taken => 'group_alias_taken',
    GroupAliasGatewayFailureKind.invalidData => 'invalid_group_alias_data',
    GroupAliasGatewayFailureKind.outcomeUnknown =>
      'group_alias_outcome_unknown',
    GroupAliasGatewayFailureKind.unexpected => 'group_alias_request_failed',
  };

  @override
  String toString() => code;
}

/// Group-only Alias seam.
///
/// [GroupId] must come from backend group creation or the reviewed legacy-group
/// resolver. A direct channel ID, Stream CID, Stream user ID, or account-level
/// profile identifier must never be converted into this port.
abstract interface class GroupAliasGateway {
  GroupAliasGatewayMode get mode;

  Future<GroupAliasResource> loadCurrentAlias(GroupId groupId);

  /// Reserves the first Alias permanently or retries the exact same normalized
  /// value to converge a pending Stream projection.
  ///
  /// An adapter must return [GroupAliasGatewayFailureKind.outcomeUnknown] for a
  /// timeout or transport/service response that cannot prove whether this PUT
  /// committed. It may use `unavailable` only when it can prove the write was
  /// not submitted. This method never accepts an idempotency key.
  Future<GroupAliasResource> putCurrentAlias({
    required GroupId groupId,
    required String normalizedAlias,
  });

  Future<GroupAliasSearchPage> searchAliases({
    required GroupId groupId,
    required String normalizedPrefix,
    required int limit,
  });
}

/// Optional production capability for recovering a LOOP [GroupId] from an
/// existing Stream group after process restart.
///
/// This is separate from [GroupAliasGateway] so preview/in-memory gateways do
/// not accidentally claim that they can verify Stream membership.
abstract interface class GroupAliasResolverGateway {
  GroupAliasGatewayMode get mode;

  Future<GroupId> resolveGroup(GroupAliasStreamChannelId channelId);
}

final class UnavailableGroupAliasResolverGateway
    implements GroupAliasResolverGateway {
  const UnavailableGroupAliasResolverGateway();

  @override
  GroupAliasGatewayMode get mode => GroupAliasGatewayMode.unavailable;

  @override
  Future<GroupId> resolveGroup(GroupAliasStreamChannelId channelId) =>
      Future<GroupId>.error(
        const GroupAliasGatewayException(
          GroupAliasGatewayFailureKind.unavailable,
        ),
      );
}

/// Production-safe default until an authenticated adapter is composed.
final class UnavailableGroupAliasGateway implements GroupAliasGateway {
  const UnavailableGroupAliasGateway();

  @override
  GroupAliasGatewayMode get mode => GroupAliasGatewayMode.unavailable;

  @override
  Future<GroupAliasResource> loadCurrentAlias(GroupId groupId) =>
      Future<GroupAliasResource>.error(
        const GroupAliasGatewayException(
          GroupAliasGatewayFailureKind.unavailable,
        ),
      );

  @override
  Future<GroupAliasResource> putCurrentAlias({
    required GroupId groupId,
    required String normalizedAlias,
  }) => Future<GroupAliasResource>.error(
    const GroupAliasGatewayException(GroupAliasGatewayFailureKind.unavailable),
  );

  @override
  Future<GroupAliasSearchPage> searchAliases({
    required GroupId groupId,
    required String normalizedPrefix,
    required int limit,
  }) => Future<GroupAliasSearchPage>.error(
    const GroupAliasGatewayException(GroupAliasGatewayFailureKind.unavailable),
  );
}

final groupAliasGatewayProvider = Provider<GroupAliasGateway>(
  (ref) => const UnavailableGroupAliasGateway(),
);

final groupAliasResolverGatewayProvider = Provider<GroupAliasResolverGateway>((
  ref,
) {
  final gateway = ref.watch(groupAliasGatewayProvider);
  if (gateway is GroupAliasResolverGateway) {
    // Dart cannot represent the intersection of these two unrelated gateway
    // interfaces in the promoted variable's static type.
    return gateway as GroupAliasResolverGateway;
  }
  return const UnavailableGroupAliasResolverGateway();
});
