import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// Decision 0100: the warm-up fills the byte cache under the key the widget
/// itself reads, so the first `launch-detail` visit does not compile `ticket`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('warming an icon caches it under LoopIcon\'s own key', () async {
    svg.cache.clear();
    final loader = SvgAssetLoader(LoopAssetPaths.icon('ticket'));
    final key = loader.cacheKey(null);
    expect(svg.cache.evict(key), isFalse);
    await loopWarmIconCache(names: const <String>['ticket']);
    // Present: evicting it succeeds.
    expect(svg.cache.evict(key), isTrue);
  });

  test('an unknown asset is skipped, not thrown', () async {
    await loopWarmIconCache(names: const <String>['not-an-icon']);
  });
}
