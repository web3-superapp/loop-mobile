import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_environment.dart';

void main() {
  test(
    'dangerous environments and operations remain compile-time disabled',
    () {
      expect(BuildPolicy.appEnvironment, AppEnvironment.development);
      expect(
        BuildPolicy.hyperliquidEnvironment,
        HyperliquidEnvironment.testnet,
      );
      expect(BuildPolicy.mainnetEnabled, isFalse);
      expect(BuildPolicy.withdrawalsEnabled, isFalse);
      expect(BuildPolicy.automatedTradingEnabled, isFalse);
      expect(BuildPolicy.perpetualsEnabled, isFalse);
      expect(BuildPolicy.spotExecutionEnabled, isFalse);
    },
  );
}
