// S184 · 发射台账本分页接入运营活动卡 (client decision 0165, loop-api S183
// `GET /v2/launch2/campaigns`).
//
// The read is decoded forgivingly (an item it cannot read is dropped, a
// failure is no campaign), the desk orders its pages live events → pinned
// campaigns → previews → other live campaigns → upcoming campaigns within
// seven days (five at most), and the campaign page is the quiet ledger with
// its cover on the right.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_campaigns.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_campaigns_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _iso(DateTime value) => value.toUtc().toIso8601String();

String _id(int n) => '8b9f3c1e-2d4a-4f6b-9c8d-${n.toString().padLeft(12, '0')}';

const String _mediaId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const String _mediaUrl = 'https://api.example.test/v2/media/$_mediaId.webp';

String? _resolve(String mediaId) => mediaId == _mediaId ? _mediaUrl : null;

/// 「10-15」 on the test machine's own calendar, as the card prints it.
String _md(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)}';
}

Map<String, Object?> _campaignJson(
  String id, {
  Object? title = '发射季交易赛',
  Object? subtitle = '内盘买入计入排名，前 50 名分 5,000 USD1。',
  Object? coverUrl,
  Duration startIn = const Duration(days: -1),
  Duration length = const Duration(days: 7),
  Object? ctaLabel = '看榜单',
  Object? link = const <String, Object?>{'kind': 'route', 'value': '/launch2'},
  Object? pinned = false,
  Object? sortOrder = 0,
  Object? state,
}) {
  final start = l2Now.add(startIn);
  return <String, Object?>{
    'campaignId': id,
    'title': title,
    'subtitle': subtitle,
    'coverUrl': coverUrl,
    'startsAt': _iso(start),
    'endsAt': _iso(start.add(length)),
    'ctaLabel': ctaLabel,
    'link': link,
    'pinned': pinned,
    'sortOrder': sortOrder,
    'state': state ?? (startIn.isNegative ? 'live' : 'upcoming'),
  };
}

Map<String, Object?> _body(List<Object?> items) => <String, Object?>{
  'items': items,
  'observedAt': _iso(l2Now),
  'contractVersion': '2.0',
};

Launch2Campaigns _decode(Object? raw) =>
    LoopV2Launch2CampaignsCodec.campaigns(raw, mediaUrl: _resolve);

Launch2DeskCampaign _campaign(
  String id, {
  Duration startIn = const Duration(days: -1),
  Duration length = const Duration(days: 7),
  bool pinned = false,
  String? subtitle = '一句副标题',
  String? coverUrl,
  Launch2CampaignLink link = const Launch2CampaignLink.route('/launch2'),
  String title = '发射季交易赛',
}) {
  final start = l2Now.add(startIn);
  return Launch2DeskCampaign(
    campaignId: id,
    title: title,
    subtitle: subtitle,
    coverUrl: coverUrl,
    startsAt: start,
    endsAt: start.add(length),
    link: link,
    pinned: pinned,
    state: startIn.isNegative
        ? Launch2CampaignState.live
        : Launch2CampaignState.upcoming,
  );
}

List<Launch2InstanceRow> _rows(List<Map<String, Object?>> rows) =>
    l2Page(rows).items;

Map<String, Object?> _rowJson(int n, String stage, {Duration? startIn}) {
  final row = l2RowJson(
    instanceId: _id(n),
    stage: stage,
    noNextChange: stage == 'public' || stage == 'graduated',
    soldBps: stage == 'public' ? 8000 : 0,
  );
  if (startIn != null) {
    final start = l2Now.add(startIn);
    row['nftSale'] = <String, Object?>{
      ...(row['nftSale']! as Map<String, Object?>),
      'startAt': _iso(start),
      'endAt': _iso(start.add(const Duration(days: 7))),
    };
    if (stage == 'upcoming') row['nextChangeAt'] = _iso(start);
  }
  return row;
}

/// A test cover that is ready on the first frame.
final class _ReadyImage extends ImageProvider<_ReadyImage> {
  const _ReadyImage(this.image);

  final ui.Image image;

  @override
  Future<_ReadyImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ReadyImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _ReadyImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
  );
}

/// A test cover whose read fails.
final class _BrokenImage extends ImageProvider<_BrokenImage> {
  const _BrokenImage();

  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_BrokenImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _BrokenImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('cover unreadable')),
  );
}

/// The pager alone, on the dark theme, at [width].
Future<void> _pumpPager(
  WidgetTester tester,
  List<Launch2DeskPage> pages, {
  List<String>? opened,
  List<Uri>? external,
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        launch2ClockProvider.overrideWithValue(() => l2Now),
        launch2ExternalLinkOpenerProvider.overrideWithValue(
          (context, uri) async => external?.add(uri),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Scaffold(
            body: Launch2DeskPager(
              pages: pages,
              chainId: 'eip155:97',
              onNavigate: (location) => opened?.add(location),
            ),
          ),
        ),
      ),
    ),
  );
}

LoopFolioPrimary _folio(WidgetTester tester, String campaignId) =>
    tester.widget<LoopFolioPrimary>(
      find.descendant(
        of: _key('launch2-desk-page-campaign-$campaignId'),
        matching: find.byType(LoopFolioPrimary),
      ),
    );

// ---- the list page --------------------------------------------------------

final class _ListGateway implements Launch2Gateway {
  _ListGateway(this.page);

  final Launch2InstancePage page;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) => Future<Launch2InstancePage>.value(page);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

final class _Campaigns implements Launch2CampaignsGateway {
  _Campaigns(this.answer);

  /// The body to decode, or `null` for a 503.
  final Map<String, Object?>? answer;
  int reads = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Campaigns> loadCampaigns() {
    reads += 1;
    final body = answer;
    if (body == null) {
      return Future<Launch2Campaigns>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
    }
    return Future<Launch2Campaigns>.value(_decode(body));
  }
}

LoopV2MetaSnapshot _meta() {
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
            const LoopV2Capability(
              id: LoopV2CapabilityId.launch2,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: LoopV2CapabilityEvidence(
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

Future<void> _pumpList(
  WidgetTester tester,
  List<Map<String, Object?>> rows, {
  _Campaigns? campaigns,
  List<String>? opened,
}) => pumpS7Page(
  tester,
  Scaffold(
    body: Launch2ListSegment(
      scope: Launch2ListScope.all,
      onNavigate: (location) => opened?.add(location),
    ),
  ),
  meta: _meta(),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(_ListGateway(l2Page(rows))),
    launch2ClockProvider.overrideWithValue(() => l2Now),
    launch2PollingProvider.overrideWithValue(
      const Launch2Polling(
        detailInterval: Duration(hours: 1),
        tradingInterval: Duration(hours: 1),
        listInterval: Duration(hours: 1),
      ),
    ),
    loopFeatureSwitchesProvider.overrideWithValue(
      const LoopFeatureSwitchValues(launch2Visible: true),
    ),
    if (campaigns != null)
      launch2CampaignsGatewayProvider.overrideWithValue(campaigns),
  ],
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

void main() {
  loopWatchGround();

  tearDown(() => debugLoopRemoteAvatarImageProvider = null);

  group('decode', () {
    test('every field', () {
      final read = _decode(
        _body(<Object?>[
          _campaignJson(
            'c1',
            coverUrl: _mediaUrl,
            pinned: true,
            sortOrder: 3,
            link: const <String, Object?>{
              'kind': 'url',
              'value': 'https://loop.example/rules',
            },
          ),
        ]),
      );
      expect(read.observedAt, l2Now);
      final campaign = read.items.single;
      expect(campaign.campaignId, 'c1');
      expect(campaign.title, '发射季交易赛');
      expect(campaign.subtitle, '内盘买入计入排名，前 50 名分 5,000 USD1。');
      expect(campaign.coverUrl, _mediaUrl);
      expect(campaign.startsAt, l2Now.subtract(const Duration(days: 1)));
      expect(campaign.endsAt, l2Now.add(const Duration(days: 6)));
      expect(campaign.ctaLabel, '看榜单');
      expect(campaign.link.kind, Launch2CampaignLinkKind.url);
      expect(campaign.link.value, 'https://loop.example/rules');
      expect(campaign.pinned, isTrue);
      expect(campaign.sortOrder, 3);
      expect(campaign.state, Launch2CampaignState.live);
    });

    test('the nullable fields: no subtitle, no cover, blank button words '
        'read as 「查看」; a cover the client does not accept is no cover', () {
      final read = _decode(
        _body(<Object?>[
          _campaignJson('c1', subtitle: null, coverUrl: null, ctaLabel: ''),
          _campaignJson(
            'c2',
            subtitle: '   ',
            coverUrl: 'https://evil.example/cover.png',
            ctaLabel: null,
            startIn: const Duration(days: 2),
          ),
        ]),
      );
      expect(read.items.map((c) => c.campaignId), <String>['c1', 'c2']);
      final first = read.items[0];
      expect(first.subtitle, isNull);
      expect(first.coverUrl, isNull);
      expect(first.ctaLabel, launch2CampaignDefaultCta);
      final second = read.items[1];
      expect(second.subtitle, isNull);
      expect(second.coverUrl, isNull);
      expect(second.ctaLabel, '查看');
      expect(second.state, Launch2CampaignState.upcoming);
    });

    test('an item it cannot read is dropped, the others kept in order', () {
      final read = _decode(
        _body(<Object?>[
          'not an object',
          _campaignJson('bad-title', title: ''),
          _campaignJson('bad-title-type', title: 7),
          _campaignJson('bad-state', state: 'ended'),
          _campaignJson(
            'bad-kind',
            link: const <String, Object?>{'kind': 'deeplink', 'value': '/x'},
          ),
          _campaignJson('no-link', link: null),
          _campaignJson('bad-pinned', pinned: 'yes'),
          _campaignJson('bad-sort', sortOrder: 1.5),
          _campaignJson('bad-subtitle', subtitle: 3),
          _campaignJson('bad-window', length: Duration.zero),
          <String, Object?>{
            ..._campaignJson('bad-time'),
            'startsAt': 'yesterday',
          },
          _campaignJson('ok-1'),
          _campaignJson('ok-1', title: '重复的 id'),
          _campaignJson('ok-2', startIn: const Duration(days: 3)),
        ]),
      );
      expect(read.items.map((c) => c.campaignId), <String>['ok-1', 'ok-2']);
      expect(read.items.first.title, '发射季交易赛');
    });

    test('at most ten', () {
      final read = _decode(
        _body(<Object?>[for (var i = 0; i < 14; i++) _campaignJson('c$i')]),
      );
      expect(read.items, hasLength(10));
    });

    test('a root it cannot read is a failure — the desk shows no campaign', () {
      for (final raw in <Object?>[
        null,
        'campaigns',
        <Object?>[],
        <String, Object?>{'observedAt': _iso(l2Now)},
        <String, Object?>{'items': 'none'},
      ]) {
        expect(
          () => _decode(raw),
          throwsA(isA<LoopBackendFailure>()),
          reason: '$raw',
        );
      }
      // An unreadable `observedAt` is only no observation time.
      expect(
        _decode(<String, Object?>{'items': <Object?>[], 'observedAt': 3})
            .observedAt,
        isNull,
      );
    });

    test('the port is unavailable until the composition root mounts it', () {
      const gateway = UnavailableLaunch2CampaignsGateway();
      expect(gateway.mode, LoopChainGatewayMode.unavailable);
      expect(gateway.loadCampaigns(), throwsA(isA<LoopChainException>()));
    });
  });

  group('page order', () {
    final hero = launch2HeroRows(
      _rows(<Map<String, Object?>>[
        _rowJson(1, 'upcoming', startIn: const Duration(days: 1)),
        _rowJson(2, 'nft_sale'),
      ]),
    );

    test('live events → pinned campaigns → previews → other live campaigns '
        '→ upcoming campaigns', () {
      final pages = launch2DeskPages(
        hero,
        campaigns: <Launch2DeskCampaign>[
          _campaign('pinned', pinned: true),
          _campaign('soon', startIn: const Duration(days: 2)),
          _campaign('live'),
        ],
        now: l2Now,
      );
      expect(pages.map((page) => page.id), <String>[
        'event-${_id(2)}',
        'campaign-pinned',
        'event-${_id(1)}',
        'campaign-live',
        'campaign-soon',
      ]);
    });

    test('a pinned campaign leads the campaigns even when it is the only '
        'page beside the previews; a pinned upcoming one too', () {
      final previews = launch2HeroRows(
        _rows(<Map<String, Object?>>[
          _rowJson(1, 'upcoming', startIn: const Duration(days: 1)),
        ]),
      );
      final pages = launch2DeskPages(
        previews,
        campaigns: <Launch2DeskCampaign>[
          _campaign('live'),
          _campaign(
            'pinned-soon',
            pinned: true,
            startIn: const Duration(days: 1),
          ),
        ],
        now: l2Now,
      );
      expect(pages.map((page) => page.id), <String>[
        'campaign-pinned-soon',
        'event-${_id(1)}',
        'campaign-live',
      ]);
    });

    test('an upcoming campaign more than 7 days out has no page — pinned or '
        'not; one that is over has none either', () {
      final pages = launch2DeskPages(
        const <Launch2InstanceRow>[],
        campaigns: <Launch2DeskCampaign>[
          _campaign('seven', startIn: const Duration(days: 7)),
          _campaign('eight', startIn: const Duration(days: 7, minutes: 1)),
          _campaign(
            'far-pinned',
            pinned: true,
            startIn: const Duration(days: 9),
          ),
          _campaign(
            'over',
            startIn: const Duration(days: -8),
            length: const Duration(days: 8),
          ),
        ],
        now: l2Now,
      );
      expect(pages.map((page) => page.id), <String>['campaign-seven']);
    });

    test('at most five pages; the rest is cut', () {
      final many = launch2HeroRows(
        _rows(<Map<String, Object?>>[
          _rowJson(1, 'nft_sale'),
          _rowJson(2, 'nft_sale'),
          _rowJson(3, 'upcoming', startIn: const Duration(days: 1)),
        ]),
      );
      final pages = launch2DeskPages(
        many,
        campaigns: <Launch2DeskCampaign>[
          _campaign('a', pinned: true),
          _campaign('b'),
          _campaign('c'),
        ],
        now: l2Now,
      );
      expect(pages, hasLength(launch2DeskPageLimit));
      expect(pages.map((page) => page.id), <String>[
        'event-${_id(1)}',
        'event-${_id(2)}',
        'campaign-a',
        'event-${_id(3)}',
        'campaign-b',
      ]);
    });
  });

  group('the campaign card', () {
    testWidgets('live: the quiet ledger, kicker with the dates, title, '
        'subtitle, button words and 「剩 N 天」', (tester) async {
      final campaign = _campaign(
        'c1',
        length: const Duration(days: 7, hours: 2),
      );
      await _pumpPager(tester, <Launch2DeskPage>[
        Launch2DeskCampaignPage(campaign),
      ]);
      final folio = _folio(tester, 'c1');
      expect(folio.variant, LoopFolioVariant.quiet);
      expect(
        folio.kicker,
        '活动 · ${_md(campaign.startsAt)} → ${_md(campaign.endsAt)}',
      );
      expect(folio.heading, '发射季交易赛');
      expect(folio.headingMaxLines, 2);
      expect(folio.caption, '一句副标题');
      expect(folio.stamp, '剩 6 天');
      expect(folio.aside, isNull);
      expect(find.text('查看'), findsOneWidget);
      // One page: no dots.
      expect(_key('launch2-desk-dots'), findsNothing);
    });

    test('the stamp: under a day 「今天结束」, before the start 「MM-dd 开始」', () {
      final ending = _campaign(
        'c1',
        startIn: const Duration(days: -3),
        length: const Duration(days: 3, hours: 5),
      );
      expect(launch2CampaignStamp(ending, l2Now), '今天结束');
      final soon = _campaign('c2', startIn: const Duration(days: 2));
      expect(launch2CampaignStamp(soon, l2Now), '${_md(soon.startsAt)} 开始');
      final long = _campaign('c3', length: const Duration(days: 2));
      expect(launch2CampaignStamp(long, l2Now), '剩 1 天');
    });

    testWidgets('upcoming and without a subtitle: no caption, stamp says '
        'when it starts', (tester) async {
      final campaign = _campaign(
        'c1',
        subtitle: null,
        startIn: const Duration(days: 3),
      );
      await _pumpPager(tester, <Launch2DeskPage>[
        Launch2DeskCampaignPage(campaign),
      ]);
      final folio = _folio(tester, 'c1');
      expect(folio.caption, isNull);
      expect(folio.stamp, '${_md(campaign.startsAt)} 开始');
      expect(_key('launch2-campaign-cta-c1'), findsOneWidget);
    });

    testWidgets('a cover is drawn on the right edge behind a 1 px rule', (
      tester,
    ) async {
      final image = await tester.runAsync(
        () => createTestImage(width: 40, height: 40),
      );
      debugLoopRemoteAvatarImageProvider = (url) => _ReadyImage(image!);
      await _pumpPager(tester, <Launch2DeskPage>[
        Launch2DeskCampaignPage(_campaign('c1', coverUrl: _mediaUrl)),
      ]);
      await tester.pump();
      expect(_folio(tester, 'c1').aside, isNotNull);
      final strip = tester.getSize(_key('loop-folio-aside'));
      expect(strip.width, LoopFolioPrimary.asideDefaultWidth);
      // Inside the quiet card's 1 px border.
      expect(strip.height, launch2DeskHeight - 2);
      expect(_key('launch2-campaign-cover-c1'), findsOneWidget);
      final card = tester.getRect(_key('launch2-desk-page-campaign-c1'));
      expect(tester.getRect(_key('loop-folio-aside')).right, card.right - 1);
      // The text keeps out of the strip.
      final title = tester.getRect(find.text('发射季交易赛'));
      expect(
        title.right,
        lessThanOrEqualTo(card.right - LoopFolioPrimary.asideDefaultWidth),
      );
    });

    testWidgets('a cover that does not load is no cover: the text takes the '
        'whole card', (tester) async {
      debugLoopRemoteAvatarImageProvider = (url) => const _BrokenImage();
      await _pumpPager(tester, <Launch2DeskPage>[
        Launch2DeskCampaignPage(_campaign('c1', coverUrl: _mediaUrl)),
      ]);
      expect(_folio(tester, 'c1').aside, isNotNull);
      await tester.pump();
      await tester.pump();
      expect(_folio(tester, 'c1').aside, isNull);
      expect(_key('loop-folio-aside'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dots ride the campaign card in Lime from two pages on', (
      tester,
    ) async {
      await _pumpPager(tester, <Launch2DeskPage>[
        Launch2DeskCampaignPage(_campaign('c1')),
        Launch2DeskCampaignPage(_campaign('c2')),
      ]);
      expect(_key('launch2-desk-dots'), findsOneWidget);
      final dot = tester.widget<Container>(_key('launch2-desk-dot-0'));
      expect((dot.decoration! as BoxDecoration).color, LoopColors.lime);
    });
  });

  group('tap', () {
    testWidgets('a route is pushed; the button words open the same', (
      tester,
    ) async {
      final opened = <String>[];
      final external = <Uri>[];
      await _pumpPager(
        tester,
        <Launch2DeskPage>[
          Launch2DeskCampaignPage(
            _campaign(
              'c1',
              link: Launch2CampaignLink.route('/launch2/nft?id=${_id(1)}'),
            ),
          ),
        ],
        opened: opened,
        external: external,
      );
      await tester.tap(_key('launch2-desk-page-campaign-c1'));
      await tester.tap(_key('launch2-campaign-cta-c1'));
      expect(opened, <String>[
        '/launch2/nft?id=${_id(1)}',
        '/launch2/nft?id=${_id(1)}',
      ]);
      expect(external, isEmpty);
    });

    testWidgets('a url is handed to the outside-link opener', (tester) async {
      final opened = <String>[];
      final external = <Uri>[];
      await _pumpPager(
        tester,
        <Launch2DeskPage>[
          Launch2DeskCampaignPage(
            _campaign(
              'c1',
              link: const Launch2CampaignLink.url('https://loop.example/rules'),
            ),
          ),
        ],
        opened: opened,
        external: external,
      );
      await tester.tap(_key('launch2-desk-page-campaign-c1'));
      expect(external, <Uri>[Uri.parse('https://loop.example/rules')]);
      expect(opened, isEmpty);
    });

    test('a route that is not an in-app path, or a url that is not https, '
        'is ignored', () {
      final pushed = <String>[];
      final handed = <Uri>[];
      for (final link in <Launch2CampaignLink>[
        const Launch2CampaignLink.route('launch2'),
        const Launch2CampaignLink.route('//evil.example/x'),
        const Launch2CampaignLink.route('https://evil.example'),
        const Launch2CampaignLink.route('/a b'),
        const Launch2CampaignLink.url('http://loop.example'),
        const Launch2CampaignLink.url('javascript:alert(1)'),
        const Launch2CampaignLink.url('https://user@loop.example'),
        const Launch2CampaignLink.url('/launch2'),
      ]) {
        launch2OpenCampaign(
          _campaign('c1', link: link),
          push: pushed.add,
          openExternal: handed.add,
        );
      }
      expect(pushed, isEmpty);
      expect(handed, isEmpty);
      expect(launch2CampaignRoute('/launch2/nft?id=x'), '/launch2/nft?id=x');
    });

    testWidgets('the default opener copies the link and says so', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              (call.arguments as Map<Object?, Object?>)['text']! as String,
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            launch2ClockProvider.overrideWithValue(() => l2Now),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              body: Launch2DeskPager(
                pages: <Launch2DeskPage>[
                  Launch2DeskCampaignPage(
                    _campaign(
                      'c1',
                      link: const Launch2CampaignLink.url(
                        'https://loop.example/rules',
                      ),
                    ),
                  ),
                ],
                chainId: 'eip155:97',
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(_key('launch2-desk-page-campaign-c1'));
      await tester.pump();
      expect(copied, <String>['https://loop.example/rules']);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('the list page', () {
    testWidgets('a 503 is no campaign: the desk, counts and rows are as '
        'before', (tester) async {
      final campaigns = _Campaigns(null);
      await _pumpList(tester, <Map<String, Object?>>[
        _rowJson(1, 'nft_sale'),
        _rowJson(2, 'graduated'),
      ], campaigns: campaigns);
      expect(campaigns.reads, 1);
      expect(_key('launch2-desk'), findsOneWidget);
      expect(_key('launch2-desk-page-${_id(1)}'), findsOneWidget);
      expect(_key('launch2-desk-segs'), findsOneWidget);
      expect(_key('launch2-desk-record-${_id(1)}'), findsOneWidget);
      expect(find.textContaining('campaign'), findsNothing);
      expect(_key('launch2-desk-dots'), findsNothing);
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });

    testWidgets('campaigns read with the first page join the pager and '
        'are read again with the pull', (tester) async {
      final campaigns = _Campaigns(
        _body(<Object?>[
          _campaignJson('c1', pinned: true),
          _campaignJson('c2', startIn: const Duration(days: 30)),
        ]),
      );
      final opened = <String>[];
      await _pumpList(
        tester,
        <Map<String, Object?>>[_rowJson(1, 'nft_sale')],
        campaigns: campaigns,
        opened: opened,
      );
      expect(campaigns.reads, 1);
      // Two pages: the event, then the pinned campaign (c2 is too far out).
      expect(_key('launch2-desk-dots'), findsOneWidget);
      expect(_key('launch2-desk-dot-1'), findsOneWidget);
      expect(_key('launch2-desk-dot-2'), findsNothing);
      await tester.drag(_key('launch2-desk-pages'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(_key('launch2-desk-page-campaign-c1'), findsOneWidget);
      expect(_key('launch2-desk-page-campaign-c2'), findsNothing);
      await tester.tap(_key('launch2-desk-page-campaign-c1'));
      expect(opened, <String>['/launch2']);
      // The pull re-reads the campaigns with the list.
      unawaited(
        tester.state<RefreshIndicatorState>(_key('loop-page-refresh')).show(),
      );
      await tester.pumpAndSettle();
      expect(campaigns.reads, 2);
      await _drain(tester);
    });

    testWidgets('the production default draws no campaign and asks nothing', (
      tester,
    ) async {
      await _pumpList(tester, <Map<String, Object?>>[_rowJson(1, 'nft_sale')]);
      expect(_key('launch2-desk-page-${_id(1)}'), findsOneWidget);
      expect(_key('launch2-desk-dots'), findsNothing);
      await _drain(tester);
    });
  });

  group('360 dp', () {
    for (final scale in <double>[1, 1.3]) {
      testWidgets('long words, a cover and a stamp fit (text ×$scale)', (
        tester,
      ) async {
        final image = await tester.runAsync(
          () => createTestImage(width: 40, height: 40),
        );
        debugLoopRemoteAvatarImageProvider = (url) => _ReadyImage(image!);
        await _pumpPager(
          tester,
          <Launch2DeskPage>[
            Launch2DeskCampaignPage(
              _campaign(
                'c1',
                title: '发射季交易赛第二季全平台联合冲榜大奖赛',
                subtitle:
                    '内盘买入计入排名，前 50 名分 5,000 USD1。'
                    '点开看规则与榜单，结算以链上记录为准。',
                coverUrl: _mediaUrl,
                startIn: const Duration(days: 3),
              ),
            ),
            Launch2DeskCampaignPage(_campaign('c2', subtitle: null)),
          ],
          width: 360,
          textScale: scale,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.drag(_key('launch2-desk-pages'), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
