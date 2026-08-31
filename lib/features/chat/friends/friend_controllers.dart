import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:uuid/uuid.dart';

enum FriendDirectoryPhase { initial, loading, ready, unavailable, failure }

@immutable
final class FriendDirectoryState {
  FriendDirectoryState({
    required this.mode,
    required this.phase,
    Iterable<FriendIdentity> friends = const <FriendIdentity>[],
    this.failureKind,
  }) : friends = validateFriendDirectory(friends);

  factory FriendDirectoryState.initial(FriendGatewayMode mode) =>
      FriendDirectoryState(
        mode: mode,
        phase: mode == FriendGatewayMode.unavailable
            ? FriendDirectoryPhase.unavailable
            : FriendDirectoryPhase.initial,
        failureKind: mode == FriendGatewayMode.unavailable
            ? FriendGatewayFailureKind.unavailable
            : null,
      );

  final FriendGatewayMode mode;
  final FriendDirectoryPhase phase;
  final List<FriendIdentity> friends;
  final FriendGatewayFailureKind? failureKind;

  bool get isBusy => phase == FriendDirectoryPhase.loading;
}

final class FriendDirectoryController extends Notifier<FriendDirectoryState> {
  Future<void>? _operation;
  var _generation = 0;

  @override
  FriendDirectoryState build() {
    _generation += 1;
    _operation = null;
    final mode = ref.watch(friendGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return FriendDirectoryState.initial(mode);
  }

  Future<void> load() {
    if (state.phase == FriendDirectoryPhase.ready) {
      return Future<void>.value();
    }
    return _startLoad();
  }

  Future<void> reload() => _startLoad();

  Future<void> _startLoad() {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(friendGatewayProvider);
    if (gateway.mode == FriendGatewayMode.unavailable) {
      state = FriendDirectoryState(
        mode: gateway.mode,
        phase: FriendDirectoryPhase.unavailable,
        failureKind: FriendGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    late final Future<void> operation;
    operation = _performLoad(gateway, generation).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _performLoad(FriendGateway gateway, int generation) async {
    final previousFriends = state.friends;
    state = FriendDirectoryState(
      mode: gateway.mode,
      phase: FriendDirectoryPhase.loading,
      friends: previousFriends,
    );
    try {
      final loaded = validateFriendDirectory(await gateway.loadFriends());
      if (!_isCurrent(generation)) return;
      state = FriendDirectoryState(
        mode: gateway.mode,
        phase: FriendDirectoryPhase.ready,
        friends: loaded,
      );
    } on FriendGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(gateway.mode, previousFriends, error.kind);
    } on InvalidFriendContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        previousFriends,
        FriendGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        previousFriends,
        FriendGatewayFailureKind.unexpected,
      );
    }
  }

  void _publishFailure(
    FriendGatewayMode mode,
    List<FriendIdentity> previousFriends,
    FriendGatewayFailureKind kind,
  ) {
    state = FriendDirectoryState(
      mode: mode,
      phase:
          kind == FriendGatewayFailureKind.unavailable &&
              previousFriends.isEmpty
          ? FriendDirectoryPhase.unavailable
          : FriendDirectoryPhase.failure,
      friends: previousFriends,
      failureKind: kind,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final friendDirectoryControllerProvider =
    NotifierProvider.autoDispose<
      FriendDirectoryController,
      FriendDirectoryState
    >(FriendDirectoryController.new);

enum FriendSearchPhase {
  idle,
  searching,
  ready,
  requesting,
  unavailable,
  failure,
}

@immutable
final class FriendSearchState {
  FriendSearchState({
    required this.mode,
    required this.phase,
    this.query = '',
    Iterable<FriendSearchResult> results = const <FriendSearchResult>[],
    this.requestingProfileRef,
    Iterable<FriendProfileRef> outcomeUnknownProfileRefs =
        const <FriendProfileRef>[],
    this.failureKind,
  }) : results = validateFriendSearchResults(results),
       outcomeUnknownProfileRefs = Set<FriendProfileRef>.unmodifiable(
         outcomeUnknownProfileRefs,
       );

  factory FriendSearchState.initial(FriendGatewayMode mode) =>
      FriendSearchState(
        mode: mode,
        phase: mode == FriendGatewayMode.unavailable
            ? FriendSearchPhase.unavailable
            : FriendSearchPhase.idle,
        failureKind: mode == FriendGatewayMode.unavailable
            ? FriendGatewayFailureKind.unavailable
            : null,
      );

  final FriendGatewayMode mode;
  final FriendSearchPhase phase;
  final String query;
  final List<FriendSearchResult> results;
  final FriendProfileRef? requestingProfileRef;
  final Set<FriendProfileRef> outcomeUnknownProfileRefs;
  final FriendGatewayFailureKind? failureKind;

  bool get isBusy =>
      phase == FriendSearchPhase.searching ||
      phase == FriendSearchPhase.requesting;
}

final class FriendSearchController extends Notifier<FriendSearchState> {
  Future<void>? _operation;
  KeepAliveLink? _unresolvedWriteKeepAlive;
  final Map<FriendProfileRef, String> _requestIds =
      <FriendProfileRef, String>{};
  final Set<FriendProfileRef> _outcomeUnknownProfileRefs = <FriendProfileRef>{};
  var _generation = 0;

  @override
  FriendSearchState build() {
    _unresolvedWriteKeepAlive?.close();
    _unresolvedWriteKeepAlive = null;
    _generation += 1;
    _operation = null;
    _requestIds.clear();
    _outcomeUnknownProfileRefs.clear();
    final mode = ref.watch(friendGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return FriendSearchState.initial(mode);
  }

  Future<void> search(String rawQuery) {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(friendGatewayProvider);
    if (gateway.mode == FriendGatewayMode.unavailable) {
      state = FriendSearchState.initial(gateway.mode);
      return Future<void>.value();
    }

    late final String query;
    try {
      query = normalizeFriendAliasQuery(rawQuery);
    } on InvalidFriendContractException {
      state = FriendSearchState(
        mode: gateway.mode,
        phase: FriendSearchPhase.failure,
        query: rawQuery.trim(),
        failureKind: FriendGatewayFailureKind.invalidData,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    late final Future<void> operation;
    operation = _performSearch(gateway, generation, query).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _performSearch(
    FriendGateway gateway,
    int generation,
    String query,
  ) async {
    state = FriendSearchState(
      mode: gateway.mode,
      phase: FriendSearchPhase.searching,
      query: query,
    );
    try {
      final results = validateFriendSearchResults(
        await gateway.searchByAlias(query),
      );
      if (!_isCurrent(generation)) return;
      for (final result in results) {
        if (result.relationship != FriendRelationship.none) {
          _outcomeUnknownProfileRefs.remove(result.identity.profileRef);
          _requestIds.remove(result.identity.profileRef);
        }
      }
      state = FriendSearchState(
        mode: gateway.mode,
        phase: FriendSearchPhase.ready,
        query: query,
        results: results,
        outcomeUnknownProfileRefs: _outcomeUnknownProfileRefs.where(
          (profileRef) =>
              results.any((result) => result.identity.profileRef == profileRef),
        ),
      );
      _releaseWriteRetentionIfResolved();
    } on FriendGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        query,
        const <FriendSearchResult>[],
        error.kind,
      );
    } on InvalidFriendContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        query,
        const <FriendSearchResult>[],
        FriendGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        query,
        const <FriendSearchResult>[],
        FriendGatewayFailureKind.unexpected,
      );
    }
  }

  Future<void> sendRequest(FriendProfileRef profileRef) {
    final active = _operation;
    if (active != null) return active;
    final index = state.results.indexWhere(
      (result) => result.identity.profileRef == profileRef,
    );
    if (index < 0 ||
        state.results[index].relationship != FriendRelationship.none ||
        _outcomeUnknownProfileRefs.contains(profileRef)) {
      return Future<void>.value();
    }
    final gateway = ref.read(friendGatewayProvider);
    if (gateway.mode == FriendGatewayMode.unavailable) {
      state = FriendSearchState.initial(gateway.mode);
      return Future<void>.value();
    }

    final generation = ++_generation;
    _unresolvedWriteKeepAlive ??= ref.keepAlive();
    final requestId = _requestIds.putIfAbsent(
      profileRef,
      () => const Uuid().v4(),
    );
    late final Future<void> operation;
    operation = _performRequest(gateway, generation, requestId, profileRef)
        .whenComplete(() {
          if (identical(_operation, operation)) _operation = null;
        });
    _operation = operation;
    return operation;
  }

  Future<void> _performRequest(
    FriendGateway gateway,
    int generation,
    String requestId,
    FriendProfileRef profileRef,
  ) async {
    final previous = state;
    state = FriendSearchState(
      mode: gateway.mode,
      phase: FriendSearchPhase.requesting,
      query: previous.query,
      results: previous.results,
      requestingProfileRef: profileRef,
      outcomeUnknownProfileRefs: previous.outcomeUnknownProfileRefs,
    );
    try {
      final updated = FriendSearchResult.copyOf(
        await gateway.sendFriendRequest(
          requestId: requestId,
          profileRef: profileRef,
        ),
      );
      if (!_isCurrent(generation)) return;
      if (updated.identity.profileRef != profileRef ||
          updated.relationship != FriendRelationship.requestPending) {
        _outcomeUnknownProfileRefs.add(profileRef);
        _publishFailure(
          gateway.mode,
          previous.query,
          previous.results,
          FriendGatewayFailureKind.outcomeUnknown,
          requestingProfileRef: profileRef,
        );
        return;
      }
      final nextResults = previous.results
          .map(
            (result) =>
                result.identity.profileRef == profileRef ? updated : result,
          )
          .toList(growable: false);
      _requestIds.remove(profileRef);
      _outcomeUnknownProfileRefs.remove(profileRef);
      state = FriendSearchState(
        mode: gateway.mode,
        phase: FriendSearchPhase.ready,
        query: previous.query,
        results: nextResults,
        outcomeUnknownProfileRefs: previous.outcomeUnknownProfileRefs.where(
          (candidate) => candidate != profileRef,
        ),
      );
      _releaseWriteRetentionIfResolved();
    } on FriendGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      final kind = error.kind;
      if (kind != FriendGatewayFailureKind.outcomeUnknown) {
        _requestIds.remove(profileRef);
        _outcomeUnknownProfileRefs.remove(profileRef);
      } else {
        _outcomeUnknownProfileRefs.add(profileRef);
      }
      _publishFailure(
        gateway.mode,
        previous.query,
        previous.results,
        kind,
        requestingProfileRef: profileRef,
      );
      _releaseWriteRetentionIfResolved();
    } on InvalidFriendContractException {
      if (!_isCurrent(generation)) return;
      _outcomeUnknownProfileRefs.add(profileRef);
      _publishFailure(
        gateway.mode,
        previous.query,
        previous.results,
        FriendGatewayFailureKind.outcomeUnknown,
        requestingProfileRef: profileRef,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _outcomeUnknownProfileRefs.add(profileRef);
      _publishFailure(
        gateway.mode,
        previous.query,
        previous.results,
        FriendGatewayFailureKind.outcomeUnknown,
        requestingProfileRef: profileRef,
      );
    }
  }

  void clear() {
    if (state.isBusy) return;
    state = FriendSearchState.initial(ref.read(friendGatewayProvider).mode);
  }

  void _releaseWriteRetentionIfResolved() {
    if (_outcomeUnknownProfileRefs.isNotEmpty) return;
    _unresolvedWriteKeepAlive?.close();
    _unresolvedWriteKeepAlive = null;
  }

  void _publishFailure(
    FriendGatewayMode mode,
    String query,
    List<FriendSearchResult> results,
    FriendGatewayFailureKind kind, {
    FriendProfileRef? requestingProfileRef,
  }) {
    state = FriendSearchState(
      mode: mode,
      phase: kind == FriendGatewayFailureKind.unavailable && results.isEmpty
          ? FriendSearchPhase.unavailable
          : FriendSearchPhase.failure,
      query: query,
      results: results,
      requestingProfileRef: requestingProfileRef,
      outcomeUnknownProfileRefs: _outcomeUnknownProfileRefs.where(
        (profileRef) =>
            results.any((result) => result.identity.profileRef == profileRef),
      ),
      failureKind: kind,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final friendSearchControllerProvider =
    NotifierProvider.autoDispose<FriendSearchController, FriendSearchState>(
      FriendSearchController.new,
    );

enum FriendGroupPhase { editing, creating, created, unavailable, failure }

@immutable
final class FriendGroupState {
  FriendGroupState({
    required this.mode,
    required this.phase,
    this.name = '',
    Iterable<FriendProfileRef> selectedFriendRefs = const <FriendProfileRef>[],
    this.requestId,
    this.receipt,
    this.failureKind,
  }) : selectedFriendRefs = List<FriendProfileRef>.unmodifiable(
         selectedFriendRefs,
       );

  factory FriendGroupState.initial(FriendGatewayMode mode) => FriendGroupState(
    mode: mode,
    phase: mode == FriendGatewayMode.unavailable
        ? FriendGroupPhase.unavailable
        : FriendGroupPhase.editing,
    failureKind: mode == FriendGatewayMode.unavailable
        ? FriendGatewayFailureKind.unavailable
        : null,
  );

  final FriendGatewayMode mode;
  final FriendGroupPhase phase;
  final String name;
  final List<FriendProfileRef> selectedFriendRefs;
  final String? requestId;
  final CreatedFriendGroup? receipt;
  final FriendGatewayFailureKind? failureKind;

  bool get isBusy => phase == FriendGroupPhase.creating;

  bool get canEdit => phase == FriendGroupPhase.editing;

  bool get canResumeEditing =>
      phase == FriendGroupPhase.failure &&
      failureKind != FriendGatewayFailureKind.outcomeUnknown;

  bool get canCreate {
    if (mode == FriendGatewayMode.unavailable ||
        phase != FriendGroupPhase.editing) {
      return false;
    }
    try {
      normalizeFriendDisplayName(name);
      validateSelectedFriendRefs(selectedFriendRefs);
      return true;
    } on InvalidFriendContractException {
      return false;
    }
  }
}

final class FriendGroupController extends Notifier<FriendGroupState> {
  Future<void>? _operation;
  KeepAliveLink? _unresolvedWriteKeepAlive;
  var _generation = 0;

  @override
  FriendGroupState build() {
    _unresolvedWriteKeepAlive?.close();
    _unresolvedWriteKeepAlive = null;
    _generation += 1;
    _operation = null;
    final mode = ref.watch(friendGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return FriendGroupState.initial(mode);
  }

  void editName(String value) {
    if (!state.canEdit) return;
    state = FriendGroupState(
      mode: state.mode,
      phase: FriendGroupPhase.editing,
      name: value,
      selectedFriendRefs: state.selectedFriendRefs,
      requestId: state.requestId,
    );
  }

  void toggleFriend(FriendProfileRef profileRef) {
    if (!state.canEdit) return;
    final selected = state.selectedFriendRefs.toList(growable: true);
    if (selected.remove(profileRef)) {
      state = FriendGroupState(
        mode: state.mode,
        phase: FriendGroupPhase.editing,
        name: state.name,
        selectedFriendRefs: selected,
        requestId: state.requestId,
      );
      return;
    }
    if (selected.length >= groupMaximumSelectedFriends) return;
    selected.add(profileRef);
    state = FriendGroupState(
      mode: state.mode,
      phase: FriendGroupPhase.editing,
      name: state.name,
      selectedFriendRefs: selected,
      requestId: state.requestId,
    );
  }

  Future<void> create() {
    final active = _operation;
    if (active != null) return active;
    if (!state.canCreate) return Future<void>.value();
    final gateway = ref.read(friendGatewayProvider);
    if (gateway.mode == FriendGatewayMode.unavailable) {
      state = FriendGroupState.initial(gateway.mode);
      return Future<void>.value();
    }

    final normalizedName = normalizeFriendDisplayName(state.name);
    final friendRefs = validateSelectedFriendRefs(state.selectedFriendRefs);
    final requestId = state.requestId ?? const Uuid().v4();
    _unresolvedWriteKeepAlive ??= ref.keepAlive();
    final generation = ++_generation;
    late final Future<void> operation;
    operation =
        _performCreate(
          gateway: gateway,
          generation: generation,
          requestId: requestId,
          normalizedName: normalizedName,
          friendRefs: friendRefs,
        ).whenComplete(() {
          if (identical(_operation, operation)) _operation = null;
        });
    _operation = operation;
    return operation;
  }

  Future<void> _performCreate({
    required FriendGateway gateway,
    required int generation,
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async {
    state = FriendGroupState(
      mode: gateway.mode,
      phase: FriendGroupPhase.creating,
      name: normalizedName,
      selectedFriendRefs: friendRefs,
      requestId: requestId,
    );
    try {
      final receipt = CreatedFriendGroup.copyOf(
        await gateway.createGroup(
          requestId: requestId,
          normalizedName: normalizedName,
          friendRefs: friendRefs,
        ),
      );
      if (!_isCurrent(generation)) return;
      if (receipt.requestId != requestId ||
          receipt.name != normalizedName ||
          !listEquals(receipt.friendRefs, friendRefs) ||
          (gateway.mode == FriendGatewayMode.preview &&
              receipt.streamCid != null) ||
          (gateway.mode == FriendGatewayMode.production &&
              receipt.streamCid == null)) {
        _publishFailure(
          gateway.mode,
          requestId,
          normalizedName,
          friendRefs,
          FriendGatewayFailureKind.outcomeUnknown,
        );
        return;
      }
      state = FriendGroupState(
        mode: gateway.mode,
        phase: FriendGroupPhase.created,
        name: normalizedName,
        selectedFriendRefs: friendRefs,
        requestId: requestId,
        receipt: receipt,
      );
      _releaseWriteRetention();
    } on FriendGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        requestId,
        normalizedName,
        friendRefs,
        error.kind,
      );
      if (error.kind != FriendGatewayFailureKind.outcomeUnknown) {
        _releaseWriteRetention();
      }
    } on InvalidFriendContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        requestId,
        normalizedName,
        friendRefs,
        FriendGatewayFailureKind.outcomeUnknown,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        requestId,
        normalizedName,
        friendRefs,
        FriendGatewayFailureKind.outcomeUnknown,
      );
    }
  }

  void resumeEditing() {
    if (!state.canResumeEditing) return;
    state = FriendGroupState(
      mode: state.mode,
      phase: FriendGroupPhase.editing,
      name: state.name,
      selectedFriendRefs: state.selectedFriendRefs,
    );
    _releaseWriteRetention();
  }

  void reset() {
    if (state.isBusy ||
        state.failureKind == FriendGatewayFailureKind.outcomeUnknown) {
      return;
    }
    state = FriendGroupState.initial(ref.read(friendGatewayProvider).mode);
    _releaseWriteRetention();
  }

  void _releaseWriteRetention() {
    _unresolvedWriteKeepAlive?.close();
    _unresolvedWriteKeepAlive = null;
  }

  void _publishFailure(
    FriendGatewayMode mode,
    String requestId,
    String name,
    List<FriendProfileRef> friendRefs,
    FriendGatewayFailureKind kind,
  ) {
    state = FriendGroupState(
      mode: mode,
      phase: FriendGroupPhase.failure,
      name: name,
      selectedFriendRefs: friendRefs,
      requestId: requestId,
      failureKind: kind,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final friendGroupControllerProvider =
    NotifierProvider.autoDispose<FriendGroupController, FriendGroupState>(
      FriendGroupController.new,
    );
