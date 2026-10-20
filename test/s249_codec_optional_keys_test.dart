import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_overview_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/referral/loop_v2_referral_api.dart';

import 'support/launch2_fixtures.dart';

/// S249 (client decision 0209): the keys loop-api decision 0162 added and
/// decision 0166 put behind `LAUNCH2_TRADER_ACCOUNT_EMIT` /
/// `REFERRAL_CENTER_EMIT` decode as optional keys. Absent, every read is
/// what build 30 read; present, they land on the model; `null` where the
/// schema allows it is `null`; any other new key is still refused.

const _account = <String, Object?>{
  'publicProfileId': 'pp_7hjkm2',
  'displayName': 'alice',
  'avatarRef': 'media/avatars/alice.png',
};

const _accountNoProfileFields = <String, Object?>{
  'publicProfileId': 'pp_7hjkm3',
  'displayName': null,
  'avatarRef': null,
};

Matcher get _invalidPayload => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

String? _noMedia(String mediaId) => null;

void main() {
  group('launch2 · curve trade account (instance.recentTrades[])', () {
    Launch2Trade decode(Map<String, Object?> trade) =>
        LoopV2Launch2Codec.detail(
          l2DetailJson(trades: <Map<String, Object?>>[trade]),
          mediaUrl: _noMedia,
        ).recentTrades.single;

    test('absent: decodes as before, account null', () {
      final trade = decode(l2TradeJson());
      expect(trade.tradeId, 't-1');
      expect(trade.traderAddress, l2WalletAddress);
      expect(trade.account, isNull);
    });

    test('present: lands on the model', () {
      final trade = decode(<String, Object?>{
        ...l2TradeJson(),
        'account': _account,
      });
      expect(trade.account!.publicProfileId, 'pp_7hjkm2');
      expect(trade.account!.displayName, 'alice');
      expect(trade.account!.avatarRef, 'media/avatars/alice.png');
      expect(trade.traderAddress, l2WalletAddress);

      final bare = decode(<String, Object?>{
        ...l2TradeJson(),
        'account': _accountNoProfileFields,
      });
      expect(bare.account!.publicProfileId, 'pp_7hjkm3');
      expect(bare.account!.displayName, isNull);
      expect(bare.account!.avatarRef, isNull);
    });

    test('null: no visible account, the row keeps its address', () {
      final trade = decode(<String, Object?>{
        ...l2TradeJson(),
        'account': null,
      });
      expect(trade.account, isNull);
      expect(trade.traderAddress, l2WalletAddress);
    });

    test('an unknown key, or an account of another shape, is refused', () {
      expect(
        () => decode(<String, Object?>{...l2TradeJson(), 'traderAlias': 'x'}),
        _invalidPayload,
      );
      expect(
        () => decode(<String, Object?>{
          ...l2TradeJson(),
          'account': <String, Object?>{..._account, 'userId': 'u1'},
        }),
        _invalidPayload,
      );
      expect(
        () => decode(<String, Object?>{
          ...l2TradeJson(),
          'account': <String, Object?>{'publicProfileId': 'pp_1'},
        }),
        _invalidPayload,
      );
    });
  });

  group('launch2 · pool trade account (…/pool/trades trades[])', () {
    Map<String, Object?> body() {
      final file = File('test/fixtures/s150-launch2/pool_trades.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      return json['body']! as Map<String, Object?>;
    }

    List<Launch2PoolTradeLike> decode(
      Map<String, Object?> Function(Map<String, Object?>) edit,
    ) {
      final source = body();
      final trades = <Object?>[
        for (final trade in source['trades']! as List<Object?>)
          edit(Map<String, Object?>.of(trade! as Map<String, Object?>)),
      ];
      final parsed = LoopV2Launch2PoolCodec.trades(
        <String, Object?>{...source, 'trades': trades},
        instanceId: source['instanceId']! as String,
        walletId: source['walletId']! as String,
      );
      return <Launch2PoolTradeLike>[
        for (final trade in parsed.trades)
          (id: trade.poolTradeId, account: trade.account?.publicProfileId),
      ];
    }

    test('absent: decodes as before, account null', () {
      final trades = decode((trade) => trade);
      expect(trades, hasLength(2));
      expect(trades.every((trade) => trade.account == null), isTrue);
    });

    test('present and null decode', () {
      final present = decode((trade) => trade..['account'] = _account);
      expect(present.every((trade) => trade.account == 'pp_7hjkm2'), isTrue);
      final none = decode((trade) => trade..['account'] = null);
      expect(none.every((trade) => trade.account == null), isTrue);
    });

    test('an unknown key is still refused', () {
      expect(
        () => decode((trade) => trade..['traderProfile'] = _account),
        _invalidPayload,
      );
    });
  });

  group('launch2 · overview activity account (activity[])', () {
    Map<String, Object?> activity({Object? account = _omit}) =>
        <String, Object?>{
          'kind': 'curve_buy',
          'instanceId': l2InstanceA,
          'ticker': 'DOGE',
          'name': 'Doge on LOOP',
          'logoUrl': null,
          'actor': '0x1d2f000000000000000000000000000000009b9b',
          'amountUsd1': '20',
          'at': l2Now.toIso8601String(),
          'transactionHash': '0x${'a' * 64}',
          if (!identical(account, _omit)) 'account': account,
        };

    Map<String, Object?> body(Map<String, Object?> item) => <String, Object?>{
      'activity': <Object?>[item],
      'observedAt': l2Now.toIso8601String(),
      'contractVersion': '2.0',
    };

    test('absent, present, null and unreadable', () {
      final absent = LoopV2Launch2OverviewCodec.overview(
        body(activity()),
        mediaUrl: _noMedia,
      ).activity.single;
      expect(absent.account, isNull);
      expect(absent.actor, '0x1d2f000000000000000000000000000000009b9b');

      final present = LoopV2Launch2OverviewCodec.overview(
        body(activity(account: _account)),
        mediaUrl: _noMedia,
      ).activity.single;
      expect(present.account!.displayName, 'alice');
      // The identity of an event does not depend on the optional account.
      expect(present.identity, absent.identity);

      final none = LoopV2Launch2OverviewCodec.overview(
        body(activity(account: null)),
        mediaUrl: _noMedia,
      ).activity.single;
      expect(none.account, isNull);

      // This read is forgiving: a bad account is null, the item stays.
      final bad = LoopV2Launch2OverviewCodec.overview(
        body(activity(account: 'pp_1')),
        mediaUrl: _noMedia,
      ).activity;
      expect(bad, hasLength(1));
      expect(bad.single.account, isNull);
    });
  });

  group('referral · center keys (GET /v2/referral)', () {
    Map<String, Object?> body({
      Object? inviteLink = _omit,
      Object? stats = _omit,
      Object? boost,
      Map<String, Object?> extra = const <String, Object?>{},
    }) => <String, Object?>{
      'inviteCode': <String, Object?>{
        'code': 'LOOP-7HJKM',
        'issuedAt': '2026-09-08T00:00:00.000Z',
      },
      if (!identical(inviteLink, _omit)) 'inviteLink': inviteLink,
      'binding': <String, Object?>{
        'status': 'unbound',
        'inviter': null,
        'claimWindow': <String, Object?>{
          'status': 'open',
          'activatedAt': '2026-09-06T00:00:00.000Z',
          'closesAt': '2026-09-13T00:00:00.000Z',
        },
      },
      'levels': <Object?>[
        for (var level = 1; level <= 5; level += 1)
          <String, Object?>{
            'level': level,
            'boostPercent': <String>['10', '5', '3', '2', '1'][level - 1],
            'counts': <String, Object?>{
              'pending_activation': 0,
              'pending_wallet': level == 1 ? 2 : 0,
              'pending_mining': 0,
              'valid': level == 1 ? 1 : 0,
              'invalidated': 0,
            },
            'total': level == 1 ? 3 : 0,
          },
      ],
      if (!identical(stats, _omit)) 'stats': stats,
      'boost':
          boost ??
          <String, Object?>{
            'status': 'unavailable',
            'reasonCode': 'MINING_REFERRAL_BOOST_PENDING',
          },
      'rules': <String, Object?>{
        'configVersion': 'referralRulesV1',
        'effectiveAt': '2026-09-01T00:00:00.000Z',
        'appliesTo': 'miningPower',
        'maximumDepth': 5,
        'claimWindowDays': 7,
      },
      'contractVersion': '2.0',
      ...extra,
    };

    Map<String, Object?> stats({
      Object? validAsOf = '2026-10-19T09:00:00.000Z',
    }) => <String, Object?>{
      'directCount': 3,
      'validCount': 1,
      'level2to5Count': 4,
      'validAsOf': validAsOf,
    };

    Map<String, Object?> available() => <String, Object?>{
      'status': 'available',
      'referralPower': '12.5',
      'nftReferralPower': '10',
      'assetReferralPower': '2.5',
      'levels': <Object?>[
        for (var level = 5; level >= 1; level -= 1)
          <String, Object?>{
            'level': level,
            'effectiveMembers': level == 1 ? 1 : 0,
            'nftPower': level == 1 ? '10' : '0',
            'assetPower': level == 1 ? '2.5' : '0',
          },
      ],
      'epochId': '0e358b31-e49f-48b9-89b2-c5c908c3ad5e',
      'hourStart': '2026-10-19T08:00:00.000Z',
      'hourEnd': '2026-10-19T09:00:00.000Z',
    };

    Future<ReferralOverview> read(Map<String, Object?> payload) =>
        DioLoopV2ReferralApi(_dio(payload))
            .getOverview(accessToken: 'access-token', clientVersion: '1.4.0');

    test('switch off (six keys): decodes exactly as before', () async {
      final overview = await read(body());
      expect(overview.inviteCode.code, 'LOOP-7HJKM');
      expect(overview.levels.first.boostPercent, '10');
      expect(overview.boost!.reasonCode, 'MINING_REFERRAL_BOOST_PENDING');
      expect(overview.boostAvailable, isNull);
      expect(overview.inviteLink, isNull);
      expect(overview.stats, isNull);
    });

    test('switch on: invite link, stats and the available boost', () async {
      final overview = await read(
        body(
          inviteLink: 'https://api-staging.example.com/i/LOOP-7HJKM',
          stats: stats(),
          boost: available(),
        ),
      );
      expect(
        overview.inviteLink,
        'https://api-staging.example.com/i/LOOP-7HJKM',
      );
      expect(overview.stats!.directCount, 3);
      expect(overview.stats!.validCount, 1);
      expect(overview.stats!.level2to5Count, 4);
      expect(overview.stats!.validAsOf, DateTime.utc(2026, 10, 19, 9));
      expect(overview.boost, isNull);
      final boost = overview.boostAvailable!;
      expect(boost.referralPower, '12.5');
      expect(boost.levels.map((level) => level.level), <int>[1, 2, 3, 4, 5]);
      expect(boost.levels.first.effectiveMembers, 1);
      expect(boost.hourEnd, DateTime.utc(2026, 10, 19, 9));
    });

    test('switch on before the first settled hour', () async {
      // `validAsOf` null, boost still the pending projection.
      final overview = await read(
        body(
          inviteLink: 'http://127.0.0.1:3100/i/LOOP-7HJKM',
          stats: stats(validAsOf: null),
        ),
      );
      expect(overview.stats!.validAsOf, isNull);
      expect(overview.boost!.reasonCode, 'MINING_REFERRAL_BOOST_PENDING');
      expect(overview.inviteLink, 'http://127.0.0.1:3100/i/LOOP-7HJKM');
    });

    test('a key the schema does not allow to be null is refused', () async {
      await expectLater(read(body(inviteLink: null)), _invalidPayload);
      await expectLater(read(body(stats: null)), _invalidPayload);
    });

    test('an unknown key is still refused', () async {
      await expectLater(
        read(body(extra: <String, Object?>{'invitees': <Object?>[]})),
        _invalidPayload,
      );
      await expectLater(
        read(body(stats: <String, Object?>{...stats(), 'activeCount': 1})),
        _invalidPayload,
      );
      await expectLater(
        read(body(boost: <String, Object?>{...available(), 'usdValue': '1'})),
        _invalidPayload,
      );
    });

    test('a link for another code or with credentials is refused', () async {
      for (final link in <String>[
        'https://api.example.com/i/LOOP-AAAAA',
        'https://user:pw@api.example.com/i/LOOP-7HJKM',
        'ftp://api.example.com/i/LOOP-7HJKM',
        'https://api.example.com/i/LOOP-7HJKM?ref=1',
      ]) {
        await expectLater(read(body(inviteLink: link)), _invalidPayload);
      }
    });

    test('inconsistent figures are refused', () async {
      await expectLater(
        read(body(stats: <String, Object?>{...stats(), 'validCount': 9})),
        _invalidPayload,
      );
      final boost = available()..['referralPower'] = '-1';
      await expectLater(read(body(boost: boost)), _invalidPayload);
      final short = available()
        ..['levels'] = (available()['levels']! as List<Object?>).sublist(1);
      await expectLater(read(body(boost: short)), _invalidPayload);
    });
  });
}

typedef Launch2PoolTradeLike = ({String id, String? account});

const Object _omit = Object();

Dio _dio(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _JsonAdapter(body);
  return dio;
}

final class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

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
      'x-request-id': <String>['11111111-2222-4333-8444-555555555555'],
    },
  );
}
