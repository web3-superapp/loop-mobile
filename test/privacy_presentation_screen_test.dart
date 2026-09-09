import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/integrations/personalization/memory_privacy_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

const _stateKeys = <String>[
  'privacy-loading',
  'privacy-offline',
  'privacy-unavailable',
  'privacy-empty',
  'privacy-permission',
  'privacy-error',
];

const _controlKeys = <String>[
  'privacy-anonymous-mode',
  'privacy-discoverable',
  'privacy-visibility-totalAssets',
  'privacy-visibility-miningPower',
  'privacy-visibility-communities',
  'privacy-visibility-tradeHistory',
];

void main() {
  testWidgets(
    'production Privacy fails closed without controls or preview claims',
    (tester) async {
      await _pumpPrivacy(tester);

      _expectOnlyState(tester, 'privacy-unavailable');
      for (final key in _controlKeys) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing);
      }
      // The primary action exists but can commit nothing.
      expect(_saveButton(tester).onPressed, isNull);
      expect(
        find.byKey(const ValueKey<String>('privacy-conflict')),
        findsNothing,
      );
      expect(find.textContaining('copy'), findsNothing);
      expect(find.textContaining('Copy'), findsNothing);
      expect(find.textContaining('跟单'), findsNothing);
    },
  );

  testWidgets('a pending load shows only the loading state', (tester) async {
    final gate = Completer<PrivacyResource>();
    addTearDown(() => gate.complete(PrivacyResource.empty()));
    await _pumpPrivacy(
      tester,
      gateway: _StubPrivacyGateway(onLoad: () => gate.future),
      settle: false,
    );

    _expectOnlyState(tester, 'privacy-loading');
    for (final key in _controlKeys) {
      expect(find.byKey(ValueKey<String>(key)), findsNothing);
    }
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('every load failure maps to one honest state, never empty', (
    tester,
  ) async {
    const expected = <PrivacyGatewayFailureKind, String>{
      PrivacyGatewayFailureKind.unavailable: 'privacy-unavailable',
      PrivacyGatewayFailureKind.offline: 'privacy-offline',
      // A refusal the server issued is its own state: it is neither a fault
      // the page can retry nor an absent capability.
      PrivacyGatewayFailureKind.permissionDenied: 'privacy-permission',
      PrivacyGatewayFailureKind.stepUpRequired: 'privacy-permission',
      PrivacyGatewayFailureKind.versionConflict: 'privacy-error',
      PrivacyGatewayFailureKind.bootstrapRequired: 'privacy-error',
      PrivacyGatewayFailureKind.validationFailed: 'privacy-error',
      PrivacyGatewayFailureKind.invalidData: 'privacy-error',
      PrivacyGatewayFailureKind.unexpected: 'privacy-error',
    };
    expect(expected.length, PrivacyGatewayFailureKind.values.length);

    var scope = 0;
    for (final entry in expected.entries) {
      await _pumpPrivacy(
        tester,
        scopeId: 'failure-${scope++}',
        gateway: _StubPrivacyGateway(
          onLoad: () async => throw PrivacyGatewayException(entry.key),
        ),
      );

      _expectOnlyState(tester, entry.value);
      // A failed load never degrades into a neutral "nothing here" screen and
      // never leaves an editable draft behind.
      expect(find.byKey(const ValueKey<String>('privacy-empty')), findsNothing);
      for (final key in _controlKeys) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing);
      }
      expect(_saveButton(tester).onPressed, isNull);
    }
  });

  testWidgets('Preview edits anonymous mode and one facet, then saves once', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpPrivacy(tester, gateway: gateway);

    for (final key in _stateKeys) {
      expect(find.byKey(ValueKey<String>(key)), findsNothing);
    }
    for (final key in _controlKeys) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }
    expect(_toggle(tester, 'privacy-anonymous-mode').value, isFalse);
    expect(_toggle(tester, 'privacy-discoverable').value, isFalse);
    for (final facet in PrivacyVisibilityFacet.values) {
      expect(
        _toggle(tester, 'privacy-visibility-${facet.wireValue}').value,
        isFalse,
      );
    }
    // Nothing is dirty yet, so the primary action commits nothing.
    expect(_saveButton(tester).onPressed, isNull);

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('privacy-anonymous-mode')),
    );
    await _tap(
      tester,
      find.byKey(const ValueKey<String>('privacy-visibility-totalAssets')),
    );

    expect(_toggle(tester, 'privacy-anonymous-mode').value, isTrue);
    expect(_toggle(tester, 'privacy-visibility-totalAssets').value, isTrue);
    expect(_toggle(tester, 'privacy-visibility-tradeHistory').value, isFalse);
    expect(_saveButton(tester).onPressed, isNotNull);

    await _tap(tester, find.byKey(const ValueKey<String>('privacy-save')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final committed = await gateway.load();
    expect(committed.version, 2);
    expect(
      committed.values,
      PrivacyValues(
        discoverable: false,
        anonymousMode: true,
        visibility: PrivacyVisibility(totalAssets: PrivacyAudience.everyone),
      ),
    );
    // A saved draft is clean again, so the action cannot resubmit.
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('version conflict preserves every draft field until reload', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpPrivacy(tester, gateway: gateway);

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('privacy-discoverable')),
    );
    await _tap(
      tester,
      find.byKey(const ValueKey<String>('privacy-visibility-tradeHistory')),
    );
    await gateway.replace(
      expectedVersion: 1,
      values: PrivacyValues(
        discoverable: false,
        anonymousMode: true,
        visibility: PrivacyVisibility(miningPower: PrivacyAudience.everyone),
      ),
    );

    await _tap(tester, find.byKey(const ValueKey<String>('privacy-save')));

    expect(
      find.byKey(const ValueKey<String>('privacy-conflict')),
      findsOneWidget,
    );
    // The local draft is still on screen and still frozen.
    expect(_toggle(tester, 'privacy-discoverable').value, isTrue);
    expect(_toggle(tester, 'privacy-visibility-tradeHistory').value, isTrue);
    expect(_toggle(tester, 'privacy-anonymous-mode').value, isFalse);
    expect(_saveButton(tester).onPressed, isNull);
    for (final key in _controlKeys) {
      expect(_toggle(tester, key).onChanged, isNull);
    }

    await _tap(tester, find.text('重新载入'));

    expect(
      find.byKey(const ValueKey<String>('privacy-conflict')),
      findsNothing,
    );
    expect(_toggle(tester, 'privacy-anonymous-mode').value, isTrue);
    expect(_toggle(tester, 'privacy-visibility-miningPower').value, isTrue);
    expect(_toggle(tester, 'privacy-discoverable').value, isFalse);
    expect(_toggle(tester, 'privacy-visibility-tradeHistory').value, isFalse);
    expect(_toggle(tester, 'privacy-anonymous-mode').onChanged, isNotNull);
  });

  testWidgets('mounted Privacy replaces the old owner after gateway rotation', (
    tester,
  ) async {
    final first = MemoryPrivacyGateway(
      initialResource: PrivacyResource(
        version: 3,
        values: PrivacyValues(
          discoverable: true,
          anonymousMode: false,
          visibility: PrivacyVisibility(totalAssets: PrivacyAudience.everyone),
        ),
        updatedAt: DateTime.utc(2026, 8, 25, 9),
      ),
    );
    final second = MemoryPrivacyGateway(
      initialResource: PrivacyResource(
        version: 7,
        values: PrivacyValues(
          discoverable: false,
          anonymousMode: true,
          visibility: PrivacyVisibility(tradeHistory: PrivacyAudience.everyone),
        ),
        updatedAt: DateTime.utc(2026, 8, 25, 10),
      ),
    );

    await _pumpPrivacy(tester, gateway: first);
    expect(_toggle(tester, 'privacy-discoverable').value, isTrue);
    expect(_toggle(tester, 'privacy-visibility-totalAssets').value, isTrue);
    expect(_toggle(tester, 'privacy-anonymous-mode').value, isFalse);

    await _pumpPrivacy(tester, gateway: second);
    expect(_toggle(tester, 'privacy-discoverable').value, isFalse);
    expect(_toggle(tester, 'privacy-visibility-totalAssets').value, isFalse);
    expect(_toggle(tester, 'privacy-anonymous-mode').value, isTrue);
    expect(_toggle(tester, 'privacy-visibility-tradeHistory').value, isTrue);
    for (final key in _stateKeys) {
      expect(find.byKey(ValueKey<String>(key)), findsNothing);
    }
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

    for (final key in _controlKeys) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }
    expect(find.byKey(const ValueKey<String>('privacy-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy copy-trade controls and permission saves are absent', (
    tester,
  ) async {
    await _pumpPrivacy(tester, gateway: _previewGateway());

    for (final legacyText in <String>[
      'You decide what leaves',
      'Portfolio Broadcast',
      'Allowed groups',
      'Visibility matrix',
      'Open positions',
      'ETH Research',
      'Perp Desk',
      'Solana Builders',
      'COPY PUBLIC',
      'Copy trading',
    ]) {
      expect(find.text(legacyText), findsNothing);
    }
    for (final retiredKey in <String>[
      'privacy-visibility-private',
      'privacy-visibility-followers',
      'privacy-visibility-public',
      'privacy-visibility-copyTrade',
      'privacy-apply',
    ]) {
      expect(find.byKey(ValueKey<String>(retiredKey)), findsNothing);
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
  String? scopeId,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      key: scopeId == null ? null : ValueKey<String>(scopeId),
      overrides: [
        privacyGatewayProvider.overrideWithValue(
          gateway ?? const UnavailablePrivacyGateway(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: LoopToastHost(child: child!),
        ),
        home: ProfileSurfaceScreen.fromId(surfaceId),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectOnlyState(WidgetTester tester, String expectedKey) {
  for (final key in _stateKeys) {
    expect(
      find.byKey(ValueKey<String>(key)),
      key == expectedKey ? findsOneWidget : findsNothing,
      reason: 'state block $key',
    );
  }
}

LoopTogglePreferenceRow _toggle(WidgetTester tester, String key) =>
    tester.widget<LoopTogglePreferenceRow>(find.byKey(ValueKey<String>(key)));

LoopButton _saveButton(WidgetTester tester) => tester.widget<LoopButton>(
  find.byKey(const ValueKey<String>('privacy-save')),
);

MemoryPrivacyGateway _previewGateway() => MemoryPrivacyGateway(
  initialResource: PrivacyResource(
    version: 1,
    values: const PrivacyValues.defaults(),
    updatedAt: DateTime.utc(2026, 8, 25),
  ),
  clock: () => DateTime.utc(2026, 8, 25, 12),
);

final class _StubPrivacyGateway implements PrivacyGateway {
  _StubPrivacyGateway({required this.onLoad});

  @override
  PrivacyMode get mode => PrivacyMode.preview;

  final Future<PrivacyResource> Function() onLoad;

  @override
  Future<PrivacyResource> load() => onLoad();

  @override
  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  }) => Future<PrivacyResource>.error(
    const PrivacyGatewayException(PrivacyGatewayFailureKind.unavailable),
  );
}
