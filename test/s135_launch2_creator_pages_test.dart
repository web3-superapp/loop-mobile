import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_create_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_entry.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_gateway.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_deployment_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_project_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_projects_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_sign_screen.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S135 · MEME v2 project side pages (client decision 0138)
// ---------------------------------------------------------------------------

const String _projectId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const String _walletId = '00000000-0000-4000-8000-000000000099';
const String _jobId = '00000000-0000-4000-8000-000000000011';
const String _owner = '0x7777777777777777777777777777777777777777';
const String _instanceId = '8b9f3c1e-2d4a-4f6b-9c8d-1e2f3a4b5c6d';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Object? _body(String name) => (jsonDecode(
  File('test/fixtures/s135-launch2-creator/$name.json').readAsStringSync(),
) as Map<String, Object?>)['body'];

Launch2HooksDraft _draft() => LoopV2Launch2CreatorCodec.configEnvelope(
  _body('hooks_config_draft'),
  projectId: _projectId,
)!;

Launch2SigningRequest _request() =>
    LoopV2Launch2CreatorCodec.signingRequest(_body('hooks_signing_request'));

Launch2DeploymentJob _job(String name) =>
    LoopV2Launch2CreatorCodec.job(_body(name), projectId: _projectId);

/// Fifteen minutes before the sample request's deadline.
DateTime _beforeDeadline() => DateTime.utc(2026, 10, 3, 4);

/// One scripted answer: a value, a failure, or a read that never answers.
final class _A<T> {
  const _A.value(T this.value) : failure = null, pending = false;
  const _A.fail(LoopChainFailureKind kind, {String? reason})
    : value = null,
      failure = (kind, reason),
      pending = false;
  const _A.pending() : value = null, failure = null, pending = true;

  final T? value;
  final (LoopChainFailureKind, String?)? failure;
  final bool pending;

  Future<T> resolve() {
    if (pending) return Completer<T>().future;
    final f = failure;
    if (f != null) {
      return Future<T>.error(LoopChainException(f.$1, reasonCode: f.$2));
    }
    return Future<T>.value(value as T);
  }
}

T _pick<T>(List<T> answers, int index) =>
    answers[index < answers.length ? index : answers.length - 1];

final class _FakeCreator implements Launch2CreatorGateway {
  _FakeCreator({
    this.configs = const <_A<Launch2HooksDraft?>>[],
    this.saves = const <_A<Launch2HooksDraft>>[],
    this.requests = const <_A<Launch2SigningRequest>>[],
    this.submits = const <_A<Launch2DeploymentJob>>[],
    this.jobs = const <_A<Launch2DeploymentJob>>[],
    this.instances = const <_A<Launch2InstanceRef?>>[],
  });

  final List<_A<Launch2HooksDraft?>> configs;
  final List<_A<Launch2HooksDraft>> saves;
  final List<_A<Launch2SigningRequest>> requests;
  final List<_A<Launch2DeploymentJob>> submits;
  final List<_A<Launch2DeploymentJob>> jobs;
  final List<_A<Launch2InstanceRef?>> instances;

  int configReads = 0;
  final List<int> saveVersions = <int>[];
  final List<Launch2ConfigInput> saved = <Launch2ConfigInput>[];
  int requestReads = 0;
  final List<String> submittedSignatures = <String>[];
  int jobReads = 0;
  int instanceReads = 0;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2HooksDraft?> loadConfig(String projectId) {
    final index = configReads++;
    return configs.isEmpty
        ? Future<Launch2HooksDraft?>.value()
        : _pick(configs, index).resolve();
  }

  @override
  Future<Launch2HooksDraft> saveConfig({
    required String projectId,
    required int expectedVersion,
    required Launch2ConfigInput input,
  }) {
    final index = saveVersions.length;
    saveVersions.add(expectedVersion);
    saved.add(input);
    return saves.isEmpty ? _unavailable() : _pick(saves, index).resolve();
  }

  @override
  Future<Launch2SigningRequest> loadSigningRequest({
    required String projectId,
    required String walletId,
  }) {
    final index = requestReads++;
    return requests.isEmpty ? _unavailable() : _pick(requests, index).resolve();
  }

  @override
  Future<Launch2DeploymentJob> submitDeployment({
    required String projectId,
    required String walletId,
    required Launch2SigningRequest request,
    required String signature,
  }) {
    final index = submittedSignatures.length;
    submittedSignatures.add(signature);
    return submits.isEmpty ? _unavailable() : _pick(submits, index).resolve();
  }

  @override
  Future<Launch2DeploymentJob> loadDeployment({
    required String projectId,
    required String jobId,
  }) {
    final index = jobReads++;
    return jobs.isEmpty ? _unavailable() : _pick(jobs, index).resolve();
  }

  @override
  Future<Launch2InstanceRef?> findInstance(String projectId) {
    final index = instanceReads++;
    return instances.isEmpty
        ? Future<Launch2InstanceRef?>.value()
        : _pick(instances, index).resolve();
  }
}

/// The catalogue half: only the five project calls the project side makes.
final class _FakeLaunch implements LaunchGateway {
  _FakeLaunch({
    this.page,
    this.pageFailure,
    this.pagePending = false,
    LaunchProject? project,
    this.projectFailure,
  }) : project =
           project ??
           s7Project(
             projectId: _projectId,
             reviewStatus: LaunchReviewStatus.approved,
           );

  final LaunchProjectPage? page;
  final LaunchFailureKind? pageFailure;
  final bool pagePending;
  final LaunchProject project;
  final LaunchFailureKind? projectFailure;

  final List<LaunchProjectDraft> created = <LaunchProjectDraft>[];
  final List<(int, LaunchProjectDraft)> updated = <(int, LaunchProjectDraft)>[];
  final List<String> submitted = <String>[];

  @override
  Future<LaunchProjectPage> listProjects({String? status, String? cursor}) {
    if (pagePending) return Completer<LaunchProjectPage>().future;
    final failure = pageFailure;
    if (failure != null) {
      return Future<LaunchProjectPage>.error(LaunchException(failure));
    }
    return Future<LaunchProjectPage>.value(page);
  }

  @override
  Future<LaunchProject> loadProject(String projectId) {
    final failure = projectFailure;
    if (failure != null) {
      return Future<LaunchProject>.error(LaunchException(failure));
    }
    return Future<LaunchProject>.value(project);
  }

  @override
  Future<LaunchProject> createProject(LaunchProjectDraft draft) {
    created.add(draft);
    return Future<LaunchProject>.value(s7Project(projectId: _projectId));
  }

  @override
  Future<LaunchProject> updateProject({
    required String projectId,
    required int expectedVersion,
    required LaunchProjectDraft draft,
  }) {
    updated.add((expectedVersion, draft));
    return Future<LaunchProject>.value(
      s7Project(projectId: projectId, version: expectedVersion + 1),
    );
  }

  @override
  Future<LaunchProject> submitProject(String projectId) {
    submitted.add(projectId);
    return Future<LaunchProject>.value(
      s7Project(
        projectId: projectId,
        reviewStatus: LaunchReviewStatus.submitted,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// Only the picture upload is used by the project side.
final class _FakeMeme implements MemeGateway {
  int uploads = 0;

  @override
  Future<MemeUploadedImage> uploadImage({
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploads += 1;
    return const MemeUploadedImage(
      mediaId: '2b1f8c3e-1d2a-4b5c-8d9e-0f1a2b3c4d5e',
      url: 'https://api-dev.example/v2/media/2b1f8c3e-1d2a-4b5c-8d9e-0f1a2b3c4d5e.webp',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

final class _Picker implements AvatarImagePicker {
  @override
  bool get available => true;

  @override
  Future<PickedAvatarImage?> pick() async =>
      PickedAvatarImage(bytes: Uint8List.fromList(<int>[1, 2, 3]));
}

final class _Signer implements Launch2TypedDataSigner {
  _Signer({this.refusal});

  final String? refusal;
  final List<(String, Map<String, Object?>, int)> calls =
      <(String, Map<String, Object?>, int)>[];

  @override
  bool get available => true;

  @override
  Future<Launch2TypedDataResult> sign({
    required String ownerAddress,
    required Map<String, Object?> typedData,
    required int chainReference,
  }) async {
    calls.add((ownerAddress, typedData, chainReference));
    final code = refusal;
    if (code != null) return Launch2TypedDataResult.refused(code);
    return Launch2TypedDataResult.signed(
      '0x${(calls.length.toRadixString(16).padLeft(2, '0')) * 65}',
    );
  }
}

LoopV2MetaSnapshot _meta({
  LoopV2CapabilityAvailability launch2 = LoopV2CapabilityAvailability.available,
}) {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.launch2)
            LoopV2Capability(
              id: LoopV2CapabilityId.launch2,
              availability: launch2,
              reasonCode: launch2 == LoopV2CapabilityAvailability.available
                  ? null
                  : 'LAUNCH2_MODULE_NOT_ENABLED',
              evidence: const LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            )
          else
            capability,
      ],
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  _FakeCreator? creator,
  _FakeLaunch? launch,
  _Signer? signer,
  _FakeMeme? meme,
  LoopV2MetaSnapshot? meta,
  bool launch2Visible = true,
  bool settle = true,
  List<Override> overrides = const <Override>[],
}) => pumpS7Page(
  tester,
  page,
  launch: launch ?? _FakeLaunch(),
  meta: meta ?? _meta(),
  settle: settle,
  wallet: FakeWalletDirectory(
    activeWalletId: _walletId,
    wallets: <LoopWalletAccount>[
      LoopWalletAccount(
        walletId: _walletId,
        address: _owner,
        kind: LoopWalletKind.embedded,
        status: LoopWalletStatus.active,
        isActive: true,
        firstSeenAt: DateTime.utc(2026, 9),
        lastSeenAt: DateTime.utc(2026, 10, 8),
      ),
    ],
  ),
  overrides: <Override>[
    launch2CreatorGatewayProvider.overrideWithValue(creator ?? _FakeCreator()),
    launch2TypedDataSignerProvider.overrideWithValue(signer ?? _Signer()),
    launch2CreatorPollingProvider.overrideWithValue(
      const Launch2CreatorPolling(
        deploymentInterval: Duration(milliseconds: 20),
        instanceInterval: Duration(milliseconds: 20),
        instanceMaxAttempts: 3,
      ),
    ),
    memeGatewayProvider.overrideWithValue(meme ?? _FakeMeme()),
    avatarImagePickerProvider.overrideWithValue(_Picker()),
    loopFeatureSwitchesProvider.overrideWithValue(
      LoopFeatureSwitchValues(launch2Visible: launch2Visible),
    ),
    ...overrides,
  ],
);

/// Lets the pending timers of the page run out before teardown.
Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 30));
}

LaunchProjectPage _page(List<LaunchProject> items) =>
    LaunchProjectPage(items: items, nextCursor: null);

void main() {
  loopWatchGround();

  setUp(() {
    debugLaunch2CropOverride = (context, bytes) async => bytes;
  });
  tearDown(() => debugLaunch2CropOverride = null);

  group('entry', () {
    Widget host(List<String> opened) => Scaffold(
      body: Column(
        children: <Widget>[
          Launch2CreatorEntry(onNavigate: opened.add),
          Launch2MyProjectsEntry(onNavigate: opened.add),
        ],
      ),
    );

    testWidgets('the switch off draws no entry at all', (tester) async {
      await _pump(tester, host(<String>[]), launch2Visible: false);
      expect(_key('launch2-creator-entry'), findsNothing);
      expect(_key('launch2-my-projects-entry'), findsNothing);
    });

    testWidgets('a closed launch2 capability draws no entry', (tester) async {
      await _pump(
        tester,
        host(<String>[]),
        meta: _meta(launch2: LoopV2CapabilityAvailability.deferred),
      );
      expect(_key('launch2-creator-entry'), findsNothing);
    });

    testWidgets('switch on and launch2 available opens the create page', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(tester, host(opened));
      await tester.tap(_key('launch2-creator-entry'));
      await tester.tap(_key('launch2-my-projects-entry'));
      expect(opened, <String>[
        Launch2CreatorRoute.createPath,
        Launch2CreatorRoute.minePath,
      ]);
    });
  });

  group('资料页', () {
    Future<void> fillProfile(WidgetTester tester) async {
      await tester.tap(_key('launch2-create-upload'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('launch2-create-name'), 'MoonCat');
      await tester.enterText(_key('launch2-create-ticker'), 'mcat');
      await tester.pump();
    }

    Future<void> toSale(WidgetTester tester) async {
      await fillProfile(tester);
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('launch2-create-x'), 'https://x.com/mooncat');
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
    }

    Future<void> pickStart(WidgetTester tester) async {
      await tester.tap(_key('launch2-create-sale-start'));
      await tester.pumpAndSettle();
      expect(_key('launch2-sale-start-sheet'), findsOneWidget);
      await tester.tap(_key('launch2-sale-start-confirm'));
      await tester.pumpAndSettle();
    }

    testWidgets('three steps: the first refuses until picture, name and '
        'ticker are there; back goes one step', (tester) async {
      await _pump(tester, const Launch2CreateScreen());
      expect(_key('launch2-create-step-1'), findsOneWidget);
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      expect(_key('launch2-create-step-1'), findsOneWidget);
      expect(_key('launch2-create-logo-missing'), findsOneWidget);
      expect(find.text('代码 2–12 位字母或数字'), findsOneWidget);

      await fillProfile(tester);
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      expect(_key('launch2-create-step-2'), findsOneWidget);
      // A link must be https.
      await tester.enterText(_key('launch2-create-x'), 'http://x.com/a');
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      expect(find.text('只支持 https:// 开头的链接'), findsOneWidget);

      // The system back is the page's own back: one step.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_key('launch2-create-step-1'), findsOneWidget);
      expect(find.text('MoonCat'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('the sale step shows the default recipient and the fixed '
        'template; 提交审核 creates, saves the config and submits', (tester) async {
      final launch = _FakeLaunch();
      final creator = _FakeCreator(
        saves: <_A<Launch2HooksDraft>>[_A<Launch2HooksDraft>.value(_draft())],
      );
      final submitted = <String>[];
      await _pump(
        tester,
        Launch2CreateScreen(onSubmitted: submitted.add),
        launch: launch,
        creator: creator,
      );
      await toSale(tester);
      expect(_key('launch2-create-step-3'), findsOneWidget);
      expect(
        find.text(Launch2Template.defaultBuybackRecipient),
        findsOneWidget,
      );
      expect(_key('launch2-template-card'), findsOneWidget);
      expect(find.text('10 亿'), findsOneWidget);
      expect(find.text('8 亿'), findsOneWidget);
      expect(find.text('133,333.332 USD1'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('2%'), findsOneWidget);
      expect(find.text('0.5%'), findsOneWidget);
      expect(find.text('100 USD1'), findsOneWidget);
      expect(find.text('由平台模板固定，不能修改。'), findsOneWidget);

      // No sale start yet: the page asks for one, nothing is written.
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      expect(_key('launch2-create-sale-start-missing'), findsOneWidget);
      expect(launch.created, isEmpty);

      await pickStart(tester);
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();

      expect(launch.created.single.ticker, 'MCAT');
      expect(launch.created.single.officialLinks.x, 'https://x.com/mooncat');
      expect(creator.saveVersions, <int>[0]);
      final input = creator.saved.single;
      expect(input.ticker, 'MCAT');
      expect(input.links, <String>['https://x.com/mooncat']);
      expect(input.buybackRecipient, Launch2Template.defaultBuybackRecipient);
      expect(input.logoAssetUrl, startsWith('https://'));
      // The picker never offers less than the contract's floor.
      expect(
        input.nftSaleStart.isAfter(
          DateTime.now().add(Launch2Template.contractMinimumSaleLead),
        ),
        isTrue,
      );
      expect(launch.submitted, <String>[_projectId]);
      expect(submitted, <String>[_projectId]);
      await _drain(tester);
    });

    testWidgets('a refused config says why; the retry does not create a '
        'second project', (tester) async {
      final launch = _FakeLaunch();
      final creator = _FakeCreator(
        saves: <_A<Launch2HooksDraft>>[
          const _A<Launch2HooksDraft>.fail(LoopChainFailureKind.invalidData),
          _A<Launch2HooksDraft>.value(_draft()),
        ],
      );
      final submitted = <String>[];
      await _pump(
        tester,
        Launch2CreateScreen(onSubmitted: submitted.add),
        launch: launch,
        creator: creator,
      );
      await toSale(tester);
      await pickStart(tester);
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      expect(_key('launch2-create-failed-config'), findsOneWidget);
      expect(find.textContaining('NFT 开售时间太早'), findsOneWidget);
      expect(find.text('重试提交'), findsOneWidget);
      expect(submitted, isEmpty);

      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      expect(launch.created, hasLength(1));
      expect(creator.saveVersions, <int>[0, 0]);
      expect(submitted, <String>[_projectId]);
      await _drain(tester);
    });

    testWidgets('a CAS conflict re-reads the draft and saves once over it', (
      tester,
    ) async {
      final creator = _FakeCreator(
        configs: <_A<Launch2HooksDraft?>>[
          _A<Launch2HooksDraft?>.value(_draft()),
        ],
        saves: <_A<Launch2HooksDraft>>[
          const _A<Launch2HooksDraft>.fail(
            LoopChainFailureKind.versionConflict,
          ),
          _A<Launch2HooksDraft>.value(_draft()),
        ],
      );
      await _pump(tester, const Launch2CreateScreen(), creator: creator);
      await toSale(tester);
      await pickStart(tester);
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      expect(creator.saveVersions, <int>[0, 1]);
      await _drain(tester);
    });

    testWidgets('editing a returned project starts from the server copy and '
        'resubmits it', (tester) async {
      final launch = _FakeLaunch(
        project: s7Project(
          projectId: _projectId,
          reviewStatus: LaunchReviewStatus.returned,
          version: 3,
          reviewReasonCode: 'materials_incomplete',
        ),
      );
      final creator = _FakeCreator(
        configs: <_A<Launch2HooksDraft?>>[
          _A<Launch2HooksDraft?>.value(_draft()),
        ],
        saves: <_A<Launch2HooksDraft>>[_A<Launch2HooksDraft>.value(_draft())],
      );
      await _pump(
        tester,
        const Launch2CreateScreen(projectId: _projectId),
        launch: launch,
        creator: creator,
      );
      expect(find.text('修改资料'), findsOneWidget);
      expect(find.text('MoonCat'), findsOneWidget);
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      // The saved recipient, lower case as the server stores it.
      expect(
        find.text('0x28816c4c4792467390c90e5b426f198570e29307'),
        findsOneWidget,
      );
      await tester.tap(_key('launch2-create-next'));
      await tester.pumpAndSettle();
      expect(launch.created, isEmpty);
      expect(launch.updated.single.$1, 3);
      expect(creator.saveVersions, <int>[1]);
      expect(launch.submitted, <String>[_projectId]);
      await _drain(tester);
    });
  });

  group('我的项目', () {
    testWidgets('rows carry their state; a row opens its project', (
      tester,
    ) async {
      final second = s7Project(
        projectId: '4fa85f64-5717-4562-b3fc-2c963f66afa7',
        reviewStatus: LaunchReviewStatus.returned,
        reviewReasonCode: 'materials_incomplete',
        reviewReasonText: '请补充社区链接。',
      );
      final launch = _FakeLaunch(
        page: _page(<LaunchProject>[
          s7Project(
            projectId: _projectId,
            reviewStatus: LaunchReviewStatus.approved,
          ),
          second,
        ]),
      );
      final creator = _FakeCreator(
        configs: <_A<Launch2HooksDraft?>>[
          _A<Launch2HooksDraft?>.value(_draft()),
          const _A<Launch2HooksDraft?>.value(null),
        ],
      );
      final opened = <String>[];
      await _pump(
        tester,
        Launch2ProjectsScreen(onNavigate: opened.add),
        launch: launch,
        creator: creator,
      );
      expect(_key('launch2-status-approved'), findsOneWidget);
      expect(_key('launch2-status-rejected'), findsOneWidget);
      expect(find.text('请补充社区链接。'), findsOneWidget);
      await tester.tap(_key('launch2-project-row-$_projectId'));
      expect(opened.single, Launch2CreatorRoute.project(_projectId));
      await tester.tap(_key('launch2-projects-create'));
      expect(opened.last, Launch2CreatorRoute.createPath);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('no project is the illustrated empty state with one action', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(
        tester,
        Launch2ProjectsScreen(onNavigate: opened.add),
        launch: _FakeLaunch(page: _page(const <LaunchProject>[])),
      );
      expect(_key('launch2-projects-empty'), findsOneWidget);
      expect(_key('loop-empty-illustration-launchpad'), findsOneWidget);
      await tester.tap(_key('launch2-projects-empty-create'));
      expect(opened.single, Launch2CreatorRoute.createPath);
    });

    testWidgets('loading, error, offline, unavailable and permission', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2ProjectsScreen(),
        launch: _FakeLaunch(pagePending: true),
        settle: false,
      );
      expect(_key('launch2-projects-state-loading'), findsOneWidget);
      await _drain(tester);

      for (final (failure, state) in <(LaunchFailureKind, String)>[
        (LaunchFailureKind.invalidData, 'error'),
        (LaunchFailureKind.offline, 'offline'),
        (LaunchFailureKind.unavailable, 'unavailable'),
        (LaunchFailureKind.permissionDenied, 'permission'),
      ]) {
        await _pump(
          tester,
          const Launch2ProjectsScreen(),
          launch: _FakeLaunch(pageFailure: failure),
        );
        expect(
          _key('launch2-projects-state-$state'),
          findsOneWidget,
          reason: failure.name,
        );
        await _drain(tester);
      }
    });
  });

  group('项目状态', () {
    testWidgets('returned shows the reviewer sentence and resubmits', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(
        tester,
        Launch2ProjectScreen(projectId: _projectId, onNavigate: opened.add),
        launch: _FakeLaunch(
          project: s7Project(
            projectId: _projectId,
            reviewStatus: LaunchReviewStatus.returned,
            reviewReasonCode: 'materials_incomplete',
            reviewReasonText: '请补充社区链接。',
          ),
        ),
        creator: _FakeCreator(
          configs: <_A<Launch2HooksDraft?>>[
            _A<Launch2HooksDraft?>.value(_draft()),
          ],
        ),
      );
      expect(_key('launch2-milestones-rejected'), findsOneWidget);
      expect(find.text('请补充社区链接。'), findsOneWidget);
      await tester.tap(_key('launch2-project-resubmit'));
      expect(opened.single, Launch2CreatorRoute.edit(_projectId));
    });

    testWidgets('under review there is nothing to do but wait', (tester) async {
      await _pump(
        tester,
        const Launch2ProjectScreen(projectId: _projectId),
        launch: _FakeLaunch(
          project: s7Project(
            projectId: _projectId,
            reviewStatus: LaunchReviewStatus.inReview,
            submittedAt: DateTime.utc(2026, 10, 9, 7),
          ),
        ),
        creator: _FakeCreator(
          configs: <_A<Launch2HooksDraft?>>[
            _A<Launch2HooksDraft?>.value(_draft()),
          ],
        ),
      );
      expect(_key('launch2-status-awaiting_approval'), findsOneWidget);
      expect(_key('launch2-project-next-review'), findsOneWidget);
      for (final action in <String>[
        'launch2-project-continue',
        'launch2-project-sign',
        'launch2-project-resubmit',
      ]) {
        expect(_key(action), findsNothing);
      }
    });

    testWidgets('approved opens signing; an activated instance opens the '
        'user page', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        Launch2ProjectScreen(projectId: _projectId, onNavigate: opened.add),
        creator: _FakeCreator(
          configs: <_A<Launch2HooksDraft?>>[
            _A<Launch2HooksDraft?>.value(_draft()),
          ],
        ),
      );
      expect(_key('launch2-status-approved'), findsOneWidget);
      // The template is the saved draft's own.
      expect(_key('launch2-template-card'), findsOneWidget);
      expect(find.text('7 天'), findsOneWidget);
      await tester.tap(_key('launch2-project-sign'));
      expect(opened.single, Launch2CreatorRoute.sign(_projectId));
      await _drain(tester);

      final instances = <String>[];
      await _pump(
        tester,
        Launch2ProjectScreen(
          projectId: _projectId,
          onOpenInstance: instances.add,
        ),
        creator: _FakeCreator(
          configs: <_A<Launch2HooksDraft?>>[
            _A<Launch2HooksDraft?>.value(_draft()),
          ],
          instances: <_A<Launch2InstanceRef?>>[
            const _A<Launch2InstanceRef?>.value(
              Launch2InstanceRef(
                instanceId: _instanceId,
                projectId: _projectId,
                stage: 'upcoming',
              ),
            ),
          ],
        ),
      );
      expect(_key('launch2-status-active'), findsOneWidget);
      await tester.tap(_key('launch2-project-open-instance'));
      expect(instances.single, _instanceId);
    });

    testWidgets('loading, error, offline, unavailable and permission', (
      tester,
    ) async {
      for (final (failure, state) in <(LaunchFailureKind, String)>[
        (LaunchFailureKind.invalidData, 'error'),
        (LaunchFailureKind.offline, 'offline'),
        (LaunchFailureKind.unavailable, 'unavailable'),
        (LaunchFailureKind.permissionDenied, 'permission'),
      ]) {
        await _pump(
          tester,
          const Launch2ProjectScreen(projectId: _projectId),
          launch: _FakeLaunch(projectFailure: failure),
        );
        expect(
          _key('launch2-project-state-$state'),
          findsOneWidget,
          reason: failure.name,
        );
        await _drain(tester);
      }
      await _pump(
        tester,
        const Launch2ProjectScreen(projectId: _projectId),
        creator: _FakeCreator(
          configs: <_A<Launch2HooksDraft?>>[
            const _A<Launch2HooksDraft?>.pending(),
          ],
        ),
        settle: false,
      );
      expect(_key('launch2-project-state-loading'), findsOneWidget);
      await _drain(tester);

      await _pump(tester, const Launch2ProjectScreen(projectId: null));
      expect(_key('launch2-project-missing'), findsOneWidget);
    });
  });

  group('签名部署', () {
    testWidgets('the predicted address and the EIP-712 summary are signed '
        'through the sign sheet and submitted as one job', (tester) async {
      final signer = _Signer();
      final creator = _FakeCreator(
        requests: <_A<Launch2SigningRequest>>[
          _A<Launch2SigningRequest>.value(_request()),
        ],
        submits: <_A<Launch2DeploymentJob>>[
          _A<Launch2DeploymentJob>.value(_job('hooks_deployment_created')),
        ],
      );
      final submitted = <(String, String)>[];
      await _pump(
        tester,
        Launch2SignScreen(
          projectId: _projectId,
          clock: _beforeDeadline,
          onSubmitted: (project, job) => submitted.add((project, job)),
        ),
        creator: creator,
        signer: signer,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_key('launch2-sign-meme-address'), findsOneWidget);
      expect(find.text('MoonCat'), findsOneWidget);
      expect(find.text('\$MCAT'), findsOneWidget);
      expect(find.text('BSC 测试网'), findsOneWidget);
      expect(find.textContaining('后过期'), findsOneWidget);

      await tester.tap(_key('launch2-sign-submit'));
      await tester.pumpAndSettle();
      expect(_key('launch2-sign-sheet'), findsOneWidget);
      expect(find.text('授权部署 \$MCAT'), findsOneWidget);
      expect(signer.calls, isEmpty);
      await tester.tap(find.text('签名'));
      await tester.pumpAndSettle();
      expect(signer.calls.single.$1, _owner);
      expect(signer.calls.single.$3, 97);
      expect(signer.calls.single.$2['primaryType'], 'LaunchRequest');
      expect(creator.submittedSignatures, hasLength(1));
      expect(submitted.single, (_projectId, _jobId));
      await _drain(tester);
    });

    testWidgets('a 409 re-reads the request and asks for a new signature', (
      tester,
    ) async {
      final creator = _FakeCreator(
        requests: <_A<Launch2SigningRequest>>[
          _A<Launch2SigningRequest>.value(_request()),
        ],
        submits: <_A<Launch2DeploymentJob>>[
          const _A<Launch2DeploymentJob>.fail(
            LoopChainFailureKind.versionConflict,
          ),
          _A<Launch2DeploymentJob>.value(_job('hooks_deployment_created')),
        ],
      );
      final submitted = <(String, String)>[];
      await _pump(
        tester,
        Launch2SignScreen(
          projectId: _projectId,
          clock: _beforeDeadline,
          onSubmitted: (project, job) => submitted.add((project, job)),
        ),
        creator: creator,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_key('launch2-sign-submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('签名'));
      await tester.pumpAndSettle();
      expect(creator.requestReads, 2);
      expect(_key('launch2-sign-refreshed'), findsOneWidget);
      expect(submitted, isEmpty);

      await tester.tap(_key('launch2-sign-submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('签名'));
      await tester.pumpAndSettle();
      // A new signature, so a new action.
      expect(creator.submittedSignatures, hasLength(2));
      expect(
        creator.submittedSignatures.first,
        isNot(creator.submittedSignatures.last),
      );
      expect(submitted.single, (_projectId, _jobId));
      await _drain(tester);
    });

    testWidgets('an expired request is renewed, never signed', (tester) async {
      final signer = _Signer();
      final creator = _FakeCreator(
        requests: <_A<Launch2SigningRequest>>[
          _A<Launch2SigningRequest>.value(_request()),
        ],
      );
      await _pump(
        tester,
        Launch2SignScreen(
          projectId: _projectId,
          clock: () => DateTime.utc(2026, 10, 3, 5),
        ),
        creator: creator,
        signer: signer,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(_key('launch2-sign-expired'), findsOneWidget);
      expect(_key('launch2-sign-submit'), findsNothing);
      await tester.tap(_key('launch2-sign-renew'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(creator.requestReads, 2);
      expect(signer.calls, isEmpty);
      await _drain(tester);
    });

    testWidgets('an unapproved config and a declined wallet both say why', (
      tester,
    ) async {
      final creator = _FakeCreator(
        requests: <_A<Launch2SigningRequest>>[
          _A<Launch2SigningRequest>.value(_request()),
        ],
        submits: <_A<Launch2DeploymentJob>>[
          const _A<Launch2DeploymentJob>.fail(
            LoopChainFailureKind.permissionDenied,
            reason: 'HOOKS_CONFIG_NOT_APPROVED',
          ),
        ],
      );
      await _pump(
        tester,
        Launch2SignScreen(projectId: _projectId, clock: _beforeDeadline),
        creator: creator,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_key('launch2-sign-submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('签名'));
      await tester.pumpAndSettle();
      expect(
        _key('launch2-sign-failed-HOOKS_CONFIG_NOT_APPROVED'),
        findsOneWidget,
      );
      expect(find.text('配置还在等平台审批，审批通过后再签名。'), findsOneWidget);
      await _drain(tester);

      final declined = _FakeCreator(
        requests: <_A<Launch2SigningRequest>>[
          _A<Launch2SigningRequest>.value(_request()),
        ],
      );
      await _pump(
        tester,
        Launch2SignScreen(projectId: _projectId, clock: _beforeDeadline),
        creator: declined,
        signer: _Signer(refusal: 'privy_signature_rejected'),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_key('launch2-sign-submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('签名'));
      await tester.pumpAndSettle();
      expect(_key('launch2-sign-wallet-refused'), findsOneWidget);
      expect(declined.submittedSignatures, isEmpty);
      await _drain(tester);
    });

    testWidgets('a closed Hooks module is said once, with no signing', (
      tester,
    ) async {
      await _pump(
        tester,
        Launch2SignScreen(projectId: _projectId, clock: _beforeDeadline),
        creator: _FakeCreator(
          requests: <_A<Launch2SigningRequest>>[
            const _A<Launch2SigningRequest>.fail(
              LoopChainFailureKind.unavailable,
              reason: 'HOOKS_LAUNCH_DISABLED',
            ),
          ],
        ),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_key('launch2-sign-load-failed-unavailable'), findsOneWidget);
      expect(find.text('v2 发射暂未开放，开放后这里可以继续。'), findsOneWidget);
      expect(_key('launch2-sign-submit'), findsNothing);
      await _drain(tester);
    });
  });

  group('部署进度', () {
    testWidgets('the job is polled until activated, then opens the project '
        'page', (tester) async {
      final instances = <String>[];
      final creator = _FakeCreator(
        jobs: <_A<Launch2DeploymentJob>>[
          _A<Launch2DeploymentJob>.value(_job('hooks_deployment_created')),
          _A<Launch2DeploymentJob>.value(_job('hooks_deployment_activated')),
        ],
        instances: <_A<Launch2InstanceRef?>>[
          const _A<Launch2InstanceRef?>.value(null),
          const _A<Launch2InstanceRef?>.value(
            Launch2InstanceRef(
              instanceId: _instanceId,
              projectId: _projectId,
              stage: 'upcoming',
            ),
          ),
        ],
      );
      await _pump(
        tester,
        Launch2DeploymentScreen(
          projectId: _projectId,
          jobId: _jobId,
          onOpenInstance: instances.add,
        ),
        creator: creator,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 10));
      expect(
        _key('launch2-deployment-status-awaiting_executor'),
        findsOneWidget,
      );
      expect(_key('launch2-deployment-queued'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 10));
      expect(_key('launch2-deployment-status-activated'), findsOneWidget);
      for (var sequence = 1; sequence <= 7; sequence += 1) {
        expect(_key('launch2-event-$sequence'), findsOneWidget);
      }
      expect(find.text('激活交易已广播'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(_key('launch2-deployment-open-instance'));
      expect(instances.single, _instanceId);
      // A settled job is not read again.
      final reads = creator.jobReads;
      await tester.pump(const Duration(milliseconds: 200));
      expect(creator.jobReads, reads);
      await _drain(tester);
    });

    testWidgets('a final failure names its cause and offers the re-sign', (
      tester,
    ) async {
      final resign = <String>[];
      await _pump(
        tester,
        Launch2DeploymentScreen(
          projectId: _projectId,
          jobId: _jobId,
          onResign: resign.add,
        ),
        creator: _FakeCreator(
          jobs: <_A<Launch2DeploymentJob>>[
            _A<Launch2DeploymentJob>.value(_job('hooks_deployment_failed')),
          ],
        ),
      );
      expect(
        _key('launch2-deployment-failure-HOOKS_SIGNATURE_EXPIRED'),
        findsOneWidget,
      );
      expect(find.text('签名已过期，请重新签名提交。'), findsWidgets);
      await tester.tap(_key('launch2-deployment-resign'));
      expect(resign.single, _projectId);
      await _drain(tester);
    });

    testWidgets('loading, error, offline, unavailable and permission', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2DeploymentScreen(projectId: _projectId, jobId: _jobId),
        creator: _FakeCreator(
          jobs: <_A<Launch2DeploymentJob>>[
            const _A<Launch2DeploymentJob>.pending(),
          ],
        ),
        settle: false,
      );
      expect(_key('launch2-deployment-state-loading'), findsOneWidget);
      await _drain(tester);
      for (final (failure, state) in <(LoopChainFailureKind, String)>[
        (LoopChainFailureKind.invalidData, 'error'),
        (LoopChainFailureKind.offline, 'offline'),
        (LoopChainFailureKind.unavailable, 'unavailable'),
        (LoopChainFailureKind.permissionDenied, 'permission'),
      ]) {
        await _pump(
          tester,
          const Launch2DeploymentScreen(projectId: _projectId, jobId: _jobId),
          creator: _FakeCreator(
            jobs: <_A<Launch2DeploymentJob>>[
              _A<Launch2DeploymentJob>.fail(failure),
            ],
          ),
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 5));
        await tester.pump(const Duration(milliseconds: 5));
        expect(
          _key('launch2-deployment-state-$state'),
          findsOneWidget,
          reason: failure.name,
        );
        await _drain(tester);
      }
    });
  });
}
