// S359 · decision 0284: the NFT price (whole USD1) and the per-address cap
// (per mille of the supply) the owner names when applying; both optional,
// defaults 100 / 5. Every value is 测试专用.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:decimal/decimal.dart';
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
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart'
    show launch2CurveCapFigure;
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart'
    show Launch2InstanceDetail;
import 'package:loop_mobile/features/launch2/launch2_nft_screen.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_codec.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s285_page.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/test_hints.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment('LOOP_SHOTS_DIR');

const String _projectId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const String _walletId = '00000000-0000-4000-8000-000000000099';
const String _owner = '0x7777777777777777777777777777777777777777';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Matcher get _invalid => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

Map<String, Object?> _body(String name) =>
    (jsonDecode(
          File('test/fixtures/s135-launch2-creator/$name.json')
              .readAsStringSync(),
        ) as Map<String, Object?>)['body']!
        as Map<String, Object?>;

/// `hooks_config_draft` with [terms] merged into its `config`.
Map<String, Object?> _draftWith(Map<String, Object?> terms) {
  final body = _body('hooks_config_draft');
  ((body['draft']! as Map)['config']! as Map).addAll(terms);
  return body;
}

Launch2HooksConfig _config(Map<String, Object?> body) =>
    LoopV2Launch2CreatorCodec.configEnvelope(body, projectId: _projectId);

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots || _dir.isEmpty) return;
  await tester.runAsync(loopLoadShotFonts);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

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
const String _nftUrl =
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
      url: _nftUrl,
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
  Size size = const Size(360, 1800),
}) => pumpS7Page(
  tester,
  page,
  size: size,
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

/// 资料 → 链接 → the sale step, a new project.
Future<void> _toSaleStep(WidgetTester tester) async {
  await _tap(tester, 'launch2-create-upload');
  await _tap(tester, 'launch2-create-nft-upload');
  await _fillText(tester);
  await _tap(tester, 'launch2-create-next');
  await _tap(tester, 'launch2-create-next');
  await _tap(tester, 'launch2-create-sale-start');
  await _tap(tester, 'launch2-sale-start-confirm');
}

Future<void> _type(WidgetTester tester, String field, String text) async {
  await tester.ensureVisible(_key('launch2-create-$field'));
  await tester.enterText(_key('launch2-create-$field'), text);
  await tester.pump();
}

String? _errorOf(WidgetTester tester, String field) => tester
    .widget<TextField>(_key('launch2-create-$field'))
    .decoration
    ?.errorText;

String _capFigure(int perMille) =>
    launch2CurveCapFigure(Decimal.fromInt(perMille * 1000000));

void main() {
  loopShowTestHints();
  loopWatchGround();

  setUp(() {
    debugLaunch2CropOverride = (context, bytes) async => bytes;
  });
  tearDown(() => debugLaunch2CropOverride = null);

  group('form rule', () {
    test('blank is allowed; whole numbers in range only', () {
      final l10n = LoopL10n.current;
      String? price(String raw) =>
          launch2FieldError(Launch2Field.nftPrice, raw);
      String? cap(String raw) => launch2FieldError(Launch2Field.walletCap, raw);
      expect(price(''), isNull);
      expect(price('  '), isNull);
      expect(cap(''), isNull);
      expect(price('1'), isNull);
      expect(price('1000'), isNull);
      expect(cap('1'), isNull);
      expect(cap('1000'), isNull);
      expect(price('1.5'), l10n.launch2Creator_termsWholeNumbers);
      expect(price('-3'), l10n.launch2Creator_termsWholeNumbers);
      expect(cap('0.5'), l10n.launch2Creator_termsWholeNumbers);
      expect(price('0'), l10n.launch2Creator_termsRange(1, 1000));
      expect(price('1001'), l10n.launch2Creator_termsRange(1, 1000));
      expect(cap('0'), l10n.launch2Creator_termsRange(1, 1000));
      expect(cap('1001'), l10n.launch2Creator_termsRange(1, 1000));
      expect(l10n.launch2Creator_termsWholeNumbers, 'Whole numbers only');
      expect(
        l10n.launch2Creator_termsRange(1, 1000),
        'Enter a whole number from 1 to 1000',
      );
      expect(launch2TermValue(''), isNull);
      expect(launch2TermValue(' 7 '), 7);
      expect(launch2TermValue('7.0'), isNull);
    });

    test('chain values: 5 per mille = 5e24 raw, 100 USD1 = 1e20 wei', () {
      expect(
        Launch2ProjectTerms.walletCapRaw(5),
        BigInt.parse('5000000000000000000000000'),
      );
      expect(
        Launch2ProjectTerms.walletCapRaw(5),
        Launch2Template.v1.perAddressLifetimeBuyCapRaw,
      );
      expect(
        Launch2ProjectTerms.nftPriceRaw(100),
        BigInt.parse('100000000000000000000'),
      );
      expect(
        Launch2ProjectTerms.nftPriceRaw(100),
        Launch2Template.v1.nftPriceUsd1Raw,
      );
    });
  });

  group('create page', () {
    testWidgets('blank fields send nothing and the template card reads '
        'as today', (tester) async {
      final draft = _config(_body('hooks_config_draft')).draft!;
      final creator = _FakeCreator(saveAnswer: draft);
      await _pump(tester, const Launch2CreateScreen(), creator: creator);
      await _toSaleStep(tester);
      expect(_key('launch2-create-nftPrice'), findsOneWidget);
      expect(_key('launch2-create-walletCap'), findsOneWidget);
      expect(find.text('NFT price (USD1)'), findsOneWidget);
      expect(find.text('Per-address cap (‰ of supply)'), findsOneWidget);
      final price = tester.widget<TextField>(_key('launch2-create-nftPrice'));
      expect(price.decoration?.hintText, '100');
      expect(price.keyboardType, TextInputType.number);
      expect(
        tester
            .widget<TextField>(_key('launch2-create-walletCap'))
            .decoration
            ?.hintText,
        '5',
      );
      final card = find.byKey(const ValueKey<String>('launch2-template-card'));
      expect(
        find.descendant(of: card, matching: find.textContaining(_capFigure(5))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('100 USD1')),
        findsOneWidget,
      );
      await _shot(tester, 's359-form-empty');

      await _tap(tester, 'launch2-create-next');
      final input = creator.saved.single;
      expect(input.nftPriceUsd1, isNull);
      expect(input.walletCapPerMille, isNull);
      final config =
          LoopV2Launch2CreatorCodec.configBody(
                expectedVersion: 0,
                input: input,
              )['config']!
              as Map<String, Object?>;
      expect(config.containsKey('nftPriceUsd1'), isFalse);
      expect(config.containsKey('walletCapPerMille'), isFalse);
      await _drain(tester);
    });

    testWidgets('digits only; out of range blocks 提交审核 with the range '
        'line', (tester) async {
      final creator = _FakeCreator(
        saveAnswer: _config(_body('hooks_config_draft')).draft!,
      );
      await _pump(tester, const Launch2CreateScreen(), creator: creator);
      await _toSaleStep(tester);
      await _type(tester, 'nftPrice', '1.5');
      expect(
        tester
            .widget<TextField>(_key('launch2-create-nftPrice'))
            .controller!
            .text,
        '15',
      );
      await _type(tester, 'nftPrice', '0');
      await _type(tester, 'walletCap', '1001');
      await _tap(tester, 'launch2-create-next');
      expect(creator.saved, isEmpty);
      expect(
        _errorOf(tester, 'nftPrice'),
        LoopL10n.current.launch2Creator_termsRange(1, 1000),
      );
      expect(
        _errorOf(tester, 'walletCap'),
        LoopL10n.current.launch2Creator_termsRange(1, 1000),
      );
      await _shot(tester, 's359-form-error');
      await _drain(tester);
    });

    testWidgets('typed terms go out as integers and the card follows them', (
      tester,
    ) async {
      final creator = _FakeCreator(
        saveAnswer: _config(_body('hooks_config_draft')).draft!,
      );
      await _pump(tester, const Launch2CreateScreen(), creator: creator);
      await _toSaleStep(tester);
      await _type(tester, 'nftPrice', '250');
      await _type(tester, 'walletCap', '7');
      final card = find.byKey(const ValueKey<String>('launch2-template-card'));
      expect(
        find.descendant(of: card, matching: find.textContaining(_capFigure(7))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('250 USD1')),
        findsOneWidget,
      );
      await _shot(tester, 's359-form-filled');
      await _tap(tester, 'launch2-create-next');
      final input = creator.saved.single;
      expect(input.nftPriceUsd1, 250);
      expect(input.walletCapPerMille, 7);
      final config =
          LoopV2Launch2CreatorCodec.configBody(
                expectedVersion: 0,
                input: input.withBuybackRecipient(input.buybackRecipient),
              )['config']!
              as Map<String, Object?>;
      expect(config['nftPriceUsd1'], 250);
      expect(config['walletCapPerMille'], 7);
      await _drain(tester);
    });

    testWidgets('editing fills the saved terms and sends them again', (
      tester,
    ) async {
      final saved = _config(
        _draftWith(<String, Object?>{
          'nftPriceUsd1': 300,
          'walletCapPerMille': 12,
          'maxCumulativeBuyRaw': '12000000000000000000000000',
        }),
      );
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
      await _tap(tester, 'launch2-create-next');
      expect(
        tester
            .widget<TextField>(_key('launch2-create-nftPrice'))
            .controller!
            .text,
        '300',
      );
      expect(
        tester
            .widget<TextField>(_key('launch2-create-walletCap'))
            .controller!
            .text,
        '12',
      );
      await _tap(tester, 'launch2-create-next');
      expect(creator.saved.single.nftPriceUsd1, 300);
      expect(creator.saved.single.walletCapPerMille, 12);
      await _drain(tester);
    });
  });

  group('hooks-config codec', () {
    test('absent keys read as null and the economics stay the template', () {
      final draft = _config(_body('hooks_config_draft')).draft!;
      expect(draft.nftPriceUsd1, isNull);
      expect(draft.walletCapPerMille, isNull);
      expect(draft.maxCumulativeBuyRaw, isNull);
      expect(identical(draft.projectEconomics, draft.economics), isTrue);
    });

    test('present keys land on the draft and its economics', () {
      final draft = _config(
        _draftWith(<String, Object?>{
          'nftPriceUsd1': 250,
          'walletCapPerMille': 7,
          'maxCumulativeBuyRaw': '7000000000000000000000000',
        }),
      ).draft!;
      expect(draft.nftPriceUsd1, 250);
      expect(draft.walletCapPerMille, 7);
      final economics = draft.projectEconomics;
      expect(economics.curveCapRaw, Launch2ProjectTerms.walletCapRaw(7));
      expect(economics.perAddressCapBps, 70);
      expect(economics.nftPriceUsd1Raw, Launch2ProjectTerms.nftPriceRaw(250));
      expect(economics.buybackOrderUsd1Raw, economics.nftPriceUsd1Raw);
    });

    test('per mille alone derives the raw cap; null reads as absent', () {
      final draft = _config(
        _draftWith(<String, Object?>{
          'walletCapPerMille': 9,
          'nftPriceUsd1': null,
          'maxCumulativeBuyRaw': null,
        }),
      ).draft!;
      expect(draft.nftPriceUsd1, isNull);
      expect(
        draft.projectEconomics.curveCapRaw,
        Launch2ProjectTerms.walletCapRaw(9),
      );
    });

    test('out of range, fractional or mistyped values are refused', () {
      for (final terms in <Map<String, Object?>>[
        <String, Object?>{'nftPriceUsd1': 0},
        <String, Object?>{'nftPriceUsd1': 1001},
        <String, Object?>{'nftPriceUsd1': 1.5},
        <String, Object?>{'nftPriceUsd1': '100'},
        <String, Object?>{'walletCapPerMille': 0},
        <String, Object?>{'walletCapPerMille': 1001},
        <String, Object?>{'maxCumulativeBuyRaw': '0'},
        <String, Object?>{'maxCumulativeBuyRaw': 5},
        <String, Object?>{'maxCumulativeBuyRaw': '1.5'},
      ]) {
        expect(() => _config(_draftWith(terms)), _invalid, reason: '$terms');
      }
      // Any other new key in `config` is still refused.
      expect(
        () => _config(_draftWith(<String, Object?>{'somethingNew': 1})),
        _invalid,
      );
    });
  });

  group('signing-request codec (contracts 0019)', () {
    Map<String, Object?> body() => _body('hooks_signing_request');
    Map<String, Object?> typed(Map<String, Object?> b) =>
        b['typedData']! as Map<String, Object?>;
    List<Object?> fields(Map<String, Object?> b) =>
        (typed(b)['types']! as Map<String, Object?>)['LaunchRequest']!
            as List<Object?>;

    test('the type list spells the Factory type string, in order', () {
      final spelled = LoopV2Launch2CreatorCodec.launchRequestType
          .map((field) => '${field.$2} ${field.$1}')
          .join(',');
      expect(
        'LaunchRequest($spelled)',
        'LaunchRequest(bytes32 configHash,address projectOwner,'
            'uint32 configVersion,string name,string ticker,'
            'uint64 nftSaleStart,address buybackRecipient,uint64 deadline,'
            'bytes32 memeSalt,uint256 nonce,bytes32 templateHash,'
            'uint256 nftPrice,uint256 maxCumulativeBuy)',
      );
      expect(LoopV2Launch2CreatorCodec.eip712DomainName, 'LOOP Launch Factory');
      expect(LoopV2Launch2CreatorCodec.eip712DomainVersion, '2');
    });

    test('a version 2 request reads both terms', () {
      final request = LoopV2Launch2CreatorCodec.signingRequest(body());
      expect(request.nftPriceRaw, Launch2ProjectTerms.nftPriceRaw(100));
      expect(request.maxCumulativeBuyRaw, Launch2ProjectTerms.walletCapRaw(5));
      expect(request.request['nftPrice'], '100000000000000000000');
    });

    test('version 1, a missing term, reordered or retyped fields, or a '
        'mismatch are refused', () {
      final cases = <String, Map<String, Object?>>{};
      final v1 = body();
      ((typed(v1)['domain']!) as Map<String, Object?>)['version'] = '1';
      cases['domain version 1'] = v1;

      final eleven = body();
      (eleven['request']! as Map<String, Object?>)
        ..remove('nftPrice')
        ..remove('maxCumulativeBuy');
      fields(eleven).removeRange(11, 13);
      (typed(eleven)['message']! as Map<String, Object?>)
        ..remove('nftPrice')
        ..remove('maxCumulativeBuy');
      cases['old eleven-field request'] = eleven;

      final oneTerm = body();
      (oneTerm['request']! as Map<String, Object?>).remove('maxCumulativeBuy');
      cases['one term missing'] = oneTerm;

      final reordered = body();
      final list = fields(reordered);
      final last = list.removeLast();
      list.insert(11, last);
      cases['terms swapped'] = reordered;

      final retyped = body();
      (fields(retyped)[11]! as Map<String, Object?>)['type'] = 'uint128';
      cases['nftPrice retyped'] = retyped;

      final mismatch = body();
      (typed(mismatch)['message']! as Map<String, Object?>)['nftPrice'] = '1';
      cases['message differs'] = mismatch;

      final zero = body();
      (zero['request']! as Map<String, Object?>)['nftPrice'] = '0';
      (typed(zero)['message']! as Map<String, Object?>)['nftPrice'] = '0';
      cases['zero price'] = zero;

      for (final entry in cases.entries) {
        expect(
          () => LoopV2Launch2CreatorCodec.signingRequest(entry.value),
          _invalid,
          reason: entry.key,
        );
      }
    });
  });

  group('instance codec', () {
    Map<String, Object?> instanceOf(Map<String, Object?> json) =>
        json['instance']! as Map<String, Object?>;

    test('absent keys keep the template as today', () {
      final t = l2Detail().template;
      expect(t.perAddressCap, Decimal.fromInt(5000000));
      expect(t.perAddressCapBps, 50);
      expect(t.nftPriceUsd1, Decimal.fromInt(100));
      expect(t.walletCapPerMille, isNull);
    });

    test('instance terms override the template figures', () {
      final json = l2DetailJson();
      instanceOf(json).addAll(<String, Object?>{
        'nftPriceUsd1': 250,
        'walletCapPerMille': 7,
        'maxCumulativeBuyRaw': '7000000000000000000000000',
      });
      final t = LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null).template;
      expect(t.perAddressCap, Decimal.fromInt(7000000));
      expect(t.perAddressCapBps, 70);
      expect(t.nftPriceUsd1, Decimal.fromInt(250));
      expect(t.buybackOrderUsd1, Decimal.fromInt(250));
      expect(t.walletCapPerMille, 7);
    });

    test('template keys: an integer price and the cap read the same', () {
      final json = l2DetailJson();
      (instanceOf(json)['template']! as Map<String, Object?>).addAll(
        <String, Object?>{
          'nftPriceUsd1': 300,
          'walletCapPerMille': 12,
          'maxCumulativeBuyRaw': '12000000000000000000000000',
        },
      );
      final t = LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null).template;
      expect(t.nftPriceUsd1, Decimal.fromInt(300));
      expect(t.perAddressCap, Decimal.fromInt(12000000));
      expect(t.perAddressCapBps, 120);
    });

    test('invalid terms on the instance are refused', () {
      for (final terms in <Map<String, Object?>>[
        <String, Object?>{'walletCapPerMille': 0},
        <String, Object?>{'nftPriceUsd1': 1.5},
        <String, Object?>{'nftPriceUsd1': 1001},
        <String, Object?>{'maxCumulativeBuyRaw': '0'},
      ]) {
        final json = l2DetailJson();
        instanceOf(json).addAll(terms);
        expect(
          () => LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null),
          _invalid,
          reason: '$terms',
        );
      }
    });
  });

  group('display', () {
    testWidgets('the template card shows the project terms', (tester) async {
      final draft = _config(
        _draftWith(<String, Object?>{
          'nftPriceUsd1': 250,
          'walletCapPerMille': 7,
        }),
      ).draft!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Launch2TemplateCard(
              economics: draft.projectEconomics,
              fromServer: true,
            ),
          ),
        ),
      );
      expect(find.text('250 USD1'), findsOneWidget);
      expect(find.textContaining(_capFigure(7)), findsOneWidget);
      expect(find.textContaining('0.7%'), findsOneWidget);
    });

    Future<void> pumpNft(WidgetTester tester, Launch2InstanceDetail detail) =>
        pumpS7Page(
          tester,
          const Launch2NftScreen(instanceId: l2InstanceA),
          meta: s285Meta(),
          size: const Size(360, 1400),
          overrides: <Override>[
            launch2GatewayProvider.overrideWithValue(
              S285Launch2(detail: detail),
            ),
            launch2ClockProvider.overrideWithValue(() => l2Now),
            launch2PollingProvider.overrideWithValue(
              const Launch2Polling(
                detailInterval: Duration(hours: 1),
                tradingInterval: Duration(hours: 1),
              ),
            ),
            loopFeatureSwitchesProvider.overrideWithValue(
              const LoopFeatureSwitchValues(launch2Visible: true),
            ),
          ],
        );

    Future<void> drainNft(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 30));
    }

    testWidgets('NFT page with default terms reads as today', (tester) async {
      await pumpNft(tester, l2Detail());
      expect(find.textContaining('100 USD1'), findsWidgets);
      expect(find.textContaining('250 USD1'), findsNothing);
      await _shot(tester, 's359-nft-page');
      await drainNft(tester);
    });

    testWidgets('NFT page reads the instance price', (tester) async {
      final json = l2DetailJson();
      final instance = json['instance']! as Map<String, Object?>;
      (instance['nftSale']! as Map<String, Object?>)['priceUsd1'] = '250';
      instance['nftPriceUsd1'] = 250;
      await pumpNft(
        tester,
        LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null),
      );
      expect(find.textContaining('100 USD1'), findsNothing);
      expect(find.textContaining('250 USD1'), findsWidgets);
      await _shot(tester, 's359-nft-page-250');
      await drainNft(tester);
    });
  });
}
