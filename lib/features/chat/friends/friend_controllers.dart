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
    this.nextCursor,
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
  final String? nextCursor;
  final FriendGatewayFailureKind? failureKind;

  bool get isBusy => phase == FriendDirectoryPhase.loading;
  bool get canLoadMore => !isBusy && nextCursor != null;
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

  Future<void> loadMore() => _startLoad(append: true);

  Future<void> _startLoad({bool append = false}) {
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
    operation = _performLoad(gateway, generation, append: append).whenComplete(
      () {
        if (identical(_operation, operation)) _operation = null;
      },
    );
    _operation = operation;
    return operation;
  }

  Future<void> _performLoad(
    FriendGateway gateway,
    int generation, {
    required bool append,
  }) async {
    final previousFriends = state.friends;
    final previousCursor = state.nextCursor;
    if (append && previousCursor == null) return;
    state = FriendDirectoryState(
      mode: gateway.mode,
      phase: FriendDirectoryPhase.loading,
      friends: previousFriends,
      nextCursor: previousCursor,
    );
    try {
      late final List<FriendIdentity> loaded;
      String? nextCursor;
      if (gateway is LoopSocialFriendGateway) {
        FriendDirectoryPage page;
        try {
          page = await gateway.loadFriendPage(
            cursor: append ? previousCursor : null,
          );
        } on FriendGatewayException catch (error) {
          if (!append || error.kind != FriendGatewayFailureKind.cursorInvalid) {
            rethrow;
          }
          page = await gateway.loadFriendPage();
          append = false;
        }
        final merged = append
            ? <FriendIdentity>[...previousFriends, ...page.items]
            : page.items;
        loaded = validateFriendDirectory(_deduplicateFriends(merged));
        nextCursor = page.nextCursor;
      } else {
        loaded = validateFriendDirectory(await gateway.loadFriends());
      }
      if (!_isCurrent(generation)) return;
      state = FriendDirectoryState(
        mode: gateway.mode,
        phase: FriendDirectoryPhase.ready,
        friends: loaded,
        nextCursor: nextCursor,
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
      nextCursor: state.nextCursor,
      failureKind: kind,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  List<FriendIdentity> _deduplicateFriends(List<FriendIdentity> values) {
    final byId = <FriendProfileRef, FriendIdentity>{};
    for (final value in values) {
      final previous = byId[value.profileRef];
      if (previous != null && previous != value) {
        throw const InvalidFriendContractException();
      }
      byId[value.profileRef] = value;
    }
    return byId.values.toList(growable: false);
  }
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
    this.truncated = false,
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
  final bool truncated;
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
      late final List<FriendSearchResult> results;
      var truncated = false;
      if (gateway is LoopSocialFriendGateway) {
        final page = await gateway.searchByAliasPage(query);
        results = page.items;
        truncated = page.truncated;
      } else {
        results = validateFriendSearchResults(
          await gateway.searchByAlias(query),
        );
      }
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
        truncated: truncated,
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

  Future<void> sendRequest(FriendProfileRef profileRef) =>
      _startRequest(profileRef, reconcileOnly: false);

  Future<void> reconcileRequest(FriendProfileRef profileRef) =>
      _startRequest(profileRef, reconcileOnly: true);

  Future<void> _startRequest(
    FriendProfileRef profileRef, {
    required bool reconcileOnly,
  }) {
    final active = _operation;
    if (active != null) return active;
    final index = state.results.indexWhere(
      (result) => result.identity.profileRef == profileRef,
    );
    if (index < 0 ||
        state.results[index].relationship != FriendRelationship.none ||
        (_outcomeUnknownProfileRefs.contains(profileRef) && !reconcileOnly) ||
        (!_outcomeUnknownProfileRefs.contains(profileRef) && reconcileOnly)) {
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
      truncated: previous.truncated,
      requestingProfileRef: profileRef,
      outcomeUnknownProfileRefs: previous.outcomeUnknownProfileRefs,
    );
    try {
      late final FriendSearchResult updated;
      if (gateway is LoopSocialFriendGateway) {
        final receipt = await gateway.sendFriendRequestCommand(
          operationId: requestId,
          targetProfileRef: profileRef,
        );
        final previousResult = previous.results.firstWhere(
          (result) => result.identity.profileRef == profileRef,
        );
        updated = FriendSearchResult(
          identity: previousResult.identity,
          relationship: FriendRelationship.outgoingPending,
          friendRequestId: receipt.friendRequestId,
        );
      } else {
        updated = FriendSearchResult.copyOf(
          await gateway.sendFriendRequest(
            requestId: requestId,
            profileRef: profileRef,
          ),
        );
      }
      if (!_isCurrent(generation)) return;
      if (updated.identity.profileRef != profileRef ||
          (!updated.isOutgoingPending)) {
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
        truncated: previous.truncated,
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
      truncated: state.truncated,
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
      failureKind != FriendGatewayFailureKind.outcomeUnknown &&
      failureKind != FriendGatewayFailureKind.operatorRequired;

  bool get canReconcile =>
      phase == FriendGroupPhase.failure &&
      failureKind == FriendGatewayFailureKind.outcomeUnknown &&
      requestId != null;

  bool get canCreate {
    if (mode == FriendGatewayMode.unavailable ||
        phase != FriendGroupPhase.editing) {
      return false;
    }
    try {
      normalizeFriendGroupName(name);
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

    final normalizedName = normalizeFriendGroupName(state.name);
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

  Future<void> reconcile() {
    final active = _operation;
    if (active != null) return active;
    if (!state.canReconcile) return Future<void>.value();
    final gateway = ref.read(friendGatewayProvider);
    final generation = ++_generation;
    late final Future<void> operation;
    operation =
        _performCreate(
          gateway: gateway,
          generation: generation,
          requestId: state.requestId!,
          normalizedName: normalizeFriendGroupName(state.name),
          friendRefs: validateSelectedFriendRefs(state.selectedFriendRefs),
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
          !_sameFriendRefSet(receipt.friendRefs, friendRefs) ||
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
      if (error.kind != FriendGatewayFailureKind.outcomeUnknown &&
          error.kind != FriendGatewayFailureKind.operatorRequired) {
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
        state.failureKind == FriendGatewayFailureKind.outcomeUnknown ||
        state.failureKind == FriendGatewayFailureKind.operatorRequired) {
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

  bool _sameFriendRefSet(
    List<FriendProfileRef> left,
    List<FriendProfileRef> right,
  ) => left.length == right.length && left.toSet().containsAll(right);
}

final friendGroupControllerProvider =
    NotifierProvider.autoDispose<FriendGroupController, FriendGroupState>(
      FriendGroupController.new,
    );

enum FriendDirectPhase { idle, opening, opened, unavailable, failure }

@immutable
final class FriendDirectState {
  const FriendDirectState({
    required this.mode,
    required this.phase,
    this.targetProfileRef,
    this.operationId,
    this.receipt,
    this.failureKind,
  });

  factory FriendDirectState.initial(FriendGatewayMode mode) =>
      FriendDirectState(
        mode: mode,
        phase: mode == FriendGatewayMode.production
            ? FriendDirectPhase.idle
            : FriendDirectPhase.unavailable,
        failureKind: mode == FriendGatewayMode.production
            ? null
            : FriendGatewayFailureKind.unavailable,
      );

  final FriendGatewayMode mode;
  final FriendDirectPhase phase;
  final FriendProfileRef? targetProfileRef;
  final String? operationId;
  final CreatedDirectFriendChannel? receipt;
  final FriendGatewayFailureKind? failureKind;

  bool get isBusy => phase == FriendDirectPhase.opening;
  bool get canReconcile =>
      phase == FriendDirectPhase.failure &&
      failureKind == FriendGatewayFailureKind.outcomeUnknown &&
      targetProfileRef != null &&
      operationId != null;
}

final class FriendDirectController extends Notifier<FriendDirectState> {
  Future<void>? _operation;
  KeepAliveLink? _unresolvedWriteKeepAlive;
  final Map<FriendProfileRef, String> _operationIds =
      <FriendProfileRef, String>{};
  final Map<FriendProfileRef, FriendGatewayFailureKind> _unresolvedFailures =
      <FriendProfileRef, FriendGatewayFailureKind>{};
  var _generation = 0;

  @override
  FriendDirectState build() {
    _unresolvedWriteKeepAlive?.close();
    _unresolvedWriteKeepAlive = null;
    _operationIds.clear();
    _unresolvedFailures.clear();
    _operation = null;
    _generation += 1;
    final mode = ref.watch(friendGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return FriendDirectState.initial(mode);
  }

  Future<void> open(FriendProfileRef targetProfileRef) =>
      _start(targetProfileRef, reconcileOnly: false);

  Future<void> reconcile() {
    final target = state.targetProfileRef;
    if (target == null || !state.canReconcile) return Future<void>.value();
    return _start(target, reconcileOnly: true);
  }

  Future<void> _start(
    FriendProfileRef targetProfileRef, {
    required bool reconcileOnly,
  }) {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(friendGatewayProvider);
    if (gateway is! LoopSocialFriendGateway ||
        gateway.mode != FriendGatewayMode.production) {
      state = FriendDirectState.initial(gateway.mode);
      return Future<void>.value();
    }
    final existing = _operationIds[targetProfileRef];
    final unresolvedKind = _unresolvedFailures[targetProfileRef];
    if (existing != null && !reconcileOnly) {
      _publishFailure(
        gateway.mode,
        existing,
        targetProfileRef,
        unresolvedKind ?? FriendGatewayFailureKind.outcomeUnknown,
      );
      return Future<void>.value();
    }
    if (reconcileOnly &&
        (existing == null ||
            unresolvedKind != FriendGatewayFailureKind.outcomeUnknown)) {
      return Future<void>.value();
    }
    final operationId = existing ?? const Uuid().v4();
    _operationIds[targetProfileRef] = operationId;
    _unresolvedWriteKeepAlive ??= ref.keepAlive();
    final generation = ++_generation;
    late final Future<void> operation;
    operation =
        _perform(
          gateway: gateway,
          generation: generation,
          operationId: operationId,
          targetProfileRef: targetProfileRef,
        ).whenComplete(() {
          if (identical(_operation, operation)) _operation = null;
        });
    _operation = operation;
    return operation;
  }

  Future<void> _perform({
    required LoopSocialFriendGateway gateway,
    required int generation,
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async {
    state = FriendDirectState(
      mode: gateway.mode,
      phase: FriendDirectPhase.opening,
      targetProfileRef: targetProfileRef,
      operationId: operationId,
    );
    try {
      final receipt = await gateway.createDirectChannel(
        operationId: operationId,
        targetProfileRef: targetProfileRef,
      );
      if (!_isCurrent(generation)) return;
      if (receipt.operationId != operationId ||
          receipt.targetProfileRef != targetProfileRef) {
        _unresolvedFailures[targetProfileRef] =
            FriendGatewayFailureKind.outcomeUnknown;
        _publishFailure(
          gateway.mode,
          operationId,
          targetProfileRef,
          FriendGatewayFailureKind.outcomeUnknown,
        );
        return;
      }
      _operationIds.remove(targetProfileRef);
      _unresolvedFailures.remove(targetProfileRef);
      state = FriendDirectState(
        mode: gateway.mode,
        phase: FriendDirectPhase.opened,
        targetProfileRef: targetProfileRef,
        operationId: operationId,
        receipt: receipt,
      );
      _releaseWriteRetentionIfResolved();
    } on FriendGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind == FriendGatewayFailureKind.outcomeUnknown ||
          error.kind == FriendGatewayFailureKind.operatorRequired) {
        _unresolvedFailures[targetProfileRef] = error.kind;
      } else {
        _operationIds.remove(targetProfileRef);
        _unresolvedFailures.remove(targetProfileRef);
      }
      _publishFailure(gateway.mode, operationId, targetProfileRef, error.kind);
      _releaseWriteRetentionIfResolved();
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _unresolvedFailures[targetProfileRef] =
          FriendGatewayFailureKind.outcomeUnknown;
      _publishFailure(
        gateway.mode,
        operationId,
        targetProfileRef,
        FriendGatewayFailureKind.outcomeUnknown,
      );
    }
  }

  void consumeReceipt() {
    if (state.phase != FriendDirectPhase.opened) return;
    state = FriendDirectState.initial(state.mode);
  }

  void _publishFailure(
    FriendGatewayMode mode,
    String operationId,
    FriendProfileRef targetProfileRef,
    FriendGatewayFailureKind kind,
  ) {
    state = FriendDirectState(
      mode: mode,
      phase: FriendDirectPhase.failure,
      targetProfileRef: targetProfileRef,
      operationId: operationId,
      failureKind: kind,
    );
  }

  void _releaseWriteRetentionIfResolved() {
    if (_operationIds.isNotEmpty) return;
    _unresolvedWriteKeepAlive?.close();
    _unresolvedWriteKeepAlive = null;
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final friendDirectControllerProvider =
    NotifierProvider.autoDispose<FriendDirectController, FriendDirectState>(
      FriendDirectController.new,
    );
