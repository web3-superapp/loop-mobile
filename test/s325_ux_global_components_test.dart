// S325 · decision 0255: the requester's UX review (2026-10-31) — UX-007
// buttons, UX-003 empty states, UX-009 one (i) per page, UX-011 card
// alignment, UX-018 no share bars on the boards.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_entry.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart' show LoopProgressBar;
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s8_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _host(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[child],
          ),
        ),
      ),
    ),
  );
}

/// The painted face of the [LoopButton] keyed [face].
BoxDecoration _face(WidgetTester tester, Finder face) => tester
    .widgetList<Container>(
      find.descendant(of: face, matching: find.byType(Container)),
    )
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .first;

/// Every (i) a page draws: a framed / bare info glyph button, or the
/// compact 「(i) 来源」 trigger.
int _infoEntries(WidgetTester tester) =>
    tester
        .widgetList<LoopIconButton>(find.byType(LoopIconButton))
        .where((button) => button.icon == 'info')
        .length +
    tester.widgetList(find.byType(LoopInfoTrigger)).length;

void main() {
  loopWatchGround();

  group('UX-007 · buttons', () {
    testWidgets('three ranks, one radius', (tester) async {
      await _host(
        tester,
        Column(
          children: <Widget>[
            LoopButton(label: '主', primary: true, onPressed: () {}),
            LoopButton(label: '次', onPressed: () {}),
            LoopButton(label: '辅', assist: true, onPressed: () {}),
          ],
        ),
      );
      final primary = _face(tester, _key('loop-button-primary'));
      final secondary = _face(tester, _key('loop-button-secondary'));
      final assist = _face(tester, _key('loop-button-assist'));
      expect(primary.color, LoopColors.yellow);
      expect(secondary.color, LoopColors.card2);
      expect(assist.color, LoopColors.assistFill);
      for (final face in <BoxDecoration>[primary, secondary, assist]) {
        expect(face.borderRadius, LoopRadius.button);
        expect(face.boxShadow, isNull);
      }
      Color? ink(String word) =>
          tester.widget<Text>(find.text(word)).style?.color;
      expect(ink('主'), LoopColors.ink);
      expect(ink('次'), LoopColors.chalk);
      expect(ink('辅'), LoopColors.text2);
    });

    testWidgets('a compact button is a 32 face in a 44 target', (tester) async {
      var taps = 0;
      await _host(
        tester,
        Center(
          child: LoopButton(
            label: '开启',
            primary: true,
            size: LoopButtonSize.compact,
            onPressed: () => taps += 1,
          ),
        ),
      );
      final face = _key('loop-button-primary');
      expect(tester.getSize(face).height, LoopTouch.compactButton);
      final target = find.ancestor(
        of: face,
        matching: find.byType(GestureDetector),
      );
      expect(tester.getSize(target.first).height, greaterThanOrEqualTo(44));
      // The word sits 12 from each side.
      final word = tester.getRect(find.text('开启'));
      final rect = tester.getRect(face);
      expect(word.left - rect.left, closeTo(12, 0.5));
      await tester.tap(face);
      expect(taps, 1);
    });

    testWidgets('a button beside a notice is compact on its own', (
      tester,
    ) async {
      await _host(
        tester,
        LoopNotice(
          title: '开启推送通知',
          body: '新消息会推送到这台设备。',
          trailing: LoopButton(label: '开启', primary: true, onPressed: () {}),
        ),
      );
      expect(
        tester.getSize(_key('loop-button-primary')).height,
        LoopTouch.compactButton,
      );
    });

    testWidgets('the soft row action is the grey assist button', (
      tester,
    ) async {
      await _host(
        tester,
        Center(
          child: LoopPillAction(label: '生成海报', soft: true, onPressed: () {}),
        ),
      );
      final face = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('生成海报'),
              matching: find.byType(Container),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(face.color, LoopColors.assistFill);
      expect(face.borderRadius, LoopRadius.button);
      expect(
        tester.widget<Text>(find.text('生成海报')).style?.color,
        LoopColors.text2,
      );
    });

    testWidgets('no glowing capsule: 发射 and the wall button', (tester) async {
      await _host(
        tester,
        Column(
          children: <Widget>[
            Launch2LaunchCapsule(onPressed: () {}),
            LoopYellowButton(label: '找朋友', onTap: () {}),
          ],
        ),
      );
      final capsule =
          tester.widget<Container>(_key('launch2-create-capsule')).decoration!
              as BoxDecoration;
      expect(capsule.borderRadius, LoopRadius.button);
      expect(capsule.boxShadow, isNull);
      final wall = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('找朋友'),
              matching: find.byType(Container),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(wall.boxShadow, isNull);
      expect(wall.borderRadius, LoopRadius.button);
    });

    testWidgets('every title-bar control sits on the dark square', (
      tester,
    ) async {
      await _host(
        tester,
        LoopTopbar(
          title: '发起 v2 发射',
          onBack: () {},
          actions: <Widget>[
            LoopIconButton(
              key: const ValueKey<String>('bar-tool'),
              icon: 'search',
              label: '我的项目',
              onPressed: () {},
            ),
          ],
        ),
      );
      for (final key in <String>['loop-topbar-back', 'bar-tool']) {
        final ground = tester
            .widgetList<Container>(
              find.descendant(of: _key(key), matching: find.byType(Container)),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .first;
        expect(ground.borderRadius, LoopRadius.tool, reason: key);
        expect(ground.color, isNotNull, reason: key);
      }
    });

    testWidgets('an off switch keeps the on thumb size', (tester) async {
      await _host(tester, const LoopFlatSwitch(value: false));
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.thumbIcon?.resolve(<WidgetState>{}), isNotNull);
      expect(
        toggle.thumbIcon?.resolve(<WidgetState>{WidgetState.selected}),
        isNotNull,
      );
    });
  });

  group('UX-003 · empty states', () {
    testWidgets('the grey crown, a title and one sentence', (tester) async {
      await _host(
        tester,
        const LoopEmptyState(
          title: '还没有通知',
          message: '代币毕业和好友申请会出现在这里。',
          compact: true,
        ),
      );
      expect(_key('loop-empty-art'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
      expect(tester.widget<Text>(_key('loop-empty-title')).data, '还没有通知');
      expect(
        tester.widget<Text>(_key('loop-empty-message')).data,
        '代币毕业和好友申请会出现在这里。',
      );
      // The crown keeps its own aspect, so nothing around it crops it, and
      // its cut-off foot fades out.
      final art = tester.getSize(_key('loop-empty-art'));
      expect(art.width / art.height, closeTo(LoopEmptyArt.aspect, 0.01));
      expect(
        find.descendant(
          of: _key('loop-empty-art'),
          matching: find.byType(ShaderMask),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a page may put its own drawing in the slot', (tester) async {
      await _host(
        tester,
        const LoopEmptyState(
          title: '暂无',
          art: SizedBox(
            key: ValueKey<String>('own-art'),
            width: 40,
            height: 40,
          ),
          compact: true,
        ),
      );
      expect(_key('own-art'), findsOneWidget);
      expect(_key('loop-empty-art'), findsNothing);
    });

    testWidgets('the wall empty state has the same two lines', (tester) async {
      await _host(
        tester,
        const LoopAtmoEmpty(title: '还没有好友会话', message: '添加好友后会出现在这里。'),
      );
      expect(_key('loop-empty-art'), findsOneWidget);
      expect(tester.widget<Text>(_key('loop-empty-title')).data, '还没有好友会话');
      expect(
        tester.widget<Text>(_key('loop-empty-message')).data,
        '添加好友后会出现在这里。',
      );
    });
  });

  group('UX-009 · one (i) per page, in the bar', () {
    testWidgets('我的挖矿: the header (i) also holds the snapshot source', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              formula: s7EffectiveFormula(),
              snapshot: s7MiningSnapshot(),
            ),
          ),
        ),
      );
      expect(_infoEntries(tester), 1);
      expect(_key('loop-provenance-line'), findsNothing);
      expect(find.text('来源'), findsNothing);
      await tester.tap(_key('mining-rules-action'));
      await tester.pumpAndSettle();
      expect(_key('mining-info-sheet'), findsOneWidget);
      expect(find.text('挖矿说明'), findsOneWidget);
      expect(find.text('LOOP 算力快照'), findsOneWidget);
      expect(find.text('观察于'), findsOneWidget);
    });

    testWidgets('交易历史: the source moved to the bar', (tester) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );
      expect(_infoEntries(tester), 1);
      expect(_key('provenance-footer'), findsNothing);
      expect(_key('loop-page-info-action'), findsOneWidget);
      await tester.tap(_key('loop-page-info-action'));
      await tester.pumpAndSettle();
      expect(_key('loop-provenance-sheet'), findsOneWidget);
    });

    testWidgets('安全中心: no (i) on the rows; the bar (i) holds them all', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(),
      );
      expect(_infoEntries(tester), 1);
      expect(
        find.descendant(
          of: _key('security-approvals-unlimited-info'),
          matching: find.byType(LoopIconButton),
        ),
        findsNothing,
      );
      await tester.tap(_key('loop-page-info-action'));
      await tester.pumpAndSettle();
      expect(_key('loop-provenance-sheet'), findsOneWidget);
      expect(find.textContaining('额度没有上限的授权，风险最高'), findsOneWidget);
      expect(find.textContaining('由 Privy 提供'), findsOneWidget);
      expect(find.textContaining('观察于'), findsWidgets);
    });

    testWidgets('outside a page the block keeps its own (i)', (tester) async {
      await _host(
        tester,
        const LoopProvenanceLine(sources: <String>['LOOP 算力快照']),
      );
      expect(_key('loop-provenance-line'), findsOneWidget);
    });
  });

  group('UX-011 · cards', () {
    testWidgets('a row figure ends on the right edge', (tester) async {
      await _host(
        tester,
        const LoopRecordRow(
          key: ValueKey<String>('row'),
          title: 'XRP',
          subtitle: '0 × 权重 1',
          trailing: '0',
          trailingCaption: '算力',
        ),
      );
      final row = tester.getRect(_key('row'));
      final figure = tester.getRect(find.text('0'));
      final caption = tester.getRect(find.text('算力'));
      expect(row.right - figure.right, lessThanOrEqualTo(LoopSpacing.page + 1));
      expect(figure.right, closeTo(caption.right, 0.5));
    });

    testWidgets('a key-value figure ends on the right edge', (tester) async {
      await _host(
        tester,
        const LoopKeyValue(
          key: ValueKey<String>('kv'),
          label: '权重',
          value: '1',
          padding: EdgeInsets.zero,
        ),
      );
      expect(
        tester.getRect(find.text('1')).right,
        closeTo(tester.getRect(_key('kv')).right, 0.5),
      );
    });

    testWidgets('a held card draws no Purple edge', (tester) async {
      await _host(
        tester,
        LoopRecordCard(
          key: const ValueKey<String>('card'),
          onTap: () {},
          child: const SizedBox(height: 60, child: Text('社区挖矿')),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(_key('card')));
      await tester.pump(const Duration(milliseconds: 200));
      final edges = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: _key('card'),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((box) => box.border != null);
      expect(edges, isEmpty);
      await gesture.up();
    });
  });

  group('UX-018 · boards', () {
    testWidgets('a place shows its figure, no bar', (tester) async {
      await _host(
        tester,
        const IntelRankRow(
          position: 3,
          leading: SizedBox.square(dimension: 40),
          name: '小满',
          caption: '直接邀请',
          figure: '1',
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.byType(LoopProgressBar), findsNothing);
    });
  });
}
