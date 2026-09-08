import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/integrations/personalization/memory_profile_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

const _aliasField = ValueKey<String>('profile-edit-alias-field');
const _saveKey = ValueKey<String>('profile-edit-save');
const _conflictKey = ValueKey<String>('profile-edit-conflict');
const _validationKey = ValueKey<String>('profile-edit-validation');

void main() {
  testWidgets('production is honestly unavailable and shows no fixture edit', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      identity: const ProfileIdentity(
        alias: 'Session identity',
        address: 'No wallet connected',
        bio: 'Session-only presentation',
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('profile-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(_aliasField), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('profile-avatar-picker')),
      findsNothing,
    );
    expect(_saveButton(tester).onPressed, isNull);
    expect(find.text('QuietComet'), findsNothing);
    expect(find.text('Session identity'), findsNothing);
    expect(find.text('资料已保存'), findsNothing);
  });

  testWidgets(
    'production Home defaults contain no unlabelled account fixture',
    (tester) async {
      await _pumpProfile(
        tester,
        surfaceId: 'profile',
        identity: const ProfileIdentity(
          alias: 'SessionFallback',
          address: '0x7c4e…9f21',
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('profile-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('profile-identity-card')),
        findsNothing,
      );
      expect(find.text('SessionFallback'), findsNothing);
      expect(find.text('0x7c4e…9f21'), findsNothing);
      expect(find.text('QuietComet'), findsNothing);
      expect(find.textContaining('128'), findsNothing);
    },
  );

  testWidgets('Preview saves exactly one reviewed Alias resource', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpProfile(tester, gateway: gateway);

    expect(find.byKey(_aliasField), findsOneWidget);
    expect(_textField(tester).controller?.text, 'QuietComet');
    // A clean draft cannot be resubmitted.
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(_aliasField), 'NorthSignal');
    await tester.pumpAndSettle();

    expect(_saveButton(tester).onPressed, isNotNull);
    expect(find.byKey(_validationKey), findsNothing);

    await _tap(tester, find.byKey(_saveKey));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final committed = await gateway.load();
    expect(committed.version, 2);
    expect(committed.values.alias, 'NorthSignal');
    expect(committed.values.avatarRef, isNull);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('invalid Unicode Alias remains local and cannot be saved', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpProfile(tester, gateway: gateway);

    await tester.enterText(find.byKey(_aliasField), 'unsafe\u202Ealias');
    await tester.pumpAndSettle();

    expect(find.byKey(_validationKey), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
    // The rejected input never reached the draft or the gateway.
    expect((await gateway.load()).values.alias, 'QuietComet');

    await tester.enterText(find.byKey(_aliasField), 'unsafe\u200Balias');
    await tester.pumpAndSettle();

    expect(find.byKey(_validationKey), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
    expect((await gateway.load()).values.alias, 'QuietComet');
  });

  testWidgets('version conflict preserves the Alias draft until reload', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpProfile(tester, gateway: gateway);

    await tester.enterText(find.byKey(_aliasField), 'LocalDraft');
    await tester.pumpAndSettle();
    await gateway.replace(
      expectedVersion: 1,
      values: ProfileValues(alias: 'RemoteAlias', avatarRef: null),
    );

    await _tap(tester, find.byKey(_saveKey));

    expect(find.byKey(_conflictKey), findsOneWidget);
    expect(_textField(tester).controller?.text, 'LocalDraft');
    expect(find.text('RemoteAlias'), findsNothing);
    // The draft is frozen: nothing can be edited or saved before a reload.
    expect(_saveButton(tester).onPressed, isNull);
    expect(_textField(tester).enabled, isFalse);

    await _tap(tester, find.text('重新载入'));

    expect(find.byKey(_conflictKey), findsNothing);
    expect(_textField(tester).controller?.text, 'RemoteAlias');
    expect(_textField(tester).enabled, isTrue);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets(
    'conflict reload keeps its draft visible through a pending failure',
    (tester) async {
      final gateway = _DelayedConflictReloadProfileGateway();
      await _pumpProfile(tester, gateway: gateway);

      await tester.enterText(find.byKey(_aliasField), 'LocalDraft');
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(_saveKey));

      expect(find.byKey(_conflictKey), findsOneWidget);

      await tester.ensureVisible(find.text('重新载入'));
      await tester.tap(find.text('重新载入'));
      await tester.pump();

      // Reload is in flight: the local draft is still the only thing shown.
      expect(_textField(tester).controller?.text, 'LocalDraft');
      expect(find.byKey(_conflictKey), findsOneWidget);

      gateway.reload.completeError(
        const ProfileGatewayException(ProfileGatewayFailureKind.unavailable),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_conflictKey), findsOneWidget);
      expect(find.textContaining('资料服务当前不可用'), findsOneWidget);
      expect(_textField(tester).controller?.text, 'LocalDraft');
      expect(_saveButton(tester).onPressed, isNull);
    },
  );

  testWidgets('unexpected save failures are sanitized and retryable', (
    tester,
  ) async {
    final gateway = _FailingSaveProfileGateway();
    await _pumpProfile(tester, gateway: gateway);

    await tester.enterText(find.byKey(_aliasField), 'LocalDraft');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(_saveKey));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(gateway.replaceCalls, 1);
    expect(find.textContaining('raw-provider-secret'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    // No success is claimed and the untouched draft can be retried.
    expect(find.text('资料已保存'), findsNothing);
    expect(_textField(tester).controller?.text, 'LocalDraft');
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byKey(_aliasField), 'unsafe\u202Ealias');
    await tester.pumpAndSettle();

    expect(find.byKey(_validationKey), findsOneWidget);
    expect(gateway.replaceCalls, 1);
  });

  testWidgets('Profile Home projects only the loaded saved Alias', (
    tester,
  ) async {
    final gateway = MemoryProfileGateway(
      initialResource: ProfileResource(
        version: 4,
        values: ProfileValues(alias: 'SavedAlias', avatarRef: null),
        updatedAt: DateTime.utc(2026, 8, 25),
      ),
    );
    await _pumpProfile(
      tester,
      surfaceId: 'profile',
      gateway: gateway,
      identity: const ProfileIdentity(
        alias: 'SessionFallback',
        address: '0x7c4e…9f21',
      ),
    );

    final card = find.byKey(const ValueKey<String>('profile-identity-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('SavedAlias')),
      findsOneWidget,
    );
    // The LOOP ID was never loaded, so nothing invents one.
    expect(
      find.descendant(of: card, matching: find.text('LOOP ID 不可读')),
      findsOneWidget,
    );
    expect(find.text('SessionFallback'), findsNothing);
    expect(find.text('0x7c4e…9f21'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('profile-unavailable')),
      findsNothing,
    );
  });

  testWidgets('Profile edit supports a narrow screen at 2x text scale', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      gateway: _previewGateway(),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byKey(_aliasField), findsOneWidget);
    expect(find.byKey(_saveKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mounted Profile reloads after its gateway owner rotates', (
    tester,
  ) async {
    final first = MemoryProfileGateway(
      initialResource: ProfileResource(
        version: 1,
        values: ProfileValues(alias: 'FirstOwner', avatarRef: null),
        updatedAt: DateTime.utc(2026, 8, 25),
      ),
    );
    final second = MemoryProfileGateway(
      initialResource: ProfileResource(
        version: 1,
        values: ProfileValues(alias: 'SecondOwner', avatarRef: null),
        updatedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    await _pumpProfile(tester, gateway: first);
    expect(_textField(tester).controller?.text, 'FirstOwner');

    await _pumpProfile(tester, gateway: second);
    expect(_textField(tester).controller?.text, 'SecondOwner');
    expect(find.byKey(const ValueKey<String>('profile-loading')), findsNothing);
  });
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  String surfaceId = 'profile-edit',
  ProfileGateway? gateway,
  ProfileIdentity identity = const ProfileIdentity(),
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
        if (gateway != null) profileGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: LoopToastHost(child: child!),
        ),
        home: ProfileSurfaceScreen.fromId(surfaceId, identity: identity),
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

LoopButton _saveButton(WidgetTester tester) =>
    tester.widget<LoopButton>(find.byKey(_saveKey));

TextField _textField(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_aliasField));

MemoryProfileGateway _previewGateway() => MemoryProfileGateway(
  initialResource: ProfileResource(
    version: 1,
    values: ProfileValues(alias: 'QuietComet', avatarRef: null),
    updatedAt: DateTime.utc(2026, 8, 25),
  ),
  clock: () => DateTime.utc(2026, 8, 25, 12),
);

final class _FailingSaveProfileGateway implements ProfileGateway {
  var replaceCalls = 0;

  @override
  ProfileMode get mode => ProfileMode.preview;

  @override
  Future<ProfileResource> load() async => ProfileResource(
    version: 1,
    values: ProfileValues(alias: 'QuietComet', avatarRef: null),
    updatedAt: DateTime.utc(2026, 8, 25),
  );

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async {
    replaceCalls += 1;
    throw Exception('raw-provider-secret');
  }
}

final class _DelayedConflictReloadProfileGateway implements ProfileGateway {
  final reload = Completer<ProfileResource>();
  var _loadCalls = 0;

  @override
  ProfileMode get mode => ProfileMode.preview;

  @override
  Future<ProfileResource> load() {
    if (_loadCalls++ == 0) {
      return Future<ProfileResource>.value(
        ProfileResource(
          version: 1,
          values: ProfileValues(alias: 'QuietComet', avatarRef: null),
          updatedAt: DateTime.utc(2026, 8, 25),
        ),
      );
    }
    return reload.future;
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) => Future<ProfileResource>.error(
    const ProfileGatewayException(ProfileGatewayFailureKind.versionConflict),
  );
}
