// S270 · decision 0230: the 发帖 sheet always offers 关联代币 — the run's
// opened tokens, then the MEME v2 tokens held, then the MEME v2 projects the
// MEME Tab reads — with a local search, and says so when none can be read.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_feed_view.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final DateTime _now = DateTime.utc(2026, 10, 21, 12);

String _uuid(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

final class _Feed implements SquareFeedGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  final List<SquareFeedTokenRef?> sent = <SquareFeedTokenRef?>[];

  @override
  Future<SquareFeedPage> loadFeed(SquareFeedScope scope, {String? cursor}) =>
      Future<SquareFeedPage>.value(
        SquareFeedPage(
          scope: scope,
          items: const <SquareFeedPost>[],
          nextCursor: null,
          observedAt: _now,
        ),
      );

  @override
  Future<SquareFeedPost> createPost({
    required String text,
    required String idempotencyKey,
    SquareFeedTokenRef? tokenRef,
  }) {
    sent.add(tokenRef);
    return Future<SquareFeedPost>.value(
      SquareFeedPost(
        postId: _uuid(900),
        kind: SquareFeedPostKind.opinion,
        author: const SquareFeedAuthor(
          publicProfileId: 'pp_author01',
          loopId: 'LOOP-AUTHOR01',
          alias: 'me',
        ),
        text: text,
        likeCount: 0,
        likedByViewer: false,
        pinned: false,
        createdAt: _now,
      ),
    );
  }

  @override
  Future<void> deletePost(String postId) => Future<void>.value();

  @override
  Future<SquareFeedLike> setLike(String postId, {required bool liked}) =>
      Completer<SquareFeedLike>().future;
}

/// Answers the MEME Tab's list and `me/positions`; nothing else.
final class _Launch2 implements Launch2Gateway {
  _Launch2({required this.page, this.positions});

  final Launch2InstancePage page;
  final Launch2Positions? positions;
  int listReads = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) {
    listReads += 1;
    return Future<Launch2InstancePage>.value(page);
  }

  @override
  Future<Launch2Positions> loadPositions() {
    final answer = positions;
    if (answer == null) {
      return Future<Launch2Positions>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
    }
    return Future<Launch2Positions>.value(answer);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

LoopV2Capability _available(LoopV2CapabilityId id) => LoopV2Capability(
  id: id,
  availability: LoopV2CapabilityAvailability.available,
  reasonCode: null,
  evidence: const LoopV2CapabilityEvidence(
    status: LoopV2CapabilityEvidenceStatus.notApplicable,
    reasonCode: null,
  ),
);

LoopV2MetaSnapshot _meta() {
  final base = s7MetaSnapshot();
  const opened = <LoopV2CapabilityId>{
    LoopV2CapabilityId.squareFeed,
    LoopV2CapabilityId.launch2,
  };
  final listed = base.capabilities.capabilities.map((c) => c.id).toSet();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          opened.contains(capability.id)
              ? _available(capability.id)
              : capability,
        for (final id in opened)
          if (!listed.contains(id)) _available(id),
      ],
    ),
  );
}

/// [count] projects, `PRJ1…`, none of them the held FROG ([l2InstanceA]),
/// plus FROG itself last when [withFrog].
Launch2InstancePage _projects(int count, {bool withFrog = true}) =>
    l2Page(<Map<String, Object?>>[
      for (var i = 1; i <= count; i += 1)
        l2RowJson(
          instanceId: _uuid(100 + i),
          stage: 'public',
          name: 'Project $i',
          ticker: 'PRJ$i',
        ),
      if (withFrog) l2RowJson(stage: 'public'),
    ]);

Future<_Feed> _openComposer(
  WidgetTester tester, {
  _Launch2? launch2,
  List<SquareFeedTokenRef> recent = const <SquareFeedTokenRef>[],
}) async {
  final feed = _Feed();
  await pumpS7Page(
    tester,
    SquareFeedSegment(onNavigate: (_) {}, now: () => _now),
    meta: _meta(),
    overrides: <Override>[
      squareFeedGatewayProvider.overrideWithValue(feed),
      if (launch2 != null) launch2GatewayProvider.overrideWithValue(launch2),
    ],
  );
  if (recent.isNotEmpty) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SquareFeedSegment)),
    );
    for (final token in recent.reversed) {
      container.read(squareRecentTokensProvider.notifier).record(token);
    }
  }
  await tester.tap(_key('square-feed-compose'));
  await tester.pumpAndSettle();
  expect(_key('square-composer'), findsOneWidget);
  return feed;
}

List<String> _chips(WidgetTester tester) => tester
    .widgetList<LoopSeg>(
      find.descendant(
        of: _key('square-composer-tokens'),
        matching: find.byType(LoopSeg),
      ),
    )
    .map((chip) => chip.label)
    .toList();

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 30));
}

void main() {
  loopWatchGround();

  testWidgets('a fresh run still offers tokens, from the MEME v2 list', (
    tester,
  ) async {
    final launch2 = _Launch2(page: _projects(3, withFrog: false));
    await _openComposer(tester, launch2: launch2);
    expect(find.text('关联代币（可不选）'), findsOneWidget);
    expect(find.text('引用代币（可不选）'), findsNothing);
    expect(_chips(tester), <String>['不带代币', 'PRJ1', 'PRJ2', 'PRJ3', '搜索代币']);
    expect(_key('square-composer-token-empty'), findsNothing);
    expect(launch2.listReads, 1);
    await _teardown(tester);
  });

  testWidgets('order: opened this run, then held, then listed; 8 + 更多', (
    tester,
  ) async {
    final launch2 = _Launch2(page: _projects(10), positions: l2Positions());
    await _openComposer(
      tester,
      launch2: launch2,
      recent: const <SquareFeedTokenRef>[
        SquareFeedTokenRef(
          kind: SquareFeedTokenKind.meme,
          id: 'meme-1',
          symbol: 'PEPE',
        ),
      ],
    );
    // PEPE (recent) · FROG (held, also listed last: drawn once) · PRJ1…6.
    expect(_chips(tester), <String>[
      '不带代币',
      'PEPE',
      'FROG',
      'PRJ1',
      'PRJ2',
      'PRJ3',
      'PRJ4',
      'PRJ5',
      'PRJ6',
      '更多 4',
      '搜索代币',
    ]);
    await tester.tap(_key('square-composer-token-more'));
    await tester.pumpAndSettle();
    expect(_chips(tester), contains('PRJ10'));
    expect(_key('square-composer-token-more'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('search filters by ticker or name; selection survives it', (
    tester,
  ) async {
    final launch2 = _Launch2(page: _projects(12), positions: l2Positions());
    final feed = await _openComposer(tester, launch2: launch2);
    await tester.tap(_key('square-composer-token-search'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('square-composer-token-search-field'), 'prj1');
    await tester.pumpAndSettle();
    expect(_chips(tester), <String>[
      '不带代币',
      'PRJ1',
      'PRJ10',
      'PRJ11',
      'PRJ12',
      '搜索代币',
    ]);
    await tester.enterText(
      _key('square-composer-token-search-field'),
      'project 11',
    );
    await tester.pumpAndSettle();
    expect(_chips(tester), <String>['不带代币', 'PRJ11', '搜索代币']);
    await tester.tap(_key('square-composer-token-${_uuid(111)}'));
    await tester.pumpAndSettle();

    await tester.enterText(_key('square-composer-token-search-field'), 'zzz');
    await tester.pumpAndSettle();
    expect(_key('square-composer-token-no-match'), findsOneWidget);
    // The chosen token stays on the row while the search hides it.
    expect(_chips(tester), <String>['不带代币', 'PRJ11', '搜索代币']);

    // Closing the search clears it; the choice stays.
    await tester.tap(_key('square-composer-token-search'));
    await tester.pumpAndSettle();
    expect(_key('square-composer-token-search-field'), findsNothing);
    expect(
      tester
          .widget<LoopSeg>(_key('square-composer-token-${_uuid(111)}'))
          .selected,
      isTrue,
    );

    await tester.enterText(_key('square-composer-field'), 'to the moon');
    await tester.pump();
    await tester.tap(_key('square-composer-send'));
    await tester.pumpAndSettle();
    expect(feed.sent, hasLength(1));
    final sent = feed.sent.single!;
    expect(sent.kind, SquareFeedTokenKind.launch2);
    expect(sent.id, _uuid(111));
    expect(_key('square-composer'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('a held token chosen is sent as its launch2 instance', (
    tester,
  ) async {
    final launch2 = _Launch2(page: _projects(2), positions: l2Positions());
    final feed = await _openComposer(tester, launch2: launch2);
    await tester.tap(_key('square-composer-token-$l2InstanceA'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('square-composer-field'), 'frog');
    await tester.pump();
    await tester.tap(_key('square-composer-send'));
    await tester.pumpAndSettle();
    expect(feed.sent.single, isNotNull);
    expect(feed.sent.single!.kind, SquareFeedTokenKind.launch2);
    expect(feed.sent.single!.id, l2InstanceA);
    await _teardown(tester);
  });

  testWidgets('不带代币 sends no tokenRef', (tester) async {
    final launch2 = _Launch2(page: _projects(2));
    final feed = await _openComposer(tester, launch2: launch2);
    expect(
      tester.widget<LoopSeg>(_key('square-composer-token-none')).selected,
      isTrue,
    );
    await tester.enterText(_key('square-composer-field'), 'plain');
    await tester.pump();
    await tester.tap(_key('square-composer-send'));
    await tester.pumpAndSettle();
    expect(feed.sent, <SquareFeedTokenRef?>[null]);
    await _teardown(tester);
  });

  testWidgets('no candidate anywhere: the section stays and says so', (
    tester,
  ) async {
    // The list is empty and positions fail.
    final launch2 = _Launch2(page: l2Page(const <Map<String, Object?>>[]));
    await _openComposer(tester, launch2: launch2);
    expect(find.text('关联代币（可不选）'), findsOneWidget);
    expect(_key('square-composer-token-empty'), findsOneWidget);
    expect(find.text('暂时读不到代币，稍后再试'), findsOneWidget);
    // Posting without a token still works.
    expect(_key('square-composer-send'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('MEME v2 closed: the run\'s tokens alone, else the notice', (
    tester,
  ) async {
    await _openComposer(tester);
    expect(find.text('暂时读不到代币，稍后再试'), findsOneWidget);
    await _teardown(tester);
  });

  test('merge drops repeats and dead projects, keeps the order', () {
    final options = squareComposerTokenOptions(
      recent: const <SquareFeedTokenRef>[
        SquareFeedTokenRef(
          kind: SquareFeedTokenKind.launch2,
          id: l2InstanceA,
          symbol: 'FROG',
        ),
      ],
      positions: l2Positions().items,
      rows: _projects(1).items
          .followedBy(
            l2Page(<Map<String, Object?>>[
              l2RowJson(
                instanceId: l2InstanceB,
                stage: 'closed_no_holders',
                ticker: 'DEAD',
              ),
            ]).items,
          )
          .toList(),
    );
    expect(options.map((o) => o.ref.symbol), <String>['FROG', 'PRJ1']);
    expect(options.first.matches('frog'), isTrue);
    expect(options.last.matches('project'), isTrue);
    expect(options.last.matches('frog'), isFalse);
  });
}
