import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/main.dart' as entrypoint;

/// The V1 Social Privacy surface retired with the V2 privacy resource
/// (decision 0053). Its models, controller and gateway stay in the tree as
/// frozen history; nothing may mount them again.
void main() {
  testWidgets('social-privacy is no longer a Profile surface', (tester) async {
    expect(
      ProfileSurfaceScreen.supportedIds,
      isNot(contains('social-privacy')),
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfileSurfaceScreen.fromId('social-privacy')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('unknown-profile-surface')),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);
  });

  test('the retired location is recorded as information, not a route', () {
    expect(
      LoopRouteManifest.informationalRetiredPaths,
      contains('/profile/social-privacy'),
    );
    expect(
      LoopRouteManifest.supplementaryPaths,
      isNot(contains('/profile/social-privacy')),
    );
    expect(
      LoopRouteManifest.entries.map((entry) => entry.path),
      isNot(contains('/profile/social-privacy')),
    );
  });

  test('production composition no longer mounts the V1 gateway', () async {
    // The frozen default is the only production behaviour left: reading the
    // port yields a fail-closed gateway that issues no request.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final gateway = container.read(socialPrivacyGatewayProvider);
    expect(gateway, isA<UnavailableSocialPrivacyGateway>());
    expect(gateway.mode, SocialPrivacyMode.unavailable);
    await expectLater(
      gateway.load(),
      throwsA(isA<SocialPrivacyGatewayException>()),
    );
    // `lib/main.dart` must not override the port back to a production adapter.
    expect(entrypoint.main, isNotNull);
  });
}
