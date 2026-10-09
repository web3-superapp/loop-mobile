import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/platform/loop_android_sdk.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/social/loop_id_copy.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_dock_bar.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_round_key.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';

/// Decision 0130 · S123c/S123d: touch feedback, pressed states, hit targets,
/// sheet handles, Chinese system controls and the one copy path.
void main() {
  loopWatchGround();

  late List<LoopHaptic> played;
  setUp(() => played = LoopHaptics.debugRecord());
  tearDown(() {
    LoopHaptics.debugPlayer = null;
    LoopAndroidSdk.debugLevel = null;
  });

  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
    theme: LoopTheme.dark,
    locale: loopAppLocale,
    supportedLocales: const <Locale>[loopAppLocale],
    localizationsDelegates: loopLocalizationsDelegates,
    builder: (context, page) => LoopToastHost(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: page!,
      ),
    ),
    home: Scaffold(body: child),
  );

  testWidgets('the five touches map onto the platform haptics', (tester) async {
    final calls = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    LoopHaptics.debugPlayer = null;
    LoopHaptics.selection();
    LoopHaptics.light();
    LoopHaptics.medium();
    LoopHaptics.success();
    LoopHaptics.error();
    await tester.pump();
    expect(calls, <String>[
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.successNotification',
      'HapticFeedbackType.errorNotification',
    ]);
  });

  testWidgets('a pressed control dims and shrinks, and keeps the dim when '
      'motion is reduced', (tester) async {
    var taps = 0;
    Future<void> mount({required bool reduceMotion}) => tester.pumpWidget(
      host(
        Center(
          child: LoopPressable(
            key: const ValueKey<String>('pressable'),
            haptic: LoopHaptic.light,
            onTap: () => taps += 1,
            child: const SizedBox(width: 80, height: 44),
          ),
        ),
        reduceMotion: reduceMotion,
      ),
    );

    await mount(reduceMotion: false);
    final target = find.byKey(const ValueKey<String>('pressable'));
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(kPressTimeout);
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      LoopMotion.pressOpacity,
    );
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      LoopMotion.pressScale,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(played, <LoopHaptic>[LoopHaptic.light]);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );

    await mount(reduceMotion: true);
    final held = await tester.startGesture(tester.getCenter(target));
    await tester.pump(kPressTimeout);
    await tester.pump();
    expect(find.byType(AnimatedScale), findsNothing);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      LoopMotion.pressOpacity,
    );
    await held.up();
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('the theme presses with a wash, never a ripple', (tester) async {
    expect(LoopTheme.dark.splashFactory, same(NoSplash.splashFactory));
    expect(LoopTheme.dark.highlightColor, LoopColors.pressHighlight);
  });

  testWidgets('a tab tap and a tab slide each play one selection', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 400,
              height: 60,
              child: LoopDockBar(
                count: 5,
                selectedIndex: selected,
                onSelect: (index) => setState(() => selected = index),
                cellBuilder: (context, index, cell) => InkWell(
                  key: ValueKey<String>('cell-$index'),
                  onTap: () => setState(() => selected = index),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('cell-2')));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(played, <LoopHaptic>[LoopHaptic.selection]);

    // Re-tapping the selected tab is not a selection.
    await tester.tap(find.byKey(const ValueKey<String>('cell-2')));
    await tester.pumpAndSettle();
    expect(played, hasLength(1));

    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey<String>('cell-2'))),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(played, <LoopHaptic>[LoopHaptic.selection, LoopHaptic.selection]);
  });

  testWidgets('choosing a segment plays a selection; re-choosing does not', (
    tester,
  ) async {
    var chosen = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => LoopSegBar(
            labels: const <String>['0.5%', '1%', '3%'],
            selectedIndex: chosen,
            onSelected: (index) => setState(() => chosen = index),
          ),
        ),
      ),
    );
    await tester.tap(find.text('1%'));
    await tester.pump();
    await tester.tap(find.text('1%'));
    await tester.pump();
    expect(chosen, 1);
    expect(played, <LoopHaptic>[LoopHaptic.selection]);
  });

  testWidgets('the signing exit plays success on a broadcast and error on a '
      'refusal, and nothing for a sheet that opens refused', (tester) async {
    Future<void> sheet(LoopSignSheetState state) => tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: LoopSignSheet(
            state: state,
            facts: const <LoopSignFact>[LoopSignFact('操作', '发送')],
            onConfirm: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await sheet(LoopSignSheetState.simulationFailed);
    expect(played, isEmpty);
    await sheet(LoopSignSheetState.signing);
    await sheet(LoopSignSheetState.complete);
    expect(played, <LoopHaptic>[LoopHaptic.success]);
    await sheet(LoopSignSheetState.signing);
    await sheet(LoopSignSheetState.simulationFailed);
    expect(played, <LoopHaptic>[LoopHaptic.success, LoopHaptic.error]);
  });

  testWidgets('a pull plays one light touch when it is far enough to refresh', (
    tester,
  ) async {
    var refreshed = 0;
    await tester.pumpWidget(
      host(
        loopRefreshable(
          onRefresh: () async => refreshed += 1,
          child: ListView(
            children: const <Widget>[SizedBox(height: 60, child: Text('行'))],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.text('行')));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(played, isEmpty, reason: '还没拉到刷新的位置');
    for (var step = 0; step < 10; step += 1) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
    }
    expect(played, <LoopHaptic>[LoopHaptic.light]);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    expect(played, hasLength(1));
  });

  testWidgets('a copy writes the clipboard, plays light and toasts, except '
      'where Android 13+ confirms it itself', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => LoopCopy.text(context, '0xabc', message: '地址已复制'),
            child: const Text('复制'),
          ),
        ),
      ),
    );

    LoopAndroidSdk.debugLevel = 32;
    await tester.tap(find.text('复制'));
    await tester.pump();
    expect(clipboard, '0xabc');
    expect(played, <LoopHaptic>[LoopHaptic.light]);
    expect(find.text('地址已复制'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    LoopAndroidSdk.debugLevel = 33;
    clipboard = null;
    await tester.tap(find.text('复制'));
    await tester.pump();
    expect(clipboard, '0xabc');
    expect(played, <LoopHaptic>[LoopHaptic.light, LoopHaptic.light]);
    expect(
      find.text('地址已复制'),
      findsNothing,
      reason: 'Android 13+ 自己会弹剪贴板提示，LOOP 不再叠一层',
    );
  });

  testWidgets(
    'a draggable sheet draws a handle and closes on a downward drag',
    (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Column(
              children: <Widget>[
                TextButton(
                  onPressed: () => showLoopSheet<void>(
                    context,
                    builder: (context) =>
                        const SizedBox(height: 200, child: Text('弹层内容')),
                  ),
                  child: const Text('打开'),
                ),
                TextButton(
                  onPressed: () => showLoopSheet<void>(
                    context,
                    isDismissible: false,
                    builder: (context) =>
                        const SizedBox(height: 200, child: Text('不可拖动')),
                  ),
                  child: const Text('打开固定'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final handle = find.byKey(
        const ValueKey<String>('loop-sheet-drag-handle'),
      );
      expect(handle, findsOneWidget);
      expect(tester.getSize(handle), LoopSheet.dragHandleSize);
      await tester.drag(handle, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('弹层内容'), findsNothing);

      await tester.tap(find.text('打开固定'));
      await tester.pumpAndSettle();
      expect(find.text('不可拖动'), findsOneWidget);
      expect(handle, findsNothing, reason: '拖不动的弹层不画把手');
    },
  );

  testWidgets('system controls speak Chinese', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(Localizations.localeOf(captured), loopAppLocale);
    final material = MaterialLocalizations.of(captured);
    expect(material.pasteButtonLabel, '粘贴');
    expect(material.selectAllButtonLabel, '全选');
    expect(CupertinoLocalizationsCheck.paste(captured), '粘贴');
  });

  testWidgets('shared controls meet the tap target guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: Column(
            children: <Widget>[
              LoopRoundKey(icon: 'copy', label: '发送', onPressed: () {}),
              LoopIconButton(icon: 'copy', label: '复制', onPressed: () {}),
              LoopPillAction(label: '关注', onPressed: () {}),
              LoopSeeAll(onPressed: () {}),
              LoopSeg(label: '全部', selected: true, onSelected: () {}),
              LoopIdCopyLine(
                loopId: 'loop_cy',
                style: const TextStyle(color: LoopColors.chalk),
                textKey: const ValueKey<String>('id-text'),
                copyKey: const ValueKey<String>('id-copy'),
              ),
              WalletPowerTag(onTap: () {}),
              WalletZeroBalanceToggle(
                hideZero: true,
                zeroCount: 3,
                onToggle: () {},
              ),
              WalletQuickActions(
                onBlocked: (_) {},
                actions: <WalletQuickAction>[
                  WalletQuickAction(
                    label: '接收',
                    actionKey: const ValueKey<String>('qa-receive'),
                    glyph: (color) => Icon(Icons.add, color: color),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    // Android's own guideline is 48 dp; LOOP's touch token is 44 on both
    // platforms (LoopTouch.minimum, decision 0130 keeps it), so the Android
    // check runs at the project minimum and the iOS check at Apple's 44 pt.
    await expectLater(tester, meetsGuideline(loopAndroidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('id-copy'))),
      const Size(44, 44),
    );
    handle.dispose();
  });

  testWidgets('the wallet round key shows a pressed state', (tester) async {
    await tester.pumpWidget(
      host(
        WalletQuickActions(
          onBlocked: (_) {},
          actions: <WalletQuickAction>[
            WalletQuickAction(
              label: '发送',
              actionKey: const ValueKey<String>('qa-send'),
              glyph: (color) => Icon(Icons.north, color: color),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    final key = find.byKey(const ValueKey<String>('qa-send'));
    expect(tester.widget(key), isA<LoopPressable>());
    final gesture = await tester.startGesture(tester.getCenter(key));
    await tester.pump(kPressTimeout);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(of: key, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      LoopMotion.pressOpacity,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });
}

/// [androidTapTargetGuideline] measured at LOOP's 44 dp touch minimum.
const AccessibilityGuideline loopAndroidTapTargetGuideline =
    MinimumTapTargetGuideline(
      size: Size(LoopTouch.minimum, LoopTouch.minimum),
      link: 'https://support.google.com/accessibility/android/answer/7101858',
    );

/// Reads one Cupertino label so the Cupertino delegate is proven installed.
abstract final class CupertinoLocalizationsCheck {
  static String paste(BuildContext context) =>
      Localizations.of<CupertinoLocalizations>(
        context,
        CupertinoLocalizations,
      )!.pasteButtonLabel;
}
