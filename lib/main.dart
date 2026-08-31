import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_display_store.dart';
import 'package:loop_mobile/integrations/personalization/loop_personalization_providers.dart';
import 'package:loop_mobile/integrations/social/loop_social_providers.dart';
import 'package:loop_mobile/integrations/social/loop_group_alias_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final displayBootstrap = await bootstrapSharedPreferencesDisplayPreferences();
  runApp(
    ProviderScope(
      overrides: [
        loopDisplayPreferencesStoreProvider.overrideWithValue(
          displayBootstrap.store,
        ),
        loopDisplayPreferencesInitialProvider.overrideWithValue(
          displayBootstrap.initial,
        ),
        friendGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProductionFriendGatewayProvider),
        ),
        groupAliasGatewayProvider.overrideWith(
          (ref) => ref.watch(loopGroupAliasGatewayProvider),
        ),
        profileGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProfileGatewayProvider),
        ),
        privacyGatewayProvider.overrideWith(
          (ref) => ref.watch(loopPrivacyGatewayProvider),
        ),
        socialPrivacyGatewayProvider.overrideWith(
          (ref) => ref.watch(loopSocialPrivacyGatewayProvider),
        ),
      ],
      child: const LoopApp(),
    ),
  );
}
