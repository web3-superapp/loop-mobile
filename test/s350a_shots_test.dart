// S350a · decision 0274: the self-review shots of 聊天 and 广场 (动态 / 社区)
// after the visual polish round (需求方 11-04 截图回看).
//
// Not a check: it writes 390- and 360-wide renders to `LOOP_SHOTS_DIR`. It
// runs only with `--dart-define=LOOP_SHOTS=true`; a plain `flutter test`
// skips every case and writes nothing.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart' show loopStreamChatConfiguration;
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S350a/shots',
);

const Size _phone = Size(390, 844);
const Size _narrow = Size(360, 780);

Future<void> _shot(WidgetTester tester, String name, Size size) =>
    loopShot(tester, name, slice: size.height, dir: _dir);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

Future<void> _settleArt(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// 聊天
// ---------------------------------------------------------------------------

const String _me = 'me';

final class _NoSource implements StreamChatSessionSource {
  @override
  Future<StreamChatIdentity?> loadIdentity() async => null;

  @override
  Future<String> loadToken(String userId) async => throw StateError('none');
}

/// Opens on the scripted rows and never reads again.
final class _ScriptedInbox extends StreamChannelListController {
  _ScriptedInbox({required super.client, required this.rows})
    : super(
        filter: loopStreamInboxFilter(_me),
        channelStateSort: loopStreamInboxSort,
        limit: loopStreamInboxPageSize,
      );

  final List<Channel> rows;

  @override
  Future<void> doInitialLoad() async {
    value = PagedValue<int, Channel>(items: rows);
  }

  @override
  Future<void> loadMore(int nextPageKey) async {}
}

Member _person(String id) => Member(
  userId: id,
  user: User(id: id, name: id),
);

Channel _conversation(
  StreamChatClient client, {
  required String id,
  required int minutesAgo,
  required String text,
  String? name,
  String from = 'loop_peer',
  int unread = 0,
  bool pinned = false,
  int members = 2,
}) {
  final at = DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo));
  final people = <Member>[
    _person(from),
    for (var index = 1; index < members; index += 1) _person('loop_m$index'),
  ];
  return Channel.fromState(
    client,
    ChannelState(
      channel: ChannelModel(
        id: id,
        type: 'messaging',
        memberCount: people.length,
        createdAt: at,
        updatedAt: at,
        lastMessageAt: at,
        extraData: name == null
            ? const <String, Object?>{}
            : <String, Object?>{'name': name},
      ),
      members: people,
      membership: Member(
        userId: _me,
        pinnedAt: pinned ? DateTime.utc(2026, 11) : null,
      ),
      read: <Read>[
        Read(
          user: User(id: _me),
          lastRead: at.subtract(const Duration(minutes: 1)),
          unreadMessages: unread,
        ),
      ],
      messages: <Message>[
        Message(
          id: 'm-$id',
          text: text,
          user: people.first.user,
          createdAt: at,
          state: MessageState.sent,
        ),
      ],
    ),
  );
}

const String _hexA = '0123456789abcdef0123456789abcdef';
const String _hexB = 'fedcba9876543210fedcba9876543210';
const String _hexC = '11111111222233334444555555555555';
const String _hexD = 'aaaaaaaabbbbccccdddd000000000000';
const String _hexE = '99999999888877776666555555555555';

List<Channel> _inboxRows(StreamChatClient client) => <Channel>[
  _conversation(
    client,
    id: 'loop_community_$_hexC',
    name: 'LOOP 官方',
    minutesAgo: 3,
    text: '本周算力快照已更新，奖励明早结算',
    pinned: true,
    unread: 2,
    members: 6,
  ),
  _conversation(
    client,
    id: 'loop_community_$_hexD',
    name: 'Meme 观察室',
    minutesAgo: 40,
    text: '今天这根阳线有点东西',
    pinned: true,
    members: 5,
  ),
  _conversation(
    client,
    id: 'loop_direct_$_hexA',
    minutesAgo: 8,
    text: '晚点一起看看 FROG 的盘',
    unread: 12,
  ),
  _conversation(
    client,
    id: 'loop_group_$_hexB',
    name: '早起打卡小组',
    minutesAgo: 95,
    text: '明天七点见',
    members: 4,
  ),
  _conversation(
    client,
    id: 'loop_community_$_hexE',
    name: 'DeFi 早读会',
    minutesAgo: 60 * 26,
    text: '收益率曲线又平了，大家怎么看',
    members: 8,
  ),
  _conversation(
    client,
    id: 'loop_direct_$_hexB',
    minutesAgo: 60 * 50,
    text: '好的，收到',
  ),
];

bool _iconsLoaded = false;

/// Stream's own icon font (the pin and mute marks), which a test binding
/// does not load from the package's assets.
Future<void> _loadStreamIcons() async {
  if (_iconsLoaded) return;
  _iconsLoaded = true;
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final packages = (config['packages']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final root =
      packages.singleWhere(
            (entry) => entry['name'] == 'stream_core_flutter',
          )['rootUri']!
          as String;
  final font = File.fromUri(Uri.parse('$root/lib/fonts/stream_icons_font.otf'))
      .readAsBytesSync();
  final loader = FontLoader('packages/stream_core_flutter/Stream Icons')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(font)));
  await loader.load();
}

Future<List<Channel>> _pumpChat(
  WidgetTester tester, {
  required Size size,
  required bool empty,
}) async {
  // The Stream client's connectivity monitor listens on a platform channel
  // the test binding has no implementation for.
  const connectivity = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(connectivity, (call) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(connectivity, null));
  await tester.runAsync(_loadStreamIcons);
  final session = StreamChatSdkSession.create(
    apiKey: 'public-stream-api-key',
    source: _NoSource(),
  );
  // No local store in a test: the rows are handed to the list directly.
  session.client.chatPersistenceClient = null;
  // ignore: invalid_use_of_internal_member
  session.client.state.currentUser = OwnUser(id: _me);
  final rows = empty ? const <Channel>[] : _inboxRows(session.client);
  final directory = LoopDirectChannelDirectory(<String, LoopPublicProfile?>{
    'messaging:loop_direct_$_hexA': testProfile(alias: 'pollak'),
    'messaging:loop_direct_$_hexB': testProfile(alias: '小月亮'),
  });
  await pumpCommunityPage(
    tester,
    Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Localizations.override(
          context: context,
          delegates: const <LocalizationsDelegate<Object?>>[
            LoopStreamChatLocalizationsDelegate(),
          ],
          child: Theme(
            data: theme.copyWith(
              extensions: [
                ...theme.extensions.values,
                loopStreamTheme(platform: theme.platform),
              ],
            ),
            child: StreamChat(
              client: session.client,
              themeData: loopStreamChatThemeData(),
              configData: loopStreamChatConfiguration,
              child: const StreamChatInboxPage(),
            ),
          ),
        );
      },
    ),
    size: size,
    settle: false,
    streamAuthorization: () async => StreamSessionAuthorization.authorized,
    overrides: <Override>[
      streamChatSdkSessionProvider.overrideWithValue(session),
      loopStreamChannelListControllerProvider.overrideWith((ref, key) {
        final controller = _ScriptedInbox(client: key.client, rows: rows);
        ref.onDispose(controller.dispose);
        return controller;
      }),
      directChannelDirectoryProvider.overrideWith((ref) async => directory),
    ],
  );
  for (var index = 0; index < 6; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _settleArt(tester);
  return rows;
}

Future<void> _drainChat(WidgetTester tester, List<Channel> rows) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (final row in rows) {
    row.dispose();
  }
  await tester.pump(const Duration(hours: 2));
}

// ---------------------------------------------------------------------------
// 广场 · 动态
// ---------------------------------------------------------------------------

final DateTime _now = DateTime.utc(2026, 11, 4, 12);

String _uuid(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

SquareFeedPost _post(
  int n, {
  SquareFeedPostKind kind = SquareFeedPostKind.opinion,
  String? text,
  SquareFeedToken? token,
  Map<String, String> event = const <String, String>{},
  bool pinned = false,
  int likes = 0,
  bool liked = false,
  String alias = 'pollak',
  int minutes = 3,
}) => SquareFeedPost(
  postId: _uuid(n),
  kind: kind,
  author: kind == SquareFeedPostKind.system
      ? null
      : SquareFeedAuthor(
          publicProfileId: 'pp_author$n',
          loopId: 'LOOP-AUTHOR$n',
          alias: alias,
        ),
  text: text,
  token: token,
  event: event,
  likeCount: likes,
  likedByViewer: liked,
  pinned: pinned,
  createdAt: _now.subtract(Duration(minutes: minutes)),
);

SquareFeedToken _token(String symbol, String price, String move, String cap) =>
    SquareFeedToken(
      kind: SquareFeedTokenKind.meme,
      memeTokenId: _uuid(symbol.hashCode.abs() % 1000 + 100),
      symbol: symbol,
      priceUsd1: Decimal.parse(price),
      change1hPct: Decimal.parse(move),
      marketCapUsd1: Decimal.parse(cap),
    );

List<SquareFeedPost> _feedRows() => <SquareFeedPost>[
  _post(
    1,
    kind: SquareFeedPostKind.system,
    text: '本周算力快照已更新，奖励将在明早 10:00 结算。',
    pinned: true,
    minutes: 60 * 5,
  ),
  _post(
    2,
    text: 'Bottom in. 这个位置我继续加，内盘还剩三成。',
    token: _token('FROG', '0.00004173', '14.4', '666700'),
    likes: 12,
    liked: true,
  ),
  _post(
    3,
    kind: SquareFeedPostKind.graduation,
    token: _token('MOON', '0.0123', '-3.2', '1250000'),
    minutes: 42,
  ),
  _post(4, text: '今天的 MEME 区有点安静，大家都在等什么？', alias: '小月亮', likes: 3),
  _post(
    5,
    kind: SquareFeedPostKind.buy,
    alias: 'whale_09',
    event: const <String, String>{'amountUsd1': '250'},
    token: _token('DOGE', '0.00000912', '2.1', '98000'),
    minutes: 90,
  ),
];

final class _Feed implements SquareFeedGateway {
  _Feed(this.items);

  final List<SquareFeedPost> items;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<SquareFeedPage> loadFeed(SquareFeedScope scope, {String? cursor}) =>
      Future<SquareFeedPage>.value(
        SquareFeedPage(
          scope: scope,
          items: items,
          nextCursor: null,
          observedAt: _now,
        ),
      );

  @override
  Future<SquareFeedPost> createPost({
    required String text,
    required String idempotencyKey,
    SquareFeedTokenRef? tokenRef,
  }) => throw UnimplementedError();

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<SquareFeedLike> setLike(String postId, {required bool liked}) =>
      Completer<SquareFeedLike>().future;
}

LoopV2MetaSnapshot _feedMeta() {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.squareFeed)
            LoopV2Capability(
              id: capability.id,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
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

Future<void> _pumpFeed(
  WidgetTester tester, {
  required Size size,
  required List<SquareFeedPost> items,
}) async {
  await pumpS7Page(
    tester,
    SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
    meta: _feedMeta(),
    size: size,
    overrides: <Override>[
      squareFeedGatewayProvider.overrideWithValue(_Feed(items)),
    ],
  );
  await tester.tap(_key('square-segment-0'));
  await tester.pumpAndSettle();
  await _settleArt(tester);
}

// ---------------------------------------------------------------------------
// 广场 · 社区
// ---------------------------------------------------------------------------

String _cid(int index) =>
    '4b96a75e-6828-4a6b-8c1d-${index.toString().padLeft(12, '0')}';

const _assetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';

const _joined = CommunityDirectoryViewer(
  role: CommunityRole.member,
  status: null,
  pending: false,
);

CommunitySummary _community(
  int index,
  String name,
  String description, {
  String? symbol,
  String? label,
  CommunityDirectoryViewer viewer = CommunityDirectoryViewer.none,
  int members = 28,
}) => CommunitySummary(
  communityId: _cid(index),
  name: name,
  slug: 'c$index',
  description: description,
  logoRef: 'avatar:preset/community-0${index % 9 + 1}',
  verificationStatus: CommunityVerification.verified,
  boundAssetKey: symbol == null ? null : _assetId,
  memberCount: members,
  createdAt: DateTime.utc(2026, 6),
  configVersion: 'communityV1',
  assetBadge: symbol == null
      ? null
      : CommunityAssetBadge(assetId: _assetId, symbol: symbol, logoUrl: null),
  viewerMembership: viewer,
  label: label,
);

List<CommunitySummary> _communities() => <CommunitySummary>[
  _community(
    0,
    'Meme 观察室',
    '只记录数据，不喊单。',
    symbol: 'DOGE',
    label: '算力社区',
    viewer: _joined,
    members: 1280,
  ),
  _community(1, 'DeFi 早读会', '每天早上十分钟，只讲链上发生的事', symbol: 'ETH', members: 230),
  _community(
    2,
    'Launch 候选池',
    '正在准备申请 Launch 的项目方交流',
    symbol: 'XRP',
    members: 22,
  ),
  _community(3, '新手问答角', '刚入圈不懂就问：钱包、Gas、授权', members: 20),
  _community(4, '链上数据观察站', '每天一张图看懂链上数据。', label: '数据', members: 20),
  _community(5, 'Frog Holders', '青蛙持有人的家', symbol: 'FROG', members: 18),
];

CommunityDirectoryPage _directory(List<CommunitySummary> items) =>
    CommunityDirectoryPage(
      items: items,
      nextCursor: null,
      recommendation: const CommunityRecommendation(
        recommendationId: '22222222-2222-4222-8222-222222222222',
        ruleVersion: 'rule:verified-members-v1',
      ),
      ordering: const CommunityOrderingApplied(
        sort: CommunityDirectorySort.members,
        basis: CommunityStoredBasis(),
      ),
    );

Future<void> _pumpCommunities(
  WidgetTester tester, {
  required Size size,
  required List<CommunitySummary> items,
}) async {
  await pumpCommunityPage(
    tester,
    SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
    size: size,
    community: FakeCommunityGateway(directoryPage: _directory(items)),
  );
  await _settleArt(tester);
}

void main() {
  loopWatchGround();

  for (final (label, size) in <(String, Size)>[
    ('390', _phone),
    ('360', _narrow),
  ]) {
    testWidgets('聊天 · 有数据 · $label', skip: !_shots, (tester) async {
      final rows = await _pumpChat(tester, size: size, empty: false);
      await _shot(tester, 'chat-$label', size);
      await _drainChat(tester, rows);
    });

    testWidgets('广场 · 动态 · $label', skip: !_shots, (tester) async {
      await _pumpFeed(tester, size: size, items: _feedRows());
      await _shot(tester, 'square-feed-$label', size);
      await _drain(tester);
    });

    testWidgets('广场 · 社区 · $label', skip: !_shots, (tester) async {
      await _pumpCommunities(tester, size: size, items: _communities());
      await _shot(tester, 'square-community-$label', size);
      await _drain(tester);
    });
  }

  testWidgets('聊天 · 空态', skip: !_shots, (tester) async {
    final rows = await _pumpChat(tester, size: _phone, empty: true);
    await _shot(tester, 'chat-empty', _phone);
    await _drainChat(tester, rows);
  });

  testWidgets('广场 · 动态 · 空态', skip: !_shots, (tester) async {
    await _pumpFeed(tester, size: _phone, items: const <SquareFeedPost>[]);
    await _shot(tester, 'square-feed-empty', _phone);
    await _drain(tester);
  });

  testWidgets('广场 · 社区 · 空态', skip: !_shots, (tester) async {
    await _pumpCommunities(
      tester,
      size: _phone,
      items: const <CommunitySummary>[],
    );
    await _shot(tester, 'square-community-empty', _phone);
    await _drain(tester);
  });
}
