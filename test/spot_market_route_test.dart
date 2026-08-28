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

  test(
    'builds the canonical full-chart location from the exact Spot index',
    () {
      expect(
        SpotMarketRoute.chartLocation(1035),
        '/market/chart?spotIndex=1035',
      );
    },
  );

  test('rejects a negative Spot index before full-chart navigation', () {
    expect(() => SpotMarketRoute.chartLocation(-1), throwsArgumentError);
  });

  test('parses only one canonical full-chart Spot index', () {
    expect(
      SpotMarketRoute.parseChartSpotIndex(
        Uri.parse('/market/chart?spotIndex=1035'),
      ),
      1035,
    );
    expect(
      SpotMarketRoute.parseChartSpotIndex(
        Uri.parse('/market/chart?spotIndex=0'),
      ),
      0,
    );

    for (final location in <String>[
      '/market/chart',
      '/market/chart?spotIndex=',
      '/market/chart?spotIndex=01',
      '/market/chart?spotIndex=+1',
      '/market/chart?spotIndex=-1',
      '/market/chart?spotIndex=one',
      '/market/chart?spotIndex=1&spotIndex=2',
      '/market/chart?spotIndex=1&source=preview',
      '/market/chart?spotIndex=1#fragment',
      '/market/chart?spotIndex=1&',
      '/market/token?spotIndex=1',
      'https://loop.invalid/market/chart?spotIndex=1',
      '/market/chart?spotIndex=999999999999999999999999999999999999',
    ]) {
      expect(
        SpotMarketRoute.parseChartSpotIndex(Uri.parse(location)),
        isNull,
        reason: location,
      );
    }
  });
}
