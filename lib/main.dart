import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_display_store.dart';
import 'package:loop_mobile/integrations/personalization/loop_personalization_providers.dart';
import 'package:loop_mobile/integrations/social/loop_social_providers.dart';
import 'package:loop_mobile/integrations/social/loop_group_alias_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_providers.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';

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
        profileActivationGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProfileActivationGatewayProvider),
        ),
        avatarCatalogGatewayProvider.overrideWith(
          (ref) => ref.watch(loopAvatarCatalogGatewayProvider),
        ),
        privacyGatewayProvider.overrideWith(
          (ref) => ref.watch(loopPrivacyGatewayProvider),
        ),
        communityGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2CommunityGatewayProvider),
        ),
        socialGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SocialGatewayProvider),
        ),
        searchGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SearchGatewayProvider),
        ),
      ],
      child: const LoopApp(),
    ),
  );
}
