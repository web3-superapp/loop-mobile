import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/integrations/personalization/memory_privacy_gateway.dart';

void main() {
  testWidgets(
    'production Privacy fails closed without controls or preview claims',
    (tester) async {
      await _pumpPrivacy(tester);

      expect(find.text('Production connection unavailable'), findsOneWidget);
      expect(
        find.text('Privacy preferences are not connected'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No private request was sent'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('privacy-discoverable-switch')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('privacy-visibility-private')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('privacy-apply')), findsNothing);
      expect(find.textContaining('开发预览'), findsNothing);
      expect(find.text('Portfolio Broadcast'), findsNothing);
    },
  );

  testWidgets(
    'Preview edits both exact preferences and commits only advanced evidence',
    (tester) async {
      final gateway = _previewGateway();
      await _pumpPrivacy(tester, gateway: gateway);

      expect(find.text('开发预览 · in-memory Privacy'), findsOneWidget);
      expect(find.text('VERSION 1'), findsOneWidget);
      expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
      expect(_discoverabilitySwitch(tester).value, isFalse);
      expect(_visibilityChip(tester, 'private').selected, isTrue);

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('privacy-discoverable-switch')),
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('privacy-visibility-public')),
      );

      expect(find.text('UNSAVED DRAFT'), findsOneWidget);
      expect(find.text('DISCOVERY PREFERENCE ON'), findsOneWidget);
      expect(find.text('COPY PUBLIC'), findsOneWidget);
      expect(find.text('VERSION 1'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey<String>('privacy-apply')));

      final committed = await gateway.load();
      expect(committed.version, 2);
      expect(
        committed.values,
        const PrivacyValues(
          discoverable: true,
          copyTradeVisibility: CopyTradeVisibility.public,
        ),
      );
      expect(find.text('VERSION 2'), findsOneWidget);
      expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
      expect(find.text('Privacy preferences saved.'), findsNothing);
    },
  );

  testWidgets('version conflict preserves both draft fields until reload', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpPrivacy(tester, gateway: gateway);

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('privacy-discoverable-switch')),
    );
    await _tap(
      tester,
      find.byKey(const ValueKey<String>('privacy-visibility-public')),
    );
    await gateway.replace(
      expectedVersion: 1,
      values: const PrivacyValues(
        discoverable: false,
        copyTradeVisibility: CopyTradeVisibility.followers,
      ),
    );

    await _tap(tester, find.byKey(const ValueKey<String>('privacy-apply')));

    expect(
      find.byKey(const ValueKey<String>('privacy-conflict')),
      findsOneWidget,
    );
    expect(find.text('UNSAVED DRAFT'), findsOneWidget);
    expect(_discoverabilitySwitch(tester).value, isTrue);
    expect(_visibilityChip(tester, 'public').selected, isTrue);
    expect(_filledButton(tester, 'privacy-apply').onPressed, isNull);
    expect(_outlinedButton(tester, 'privacy-discard').onPressed, isNull);

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('privacy-conflict-reload')),
    );

    expect(
      find.byKey(const ValueKey<String>('privacy-conflict')),
      findsNothing,
    );
    expect(find.text('VERSION 2'), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
    expect(_discoverabilitySwitch(tester).value, isFalse);
    expect(_visibilityChip(tester, 'followers').selected, isTrue);
  });

  testWidgets('mounted Privacy replaces the old owner after gateway rotation', (
    tester,
  ) async {
    final first = MemoryPrivacyGateway(
      initialResource: PrivacyResource(
        version: 3,
        values: const PrivacyValues(
          discoverable: true,
          copyTradeVisibility: CopyTradeVisibility.public,
        ),
        updatedAt: DateTime.utc(2026, 8, 25, 9),
      ),
    );
    final second = MemoryPrivacyGateway(
      initialResource: PrivacyResource(
        version: 7,
        values: const PrivacyValues(
          discoverable: false,
          copyTradeVisibility: CopyTradeVisibility.followers,
        ),
        updatedAt: DateTime.utc(2026, 8, 25, 10),
      ),
    );

    await _pumpPrivacy(tester, gateway: first);
    expect(find.text('VERSION 3'), findsOneWidget);
    expect(_discoverabilitySwitch(tester).value, isTrue);
    expect(_visibilityChip(tester, 'public').selected, isTrue);

    await _pumpPrivacy(tester, gateway: second);
    expect(find.text('VERSION 3'), findsNothing);
    expect(find.text('VERSION 7'), findsOneWidget);
    expect(_discoverabilitySwitch(tester).value, isFalse);
    expect(_visibilityChip(tester, 'followers').selected, isTrue);
    expect(find.text('Loading Privacy preferences…'), findsNothing);
  });

  testWidgets('Privacy supports a 390pt screen at 2x Dynamic Type', (
    tester,
  ) async {
    await _pumpPrivacy(
      tester,
      gateway: _previewGateway(),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.byKey(const ValueKey<String>('privacy-discoverable-switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('privacy-visibility-private')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy H3 controls and fake Copy permission save are absent', (
    tester,
  ) async {
    await _pumpPrivacy(tester, gateway: _previewGateway());

    for (final legacyText in <String>[
      'You decide what leaves',
      'Anonymous chat alias',
      'Portfolio Broadcast',
      'Allowed groups',
      'Visibility matrix',
      'Trading activity',
      'Open positions',
      'ETH Research',
      'Perp Desk',
      'Solana Builders',
    ]) {
      expect(find.text(legacyText), findsNothing);
    }

    await _pumpPrivacy(tester, surfaceId: 'copytrade-perms');

    expect(find.text('Copy trading is not connected'), findsOneWidget);
    expect(find.text('No permission can be granted here'), findsOneWidget);
    expect(find.text('Save permissions'), findsNothing);
    expect(find.text('Copy-trade permissions saved.'), findsNothing);
    expect(find.text('Copy trading remains off.'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });
}

Future<void> _pumpPrivacy(
  WidgetTester tester, {
  String surfaceId = 'privacy',
  PrivacyGateway? gateway,
  Size size = const Size(900, 1800),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyGatewayProvider.overrideWithValue(
          gateway ?? const UnavailablePrivacyGateway(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: ProfileSurfaceScreen.fromId(surfaceId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

SwitchListTile _discoverabilitySwitch(WidgetTester tester) =>
    tester.widget<SwitchListTile>(
      find.byKey(const ValueKey<String>('privacy-discoverable-switch')),
    );

ChoiceChip _visibilityChip(WidgetTester tester, String value) =>
    tester.widget<ChoiceChip>(
      find.byKey(ValueKey<String>('privacy-visibility-$value')),
    );

FilledButton _filledButton(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey<String>(key)));

OutlinedButton _outlinedButton(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.byKey(ValueKey<String>(key)));

MemoryPrivacyGateway _previewGateway() => MemoryPrivacyGateway(
  initialResource: PrivacyResource(
    version: 1,
    values: const PrivacyValues.defaults(),
    updatedAt: DateTime.utc(2026, 8, 25),
  ),
  clock: () => DateTime.utc(2026, 8, 25, 12),
);
