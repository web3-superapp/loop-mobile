import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/mining/loop_v2_mining_api.dart';

import 'support/community_test_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// S60 · decision 0061: the two discover orders that name their source, and
/// the settled run that admits which kinds of balance it counted.
///
/// Two facts this suite keeps: an empty page under an ordering the server
/// could not apply is never rendered as 「没有社区」, and a figure computed
/// from holdings nobody holds always says so on the page that prints it.
const _token = 'access.token';
const _clientVersion = '1.0.0';
const _communityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const _otherCommunityId = '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e60';
const _recommendationId = '22222222-2222-4222-8222-222222222222';
const _snapshotId = '0e358b31-e49f-48b9-89b2-c5c908c3ad5e';
const _baselineVersion = 'miningFormula-devBaseline-2026-09-21-r4';

Map<String, Object?> _community({
  String communityId = _communityId,
  String name = 'Frog Holders',
  int memberCount = 311,
  Map<String, Object?>? miningPower,
  Map<String, Object?>? activity,
}) => <String, Object?>{
  'communityId': communityId,
  'name': name,
  'slug': 'frog-holders',
  'description': null,
  'logoRef': 'avatar:preset/community-03',
  'verificationStatus': 'verified',
  'boundAssetKey': null,
  'memberCount': memberCount,
  'createdAt': '2026-09-07T01:00:00.000Z',
  'configVersion': 'communityV1',
  'miningPower': ?miningPower,
  'activity': ?activity,
};

Map<String, Object?> _rowPower({String power = '2305.5'}) => <String, Object?>{
  'status': 'available',
  'subject': 'community',
  'power': power,
  'snapshotId': _snapshotId,
  'formulaVersion': _baselineVersion,
  'computedAt': '2026-09-21T09:00:00.000Z',
  'scope': 'development_baseline',
  'stale': false,
  'weight': <String, Object?>{
    'status': 'approved',
    'value': '1.5',
    'configVersion': _baselineVersion,
    'reviewedAt': '2026-09-21T08:00:00.000Z',
  },
  'participants': <String, Object?>{'status': 'available', 'count': 2},
};

Map<String, Object?> _rowActivity({
  int messageCount = 41,
  bool bounded = false,
}) => <String, Object?>{
  'status': 'available',
  'messageCount': messageCount,
  'windowDays': 7,
  'bounded': bounded,
  'observedAt': '2026-09-21T09:15:00.000Z',
};

Map<String, Object?> _body({
  required List<Object?> items,
  Object? ordering,
  Object? nextCursor,
}) => <String, Object?>{
  'items': items,
  'nextCursor': nextCursor,
  'ordering': ?ordering,
  'recommendation': <String, Object?>{
    'recommendationId': _recommendationId,
    'ruleVersion': 'rule:verified-members-v1',
  },
  'contractVersion': '2.0',
};

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  final Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      'cache-control': <String>['no-store'],
      'x-request-id': const <String>['11111111-1111-4111-8111-111111111111'],
    },
  );
}

Future<CommunityDirectoryPage> _list(
  Object? body, {
  CommunityDirectorySort sort = CommunityDirectorySort.members,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _Adapter(body);
  return DioLoopV2CommunityApi(dio).listCommunities(
    accessToken: _token,
    clientVersion: _clientVersion,
    sort: sort,
    verification: CommunityVerificationFilter.verified,
    membership: CommunityMembershipFilter.all,
  );
}

Map<String, Object?> _miningSummaryBody({Object? holdingsSource}) =>
    <String, Object?>{
      'power': <String, Object?>{'status': 'available', 'value': '1000'},
      'networkPower': <String, Object?>{'status': 'available', 'value': '4000'},
      'estimatedToday': <String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'MINING_NETWORK_POWER_ZERO',
      },
      'accumulated': <String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'REWARD_AUTHORITY_PENDING',
      },
      'claimable': <String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'REWARD_AUTHORITY_PENDING',
      },
      'referralBoost': <String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'MINING_REFERRAL_BOOST_PENDING',
      },
      'formula': <String, Object?>{
        'status': 'approved',
        'configVersion': _baselineVersion,
        'effectiveAt': '2026-09-21T08:57:37.026Z',
        'scope': 'development_baseline',
      },
      'snapshot': <String, Object?>{
        'snapshotId': _snapshotId,
        'blockNumber': '122037728',
        'blockHash':
            '0x3decab82b150493d90cb8fe47b3873c6e3b8c72aecf08ce91b4aceb266bda2'
            '8a',
        'formulaVersion': _baselineVersion,
        'priceVersion': 'dexscreener:2026-09-21T08:58:51.862Z',
        'computedAt': '2026-09-21T09:00:00.000Z',
        'holdingsSource': ?holdingsSource,
      },
      'contractVersion': '2.0',
    };

Future<MiningSummary> _summary(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _Adapter(body);
  return DioLoopV2MiningApi(dio)
      .getSummary(accessToken: _token, clientVersion: _clientVersion);
}

void main() {
  group('GET /v2/communities · ordering', () {
    test('a stored order names the column it ranked by', () async {
      final page = await _list(
        _body(
          items: <Object?>[_community()],
          ordering: <String, Object?>{
            'status': 'available',
            'sort': 'members',
            'basis': <String, Object?>{'kind': 'stored'},
          },
        ),
      );

      final ordering = page.ordering as CommunityOrderingApplied;
      expect(ordering.sort, CommunityDirectorySort.members);
      expect(ordering.basis, isA<CommunityStoredBasis>());
      // A stored sort carries no row fact, not a null one.
      expect(page.items.single.miningPower, isNull);
      expect(page.items.single.activity, isNull);
    });

    test('the power order carries the run it ranked by, and the row '
        'carries its own number', () async {
      final page = await _list(
        _body(
          items: <Object?>[
            _community(miningPower: _rowPower()),
            _community(
              communityId: _otherCommunityId,
              name: '空投猎人小队',
              miningPower: <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'COMMUNITY_ASSET_NOT_BOUND',
              },
            ),
          ],
          ordering: <String, Object?>{
            'status': 'available',
            'sort': 'miningPower',
            'basis': <String, Object?>{
              'kind': 'miningSnapshot',
              'snapshotId': _snapshotId,
              'formulaVersion': _baselineVersion,
              'computedAt': '2026-09-21T09:00:00.000Z',
              'scope': 'development_baseline',
              'stale': false,
            },
          },
        ),
        sort: CommunityDirectorySort.miningPower,
      );

      final ordering = page.ordering as CommunityOrderingApplied;
      final basis = ordering.basis as CommunityMiningBasis;
      expect(basis.snapshotId, _snapshotId);
      expect(basis.scope, MiningFormulaScope.developmentBaseline);
      expect(basis.stale, isFalse);
      final ranked = page.items.first.miningPower as LoopCommunityMiningPower;
      expect(ranked.power, '2305.5');
      expect((ranked.weight as MiningCommunityWeightApproved).value, '1.5');
      // A community with no approved weight is still listed; its number is
      // absent, which is not a zero.
      expect(
        (page.items.last.miningPower as LoopMiningPowerUnavailable).reasonCode,
        'COMMUNITY_ASSET_NOT_BOUND',
      );
    });

    test('the discussion order carries its window, and a bounded row is a '
        'floor', () async {
      final page = await _list(
        _body(
          items: <Object?>[
            _community(activity: _rowActivity(bounded: true)),
            _community(
              communityId: _otherCommunityId,
              activity: <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'COMMUNITY_ACTIVITY_CHANNEL_NOT_OBSERVED',
              },
            ),
          ],
          ordering: <String, Object?>{
            'status': 'available',
            'sort': 'activity',
            'basis': <String, Object?>{
              'kind': 'channelActivity',
              'windowDays': 7,
              'observedCommunityCount': 26,
              'observedAt': '2026-09-21T09:15:00.000Z',
            },
          },
        ),
        sort: CommunityDirectorySort.activity,
      );

      final basis =
          (page.ordering as CommunityOrderingApplied).basis
              as CommunityActivityBasis;
      expect(basis.windowDays, 7);
      expect(basis.observedCommunityCount, 26);
      final counted = page.items.first.activity as CommunityActivityCount;
      expect(counted.messageCount, 41);
      expect(counted.bounded, isTrue);
      expect(
        (page.items.last.activity as CommunityActivityUnavailable).reasonCode,
        'COMMUNITY_ACTIVITY_CHANNEL_NOT_OBSERVED',
      );
    });

    test('an order nobody could apply answers with its reason', () async {
      final page = await _list(
        _body(
          items: const <Object?>[],
          ordering: <String, Object?>{
            'status': 'unavailable',
            'sort': 'activity',
            'reasonCode': 'COMMUNITY_ACTIVITY_NOT_OBSERVED',
          },
        ),
        sort: CommunityDirectorySort.activity,
      );

      expect(page.orderingFailed, isTrue);
      expect(
        (page.ordering as CommunityOrderingUnavailable).reasonCode,
        'COMMUNITY_ACTIVITY_NOT_OBSERVED',
      );
      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('a deployment that predates the field is read as the stored order '
        'it could only have applied', () async {
      final page = await _list(_body(items: <Object?>[_community()]));

      final ordering = page.ordering as CommunityOrderingApplied;
      expect(ordering.sort, CommunityDirectorySort.members);
      expect(ordering.basis, isA<CommunityStoredBasis>());
    });

    test('a payload the page cannot place is refused', () async {
      Future<void> refuses(Object? body, CommunityDirectorySort sort) async {
        await expectLater(
          _list(body, sort: sort),
          throwsA(
            isA<LoopBackendFailure>().having(
              (e) => e.kind,
              'kind',
              LoopBackendFailureKind.invalidPayload,
            ),
          ),
        );
      }

      // Rows under an order the server says it could not apply.
      await refuses(
        _body(
          items: <Object?>[_community()],
          ordering: <String, Object?>{
            'status': 'unavailable',
            'sort': 'members',
            'reasonCode': 'COMMUNITY_ACTIVITY_NOT_OBSERVED',
          },
        ),
        CommunityDirectorySort.members,
      );
      // An order other than the one that was asked for.
      await refuses(
        _body(
          items: const <Object?>[],
          ordering: <String, Object?>{
            'status': 'available',
            'sort': 'members',
            'basis': <String, Object?>{'kind': 'stored'},
          },
        ),
        CommunityDirectorySort.activity,
      );
      // A basis that does not belong to the order it was sent with.
      await refuses(
        _body(
          items: const <Object?>[],
          ordering: <String, Object?>{
            'status': 'available',
            'sort': 'activity',
            'basis': <String, Object?>{'kind': 'stored'},
          },
        ),
        CommunityDirectorySort.activity,
      );
      // A row carrying the other order's fact.
      await refuses(
        _body(
          items: <Object?>[_community(activity: _rowActivity())],
          ordering: <String, Object?>{
            'status': 'available',
            'sort': 'miningPower',
            'basis': <String, Object?>{
              'kind': 'miningSnapshot',
              'snapshotId': _snapshotId,
              'formulaVersion': _baselineVersion,
              'computedAt': '2026-09-21T09:00:00.000Z',
              'scope': 'development_baseline',
              'stale': false,
            },
          },
        ),
        CommunityDirectorySort.miningPower,
      );
      // A stored order whose rows carry a ranking fact anyway.
      await refuses(
        _body(
          items: <Object?>[_community(miningPower: _rowPower())],
          ordering: <String, Object?>{
            'status': 'available',
            'sort': 'members',
            'basis': <String, Object?>{'kind': 'stored'},
          },
        ),
        CommunityDirectorySort.members,
      );
      // An unknown key anywhere in the new projection.
      await refuses(
        _body(
          items: const <Object?>[],
          ordering: <String, Object?>{
            'status': 'available',
            'sort': 'activity',
            'basis': <String, Object?>{
              'kind': 'channelActivity',
              'windowDays': 7,
              'observedCommunityCount': 26,
              'observedAt': '2026-09-21T09:15:00.000Z',
              'trend': 'up',
            },
          },
        ),
        CommunityDirectorySort.activity,
      );
    });
  });

  group('community-discover · the four segments', () {
    CommunityDirectoryPage ranked({
      required CommunityDirectorySort sort,
      required List<CommunitySummary> items,
    }) => CommunityDirectoryPage(
      items: items,
      nextCursor: null,
      recommendation: const CommunityRecommendation(
        recommendationId: _recommendationId,
        ruleVersion: 'rule:verified-members-v1',
      ),
      ordering: CommunityOrderingApplied(
        sort: sort,
        basis: sort == CommunityDirectorySort.miningPower
            ? CommunityMiningBasis(
                snapshotId: _snapshotId,
                formulaVersion: _baselineVersion,
                computedAt: DateTime.utc(2026, 9, 21, 9),
                scope: MiningFormulaScope.developmentBaseline,
                stale: false,
              )
            : CommunityActivityBasis(
                windowDays: 7,
                observedCommunityCount: 26,
                observedAt: DateTime.utc(2026, 9, 21, 9, 15),
              ),
      ),
    );

    CommunityDirectoryPage unavailable({
      required CommunityDirectorySort sort,
      required String reasonCode,
    }) => CommunityDirectoryPage(
      items: const <CommunitySummary>[],
      nextCursor: null,
      recommendation: const CommunityRecommendation(
        recommendationId: _recommendationId,
        ruleVersion: 'rule:verified-members-v1',
      ),
      ordering: CommunityOrderingUnavailable(
        sort: sort,
        reasonCode: reasonCode,
      ),
    );

    CommunityDirectoryPage stored(List<CommunitySummary> items) =>
        CommunityDirectoryPage(
          items: items,
          nextCursor: null,
          recommendation: const CommunityRecommendation(
            recommendationId: _recommendationId,
            ruleVersion: 'rule:verified-members-v1',
          ),
          ordering: const CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),
        );

    test('a failed read answers for itself, not with the last order it was '
        'told about', () {
      // The ordering a page was last told about says nothing about a request
      // that never arrived, so the failure keeps its own state.
      const state = CommunityDiscoverState(
        mode: CommunityGatewayMode.production,
        phase: CommunityViewPhase.offline,
        sort: CommunityDirectorySort.activity,
        membership: CommunityMembershipFilter.all,
        ordering: CommunityOrderingUnavailable(
          sort: CommunityDirectorySort.activity,
          reasonCode: 'COMMUNITY_ACTIVITY_NOT_OBSERVED',
        ),
        failureKind: CommunityFailureKind.offline,
      );
      expect(state.orderingReasonCode, isNull);
      expect(
        CommunityDiscoverState(
          mode: state.mode,
          phase: CommunityViewPhase.ready,
          sort: state.sort,
          membership: state.membership,
          ordering: state.ordering,
        ).orderingReasonCode,
        'COMMUNITY_ACTIVITY_NOT_OBSERVED',
      );
    });

    testWidgets('an order the server could not apply is not an empty list', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        directoryPage: stored(<CommunitySummary>[testCommunity()]),
      );
      gateway.directoryPagesBySort =
          <CommunityDirectorySort, CommunityDirectoryPage>{
            CommunityDirectorySort.activity: unavailable(
              sort: CommunityDirectorySort.activity,
              reasonCode: 'COMMUNITY_ACTIVITY_NOT_OBSERVED',
            ),
          };
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('discover-seg-discussion')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('community-discover-ordering-unavailable'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          communityUnavailableReason('COMMUNITY_ACTIVITY_NOT_OBSERVED'),
        ),
        findsOneWidget,
      );
      // The empty-collection sentence would claim there are no communities,
      // which is not what the server answered.
      expect(find.text('没有符合条件的社区'), findsNothing);
      expect(find.text('这个排序下没有社区。'), findsNothing);

      // The page offers the order it can apply, and taking it asks for that
      // order by name.
      await tester.tap(
        find.byKey(const ValueKey<String>('community-discover-ordering-back')),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands.last, startsWith('list:members:'));
      expect(
        find.byKey(
          const ValueKey<String>('community-discover-ordering-unavailable'),
        ),
        findsNothing,
      );
    });

    testWidgets('a ranked row states the number it was ranked by', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        directoryPage: stored(<CommunitySummary>[testCommunity()]),
      );
      gateway.directoryPagesBySort =
          <CommunityDirectorySort, CommunityDirectoryPage>{
            CommunityDirectorySort.miningPower: ranked(
              sort: CommunityDirectorySort.miningPower,
              items: <CommunitySummary>[
                testCommunity(
                  miningPower: LoopCommunityMiningPower(
                    power: '23050.5',
                    snapshotId: _snapshotId,
                    formulaVersion: _baselineVersion,
                    computedAt: DateTime.utc(2026, 9, 21, 9),
                    scope: MiningFormulaScope.developmentBaseline,
                    weight: MiningCommunityWeightApproved(
                      value: '1.5',
                      configVersion: _baselineVersion,
                      reviewedAt: DateTime.utc(2026, 9, 21, 8),
                    ),
                    participants: const MiningParticipantsCount(2),
                  ),
                ),
                testCommunity(
                  communityId: '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e60',
                  name: '空投猎人小队',
                  miningPower: const LoopMiningPowerUnavailable(
                    'COMMUNITY_ASSET_NOT_BOUND',
                  ),
                ),
              ],
            ),
            CommunityDirectorySort.activity: ranked(
              sort: CommunityDirectorySort.activity,
              items: <CommunitySummary>[
                testCommunity(
                  activity: CommunityActivityCount(
                    messageCount: 41,
                    windowDays: 7,
                    bounded: true,
                    observedAt: DateTime.utc(2026, 9, 21, 9, 15),
                  ),
                ),
              ],
            ),
          };
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('discover-seg-power')),
      );
      await tester.pumpAndSettle();
      expect(find.text('23,050.5'), findsOneWidget);
      expect(find.text('算力'), findsNWidgets(2));
      // The row with no approved weight prints a dash, never a zero.
      expect(find.text('—'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('discover-seg-discussion')),
      );
      await tester.pumpAndSettle();
      // A full page of messages that still began inside the window is a
      // floor, and the row says so.
      expect(find.text('≥41'), findsOneWidget);
      expect(find.text('7 天讨论'), findsOneWidget);
    });
  });

  group('mining · holdings that say what they are', () {
    test('the settled run carries which balances produced it', () async {
      final chain = await _summary(_miningSummaryBody(holdingsSource: 'chain'));
      expect(
        (chain.snapshot as MiningSnapshotComputed).holdingsSource,
        MiningHoldingsSource.chain,
      );
      expect(
        (chain.snapshot as MiningSnapshotComputed)
            .includesDemonstrationHoldings,
        isFalse,
      );

      for (final pair in <(String, MiningHoldingsSource)>[
        ('mock_seed', MiningHoldingsSource.mockSeed),
        ('mixed', MiningHoldingsSource.mixed),
      ]) {
        final summary = await _summary(
          _miningSummaryBody(holdingsSource: pair.$1),
        );
        final snapshot = summary.snapshot as MiningSnapshotComputed;
        expect(snapshot.holdingsSource, pair.$2);
        expect(snapshot.includesDemonstrationHoldings, isTrue);
      }

      // A deployment that predates the field claims nothing about it.
      final silent = await _summary(_miningSummaryBody());
      expect(
        (silent.snapshot as MiningSnapshotComputed).holdingsSource,
        isNull,
      );
      expect(
        (silent.snapshot as MiningSnapshotComputed)
            .includesDemonstrationHoldings,
        isFalse,
      );

      await expectLater(
        _summary(_miningSummaryBody(holdingsSource: 'seeded')),
        throwsA(
          isA<LoopBackendFailure>().having(
            (e) => e.kind,
            'kind',
            LoopBackendFailureKind.invalidPayload,
          ),
        ),
      );
    });

    testWidgets('a figure computed from demonstration holdings says so under '
        'the hero', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              snapshot: s7MiningSnapshot(
                holdingsSource: MiningHoldingsSource.mixed,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-demo-holdings-summary')),
        findsOneWidget,
      );
      expect(find.text('含演示持仓 · 仅开发环境'), findsOneWidget);
    });

    testWidgets('a chain-only run prints no demonstration line', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              snapshot: s7MiningSnapshot(
                holdingsSource: MiningHoldingsSource.chain,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-demo-holdings-summary')),
        findsNothing,
      );
      expect(find.textContaining('演示持仓'), findsNothing);
    });
  });
}
