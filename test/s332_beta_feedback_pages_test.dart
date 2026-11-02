import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_gateway.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_mine_screen.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_screen.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s332_beta_feedback.dart';

const _submit = ValueKey<String>('beta-feedback-submit');
const _body = ValueKey<String>('beta-feedback-body-field');

bool _enabled(WidgetTester tester) =>
    tester.widget<LoopButton>(find.byKey(_submit)).onPressed != null;

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(_submit));
  await tester.tap(find.byKey(_submit));
  await tester.pumpAndSettle();
}

void main() {
  group('beta-feedback form', () {
    late FakeBetaFeedbackGateway gateway;
    late FakeBetaFeedbackPicker picker;
    late int done;
    late int openedMine;

    Widget page() => BetaFeedbackScreen(
      origin: s332Origin,
      onOpenMine: () => openedMine++,
      onDone: () => done++,
      onBack: () {},
    );

    setUp(() {
      gateway = FakeBetaFeedbackGateway();
      picker = FakeBetaFeedbackPicker();
      done = 0;
      openedMine = 0;
    });

    testWidgets('an empty or blank body cannot be submitted', (tester) async {
      await pumpS332Page(tester, page(), gateway: gateway, picker: picker);

      expect(
        find.byKey(const ValueKey<String>('beta-feedback-screen')),
        findsOneWidget,
      );
      expect(find.text('Bug'), findsOneWidget);
      expect(find.text('建议'), findsOneWidget);
      expect(find.text('其他'), findsOneWidget);
      expect(_enabled(tester), isFalse);
      expect(find.text('0 / 2000'), findsOneWidget);

      await tester.enterText(find.byKey(_body), '   \n  ');
      await tester.pump();
      expect(_enabled(tester), isFalse);

      await tester.enterText(find.byKey(_body), '闪退');
      await tester.pump();
      expect(_enabled(tester), isTrue);
      expect(find.text('2 / 2000'), findsOneWidget);
    });

    testWidgets('a body over 2000 code points cannot be submitted', (
      tester,
    ) async {
      await pumpS332Page(tester, page(), gateway: gateway, picker: picker);
      await tester.enterText(find.byKey(_body), '字' * 2001);
      await tester.pump();
      expect(_enabled(tester), isFalse);
      expect(find.text('2001 / 2000'), findsOneWidget);
      expect(gateway.calls, isEmpty);
    });

    testWidgets('at most four pictures; a fifth is refused', (tester) async {
      picker.library = <BetaFeedbackPickedImage>[
        s332Picked(),
        s332Picked(),
        s332Picked(),
      ];
      await pumpS332Page(tester, page(), gateway: gateway, picker: picker);

      await tester.tap(
        find.byKey(const ValueKey<String>('beta-feedback-add-library')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-image-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-image-2')),
        findsOneWidget,
      );
      expect(picker.limits, <int>[4]);

      await tester.tap(
        find.byKey(const ValueKey<String>('beta-feedback-add-library')),
      );
      await tester.pumpAndSettle();
      expect(picker.limits, <int>[4, 1]);
      // The picker answered three again: one fits, two are refused.
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-image-3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-image-4')),
        findsNothing,
      );
      expect(find.text('最多 4 张图片'), findsOneWidget);
      // Full: the two add tiles are gone.
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-add-library')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-add-camera')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('beta-feedback-remove-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-image-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-add-camera')),
        findsOneWidget,
      );
    });

    testWidgets('a refused library says so', (tester) async {
      picker.failure = BetaFeedbackPickFailure.permissionDenied;
      await pumpS332Page(tester, page(), gateway: gateway, picker: picker);
      await tester.tap(
        find.byKey(const ValueKey<String>('beta-feedback-add-camera')),
      );
      await tester.pumpAndSettle();
      expect(find.text('没有相机权限'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.tap(
        find.byKey(const ValueKey<String>('beta-feedback-add-library')),
      );
      await tester.pumpAndSettle();
      expect(find.text('没有相册权限'), findsOneWidget);
    });

    testWidgets(
      'uploads each picture in order, then submits their ids with the context',
      (tester) async {
        picker.library = <BetaFeedbackPickedImage>[s332Picked(), s332Picked()];
        picker.photo = s332Picked();
        await pumpS332Page(tester, page(), gateway: gateway, picker: picker);

        await tester.tap(find.text('建议'));
        await tester.tap(
          find.byKey(const ValueKey<String>('beta-feedback-add-library')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('beta-feedback-add-camera')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_body), '  钱包页白屏  ');
        await tester.pump();
        await _tapSubmit(tester);

        expect(gateway.calls, <String>[
          'upload:0',
          'upload:1',
          'upload:2',
          'submit',
        ]);
        final sent = gateway.submissions.single;
        expect(sent.category, BetaFeedbackCategory.suggestion);
        expect(sent.body, '钱包页白屏');
        expect(sent.mediaIds, <String>[
          s332Uuid(0x100),
          s332Uuid(0x101),
          s332Uuid(0x102),
        ]);
        expect(sent.context.toJson(), <String, Object?>{
          'appVersion': '1.0.0',
          'build': '57',
          'platform': 'ios',
          'osVersion': 'iOS 26.1.0',
          'deviceModel': 'iPhone17,1',
          'route': '/meme',
          'locale': 'zh-CN',
        });
        expect(find.text('已提交'), findsOneWidget);
        expect(done, 1);
      },
    );

    testWidgets('the environment block shows what will be sent', (
      tester,
    ) async {
      await pumpS332Page(tester, page(), gateway: gateway, picker: picker);
      String value(String label) => tester
          .widget<Text>(
            find.byKey(ValueKey<String>('beta-feedback-environment-$label')),
          )
          .data!;
      expect(value('版本'), '1.0.0 (57)');
      expect(value('设备'), 'iPhone17,1');
      expect(value('系统'), 'iOS 26.1.0');
      expect(value('页面'), '/meme');
      expect(value('语言'), 'zh-CN');
    });

    testWidgets('while the environment is read it is a skeleton', (
      tester,
    ) async {
      await pumpS332Page(
        tester,
        page(),
        gateway: gateway,
        picker: picker,
        environment: _PendingEnvironment(),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-environment-loading')),
        findsOneWidget,
      );
    });

    testWidgets(
      'a failed send keeps the form; the retry uploads nothing again',
      (tester) async {
        picker.library = <BetaFeedbackPickedImage>[s332Picked()];
        gateway.submitFailure = LoopChainFailureKind.offline;
        await pumpS332Page(tester, page(), gateway: gateway, picker: picker);

        await tester.tap(
          find.byKey(const ValueKey<String>('beta-feedback-add-library')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_body), '闪退');
        await tester.pump();
        await _tapSubmit(tester);

        expect(gateway.calls, <String>['upload:0', 'submit']);
        expect(
          find.byKey(const ValueKey<String>('beta-feedback-error')),
          findsOneWidget,
        );
        expect(find.text('网络不可用，反馈没有提交。'), findsOneWidget);
        expect(find.text('没有提交'), findsWidgets);
        expect(done, 0);
        expect(find.text('闪退'), findsOneWidget);

        gateway.submitFailure = null;
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await _tapSubmit(tester);
        expect(gateway.calls, <String>['upload:0', 'submit', 'submit']);
        expect(
          gateway.submissions.last.mediaIds,
          gateway.submissions.first.mediaIds,
        );
        expect(done, 1);
      },
    );

    testWidgets('while sending the button says so and is disabled', (
      tester,
    ) async {
      gateway.submitGate = Completer<void>();
      await pumpS332Page(tester, page(), gateway: gateway, picker: picker);
      await tester.enterText(find.byKey(_body), '卡住了');
      await tester.pump();
      await tester.ensureVisible(find.byKey(_submit));
      await tester.tap(find.byKey(_submit));
      await tester.pump();
      await tester.pump();
      expect(find.text('提交中'), findsOneWidget);
      expect(_enabled(tester), isFalse);
      gateway.submitGate!.complete();
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('with no adapter the whole page is unavailable', (
      tester,
    ) async {
      await pumpS332Page(
        tester,
        page(),
        gateway: const UnavailableBetaFeedbackGateway(),
        picker: picker,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(_body), findsNothing);
    });

    testWidgets('我的反馈 opens from the bar', (tester) async {
      await pumpS332Page(tester, page(), gateway: gateway, picker: picker);
      await tester.tap(
        find.byKey(const ValueKey<String>('beta-feedback-open-mine')),
      );
      expect(openedMine, 1);
      expect(find.bySemanticsLabel('我的反馈'), findsOneWidget);
    });
  });

  group('beta-feedback-mine', () {
    late FakeBetaFeedbackGateway gateway;

    setUp(() {
      gateway = FakeBetaFeedbackGateway();
      debugBetaFeedbackImageProvider = (url) => MemoryImage(s332Png);
    });
    tearDown(() => debugBetaFeedbackImageProvider = null);

    testWidgets('loading is a skeleton', (tester) async {
      gateway.pages = <Future<BetaFeedbackPage> Function()>[
        () => Completer<BetaFeedbackPage>().future,
      ];
      await pumpS332Page(
        tester,
        const BetaFeedbackMineScreen(),
        gateway: gateway,
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-mine-loading')),
        findsOneWidget,
      );
    });

    testWidgets('empty is one line', (tester) async {
      await pumpS332Page(
        tester,
        const BetaFeedbackMineScreen(),
        gateway: gateway,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-mine-empty')),
        findsOneWidget,
      );
      expect(find.text('还没有提交过反馈'), findsOneWidget);
    });

    testWidgets('a failed read offers a retry that reads again', (
      tester,
    ) async {
      gateway.pages = <Future<BetaFeedbackPage> Function()>[
        () => Future<BetaFeedbackPage>.error(
          const LoopChainException(LoopChainFailureKind.readFailed),
        ),
        () => Future<BetaFeedbackPage>.value(
          BetaFeedbackPage(items: <BetaFeedbackItem>[s332Item(1)]),
        ),
      ];
      await pumpS332Page(
        tester,
        const BetaFeedbackMineScreen(),
        gateway: gateway,
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-mine-error')),
        findsOneWidget,
      );
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('第 1 条反馈'), findsOneWidget);
      expect(gateway.listCursors, <String?>[null, null]);
    });

    testWidgets('offline, permission and unavailable each have their block', (
      tester,
    ) async {
      for (final (kind, key) in <(LoopChainFailureKind, String)>[
        (LoopChainFailureKind.offline, 'beta-feedback-mine-offline'),
        (
          LoopChainFailureKind.permissionDenied,
          'beta-feedback-mine-permission',
        ),
        (LoopChainFailureKind.unavailable, 'beta-feedback-mine-unavailable'),
      ]) {
        final failing = FakeBetaFeedbackGateway()
          ..pages = <Future<BetaFeedbackPage> Function()>[
            () => Future<BetaFeedbackPage>.error(LoopChainException(kind)),
          ];
        await pumpS332Page(
          tester,
          BetaFeedbackMineScreen(key: ValueKey<String>(key)),
          gateway: failing,
        );
        expect(find.byKey(ValueKey<String>(key)), findsWidgets, reason: key);
      }
      await pumpS332Page(
        tester,
        const BetaFeedbackMineScreen(),
        gateway: const UnavailableBetaFeedbackGateway(),
      );
      expect(
        find.byKey(const ValueKey<String>('beta-feedback-mine-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('a row shows category, status, time, text and pictures', (
      tester,
    ) async {
      gateway.pages = <Future<BetaFeedbackPage> Function()>[
        () => Future<BetaFeedbackPage>.value(
          BetaFeedbackPage(
            items: <BetaFeedbackItem>[
              s332Item(
                1,
                status: BetaFeedbackStatus.resolved,
                images: <String>[
                  'https://api.example/v2/media/a.webp',
                  'https://api.example/v2/media/b.webp',
                ],
              ),
              s332Item(2, status: BetaFeedbackStatus.wontFix),
            ],
          ),
        ),
      ];
      await pumpS332Page(
        tester,
        const BetaFeedbackMineScreen(),
        gateway: gateway,
      );
      final row = find.byKey(
        ValueKey<String>('beta-feedback-item-${s332Uuid(1)}'),
      );
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Bug')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('已解决')),
        findsOneWidget,
      );
      expect(find.text('第 1 条反馈'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>('beta-feedback-item-${s332Uuid(1)}-image-1'),
        ),
        findsOneWidget,
      );
      expect(find.text('暂不处理'), findsOneWidget);
    });

    testWidgets('the next page is read by its cursor', (tester) async {
      gateway.pages = <Future<BetaFeedbackPage> Function()>[
        () => Future<BetaFeedbackPage>.value(
          BetaFeedbackPage(
            items: <BetaFeedbackItem>[s332Item(1)],
            nextCursor: 'next.page',
          ),
        ),
        () => Future<BetaFeedbackPage>.value(
          BetaFeedbackPage(items: <BetaFeedbackItem>[s332Item(2)]),
        ),
      ];
      await pumpS332Page(
        tester,
        const BetaFeedbackMineScreen(),
        gateway: gateway,
      );
      expect(gateway.listCursors, <String?>[null, 'next.page']);
      expect(find.text('第 2 条反馈'), findsOneWidget);
    });
  });
}

final class _PendingEnvironment implements BetaFeedbackEnvironmentSource {
  @override
  Future<BetaFeedbackEnvironment> read() =>
      Completer<BetaFeedbackEnvironment>().future;
}
