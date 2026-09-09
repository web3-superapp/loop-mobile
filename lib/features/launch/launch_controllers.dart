import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';

/// Single-flight guard shared by the S7 controllers: one in-flight operation
/// per controller, and a generation counter so a result that arrives after a
/// rebuild or a filter change is dropped instead of overwriting newer truth.
mixin LaunchSingleFlight {
  Future<void>? _operation;
  int _generation = 0;

  int nextGeneration() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;

  Future<void> single(Future<void> Function() body) {
    final active = _operation;
    if (active != null) return active;
    late final Future<void> operation;
    operation = body().whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }
}

/// One read-only S7 resource. The three modules share it so every page gets
/// the same five reviewed states from one place.
abstract base class LaunchReadController<T>
    extends Notifier<LaunchResourceState<T>>
    with LaunchSingleFlight {
  @override
  LaunchResourceState<T> build() {
    nextGeneration();
    final mode = ref.watch(launchGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return LaunchResourceState<T>.initial(mode);
  }

  Future<T> fetch(LaunchGateway gateway);

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final gateway = ref.read(launchGatewayProvider);
    final generation = nextGeneration();
    state = state.loading();
    try {
      final value = await fetch(gateway);
      if (!isCurrent(generation)) return;
      state = state.ready(value);
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.failed(LaunchFailureKind.unexpected);
    }
  });
}

// ---------------------------------------------------------------------------
// launch · catalogue
// ---------------------------------------------------------------------------

/// The catalogue segment the list page is showing. `awaitingSchedule` is its
/// own segment: an approved launch without a schedule is never "即将开始", and
/// "已毕业" is a liquidity fact that no schedule can imply.
enum LaunchSegment { live, upcoming, awaitingSchedule, ended }

String launchSegmentLabel(LaunchSegment segment) => switch (segment) {
  LaunchSegment.live => '发射中',
  LaunchSegment.upcoming => '即将开始',
  LaunchSegment.awaitingSchedule => '待排期',
  LaunchSegment.ended => '已结束',
};

final class LaunchOverviewController
    extends LaunchReadController<LaunchOverview> {
  @override
  Future<LaunchOverview> fetch(LaunchGateway gateway) => gateway.loadOverview();
}

final launchOverviewControllerProvider =
    NotifierProvider.autoDispose<
      LaunchOverviewController,
      LaunchResourceState<LaunchOverview>
    >(LaunchOverviewController.new);

/// Which segment the list page shows. It is page state, not server state, so
/// it never becomes part of a resource projection.
final class LaunchSegmentController extends Notifier<LaunchSegment> {
  @override
  LaunchSegment build() => LaunchSegment.live;

  void select(LaunchSegment segment) => state = segment;
}

final launchSegmentControllerProvider =
    NotifierProvider.autoDispose<LaunchSegmentController, LaunchSegment>(
      LaunchSegmentController.new,
    );

// ---------------------------------------------------------------------------
// launch-detail / launch-rounds / launch-graduation
// ---------------------------------------------------------------------------

final class LaunchDetailController extends LaunchReadController<LaunchDetail> {
  @override
  LaunchResourceState<LaunchDetail> build() {
    _launchId = null;
    return super.build();
  }

  String? _launchId;

  /// The subject is set by the route, never recovered from display text.
  Future<void> open(String? launchId) {
    if (launchId == null) {
      state = state.failed(LaunchFailureKind.notFound);
      return Future<void>.value();
    }
    if (_launchId == launchId && state.isReady) return Future<void>.value();
    _launchId = launchId;
    return reload();
  }

  @override
  Future<LaunchDetail> fetch(LaunchGateway gateway) {
    final launchId = _launchId;
    if (launchId == null) {
      throw const LaunchException(LaunchFailureKind.notFound);
    }
    return gateway.loadLaunch(launchId);
  }
}

final launchDetailControllerProvider =
    NotifierProvider.autoDispose<
      LaunchDetailController,
      LaunchResourceState<LaunchDetail>
    >(LaunchDetailController.new);

// ---------------------------------------------------------------------------
// launch-tier
// ---------------------------------------------------------------------------

final class LaunchEligibilityController
    extends LaunchReadController<LaunchEligibility> {
  @override
  LaunchResourceState<LaunchEligibility> build() {
    _launchId = null;
    return super.build();
  }

  String? _launchId;

  Future<void> open(String? launchId) {
    if (launchId == null) {
      state = state.failed(LaunchFailureKind.notFound);
      return Future<void>.value();
    }
    if (_launchId == launchId && state.isReady) return Future<void>.value();
    _launchId = launchId;
    return reload();
  }

  @override
  Future<LaunchEligibility> fetch(LaunchGateway gateway) {
    final launchId = _launchId;
    if (launchId == null) {
      throw const LaunchException(LaunchFailureKind.notFound);
    }
    return gateway.loadEligibility(launchId);
  }
}

final launchEligibilityControllerProvider =
    NotifierProvider.autoDispose<
      LaunchEligibilityController,
      LaunchResourceState<LaunchEligibility>
    >(LaunchEligibilityController.new);

// ---------------------------------------------------------------------------
// loop-stake
// ---------------------------------------------------------------------------

final class LaunchStakeController extends LaunchReadController<LaunchStake> {
  @override
  Future<LaunchStake> fetch(LaunchGateway gateway) => gateway.loadStake();
}

final launchStakeControllerProvider =
    NotifierProvider.autoDispose<
      LaunchStakeController,
      LaunchResourceState<LaunchStake>
    >(LaunchStakeController.new);

// ---------------------------------------------------------------------------
// launch-holders
// ---------------------------------------------------------------------------

final class LaunchHoldersController
    extends LaunchReadController<LaunchHolders> {
  @override
  LaunchResourceState<LaunchHolders> build() {
    _launchId = null;
    return super.build();
  }

  String? _launchId;

  Future<void> open(String? launchId) {
    if (launchId == null) {
      state = state.failed(LaunchFailureKind.notFound);
      return Future<void>.value();
    }
    if (_launchId == launchId && state.isReady) return Future<void>.value();
    _launchId = launchId;
    return reload();
  }

  @override
  Future<LaunchHolders> fetch(LaunchGateway gateway) {
    final launchId = _launchId;
    if (launchId == null) {
      throw const LaunchException(LaunchFailureKind.notFound);
    }
    return gateway.loadHolders(launchId);
  }
}

final launchHoldersControllerProvider =
    NotifierProvider.autoDispose<
      LaunchHoldersController,
      LaunchResourceState<LaunchHolders>
    >(LaunchHoldersController.new);

// ---------------------------------------------------------------------------
// launch-history
// ---------------------------------------------------------------------------

final class LaunchHistoryController
    extends LaunchReadController<LaunchHistory> {
  @override
  LaunchResourceState<LaunchHistory> build() {
    _launchId = null;
    return super.build();
  }

  String? _launchId;

  Future<void> open(String? launchId) {
    if (launchId == null) {
      state = state.failed(LaunchFailureKind.notFound);
      return Future<void>.value();
    }
    if (_launchId == launchId && state.isReady) return Future<void>.value();
    _launchId = launchId;
    return reload();
  }

  @override
  Future<LaunchHistory> fetch(LaunchGateway gateway) {
    final launchId = _launchId;
    if (launchId == null) {
      throw const LaunchException(LaunchFailureKind.notFound);
    }
    return gateway.loadHistory(launchId);
  }
}

final launchHistoryControllerProvider =
    NotifierProvider.autoDispose<
      LaunchHistoryController,
      LaunchResourceState<LaunchHistory>
    >(LaunchHistoryController.new);

// ---------------------------------------------------------------------------
// loop-economy
// ---------------------------------------------------------------------------

final class LaunchEconomyController
    extends LaunchReadController<LaunchEconomy> {
  @override
  Future<LaunchEconomy> fetch(LaunchGateway gateway) => gateway.loadEconomy();
}

final launchEconomyControllerProvider =
    NotifierProvider.autoDispose<
      LaunchEconomyController,
      LaunchResourceState<LaunchEconomy>
    >(LaunchEconomyController.new);

// ---------------------------------------------------------------------------
// launch-apply
// ---------------------------------------------------------------------------

/// The apply page's own state: my applications, the selected one, and whether
/// a write is in flight. The selected project is the CAS subject; its version
/// always comes from the last server projection, never from the form.
@immutable
final class LaunchApplyState {
  const LaunchApplyState({
    required this.mode,
    required this.phase,
    this.projects = const <LaunchProject>[],
    this.nextCursor,
    this.selectedProjectId,
    this.failureKind,
    this.writeFailureKind,
    this.busy = false,
    this.invalidField,
    this.lastSavedAt,
  });

  factory LaunchApplyState.initial(LaunchGatewayMode mode) {
    final closed = mode == LaunchGatewayMode.unavailable;
    return LaunchApplyState(
      mode: mode,
      phase: closed ? LaunchViewPhase.unavailable : LaunchViewPhase.loading,
      failureKind: closed ? LaunchFailureKind.unavailable : null,
    );
  }

  final LaunchGatewayMode mode;
  final LaunchViewPhase phase;
  final List<LaunchProject> projects;
  final String? nextCursor;
  final String? selectedProjectId;
  final LaunchFailureKind? failureKind;

  /// The refusal of the last write, kept apart from the read failure so a
  /// rejected submit never blanks the list that did load.
  final LaunchFailureKind? writeFailureKind;
  final bool busy;

  /// The field the local shape check rejected before any request went out.
  final LaunchDraftField? invalidField;
  final DateTime? lastSavedAt;

  LaunchProject? get selected {
    final id = selectedProjectId;
    if (id == null) return null;
    for (final project in projects) {
      if (project.projectId == id) return project;
    }
    return null;
  }

  bool get isReady => phase == LaunchViewPhase.ready;
}

final class LaunchApplyController extends Notifier<LaunchApplyState>
    with LaunchSingleFlight {
  @override
  LaunchApplyState build() {
    nextGeneration();
    final mode = ref.watch(launchGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return LaunchApplyState.initial(mode);
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final gateway = ref.read(launchGatewayProvider);
    final generation = nextGeneration();
    state = LaunchApplyState(
      mode: state.mode,
      phase: state.projects.isEmpty
          ? LaunchViewPhase.loading
          : LaunchViewPhase.ready,
      projects: state.projects,
      nextCursor: state.nextCursor,
      selectedProjectId: state.selectedProjectId,
    );
    try {
      final page = await gateway.listProjects();
      if (!isCurrent(generation)) return;
      state = LaunchApplyState(
        mode: state.mode,
        phase: LaunchViewPhase.ready,
        projects: page.items,
        nextCursor: page.nextCursor,
        selectedProjectId: _stillPresent(page.items, state.selectedProjectId),
      );
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = _failedRead(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = _failedRead(LaunchFailureKind.unexpected);
    }
  });

  static String? _stillPresent(List<LaunchProject> items, String? id) {
    if (id == null) return null;
    for (final project in items) {
      if (project.projectId == id) return id;
    }
    return null;
  }

  LaunchApplyState _failedRead(LaunchFailureKind kind) => LaunchApplyState(
    mode: state.mode,
    phase: state.projects.isEmpty
        ? launchPhaseForFailure(kind)
        : LaunchViewPhase.ready,
    projects: state.projects,
    nextCursor: state.nextCursor,
    selectedProjectId: state.selectedProjectId,
    failureKind: kind,
  );

  void select(String? projectId) {
    state = LaunchApplyState(
      mode: state.mode,
      phase: state.phase,
      projects: state.projects,
      nextCursor: state.nextCursor,
      selectedProjectId: projectId,
      failureKind: state.failureKind,
    );
  }

  /// Creates a draft, or saves the selected one with its exact CAS version.
  Future<void> save(LaunchProjectDraft draft) => single(() async {
    final invalid = draft.invalidField;
    if (invalid != null) {
      state = _writeState(busy: false, invalidField: invalid);
      return;
    }
    final gateway = ref.read(launchGatewayProvider);
    final generation = nextGeneration();
    state = _writeState(busy: true);
    try {
      final current = state.selected;
      final LaunchProject saved;
      if (current == null) {
        saved = await gateway.createProject(draft);
      } else {
        final version = current.version;
        if (version == null) {
          throw const LaunchException(LaunchFailureKind.permissionDenied);
        }
        saved = await gateway.updateProject(
          projectId: current.projectId,
          expectedVersion: version,
          draft: draft,
        );
      }
      if (!isCurrent(generation)) return;
      state = _merged(saved);
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = _writeState(busy: false, writeFailureKind: error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = _writeState(
        busy: false,
        writeFailureKind: LaunchFailureKind.unexpected,
      );
    }
  });

  Future<void> submit() => single(() async {
    final current = state.selected;
    if (current == null || !current.canSubmit) {
      state = _writeState(
        busy: false,
        writeFailureKind: LaunchFailureKind.stale,
      );
      return;
    }
    final gateway = ref.read(launchGatewayProvider);
    final generation = nextGeneration();
    state = _writeState(busy: true);
    try {
      final saved = await gateway.submitProject(current.projectId);
      if (!isCurrent(generation)) return;
      state = _merged(saved);
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = _writeState(busy: false, writeFailureKind: error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = _writeState(
        busy: false,
        writeFailureKind: LaunchFailureKind.unexpected,
      );
    }
  });

  LaunchApplyState _writeState({
    required bool busy,
    LaunchFailureKind? writeFailureKind,
    LaunchDraftField? invalidField,
  }) => LaunchApplyState(
    mode: state.mode,
    phase: state.phase == LaunchViewPhase.loading
        ? LaunchViewPhase.loading
        : LaunchViewPhase.ready,
    projects: state.projects,
    nextCursor: state.nextCursor,
    selectedProjectId: state.selectedProjectId,
    failureKind: state.failureKind,
    writeFailureKind: writeFailureKind,
    busy: busy,
    invalidField: invalidField,
    lastSavedAt: state.lastSavedAt,
  );

  /// Replaces the stored projection with the one the server just returned.
  LaunchApplyState _merged(LaunchProject saved) {
    final items = <LaunchProject>[];
    var replaced = false;
    for (final project in state.projects) {
      if (project.projectId == saved.projectId) {
        items.add(saved);
        replaced = true;
      } else {
        items.add(project);
      }
    }
    if (!replaced) items.insert(0, saved);
    return LaunchApplyState(
      mode: state.mode,
      phase: LaunchViewPhase.ready,
      projects: List<LaunchProject>.unmodifiable(items),
      nextCursor: state.nextCursor,
      selectedProjectId: saved.projectId,
      lastSavedAt: saved.updatedAt,
    );
  }
}

final launchApplyControllerProvider =
    NotifierProvider.autoDispose<LaunchApplyController, LaunchApplyState>(
      LaunchApplyController.new,
    );

/// Exchange listing milestones for one project (`launch-apply` detail block).
final class LaunchMilestonesController
    extends LaunchReadController<LaunchMilestones> {
  @override
  LaunchResourceState<LaunchMilestones> build() {
    _projectId = null;
    return super.build();
  }

  String? _projectId;

  Future<void> open(String? projectId) {
    if (projectId == null) {
      state = LaunchResourceState<LaunchMilestones>.initial(state.mode);
      _projectId = null;
      return Future<void>.value();
    }
    if (_projectId == projectId && state.isReady) return Future<void>.value();
    _projectId = projectId;
    return reload();
  }

  @override
  Future<LaunchMilestones> fetch(LaunchGateway gateway) {
    final projectId = _projectId;
    if (projectId == null) {
      throw const LaunchException(LaunchFailureKind.notFound);
    }
    return gateway.loadMilestones(projectId);
  }
}

final launchMilestonesControllerProvider =
    NotifierProvider.autoDispose<
      LaunchMilestonesController,
      LaunchResourceState<LaunchMilestones>
    >(LaunchMilestonesController.new);

// ---------------------------------------------------------------------------
// launch-trade
// ---------------------------------------------------------------------------

/// The purchase form. The main action is enabled only while a round, a wallet
/// and an amount exist **and** the last attempt has not been refused; the
/// refusal itself always comes from the server, never from a hidden control.
@immutable
final class LaunchTradeState {
  const LaunchTradeState({
    required this.mode,
    this.busy = false,
    this.refusalKind,
    this.attempted = false,
  });

  final LaunchGatewayMode mode;
  final bool busy;
  final LaunchFailureKind? refusalKind;

  /// True once the server has answered at least one intent attempt.
  final bool attempted;
}

final class LaunchTradeController extends Notifier<LaunchTradeState>
    with LaunchSingleFlight {
  @override
  LaunchTradeState build() {
    nextGeneration();
    final mode = ref.watch(launchGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return LaunchTradeState(mode: mode);
  }

  /// Submits the purchase intent. In this step the server answers `503`, and
  /// the page renders that refusal verbatim.
  Future<void> submit({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
  }) => single(() async {
    final gateway = ref.read(launchGatewayProvider);
    final generation = nextGeneration();
    state = LaunchTradeState(mode: state.mode, busy: true, attempted: true);
    try {
      await gateway.submitPurchaseIntent(
        launchId: launchId,
        walletId: walletId,
        roundId: roundId,
        payAmount: payAmount,
      );
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = LaunchTradeState(
        mode: state.mode,
        refusalKind: error.kind,
        attempted: true,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = LaunchTradeState(
        mode: state.mode,
        refusalKind: LaunchFailureKind.unexpected,
        attempted: true,
      );
    }
  });
}

final launchTradeControllerProvider =
    NotifierProvider.autoDispose<LaunchTradeController, LaunchTradeState>(
      LaunchTradeController.new,
    );
