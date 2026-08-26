import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/spot_market_route.dart';

void main() {
  test(
    'builds the canonical detail location from a non-negative Spot index',
    () {
      expect(SpotMarketRoute.location(1035), '/market/token?spotIndex=1035');
    },
  );

  test('rejects a negative Spot index before navigation', () {
    expect(() => SpotMarketRoute.location(-1), throwsArgumentError);
  });
}
