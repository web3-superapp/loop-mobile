import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_read_retention.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';

/// Single-flight guard shared by the S7 controllers: one in-flight operation
/// per controller, and a generation counter so a result that arrives after a
/// rebuild or a filter change is dropped instead of overwriting newer truth.
mixin LaunchSingleFlight {
  Future<void>? _operation;
  int _generation = 0;

  int nextGeneration() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;

  /// Whether an operation is running right now.
  bool get inFlight => _operation != null;

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

/// How often a broadcast Launch intent is read back (S83b3.1 suggests 5 s),
/// and how many reads before the page stops and offers a re-read.
final launchIntentPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);
const int launchIntentMaxPolls = 72;

/// The one read-back loop of a broadcast Launch intent, shared by the
/// purchase (S92b2) and the claim / refund (decision 0103) controllers.
///
/// Every [interval] it reads `GET …/intents/{id}` through [load] and hands
/// the answer to [onRead], until the state is settled
/// ([LaunchIntentState.isSettled]) or [launchIntentMaxPolls] reads ran out
/// (`timedOut`). A read that did not land, or that names another intent,
/// keeps the last known intent. [stop] drops any read in flight.
final class LaunchIntentPoller {
  LaunchIntentPoller({required this.load, required this.onRead});

  final Future<LaunchPurchaseIntent> Function(LaunchPurchaseIntent current)
  load;
  final void Function(
    LaunchPurchaseIntent intent, {
    required bool polling,
    required bool timedOut,
  })
  onRead;

  Timer? _timer;
  LaunchPurchaseIntent? _current;
  Duration _interval = Duration.zero;
  int _polls = 0;
  int _generation = 0;

  /// Starts (or restarts) reading [intent] back. A settled intent is not
  /// read.
  void start(LaunchPurchaseIntent intent, Duration interval) {
    stop();
    if (intent.state.isSettled) return;
    _current = intent;
    _interval = interval;
    _polls = 0;
    _schedule();
  }

  void stop() {
    _generation += 1;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    final generation = _generation;
    _timer = Timer(_interval, () => unawaited(_pollOnce(generation)));
  }

  Future<void> _pollOnce(int generation) async {
    final current = _current;
    if (current == null || generation != _generation) return;
    _polls += 1;
    LaunchPurchaseIntent? next;
    try {
      next = await load(current);
    } catch (_) {
      // A read that did not land changes nothing; the next one may.
      next = null;
    }
    if (generation != _generation) return;
    // The read-back must be about this intent; anything else is ignored.
    if (next != null && next.launchIntentId != current.launchIntentId) {
      next = null;
    }
    final intent = next ?? current;
    _current = intent;
    if (intent.state.isSettled) {
      onRead(intent, polling: false, timedOut: false);
      return;
    }
    if (_polls >= launchIntentMaxPolls) {
      onRead(intent, polling: false, timedOut: true);
      return;
    }
    onRead(intent, polling: true, timedOut: false);
    _schedule();
  }
}

/// Whether an intent that reached [state] moved (or may have moved) the
/// position and the records: a confirmed intent moves them, an expired one
/// may have landed late (S92a.6), a reverted one is re-read to show it.
bool launchIntentRereads(LaunchIntentState? state) =>
    state == LaunchIntentState.confirmed ||
    state == LaunchIntentState.expired ||
    state == LaunchIntentState.reverted;

/// Re-reads the launch's detail, holders (the position) and history (the
/// records) after a settled intent. Purchase, claim and refund share it.
///
/// [openIfIdle] opens a resource that was never read; the purchase page
/// passes `false`, since it does not draw them itself and only refreshes the
/// ones `launch-detail` below it already holds.
void launchRereadAfterIntent(
  WidgetRef ref,
  String launchId, {
  bool detail = true,
  bool openIfIdle = true,
}) {
  if (detail) {
    unawaited(ref.read(launchDetailControllerProvider.notifier).reload());
  }
  final holders = ref.read(launchHoldersControllerProvider);
  if (holders.isReady) {
    unawaited(ref.read(launchHoldersControllerProvider.notifier).reload());
  } else if (openIfIdle) {
    unawaited(
      ref.read(launchHoldersControllerProvider.notifier).open(launchId),
    );
  }
  final history = ref.read(launchHistoryControllerProvider);
  if (history.isReady) {
    unawaited(ref.read(launchHistoryControllerProvider.notifier).reload());
  } else if (openIfIdle) {
    unawaited(
      ref.read(launchHistoryControllerProvider.notifier).open(launchId),
    );
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

/// The catalogue is the one Launch read that outlives its page and may open
/// on a stored snapshot (decision 0095). The per-launch reads never do: each
/// of them is a subject the route names, and the purchase path re-reads it.
final class LaunchOverviewController
    extends LaunchReadController<LaunchOverview> {
  DateTime? _readAt;
  DateTime? _restoredObservedAt;

  /// When this device received the catalogue on screen, live or restored.
  DateTime? get valueObservedAt => _readAt;

  /// Non-null while the catalogue on screen is a stored snapshot.
  DateTime? get restoredObservedAt => _restoredObservedAt;

  DateTime _now() => ref.read(loopReadClockProvider)();

  @override
  LaunchResourceState<LaunchOverview> build() {
    final initial = super.build();
    ref.watch(loopAccountScopeProvider);
    _readAt = null;
    _restoredObservedAt = null;
    loopRetainRead(ref, onRevisit: _revisit);
    if (initial.mode == LaunchGatewayMode.unavailable) return initial;
    final restored = ref
        .read(loopSnapshotRestorerProvider)
        ?.restore(LoopSnapshotResource.launchOverview);
    final value = restored?.value;
    if (restored == null || value is! LaunchOverview) return initial;
    _readAt = restored.observedAt;
    _restoredObservedAt = restored.observedAt;
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(reload());
    });
    return LaunchResourceState<LaunchOverview>(
      mode: initial.mode,
      phase: LaunchViewPhase.ready,
      value: value,
    );
  }

  void _revisit() {
    if (state.phase == LaunchViewPhase.loading && state.value == null) return;
    if (!loopRevisitIsDue(
      hasValue: state.value != null,
      inFlight: inFlight,
      readAt: _readAt,
      now: _now(),
    )) {
      return;
    }
    unawaited(reload());
  }

  @override
  Future<LaunchOverview> fetch(LaunchGateway gateway) async {
    final overview = await gateway.loadOverview();
    _readAt = _now();
    _restoredObservedAt = null;
    return overview;
  }
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

/// The purchase form (decision 0088).
///
/// The page opens the main action only while the capability is settled and
/// the four axes read `LIVE` + `ACTIVE`; every refusal after that comes from
/// the server. A prepared intent is the server's canonical payload and is held
/// here only until the signing exit consumes it.
@immutable
final class LaunchTradeState {
  const LaunchTradeState({
    required this.mode,
    this.busy = false,
    this.refusalKind,
    this.refusalReasonCode,
    this.attempted = false,
    this.prepared,
    this.signOutcomeStatus,
    this.signReasonCode,
    this.txHash,
    this.reported,
    this.reporting = false,
    this.polling = false,
    this.pollTimedOut = false,
  });

  final LaunchGatewayMode mode;
  final bool busy;
  final LaunchFailureKind? refusalKind;

  /// The server's `detailsSafe.reasonCode` for [refusalKind], when named.
  final String? refusalReasonCode;

  /// True once the server has answered at least one intent attempt.
  final bool attempted;

  /// The server's prepared intent, awaiting the signing exit.
  final LaunchPurchasePrepared? prepared;

  /// How the last trip through the signing exit ended, by name. It is a
  /// statement of what the wallet did, never of what the chain did.
  final String? signOutcomeStatus;
  final String? signReasonCode;

  /// What the wallet broadcast, when it did. Its presence locks the page.
  final String? txHash;

  /// The server's intent after the broadcast report (decision 0089): its
  /// `state` is the server's, shown as it is and never upgraded here.
  final LaunchPurchaseIntent? reported;

  /// A report (or a repeated report of the same hash) is in flight.
  final bool reporting;

  /// [reported] is being read back (S92b2): every 5 s after the broadcast
  /// report, until it settles or [launchIntentMaxPolls] reads ran out.
  final bool polling;

  /// The read-back window ran out without a settled state; the page offers
  /// a re-read.
  final bool pollTimedOut;

  /// The server settled the broadcast (S92a.6). The attempt stays on screen
  /// — the page never offers a second signature of the same intent — but it
  /// may now be dismissed so a new purchase can be prepared.
  bool get settled => reported?.state.isSettled ?? false;

  /// Once the wallet has produced a hash, or its outcome is unknown, the
  /// page may never offer a second signature for this attempt.
  bool get locked =>
      signOutcomeStatus == 'locked' ||
      signOutcomeStatus == 'reportRefused' ||
      signOutcomeStatus == 'submitted' ||
      txHash != null;

  /// A broadcast the server has not recorded, whose report may be sent again
  /// with the same hash.
  bool get reportRetryable =>
      signOutcomeStatus == 'reportRefused' &&
      txHash != null &&
      launchReportRetryable(signReasonCode ?? '');
}

final class LaunchTradeController extends Notifier<LaunchTradeState>
    with LaunchSingleFlight {
  late final LaunchIntentPoller _poller = LaunchIntentPoller(
    load: (current) => ref
        .read(launchGatewayProvider)
        .loadIntent(
          launchId: current.launchId,
          launchIntentId: current.launchIntentId,
        ),
    onRead: (intent, {required polling, required timedOut}) {
      if (!ref.mounted) return;
      state = _withRead(intent, polling: polling, timedOut: timedOut);
    },
  );

  @override
  LaunchTradeState build() {
    nextGeneration();
    final mode = ref.watch(launchGatewayProvider).mode;
    ref.onDispose(() {
      nextGeneration();
      _poller.stop();
    });
    return LaunchTradeState(mode: mode);
  }

  /// Asks the server to prepare one purchase intent. While the contract is
  /// unconfigured the server answers `503`, and the page renders that refusal
  /// with the server's own reason.
  Future<void> prepare({
    required String launchId,
    required String walletId,
    required String roundId,
    required String payAmount,
  }) => single(() async {
    if (state.locked) return;
    final gateway = ref.read(launchGatewayProvider);
    final generation = nextGeneration();
    state = LaunchTradeState(mode: state.mode, busy: true, attempted: true);
    try {
      final prepared = await gateway.preparePurchaseIntent(
        launchId: launchId,
        walletId: walletId,
        roundId: roundId,
        payAmount: payAmount,
      );
      if (!isCurrent(generation)) return;
      state = LaunchTradeState(
        mode: state.mode,
        attempted: true,
        prepared: prepared,
      );
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = LaunchTradeState(
        mode: state.mode,
        refusalKind: error.kind,
        refusalReasonCode: error.reasonCode,
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

  /// Records what the signing exit reported. A hash or an unknown outcome
  /// keeps the prepared intent on screen and locks the form.
  ///
  /// A broadcast the server recorded is then read back with the same loop
  /// the claim and refund use (S92b2), until it settles.
  void recordSignOutcome(LaunchSignOutcome outcome) {
    _poller.stop();
    final reported = outcome.reported;
    state = LaunchTradeState(
      mode: state.mode,
      attempted: true,
      prepared: state.prepared,
      signOutcomeStatus: outcome.status.name,
      signReasonCode: outcome.reasonCode,
      txHash: outcome.txHash,
      reported: reported,
      polling: reported != null && !reported.state.isSettled,
    );
    if (reported != null) {
      _poller.start(reported, ref.read(launchIntentPollIntervalProvider));
    }
  }

  /// Reads the intent again after the window ran out without an answer.
  void resumePolling() {
    final reported = state.reported;
    if (reported == null || state.settled || state.polling) return;
    state = _withRead(reported, polling: true, timedOut: false);
    _poller.start(reported, ref.read(launchIntentPollIntervalProvider));
  }

  LaunchTradeState _withRead(
    LaunchPurchaseIntent intent, {
    required bool polling,
    required bool timedOut,
  }) => LaunchTradeState(
    mode: state.mode,
    attempted: true,
    prepared: state.prepared,
    signOutcomeStatus: state.signOutcomeStatus,
    signReasonCode: state.signReasonCode,
    txHash: state.txHash,
    reported: intent,
    polling: polling,
    pollTimedOut: timedOut,
  );

  /// Sends the same hash again after a report that did not land. The server
  /// answers a repeated hash unchanged, so this can never create a second
  /// purchase; it only lets the server learn about the first.
  Future<void> retryReport() => single(() async {
    final prepared = state.prepared;
    final hash = state.txHash;
    if (prepared == null || hash == null || !state.reportRetryable) return;
    final before = state;
    state = LaunchTradeState(
      mode: before.mode,
      attempted: true,
      prepared: prepared,
      signOutcomeStatus: before.signOutcomeStatus,
      signReasonCode: before.signReasonCode,
      txHash: hash,
      reporting: true,
    );
    final outcome = await ref
        .read(launchPurchaseSignerProvider)
        .report(prepared.intent, txHash: hash);
    recordSignOutcome(outcome);
  });

  /// Drops a prepared intent that was never handed to a wallet, or a refusal,
  /// so a fresh one can be prepared. A locked attempt is never discarded
  /// while the server has not settled it.
  /// A settled broadcast (S92b2) may be dismissed too.
  void discard() {
    if (state.locked && !state.settled) return;
    nextGeneration();
    _poller.stop();
    state = LaunchTradeState(mode: state.mode);
  }
}

final launchTradeControllerProvider =
    NotifierProvider.autoDispose<LaunchTradeController, LaunchTradeState>(
      LaunchTradeController.new,
    );
