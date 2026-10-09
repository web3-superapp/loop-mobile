import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/settings/settings_screen.dart';
import 'package:loop_mobile/features/wallet/approval_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';
import 'support/s8_harness.dart';

/// Decision 0126 (S121e): account, profile, settings and wallet second-level
/// pages in the OKX flat voice.
void main() {
  loopWatchGround();

  group('LoopFlat primitives', () {
    testWidgets('a flat row is 56 high, unboxed, 16 title, 40 entry tile', (
      tester,
    ) async {
      await _pumpFlat(
        tester,
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('row'),
              leading: const LoopRowIcon(icon: 'wallet'),
              title: '我的钱包',
              trailing: '1 个已绑定',
              onTap: () {},
            ),
          ],
        ),
      );

      final row = find.byKey(const ValueKey<String>('row'));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
      final title = tester.widget<Text>(find.text('我的钱包'));
      expect(title.style?.fontSize, 16);
      final value = tester.widget<Text>(find.text('1 个已绑定'));
      expect(value.style?.fontSize, 14);
      // No card ground: the only fill under the row is the round glyph
      // tile (decision 0127's `LoopEntryIcon`).
      expect(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color != null &&
                (widget.decoration! as BoxDecoration).shape != BoxShape.circle,
          ),
        ),
        findsNothing,
      );
      final tile = find.descendant(
        of: row,
        matching: find.byType(LoopEntryIcon),
      );
      expect(tester.getSize(tile), const Size(40, 40));
    });

    testWidgets('a flat label is the 17 section title of decision 0127', (
      tester,
    ) async {
      await _pumpFlat(tester, const LoopLabel('账号'));
      final label = tester.widget<Text>(find.text('账号'));
      expect(label.style?.fontSize, LoopType.headingSm.fontSize);
      expect(label.style?.fontWeight, LoopType.headingSm.fontWeight);
    });

    testWidgets('a flat block button is the 52 stadium Lime button', (
      tester,
    ) async {
      await _pumpFlat(
        tester,
        LoopButton(label: '保存', primary: true, block: true, onPressed: () {}),
      );
      expect(tester.getSize(find.byType(LoopButton)).height, 52);
      expect(tester.widget<Text>(find.text('保存')).style?.fontSize, 16);
    });

    testWidgets('an informational notice is one ⓘ line, a warning keeps its '
        'card', (tester) async {
      await _pumpFlat(
        tester,
        const Column(
          children: <Widget>[
            LoopNotice(title: '说明', body: '这是一句话。'),
            LoopNotice(
              title: '只接收这一条网络',
              body: '别的网络会丢失。',
              tone: LoopNoticeTone.warn,
              icon: 'warn',
            ),
          ],
        ),
      );
      final line = tester.widget<Text>(find.text('说明。这是一句话。'));
      expect(line.style?.fontSize, 11);
      expect(
        find.byKey(const ValueKey<String>('loop-notice-warn')),
        findsOneWidget,
      );
    });

    testWidgets('the step dots and the flat field', (tester) async {
      await _pumpFlat(
        tester,
        const Column(
          children: <Widget>[
            LoopStepDots(step: 2, label: '创建钱包'),
            LoopFlatField(label: '用户名', boxed: true, child: Text('cy')),
          ],
        ),
      );
      expect(find.text('创建钱包'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('loop-step-dot-2'))),
        const Size(18, 6),
      );
      expect(
        tester.getSize(find.byType(LoopFlatField)).height,
        greaterThanOrEqualTo(52 + 14),
      );
      expect(tester.widget<Text>(find.text('用户名')).style?.fontSize, 13);
    });
  });

  group('我', () {
    testWidgets('header, four round keys, three sections, the version', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pumpProfile(tester, 'profile', onNavigate: destinations.add);

      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(find.text('PUBLIC PROFILE'), findsNothing);
      final header = find.byKey(
        const ValueKey<String>('profile-identity-card'),
      );
      expect(header, findsOneWidget);
      expect(tester.widget<Text>(find.text('Voyager_7')).style?.fontSize, 18);
      expect(tester.widget<Text>(find.text(_loopId)).style?.fontSize, 13);
      expect(
        find.byKey(const ValueKey<String>('profile-open-edit')),
        findsOneWidget,
      );

      // Four 56 Lime discs, in order, under the header.
      final keys = <String>[
        'profile-share-loop-id',
        'profile-open-scan',
        'profile-open-friends',
        'profile-open-mining-key',
      ];
      double? previous;
      for (final key in keys) {
        final finder = find.byKey(ValueKey<String>(key));
        expect(finder, findsOneWidget, reason: key);
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(tester.getRect(header).bottom));
        if (previous != null) expect(rect.left, greaterThan(previous));
        previous = rect.left;
        final disc = tester.widget<Container>(
          find
              .descendant(
                of: finder,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration! as BoxDecoration).shape ==
                          BoxShape.circle,
                ),
              )
              .first,
        );
        expect(
          (disc.decoration! as BoxDecoration).color,
          LoopColors.lime,
          reason: key,
        );
      }

      expect(_labels(tester), containsAllInOrder(<String>['账号', '资产与挖矿']));
      // 挖矿资产 / 奖励 / 规则 sit under 资产与挖矿.
      final miningTop = tester.getTopLeft(find.text('资产与挖矿')).dy;
      for (final key in <String>[
        'profile-open-mining-assets',
        'profile-open-mining-rewards',
        'profile-open-mining-rules',
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey<String>(key)),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      }
      expect(miningTop, isNotNull);

      final version = find.byKey(const ValueKey<String>('profile-version'));
      await tester.scrollUntilVisible(
        version,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(_labels(tester), contains('设置'));
      final versionText = tester.widget<Text>(
        find.descendant(of: version, matching: find.byType(Text)),
      );
      expect(versionText.style?.fontSize, 11);
      expect(versionText.data, startsWith('LOOP'));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('profile-open-scan')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('profile-open-scan')));
      expect(destinations.last, 'scan');
      _expectCleanCopy(tester);
    });

    for (final (failure, key) in <(ProfileGatewayFailureKind, String)>[
      (ProfileGatewayFailureKind.offline, 'profile-offline'),
      (ProfileGatewayFailureKind.unavailable, 'profile-unavailable'),
      (ProfileGatewayFailureKind.permissionDenied, 'profile-permission'),
      (ProfileGatewayFailureKind.unexpected, 'profile-error'),
    ]) {
      testWidgets('a ${failure.name} read keeps the keys and states $key', (
        tester,
      ) async {
        await _pumpProfile(
          tester,
          'profile',
          gateway: _Profile(failure: ProfileGatewayException(failure)),
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('profile-identity-card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('profile-round-keys')),
          findsOneWidget,
        );
      });
    }

    testWidgets('loading draws a skeleton, never an identity', (tester) async {
      await _pumpProfile(
        tester,
        'profile',
        gateway: _Profile(delay: const Duration(seconds: 1)),
        settle: false,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('profile-loading')),
        findsOneWidget,
      );
      expect(find.text(_loopId), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
  });

  group('资料编辑 / 隐私', () {
    testWidgets('profile-edit: flat fields and a 52 Lime save', (tester) async {
      await _pumpProfile(tester, 'profile-edit');
      for (final key in <String>[
        'profile-edit-alias',
        'profile-edit-bio',
        'profile-edit-loop-id-field',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey<String>(key))).height,
          greaterThanOrEqualTo(52),
          reason: key,
        );
      }
      final label = tester.widget<Text>(find.text('用户名'));
      expect(label.style?.fontSize, 13);
      final save = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('profile-edit-save')),
      );
      expect(save.primary, isTrue);
      expect(save.block, isTrue);
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('profile-edit-save')))
            .height,
        52,
      );
      _expectCleanCopy(tester);
    });

    testWidgets('privacy: three sections of switches, no folio, an ⓘ line', (
      tester,
    ) async {
      await _pumpProfile(tester, 'privacy');
      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(find.text('PRIVACY STATUS'), findsNothing);
      expect(_labels(tester), <String>['身份', '社交', '可见性']);
      expect(find.byType(Switch), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('privacy-visibility-note')),
        findsOneWidget,
      );
      _expectCleanCopy(tester);
    });
  });

  group('设置', () {
    testWidgets('settings: switches for the device toggles, no usage card', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: (_) {}),
        settings: FakeAccountSettingsGateway(),
      );
      final motion = find.byKey(
        const ValueKey<String>('settings-reduce-motion'),
      );
      expect(
        find.descendant(of: motion, matching: find.byType(Switch)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-data-usage-absent')),
        findsNothing,
      );
      _expectCleanCopy(tester);
    });
  });

  group('钱包二级页', () {
    testWidgets('tx-history: OKX record rows, signed amount in rise', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );
      expect(
        find.byKey(const ValueKey<String>('tx-history-folio')),
        findsNothing,
      );
      final amount = tester.widget<Text>(find.text('+1.5'));
      expect(amount.style?.color, LoopColors.rise);
      expect(amount.style?.fontSize, 16);
      // A 36 circle heads the row.
      final mark = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
            (widget.decoration! as BoxDecoration).color == LoopColors.card2,
      );
      expect(tester.getSize(mark.first), const Size(36, 36));
      expect(find.text('没有更早的记录'), findsNothing);
      _expectCleanCopy(tester);
    });

    testWidgets('tx-history: an empty segment is the shared empty state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );
      await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-2')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tx-history-empty')),
          matching: find.byKey(
            const ValueKey<String>('loop-empty-illustration-history'),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('receive: chip, centred code, capsule, 复制 / 分享', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );
      final screen = tester.getRect(find.byType(ReceiveScreen));
      final code = tester.getRect(
        find.byKey(const ValueKey<String>('receive-qr')),
      );
      expect(code.center.dx, moreOrLessEquals(screen.center.dx, epsilon: 1));
      expect(
        find.byKey(const ValueKey<String>('receive-address-capsule')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('receive-copy-address')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('receive-share')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('receive-folio')), findsNothing);
      _expectCleanCopy(tester);
    });

    testWidgets('wallets: the address heads its row under a flat section', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(),
      );
      expect(_labels(tester), containsAll(<String>['嵌入式钱包', '外部钱包']));
      expect(find.text('0x0000…00a1'), findsOneWidget);
      expect(find.byType(LoopFolioPrimary), findsNothing);
      _expectCleanCopy(tester);
    });

    testWidgets('networth: the trend is the shared empty state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetWorthScreen(),
        wallet: FakeWalletReadGateway(),
      );
      final trend = find.byKey(
        const ValueKey<String>('networth-trend-unavailable'),
      );
      await scrollToS5Section(tester, trend);
      expect(tester.widget(trend), isA<LoopEmptyState>());
      _expectCleanCopy(tester);
    });

    testWidgets('networks: the endpoint health is the chain row value', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(),
      );
      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('networks-chain-row')),
      );
      expect(row.trailing, '1 / 1 正常');
      expect(find.byType(LoopFolioPrimary), findsNothing);
    });

    testWidgets('approvals: no English folio, the counts lead', (tester) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(),
      );
      expect(find.text('WALLET APPROVALS'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('approvals-stat-unlimited')),
        findsOneWidget,
      );
      _expectCleanCopy(tester);
    });
  });
}

const String _loopId = 'LOOP-7HJKMNPQ';

/// Words a user must never read on these pages (S121 §3, decision 0126).
const List<String> _bannedCopy = <String>[
  '仅开发环境',
  '还没有接入',
  '还开不了',
  'PUBLIC PROFILE',
  'PRIVACY STATUS',
  'SECURITY POSTURE',
  'NOTIFICATION SUMMARY',
  'LOOP SUPPORT',
  'WALLET APPROVALS',
  'PRODUCT RECORD',
  '没有更多',
];

final RegExp _emoji = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
  unicode: true,
);

void _expectCleanCopy(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data ?? text.textSpan?.toPlainText() ?? '';
    expect(_emoji.hasMatch(data), isFalse, reason: data);
    for (final word in _bannedCopy) {
      expect(data.contains(word), isFalse, reason: '$word in $data');
    }
  }
}

List<String> _labels(WidgetTester tester) => tester
    .widgetList<LoopLabel>(find.byType(LoopLabel))
    .map((label) => label.text)
    .toList(growable: false);

Future<void> _pumpFlat(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        body: LoopFlat(child: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpProfile(
  WidgetTester tester,
  String surfaceId, {
  _Profile? gateway,
  ValueChanged<String>? onNavigate,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileGatewayProvider.overrideWithValue(gateway ?? _Profile()),
        privacyGatewayProvider.overrideWithValue(_Privacy()),
        avatarCatalogGatewayProvider.overrideWithValue(_Avatars()),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: LoopToastHost(
          child: ProfileSurfaceScreen.fromId(
            surfaceId,
            onNavigate: onNavigate ?? (_) {},
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

final class _Profile implements ProfileGateway {
  _Profile({this.failure, this.delay});

  final ProfileGatewayException? failure;
  final Duration? delay;

  @override
  ProfileMode get mode => ProfileMode.production;

  ProfileResource _resource(int version, ProfileValues values) =>
      ProfileResource(
        version: version,
        values: values,
        updatedAt: DateTime.utc(2026, 10, 9),
        loopId: _loopId,
        profileStatus: ProfileStatus.active,
        activatedAt: DateTime.utc(2026, 10, 9),
      );

  @override
  Future<ProfileResource> load() async {
    if (delay case final Duration wait) await Future<void>.delayed(wait);
    if (failure case final ProfileGatewayException error) throw error;
    return _resource(
      1,
      ProfileValues(alias: 'Voyager_7', avatarRef: 'avatar:preset/people-01'),
    );
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async => _resource(expectedVersion + 1, values);
}

final class _Privacy implements PrivacyGateway {
  @override
  PrivacyMode get mode => PrivacyMode.production;

  @override
  Future<PrivacyResource> load() async => PrivacyResource(
    version: 1,
    values: const PrivacyValues(discoverable: true, anonymousMode: false),
    updatedAt: DateTime.utc(2026, 10, 9),
  );

  @override
  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  }) async => PrivacyResource(
    version: expectedVersion + 1,
    values: values,
    updatedAt: DateTime.utc(2026, 10, 9),
  );
}

final class _Avatars implements AvatarCatalogGateway {
  @override
  Future<List<AvatarPreset>> load() async => const <AvatarPreset>[];
}
