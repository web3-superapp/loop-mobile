import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_upload.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';

class _SelectedAvatar extends AvatarUploadController {
  @override
  AvatarUploadState build() => AvatarUploadState(
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
    ),
  );
}

void main() {
  testWidgets(
    'local owner avatar survives navigation and never paints another identity',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            avatarUploadControllerProvider.overrideWith(_SelectedAvatar.new),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const LoopProfileAvatar(
                      avatarRef: null,
                      alias: 'Owner',
                      useLocalAvatar: true,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: LoopProfileAvatar(
                              avatarRef: null,
                              alias: 'Peer',
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Open peer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Open peer'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('PE'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner default stays one glyph for every username', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: Row(
              children: [
                LoopProfileAvatar(
                  avatarRef: null,
                  alias: 'Alice',
                  useLocalAvatar: true,
                ),
                LoopProfileAvatar(
                  avatarRef: null,
                  alias: 'Bob',
                  useLocalAvatar: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.person_outline_rounded), findsNWidgets(2));
    expect(find.text('AL'), findsNothing);
    expect(find.text('BO'), findsNothing);
  });
}
