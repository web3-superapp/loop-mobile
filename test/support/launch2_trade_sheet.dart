import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// S285 · decision 0240: the project page's trade panels live in a bottom
/// sheet behind the fixed 买入 / 卖出 bar. Opens it on [sell]'s side.
Future<void> l2OpenTradeSheet(WidgetTester tester, {bool sell = false}) async {
  await tester.tap(
    find.byKey(ValueKey<String>(sell ? 'launch2-bar-sell' : 'launch2-bar-buy')),
  );
  await tester.pumpAndSettle();
}

/// Opens one of the page's tabs (成交 / 信息 / 回购).
Future<void> l2OpenTab(WidgetTester tester, String name) async {
  final tab = find.byKey(ValueKey<String>('launch2-tab-$name'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}
