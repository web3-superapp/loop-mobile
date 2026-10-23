import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';

import 'support/launch2_fixtures.dart';

// ---------------------------------------------------------------------------
// S152 · official-pool user trades apart from buybacks (client decision 0150)
// ---------------------------------------------------------------------------
//
// `test/fixtures/s152-launch2/pool_user_trades.json` is handwritten from
// loop-api S151-api (Decision 0127) at 66b04fa; it carries `_handwritten`.

Map<String, Object?> _pool() =>
    (jsonDecode(
          File('test/fixtures/s152-launch2/pool_user_trades.json')
              .readAsStringSync(),
        ) as Map<String, Object?>)['pool']!
        as Map<String, Object?>;

Matcher get _invalid => throwsA(
  isA<LoopBackendFailure>().having(
    (e) => e.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

Map<String, Object?> _legacy() => Map<String, Object?>.of(_pool())
  ..remove('userTradeCount')
  ..remove('userBuyVolumeUsd1')
  ..remove('userSellVolumeUsd1');

void main() {
  group('codec', () {
    test('S151 pool: the three user keys are read', () {
      final pool = LoopV2Launch2PoolCodec.summary(_pool())!;
      expect(pool.tradeCount, BigInt.from(6));
      expect(pool.userTradeCount, BigInt.from(3));
      expect(pool.userBuyVolumeUsd1, Decimal.parse('50'));
      expect(pool.userSellVolumeUsd1, Decimal.parse('40'));
      expect(pool.buybackTradeCount, BigInt.from(3));
      // The totals keep their meaning.
      expect(pool.buyVolumeUsd1, Decimal.parse('350'));
    });

    test('a server before S151 (all three absent) still reads', () {
      final pool = LoopV2Launch2PoolCodec.summary(_legacy())!;
      expect(pool.userTradeCount, isNull);
      expect(pool.userBuyVolumeUsd1, isNull);
      expect(pool.userSellVolumeUsd1, isNull);
      expect(pool.buybackTradeCount, isNull);
    });

    test('some of the group absent is invalid', () {
      for (final key in <String>[
        'userTradeCount',
        'userBuyVolumeUsd1',
        'userSellVolumeUsd1',
      ]) {
        expect(
          () => LoopV2Launch2PoolCodec.summary(_pool()..remove(key)),
          _invalid,
          reason: key,
        );
      }
    });

    test('a user total above the pool total, a bad value or an unknown key '
        'is invalid', () {
      expect(
        () => LoopV2Launch2PoolCodec.summary(_pool()..['userTradeCount'] = '7'),
        _invalid,
      );
      expect(
        () => LoopV2Launch2PoolCodec.summary(
          _pool()..['userBuyVolumeUsd1'] = '350.1',
        ),
        _invalid,
      );
      expect(
        () => LoopV2Launch2PoolCodec.summary(
          _pool()..['userSellVolumeUsd1'] = '40.000000000000000001',
        ),
        _invalid,
      );
      expect(
        () =>
            LoopV2Launch2PoolCodec.summary(_pool()..['userTradeCount'] = null),
        _invalid,
      );
      expect(
        () => LoopV2Launch2PoolCodec.summary(_pool()..['userTradeCount'] = 3),
        _invalid,
      );
      expect(
        () => LoopV2Launch2PoolCodec.summary(_pool()..['userBuyCount'] = '2'),
        _invalid,
      );
      // Equal to the total is fine (no buyback yet).
      final none = LoopV2Launch2PoolCodec.summary(
        _pool()
          ..['userTradeCount'] = '6'
          ..['userBuyVolumeUsd1'] = '350',
      )!;
      expect(none.buybackTradeCount, BigInt.zero);
    });

    test('the detail decoder takes the S151 pool', () {
      final Launch2InstanceDetail detail = l2Detail(
        stage: 'graduated',
        noNextChange: true,
        pool: _pool(),
      );
      expect(detail.pool!.userTradeCount, BigInt.from(3));
    });
  });
  // S294 · decision 0244 (需求方 2026-10-23 第 07 条): the 信息 tab no
  // longer draws the pool rows (外盘最新价 … 最近成交), so the widget cases of
  // this file (官方池读数) went with Launch2PoolStats. The codec still reads
  // and checks the S151 keys above.
}
