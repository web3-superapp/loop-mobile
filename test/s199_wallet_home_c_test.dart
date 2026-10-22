import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_networth_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const _accessToken = 'privy-access-token';

Map<String, Object?> _body({
  String range = '7d',
  List<Object?>? points,
  Object? change24h = const <String, Object?>{'usd': '12.08', 'pct': '10.4'},
  Object? fiat = const <String, Object?>{
    'currency': 'CNY',
    'rate': '7.1125',
    'amount': '913.27',
  },
}) => <String, Object?>{
  'range': range,
  'points':
      points ??
      <Object?>[
        <String, Object?>{
          'at': '2026-10-08T00:00:00.000Z',
          'netWorthUsd': '106.12',
          'quality': 'fresh',
        },
        <String, Object?>{
          'at': '2026-10-11T00:00:00.000Z',
          'netWorthUsd': '141.90',
          'quality': 'fresh',
        },
        <String, Object?>{
          'at': '2026-10-15T00:00:00.000Z',
          'netWorthUsd': '128.40',
          'quality': 'fresh',
        },
      ],
  'current': <String, Object?>{
    'netWorthUsd': '128.40',
    'at': '2026-10-15T00:00:00.000Z',
    'quality': 'fresh',
  },
  'change24h': change24h,
  'high': <String, Object?>{
    'at': '2026-10-11T00:00:00.000Z',
    'netWorthUsd': '141.90',
  },
  'low': <String, Object?>{
    'at': '2026-10-08T00:00:00.000Z',
    'netWorthUsd': '106.12',
  },
  'fiat': fiat,
  'source': 'loop_networth_snapshots',
  'observedAt': '2026-10-15T00:05:00.000Z',
};

LoopNetWorthHistory _history(
  LoopNetWorthRange range, {
  List<String> values = const <String>['106.12', '141.90', '128.40'],
  LoopNetWorthChangeAvailable? change,
  bool noChange = false,
  LoopNetWorthFiat? fiat,
  bool noFiat = false,
}) => LoopNetWorthHistory(
  range: range,
  points: <LoopNetWorthPoint>[
    for (var index = 0; index < values.length; index++)
      LoopNetWorthPoint(
        at: DateTime.utc(2026, 10, 8 + index),
        netWorthUsd: Decimal.parse(values[index]),
      ),
  ],
  change24h: noChange
      ? null
      : change ??
            LoopNetWorthChangeAvailable(
              usd: Decimal.parse('12.08'),
              pct: Decimal.parse('10.4'),
            ),
  fiat: noFiat
      ? null
      : fiat ??
            LoopNetWorthFiat(
              currency: 'CNY',
              rate: Decimal.parse('7.1125'),
              amount: Decimal.parse('913.27'),
            ),
  source: 'loop_networth_snapshots',
  observedAt: DateTime.utc(2026, 10, 15, 0, 5),
);

/// The history port, answering per window and counting what was asked.
final class _FakeHistory implements WalletNetWorthHistoryGateway {
  _FakeHistory({this.answers = const {}, this.failure});

  final Map<LoopNetWorthRange, LoopNetWorthHistory> answers;
  final LoopChainFailureKind? failure;
  final List<LoopNetWorthRange> requested = <LoopNetWorthRange>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) {
    requested.add(range);
    final kind = failure;
    if (kind != null) {
      return Future<LoopNetWorthHistory>.error(LoopChainException(kind));
    }
    return Future<LoopNetWorthHistory>.value(answers[range] ?? _history(range));
  }
}

/// A history port whose week read lands only when the test says so.
final class _PendingHistory implements WalletNetWorthHistoryGateway {
  final Completer<LoopNetWorthHistory> _week = Completer<LoopNetWorthHistory>();

  void complete(LoopNetWorthHistory history) => _week.complete(history);

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) => _week.future;
}

void main() {
  loopWatchGround();

  Finder key(String value) => find.byKey(ValueKey<String>(value));

  Matcher invalid() => throwsA(
    isA<LoopBackendFailure>().having(
      (failure) => failure.kind,
      'kind',
      LoopBackendFailureKind.invalidPayload,
    ),
  );

  Future<void> pumpWallet(
    WidgetTester tester, {
    WalletNetWorthHistoryGateway? history,
    FakeWalletReadGateway? wallet,
    void Function(String location)? onNavigate,
    LoopV2MetaSnapshot? meta,
  }) => pumpS5Page(
    tester,
    WalletScreen(onNavigate: onNavigate),
    wallet: wallet ?? FakeWalletReadGateway(),
    meta: meta,
    overrides: <Override>[
      if (history != null)
        walletNetWorthHistoryGatewayProvider.overrideWithValue(history),
    ],
  );

  group('codec · GET …/networth/history (lenient)', () {
    LoopNetWorthHistory decode(Object? body, {String range = '7d'}) =>
        DioLoopV2WalletApi.decodeNetWorthHistory(
          body,
          range: LoopNetWorthRange.tryParse(range)!,
        );

    test('a full body decodes every block', () {
      final history = decode(_body());
      expect(history.points.map((point) => point.netWorthUsd), <Decimal>[
        Decimal.parse('106.12'),
        Decimal.parse('141.90'),
        Decimal.parse('128.40'),
      ]);
      expect(history.drawable, isTrue);
      expect(history.change24h!.usd, Decimal.parse('12.08'));
      expect(history.change24h!.pct, Decimal.parse('10.4'));
      expect(history.fiat!.currency, 'CNY');
      expect(history.fiat!.amount, Decimal.parse('913.27'));
      expect(history.high!.netWorthUsd, Decimal.parse('141.90'));
      expect(history.low!.netWorthUsd, Decimal.parse('106.12'));
      expect(history.currentUsd, Decimal.parse('128.40'));
      expect(history.source, 'loop_networth_snapshots');
      expect(history.observedAt, DateTime.utc(2026, 10, 15, 0, 5));
    });

    test('a body without points or change24h, or for another range, is no '
        'history', () {
      expect(() => decode(_body()..remove('points')), invalid());
      expect(() => decode(_body()..remove('change24h')), invalid());
      expect(() => decode(_body(range: '30d')), invalid());
      expect(() => decode(<Object?>[]), invalid());
      expect(decode(_body(points: <Object?>[])).drawable, isFalse);
    });

    test('a malformed point is skipped and a malformed block reads as '
        'absent; unknown keys are ignored', () {
      final history = decode(
        _body(
          points: <Object?>[
            <String, Object?>{'at': 'not a time', 'netWorthUsd': '1'},
            <String, Object?>{'at': '2026-10-09T00:00:00Z', 'netWorthUsd': -3},
            <String, Object?>{'at': '2026-10-10T00:00:00Z', 'netWorthUsd': 7.5},
            'junk',
            <String, Object?>{'at': '2026-10-08T00:00:00Z', 'netWorthUsd': '2'},
          ],
          change24h: const <String, Object?>{'usd': 'x'},
          fiat: const <String, Object?>{'currency': 'cny', 'rate': '7'},
        )..['futureKey'] = true,
      );
      // Sorted oldest first; the JSON number goes through its text form.
      expect(history.points.map((point) => point.netWorthUsd), <Decimal>[
        Decimal.parse('2'),
        Decimal.parse('7.5'),
      ]);
      expect(history.change24h, isNull);
      expect(history.fiat, isNull);
    });

    test('null change24h and fiat are 「暂无」 and no ¥, not a refusal', () {
      final history = decode(_body(change24h: null, fiat: null));
      expect(history.change24h, isNull);
      expect(history.fiat, isNull);
      expect(history.points, hasLength(3));
    });

    test('the request names the wallet and the window, and a 503 fails', () {
      RequestOptions? captured;
      final api = DioLoopV2WalletApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, _body(range: '30d')));
        }),
      );
      return api
          .getNetWorthHistory(
            accessToken: _accessToken,
            clientVersion: s5ClientVersion,
            walletId: s5WalletId,
            range: LoopNetWorthRange.month,
          )
          .then((history) async {
            expect(captured!.method, 'GET');
            expect(captured!.path, '/v2/wallets/$s5WalletId/networth/history');
            expect(captured!.queryParameters, <String, Object?>{
              'range': '30d',
            });
            expect(history.range, LoopNetWorthRange.month);

            final down = DioLoopV2WalletApi(
              s5Dio(
                (options, handler) => handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.badResponse,
                    response: s5Response(options, const <String, Object?>{
                      'error': <String, Object?>{
                        'code': 'CAPABILITY_UNAVAILABLE',
                        'message': 'not yet',
                        'requestId': s5RequestId,
                      },
                    }, statusCode: 503),
                  ),
                ),
              ),
            );
            await expectLater(
              down.getNetWorthHistory(
                accessToken: _accessToken,
                clientVersion: s5ClientVersion,
                walletId: s5WalletId,
                range: LoopNetWorthRange.week,
              ),
              throwsA(isA<LoopBackendFailure>()),
            );
          });
    });
  });

  group('总资产 · 钱包 C header', () {
    testWidgets('the figure carries USD, the ¥ line and 今日盈亏 in rise', (
      tester,
    ) async {
      await pumpWallet(tester, history: _FakeHistory());

      expect(
        tester.widget<Text>(key('wallet-total-figure')).style!.fontSize,
        // Decision 0224: the chrome plate's figure, Anton 40.
        LoopType.plateFigure.fontSize,
      );
      expect(key('wallet-total-unit'), findsOneWidget);
      expect(
        tester.widget<Text>(key('wallet-total-subline')).data,
        startsWith('≈ ¥913.27 · '),
      );
      final pnl = tester.widget<Text>(key('wallet-pnl-value'));
      expect(pnl.data, '+\$12.08 (+10.4%)');
      expect(pnl.style!.color, LoopColors.rise);
    });

    testWidgets('a fall reads in fall; no fiat draws no ¥', (tester) async {
      await pumpWallet(
        tester,
        history: _FakeHistory(
          answers: <LoopNetWorthRange, LoopNetWorthHistory>{
            LoopNetWorthRange.week: _history(
              LoopNetWorthRange.week,
              change: LoopNetWorthChangeAvailable(
                usd: Decimal.parse('-0.14'),
                pct: Decimal.parse('-1.2'),
              ),
              noFiat: true,
            ),
          },
        ),
      );
      final pnl = tester.widget<Text>(key('wallet-pnl-value'));
      expect(pnl.data, '-\$0.14 (-1.2%)');
      expect(pnl.style!.color, LoopColors.fall);
      expect(find.textContaining('¥'), findsNothing);
      expect(key('wallet-total-subline'), findsOneWidget);
    });

    testWidgets('no 24h figure says 暂无, never 0', (tester) async {
      await pumpWallet(
        tester,
        history: _FakeHistory(
          answers: <LoopNetWorthRange, LoopNetWorthHistory>{
            LoopNetWorthRange.week: _history(
              LoopNetWorthRange.week,
              noChange: true,
            ),
          },
        ),
      );
      expect(tester.widget<Text>(key('wallet-pnl-value')).data, '暂无');
      expect(find.textContaining('(+0%)'), findsNothing);
    });

    testWidgets('the sparkline needs two snapshots', (tester) async {
      await pumpWallet(tester, history: _FakeHistory());
      expect(key('wallet-networth-spark'), findsOneWidget);
      expect(
        tester.getSize(key('wallet-networth-spark')),
        WalletNetWorthSpark.size,
      );
    });

    testWidgets('one snapshot draws no sparkline but keeps 今日盈亏', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        history: _FakeHistory(
          answers: <LoopNetWorthRange, LoopNetWorthHistory>{
            LoopNetWorthRange.week: _history(
              LoopNetWorthRange.week,
              values: const <String>['128.40'],
            ),
          },
        ),
      );
      expect(key('wallet-networth-spark'), findsNothing);
      // 今日盈亏 does not need a line to be true.
      expect(key('wallet-pnl-value'), findsOneWidget);
    });

    // Decision 0193: a history read but not drawable keeps the slot.
    for (final values in const <List<String>>[
      <String>[],
      <String>['0'],
    ]) {
      testWidgets('${values.length} snapshot(s) draw the placeholder, which '
          'opens the chart', (tester) async {
        await pumpWallet(
          tester,
          history: _FakeHistory(
            answers: <LoopNetWorthRange, LoopNetWorthHistory>{
              LoopNetWorthRange.week: _history(
                LoopNetWorthRange.week,
                values: values,
              ),
            },
          ),
        );
        final placeholder = key('wallet-networth-spark-placeholder');
        expect(placeholder, findsOneWidget);
        expect(key('wallet-networth-spark'), findsNothing);
        expect(key('wallet-networth-spark-loading'), findsNothing);
        expect(tester.getSize(placeholder), WalletNetWorthSpark.size);
        final text = tester.widget<Text>(
          key('wallet-networth-spark-placeholder-text'),
        );
        expect(text.data, '净值走势 · 记录中');
        expect(text.style!.fontSize, LoopType.captionSm.fontSize);
        final dash = tester.widget<CustomPaint>(
          key('wallet-networth-spark-placeholder-line'),
        );
        expect(
          (dash.painter! as WalletNetWorthDashPainter).color.a,
          closeTo(LoopColors.text3.a, 0.01),
        );

        await tester.tap(placeholder);
        await tester.pumpAndSettle();
        expect(key('wallet-networth-panel'), findsOneWidget);
        expect(key('wallet-networth-spark-placeholder'), findsNothing);
        final empty = tester.widget<LoopInlineUnavailable>(
          key('wallet-networth-chart-empty'),
        );
        expect(empty.message, '这个区间还没有净值记录 · 每小时记一次，有资产后开始画线');
        await tester.tap(key('wallet-networth-collapse'));
        await tester.pumpAndSettle();
        expect(placeholder, findsOneWidget);
      });
    }

    testWidgets('decision 0224: a history zero all the way draws no flat '
        'Yellow rule, a short spray stroke instead', (tester) async {
      await pumpWallet(
        tester,
        history: _FakeHistory(
          answers: <LoopNetWorthRange, LoopNetWorthHistory>{
            LoopNetWorthRange.week: _history(
              LoopNetWorthRange.week,
              values: const <String>['0', '0', '0'],
            ),
          },
        ),
      );
      expect(key('wallet-networth-spark'), findsNothing);
      expect(key('wallet-networth-spark-spray'), findsOneWidget);
      expect(find.byType(LoopSparkline), findsNothing);
    });

    testWidgets('two snapshots draw the line, not the placeholder', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        history: _FakeHistory(
          answers: <LoopNetWorthRange, LoopNetWorthHistory>{
            LoopNetWorthRange.week: _history(
              LoopNetWorthRange.week,
              values: const <String>['1', '2'],
            ),
          },
        ),
      );
      expect(key('wallet-networth-spark'), findsOneWidget);
      expect(key('wallet-networth-spark-placeholder'), findsNothing);
    });

    testWidgets('the placeholder carries no figure, so 隐藏余额 keeps it', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        history: _FakeHistory(
          answers: <LoopNetWorthRange, LoopNetWorthHistory>{
            LoopNetWorthRange.week: _history(
              LoopNetWorthRange.week,
              values: const <String>[],
            ),
          },
        ),
      );
      await tester.tap(key('wallet-eye'));
      await tester.pumpAndSettle();
      expect(key('wallet-networth-spark-placeholder'), findsOneWidget);
      expect(
        tester.widget<Text>(key('wallet-networth-spark-placeholder-text')).data,
        '净值走势 · 记录中',
      );
      await tester.tap(key('wallet-eye'));
      await tester.pumpAndSettle();
    });

    testWidgets('while the week is read the slot is a same-size skeleton', (
      tester,
    ) async {
      final pending = _PendingHistory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletReadGatewayProvider.overrideWithValue(
              FakeWalletReadGateway(),
            ),
            walletNetWorthHistoryGatewayProvider.overrideWithValue(pending),
            loopV2MetaSnapshotProvider.overrideWith(
              (ref) async => s5MetaSnapshot(),
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => LoopToastHost(child: child!),
            home: const WalletScreen(),
          ),
        ),
      );
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final skeleton = key('wallet-networth-spark-loading');
      expect(skeleton, findsOneWidget);
      expect(tester.getSize(skeleton), WalletNetWorthSpark.size);
      expect(
        find.descendant(of: skeleton, matching: find.byType(LoopSkeletonBlock)),
        findsOneWidget,
      );
      expect(key('wallet-networth-spark'), findsNothing);
      expect(key('wallet-networth-spark-placeholder'), findsNothing);
      // Let the read land so nothing is left pending.
      pending.complete(_history(LoopNetWorthRange.week));
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(skeleton, findsNothing);
      expect(key('wallet-networth-spark'), findsOneWidget);
    });

    testWidgets('the chevron says 净值走势 closed and 收起 open', (tester) async {
      await pumpWallet(tester, history: _FakeHistory());
      Text label() => tester.widget<Text>(key('wallet-networth-chevron-label'));
      expect(label().data, '净值走势');
      expect(label().style!.fontSize, LoopType.captionSm.fontSize);
      expect(
        tester.getSize(key('wallet-networth-expand')).height,
        LoopTouch.minimum,
      );
      await tester.tap(key('wallet-networth-expand'));
      await tester.pumpAndSettle();
      expect(label().data, '收起');
      expect(
        tester.getSize(key('wallet-networth-collapse')).height,
        LoopTouch.minimum,
      );
      await tester.tap(key('wallet-networth-collapse'));
      await tester.pumpAndSettle();
      expect(label().data, '净值走势');
    });

    testWidgets('the sparkline opens a 200-high Lime chart with its high and '
        'low; ⌃ closes it; the choice outlives the page', (tester) async {
      final visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final history = _FakeHistory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletReadGatewayProvider.overrideWithValue(
              FakeWalletReadGateway(),
            ),
            walletNetWorthHistoryGatewayProvider.overrideWithValue(history),
            loopV2MetaSnapshotProvider.overrideWith(
              (ref) async => s5MetaSnapshot(),
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => LoopToastHost(child: child!),
            home: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, show, _) =>
                  show ? const WalletScreen() : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(key('wallet-networth-panel'), findsNothing);
      expect(key('wallet-networth-expand'), findsOneWidget);

      await tester.tap(key('wallet-networth-spark'));
      await tester.pumpAndSettle();
      expect(key('wallet-networth-panel'), findsOneWidget);
      expect(key('wallet-networth-spark'), findsNothing);
      expect(tester.getSize(key('wallet-networth-chart')).height, 200);
      expect(tester.widget<Text>(key('wallet-networth-high')).data, '\$141.9');
      expect(tester.widget<Text>(key('wallet-networth-low')).data, '\$106.12');
      final high = tester.widget<Text>(key('wallet-networth-high'));
      // Decision 0229: the caption size, 14.
      expect(high.style!.fontSize, 14);
      expect(
        WalletNetWorthChartPainter.washColors().first,
        LoopColors.lime.withValues(alpha: 0.28),
      );
      expect(WalletNetWorthChartPainter.washColors().last.a, 0);
      // Five quiet windows, 7 天 chosen.
      for (final range in LoopNetWorthRange.values) {
        final seg = tester.widget<LoopSeg>(
          key('wallet-networth-range-${range.wireName}'),
        );
        expect(seg.quiet, isTrue);
        expect(seg.selected, range == LoopNetWorthRange.week);
      }
      // The open chart is remembered when the tab comes back.
      visible.value = false;
      await tester.pumpAndSettle();
      visible.value = true;
      await tester.pumpAndSettle();
      expect(key('wallet-networth-panel'), findsOneWidget);

      await tester.tap(key('wallet-networth-collapse'));
      await tester.pumpAndSettle();
      expect(key('wallet-networth-panel'), findsNothing);
      expect(key('wallet-networth-spark'), findsOneWidget);
      // ⌄ opens it too.
      await tester.tap(key('wallet-networth-expand'));
      await tester.pumpAndSettle();
      expect(key('wallet-networth-panel'), findsOneWidget);
      // Collapse again so the run-scoped choice does not leak into others.
      await tester.tap(key('wallet-networth-collapse'));
      await tester.pumpAndSettle();
    });

    testWidgets('a window asks the server once for that window', (
      tester,
    ) async {
      final history = _FakeHistory();
      await pumpWallet(tester, history: history);
      expect(history.requested, <LoopNetWorthRange>[LoopNetWorthRange.week]);

      await tester.tap(key('wallet-networth-expand'));
      await tester.pumpAndSettle();
      await tester.tap(key('wallet-networth-range-30d'));
      await tester.pumpAndSettle();
      expect(history.requested, <LoopNetWorthRange>[
        LoopNetWorthRange.week,
        LoopNetWorthRange.month,
      ]);
      expect(
        tester.widget<LoopSeg>(key('wallet-networth-range-30d')).selected,
        isTrue,
      );
      await tester.tap(key('wallet-networth-range-7d'));
      await tester.pumpAndSettle();
      await tester.tap(key('wallet-networth-range-360d'));
      await tester.pumpAndSettle();
      expect(history.requested, <LoopNetWorthRange>[
        LoopNetWorthRange.week,
        LoopNetWorthRange.month,
        LoopNetWorthRange.year,
      ]);
      await tester.tap(key('wallet-networth-range-7d'));
      await tester.tap(key('wallet-networth-collapse'));
      await tester.pumpAndSettle();
    });

    testWidgets('隐藏余额 masks the total, the ¥, 今日盈亏 and the chart marks', (
      tester,
    ) async {
      await pumpWallet(tester, history: _FakeHistory());
      await tester.tap(key('wallet-eye'));
      await tester.pumpAndSettle();
      await tester.tap(key('wallet-networth-expand'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(key('wallet-total-figure')).data,
        walletMaskedFigure,
      );
      expect(
        tester.widget<Text>(key('wallet-total-subline')).data,
        startsWith('≈ ¥$walletMaskedFigure'),
      );
      expect(
        tester.widget<Text>(key('wallet-pnl-value')).data,
        '$walletMaskedFigure (+10.4%)',
      );
      expect(
        tester.widget<Text>(key('wallet-networth-high')).data,
        walletMaskedFigure,
      );
      expect(
        tester.widget<Text>(key('wallet-networth-low')).data,
        walletMaskedFigure,
      );
      expect(
        tester.widget<Text>(key('wallet-balance-amount-$s5NativeAssetId')).data,
        walletMaskedFigure,
      );
      expect(find.textContaining('913.27'), findsNothing);
      expect(find.textContaining('12.08'), findsNothing);
      await tester.tap(key('wallet-networth-collapse'));
      await tester.tap(key('wallet-eye'));
      await tester.pumpAndSettle();
    });

    testWidgets('a history 503 draws no line and no 今日盈亏; the balances '
        'stay', (tester) async {
      final history = _FakeHistory(failure: LoopChainFailureKind.unavailable);
      await pumpWallet(tester, history: history);

      expect(key('wallet-networth-spark'), findsNothing);
      expect(key('wallet-networth-spark-placeholder'), findsNothing);
      expect(key('wallet-networth-spark-loading'), findsNothing);
      expect(key('wallet-pnl'), findsNothing);
      expect(find.textContaining('¥'), findsNothing);
      expect(find.text('\$6,352.82'), findsOneWidget);
      expect(key('wallet-balance-$s5NativeAssetId'), findsOneWidget);
      expect(key('wallet-asset-list'), findsOneWidget);

      await tester.tap(key('wallet-networth-expand'));
      await tester.pumpAndSettle();
      final line = key('wallet-networth-chart-unavailable');
      expect(line, findsOneWidget);
      // One line, not the chart's 200 points of height.
      expect(tester.getSize(line).height, lessThan(100));
      expect(key('wallet-networth-chart'), findsNothing);
      expect(key('wallet-balance-$s5NativeAssetId'), findsOneWidget);
      await tester.tap(key('wallet-networth-collapse'));
      await tester.pumpAndSettle();
    });

    testWidgets('without a history port there is no chevron at all', (
      tester,
    ) async {
      await pumpWallet(tester);
      expect(key('wallet-networth-expand'), findsNothing);
      expect(key('wallet-networth-spark'), findsNothing);
      expect(key('wallet-pnl'), findsNothing);
    });
  });

  group('持仓分布', () {
    LoopAssetBalanceRow wbnb({LoopValuation? valuation}) => s5Row(
      assetId: s5WbnbAssetId,
      valuation:
          valuation ??
          LoopValuationAvailable(
            priceSource: LoopFactSource.dexscreener,
            fetchedAt: DateTime.utc(2026, 9, 8, 7, 52),
            quality: LoopFactQuality.fresh,
            reasonCode: null,
            proxyAsset: null,
            priceUsd: Decimal.parse('142.86'),
            valueUsd: Decimal.parse('1000'),
            change24hPct: null,
          ),
    );

    test('shares follow each valued row; four or more fold into 其它', () {
      final shares = walletHoldingShares(
        s5Balances(rows: <LoopAssetBalanceRow>[s5Row(), wbnb()]),
      )!;
      expect(shares.map((share) => share.label), <String>['BNB', 'WBNB']);
      expect(
        WalletHoldingsDistribution.percentText(shares.first.percent),
        '84%',
      );
      expect(
        WalletHoldingsDistribution.percentText(shares.last.percent),
        '16%',
      );

      // A fourth holding folds into 其它: three named slices at most.
      final folded = walletHoldingShares(
        s5Balances(
          rows: <LoopAssetBalanceRow>[
            s5Row(),
            wbnb(),
            s5Row(assetId: s5UsdtAssetId),
            s5Row(assetId: '$s5UsdtAssetId-x'),
          ],
        ),
      )!;
      expect(folded, hasLength(4));
      expect(folded.last.label, '其它');
      final total = folded.fold<Decimal>(
        Decimal.zero,
        (sum, share) => sum + share.percent,
      );
      expect(total.toDouble(), closeTo(100, 0.001));
    });

    testWidgets('a complete set draws one bar and its legend in a record '
        'card', (tester) async {
      await pumpWallet(
        tester,
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(rows: <LoopAssetBalanceRow>[s5Row(), wbnb()]),
          ),
        ),
      );
      final card = key('wallet-distribution');
      expect(card, findsOneWidget);
      expect(tester.widget(card), isA<LoopRecordCard>());
      expect(
        tester.widget<Text>(key('wallet-distribution-legend-0')).data,
        'BNB 84%',
      );
      expect(
        tester.widget<Text>(key('wallet-distribution-legend-1')).data,
        'WBNB 16%',
      );
      final first = tester.getSize(key('wallet-distribution-segment-0'));
      final second = tester.getSize(key('wallet-distribution-segment-1'));
      expect(first.width / second.width, closeTo(5231.73 / 1000, 0.1));
      expect(
        (tester
                    .widget<DecoratedBox>(key('wallet-distribution-segment-0'))
                    .decoration
                as BoxDecoration)
            .color,
        LoopColors.lime,
      );
    });

    testWidgets('an unpriced holding or a partial total draws no split', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(),
                wbnb(
                  valuation: const LoopValuationUnavailable(
                    'MARKET_PRICE_PROVIDER_NOT_CONFIGURED',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(key('wallet-distribution'), findsNothing);
      expect(key('wallet-balance-$s5WbnbAssetId'), findsOneWidget);
    });
  });

  group('余额 rows', () {
    testWidgets('发送 / 兑换 open their routes, 兑换 from the row\'s asset', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpWallet(
        tester,
        onNavigate: opened.add,
        meta: s5MetaSnapshot(
          sendApprovals: LoopV2CapabilityAvailability.available,
          privySwap: LoopV2CapabilityAvailability.available,
          swapEvidencePending: false,
        ),
      );
      final send = key('wallet-balance-send-$s5NativeAssetId');
      final swap = key('wallet-balance-swap-$s5NativeAssetId');
      expect(tester.widget<LoopSeg>(send).quiet, isTrue);
      expect(tester.widget<LoopSeg>(swap).quiet, isTrue);
      await tester.tap(send);
      await tester.pumpAndSettle();
      await tester.tap(swap);
      await tester.pumpAndSettle();
      expect(opened, <String>[
        '/wallet/send',
        Uri(
          path: '/wallet/swap',
          queryParameters: <String, String>{'from': s5NativeAssetId},
        ).toString(),
      ]);
      expect(Uri.parse(opened.last).queryParameters['from'], s5NativeAssetId);
    });

    testWidgets('a closed gate keeps the chip and opens nothing', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpWallet(tester, onNavigate: opened.add);
      await tester.tap(key('wallet-balance-send-$s5NativeAssetId'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(opened, isEmpty);
      expect(find.textContaining('链上操作'), findsWidgets);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a row without a 24h figure draws no 24 小时 line', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(
                  valuation: LoopValuationAvailable(
                    priceSource: LoopFactSource.dexscreener,
                    fetchedAt: DateTime.utc(2026, 9, 8, 7, 52),
                    quality: LoopFactQuality.fresh,
                    reasonCode: null,
                    proxyAsset: null,
                    priceUsd: Decimal.parse('747.39'),
                    valueUsd: Decimal.parse('5231.73'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(key('wallet-balance-change-$s5NativeAssetId'), findsNothing);
      expect(find.text('24 小时'), findsNothing);
    });

    testWidgets('an unread row keeps its one weak line and no action', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(
                  balance: const LoopBalanceUnavailable('BSC_RPC_UNREACHABLE'),
                  valuation: const LoopValuationUnavailable(
                    'BALANCE_UNAVAILABLE',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        key('wallet-balance-unavailable-$s5NativeAssetId'),
        findsOneWidget,
      );
      expect(key('wallet-balance-send-$s5NativeAssetId'), findsNothing);
      expect(key('wallet-distribution'), findsNothing);
    });
  });

  // Decision 0194: the ≈¥ carries its rate's source and observation time.
  group('≈¥ · rate provenance (0194)', () {
    LoopNetWorthHistory decode(Object? body) =>
        DioLoopV2WalletApi.decodeNetWorthHistory(
          body,
          range: LoopNetWorthRange.week,
        );

    Map<String, Object?> fxBody({String quality = 'fresh'}) =>
        <String, Object?>{
          'currency': 'CNY',
          'rate': '6.6921',
          'amount': '913.27',
          'source': 'ecb',
          'asOf': '2026-10-15',
          'fetchedAt': '2026-10-16T03:20:00.000Z',
          'quality': quality,
        };

    LoopNetWorthFiat fx({
      String source = 'ecb',
      LoopFactQuality? quality = LoopFactQuality.fresh,
      DateTime? fetchedAt,
    }) => LoopNetWorthFiat(
      currency: 'CNY',
      rate: Decimal.parse('6.6921'),
      amount: Decimal.parse('913.27'),
      source: quality == null ? null : source,
      asOf: quality == null ? null : DateTime.utc(2026, 10, 15),
      fetchedAt: quality == null ? null : (fetchedAt ?? DateTime.now()),
      quality: quality,
    );

    _FakeHistory port(LoopNetWorthFiat fiat) => _FakeHistory(
      answers: <LoopNetWorthRange, LoopNetWorthHistory>{
        LoopNetWorthRange.week: _history(LoopNetWorthRange.week, fiat: fiat),
      },
    );

    const freshHead = '人民币按欧洲央行参考汇率 1 USD = 6.6921 CNY（10-15 发布，观察于 ';

    test('the new shape decodes source, publication day, fetch time and '
        'quality', () {
      final fiat = decode(_body(fiat: fxBody())).fiat!;
      expect(fiat.amount, Decimal.parse('913.27'));
      expect(fiat.rate, Decimal.parse('6.6921'));
      expect(fiat.source, 'ecb');
      expect(fiat.asOf, DateTime.utc(2026, 10, 15));
      expect(fiat.fetchedAt, DateTime.utc(2026, 10, 16, 3, 20));
      expect(fiat.quality, LoopFactQuality.fresh);
      expect(fiat.hasProvenance, isTrue);
      expect(fiat.stale, isFalse);

      expect(
        decode(_body(fiat: fxBody(quality: 'stale'))).fiat!.quality,
        LoopFactQuality.stale,
      );
      // A word the client does not know is never read as fresh.
      expect(
        decode(_body(fiat: fxBody(quality: 'derived'))).fiat!.quality,
        LoopFactQuality.stale,
      );
      // A full instant names its UTC day.
      expect(
        decode(_body(fiat: fxBody()..['asOf'] = '2026-10-15T14:00:00Z'))
            .fiat!
            .asOf,
        DateTime.utc(2026, 10, 15),
      );
    });

    test('the old shape, or any provenance key missing or unreadable, still '
        'draws ¥ with no provenance', () {
      final legacy = decode(_body()).fiat!;
      expect(legacy.amount, Decimal.parse('913.27'));
      expect(legacy.hasProvenance, isFalse);
      expect(legacy.source, isNull);
      expect(legacy.quality, isNull);
      for (final missing in const <String>[
        'source',
        'asOf',
        'fetchedAt',
        'quality',
      ]) {
        final fiat = decode(_body(fiat: fxBody()..remove(missing))).fiat!;
        expect(fiat.amount, Decimal.parse('913.27'), reason: missing);
        expect(fiat.hasProvenance, isFalse, reason: missing);
        expect(fiat.source, isNull, reason: missing);
        expect(fiat.asOf, isNull, reason: missing);
        expect(fiat.fetchedAt, isNull, reason: missing);
        expect(fiat.quality, isNull, reason: missing);
      }
      expect(
        decode(_body(fiat: fxBody()..['asOf'] = 'yesterday'))
            .fiat!
            .hasProvenance,
        isFalse,
      );
      expect(walletFxProvenanceText(legacy), isNull);
    });

    test(
      'the sentence: publisher in Chinese, day, local clock, stale tail',
      () {
        final now = DateTime(2026, 10, 16, 12);
        final seen = DateTime(2026, 10, 16, 11, 20);
        expect(
          walletFxProvenanceText(fx(fetchedAt: seen), now: now),
          '人民币按欧洲央行参考汇率 1 USD = 6.6921 CNY（10-15 发布，观察于 11:20）折算',
        );
        expect(
          walletFxProvenanceText(
            fx(fetchedAt: seen, quality: LoopFactQuality.stale),
            now: now,
          ),
          '人民币按欧洲央行参考汇率 1 USD = 6.6921 CNY（10-15 发布，观察于 11:20）折算，数据可能过期',
        );
        // An unknown publisher is 「参考汇率」, never its identifier.
        expect(
          walletFxProvenanceText(
            fx(source: 'boc', fetchedAt: seen),
            now: now,
          ),
          '人民币按参考汇率 1 USD = 6.6921 CNY（10-15 发布，观察于 11:20）折算',
        );
        // Observed on an earlier day: the date comes with the clock.
        expect(
          walletFxProvenanceText(
            fx(fetchedAt: seen),
            now: DateTime(2026, 10, 17, 9),
          ),
          contains('观察于 10-16 11:20）'),
        );
      },
    );

    testWidgets('fresh: the subline is unchanged and (i) says where ¥ came '
        'from', (tester) async {
      final fiat = fx();
      await pumpWallet(tester, history: port(fiat));
      final subline = tester.widget<Text>(key('wallet-total-subline'));
      expect(subline.data, startsWith('≈ ¥913.27 · '));
      expect(key('wallet-total-fiat-stale'), findsNothing);

      await tester.tap(key('wallet-info'));
      await tester.pumpAndSettle();
      final line = tester.widget<Text>(key('wallet-info-fx'));
      expect(line.data, walletFxProvenanceText(fiat));
      expect(line.data, startsWith(freshHead));
      expect(line.data, endsWith('）折算'));
      expect(find.text('ecb'), findsNothing);
      expect(find.textContaining('ecb'), findsNothing);
    });

    testWidgets('stale: the ¥ wears the stale badge and (i) says so', (
      tester,
    ) async {
      final fiat = fx(quality: LoopFactQuality.stale);
      await pumpWallet(tester, history: port(fiat));
      final subline = tester.widget<Text>(key('wallet-total-subline'));
      final plain = subline.textSpan!.toPlainText(includePlaceholders: false);
      expect(plain, startsWith('≈ ¥913.27 · '));
      final badge = tester.widget<LoopBadge>(key('wallet-total-fiat-stale'));
      expect(badge.text, '数据可能过期');
      expect(badge.kind, LoopBadgeKind.down);

      await tester.tap(key('wallet-info'));
      await tester.pumpAndSettle();
      final line = tester.widget<Text>(key('wallet-info-fx'));
      expect(line.data, startsWith(freshHead));
      expect(line.data, endsWith('）折算，数据可能过期'));
    });

    testWidgets('hidden amounts mask the ¥ but keep the stale badge', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        history: port(fx(quality: LoopFactQuality.stale)),
      );
      await tester.tap(key('wallet-eye'));
      await tester.pumpAndSettle();
      final plain = tester
          .widget<Text>(key('wallet-total-subline'))
          .textSpan!
          .toPlainText(includePlaceholders: false);
      expect(plain, startsWith('≈ ¥$walletMaskedFigure · '));
      expect(key('wallet-total-fiat-stale'), findsOneWidget);
      await tester.tap(key('wallet-eye'));
      await tester.pumpAndSettle();
    });

    testWidgets('the old shape draws ¥ and no rate line anywhere', (
      tester,
    ) async {
      await pumpWallet(tester, history: port(fx(quality: null)));
      expect(
        tester.widget<Text>(key('wallet-total-subline')).data,
        startsWith('≈ ¥913.27 · '),
      );
      expect(key('wallet-total-fiat-stale'), findsNothing);
      await tester.tap(key('wallet-networth-expand'));
      await tester.pumpAndSettle();
      // S278 · decision 0236: nothing is printed under the chart.
      expect(key('wallet-networth-provenance'), findsNothing);
      expect(key('wallet-networth-fx-provenance'), findsNothing);
      await tester.tap(key('wallet-networth-collapse'));
      await tester.pumpAndSettle();
      await tester.tap(key('wallet-info'));
      await tester.pumpAndSettle();
      expect(key('wallet-info-sheet'), findsOneWidget);
      expect(key('wallet-info-fx'), findsNothing);
    });

    // S278 · decision 0236 (需求方第 13 条): the two grey lines that stood
    // under the chart are gone; 「关于总资产」 carries the snapshot's source
    // and the rate.
    testWidgets('no line under the chart; (i) says the snapshot and the rate', (
      tester,
    ) async {
      final fiat = fx();
      await pumpWallet(tester, history: port(fiat));
      await tester.tap(key('wallet-networth-expand'));
      await tester.pumpAndSettle();
      expect(key('wallet-networth-provenance'), findsNothing);
      expect(key('wallet-networth-fx-provenance'), findsNothing);
      expect(find.textContaining('净值快照'), findsNothing);
      expect(find.textContaining('人民币按'), findsNothing);
      await tester.tap(key('wallet-info'));
      await tester.pumpAndSettle();
      expect(key('wallet-info-history-source'), findsOneWidget);
      expect(
        tester.widget<Text>(key('wallet-info-history')).data,
        contains('每小时为这个钱包记下的 USD 估值'),
      );
      expect(
        tester.widget<Text>(key('wallet-info-fx')).data,
        walletFxProvenanceText(fiat),
      );
    });
  });
}
