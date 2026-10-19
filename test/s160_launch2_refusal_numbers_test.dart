import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';

import 'support/test_hints.dart';

/// Client decision 0156 §1: the launch2 balance refusals carry the wallet's
/// own figures (loop-api decision 0129 §1) and the failure line says them.
void main() {
  // S237 · decision 0204: these cases pin the testnet / specimen behaviour.
  loopShowTestHints();

  LoopChainException mapped(Map<String, Object?> detailsSafe) =>
      loopChainExceptionForV2(
        LoopBackendFailure(
          LoopBackendFailureKind.unexpected,
          statusCode: 409,
          code: 'INSUFFICIENT_BALANCE',
          detailsSafe: LoopFailureDetails.tryRead(detailsSafe),
        ),
        write: true,
      );

  group('detailsSafe', () {
    test('reads the four balance keys and carries them across', () {
      final failure = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_GAS_INSUFFICIENT',
        'balanceUsd1': '99.5',
        'balanceMeme': '1200',
        'requiredBnb': '0.000412',
        'balanceBnb': '0.0001',
      });
      expect(failure.kind, LoopChainFailureKind.insufficientBalance);
      expect(failure.balanceUsd1, '99.5');
      expect(failure.balanceMeme, '1200');
      expect(failure.requiredBnb, '0.000412');
      expect(failure.balanceBnb, '0.0001');
    });

    test('a bad value drops only its own key', () {
      final details = LoopFailureDetails.tryRead(<String, Object?>{
        'reasonCode': 'LAUNCH2_GAS_INSUFFICIENT',
        'requiredBnb': 0.000412,
        'balanceBnb': '-1',
        'balanceUsd1': '1e3',
        'balanceMeme': '12',
      })!;
      expect(details.reasonCode, 'LAUNCH2_GAS_INSUFFICIENT');
      expect(details.requiredBnb, isNull);
      expect(details.balanceBnb, isNull);
      expect(details.balanceUsd1, isNull);
      expect(details.balanceMeme, '12');
      // A balance alone is still something to show.
      expect(
        LoopFailureDetails.tryRead(<String, Object?>{'balanceBnb': '0.5'})
            ?.balanceBnb,
        '0.5',
      );
    });
  });

  group('failure line', () {
    test('USD1: the server balance wins over the page and the pool max', () {
      final failure = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
        'requiredUsd1': '100',
        'balanceUsd1': '99.5',
      });
      expect(
        launch2ActionFailure(failure, usd1Balance: Decimal.fromInt(7)),
        const Launch2ActionFailure(
          'USD1 余额不足：需要 100 USD1，当前 99.5 USD1',
          topUp: true,
        ),
      );
      final pool = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
        'requiredAmountIn': '100.5',
        'maxAmountIn': '20',
        'balanceUsd1': '20.25',
      });
      expect(
        launch2ActionFailure(pool, maxIsBalance: true).text,
        'USD1 余额不足：需要 100.5 USD1，当前 20.25 USD1',
      );
      // Curve buy: the balance replaces 「最多可付」.
      final curve = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
        'maxAmountIn': '3',
        'balanceUsd1': '3.1',
      });
      expect(
        launch2ActionFailure(curve, requested: Decimal.fromInt(5)).text,
        'USD1 余额不足：需要 5 USD1，当前 3.1 USD1',
      );
    });

    test('USD1 without balanceUsd1 keeps the existing fallbacks', () {
      final failure = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
        'requiredUsd1': '100',
      });
      expect(
        launch2ActionFailure(failure, usd1Balance: Decimal.zero).text,
        'USD1 余额不足：需要 100 USD1，当前 0 USD1',
      );
      final curve = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
        'maxAmountIn': '3',
      });
      expect(
        launch2ActionFailure(curve, requested: Decimal.fromInt(5)).text,
        'USD1 余额不足：需要 5 USD1，最多可付 3 USD1',
      );
    });

    test('MEME: the holding comes from balanceMeme', () {
      final curve = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_MEME_BALANCE_INSUFFICIENT',
        'maxAmountIn': '4',
        'balanceMeme': '4.5',
      });
      expect(
        launch2ActionFailure(
          curve,
          requested: Decimal.fromInt(12),
          ticker: 'PEPE',
        ),
        const Launch2ActionFailure(r'卖出数量超过持有：需要 12 $PEPE，当前持有 4.5 $PEPE'),
      );
      final noBalance = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_MEME_BALANCE_INSUFFICIENT',
        'maxAmountIn': '4',
      });
      expect(
        launch2ActionFailure(
          noBalance,
          requested: Decimal.fromInt(12),
          ticker: 'PEPE',
        ).text,
        r'卖出数量超过持有：需要 12 $PEPE，最多可卖 4 $PEPE',
      );
      final bare = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_MEME_BALANCE_INSUFFICIENT',
      });
      expect(launch2ActionFailure(bare).text, '卖出数量超过持有');
    });

    test('tBNB: the fee ceiling and the wallet, else the old sentence', () {
      final both = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_GAS_INSUFFICIENT',
        'requiredBnb': '0.000412',
        'balanceBnb': '0.0001',
      });
      expect(
        launch2ActionFailure(both),
        const Launch2ActionFailure(
          'tBNB 手续费不足：这笔约需 0.000412 tBNB，钱包有 0.0001 tBNB，充值后再试',
          topUp: true,
        ),
      );
      final none = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_GAS_INSUFFICIENT',
      });
      expect(
        launch2ActionFailure(none),
        Launch2ActionFailure(launch2GasShortText, topUp: true),
      );
      final requiredOnly = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_GAS_INSUFFICIENT',
        'requiredBnb': '0.000412',
      });
      expect(
        launch2ActionFailure(requiredOnly).text,
        'tBNB 手续费不足：这笔约需 0.000412 tBNB，充值后再试',
      );
      final balanceOnly = mapped(<String, Object?>{
        'reasonCode': 'LAUNCH2_GAS_INSUFFICIENT',
        'balanceBnb': '0',
      });
      expect(
        launch2ActionFailure(balanceOnly).text,
        'tBNB 手续费不足：钱包有 0 tBNB，充值后再试',
      );
    });
  });
}
