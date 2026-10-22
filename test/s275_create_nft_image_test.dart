import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_create_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_gateway.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_project_screen.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_api.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_codec.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/test_hints.dart';

// ---------------------------------------------------------------------------
// S275 · decision 0233: the owner uploads the project NFT's image beside the
// logo; it is required for a new project and saved as `nftImageAssetUrl`
// (loop-api decision 0173).
// ---------------------------------------------------------------------------

const String _projectId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const String _walletId = '00000000-0000-4000-8000-000000000099';
const String _owner = '0x7777777777777777777777777777777777777777';
const String _nftUrl =
    'https://api-dev.example/v2/media/9c1d2e3f-4a5b-4c6d-8e7f-0a1b2c3d4e5f.webp';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Map<String, Object?> _body(String name) =>
    (jsonDecode(
          File('test/fixtures/s135-launch2-creator/$name.json')
              .readAsStringSync(),
        ) as Map<String, Object?>)['body']!
        as Map<String, Object?>;

/// `hooks_config_draft` with the NFT image the server echoes back.
Map<String, Object?> _bodyWithNft([String url = _nftUrl]) {
  final body = _body('hooks_config_draft');
  ((body['draft']! as Map)['config']! as Map)['nftImageAssetUrl'] = url;
  return body;
}

Launch2HooksConfig _config(Map<String, Object?> body) =>
    LoopV2Launch2CreatorCodec.configEnvelope(body, projectId: _projectId);

final class _FakeCreator implements Launch2CreatorGateway {
  _FakeCreator({this.config, required this.saveAnswer});

  final Launch2HooksConfig? config;
  final Launch2HooksDraft saveAnswer;
  final List<Launch2ConfigInput> saved = <Launch2ConfigInput>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2HooksConfig> loadConfig(String projectId) =>
      Future<Launch2HooksConfig>.value(
        config ?? _config(_body('hooks_config_empty')),
      );

  @override
  Future<Launch2HooksDraft> saveConfig({
    required String projectId,
    required int expectedVersion,
    required Launch2ConfigInput input,
  }) {
    saved.add(input);
    return Future<Launch2HooksDraft>.value(saveAnswer);
  }

  @override
  Future<Launch2InstanceRef?> findInstance(String projectId) =>
      Future<Launch2InstanceRef?>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

final class _FakeLaunch implements LaunchGateway {
  _FakeLaunch({LaunchProject? project})
    : project =
          project ??
          s7Project(
            projectId: _projectId,
            reviewStatus: LaunchReviewStatus.approved,
          );

  final LaunchProject project;
  final List<LaunchProjectDraft> created = <LaunchProjectDraft>[];

  @override
  Future<LaunchProject> loadProject(String projectId) =>
      Future<LaunchProject>.value(project);

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
  }) => Future<LaunchProject>.value(
    s7Project(projectId: projectId, version: expectedVersion + 1),
  );

  @override
  Future<LaunchProject> submitProject(String projectId) =>
      Future<LaunchProject>.value(
        s7Project(
          projectId: projectId,
          reviewStatus: LaunchReviewStatus.submitted,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

const String _logoUrl =
    'https://api-dev.example/v2/media/2b1f8c3e-1d2a-4b5c-8d9e-0f1a2b3c4d5e.webp';
const String _gatewayNftUrl =
    'https://ipfs.example/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';

/// The logo stays a community-logo upload.
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
      url: _logoUrl,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// The NFT image goes through its own media kind and answers an IPFS
/// gateway URL.
final class _FakeNftUploader implements Launch2NftImageUploader {
  int uploads = 0;

  @override
  Future<MemeUploadedImage> upload({
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploads += 1;
    return const MemeUploadedImage(
      mediaId: '9c1d2e3f-4a5b-4c6d-8e7f-0a1b2c3d4e5f',
      url: _gatewayNftUrl,
      cid: 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
    );
  }
}

final class _Picker implements AvatarImagePicker {
  @override
  bool get available => true;

  @override
  Future<PickedAvatarImage?> pick() async =>
      PickedAvatarImage(bytes: Uint8List.fromList(<int>[1, 2, 3]));
}

final class _Signer implements Launch2TypedDataSigner {
  @override
  bool get available => true;

  @override
  Future<Launch2TypedDataResult> sign({
    required String ownerAddress,
    required Map<String, Object?> typedData,
    required int chainReference,
  }) async => Launch2TypedDataResult.refused('test');
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required _FakeCreator creator,
  _FakeLaunch? launch,
  _FakeMeme? meme,
  _FakeNftUploader? nft,
}) => pumpS7Page(
  tester,
  page,
  launch: launch ?? _FakeLaunch(),
  meta: s7MetaSnapshot(),
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
    launch2CreatorGatewayProvider.overrideWithValue(creator),
    launch2TypedDataSignerProvider.overrideWithValue(_Signer()),
    launch2CreatorPollingProvider.overrideWithValue(
      const Launch2CreatorPolling(
        deploymentInterval: Duration(milliseconds: 20),
        instanceInterval: Duration(milliseconds: 20),
        instanceMaxAttempts: 3,
        submitRecheckDelay: Duration.zero,
      ),
    ),
    memeGatewayProvider.overrideWithValue(meme ?? _FakeMeme()),
    launch2NftImageUploaderProvider.overrideWithValue(
      nft ?? _FakeNftUploader(),
    ),
    avatarImagePickerProvider.overrideWithValue(_Picker()),
    loopFeatureSwitchesProvider.overrideWithValue(
      const LoopFeatureSwitchValues(launch2Visible: true),
    ),
  ],
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 30));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _fillText(WidgetTester tester) async {
  await tester.enterText(_key('launch2-create-name'), 'MoonCat');
  await tester.enterText(_key('launch2-create-ticker'), 'mcat');
  await tester.pump();
}

String? _frameUrl(WidgetTester tester, String key) =>
    tester.widget<Launch2NftImageFrame>(_key(key)).imageUrl;

void main() {
  loopShowTestHints();
  loopWatchGround();

  setUp(() {
    debugLaunch2CropOverride = (context, bytes) async => bytes;
  });
  tearDown(() => debugLaunch2CropOverride = null);

  group('create page', () {
    testWidgets('a new project cannot leave 资料 without an NFT image; the '
        'slot says what the image is for', (tester) async {
      final creator = _FakeCreator(saveAnswer: _config(_bodyWithNft()).draft!);
      await _pump(tester, const Launch2CreateScreen(), creator: creator);
      expect(_key('launch2-create-nft-preview'), findsOneWidget);
      expect(find.text('NFT 图'), findsOneWidget);
      expect(find.text(launch2NftImageHelp), findsOneWidget);
      expect(_key('launch2-nft-image-empty'), findsOneWidget);

      // Logo, name and ticker are there; the NFT image is not.
      await _tap(tester, 'launch2-create-upload');
      await _fillText(tester);
      await _tap(tester, 'launch2-create-next');
      expect(_key('launch2-create-step-2'), findsNothing);
      expect(_key('launch2-create-nft-missing'), findsOneWidget);
      expect(_key('launch2-create-logo-missing'), findsNothing);
      expect(
        tester
            .widget<Launch2NftImageFrame>(_key('launch2-create-nft-preview'))
            .missing,
        isTrue,
      );

      await _tap(tester, 'launch2-create-nft-upload');
      expect(_key('launch2-create-nft-missing'), findsNothing);
      await _tap(tester, 'launch2-create-next');
      expect(_key('launch2-create-step-2'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('the NFT image is its own upload and shows its url in the '
        'square preview, apart from the logo', (tester) async {
      final meme = _FakeMeme();
      final nft = _FakeNftUploader();
      final creator = _FakeCreator(saveAnswer: _config(_bodyWithNft()).draft!);
      await _pump(
        tester,
        const Launch2CreateScreen(),
        creator: creator,
        meme: meme,
        nft: nft,
      );
      await _tap(tester, 'launch2-create-upload');
      expect(_frameUrl(tester, 'launch2-create-nft-preview'), isNull);
      await _tap(tester, 'launch2-create-nft-upload');
      expect(meme.uploads, 1);
      expect(nft.uploads, 1);
      expect(_frameUrl(tester, 'launch2-create-nft-preview'), _gatewayNftUrl);
      expect(
        find.descendant(
          of: _key('launch2-create-nft-preview'),
          matching: _key('loop-remote-avatar-image'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-create-nft-upload'),
          matching: find.text('换一张'),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('提交审核 saves the NFT image as nftImageAssetUrl beside the '
        'logo', (tester) async {
      final launch = _FakeLaunch();
      final creator = _FakeCreator(saveAnswer: _config(_bodyWithNft()).draft!);
      await _pump(
        tester,
        const Launch2CreateScreen(),
        creator: creator,
        launch: launch,
      );
      await _tap(tester, 'launch2-create-upload');
      await _tap(tester, 'launch2-create-nft-upload');
      await _fillText(tester);
      await _tap(tester, 'launch2-create-next');
      await tester.enterText(_key('launch2-create-x'), 'https://x.com/mooncat');
      await _tap(tester, 'launch2-create-next');
      await _tap(tester, 'launch2-create-sale-start');
      await _tap(tester, 'launch2-sale-start-confirm');
      await _tap(tester, 'launch2-create-next');

      final input = creator.saved.single;
      expect(input.logoAssetUrl, _logoUrl);
      expect(input.nftImageAssetUrl, _gatewayNftUrl);
      final config =
          LoopV2Launch2CreatorCodec.configBody(
                expectedVersion: 0,
                input: input,
              )['config']!
              as Map<String, Object?>;
      expect(config['nftImageAssetUrl'], input.nftImageAssetUrl);
      expect(config['logoAssetUrl'], input.logoAssetUrl);
      await _drain(tester);
    });

    testWidgets('editing restores the saved NFT image and sends it again', (
      tester,
    ) async {
      final saved = _config(_bodyWithNft());
      final creator = _FakeCreator(config: saved, saveAnswer: saved.draft!);
      await _pump(
        tester,
        Launch2CreateScreen(
          projectId: _projectId,
          clock: () => DateTime.utc(2026, 10, 3, 4),
        ),
        creator: creator,
        launch: _FakeLaunch(
          project: s7Project(
            projectId: _projectId,
            reviewStatus: LaunchReviewStatus.returned,
            version: 3,
            reviewReasonCode: 'materials_incomplete',
          ),
        ),
      );
      expect(_frameUrl(tester, 'launch2-create-nft-preview'), _nftUrl);
      await _tap(tester, 'launch2-create-next');
      await _tap(tester, 'launch2-create-next');
      await _tap(tester, 'launch2-create-next');
      expect(creator.saved.single.nftImageAssetUrl, _nftUrl);
      await _drain(tester);
    });

    testWidgets('an older draft with no NFT image can still be edited', (
      tester,
    ) async {
      final saved = _config(_body('hooks_config_draft'));
      expect(saved.draft!.nftImageAssetUrl, isNull);
      final creator = _FakeCreator(config: saved, saveAnswer: saved.draft!);
      await _pump(
        tester,
        Launch2CreateScreen(
          projectId: _projectId,
          clock: () => DateTime.utc(2026, 10, 3, 4),
        ),
        creator: creator,
        launch: _FakeLaunch(
          project: s7Project(
            projectId: _projectId,
            reviewStatus: LaunchReviewStatus.returned,
            version: 3,
            reviewReasonCode: 'materials_incomplete',
          ),
        ),
      );
      await _tap(tester, 'launch2-create-next');
      expect(_key('launch2-create-step-2'), findsOneWidget);
      await _tap(tester, 'launch2-create-next');
      await _tap(tester, 'launch2-create-next');
      expect(creator.saved.single.nftImageAssetUrl, isNull);
      await _drain(tester);
    });
  });

  group('codec', () {
    test('the draft round-trips nftImageAssetUrl', () {
      final draft = _config(_bodyWithNft()).draft!;
      expect(draft.nftImageAssetUrl, _nftUrl);
      final input = Launch2ConfigInput(
        name: draft.name,
        ticker: draft.ticker,
        logoAssetUrl: draft.logoAssetUrl,
        nftImageAssetUrl: draft.nftImageAssetUrl,
        description: draft.description,
        links: draft.links,
        nftSaleStart: draft.nftSaleStart,
        buybackRecipient: draft.buybackRecipient,
      );
      final config =
          LoopV2Launch2CreatorCodec.configBody(
                expectedVersion: draft.version,
                input: input,
              )['config']!
              as Map<String, Object?>;
      expect(config['nftImageAssetUrl'], _nftUrl);
      // The fixed recipient swap keeps it.
      expect(
        input.withBuybackRecipient(draft.buybackRecipient).nftImageAssetUrl,
        _nftUrl,
      );
    });

    test('without an image the PUT body keeps the seven owner fields', () {
      final draft = _config(_body('hooks_config_draft')).draft!;
      final config =
          LoopV2Launch2CreatorCodec.configBody(
                expectedVersion: 1,
                input: Launch2ConfigInput(
                  name: draft.name,
                  ticker: draft.ticker,
                  logoAssetUrl: draft.logoAssetUrl,
                  description: draft.description,
                  links: draft.links,
                  nftSaleStart: draft.nftSaleStart,
                  buybackRecipient: draft.buybackRecipient,
                ),
              )['config']!
              as Map<String, Object?>;
      expect(config.containsKey('nftImageAssetUrl'), isFalse);
      expect(config.length, 7);
    });

    test('the upload kind names the route', () {
      expect(launch2NftImageMediaKind, 'project_nft_image');
      expect(
        DioLoopV2MemeApi.nftImageUploadPath,
        '/v2/media/project-nft-images',
      );
    });

    test('the NFT upload answer is read tolerantly: cid / ipfsUri and '
        'unknown keys are fine', () {
      final image = LoopV2MemeCodec.uploadedNftImage(<String, Object?>{
        'mediaId': '9c1d2e3f-4a5b-4c6d-8e7f-0a1b2c3d4e5f',
        'ref': 'project_nft_image:media/9c1d2e3f-4a5b-4c6d-8e7f-0a1b2c3d4e5f',
        'url': _gatewayNftUrl,
        'cid': 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        'ipfsUri': 'ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        'width': 512,
        'height': 512,
        'contractVersion': '2.0',
        'somethingNew': true,
      }, mediaUrl: (_) => null);
      expect(image.url, _gatewayNftUrl);
      expect(image.cid, startsWith('bafy'));
      expect(image.ipfsUri, startsWith('ipfs://'));

      final bare = LoopV2MemeCodec.uploadedNftImage(<String, Object?>{
        'mediaId': '9c1d2e3f-4a5b-4c6d-8e7f-0a1b2c3d4e5f',
        'url': '/v2/media/9c1d2e3f-4a5b-4c6d-8e7f-0a1b2c3d4e5f.webp',
      }, mediaUrl: (id) => 'https://api-dev.example/v2/media/$id.webp');
      expect(bare.url, startsWith('https://api-dev.example/v2/media/'));
      expect(bare.cid, isNull);

      for (final url in <Object?>[null, 'http://ipfs.example/x', 'ipfs://x']) {
        expect(
          () => LoopV2MemeCodec.uploadedNftImage(<String, Object?>{
            'mediaId': '9c1d2e3f-4a5b-4c6d-8e7f-0a1b2c3d4e5f',
            'url': url,
          }, mediaUrl: (_) => null),
          throwsA(isA<LoopBackendFailure>()),
          reason: '$url',
        );
      }
    });

    test('a non-https NFT image is refused like the logo', () {
      expect(
        () => _config(_bodyWithNft('http://insecure.example/nft.png')),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('project page', () {
    testWidgets('the submitted NFT image shows with its label', (tester) async {
      final saved = _config(_bodyWithNft());
      await _pump(
        tester,
        const Launch2ProjectScreen(projectId: _projectId),
        creator: _FakeCreator(config: saved, saveAnswer: saved.draft!),
        launch: _FakeLaunch(
          project: s7Project(
            projectId: _projectId,
            reviewStatus: LaunchReviewStatus.inReview,
            submittedAt: DateTime.utc(2026, 10, 9, 7),
          ),
        ),
      );
      expect(_key('launch2-project-nft-image'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-project-nft-image'),
          matching: find.text('NFT 图'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Launch2NftImageFrame>(find.byType(Launch2NftImageFrame))
            .imageUrl,
        _nftUrl,
      );
    });

    testWidgets('an older draft without one shows no NFT block', (
      tester,
    ) async {
      final saved = _config(_body('hooks_config_draft'));
      await _pump(
        tester,
        const Launch2ProjectScreen(projectId: _projectId),
        creator: _FakeCreator(config: saved, saveAnswer: saved.draft!),
        launch: _FakeLaunch(
          project: s7Project(
            projectId: _projectId,
            reviewStatus: LaunchReviewStatus.inReview,
            submittedAt: DateTime.utc(2026, 10, 9, 7),
          ),
        ),
      );
      expect(_key('launch2-project-nft-image'), findsNothing);
    });
  });
}
