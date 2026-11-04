import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/loop_locale.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_locale_store.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show DefaultTranslations;

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';

/// Decision 0281: English by default, 简体中文 on request, kept on the device.
void main() {
  loopWatchGround();

  group('locale store and controller', () {
    test('shared-preferences adapter uses the one loop.locale key', () async {
      final values = <String, String>{};
      final store = SharedPreferencesLoopLocaleStore.forTesting(
        (key) async => values[key],
        (key, value) async => values[key] = value,
      );
      expect(SharedPreferencesLoopLocaleStore.localeKey, 'loop.locale');
      expect(await store.readLocaleTag(), isNull);
      await store.writeLocaleTag('zh-CN');
      expect(values, <String, String>{'loop.locale': 'zh-CN'});
    });

    test(
      'nothing stored, an unknown tag or a failing store is English',
      () async {
        expect(await loadLoopLocale(_MemoryLocaleStore()), LoopL10n.english);
        expect(
          await loadLoopLocale(_MemoryLocaleStore('fr-FR')),
          LoopL10n.english,
        );
        expect(
          await loadLoopLocale(const UnavailableLoopLocaleStore()),
          LoopL10n.english,
        );
        expect(
          await loadLoopLocale(_MemoryLocaleStore('zh-CN')),
          LoopL10n.simplifiedChinese,
        );
      },
    );

    test('bootstrap survives a store that cannot be created', () async {
      final bootstrap = await bootstrapSharedPreferencesLocaleForTesting(
        () => throw StateError('no platform channel'),
      );
      expect(bootstrap.initial, LoopL10n.english);
      expect(bootstrap.store, isA<UnavailableLoopLocaleStore>());
    });

    test(
      'a pick applies at once, is written, and moves LoopL10n.current',
      () async {
        final store = _MemoryLocaleStore();
        final container = ProviderContainer(
          overrides: [loopLocaleStoreProvider.overrideWithValue(store)],
        );
        addTearDown(container.dispose);

        expect(container.read(loopLocaleProvider), LoopL10n.english);
        expect(LoopL10n.current.common_language, 'Language');

        await container
            .read(loopLocaleProvider.notifier)
            .setLocale(LoopL10n.simplifiedChinese);
        expect(container.read(loopLocaleProvider), LoopL10n.simplifiedChinese);
        expect(store.tag, 'zh-CN');
        expect(LoopL10n.current.common_language, '语言');
      },
    );

    test('a failed write keeps the pick for this run', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(loopLocaleProvider.notifier)
          .setLocale(LoopL10n.simplifiedChinese);
      expect(container.read(loopLocaleProvider), LoopL10n.simplifiedChinese);
    });
  });

  test('the Stream delegate answers every locale', () {
    const delegate = LoopStreamChatLocalizationsDelegate();
    expect(delegate.isSupported(const Locale('en')), isTrue);
    expect(delegate.isSupported(const Locale('zh', 'CN')), isTrue);
  });

  test(
    'Stream loads LOOP Chinese for zh and the SDK English otherwise',
    () async {
      const delegate = LoopStreamChatLocalizationsDelegate();
      final zh = await delegate.load(const Locale('zh', 'CN'));
      final en = await delegate.load(const Locale('en'));
      expect(zh, isA<LoopStreamChatLocalizations>());
      expect(en.retryLabel, DefaultTranslations.instance.retryLabel);
      expect(
        en.threadReplyCountText(2),
        DefaultTranslations.instance.threadReplyCountText(2),
      );
    },
  );

  testWidgets('a bare MaterialApp still reads copy through context.l10n', (
    tester,
  ) async {
    late String label;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            label = context.l10n.common_language;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(label, 'Language');
  });

  testWidgets('the app opens in English with English system controls', (
    tester,
  ) async {
    await _pumpSettings(tester);
    final row = find.byKey(const ValueKey<String>('settings-language'));
    expect(row, findsOneWidget);
    expect(Localizations.localeOf(tester.element(row)), LoopL10n.english);
    expect(
      MaterialLocalizations.of(tester.element(row)).pasteButtonLabel,
      'Paste',
    );
    expect(
      find.descendant(of: row, matching: find.text('English')),
      findsOneWidget,
    );
  });

  testWidgets('Language switches to 简体中文 at once and remembers it', (
    tester,
  ) async {
    final store = _MemoryLocaleStore();
    await _pumpSettings(tester, store: store);

    await tester.tap(find.byKey(const ValueKey<String>('settings-language')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('settings-language-sheet')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-language-zh-CN')),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey<String>('settings-language'));
    expect(store.tag, 'zh-CN');
    expect(
      Localizations.localeOf(tester.element(row)),
      LoopL10n.simplifiedChinese,
    );
    expect(
      MaterialLocalizations.of(tester.element(row)).pasteButtonLabel,
      '粘贴',
    );
    expect(find.descendant(of: row, matching: find.text('语言')), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('简体中文')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-language-sheet')),
      findsNothing,
    );
  });

  testWidgets('a stored 简体中文 opens the app in Chinese', (tester) async {
    await _pumpSettings(tester, initial: LoopL10n.simplifiedChinese);
    final row = find.byKey(const ValueKey<String>('settings-language'));
    expect(
      Localizations.localeOf(tester.element(row)),
      LoopL10n.simplifiedChinese,
    );
    expect(LoopL10n.current.common_language, '语言');
  });

  testWidgets(
    'the tab bar and LoopL10n.current copy follow a switch in place',
    (tester) async {
      await _pumpSettings(tester);
      expect(LoopShell.destinationLabels, <String>[
        'Chat',
        'Square',
        'MEME',
        'Intel',
        'Me',
      ]);
      expect(find.text('Reduce motion'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('settings-language')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-language-zh-CN')),
      );
      await tester.pumpAndSettle();

      // Same route, same page: nothing was remounted, the copy repainted.
      expect(
        find.byKey(const ValueKey<String>('settings-language')),
        findsOneWidget,
      );
      expect(find.text('减少动效'), findsOneWidget);
      expect(LoopShell.destinationLabels.first, '聊天');
    },
  );

  testWidgets('LoopLocaleScope repaints a reader of LoopL10n.current', (
    tester,
  ) async {
    Widget app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: LoopL10n.supportedLocales,
      localizationsDelegates: loopLocalizationsDelegates,
      builder: (context, child) => LoopLocaleScope(
        locale: Localizations.localeOf(context),
        child: child!,
      ),
      home: const _CurrentReader(),
    );
    await tester.pumpWidget(app(LoopL10n.english));
    expect(find.text('Language'), findsOneWidget);
    await tester.pumpWidget(app(LoopL10n.simplifiedChinese));
    await tester.pump();
    expect(find.text('语言'), findsOneWidget);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  LoopLocaleStore? store,
  Locale? initial,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        if (store != null) loopLocaleStoreProvider.overrideWithValue(store),
        if (initial != null)
          loopLocaleInitialProvider.overrideWithValue(initial),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();

  final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
  router.go('/profile/settings');
  await tester.pumpAndSettle();
}

class _MemoryLocaleStore implements LoopLocaleStore {
  _MemoryLocaleStore([this.tag]);

  String? tag;

  @override
  Future<String?> readLocaleTag() async => tag;

  @override
  Future<void> writeLocaleTag(String value) async {
    tag = value;
  }
}

class _CurrentReader extends StatelessWidget {
  const _CurrentReader();

  @override
  Widget build(BuildContext context) =>
      Text(LoopL10n.current.common_language, textDirection: TextDirection.ltr);
}
