import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_card_view.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_entry.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_projects_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';
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
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_codec.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/test_hints.dart';

// ---------------------------------------------------------------------------
// S326 · decision 0256: the UX batch — the MEME home's trade band and tabs
// (UX-004), no 「发射」 inside the launch flow and no duplicate pushes
// (UX-005), the create page's upload placeholders (UX-006), the chat Token
// Card (UX-014). The create-page harness is S275's.
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
  _FakeCreator({required this.saveAnswer});

  final Launch2HooksConfig? config = null;
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

Future<void> _pumpPlain(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Launch2Activity _trade(int i) => Launch2Activity(
  kind: Launch2ActivityKind.curveBuy,
  instanceId: 'i$i',
  ticker: 'TC',
  name: '天才',
  at: DateTime.utc(2026, 10, 31, 12, i),
  actor: '0x${'$i'.padLeft(40, '0')}',
  amountUsd1: Decimal.fromInt(237),
  transactionHash: '0x$i',
);

LoopTokenCardModel _cardModel() => const LoopTokenCardModel(
  symbol: 'DOGE',
  identifier: '0xba2a…4c43',
  price: r'$0.08',
  change: '+3.21%',
  move: LoopPriceMove.up,
  metrics: <LoopTokenMetric>[
    LoopTokenMetric('市值', r'$204.3M'),
    LoopTokenMetric('流动性', r'$908K'),
    LoopTokenMetric('持有人', '1.1M'),
  ],
  riskFacts: <LoopTokenRiskFact>[
    LoopTokenRiskFact(fact: '是代理合约', source: 'GoPlus', observedLabel: '1 分钟前'),
  ],
  footnotes: <String>['买入与卖出现在不可用 · 兑换还没有开放'],
  chartRangeLabel: '1H · 最近 24 根收盘价',
  chart: Center(child: Text('数据服务限流中')),
);

void main() {
  loopShowTestHints();
  loopWatchGround();

  setUp(() {
    debugLaunch2CropOverride = (context, bytes) async => bytes;
  });
  tearDown(() => debugLaunch2CropOverride = null);

  group('UX-005 · no 「发射」 inside the launch flow', () {
    testWidgets('the create page and 我的项目 carry no launch entry', (
      tester,
    ) async {
      final creator = _FakeCreator(saveAnswer: _config(_bodyWithNft()).draft!);
      await _pump(
        tester,
        Launch2CreateScreen(onOpenMyProjects: () {}),
        creator: creator,
      );
      expect(find.byType(Launch2LaunchCapsule), findsNothing);
      expect(find.byType(Launch2CreatorActions), findsNothing);
      await _drain(tester);

      await _pump(
        tester,
        Launch2ProjectsScreen(onNavigate: (_) {}),
        creator: creator,
      );
      await tester.pumpAndSettle();
      expect(find.byType(Launch2LaunchCapsule), findsNothing);
      expect(_key('launch2-projects-create'), findsNothing);
      expect(_key('launch2-projects-empty-create'), findsNothing);
      expect(find.text('发起 v2 发射'), findsNothing);
      await _drain(tester);
    });

    testWidgets('launch2PushOnce pops back to a page already on the stack '
        'and never pushes the top page again', (tester) async {
      late BuildContext top;
      Widget page(String name) => Builder(
        builder: (context) {
          top = context;
          return Scaffold(body: Text('page $name'));
        },
      );
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (context, state) => page('home')),
          GoRoute(
            path: Launch2CreatorRoute.createPath,
            builder: (context, state) => page('create'),
          ),
          GoRoute(
            path: Launch2CreatorRoute.minePath,
            builder: (context, state) => page('mine'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      int pushed() => router.routerDelegate.currentConfiguration.matches
          .whereType<ImperativeRouteMatch>()
          .length;

      launch2PushOnce(top, Launch2CreatorRoute.createPath);
      await tester.pumpAndSettle();
      launch2PushOnce(top, Launch2CreatorRoute.minePath);
      await tester.pumpAndSettle();
      expect(find.text('page mine'), findsOneWidget);
      expect(pushed(), 2);

      // The same page again: nothing.
      launch2PushOnce(top, Launch2CreatorRoute.minePath);
      await tester.pumpAndSettle();
      expect(pushed(), 2);

      // A page lower in the stack: back to it, not a third page.
      launch2PushOnce(top, Launch2CreatorRoute.createPath);
      await tester.pumpAndSettle();
      expect(find.text('page create'), findsOneWidget);
      expect(pushed(), 1);
      expect(
        launch2SameLocation(Uri.parse('/a?x=1&y=2'), Uri.parse('/a?y=2&x=1')),
        isTrue,
      );
      expect(
        launch2SameLocation(Uri.parse('/a?x=1'), Uri.parse('/a?x=2')),
        isFalse,
      );
    });
  });

  group('UX-006 · step 1 placeholders are the upload controls', () {
    testWidgets('no separate upload buttons; tapping a placeholder uploads; '
        'the steps are a segment bar; fields are titled above with the count '
        'beside the title', (tester) async {
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
      expect(find.text('图片资料'), findsOneWidget);
      expect(find.text('基础信息'), findsOneWidget);
      expect(find.text('上传头像'), findsNothing);
      expect(find.text('上传 NFT 图'), findsNothing);
      expect(
        find.descendant(
          of: _key('launch2-create-screen'),
          matching: find.byType(LoopButton),
        ),
        findsOneWidget, // 下一步 only
      );
      expect(find.byType(Launch2UploadSlot), findsNWidgets(2));
      expect(find.text('上传'), findsNWidgets(2));
      expect(find.text('方形图片，上传前可裁剪'), findsOneWidget);
      expect(find.text(launch2NftImageHelp), findsOneWidget);

      // The bar sits above the title bar; no step dots under it.
      final bar = tester.widget<Launch2CreateStepBar>(
        _key('launch2-create-step-1'),
      );
      expect(bar.current, 0);
      expect(bar.labels, launch2CreateSteps);
      expect(
        tester.getTopLeft(_key('launch2-create-step-1')).dy,
        lessThan(tester.getTopLeft(find.text('发起 v2 发射')).dy),
      );
      final first = tester.getRect(_key('launch2-create-step-segment-0'));
      final last = tester.getRect(_key('launch2-create-step-segment-2'));
      expect(first.width, moreOrLessEquals(last.width));

      // The title is above the box, the count on the title's line.
      expect(find.text('名称'), findsOneWidget);
      expect(
        tester.getTopLeft(_key('launch2-create-name-label')).dy,
        lessThan(tester.getTopLeft(_key('launch2-create-name')).dy),
      );
      expect(
        tester.getCenter(_key('launch2-create-name-counter')).dy,
        moreOrLessEquals(
          tester.getCenter(_key('launch2-create-name-label')).dy,
          epsilon: 2,
        ),
      );
      expect(find.text('0/20'), findsNWidgets(2));

      await _tap(tester, 'launch2-create-upload');
      expect(meme.uploads, 1);
      await _tap(tester, 'launch2-create-nft-upload');
      expect(nft.uploads, 1);
      expect(find.text('换一张'), findsNWidgets(2));
      await _drain(tester);
    });
  });

  group('UX-004 · the MEME home', () {
    testWidgets('the trade band: no index, no loud ground, 「实时」 and 「买入」 '
        'apart, the amount close to its unit, 「全部」 a chevron', (tester) async {
      await _pumpPlain(
        tester,
        Launch2TradeTicker(
          items: <Launch2Activity>[for (var i = 1; i <= 3; i++) _trade(i)],
          onOpenAll: () {},
        ),
      );
      for (final index in <String>['01', '02', '03']) {
        expect(find.text(index), findsNothing);
      }
      final band = tester.widget<DecoratedBox>(_key('launch2-ticker-band'));
      expect(
        (band.decoration as BoxDecoration).color,
        isNot(LoopColors.purple),
      );
      final live = tester.widget<Text>(find.text('实时')).style!.color;
      final buy = tester.widget<Text>(find.text('买入').first).style!.color;
      expect(live, isNot(buy));
      expect(find.text('全部'), findsNothing);
      expect(_key('launch2-ticker-all'), findsOneWidget);
      final amount = find.descendant(
        of: _key('launch2-ticker-amount').first,
        matching: find.byType(Text),
      );
      final gap =
          tester.getTopLeft(amount.at(1)).dx -
          tester.getTopRight(amount.at(0)).dx;
      expect(gap, lessThanOrEqualTo(2.5));
    });

    testWidgets('the tabs carry no index and a smaller count', (tester) async {
      await _pumpPlain(
        tester,
        Launch2DeskTabs(
          tabs: const <Launch2DeskTabSpec>[
            (id: 'live', title: '内盘', count: 4, selected: true),
            (id: 'upcoming', title: '预告', count: 0, selected: false),
            (id: 'graduated', title: '已毕业', count: 3, selected: false),
          ],
          onSelected: (_) {},
        ),
      );
      expect(find.text('01'), findsNothing);
      expect(find.text('02'), findsNothing);
      expect(find.text('03'), findsNothing);
      final title = tester.widget<Text>(find.text('内盘')).style!.fontSize!;
      final count = tester
          .widget<Text>(_key('launch2-desk-tab-count-live'))
          .style!
          .fontSize!;
      expect(count, lessThan(title));
      expect(count, greaterThanOrEqualTo(12));
    });

    testWidgets('the tab bar floats: a blur under it and a light edge all '
        'round', (tester) async {
      await _pumpPlain(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: LoopTabBar(selectedIndex: 2, onSelect: (_) {}),
        ),
      );
      expect(_key('loop-tab-bar-blur'), findsOneWidget);
      final edge = tester.widget<DecoratedBox>(_key('loop-tab-bar-edge'));
      expect((edge.decoration as BoxDecoration).border, isNotNull);
      expect(loopTabBarGround.a, lessThan(0.92));
    });
  });

  group('UX-014 · the chat Token Card', () {
    testWidgets('four LoopButtons; 买入 and 卖出 disabled; 图表 and 社区 open', (
      tester,
    ) async {
      final opened = <String>[];
      await _pumpPlain(
        tester,
        SingleChildScrollView(
          child: ChatTokenCardView(
            state: LoopTokenCardState.normal,
            kicker: '自动识别到代币',
            model: _cardModel(),
            actions: <LoopTokenCardAction>[
              const LoopTokenCardAction('买入', buy: true),
              const LoopTokenCardAction('卖出'),
              LoopTokenCardAction('图表', onTap: () => opened.add('chart')),
              LoopTokenCardAction('社区', onTap: () => opened.add('community')),
            ],
          ),
        ),
      );
      expect(find.text('自动识别到代币'), findsOneWidget);
      final buttons = find.descendant(
        of: _key('chat-token-card-actions'),
        matching: find.byType(LoopButton),
      );
      expect(buttons, findsNWidgets(4));
      final byLabel = <String, LoopButton>{
        for (final button in tester.widgetList<LoopButton>(buttons))
          button.label: button,
      };
      expect(byLabel.keys, <String>['买入', '卖出', '图表', '社区']);
      expect(byLabel['买入']!.onPressed, isNull);
      expect(byLabel['卖出']!.onPressed, isNull);
      expect(byLabel['图表']!.onPressed, isNotNull);
      expect(byLabel['社区']!.onPressed, isNotNull);
      await tester.tap(find.text('图表'));
      await tester.tap(find.text('社区'));
      expect(opened, <String>['chart', 'community']);
      // The chart is its own block with its title; the facts are a list
      // with the source on the same line; the figures are larger.
      expect(
        find.descendant(
          of: _key('chat-token-card-chart-block'),
          matching: find.text('1H · 最近 24 根收盘价'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('是代理合约 —— 来源 GoPlus，观察于 1 分钟前'),
        findsOneWidget,
      );
      final figure = tester.widget<Text>(find.text(r'$204.3M'));
      expect(figure.style!.fontSize, greaterThan(13));
      expect(find.text('买入与卖出现在不可用 · 兑换还没有开放'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
