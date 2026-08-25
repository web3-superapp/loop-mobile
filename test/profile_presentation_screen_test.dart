import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/integrations/personalization/memory_profile_gateway.dart';

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
        connections: 0,
        groups: 0,
        watchlistItems: 0,
      ),
    );

    expect(find.text('Production connection unavailable'), findsOneWidget);
    expect(find.text('Profile editing is not connected'), findsOneWidget);
    expect(find.textContaining('No private request was sent'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-alias-input')), findsNothing);
    expect(find.text('QuietComet'), findsNothing);
    expect(find.textContaining('开发预览'), findsNothing);
    expect(find.text('Profile changes saved.'), findsNothing);
  });

  testWidgets(
    'production Home defaults contain no unlabelled account fixture',
    (tester) async {
      await _pumpProfile(tester, surfaceId: 'profile');

      expect(find.text('Production connection unavailable'), findsOneWidget);
      expect(find.text('Profile unavailable'), findsOneWidget);
      expect(find.text('No wallet connected'), findsOneWidget);
      expect(find.text('QuietComet'), findsNothing);
      expect(find.text('0x7c4e…9f21'), findsNothing);
      expect(find.textContaining('128'), findsNothing);
      expect(find.textContaining('开发预览'), findsNothing);
    },
  );

  testWidgets('Preview is labelled and saves one reviewed Alias resource', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpProfile(tester, gateway: gateway);

    expect(find.text('开发预览 · in-memory Profile'), findsOneWidget);
    expect(find.text('VERSION 1'), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
    expect(find.text('Only Alias is editable here'), findsOneWidget);
    expect(find.text('Bio'), findsNothing);
    expect(find.text('Profile visibility'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('profile-alias-input')),
      'NorthSignal',
    );
    await tester.pumpAndSettle();

    expect(find.text('UNSAVED DRAFT'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('profile-save')));

    expect(find.text('VERSION 2'), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
    expect((await gateway.load()).values.alias, 'NorthSignal');
    expect(find.text('Profile changes saved.'), findsNothing);
  });

  testWidgets('invalid Unicode Alias remains local and cannot be saved', (
    tester,
  ) async {
    await _pumpProfile(tester, gateway: _previewGateway());
    final input = find.byKey(const ValueKey('profile-alias-input'));
    const validation =
        'Use 1–40 visible characters. Control and text-direction override characters are not accepted.';

    await tester.enterText(input, 'A' * 41);
    await tester.pumpAndSettle();

    expect(find.text(validation), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
    expect(_filledButton(tester, 'profile-save').onPressed, isNull);

    await tester.enterText(input, 'unsafe\u202Ealias');
    await tester.pumpAndSettle();

    expect(find.text(validation), findsOneWidget);
    expect(_filledButton(tester, 'profile-save').onPressed, isNull);
  });

  testWidgets('version conflict preserves the Alias draft until reload', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpProfile(tester, gateway: gateway);
    final input = find.byKey(const ValueKey('profile-alias-input'));

    await tester.enterText(input, 'LocalDraft');
    await tester.pumpAndSettle();
    await gateway.replace(
      expectedVersion: 1,
      values: ProfileValues(alias: 'RemoteAlias', avatarRef: null),
    );

    await _tap(tester, find.byKey(const ValueKey('profile-save')));

    expect(find.byKey(const ValueKey('profile-conflict')), findsOneWidget);
    expect(find.text('UNSAVED DRAFT'), findsOneWidget);
    expect(_textField(tester).controller?.text, 'LocalDraft');
    expect(find.text('RemoteAlias'), findsNothing);
    expect(_outlinedButton(tester, 'profile-discard').onPressed, isNull);

    await _tap(tester, find.byKey(const ValueKey('profile-conflict-reload')));

    expect(find.byKey(const ValueKey('profile-conflict')), findsNothing);
    expect(_textField(tester).controller?.text, 'RemoteAlias');
    expect(find.text('VERSION 2'), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
  });

  testWidgets(
    'conflict reload keeps its draft visible through pending failure',
    (tester) async {
      final gateway = _DelayedConflictReloadProfileGateway();
      await _pumpProfile(tester, gateway: gateway);
      final input = find.byKey(const ValueKey('profile-alias-input'));

      await tester.enterText(input, 'LocalDraft');
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('profile-save')));

      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-conflict-reload')),
      );
      await tester.tap(find.byKey(const ValueKey('profile-conflict-reload')));
      await tester.pump();

      expect(find.text('Reloading the latest Profile…'), findsOneWidget);
      expect(find.text('Reloading…'), findsOneWidget);
      expect(_textField(tester).controller?.text, 'LocalDraft');
      expect(find.byKey(const ValueKey('profile-conflict')), findsOneWidget);

      gateway.reload.completeError(
        const ProfileGatewayException(ProfileGatewayFailureKind.unavailable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Latest Profile could not be reloaded'), findsOneWidget);
      expect(
        find.textContaining('The Profile service is unavailable.'),
        findsOneWidget,
      );
      expect(find.textContaining('draft is still preserved'), findsOneWidget);
      expect(_textField(tester).controller?.text, 'LocalDraft');
      expect(find.text('UNSAVED DRAFT'), findsOneWidget);
    },
  );

  testWidgets('unexpected save failures are sanitized and retryable', (
    tester,
  ) async {
    final gateway = _FailingSaveProfileGateway();
    await _pumpProfile(tester, gateway: gateway);

    await tester.enterText(
      find.byKey(const ValueKey('profile-alias-input')),
      'LocalDraft',
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('profile-save')));

    expect(find.text('Changes were not saved'), findsOneWidget);
    expect(
      find.text(
        'The Profile operation failed. Provider details were not exposed.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('raw-provider-secret'), findsNothing);
    expect(find.byKey(const ValueKey('profile-retry-save')), findsOneWidget);
    expect(find.text('UNSAVED DRAFT'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-alias-input')),
      'A' * 41,
    );
    await tester.pumpAndSettle();

    expect(_outlinedButton(tester, 'profile-retry-save').onPressed, isNull);
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
        address: 'No wallet connected',
        bio: 'Session-only presentation',
        connections: 0,
        groups: 0,
        watchlistItems: 0,
      ),
    );

    expect(find.text('SavedAlias'), findsOneWidget);
    expect(find.text('SessionFallback'), findsNothing);
    expect(find.text('VERSION 4'), findsOneWidget);
    expect(find.textContaining('开发预览'), findsWidgets);
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

    expect(find.byKey(const ValueKey('profile-alias-input')), findsOneWidget);
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
    expect(find.text('Loading Profile presentation…'), findsNothing);
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
          child: child!,
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

FilledButton _filledButton(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey<String>(key)));

TextField _textField(WidgetTester tester) => tester.widget<TextField>(
  find.byKey(const ValueKey<String>('profile-alias-input')),
);

OutlinedButton _outlinedButton(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.byKey(ValueKey<String>(key)));

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
