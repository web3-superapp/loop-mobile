import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_gateway.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';

// ---------------------------------------------------------------------------
// MEME v2 project side · controllers (S135, decision 0138)
// ---------------------------------------------------------------------------

/// The catalogue project is read through the Launch port, whose failures are
/// [LaunchException]s. The project side speaks [LoopChainException] only.
LoopChainException launch2ChainFailureOf(LaunchException error) {
  final kind = switch (error.kind) {
    LaunchFailureKind.offline => LoopChainFailureKind.offline,
    LaunchFailureKind.timedOut => LoopChainFailureKind.timedOut,
    LaunchFailureKind.cancelled => LoopChainFailureKind.cancelled,
    LaunchFailureKind.outcomeUnknown => LoopChainFailureKind.outcomeUnknown,
    LaunchFailureKind.unavailable => LoopChainFailureKind.unavailable,
    LaunchFailureKind.permissionDenied ||
    LaunchFailureKind.policyBlocked ||
    LaunchFailureKind.activationRequired =>
      LoopChainFailureKind.permissionDenied,
    LaunchFailureKind.notFound => LoopChainFailureKind.notFound,
    LaunchFailureKind.stale ||
    LaunchFailureKind.versionConflict => LoopChainFailureKind.versionConflict,
    LaunchFailureKind.bootstrapRequired =>
      LoopChainFailureKind.bootstrapRequired,
    LaunchFailureKind.validationFailed => LoopChainFailureKind.validationFailed,
    LaunchFailureKind.idempotencyConflict =>
      LoopChainFailureKind.idempotencyConflict,
    LaunchFailureKind.insufficientBalance =>
      LoopChainFailureKind.insufficientBalance,
    LaunchFailureKind.invalidData => LoopChainFailureKind.invalidData,
    LaunchFailureKind.unexpected => LoopChainFailureKind.unexpected,
  };
  return LoopChainException(
    kind,
    reasonCode:
        error.reasonCode ??
        (error.kind == LaunchFailureKind.activationRequired
            ? 'PROFILE_ACTIVATION_REQUIRED'
            : null),
  );
}

Future<T> _launch<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on LaunchException catch (error) {
    throw launch2ChainFailureOf(error);
  }
}

LoopChainGatewayMode _mode(Ref ref) =>
    ref.watch(launch2CreatorGatewayProvider.select((gateway) => gateway.mode));

/// How often the progress page re-reads a job (contract §6 suggests 5 s).
@immutable
final class Launch2CreatorPolling {
  const Launch2CreatorPolling({
    this.deploymentInterval = const Duration(seconds: 5),
    this.instanceInterval = const Duration(seconds: 6),
    this.instanceMaxAttempts = 10,
  });

  final Duration deploymentInterval;

  /// After `activated`, the read model lists the instance a little later.
  final Duration instanceInterval;
  final int instanceMaxAttempts;
}

final launch2CreatorPollingProvider = Provider<Launch2CreatorPolling>(
  (ref) => const Launch2CreatorPolling(),
);

// -- 我的项目 -----------------------------------------------------------------

/// `launch2-projects` · the owner's MEME v2 catalogue projects
/// (`GET /v2/launch/projects?kind=launch2`, decision 0142), each with its
/// `hooks-config` read (draft, approval, newest task, lead) and — for an
/// activated one — the instance the read model lists, so a tap can land
/// straight on the right page.
final class Launch2CreatorListController
    extends LoopChainReadController<Launch2CreatorPage> {
  bool _appendFailed = false;

  bool get appendFailed => _appendFailed;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _mode(ref);

  Future<Launch2CreatorPage> _page(String? cursor) async {
    final page = await _launch(
      () => ref
          .read(launchGatewayProvider)
          .listProjects(cursor: cursor, kind: LaunchProjectKind.launch2),
    );
    final creator = ref.read(launch2CreatorGatewayProvider);
    final rows = await Future.wait<Launch2CreatorProject>(
      <Future<Launch2CreatorProject>>[
        for (final project in page.items) _row(creator, project),
      ],
    );
    return Launch2CreatorPage(rows: rows, nextCursor: page.nextCursor);
  }

  static Future<Launch2CreatorProject> _row(
    Launch2CreatorGateway creator,
    LaunchProject project,
  ) async {
    final config = await creator.loadConfig(project.projectId);
    return Launch2CreatorProject(
      project: project,
      config: config,
      instance: await _instanceOf(creator, project.projectId, config),
    );
  }

  @override
  Future<Launch2CreatorPage> fetch() {
    _appendFailed = false;
    return _page(null);
  }

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || state.busy) return;
    _appendFailed = false;
    state = state.working(true);
    try {
      final next = await _page(cursor);
      if (!ref.mounted) return;
      state = state.working(false).ready(current.append(next));
    } on LoopChainException catch (error) {
      if (!ref.mounted) return;
      _appendFailed = true;
      state = state.working(false).failed(error.kind);
    } catch (_) {
      if (!ref.mounted) return;
      _appendFailed = true;
      state = state.working(false).failed(LoopChainFailureKind.readFailed);
    }
  }
}

final launch2CreatorListControllerProvider =
    NotifierProvider.autoDispose<
      Launch2CreatorListController,
      LoopChainResourceState<Launch2CreatorPage>
    >(Launch2CreatorListController.new);

// -- One project --------------------------------------------------------------

/// The instance an activated project became, best effort: the list being
/// unreadable does not make the project unreadable.
Future<Launch2InstanceRef?> _instanceOf(
  Launch2CreatorGateway creator,
  String projectId,
  Launch2HooksConfig config,
) async {
  if (config.currentJob?.status != Launch2JobStatus.activated) return null;
  try {
    return await creator.findInstance(projectId);
  } on LoopChainException {
    return null;
  }
}

/// `launch2-project` · one project: the catalogue record and its
/// `hooks-config` read, which since loop-api decision 0120 carries the
/// approval and the newest task, so a cold start resumes where the owner
/// left off; once activated, the instance the read model lists.
final class Launch2ProjectController
    extends LoopChainReadController<Launch2CreatorProject> {
  Launch2ProjectController(this.projectId);

  final String projectId;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _mode(ref);

  @override
  Future<Launch2CreatorProject> fetch() async {
    final creator = ref.read(launch2CreatorGatewayProvider);
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _launch(() => ref.read(launchGatewayProvider).loadProject(projectId)),
      creator.loadConfig(projectId),
    ]);
    final project = results[0]! as LaunchProject;
    final config = results[1]! as Launch2HooksConfig;
    return Launch2CreatorProject(
      project: project,
      config: config,
      instance: await _instanceOf(creator, projectId, config),
    );
  }
}

final launch2ProjectControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2ProjectController,
      LoopChainResourceState<Launch2CreatorProject>,
      String
    >(Launch2ProjectController.new);

// -- 资料页：create, or edit a returned / draft project ----------------------

enum Launch2SaveStage { project, config, submit }

enum Launch2SavePhase { idle, saving, failed, done }

@immutable
final class Launch2SaveState {
  const Launch2SaveState({
    this.phase = Launch2SavePhase.idle,
    this.stage,
    this.projectId,
    this.failure,
    this.minSaleLead,
    this.earliestSaleStart,
  });

  final Launch2SavePhase phase;

  /// Where the save is, or where it stopped.
  final Launch2SaveStage? stage;

  /// The catalogue project, once it exists. A retry continues from it rather
  /// than creating a second one.
  final String? projectId;
  final LoopChainException? failure;

  /// The server's sale lead, once a `hooks-config` read gave it.
  final Duration? minSaleLead;

  /// Set when the save stopped before writing because the chosen sale start
  /// is earlier than this (the server's lead read just now).
  final DateTime? earliestSaleStart;

  bool get busy => phase == Launch2SavePhase.saving;
}

/// The three writes behind 「提交审核」, in order: the catalogue project
/// (`POST`, or a CAS `PUT` when editing), the Hooks draft (CAS `PUT`), and the
/// review submission. Each step that landed is not repeated by a retry.
final class Launch2SaveController extends Notifier<Launch2SaveState> {
  Launch2SaveController(this.scope);

  /// `new`, or the project id being edited.
  final String scope;

  bool _projectSaved = false;
  bool _configSaved = false;

  @override
  Launch2SaveState build() {
    ref.watch(loopAccountScopeProvider);
    return Launch2SaveState(projectId: scope == 'new' ? null : scope);
  }

  /// Runs the remaining steps. [existing] is the project being edited;
  /// `null` for a new project, which is created as `kind: launch2`
  /// (decision 0142). [now] is the page's clock: before writing the draft the
  /// controller reads `hooks-config` (the current version for the CAS and
  /// the server's sale lead) and stops, without writing, when the chosen
  /// start is already earlier than now + lead.
  Future<String?> save({
    required LaunchProjectDraft project,
    required Launch2ConfigInput config,
    required DateTime now,
    LaunchProject? existing,
  }) async {
    if (state.busy) return null;
    final launch = ref.read(launchGatewayProvider);
    final creator = ref.read(launch2CreatorGatewayProvider);
    var projectId = state.projectId;
    var lead = state.minSaleLead;
    var stage = Launch2SaveStage.project;
    state = Launch2SaveState(
      phase: Launch2SavePhase.saving,
      stage: stage,
      projectId: projectId,
      minSaleLead: lead,
    );
    try {
      final editable = existing == null || existing.reviewStatus.isEditable;
      if (!_projectSaved) {
        if (projectId == null) {
          final created = await _launch(
            () => launch.createProject(
              LaunchProjectDraft(
                name: project.name,
                ticker: project.ticker,
                narrative: project.narrative,
                officialLinks: project.officialLinks,
                kind: LaunchProjectKind.launch2,
              ),
            ),
          );
          projectId = created.projectId;
        } else if (existing != null && editable) {
          final version = existing.version;
          if (version == null) {
            throw const LoopChainException(LoopChainFailureKind.notFound);
          }
          await _launch(
            () => launch.updateProject(
              projectId: projectId!,
              expectedVersion: version,
              draft: project,
            ),
          );
        }
        _projectSaved = true;
      }
      final id = projectId!;
      stage = Launch2SaveStage.config;
      state = Launch2SaveState(
        phase: Launch2SavePhase.saving,
        stage: stage,
        projectId: id,
        minSaleLead: lead,
      );
      if (!_configSaved) {
        final current = await creator.loadConfig(id);
        lead = current.minSaleLead;
        final earliest = launch2EarliestSaleStart(now, lead);
        if (config.nftSaleStart.isBefore(earliest)) {
          state = Launch2SaveState(
            phase: Launch2SavePhase.failed,
            stage: stage,
            projectId: id,
            minSaleLead: lead,
            earliestSaleStart: earliest,
          );
          return null;
        }
        var expected = current.draft?.version ?? 0;
        try {
          await creator.saveConfig(
            projectId: id,
            expectedVersion: expected,
            input: config,
          );
        } on LoopChainException catch (error) {
          // Another version landed since the read: read the latest and save
          // once more over it, never in a loop.
          if (error.kind != LoopChainFailureKind.versionConflict) rethrow;
          expected = (await creator.loadConfig(id)).draft?.version ?? 0;
          await creator.saveConfig(
            projectId: id,
            expectedVersion: expected,
            input: config,
          );
        }
        _configSaved = true;
      }
      if (editable) {
        stage = Launch2SaveStage.submit;
        state = Launch2SaveState(
          phase: Launch2SavePhase.saving,
          stage: stage,
          projectId: id,
          minSaleLead: lead,
        );
        await _launch(() => launch.submitProject(id));
      }
      state = Launch2SaveState(
        phase: Launch2SavePhase.done,
        stage: stage,
        projectId: id,
        minSaleLead: lead,
      );
      return id;
    } on LoopChainException catch (error) {
      state = Launch2SaveState(
        phase: Launch2SavePhase.failed,
        stage: stage,
        projectId: projectId,
        failure: error,
        minSaleLead: lead,
      );
      return null;
    } catch (_) {
      state = Launch2SaveState(
        phase: Launch2SavePhase.failed,
        stage: stage,
        projectId: projectId,
        failure: const LoopChainException(LoopChainFailureKind.unexpected),
        minSaleLead: lead,
      );
      return null;
    }
  }

  /// The config content changed after a saved attempt: it is saved again.
  void contentChanged() {
    _configSaved = false;
  }
}

final launch2SaveControllerProvider = NotifierProvider.autoDispose
    .family<Launch2SaveController, Launch2SaveState, String>(
      Launch2SaveController.new,
    );

// -- 签名部署 -------------------------------------------------------------------

enum Launch2SignPhase {
  /// The signing request is being read (or re-read after a conflict).
  loading,

  /// A request is on screen and may be signed.
  ready,

  /// The wallet is open.
  signing,

  /// The signature is being submitted.
  submitting,

  /// A job exists; the page moves to the progress page.
  submitted,

  /// The read or the submit failed; [Launch2SignState.failure] says why.
  failed,
}

@immutable
final class Launch2SignState {
  const Launch2SignState({
    this.phase = Launch2SignPhase.loading,
    this.request,
    this.failure,
    this.walletRefusal,
    this.refreshedAfterConflict = false,
    this.job,
  });

  final Launch2SignPhase phase;
  final Launch2SigningRequest? request;
  final LoopChainException? failure;

  /// The wallet's own refusal code, when it refused.
  final String? walletRefusal;

  /// The submit answered `409 VERSION_CONFLICT` and the request on screen is
  /// the re-read one: the owner signs again.
  final bool refreshedAfterConflict;
  final Launch2DeploymentJob? job;

  bool get busy =>
      phase == Launch2SignPhase.loading ||
      phase == Launch2SignPhase.signing ||
      phase == Launch2SignPhase.submitting;

  Launch2SignState copyWith({
    Launch2SignPhase? phase,
    Launch2SigningRequest? request,
    LoopChainException? failure,
    String? walletRefusal,
    bool? refreshedAfterConflict,
    Launch2DeploymentJob? job,
  }) => Launch2SignState(
    phase: phase ?? this.phase,
    request: request ?? this.request,
    failure: failure,
    walletRefusal: walletRefusal,
    refreshedAfterConflict:
        refreshedAfterConflict ?? this.refreshedAfterConflict,
    job: job ?? this.job,
  );
}

final class Launch2SignController extends Notifier<Launch2SignState> {
  Launch2SignController(this.projectId);

  final String projectId;

  @override
  Launch2SignState build() {
    ref.watch(loopAccountScopeProvider);
    return const Launch2SignState();
  }

  /// Reads (or renews) the signing request for [walletId]. An expired
  /// deadline, a changed config and a changed nonce all mean the same thing:
  /// a new request and a new signature (§4).
  Future<void> load(String walletId, {bool afterConflict = false}) async {
    state = state.copyWith(phase: Launch2SignPhase.loading);
    try {
      final request = await ref
          .read(launch2CreatorGatewayProvider)
          .loadSigningRequest(projectId: projectId, walletId: walletId);
      if (!ref.mounted) return;
      state = Launch2SignState(
        phase: Launch2SignPhase.ready,
        request: request,
        refreshedAfterConflict: afterConflict,
      );
    } on LoopChainException catch (error) {
      if (!ref.mounted) return;
      state = Launch2SignState(phase: Launch2SignPhase.failed, failure: error);
    } catch (_) {
      if (!ref.mounted) return;
      state = const Launch2SignState(
        phase: Launch2SignPhase.failed,
        failure: LoopChainException(LoopChainFailureKind.readFailed),
      );
    }
  }

  /// Signs the request on screen and submits it. Returns the job, or `null`
  /// when anything refused; the state says what.
  Future<Launch2DeploymentJob?> signAndSubmit({
    required String walletId,
    required DateTime now,
  }) async {
    final request = state.request;
    if (request == null || state.busy) return null;
    if (request.expiredAt(now)) {
      state = state.copyWith(
        phase: Launch2SignPhase.failed,
        failure: const LoopChainException(
          LoopChainFailureKind.quoteExpired,
          reasonCode: 'HOOKS_SIGNATURE_EXPIRED',
        ),
      );
      return null;
    }
    state = state.copyWith(phase: Launch2SignPhase.signing);
    final signed = await ref
        .read(launch2TypedDataSignerProvider)
        .sign(
          ownerAddress: request.projectOwner,
          typedData: request.typedData,
          chainReference: request.domainChainId,
        );
    if (!ref.mounted) return null;
    final signature = signed.signature;
    if (signature == null) {
      state = state.copyWith(
        phase: Launch2SignPhase.ready,
        walletRefusal: signed.refusal,
      );
      return null;
    }
    state = state.copyWith(phase: Launch2SignPhase.submitting);
    try {
      final job = await ref
          .read(launch2CreatorGatewayProvider)
          .submitDeployment(
            projectId: projectId,
            walletId: walletId,
            request: request,
            signature: signature,
          );
      if (!ref.mounted) return job;
      state = state.copyWith(phase: Launch2SignPhase.submitted, job: job);
      return job;
    } on LoopChainException catch (error) {
      if (!ref.mounted) return null;
      if (error.kind == LoopChainFailureKind.versionConflict) {
        // The approved config, the nonce or an existing job moved: re-read
        // and sign again with a new key (§5).
        await load(walletId, afterConflict: true);
        return null;
      }
      state = state.copyWith(phase: Launch2SignPhase.failed, failure: error);
      return null;
    } catch (_) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        phase: Launch2SignPhase.failed,
        failure: const LoopChainException(LoopChainFailureKind.unexpected),
      );
      return null;
    }
  }
}

final launch2SignControllerProvider = NotifierProvider.autoDispose
    .family<Launch2SignController, Launch2SignState, String>(
      Launch2SignController.new,
    );

// -- 部署进度 -------------------------------------------------------------------

/// `launch2-project-deployment` · one job, re-read every
/// [Launch2CreatorPolling.deploymentInterval] until it settles.
final class Launch2DeploymentController
    extends LoopChainReadController<Launch2DeploymentJob> {
  Launch2DeploymentController(this.key);

  final ({String projectId, String jobId}) key;

  Timer? _timer;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() {
    ref.onDispose(() => _timer?.cancel());
    return _mode(ref);
  }

  @override
  Future<Launch2DeploymentJob> fetch() async {
    final job = await ref
        .read(launch2CreatorGatewayProvider)
        .loadDeployment(projectId: key.projectId, jobId: key.jobId);
    if (ref.mounted) _schedule(job);
    return job;
  }

  void _schedule(Launch2DeploymentJob job) {
    _timer?.cancel();
    if (job.settled) return;
    _timer = Timer(
      ref.read(launch2CreatorPollingProvider).deploymentInterval,
      () {
        if (ref.mounted) unawaited(reload());
      },
    );
  }

  @override
  Future<void> reload() async {
    await super.reload();
    // A failed read keeps polling: the job is still running on the server.
    if (!ref.mounted) return;
    final value = state.value;
    if (state.failureKind != null && (value == null || !value.settled)) {
      _timer?.cancel();
      _timer = Timer(
        ref.read(launch2CreatorPollingProvider).deploymentInterval,
        () {
          if (ref.mounted) unawaited(reload());
        },
      );
    }
  }
}

final launch2DeploymentControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2DeploymentController,
      LoopChainResourceState<Launch2DeploymentJob>,
      ({String projectId, String jobId})
    >(Launch2DeploymentController.new);

/// After `activated`: the instance the read model lists for the project,
/// asked a few times because indexing trails the chain.
final class Launch2InstanceLookup extends Notifier<Launch2InstanceRef?> {
  Launch2InstanceLookup(this.projectId);

  final String projectId;
  bool _started = false;

  @override
  Launch2InstanceRef? build() => null;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final polling = ref.read(launch2CreatorPollingProvider);
    for (var attempt = 0; attempt < polling.instanceMaxAttempts; attempt += 1) {
      try {
        final found = await ref
            .read(launch2CreatorGatewayProvider)
            .findInstance(projectId);
        if (!ref.mounted) return;
        if (found != null) {
          state = found;
          return;
        }
      } on LoopChainException {
        if (!ref.mounted) return;
      }
      await Future<void>.delayed(polling.instanceInterval);
      if (!ref.mounted) return;
    }
  }
}

final launch2InstanceLookupProvider = NotifierProvider.autoDispose
    .family<Launch2InstanceLookup, Launch2InstanceRef?, String>(
      Launch2InstanceLookup.new,
    );
