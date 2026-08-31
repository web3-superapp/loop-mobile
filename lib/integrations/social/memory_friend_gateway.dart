import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';

/// Explicit, process-local friend directory for Development Preview and tests.
///
/// It never creates a Stream channel, sends a provider request, or claims that
/// the other Preview account accepted a request.
final class MemoryFriendGateway implements FriendGateway {
  MemoryFriendGateway({Iterable<FriendSearchResult>? initialDirectory})
    : _directory = <FriendProfileRef, FriendSearchResult>{
        for (final result in validateFriendSearchResults(
          initialDirectory ?? developmentPreviewFriendDirectory,
        ))
          result.identity.profileRef: result,
      };

  final Map<FriendProfileRef, FriendSearchResult> _directory;
  final List<CreatedFriendGroup> _createdGroups = <CreatedFriendGroup>[];
  final Map<String, FriendProfileRef> _friendRequestTargets =
      <String, FriendProfileRef>{};
  final Map<String, CreatedFriendGroup> _groupReceipts =
      <String, CreatedFriendGroup>{};

  @override
  FriendGatewayMode get mode => FriendGatewayMode.preview;

  List<CreatedFriendGroup> get createdGroups =>
      List<CreatedFriendGroup>.unmodifiable(
        _createdGroups.map(CreatedFriendGroup.copyOf),
      );

  @override
  Future<List<FriendIdentity>> loadFriends() async {
    return validateFriendDirectory(
      _directory.values
          .where((result) => result.relationship == FriendRelationship.friend)
          .map((result) => result.identity),
    );
  }

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) async {
    late final String query;
    try {
      query = normalizeFriendAliasQuery(normalizedQuery).toLowerCase();
    } on InvalidFriendContractException {
      throw const FriendGatewayException(FriendGatewayFailureKind.invalidData);
    }
    return validateFriendSearchResults(
      _directory.values.where(
        (result) => result.identity.alias.toLowerCase().contains(query),
      ),
    );
  }

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) async {
    try {
      validateFriendOperationId(requestId);
    } on InvalidFriendContractException {
      throw const FriendGatewayException(FriendGatewayFailureKind.invalidData);
    }
    final previousTarget = _friendRequestTargets[requestId];
    if (previousTarget != null && previousTarget != profileRef) {
      throw const FriendGatewayException(FriendGatewayFailureKind.conflict);
    }
    final current = _directory[profileRef];
    if (current == null) {
      throw const FriendGatewayException(FriendGatewayFailureKind.notFound);
    }
    if (current.relationship != FriendRelationship.none) {
      _friendRequestTargets[requestId] = profileRef;
      return FriendSearchResult.copyOf(current);
    }
    final updated = FriendSearchResult(
      identity: current.identity,
      relationship: FriendRelationship.requestPending,
    );
    _friendRequestTargets[requestId] = profileRef;
    _directory[profileRef] = updated;
    return FriendSearchResult.copyOf(updated);
  }

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async {
    late final String name;
    late final List<FriendProfileRef> selected;
    try {
      validateFriendOperationId(requestId);
      name = normalizeFriendDisplayName(normalizedName);
      selected = validateSelectedFriendRefs(friendRefs);
    } on InvalidFriendContractException {
      throw const FriendGatewayException(FriendGatewayFailureKind.invalidData);
    }
    final previousReceipt = _groupReceipts[requestId];
    if (previousReceipt != null) {
      if (previousReceipt.name == name &&
          _sameOrderedValues(previousReceipt.friendRefs, selected)) {
        return CreatedFriendGroup.copyOf(previousReceipt);
      }
      throw const FriendGatewayException(FriendGatewayFailureKind.conflict);
    }
    if (selected.any(
      (profileRef) =>
          _directory[profileRef]?.relationship != FriendRelationship.friend,
    )) {
      throw const FriendGatewayException(
        FriendGatewayFailureKind.permissionDenied,
      );
    }
    final receipt = CreatedFriendGroup(
      requestId: requestId,
      name: name,
      friendRefs: selected,
      streamCid: null,
    );
    _groupReceipts[requestId] = receipt;
    _createdGroups.add(receipt);
    return CreatedFriendGroup.copyOf(receipt);
  }
}

bool _sameOrderedValues(
  List<FriendProfileRef> left,
  List<FriendProfileRef> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final developmentPreviewFriendDirectory = <FriendSearchResult>[
  FriendSearchResult(
    identity: FriendIdentity(
      profileRef: FriendProfileRef.fromWire('preview-profile-nightowl'),
      alias: 'NightOwl',
      colorSeed: 2,
    ),
    relationship: FriendRelationship.friend,
  ),
  FriendSearchResult(
    identity: FriendIdentity(
      profileRef: FriendProfileRef.fromWire('preview-profile-sable'),
      alias: '0xSable',
      colorSeed: 4,
    ),
    relationship: FriendRelationship.friend,
  ),
  FriendSearchResult(
    identity: FriendIdentity(
      profileRef: FriendProfileRef.fromWire('preview-profile-atlas'),
      alias: 'AtlasLoop',
      colorSeed: 3,
    ),
    relationship: FriendRelationship.friend,
  ),
  FriendSearchResult(
    identity: FriendIdentity(
      profileRef: FriendProfileRef.fromWire('preview-profile-nori'),
      alias: 'Nori',
      colorSeed: 6,
    ),
    relationship: FriendRelationship.friend,
  ),
  FriendSearchResult(
    identity: FriendIdentity(
      profileRef: FriendProfileRef.fromWire('preview-profile-mia'),
      alias: 'onchain.mia',
      colorSeed: 1,
    ),
    relationship: FriendRelationship.none,
  ),
  FriendSearchResult(
    identity: FriendIdentity(
      profileRef: FriendProfileRef.fromWire('preview-profile-mina'),
      alias: 'Mina.Ξ',
      colorSeed: 7,
    ),
    relationship: FriendRelationship.requestPending,
  ),
];
