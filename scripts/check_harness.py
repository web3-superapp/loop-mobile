#!/usr/bin/env python3
"""Validate Loop Mobile's repository-level engineering harness."""

from __future__ import annotations

import hashlib
import json
import plistlib
import re
import struct
import subprocess
import sys
import xml.etree.ElementTree as ElementTree
import zlib
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PRIMARY_DESTINATIONS = ["Community", "Mining", "Launch", "Market", "Wallet"]
PINNED_DEPENDENCIES = {
    "cupertino_icons": "1.0.8",
    "decimal": "3.2.6",
    "dio": "5.11.0",
    "firebase_core": "4.13.0",
    "firebase_messaging": "16.5.0",
    "flutter_lints": "6.0.0",
    "flutter_riverpod": "3.4.2",
    "flutter_secure_storage": "10.3.1",
    "flutter_svg": "2.3.0",
    "go_router": "17.5.0",
    "privy_flutter": "0.10.1",
    "reown_appkit": "1.8.4",
    "share_plus": "12.0.2",
    "shared_preferences": "2.5.5",
    "stream_chat_flutter": "10.3.0",
    "stream_chat_persistence": "10.3.0",
    "stream_video_flutter": "1.4.3",
    "uuid": "4.6.0",
}
PINNED_SQLITE_GRAPH = {
    "drift": "2.34.3",
    "sqlite3": "3.5.2",
    "sqlite3_flutter_libs": "0.5.42",
}
REQUIRED_FILES = (
    ".gitignore",
    ".gitnexusignore",
    ".metadata",
    "README.md",
    "AGENTS.md",
    "harness.json",
    "pubspec.yaml",
    "pubspec.lock",
    "bin/dart",
    "bin/flutter",
    "bin/loop-sdk",
    "ios/Podfile",
    "ios/Podfile.lock",
    "ios/Runner/Runner.entitlements",
    "scripts/check_harness.py",
    "tests/test_check_harness.py",
    "docs/product-decisions.md",
    "docs/product/implementation-constraints.md",
    "docs/decisions/0001-merge-verified-mobile-foundation.md",
    "docs/decisions/0006-use-identifier-only-stream-token-cards.md",
    "docs/decisions/0007-centralize-notification-intents-before-provider-ingress.md",
    "docs/decisions/0008-finish-app-logic-before-new-transports.md",
    "docs/decisions/0009-model-watchlist-before-http-adapter.md",
    "docs/decisions/0010-model-profile-presentation-before-http-adapter.md",
    "docs/decisions/0011-model-privacy-preferences-before-http-adapter.md",
    "docs/decisions/0012-model-notification-preferences-before-http-adapter.md",
    "docs/decisions/0013-connect-principal-bound-perp-private-reads.md",
    "docs/decisions/0014-connect-perp-positions-projection.md",
    "docs/decisions/0015-use-debug-only-routine-verification.md",
    "docs/decisions/0016-make-primary-market-spot-only.md",
    "docs/decisions/0017-use-public-testnet-spot-market-data.md",
    "docs/decisions/0018-use-system-sqlite-for-cold-builds.md",
    "docs/decisions/0019-use-public-testnet-spot-candles.md",
    "docs/decisions/0023-close-providerless-wallet-controls.md",
    "docs/decisions/0024-expose-production-audio-room-from-chat.md",
    "docs/decisions/0026-bound-home-discovery-and-security-facts.md",
    "docs/decisions/0036-mount-public-spot-full-chart.md",
    "docs/decisions/0037-bound-home-portfolio-and-net-worth-facts.md",
    "docs/decisions/0038-bound-new-pairs-to-exact-preview.md",
    "docs/decisions/0039-close-preview-group-info-controls.md",
    "docs/decisions/0040-separate-security-capability-from-enrollment.md",
    "docs/decisions/0041-centralize-dio-trust-boundaries.md",
    "docs/decisions/0042-persist-only-device-display-preferences.md",
    "docs/decisions/0043-use-reown-only-for-privy-external-evm-credentials.md",
    "docs/decisions/0044-separate-build-profiles-from-product-environments.md",
    "docs/decisions/0045-connect-bounded-stream-user-token-loader.md",
    "docs/decisions/0046-model-friends-and-group-creation-before-transport.md",
    "docs/decisions/0047-connect-backend-social-and-server-created-chat.md",
    "docs/decisions/0048-adopt-v2-five-destination-ui-foundation.md",
    "docs/decisions/0049-connect-v2-account-device-session.md",
    "docs/decisions/0069-adopt-the-seven-band-type-ladder.md",
    "docs/failures/flutter-gradle-version-floor.md",
    "docs/failures/gitnexus-generated-source-pollution.md",
    "docs/failures/providerless-notification-fixtures.md",
    "docs/failures/providerless-home-portfolio-facts.md",
    "docs/failures/providerless-new-pairs-facts.md",
    "docs/failures/providerless-security-activity-facts.md",
    "docs/failures/providerless-protection-status-and-setup.md",
    "docs/failures/providerless-wallet-controls-without-effects.md",
    "docs/failures/privy-android-compile-sdk.md",
    "docs/failures/principal-agnostic-wallet-single-flight.md",
    "docs/failures/production-chat-preview-route-leak.md",
    "docs/failures/perp-semantics-in-chat-preview.md",
    "docs/failures/preview-message-request-fake-success.md",
    "docs/failures/preview-group-info-controls-without-effects.md",
    "docs/failures/sqlite3-native-hook-download.md",
    "docs/failures/swiftpm-file-picker-cold-cache.md",
    "docs/harness/adoption-report.md",
    "docs/open-source-attribution.md",
    "docs/phase-0/compatibility-report.md",
    "docs/phase-1/frontend-integration-report.md",
    ".vscode/launch.json",
    "config/README.md",
    "config/debug.json",
    "config/release.example.json",
    "lib/core/navigation/stream_channel_route.dart",
    "lib/core/navigation/surface_catalog.dart",
    "lib/core/navigation/route_manifest.dart",
    "lib/core/navigation/loop_routing_error_log.dart",
    "lib/features/shell/loop_pending_surface.dart",
    "docs/product/routes-manifest.json",
    "docs/decisions/0050-adopt-93-route-manifest.md",
    "docs/decisions/0051-adopt-flutter-svg-and-prototype-assets.md",
    "test/route_manifest_test.dart",
    "docs/decisions/0054-adopt-v2-community-social-graph-and-search.md",
    "docs/decisions/0057-adopt-v2-chain-market-and-wallet-read.md",
    "docs/decisions/0058-adopt-v2-launch-catalog-and-mining-skeleton.md",
    "docs/decisions/0062-adopt-the-launch-chain-slot.md",
    "docs/decisions/0070-speak-to-the-user-not-to-the-backlog.md",
    "docs/copy-glossary.md",
    "lib/core/chain/loop_chain_ids.dart",
    "test/s9_dual_chain_test.dart",
    "test/s9_dual_chain_pages_test.dart",
    "test/community_api_contract_test.dart",
    "test/community_idempotency_test.dart",
    "test/community_pages_test.dart",
    "test/community_social_pages_test.dart",
    "test/community_public_profile_and_apply_test.dart",
    "lib/core/network/loop_dio_factory.dart",
    "lib/app.dart",
    "lib/features/shell/loop_shell.dart",
    "lib/features/community/community_screen.dart",
    "lib/features/mining/mining_screen.dart",
    "lib/main.dart",
    "lib/main_preview.dart",
    "lib/app/app_config.dart",
    "lib/app/loop_display_preferences.dart",
    "lib/integrations/personalization/shared_preferences_display_store.dart",
    "lib/app/notifications/loop_notification_coordinator.dart",
    "lib/integrations/reown/external_wallet_credential_gateway.dart",
    "lib/integrations/reown/reown_external_wallet_connector.dart",
    "lib/integrations/backend/loop_stream_token.dart",
    "lib/integrations/backend/loop_stream_token_providers.dart",
    "lib/integrations/backend/loop_stream_token_repository.dart",
    "lib/integrations/backend/loop_stream_token_session.dart",
    "lib/integrations/backend/loop_backend_providers.dart",
    "lib/integrations/backend/v2/loop_v2_contract.dart",
    "lib/integrations/backend/v2/loop_v2_meta.dart",
    "lib/integrations/backend/v2/loop_v2_meta_providers.dart",
    "lib/integrations/backend/v2/loop_v2_meta_repository.dart",
    "lib/integrations/backend/v2/loop_v2_session.dart",
    "lib/integrations/backend/v2/loop_v2_session_api.dart",
    "lib/integrations/backend/v2/loop_v2_session_coordinator.dart",
    "lib/integrations/backend/v2/loop_v2_session_providers.dart",
    "lib/integrations/backend/v2/loop_v2_session_store.dart",
    "lib/app/session/loop_communication_retirement.dart",
    "lib/integrations/notifications/loop_notification_event_source.dart",
    "lib/integrations/notifications/loop_notification_router.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_market.dart",
    "lib/integrations/hyperliquid/hyperliquid_http_providers.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_market_providers.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_market_repository.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_candle.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart",
    # Step 5 retired the Hyperliquid Spot market and chart slice; the mounted
    # chart is now the generalised `loop_candle_chart.dart` registered below.
    "lib/features/market/watchlist/watchlist_controller.dart",
    "lib/features/chat/friends/chat_create_menu_button.dart",
    "lib/features/chat/friends/friend_controllers.dart",
    "lib/features/chat/friends/friend_gateway.dart",
    "lib/features/chat/friends/friend_models.dart",
    "lib/features/chat/friends/friend_request_controller.dart",
    "lib/features/chat/friends/friend_request_screen.dart",
    "lib/features/chat/friends/friend_screens.dart",
    "lib/features/chat/group_alias/group_alias_controller.dart",
    "lib/features/chat/group_alias/group_alias_gateway.dart",
    "lib/features/chat/group_alias/group_alias_models.dart",
    "lib/features/chat/group_alias/group_alias_screen.dart",
    "lib/features/chat/group_alias/group_alias_stream_message_identity.dart",
    "lib/features/profile/social_privacy/social_privacy_controller.dart",
    "lib/features/profile/social_privacy/social_privacy_gateway.dart",
    "lib/features/profile/social_privacy/social_privacy_models.dart",
    "lib/integrations/backend/loop_authenticated_providers.dart",
    "lib/integrations/backend/loop_authenticated_session.dart",
    "lib/integrations/personalization/dio_loop_personalization_gateways.dart",
    "lib/integrations/personalization/loop_personalization_providers.dart",
    "lib/integrations/personalization/memory_social_privacy_gateway.dart",
    "lib/integrations/social/dio_loop_group_alias_gateway.dart",
    "lib/integrations/social/dio_loop_social_friend_gateway.dart",
    "lib/integrations/social/loop_group_alias_providers.dart",
    "lib/integrations/social/loop_social_providers.dart",
    "lib/integrations/social/loop_social_repository.dart",
    "lib/integrations/social/loop_social_transport_models.dart",
    "lib/integrations/social/memory_friend_gateway.dart",
    "test/security_capability_truthfulness_test.dart",
    "test/loop_dio_factory_test.dart",
    "lib/features/market/watchlist/watchlist_gateway.dart",
    "lib/features/market/watchlist/watchlist_models.dart",
    # Step 5 retired the Preview Watchlist adapter; the Watchlist port is now
    # backed by the V2 transport and stays fail-closed without it.
    "lib/features/profile/presentation/profile_controller.dart",
    "lib/features/profile/presentation/profile_gateway.dart",
    "lib/features/profile/presentation/profile_models.dart",
    "lib/integrations/personalization/memory_profile_gateway.dart",
    "lib/features/profile/privacy/privacy_controller.dart",
    "lib/features/profile/privacy/privacy_gateway.dart",
    "lib/features/profile/privacy/privacy_models.dart",
    "lib/integrations/personalization/memory_privacy_gateway.dart",
    # Step 5 retired the v1 notification-preference module and its Preview
    # adapter; `notif-settings` is now the V2 ten-category page registered
    # with the step-5 files below.
    "lib/features/perp/account/perp_account_controller.dart",
    "lib/features/perp/perp_portfolio_screens.dart",
    "lib/features/perp/positions/perp_positions_controller.dart",
    "lib/features/perp/private/perp_private_gateway.dart",
    "lib/features/perp/private/perp_private_models.dart",
    "lib/integrations/backend/loop_perp_providers.dart",
    "lib/integrations/backend/loop_perp_repository.dart",
    "lib/integrations/backend/loop_perp_session.dart",
    "test/app_notification_coordinator_test.dart",
    "test/app_config_test.dart",
    "test/loop_stream_token_repository_test.dart",
    "test/loop_stream_token_session_test.dart",
    "test/loop_v2_meta_providers_test.dart",
    "test/loop_v2_meta_repository_test.dart",
    "test/loop_v2_session_api_test.dart",
    "test/loop_v2_session_coordinator_test.dart",
    "test/loop_v2_session_store_test.dart",
    "test/loop_session_controller_test.dart",
    "test/privy_provider_test.dart",
    "test/chat_spot_snapshot_test.dart",
    "test/chat_preview_message_requests_test.dart",
    "test/loop_notification_coordinator_test.dart",
    "test/loop_notification_router_test.dart",
    "test/development_preview_experience_test.dart",
    "test/hyperliquid_spot_candle_providers_test.dart",
    "test/hyperliquid_spot_candle_repository_test.dart",
    "test/hyperliquid_spot_market_repository_test.dart",
    "test/local_settings_and_help_test.dart",
    "test/loop_display_preferences_test.dart",
    "test/external_wallet_credential_gateway_test.dart",
    "test/identity_auth_controller_test.dart",
    "test/post_auth_bootstrap_coordinator_test.dart",
    "test/privy_login_screen_test.dart",
    "test/profile_controller_test.dart",
    "test/profile_models_test.dart",
    "test/profile_presentation_screen_test.dart",
    "test/v2_primary_navigation_test.dart",
    "test/v2_ui_foundation_test.dart",
    "test/friend_feature_test.dart",
    "test/friend_request_feature_test.dart",
    "test/social_ui_safety_edges_test.dart",
    "test/loop_social_authenticated_session_test.dart",
    "test/loop_social_repository_test.dart",
    "test/loop_social_friend_gateway_test.dart",
    "test/social_privacy_models_test.dart",
    "test/social_privacy_controller_test.dart",
    "test/social_privacy_presentation_screen_test.dart",
    "test/group_alias_models_test.dart",
    "test/group_alias_controller_test.dart",
    "test/group_alias_resolver_test.dart",
    "test/group_alias_stream_message_identity_test.dart",
    "test/dio_loop_group_alias_gateway_test.dart",
    "test/dio_loop_group_alias_resolver_gateway_test.dart",
    "test/loop_group_alias_providers_test.dart",
    "test/dio_loop_personalization_gateways_test.dart",
    "test/loop_personalization_providers_test.dart",
    "test/privacy_controller_test.dart",
    "test/privacy_models_test.dart",
    "test/privacy_presentation_screen_test.dart",
    "test/loop_perp_providers_test.dart",
    "test/loop_perp_repository_test.dart",
    "test/loop_perp_session_test.dart",
    "test/perp_account_controller_test.dart",
    "test/perp_account_screen_test.dart",
    "test/perp_positions_controller_test.dart",
    "test/perp_positions_screen_test.dart",
    # Step 5 replaced `SpotMarketRoute`, the Hyperliquid Spot Market screens
    # and the v1 wallet/notification modules with the V2 chain, market, wallet,
    # watchlist, alert and notification modules.
    "lib/core/navigation/market_asset_route.dart",
    "lib/core/qr/loop_qr_code.dart",
    "lib/features/chain/chain_contract.dart",
    "lib/features/chain/chain_controllers.dart",
    "lib/features/chain/chain_gateway.dart",
    "lib/features/chain/chain_models.dart",
    "lib/features/chain/chain_widgets.dart",
    "lib/features/market/market_screen.dart",
    "lib/features/market/token_screen.dart",
    "lib/features/market/market_secondary_screens.dart",
    "lib/features/market/market_widgets.dart",
    "lib/features/market/loop_candle_chart.dart",
    "lib/features/market/market_controllers.dart",
    "lib/features/market/market_read_gateway.dart",
    "lib/features/market/market_read_models.dart",
    "lib/features/market/alerts/alert_models.dart",
    "lib/features/market/alerts/alerts_controller.dart",
    "lib/features/market/alerts/alerts_gateway.dart",
    "lib/features/market/alerts/alerts_screen.dart",
    "lib/features/notifications/notification_controllers.dart",
    "lib/features/notifications/notification_models.dart",
    "lib/features/notifications/notifications_gateway.dart",
    "lib/features/wallet/wallet_read_screens.dart",
    "lib/features/wallet/wallet_read_widgets.dart",
    "lib/features/wallet/wallet_read_models.dart",
    "lib/features/wallet/wallet_read_gateway.dart",
    "lib/features/wallet/wallet_read_controllers.dart",
    "lib/features/profile/notification_preferences/notification_preferences_screen.dart",
    "lib/integrations/backend/v2/loop_v2_chain_codec.dart",
    "lib/integrations/backend/v2/loop_v2_chain_failure.dart",
    "lib/integrations/backend/v2/loop_v2_s5_gateways.dart",
    "lib/integrations/backend/v2/loop_v2_s5_providers.dart",
    "lib/integrations/backend/v2/loop_v2_write_origin_source.dart",
    "lib/integrations/backend/v2/chain/loop_v2_chain_api.dart",
    "lib/integrations/backend/v2/wallet/loop_v2_wallet_api.dart",
    "lib/integrations/backend/v2/market/loop_v2_market_api.dart",
    "lib/integrations/backend/v2/watchlist/loop_v2_watchlist_api.dart",
    "lib/integrations/backend/v2/alerts/loop_v2_alerts_api.dart",
    "lib/integrations/backend/v2/notifications/loop_v2_notifications_api.dart",
    "test/s5_api_contract_test.dart",
    "test/s5_market_pages_test.dart",
    "test/s5_wallet_pages_test.dart",
    "test/s5_watchlist_alerts_notifications_test.dart",
    "test/loop_candle_chart_test.dart",
    "test/loop_qr_code_test.dart",
    # Step 7 (decision 0058): the launch catalogue, the mining skeleton and the
    # referral graph, each behind a fail-closed port.
    "lib/core/navigation/launch_route.dart",
    "lib/features/launch/launch_contract.dart",
    "lib/features/launch/launch_models.dart",
    "lib/features/launch/launch_gateway.dart",
    "lib/features/launch/launch_controllers.dart",
    "lib/features/launch/launch_widgets.dart",
    "lib/features/launch/launch_screen.dart",
    "lib/features/launch/launch_detail_screens.dart",
    "lib/features/launch/launch_action_screens.dart",
    "lib/features/mining/mining_models.dart",
    "lib/features/mining/mining_gateway.dart",
    "lib/features/mining/mining_controllers.dart",
    "lib/features/mining/mining_widgets.dart",
    "lib/features/mining/mining_secondary_screens.dart",
    "lib/features/mining/referral_models.dart",
    "lib/features/mining/referral_gateway.dart",
    "lib/features/mining/referral_screen.dart",
    "lib/integrations/backend/v2/loop_v2_s7_codec.dart",
    "lib/integrations/backend/v2/loop_v2_s7_gateways.dart",
    "lib/integrations/backend/v2/loop_v2_s7_providers.dart",
    "lib/integrations/backend/v2/launch/loop_v2_launch_api.dart",
    "lib/integrations/backend/v2/mining/loop_v2_mining_api.dart",
    "lib/integrations/backend/v2/referral/loop_v2_referral_api.dart",
    "test/s7_api_contract_test.dart",
    "test/s7_launch_pages_test.dart",
    "test/s7_mining_pages_test.dart",
    "test/s7_referral_test.dart",
)
# Step 3 replaced `/chat/requests` with the V2 `dm-requests` page, which has a
# real backend and is no longer a Development Preview fixture route.
CHAT_PREVIEW_ONLY_ROUTES = (
    "/chat/group",
    "/chat/dm",
    "/chat/group-info",
    "/chat/search",
    "/preview/token-card",
    "/preview/contract-facts",
    "/preview/asset-message",
)
TOKEN_CARD_EXTRA_DATA_KEYS = frozenset(
    {
        "loop_schema",
        "asset_id",
        "chain_id",
        "contract_id",
        "snapshot_at",
    }
)
TOKEN_CARD_RENDER_IMPORTS = {
    "lib/features/chat/attachments/token_card_attachment.dart": frozenset(
        {"'package:flutter/foundation.dart' show immutable"}
    ),
    "lib/features/chat/attachments/stream_token_card_attachment_policy.dart": frozenset(
        {
            "'package:loop_mobile/features/chat/attachments/token_card_attachment.dart'",
            "'package:stream_chat_flutter/stream_chat_flutter.dart' show Attachment",
        }
    ),
    "lib/features/chat/attachments/stream_token_card_attachment_builder.dart": frozenset(
        {
            "'package:flutter/widgets.dart' show BuildContext, Widget",
            "'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_policy.dart'",
            "'package:loop_mobile/features/chat/widgets/token_card_view.dart'",
            "'package:stream_chat_flutter/stream_chat_flutter.dart' show Attachment, Message, StreamAttachmentWidgetBuilder",
        }
    ),
    "lib/features/chat/attachments/stream_token_card_message_preview_formatter.dart": frozenset(
        {
            "'package:flutter/widgets.dart' show BuildContext, TextSpan",
            "'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_policy.dart'",
            "'package:stream_chat_flutter/stream_chat_flutter.dart' show ChannelModel, DraftMessage, Message, MessageState, StreamMessagePreviewFormatter, User",
        }
    ),
    "lib/features/chat/widgets/token_card_view.dart": frozenset(
        {
            (
                "'package:flutter/material.dart' show Alignment, Border, BoxDecoration, BoxShape, "
                "BuildContext, ClipRRect, Column, Color, Container, CrossAxisAlignment, "
                "DecoratedBox, EdgeInsets, Expanded, FontWeight, Icon, IconData, Icons, "
                "MainAxisSize, OutlinedButton, Padding, Positioned, Row, Semantics, SizedBox, "
                "Stack, StatelessWidget, Text, TextOverflow, Theme, ValueKey, Widget, immutable"
            ),
            (
                "'package:loop_mobile/core/theme/loop_theme.dart' show "
                "LoopColors, LoopRadius, LoopType, LoopTypography"
            ),
            "'package:loop_mobile/features/chat/attachments/token_card_attachment.dart'",
        }
    ),
}
DECISION_SECTIONS = ("Status", "Context", "Decision", "Consequences")
FAILURE_SECTIONS = ("Summary", "Root Cause", "Detection", "Prevention", "Evidence")
ADOPTION_SECTIONS = (
    "Baseline",
    "Adopted surfaces",
    "Rules and checks",
    "Verification",
    "Assumptions and follow-up",
    "Failure memory",
    "Effectiveness",
)
ANDROID_NAME = "{http://schemas.android.com/apk/res/android}name"
ANDROID_EXPORTED = "{http://schemas.android.com/apk/res/android}exported"
ANDROID_SCHEME = "{http://schemas.android.com/apk/res/android}scheme"
ANDROID_VALUE = "{http://schemas.android.com/apk/res/android}value"
ANDROID_TOOLS_NODE = "{http://schemas.android.com/tools}node"
ANDROID_INTERNET_PERMISSION = "android.permission.INTERNET"
PRIVY_OAUTH_SCHEME = "com.cywd.loop.privy"
REOWN_WALLET_SCHEME = "com.cywd.loop.wallet"
ANDROID_REOWN_WALLET_PACKAGES = frozenset(
    {
        "io.metamask",
        "com.wallet.crypto.trustapp",
        "me.rainbow",
    }
)
IOS_REOWN_WALLET_SCHEMES = frozenset({"metamask", "trust", "rainbow"})
REOWN_CONNECTOR_PATH = Path(
    "lib/integrations/reown/reown_external_wallet_connector.dart"
)
REOWN_SDK_IMPORT = "package:reown_appkit/reown_appkit.dart"
REOWN_EXCLUDED_WALLET_IDS = {
    "_phantomWalletId": (
        "a797aa35c0fadbfc1a53e7f675162ed5226968b44a19ee3d24385c64d1d3c393"
    ),
    "_solflareWalletId": (
        "1ca0bdd4747578705b1939af023d120677c64fe6ca76add81fda36e350605e79"
    ),
    "_coinbaseWalletId": (
        "fd20dc426fb37566d803205b19bbc1d4096b248ac04548e3cfb6b3a38bd033aa"
    ),
}
REOWN_FORBIDDEN_IMPORT_ROOTS = (
    Path("lib/features/market"),
    Path("lib/features/perp"),
    Path("lib/features/review"),
    Path("lib/integrations/hyperliquid"),
)
REOWN_FORBIDDEN_IMPORT_FILES = frozenset(
    {
        Path("lib/features/wallet/send_screens.dart"),
        Path("lib/features/wallet/trade_screens.dart"),
        Path("lib/integrations/privy/privy_production_adapter.dart"),
        Path("lib/integrations/privy/privy_provider.dart"),
        Path("lib/integrations/privy/wallet_signing_gateway.dart"),
    }
)
ANDROID_AUDIO_ROOM_PERMISSIONS = frozenset(
    {
        "android.permission.RECORD_AUDIO",
        "android.permission.MODIFY_AUDIO_SETTINGS",
    }
)
ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS = frozenset(
    {
        "android.permission.USE_FULL_SCREEN_INTENT",
        "android.permission.DISABLE_KEYGUARD",
        "android.permission.VIBRATE",
        "android.permission.WAKE_LOCK",
        "android.permission.ACCESS_NOTIFICATION_POLICY",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.MANAGE_OWN_CALLS",
        "android.permission.FOREGROUND_SERVICE_PHONE_CALL",
        "android.permission.FOREGROUND_SERVICE_MICROPHONE",
        "android.permission.FOREGROUND_SERVICE_CAMERA",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION",
        "${applicationId}.PERMISSION_CALL",
    }
)
ANDROID_AUDIO_ROOM_REMOVED_DECLARED_PERMISSIONS = frozenset(
    {"${applicationId}.PERMISSION_CALL"}
)
ANDROID_AUDIO_ROOM_REMOVED_COMPONENTS = {
    "activity": frozenset(
        {
            "io.getstream.video.flutter.stream_video_push_notification.IncomingCallActivity",
            "io.getstream.video.flutter.stream_video_push_notification.TransparentActivity",
        }
    ),
    "receiver": frozenset(
        {
            "io.getstream.video.flutter.stream_video_push_notification.IncomingCallBroadcastReceiver",
        }
    ),
    "service": frozenset(
        {
            "io.getstream.video.flutter.stream_video_push_notification.IncomingCallNotificationService",
            "io.getstream.video.flutter.stream_video_push_notification.IncomingCallConnectionService",
            "io.getstream.video.flutter.stream_video_flutter.service.StreamCallService",
            "io.getstream.video.flutter.stream_video_flutter.service.StreamScreenShareService",
        }
    ),
}
# The still camera left this set on 2026-09-19: the chat composer may take a
# photo, and `check_chat_camera_contract` now requires the one declaration that
# allows it. Audio Room still gets no camera of its own — the hardware feature
# and Stream's call-camera components stay removed below.
ANDROID_AUDIO_ROOM_FORBIDDEN_ACTIVE_PERMISSIONS = frozenset(
    ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS
)
# S70: Android 13+ shows nothing without it, and the one category the account
# cannot turn off is 安全事件. It is declared once and asked for after login,
# never on first launch.
ANDROID_PUSH_PERMISSION = "android.permission.POST_NOTIFICATIONS"
# Firebase posts into the channel named here. Without all three the OS invents
# its own "Miscellaneous" channel and draws the launcher plate as a white
# square in the status bar.
ANDROID_PUSH_MANIFEST_META = {
    "com.google.firebase.messaging.default_notification_channel_id": (
        "@string/loop_notification_channel_id"
    ),
    "com.google.firebase.messaging.default_notification_icon": (
        "@drawable/ic_loop_notification"
    ),
    "com.google.firebase.messaging.default_notification_color": "@color/loop_lime",
}
ANDROID_CHAT_CAMERA_PERMISSION = "android.permission.CAMERA"
IOS_CHAT_CAMERA_USAGE_KEY = "NSCameraUsageDescription"
# Two-sided on purpose. A declared permission with no caller is one nobody can
# answer for in a store review; a caller with no declaration is a crash on the
# first tap. Both sides are named here.
CHAT_CAMERA_CONTRACTS = {
    "lib/integrations/communication/loop_chat_camera.dart": (
        "loopChatCameraPickerOption",
        "StreamAttachmentHandler.instance.pickImage(source: .camera)",
        "const String loopChatCameraPermissionMessage = "
        "'没有相机权限，去系统设置里允许 LOOP 使用相机后再试'",
        # The captured photo is judged by S45's rule, not a second one.
        "loopChatReviewImages(<Attachment>[...current, photo])",
    ),
    "lib/integrations/communication/loop_chat_image_composer.dart": (
        "attachmentPickerOptionsBuilder:",
        "loopChatCameraPickerOption(",
    ),
    "test/stream_chat_camera_test.dart": ("loopChatCameraPermissionMessage",),
}
CHAT_CAMERA_TEST_MARKERS = {
    Path("test/stream_chat_camera_test.dart"): (
        "就在相册那一行旁边，叫「拍照」",
        "取消拍照既不发消息，也不报错",
        "没有相机权限时，只说去系统设置",
        "拍出来的图走的是 S45 那条闸门",
    ),
}
# `aps-environment` left this set on 2026-09-22 (S70): ordinary push is the
# whole point of the Firebase slice, and the entitlement is what makes APNs
# hand the device a token at all. The VoIP and call entitlements stay out —
# Audio Room is still foreground-only and LOOP still has no PushKit path.
IOS_AUDIO_ROOM_FORBIDDEN_ENTITLEMENTS = frozenset(
    {
        "com.apple.developer.background-modes",
        "com.apple.developer.usernotifications.communication",
        "com.apple.developer.voip",
    }
)
# The one background mode LOOP declares. `audio`, `voip`, `fetch` and
# `processing` would each buy a capability the product does not have, and a
# reviewer reads this array as a claim about what the app does in the
# background.
IOS_PUSH_BACKGROUND_MODES = ("remote-notification",)
IOS_AUDIO_ROOM_FORBIDDEN_RUNNER_MARKERS = (
    "import CallKit",
    "import PushKit",
    "CXProvider",
    "CXCallController",
    "PKPushRegistry",
)
NOTIFICATION_ROUTER_PATH = Path(
    "lib/integrations/notifications/loop_notification_router.dart"
)
NOTIFICATION_EVENT_SOURCE_PATH = Path(
    "lib/integrations/notifications/loop_notification_event_source.dart"
)
NOTIFICATION_PROVIDER_INGRESS_PATH = Path(
    "lib/integrations/notifications/firebase_notification_ingress.dart"
)
NOTIFICATION_COORDINATOR_PATH = Path(
    "lib/app/notifications/loop_notification_coordinator.dart"
)
NOTIFICATION_APPLICATION_PATH = Path("lib/app.dart")
NOTIFICATION_GLOBAL_INGRESS_PATTERNS = (
    (re.compile(r"\bFirebaseMessaging\s*\.\s*instance\b"), "FirebaseMessaging.instance"),
    (
        re.compile(r"\bFirebaseMessaging\s*\.\s*onBackgroundMessage\s*\("),
        "FirebaseMessaging.onBackgroundMessage",
    ),
    (
        re.compile(r"\bFirebaseMessaging\s*\.\s*onMessageOpenedApp\b"),
        "FirebaseMessaging.onMessageOpenedApp",
    ),
    (
        re.compile(r"\bFirebaseMessaging\s*\.\s*onMessage\b"),
        "FirebaseMessaging.onMessage",
    ),
    (re.compile(r"\.\s*getInitialMessage\s*\("), ".getInitialMessage("),
)
# Decision 0067 replaced the speculative `notification.v1` envelope with the
# four-key payload the server actually sends. The chat CID left with it: a push
# now points at a notification record, and the only parameterised destination is
# the token page, which still needs the canonical asset-route contract to reject
# a non-canonical `assetId` before it becomes a location. The allowlist stays
# closed: a raw provider-payload import is still rejected.
NOTIFICATION_ROUTER_IMPORTS = frozenset(
    {
        "'dart:collection'",
        "'package:loop_mobile/core/navigation/market_asset_route.dart'",
    }
)
FIREBASE_OPTIONS_PATH = Path("lib/firebase_options.dart")
NOTIFICATION_PROVIDER_IMPORT_ALLOWED_PATHS = frozenset(
    {
        Path("lib/app/bootstrap/sdk_compatibility.dart"),
        # The hand-written equivalent of `flutterfire configure`'s output. It
        # imports `FirebaseOptions` and names no other provider type; the
        # contract below holds it to the two applications LOOP registered.
        FIREBASE_OPTIONS_PATH,
        NOTIFICATION_PROVIDER_INGRESS_PATH,
    }
)
NOTIFICATION_PROVIDER_IMPORT_MARKERS = (
    "package:firebase_core/firebase_core.dart",
    "package:firebase_messaging/firebase_messaging.dart",
)
# The first push dictionary (decision 0067 §7.3). A fourth event type is a
# contract change, not a client decision.
NOTIFICATION_KIND_MEMBERS = frozenset(
    {"priceAlertTriggered", "securityEvent", "communityVoiceRoomStarted"}
)
NOTIFICATION_CONTEXT_ROUTE_MEMBERS = frozenset({"token", "devices", "voiceRoom"})
NOTIFICATION_SOURCE_EVENT_KIND_MEMBERS = frozenset(
    {"foreground", "background", "interaction"}
)
# Four intents for three events: a price alert has two, because the asset is
# the feed's answer and a notification that cannot be matched to a record must
# still land somewhere that names nothing.
NOTIFICATION_INTENT_CLASSES = frozenset(
    {
        "LoopPriceAlertNotificationIntent",
        "LoopPriceAlertListNotificationIntent",
        "LoopSecurityEventNotificationIntent",
        "LoopVoiceRoomNotificationIntent",
    }
)
# Both parameterless destinations. The two price-alert intents hold no literal
# at all: they go through `MarketAssetRoute`, which is where the canonical
# asset identity is enforced.
NOTIFICATION_ROUTE_LITERALS = frozenset({"/chat/voice", "/profile/devices"})
# `lib/app.dart` joined this set with decision 0067: confirming a pointer needs
# the notification feed, which is a feature gateway the router may not import,
# so the composition root is where the two meet. It may name the pointer and
# the context; it still may not construct routing identity (checked below).
NOTIFICATION_ROUTER_CONSUMER_PATHS = frozenset(
    {
        NOTIFICATION_ROUTER_PATH,
        NOTIFICATION_COORDINATOR_PATH,
        NOTIFICATION_APPLICATION_PATH,
    }
)
NOTIFICATION_ROUTER_IMPORT = (
    "package:loop_mobile/integrations/notifications/loop_notification_router.dart"
)
NOTIFICATION_COORDINATOR_IMPORT = (
    "package:loop_mobile/app/notifications/loop_notification_coordinator.dart"
)
NOTIFICATION_ROUTER_CONSTRUCTION_PATTERN = re.compile(
    r"\b(?:LoopNotificationRouter|LoopNotificationSessionContext\s*\.\s*authenticated)\s*\("
)
NOTIFICATION_COORDINATOR_CONSTRUCTION_PATTERN = re.compile(
    r"\bLoopNotificationCoordinator\s*\("
)
NOTIFICATION_COORDINATOR_CONSUMER_PATHS = frozenset(
    {NOTIFICATION_COORDINATOR_PATH, NOTIFICATION_APPLICATION_PATH}
)
FEATURE_TRANSPORT_FORBIDDEN_IMPORTS = (
    "package:dio/dio.dart",
)
# Step 5 (decision 0057) put the V2 modules behind ports as well: no Dio type
# and no `/v2/` literal may cross into a feature module.
FEATURE_TRANSPORT_FORBIDDEN_TYPE_PATTERN = re.compile(r"\bDio\b")
FEATURE_BACKEND_ROUTE_PATTERN = re.compile(r"(?P<quote>['\"])/v(?P<version>[12])/")

# The six S5 ports. Each production default is its own `Unavailable…Gateway`,
# so a feature is unavailable until `lib/main.dart` mounts a real adapter.
S5_PORT_DEFAULTS = (
    (
        "lib/features/chain/chain_gateway.dart",
        "chainGatewayProvider",
        "ChainGateway",
        "UnavailableChainGateway",
    ),
    (
        "lib/features/wallet/wallet_read_gateway.dart",
        "walletReadGatewayProvider",
        "WalletReadGateway",
        "UnavailableWalletReadGateway",
    ),
    (
        "lib/features/market/market_read_gateway.dart",
        "marketReadGatewayProvider",
        "MarketReadGateway",
        "UnavailableMarketReadGateway",
    ),
    (
        "lib/features/market/watchlist/watchlist_gateway.dart",
        "watchlistGatewayProvider",
        "WatchlistGateway",
        "UnavailableWatchlistGateway",
    ),
    (
        "lib/features/market/alerts/alerts_gateway.dart",
        "alertsGatewayProvider",
        "AlertsGateway",
        "UnavailableAlertsGateway",
    ),
    (
        "lib/features/notifications/notifications_gateway.dart",
        "notificationsGatewayProvider",
        "NotificationsGateway",
        "UnavailableNotificationsGateway",
    ),
    # Step 6 money actions. A write port that is not mounted must fail closed
    # exactly like a read port: no prepare, no report, no execute.
    (
        "lib/features/wallet/money_actions_gateway.dart",
        "walletIntentsGatewayProvider",
        "WalletIntentsGateway",
        "UnavailableWalletIntentsGateway",
    ),
    (
        "lib/features/wallet/money_actions_gateway.dart",
        "swapQuoteGatewayProvider",
        "SwapQuoteGateway",
        "UnavailableSwapQuoteGateway",
    ),
    (
        "lib/features/wallet/money_actions_gateway.dart",
        "approvalsGatewayProvider",
        "ApprovalsGateway",
        "UnavailableApprovalsGateway",
    ),
)
S5_CAPABILITY_META_PATH = Path("lib/integrations/backend/v2/loop_v2_meta.dart")
# The contract's 31 capability ids, in contract order. Steps 6 and 7 both read
# the frozen contract, which carries the three step-8 ids `security`,
# `settings` and `support` alongside the three S7 ids.
S5_CAPABILITY_IDS = (
    "privyAuthentication",
    "accountSession",
    "streamChatToken",
    "streamVideoToken",
    "community",
    "communityChat",
    "voiceRooms",
    "communityMining",
    "communityPresence",
    "search",
    "bscRead",
    "walletRead",
    "watchlist",
    "marketRead",
    "privySwap",
    "sendApprovals",
    "launch",
    "mining",
    "referral",
    "priceAlerts",
    "notificationsFeed",
    "pushNotifications",
    "profile",
    "avatarUpload",
    "security",
    "settings",
    "support",
    "pay",
    "bridge",
    "dappExecution",
    "communityAi",
)
# The three S7 ports (decision 0058). Each production default is its own
# `Unavailable…Gateway`, so Launch, Mining and Referral are unavailable until
# `lib/main.dart` mounts a real adapter. There is no Preview mode for step 7:
# no Launch or Mining fixture can be labelled truthfully.
S7_PORT_DEFAULTS = (
    (
        "lib/features/launch/launch_gateway.dart",
        "launchGatewayProvider",
        "LaunchGateway",
        "UnavailableLaunchGateway",
    ),
    (
        "lib/features/mining/mining_gateway.dart",
        "miningGatewayProvider",
        "MiningGateway",
        "UnavailableMiningGateway",
    ),
    (
        "lib/features/mining/referral_gateway.dart",
        "referralGatewayProvider",
        "ReferralGateway",
        "UnavailableReferralGateway",
    ),
)
S7_CONTRACT_PATH = Path("lib/features/launch/launch_contract.dart")
# The em dash is the only placeholder an S7 metric may render. `0` next to a
# missing contract fact would be indistinguishable from a proven zero.
S7_MISSING_FIGURE_MARKER = "const String launchMissingFigure = '—';"
# The prototype口径 that the missing 02 contract document retires. None of them
# may appear in a mounted Launch, Mining or Referral surface. Naming the
# server's own `ecosystemTax` field while rendering it unavailable is not a
# claim, so the bare word is not forbidden — only the asserted rate is.
S7_RETIRED_PROTOTYPE_COPY = (
    "永久 1%",
    "1% 生态税",
    "0.5% 单地址",
    "统一 10 亿",
    "尾号统一",
    "10 亿总量",
)
# The graduated Token Card lost its ecosystem-tax metric with decision 0058:
# there is no proven rate to label.
S7_TOKEN_CARD_PATHS = (
    Path("lib/widgets/loop_token_card.dart"),
    Path("lib/features/system/system_specimens.dart"),
)
S7_SURFACE_ROOTS = (
    Path("lib/features/launch"),
    Path("lib/features/mining"),
)
# `loop-stake` is non-executable as a whole page, so it owns no amount field
# and no signing entry; `launch-trade` keeps its form but never opens one.
S7_NON_EXECUTABLE_PATH = Path("lib/features/launch/launch_action_screens.dart")
S7_SIGNING_MARKERS = ("showLoopSignSheet", "LoopSignSheet", "SigningIntent")
S5_TOKEN_SURFACE_PATH = Path("lib/features/market/token_screen.dart")
S5_SWAP_GATE = "if (detail.capability.swappable)"
S5_SWAP_ENTRY_KEY = "'token-swap-entry'"
# The Token Card's own 买入 / 卖出 segments are the prototype's first-screen
# action row (audit 2026-09-21 §G.2). They must be shut by the same one gate
# the entry button below them is shut by, so the page reads `swappable` in
# exactly these two places and nowhere else.
S5_SWAP_CARD_GATE = "tradable: detail?.capability.swappable ?? false,"
S5_QR_ENCODER_PATH = Path("lib/core/qr/loop_qr_code.dart")
S5_QR_ENCODER_IMPORTS = frozenset({"'package:flutter/foundation.dart'"})
S5_HYPERLIQUID_IMPORT_ROOT = "package:loop_mobile/integrations/hyperliquid/"
# `lib/features/perp/**` is retained, unmounted history for the same reason the
# Hyperliquid adapters are: no product route reaches it. It may keep its
# imports; nothing that is mounted may.
S5_HYPERLIQUID_UNMOUNTED_EXEMPT_ROOT = Path("lib/features/perp")
PRODUCTION_FIXTURE_MARKERS = (
    "MemoryCommunicationGateway(",
    "MemoryPrivacyGateway",
    "MemoryProfileGateway",
    # Step 5 retired the Preview Watchlist and notification-preference adapters
    # (decision 0057); both classes are deleted, so there is no fixture left to
    # keep out of the production composition root.
    "HyperliquidFixtureAdapter(",
    "PrivyFixtureAdapter(",
)
WATCHLIST_GATEWAY_PATH = Path(
    "lib/features/market/watchlist/watchlist_gateway.dart"
)
WATCHLIST_MODELS_PATH = Path(
    "lib/features/market/watchlist/watchlist_models.dart"
)
# Step 5 retired the Preview Watchlist adapter; `main_preview.dart` no longer
# composes one and the Watchlist surface is unavailable in Preview rather than
# showing a labelled fixture.
WATCHLIST_VOLATILE_FACT_MEMBER_PATTERN = re.compile(
    r"\b(?:price|markPrice|indexPrice|fundingRate|volume|change|tradable|"
    r"liquidity|riskScore|alertEnabled)\b"
)
PROFILE_GATEWAY_PATH = Path(
    "lib/features/profile/presentation/profile_gateway.dart"
)
PROFILE_MODELS_PATH = Path(
    "lib/features/profile/presentation/profile_models.dart"
)
PROFILE_MEMORY_GATEWAY_PATH = Path(
    "lib/integrations/personalization/memory_profile_gateway.dart"
)
PROFILE_SURFACE_PATH = Path("lib/features/profile/profile_screens.dart")
# Decision 0053: the V2 Profile, Profile edit and Privacy pages.
PROFILE_V2_SURFACE_PATH = Path(
    "lib/features/profile/profile_v2_screens.dart"
)
PROFILE_PREVIEW_ROOT_PATH = Path("lib/main_preview.dart")
PROFILE_MEMORY_CONSTRUCTION_PATTERN = re.compile(r"\bMemoryProfileGateway\s*\(")
PROFILE_MEMORY_REFERENCE_PATTERN = re.compile(r"\bMemoryProfileGateway\b")
PROFILE_CLASS_FIELD_LIST_PATTERN = re.compile(
    r"^(?P<modifiers>(?:(?:static|late|final|const)\s+)*)"
    r"(?P<type>[A-Za-z_]\w*(?:<[^;=]+>)?\??)\s+"
    r"(?P<variables>[\s\S]+);$"
)
PROFILE_CLASS_FIELD_VARIABLE_PATTERN = re.compile(
    r"^(?P<name>[A-Za-z_]\w*)\s*(?:=(?!=|>)[\s\S]*)?$"
)
PROFILE_CLASS_INFERRED_FIELD_PATTERN = re.compile(
    r"^(?P<modifiers>(?:(?:static|late|final|const)\s+)+)"
    r"(?P<name>[A-Za-z_]\w*)\s*=(?!=|>)[\s\S]*;$"
)
PROFILE_POSITIVE_SAVE_PATTERN = re.compile(
    r"\b(?:saved\s+successfully|save\s+(?:successful|succeeded|complete)|"
    r"profile\s+(?:changes?\s+)?(?:saved|updated)|"
    r"alias\s+(?:saved|updated)|changes?\s+(?:saved|applied)|"
    r"(?:profile|alias)\s+(?:save|update)\s+(?:complete|completed))\b",
    re.IGNORECASE,
)
PRIVACY_GATEWAY_PATH = Path(
    "lib/features/profile/privacy/privacy_gateway.dart"
)
PRIVACY_MODELS_PATH = Path("lib/features/profile/privacy/privacy_models.dart")
PRIVACY_MEMORY_GATEWAY_PATH = Path(
    "lib/integrations/personalization/memory_privacy_gateway.dart"
)
PRIVACY_SURFACE_PATH = Path("lib/features/profile/profile_screens.dart")
PRIVACY_PREVIEW_ROOT_PATH = Path("lib/main_preview.dart")
PRIVACY_MEMORY_CONSTRUCTION_PATTERN = re.compile(
    r"\bMemoryPrivacyGateway\s*\("
)
PRIVACY_MEMORY_REFERENCE_PATTERN = re.compile(r"\bMemoryPrivacyGateway\b")
PRIVACY_LEGACY_MARKERS = (
    "_anonymousAlias",
    "_portfolioBroadcast",
    "_allowedGroups",
    "_activityVisible",
    "_positionsVisible",
    "Anonymous chat alias",
    "Portfolio Broadcast",
    "Allowed groups",
    "Trading activity",
    "Open positions",
)
PRIVACY_COPY_PERMISSION_MARKERS = (
    "Save permissions",
    "Revoke all copy permissions",
    "Maximum per copied trade",
    "Daily copied-trade limit",
    "Pause after a sharp loss",
)
PRIVACY_COPY_INTERACTION_PATTERN = re.compile(
    r"\b(?:FilledButton|OutlinedButton|TextButton|ElevatedButton|IconButton|"
    r"FloatingActionButton|CupertinoButton|Switch|SwitchListTile|"
    r"CupertinoSwitch|Checkbox|CheckboxListTile|Radio|RadioListTile|Slider|"
    r"RangeSlider|ChoiceChip|FilterChip|ActionChip|InputChip|TextField|"
    r"TextFormField|Form|SegmentedButton|DropdownButton|DropdownMenu|"
    r"PopupMenuButton|MenuAnchor|GestureDetector|RawGestureDetector|InkWell|"
    r"Dismissible|Listener|MouseRegion|FocusableActionDetector|Shortcuts|"
    r"Actions|"
    r"ScaffoldMessenger|SnackBar|FilteringTextInputFormatter)\b|"
    r"\baction\s*:|\bon[A-Z]\w*\s*:"
)
# Decision 0053: the V2 privacy audience and the four reviewed facets.
PRIVACY_AUDIENCE_WIRE_VALUES = {
    "self": "self",
    "everyone": "everyone",
}
PRIVACY_VISIBILITY_FACETS = (
    "totalAssets",
    "miningPower",
    "communities",
    "tradeHistory",
)
# Decision 0070: the V2 privacy resource also carries the three social
# admission gates. Each is binary but keeps its own open value on the wire,
# and `disabled` is the only closed value for all three.
PRIVACY_SOCIAL_GATES = {
    "friendRequests": "enabled",
    "directMessages": "friends",
    "groupInvites": "friends",
}
PRIVACY_POSITIVE_COMMIT_PATTERN = re.compile(
    r"\b(?:(?:settings?|privacy|preferences?|changes?)\s+(?:are\s+)?"
    r"(?:now\s+)?(?:saved|committed|applied|updated|live)|"
    r"(?:all\s+)?changes?\s+(?:are\s+)?(?:now\s+)?live|"
    r"(?:save|commit|apply|update)\s+"
    r"(?:complete|completed|successful|succeeded)|"
    r"(?:saved|committed|applied|updated)\s+successfully)\b",
    re.IGNORECASE,
)
PRIVACY_POSITIVE_COMMIT_CJK_PATTERN = re.compile(
    r"(?:设置|隐私|偏好|更改|修改|变更).{0,8}"
    r"(?:已保存|保存成功|已提交|提交成功|已应用|应用成功|已更新|更新成功|"
    r"已生效|生效)"
)
# Decision 0053 renamed the V2 privacy evidence: the copy-trade preference
# became an audience enumeration plus four independent visibility facets.
PRIVACY_BEHAVIOR_TEST_MARKERS = {
    Path("test/privacy_models_test.dart"): (
        "uses the exact fail-closed backend defaults",
        "round-trips only the reviewed audience values",
        "exposes exactly the four reviewed visibility facets",
        "enforces the version and timestamp biconditional",
        "keeps contract failures sanitized",
    ),
    Path("test/privacy_controller_test.dart"): (
        "mirrors first-write and identical-retry semantics",
        "production defaults directly unavailable",
        "load and save are single-flight and save complete values",
        "version conflict freezes the draft until reload succeeds",
        "an ambiguous save retries the same version and converges",
        "invalidation and disposal retire late work safely",
    ),
    Path("test/privacy_presentation_screen_test.dart"): (
        "every load failure maps to one honest state, never empty",
        "Preview edits anonymous mode and one facet, then saves once",
        "version conflict preserves every draft field until reload",
        "mounted Privacy replaces the old owner after gateway rotation",
        "Privacy supports a 390pt screen at 2x Dynamic Type",
        "legacy copy-trade controls and permission saves are absent",
    ),
}
# Step 5 retired the V1 four-intent notification-preference module, its Preview
# adapter and its models (decision 0057). `notif-settings` is now the V2
# ten-category page; only its copy contract survives, on the new surface.
NOTIFICATION_PREFERENCES_SURFACE_PATH = Path(
    "lib/features/profile/notification_preferences/notification_preferences_screen.dart"
)
NOTIFICATION_PREFERENCES_LEGACY_MARKERS = (
    "_settings",
    "Orders and fills",
    "Liquidation risk",
    "Community activity",
    "System notices",
    "System notifications are off",
    "Open device settings",
    "Quiet hours",
)
NOTIFICATION_PREFERENCES_POSITIVE_COMMIT_PATTERN = re.compile(
    r"\b(?:(?:notification\s+)?preferences?|notification\s+settings?|changes?)\s+"
    r"(?:(?:are|were)\s+|(?:have|has)\s+been\s+)?(?:now\s+)?"
    r"(?:saved|committed|applied|updated|live)|"
    r"\b(?:save|commit|apply|update)\s+"
    r"(?:complete|completed|successful|succeeded)|"
    r"\b(?:saved|committed|applied|updated)\s+successfully\b|"
    r"\bsuccessfully\s+(?:saved|committed|applied|updated)\b",
    re.IGNORECASE,
)
NOTIFICATION_PREFERENCES_POSITIVE_DELIVERY_PATTERN = re.compile(
    r"\b(?:notification\s+delivery|delivery|notifications?|alerts?)\s+"
    r"(?:is\s+|are\s+)?(?:now\s+)?"
    r"(?:active|available|connected|delivered|enabled|live|working)|"
    r"\b(?:you|users?)\s+(?:can|will)\s+(?:now\s+)?"
    r"(?:receive|be\s+notified)|"
    r"\b(?:notifications?|alerts?)\s+will\s+(?:arrive|be\s+delivered)\b",
    re.IGNORECASE,
)
NOTIFICATION_PREFERENCES_POSITIVE_CJK_PATTERN = re.compile(
    r"(?:通知偏好|通知设置|偏好|设置|修改|更改).{0,8}"
    r"(?:已保存|保存成功|已提交|提交成功|已应用|应用成功|已生效)"
)
NOTIFICATION_PREFERENCES_POSITIVE_DELIVERY_CJK_PATTERN = re.compile(
    r"(?:通知|提醒|推送).{0,8}(?:已开启|已启用|已连接|已送达|将会送达|将收到)"
)
# Decision 0057: `notif-settings` stores an owner intent under a version CAS
# and the server answers with the committed resource. A confirmation that only
# follows that committed resource is a truthful save receipt, so it is allowed
# — but only on a surface that also states, in the same page, that delivery is
# unavailable. A delivery claim stays forbidden either way.
NOTIFICATION_PREFERENCES_COMMIT_EVIDENCE_PATTERNS = (
    # The confirmation is reached only through the boolean the commit returns.
    re.compile(
        r"final\s+(?P<name>\w+)\s*=\s*await\s+controller\.\w+\("
        r"[\s\S]{0,400}?\bif\s*\(\s*(?P=name)\s*\)",
    ),
)
NOTIFICATION_PREFERENCES_DELIVERY_TRUTH_MARKERS = (
    "推送尚不可用",
    "resource.push",
)
# Step 5 retired the V1 four-intent evidence with its module; the V2 page is
# covered by test/s5_watchlist_alerts_notifications_test.dart.
NOTIFICATION_PREFERENCES_BEHAVIOR_TEST_MARKERS = {
    Path("test/s5_watchlist_alerts_notifications_test.dart"): (
        "renders the ten categories with security locked on",
        "a toggle commits under the CAS version with all ten keys",
        "a conflict keeps the page and asks for a reload",
        "delivery is unavailable regardless of the saved intents",
        "an unavailable capability stops the page",
    ),
}
WALLET_PROVIDERLESS_CONTROL_BEHAVIOR_TEST_MARKERS = {
    Path("test/wallet_preview_activity_test.dart"): (
        "each history filter returns only its labelled Preview category",
    ),
    Path("test/app_navigation_test.dart"): (
        "Bridge status is reachable on its own and stays pending",
    ),
    Path("test/s8_deferred_pages_test.dart"): (
        "bridge offers no amount, no route and no fee",
        "bridge-status keeps its skeleton and invents no step",
    ),
}
WALLET_PROVIDERLESS_CONTROL_EXECUTABLE_TEST_EVIDENCE = {
    Path("test/wallet_preview_activity_test.dart"): {
        "each history filter returns only its labelled Preview category": (
            r"\bWalletPreviewActivity\.filteredBy\s*\(",
            r"\bhasLength\s*\(",
            r"\.single\.kind\b",
        ),
    },
    Path("test/app_navigation_test.dart"): {
        "Bridge status is reachable on its own and stays pending": (
            r"\brouter\.go\s*\(",
            # C-19: no step is drawn in any state, so the evidence is the
            # absence of all three, not three pending badges.
            r"for\s*\(\s*final\s+step\s+in\s*<String>\[[\s\S]*?\]\s*\)",
            r"\bfindsNothing\b",
            r"\bfindsOneWidget\b",
        ),
    },
    Path("test/s8_deferred_pages_test.dart"): {
        "bridge offers no amount, no route and no fee": (
            r"\bawait\s+pumpS8Page\s*\(",
            r"\bfind\.byType\s*\(\s*TextField\s*\)\s*,\s*findsNothing",
            r"\bfind\.textContaining\s*\([\s\S]*?\)\s*,\s*findsNothing",
        ),
        "bridge-status keeps its skeleton and invents no step": (
            r"\bawait\s+pumpS8Page\s*\(",
            r"\bfor\s*\(\s*var\s+index\s*=\s*1\s*;",
            r"\bfind\.byKey\s*\([\s\S]*?\)\s*,\s*findsOneWidget",
            r"\bfindsNothing\b",
        ),
    },
}
PERP_POSITIONS_CONTROLLER_PATH = Path(
    "lib/features/perp/positions/perp_positions_controller.dart"
)
PERP_POSITIONS_SURFACE_PATH = Path(
    "lib/features/perp/perp_portfolio_screens.dart"
)
PERP_POSITIONS_BEHAVIOR_TEST_MARKERS = {
    Path("test/perp_positions_controller_test.dart"): (
        "all position reads share one single-flight",
        "initial read uses bounded limit and continuation uses cursor only",
        "malformed dataset coverage and cursor pages clear all facts",
        "expiry clears nonempty and empty position facts",
        "gateway rotation retires late positions from the previous owner",
        "expired load-more releases single-flight for a fresh initial read",
        "wallet binding rejection never attempts a binding mutation",
    ),
    Path("test/perp_positions_screen_test.dart"): (
        "explicit Preview is labelled and performs no private read",
        "production renders Decimal-backed positions without fixture facts",
        "production binding failure links to Perp account without binding",
        "returning from Perp account retries positions without binding",
        "resume clears expired position facts",
        "production D5 fails closed without an ETH fixture",
    ),
}
PERP_POSITIONS_EXECUTABLE_TEST_EVIDENCE = {
    Path("test/perp_positions_controller_test.dart"): {
        "all position reads share one single-flight": (
            r"\bidentical\s*\(\s*first\s*,\s*second\s*\)",
            r"\bidentical\s*\(\s*first\s*,\s*refresh\s*\)",
            r"\bidentical\s*\(\s*firstMore\s*,\s*secondMore\s*\)",
            r"\bidentical\s*\(\s*firstMore\s*,\s*refreshDuringMore\s*\)",
            r"\bexpect\s*\(\s*gateway\.requests\s*,\s*hasLength\s*\(\s*2\s*\)",
        ),
        "initial read uses bounded limit and continuation uses cursor only": (
            r"\bawait\s+fixture\.controller\.load\s*\(",
            r"\bawait\s+fixture\.controller\.loadMore\s*\(",
            r"\bexpect\s*\(\s*gateway\.requests\b",
            r"\blimit\s*:\s*PerpPositionsController\.initialLimit\b",
            r"\blimit\s*:\s*null\b",
        ),
        "malformed dataset coverage and cursor pages clear all facts": (
            r"\bPerpSourceDataset\.account\b",
            r"\bPerpRecentWindowCoverage\s*\(",
            r"\bitems\s*:\s*const\s*<PerpPosition>\[\]\s*,\s*nextCursor\s*:",
            r"\bcursor\s*==\s*null\s*\?[\s\S]*?\bnextCursor\s*:[\s\S]*?"
            r":\s*_page\s*\([\s\S]*?\bnextCursor\s*:",
            r"\.controller\.loadMore\s*\(",
            r"\bPerpGatewayFailureKind\.invalidData\b",
            r"\.state\.items\s*,\s*isEmpty\b",
        ),
        "expiry clears nonempty and empty position facts": (
            r"\bfor\s*\(\s*final\s+items\b",
            r"\bscheduler\.fireNext\s*\(",
            r"\bPerpPositionsPhase\.stale\b",
            r"\.state\.items\s*,\s*isEmpty\b",
            r"\.state\.nextCursor\s*,\s*isNull\b",
        ),
        "gateway rotation retires late positions from the previous owner": (
            r"\.container\.updateOverrides\s*\(",
            r"\boldPage\.complete\s*\(",
            r"\bawait\s+retired\b",
            r"\bPerpCoin\.sol\b",
        ),
        "expired load-more releases single-flight for a fresh initial read": (
            r"\bretiredLoadMore\b",
            r"\.controller\.expireIfNeeded\s*\(",
            r"\.controller\.refresh\s*\(",
            r"\bexpect\s*\(\s*initialCalls\s*,\s*2\s*\)",
            r"\bawait\s+retiredLoadMore\b",
        ),
        "wallet binding rejection never attempts a binding mutation": (
            r"\bPerpGatewayFailureKind\.walletBindingRequired\b",
            r"\bPerpPositionsPhase\.bindingRequired\b",
            r"\bexpect\s*\(\s*gateway\.bindCalls\s*,\s*0\s*\)",
        ),
    },
    Path("test/perp_positions_screen_test.dart"): {
        "explicit Preview is labelled and performs no private read": (
            r"\bpreview\s*:\s*true\b",
            r"\bfind\.byKey\s*\(",
            r"\bexpect\s*\(\s*gateway\.requests\s*,\s*isEmpty\s*\)",
        ),
        "production renders Decimal-backed positions without fixture facts": (
            r"\b_AuthenticatedSession\.new\b",
            r"\b_position\s*\(\s*PerpCoin\.eth\s*\)",
            r"\bPerpPositionsController\.initialLimit\b",
            r"\bfindsOne\b",
            r"\bfindsNothing\b",
        ),
        "production binding failure links to Perp account without binding": (
            r"\bPerpGatewayFailureKind\.walletBindingRequired\b",
            r"\bfind\.byKey\s*\(",
            r"\bexpect\s*\(\s*gateway\.bindCalls\s*,\s*0\s*\)",
        ),
        "returning from Perp account retries positions without binding": (
            r"\bGoRouter\s*\(",
            r"\btester\.tap\s*\(",
            r"\bexpect\s*\(\s*calls\s*,\s*2\s*\)",
            r"\bexpect\s*\(\s*gateway\.bindCalls\s*,\s*0\s*\)",
        ),
        "resume clears expired position facts": (
            r"\bhandleAppLifecycleStateChanged\s*\(\s*AppLifecycleState\.paused",
            r"\bhandleAppLifecycleStateChanged\s*\(\s*AppLifecycleState\.resumed",
            r"\btester\.widget<Semantics>\s*\(",
            r"\.properties\.liveRegion\b",
        ),
        "production D5 fails closed without an ETH fixture": (
            r"\bscreen\s*:\s*const\s+PerpPositionScreen\s*\(",
            r"\bfindsNothing\b",
            r"\bexpect\s*\(\s*gateway\.requests\s*,\s*isEmpty\s*\)",
        ),
    },
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def strip_dart_comments(text: str) -> str:
    """Remove Dart comments while preserving strings and line boundaries."""

    output: list[str] = []
    index = 0
    quote: str | None = None
    triple = False
    while index < len(text):
        if quote is not None:
            closing = quote * (3 if triple else 1)
            if text.startswith(closing, index):
                output.append(closing)
                index += len(closing)
                quote = None
                triple = False
                continue
            character = text[index]
            output.append(character)
            index += 1
            if not triple and character == "\\" and index < len(text):
                output.append(text[index])
                index += 1
            continue

        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            if newline < 0:
                output.extend(" " * (len(text) - index))
                break
            output.extend(" " * (newline - index))
            output.append("\n")
            index = newline + 1
            continue

        if text.startswith("/*", index):
            depth = 1
            output.extend("  ")
            index += 2
            while index < len(text) and depth:
                if text.startswith("/*", index):
                    depth += 1
                    output.extend("  ")
                    index += 2
                elif text.startswith("*/", index):
                    depth -= 1
                    output.extend("  ")
                    index += 2
                else:
                    output.append("\n" if text[index] == "\n" else " ")
                    index += 1
            continue

        if text.startswith("'''", index) or text.startswith('\"\"\"', index):
            quote = text[index]
            triple = True
            output.append(quote * 3)
            index += 3
            continue
        if text[index] in ("'", '"'):
            quote = text[index]
            output.append(text[index])
            index += 1
            continue
        output.append(text[index])
        index += 1
    return "".join(output)


def normalized_dart_source_fingerprint(text: str) -> str:
    """Fingerprint a reviewed Dart slice without comment or layout noise."""

    normalized = re.sub(r"\s+", " ", strip_dart_comments(text)).strip()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def strip_dart_comments_and_strings(text: str) -> str:
    """Remove comments and string bodies before matching executable Dart."""

    source = strip_dart_comments(text)
    output: list[str] = []
    index = 0
    quote: str | None = None
    triple = False
    while index < len(source):
        if quote is not None:
            closing = quote * (3 if triple else 1)
            if source.startswith(closing, index):
                output.extend(" " * len(closing))
                index += len(closing)
                quote = None
                triple = False
                continue
            character = source[index]
            output.append("\n" if character == "\n" else " ")
            index += 1
            if not triple and character == "\\" and index < len(source):
                output.append("\n" if source[index] == "\n" else " ")
                index += 1
            continue

        if source.startswith("'''", index) or source.startswith('\"\"\"', index):
            quote = source[index]
            triple = True
            output.extend("   ")
            index += 3
            continue
        if source[index] in ("'", '"'):
            quote = source[index]
            output.append(" ")
            index += 1
            continue
        output.append(source[index])
        index += 1
    return "".join(output)


def dart_class_fields(
    source: str, class_name: str
) -> set[tuple[str, str, str]] | None:
    """Return class-level Dart field declarations without parsing method locals."""

    class_match = re.search(rf"\bclass\s+{re.escape(class_name)}\b", source)
    if class_match is None:
        return None
    opening = source.find("{", class_match.end())
    if opening < 0:
        return None

    fields: set[tuple[str, str, str]] = set()
    block_depth = 0
    parenthesis_depth = 0
    bracket_depth = 0
    expression_brace_depth = 0
    statement: list[str] = []
    for character in source[opening + 1 :]:
        if block_depth:
            if character == "{":
                block_depth += 1
            elif character == "}":
                block_depth -= 1
            continue

        if character == "(":
            parenthesis_depth += 1
            statement.append(character)
            continue
        if character == ")" and parenthesis_depth:
            parenthesis_depth -= 1
            statement.append(character)
            continue
        if character == "[":
            bracket_depth += 1
            statement.append(character)
            continue
        if character == "]" and bracket_depth:
            bracket_depth -= 1
            statement.append(character)
            continue
        if character == "{":
            if (
                parenthesis_depth
                or bracket_depth
                or expression_brace_depth
                or _has_top_level_assignment("".join(statement))
            ):
                expression_brace_depth += 1
                statement.append(character)
            else:
                block_depth = 1
                statement.clear()
            continue
        if character == "}":
            if expression_brace_depth:
                expression_brace_depth -= 1
                statement.append(character)
                continue
            if parenthesis_depth or bracket_depth:
                statement.append(character)
                continue
            return fields
        statement.append(character)
        if (
            character != ";"
            or parenthesis_depth
            or bracket_depth
            or expression_brace_depth
        ):
            continue

        declaration = _strip_leading_dart_metadata("".join(statement).strip())
        statement.clear()
        fields.update(_parse_dart_field_declaration(declaration))
    return None


def _has_top_level_assignment(source: str) -> bool:
    """Return whether a class member prefix contains a field assignment."""

    parenthesis_depth = 0
    bracket_depth = 0
    for index, character in enumerate(source):
        if character == "(":
            parenthesis_depth += 1
        elif character == ")" and parenthesis_depth:
            parenthesis_depth -= 1
        elif character == "[":
            bracket_depth += 1
        elif character == "]" and bracket_depth:
            bracket_depth -= 1
        elif character == "=" and not parenthesis_depth and not bracket_depth:
            before = source[index - 1] if index else ""
            after = source[index + 1] if index + 1 < len(source) else ""
            if before not in "=!<>" and after not in "=>":
                return True
    return False


def _strip_leading_dart_metadata(declaration: str) -> str:
    """Remove one or more Dart metadata annotations from a declaration."""

    index = 0
    while True:
        while index < len(declaration) and declaration[index].isspace():
            index += 1
        if index >= len(declaration) or declaration[index] != "@":
            return declaration[index:]
        index += 1
        if index >= len(declaration) or not (
            declaration[index].isalpha() or declaration[index] == "_"
        ):
            return declaration
        while index < len(declaration) and (
            declaration[index].isalnum() or declaration[index] in "_."
        ):
            index += 1
        while index < len(declaration) and declaration[index].isspace():
            index += 1
        if index >= len(declaration) or declaration[index] != "(":
            continue
        depth = 1
        index += 1
        while index < len(declaration) and depth:
            if declaration[index] == "(":
                depth += 1
            elif declaration[index] == ")":
                depth -= 1
            index += 1
        if depth:
            return declaration


def _parse_dart_field_declaration(
    declaration: str,
) -> set[tuple[str, str, str]]:
    """Parse explicit or inferred class fields, including variable lists."""

    match = PROFILE_CLASS_FIELD_LIST_PATTERN.fullmatch(declaration)
    if match is not None:
        variables = _split_top_level_commas(match.group("variables"))
        parsed_variables = [
            PROFILE_CLASS_FIELD_VARIABLE_PATTERN.fullmatch(variable.strip())
            for variable in variables
        ]
        if parsed_variables and all(item is not None for item in parsed_variables):
            modifiers = " ".join(match.group("modifiers").split())
            return {
                (modifiers, match.group("type"), item.group("name"))
                for item in parsed_variables
                if item is not None
            }

    inferred = PROFILE_CLASS_INFERRED_FIELD_PATTERN.fullmatch(declaration)
    if inferred is not None:
        return {
            (
                " ".join(inferred.group("modifiers").split()),
                "<inferred>",
                inferred.group("name"),
            )
        }
    return set()


def _split_top_level_commas(source: str) -> list[str]:
    """Split a Dart variable list without splitting collection initializers."""

    parts: list[str] = []
    start = 0
    parenthesis_depth = 0
    bracket_depth = 0
    brace_depth = 0
    angle_depth = 0
    for index, character in enumerate(source):
        if character == "(":
            parenthesis_depth += 1
        elif character == ")" and parenthesis_depth:
            parenthesis_depth -= 1
        elif character == "[":
            bracket_depth += 1
        elif character == "]" and bracket_depth:
            bracket_depth -= 1
        elif character == "{":
            brace_depth += 1
        elif character == "}" and brace_depth:
            brace_depth -= 1
        elif character == "<":
            angle_depth += 1
        elif character == ">" and angle_depth:
            angle_depth -= 1
        elif (
            character == ","
            and not parenthesis_depth
            and not bracket_depth
            and not brace_depth
            and not angle_depth
        ):
            parts.append(source[start:index])
            start = index + 1
    parts.append(source[start:])
    return parts


def dart_concatenated_string_contents(source: str) -> list[str]:
    """Extract Dart string contents, joining compile-time adjacent literals."""

    source = strip_dart_comments(source)
    contents: list[str] = []
    index = 0
    while index < len(source):
        parsed = _parse_dart_string_at(source, index)
        if parsed is None:
            index += 1
            continue
        content, index = parsed
        while True:
            candidate = index
            while candidate < len(source) and source[candidate].isspace():
                candidate += 1
            adjacent = _parse_dart_string_at(source, candidate)
            if adjacent is None:
                break
            adjacent_content, index = adjacent
            content += adjacent_content
        contents.append(content)
    return contents


def _parse_dart_string_at(source: str, index: int) -> tuple[str, int] | None:
    """Parse one raw or regular Dart string literal at an exact offset."""

    raw = False
    if (
        index + 1 < len(source)
        and source[index] in "rR"
        and source[index + 1] in "'\""
        and (
            index == 0
            or not (source[index - 1].isalnum() or source[index - 1] == "_")
        )
    ):
        raw = True
        index += 1
    if index >= len(source) or source[index] not in "'\"":
        return None

    quote = source[index]
    triple = source.startswith(quote * 3, index)
    closing = quote * (3 if triple else 1)
    index += len(closing)
    content: list[str] = []
    while index < len(source):
        if source.startswith(closing, index):
            rendered = "".join(content)
            if not raw:
                rendered = _decode_dart_string_escapes(rendered)
            return rendered, index + len(closing)
        character = source[index]
        if not raw and character == "\\" and index + 1 < len(source):
            content.extend((character, source[index + 1]))
            index += 2
            continue
        content.append(character)
        index += 1
    return None


def _decode_dart_string_escapes(content: str) -> str:
    """Decode the bounded Dart escapes relevant to visible guard language."""

    decoded: list[str] = []
    index = 0
    simple = {
        "n": "\n",
        "r": "\r",
        "t": "\t",
        "b": "\b",
        "f": "\f",
        "v": "\v",
        "\\": "\\",
        "'": "'",
        '"': '"',
        "$": "$",
    }
    while index < len(content):
        if content[index] != "\\" or index + 1 >= len(content):
            decoded.append(content[index])
            index += 1
            continue
        marker = content[index + 1]
        if marker in simple:
            decoded.append(simple[marker])
            index += 2
            continue
        if marker == "x" and index + 3 < len(content):
            digits = content[index + 2 : index + 4]
            if re.fullmatch(r"[0-9A-Fa-f]{2}", digits):
                decoded.append(chr(int(digits, 16)))
                index += 4
                continue
        if marker == "u":
            if index + 2 < len(content) and content[index + 2] == "{":
                closing = content.find("}", index + 3)
                digits = content[index + 3 : closing] if closing >= 0 else ""
                if re.fullmatch(r"[0-9A-Fa-f]{1,6}", digits):
                    code_point = int(digits, 16)
                    if code_point <= 0x10FFFF:
                        decoded.append(chr(code_point))
                        index = closing + 1
                        continue
            elif index + 5 < len(content):
                digits = content[index + 2 : index + 6]
                if re.fullmatch(r"[0-9A-Fa-f]{4}", digits):
                    decoded.append(chr(int(digits, 16)))
                    index += 6
                    continue
        decoded.extend(("\\", marker))
        index += 2
    return "".join(decoded)


def contains_positive_profile_save_language(source: str) -> bool:
    """Detect only positive, user-visible Profile save evidence strings."""

    for content in dart_concatenated_string_contents(source):
        normalized = " ".join(content.split())
        if normalized.casefold().rstrip(".!?…") == "saved":
            return True
        if PROFILE_POSITIVE_SAVE_PATTERN.search(normalized):
            return True
    return False


def contains_positive_privacy_commit_language(source: str) -> bool:
    """Detect only positive, user-visible Privacy commit evidence strings."""

    for content in dart_concatenated_string_contents(source):
        normalized = " ".join(content.split())
        normalized_word = normalized.casefold().rstrip(".!?…")
        if normalized_word in {
            "saved",
            "committed",
            "applied",
            "success",
            "successful",
            "保存成功",
        }:
            return True
        if PRIVACY_POSITIVE_COMMIT_PATTERN.search(normalized):
            return True
        if PRIVACY_POSITIVE_COMMIT_CJK_PATTERN.search(normalized):
            return True
    return False


# Step 5 retired `dart_enum_members` / `dart_enum_wire_mappings` with the V1
# notification-preference models they read; the V2 wire enums live behind the
# strict transports in `lib/integrations/backend/v2/`, not in a feature module.


def contains_positive_notification_delivery_language(source: str) -> bool:
    """Reject any claim that a notification was, or will be, delivered."""

    for content in dart_concatenated_string_contents(source):
        normalized = " ".join(content.split())
        normalized_word = normalized.casefold().rstrip(".!?…")
        if normalized_word in {
            "delivered",
            "delivery connected",
            "notifications enabled",
        }:
            return True
        if NOTIFICATION_PREFERENCES_POSITIVE_DELIVERY_PATTERN.search(normalized):
            return True
        if NOTIFICATION_PREFERENCES_POSITIVE_DELIVERY_CJK_PATTERN.search(
            normalized
        ):
            return True
    return False


def contains_positive_notification_preferences_commit_language(
    source: str,
) -> bool:
    """Detect a positive, user-visible save claim for the preference resource."""

    for content in dart_concatenated_string_contents(source):
        normalized = " ".join(content.split())
        normalized_word = normalized.casefold().rstrip(".!?…")
        if normalized_word in {"saved", "committed", "applied", "保存成功"}:
            return True
        if NOTIFICATION_PREFERENCES_POSITIVE_COMMIT_PATTERN.search(normalized):
            return True
        if NOTIFICATION_PREFERENCES_POSITIVE_CJK_PATTERN.search(normalized):
            return True
    return False


def notification_preferences_commit_evidence(source: str) -> bool:
    """Report whether a save claim is bound to a committed server resource.

    A toast that fires unconditionally would announce a stored intent. One
    that is reachable only through the boolean a compare-and-set commit
    returns — on a page that also states delivery is unavailable — reports the
    resource the server committed, which is what happened.
    """

    executable = strip_dart_comments(source)
    if not all(
        pattern.search(executable) is not None
        for pattern in NOTIFICATION_PREFERENCES_COMMIT_EVIDENCE_PATTERNS
    ):
        return False
    return all(
        marker in executable
        for marker in NOTIFICATION_PREFERENCES_DELIVERY_TRUTH_MARKERS
    )


def check_behavior_test_evidence(
    root: Path, markers_by_path: dict[Path, tuple[str, ...]]
) -> list[str]:
    """Require named tests to contain executable assertions, not marker constants."""

    errors: list[str] = []
    for relative, markers in markers_by_path.items():
        path = root / relative
        if not path.is_file():
            continue
        source = strip_dart_comments(read_text(path))
        test_starts = [
            match.start() for match in re.finditer(r"\btest(?:Widgets)?\s*\(", source)
        ]
        missing: list[str] = []
        for marker in markers:
            declaration = re.search(
                r"\btest(?:Widgets)?\s*\(\s*(['\"])"
                + re.escape(marker)
                + r"\1\s*,",
                source,
                re.DOTALL,
            )
            if declaration is None:
                missing.append(marker)
                continue
            next_test = next(
                (start for start in test_starts if start > declaration.start()),
                len(source),
            )
            executable_test = strip_dart_comments_and_strings(
                source[declaration.end() : next_test]
            )
            if re.search(r"\bexpect(?:Later)?\s*\(", executable_test) is None:
                missing.append(marker + " (no assertion)")
        if missing:
            errors.append(
                f"{relative} is missing required behavior evidence: "
                + ", ".join(missing)
            )
    return errors


def check_named_executable_test_evidence(
    root: Path,
    patterns_by_path: dict[Path, dict[str, tuple[str, ...]]],
) -> list[str]:
    """Require each named test to execute domain-specific contract evidence."""

    errors: list[str] = []
    for relative, patterns_by_marker in patterns_by_path.items():
        path = root / relative
        if not path.is_file():
            continue
        source = strip_dart_comments(read_text(path))
        test_starts = [
            match.start() for match in re.finditer(r"\btest(?:Widgets)?\s*\(", source)
        ]
        for marker, patterns in patterns_by_marker.items():
            declaration = re.search(
                r"\btest(?:Widgets)?\s*\(\s*(['\"])"
                + re.escape(marker)
                + r"\1\s*,",
                source,
                re.DOTALL,
            )
            if declaration is None:
                continue
            next_test = next(
                (start for start in test_starts if start > declaration.start()),
                len(source),
            )
            executable_test = strip_dart_comments_and_strings(
                source[declaration.end() : next_test]
            )
            missing = [
                pattern
                for pattern in patterns
                if re.search(pattern, executable_test, re.DOTALL) is None
            ]
            if missing:
                errors.append(
                    f"{relative} test `{marker}` lacks executable contract "
                    "evidence: "
                    + ", ".join(missing)
                )
    return errors


def git_visible_paths(root: Path) -> tuple[list[Path], str | None]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        return [], result.stderr.decode("utf-8", errors="replace").strip()
    return [
        Path(item.decode("utf-8", errors="surrogateescape"))
        for item in result.stdout.split(b"\0")
        if item
    ], None


def load_profile(root: Path) -> tuple[dict[str, Any] | None, list[str]]:
    path = root / "harness.json"
    if not path.is_file():
        return None, ["missing required harness file: harness.json"]
    try:
        value = json.loads(read_text(path))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return None, [f"harness.json is not valid UTF-8 JSON: {error}"]
    if not isinstance(value, dict):
        return None, ["harness.json must contain a JSON object"]
    return value, []


def check_required_files(root: Path) -> list[str]:
    return [f"missing required harness file: {path}" for path in REQUIRED_FILES if not (root / path).is_file()]


def check_profile(root: Path, profile: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if type(profile.get("schema_version")) is not int or profile.get("schema_version") != 1:
        errors.append("harness.json `schema_version` must be 1")

    project = profile.get("project")
    application = profile.get("application")
    verification = profile.get("verification")
    commands = profile.get("commands")
    if not isinstance(project, dict):
        return errors + ["harness.json `project` must be an object"]
    if not isinstance(application, dict):
        return errors + ["harness.json `application` must be an object"]
    if not isinstance(verification, dict):
        return errors + ["harness.json `verification` must be an object"]
    if not isinstance(commands, dict):
        return errors + ["harness.json `commands` must be an object"]

    if project.get("phase") != "active":
        errors.append("harness.json project phase must remain `active`")
    purpose = project.get("purpose")
    if not isinstance(purpose, str) or not purpose.strip():
        errors.append("harness.json project purpose must be non-empty")
    if project.get("primary_destinations") != PRIMARY_DESTINATIONS:
        errors.append(
            "harness.json must preserve Community / Mining / Launch / Market / Wallet in order"
        )

    for field in ("ownership_boundaries",):
        value = project.get(field)
        if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item for item in value):
            errors.append(f"harness.json project `{field}` must be a non-empty string list")

    for field in ("stack", "package_managers", "manifests", "lockfiles", "source_roots", "generated_paths"):
        value = application.get(field)
        if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item for item in value):
            errors.append(f"harness.json application `{field}` must be a non-empty string list")

    for field in ("manifests", "lockfiles", "source_roots"):
        values = application.get(field)
        if isinstance(values, list):
            for value in values:
                if isinstance(value, str) and not (root / value).exists():
                    errors.append(f"registered application path does not exist: {value}")

    expected_commands = {
        "setup": "bin/flutter pub get",
        "lint": "bin/dart format --output=none --set-exit-if-changed lib test",
        "typecheck": "bin/flutter analyze",
        "test": "bin/flutter test",
        "build": "bin/flutter build apk --debug",
        "run": "bin/flutter run",
        "cleanup": "bin/flutter clean",
    }
    for name, expected in expected_commands.items():
        if commands.get(name) != expected:
            errors.append(f"harness.json `commands.{name}` must equal `{expected}`")

    expected_verification = {
        "routine_native_gate": "bin/flutter build apk --debug",
        "routine_build_frequency": "feature_checkpoint_only",
        "release_matrix": "explicit_user_request_only",
        "device_validation": "user_owned",
        "retain_build_artifacts": False,
    }
    if verification != expected_verification:
        errors.append(
            "harness.json verification policy must keep routine native "
            "verification Android Debug-only and release/device checks manual"
        )

    expected_manual_native = [
        "bin/flutter build apk --release",
        "bin/flutter build ios --debug --no-codesign",
        "bin/flutter build ios --release --no-codesign",
    ]
    if "native_release_matrix" in commands:
        errors.append(
            "harness.json must not expose an automatic native release matrix"
        )
    if commands.get("manual_release_matrix") != expected_manual_native:
        errors.append("harness.json manual release matrix has drifted")
    expected_harness = [
        "python3 scripts/check_harness.py",
        "python3 -m unittest discover -s tests -p 'test_*.py'",
    ]
    if commands.get("harness") != expected_harness:
        errors.append("harness.json harness command contract has drifted")
    return errors


def lockfile_versions(text: str) -> dict[str, str]:
    versions: dict[str, str] = {}
    current: str | None = None
    for line in text.splitlines():
        package = re.fullmatch(r"  ([a-z0-9_]+):", line)
        if package:
            current = package.group(1)
            continue
        version = re.fullmatch(r'    version: "([^"]+)"', line)
        if current and version:
            versions[current] = version.group(1)
            current = None
    return versions


def check_dependency_pins(root: Path) -> list[str]:
    errors: list[str] = []
    pubspec = root / "pubspec.yaml"
    lockfile = root / "pubspec.lock"
    if not pubspec.is_file():
        return errors
    text = read_text(pubspec)
    for package, version in PINNED_DEPENDENCIES.items():
        if not re.search(rf"^  {re.escape(package)}: {re.escape(version)}$", text, re.MULTILINE):
            errors.append(f"pubspec.yaml must pin `{package}` exactly to `{version}`")
    if "sdk: '>=3.13.1 <4.0.0'" not in text:
        errors.append("pubspec.yaml must require Dart >=3.13.1 <4.0.0")
    if "enable-swift-package-manager: false" not in text:
        errors.append("pubspec.yaml must disable Swift Package Manager per project")
    sqlite_system_hook = re.compile(
        r"^hooks:\n"
        r"  user_defines:\n"
        r"    sqlite3:\n"
        r"      source: system$",
        re.MULTILINE,
    )
    if not sqlite_system_hook.search(text):
        errors.append(
            "pubspec.yaml must use the locked sqlite3 system-source hook"
        )

    if lockfile.is_file():
        versions = lockfile_versions(read_text(lockfile))
        for package, version in PINNED_DEPENDENCIES.items():
            if versions.get(package) != version:
                errors.append(f"pubspec.lock must resolve `{package}` to `{version}`, found `{versions.get(package)}`")
        for package, version in PINNED_SQLITE_GRAPH.items():
            if versions.get(package) != version:
                errors.append(
                    "pubspec.lock must preserve sqlite compatibility package "
                    f"`{package}` at `{version}`, found `{versions.get(package)}`"
                )
    return errors


SPOT_ONLY_PRIMARY_PATHS = (
    # Step 5 deleted the Home slice outright (decision 0057).
    # Step 5 retired `wallet_overview_screens.dart`; the mounted Wallet pages
    # are the V2 read-only screens.
    "lib/features/wallet/wallet_read_screens.dart",
    "lib/features/market/market_screen.dart",
    "lib/features/market/token_screen.dart",
    "lib/features/profile/profile_screens.dart",
)


def check_spot_only_product_contract(root: Path) -> list[str]:
    errors = require_fragments(
        root,
        {
            "lib/app/app_environment.dart": (
                "static const perpetualsEnabled = false;",
                "static const spotExecutionEnabled = false;",
            ),
            # Step 5 retired the mounted Hyperliquid Spot Market screens and
            # the `SpotMarketRoute` identity (decision 0057). The mounted
            # market slice is the V2 BSC read surface and its only route
            # identity is the canonical CAIP `assetId`.
            "lib/core/navigation/market_asset_route.dart": (
                "static const String tokenPath = '/market/token';",
                "static const String assetParameter = 'assetId';",
                "throw ArgumentError.value",
            ),
            "lib/app.dart": (
                "path: MarketAssetRoute.tokenPath",
                "assetId: MarketAssetRoute.parse(",
                "_pendingManifestRoutes",
                "routingErrors.record(state.uri.toString())",
            ),
            "lib/main.dart": (
                "child: const LoopApp(),",
            ),
            "lib/integrations/hyperliquid/hyperliquid_spot_market_repository.dart": (
                "api.hyperliquid-testnet.xyz",
                "'type': 'spotMetaAndAssetCtxs'",
            ),
            "lib/main_preview.dart": (
                "developmentPreviewEnabledProvider.overrideWithValue(true)",
                "MemoryCommunicationGateway()",
            ),
            "test/development_preview_experience_test.dart": (
                # Step 5 dropped the live-Spot half of this test with the
                # mounted Hyperliquid market slice; the offline Chat half is
                # the surviving Preview evidence.
                "explicit Preview opens an interactive offline Chat",
            ),
            "test/hyperliquid_spot_market_repository_test.dart": (
                "joins sparse tokens and shuffled",
                "contexts by provider coin",
            ),
            # Step 5 retired the Spot-detail evidence with its screen; the
            # mounted market pages are covered by test/s5_market_pages_test.dart.
            "test/s5_market_pages_test.dart": (
                "a malformed route identity fails closed",
                "go_router hands the page back the exact CAIP identity",
            ),
            "test/app_navigation_test.dart": (
                # Step 5 retired the Spot-ledger walk with the screens it drove.
                "retained Perp paths are unmounted and fall back to Community with a logged error",
            ),
            "test/route_manifest_test.dart": (
                "manifest keeps every retired Perp path unmounted",
            ),
        },
    )

    for relative in SPOT_ONLY_PRIMARY_PATHS:
        path = root / relative
        if path.is_file() and "/perp" in read_text(path):
            errors.append(
                f"{relative} must not mount a retained Perp product route"
            )

    # Step 5 retired the `LegacyPerpetualMarketScreen` boundary with
    # `market_screens.dart`; the mounted Market files are listed in
    # SPOT_ONLY_PRIMARY_PATHS and carry no Perp route at all.

    app_path = root / "lib/app.dart"
    if app_path.is_file():
        source = read_text(app_path)
        for marker in (
            "features/perp/perp.dart",
            "PerpMarketScreen(",
            "PerpTradeScreen(",
            "PerpConfirmScreen(",
            "PerpPositionsScreen(",
            "PerpPositionScreen(",
            "PerpOrdersScreen(",
            "PerpHistoryScreen(",
            "PerpAccountScreen(",
            "PerpTransferScreen(",
            "PerpDepositScreen(",
            "PerpFundingScreen(",
            "PerpRiskScreen(",
            # Step 5 retired the providerless token Preview route;
            # `TokenDetailScreen` is now the mounted V2 token page.
        ):
            if marker in source:
                errors.append(
                    "lib/app.dart must redirect retained Perp and providerless "
                    f"token routes without mounting `{marker}`"
                )

    main_path = root / "lib/main.dart"
    if main_path.is_file():
        source = read_text(main_path)
        for marker in (
            "perpPrivateGatewayProvider",
            "loopPerpSessionProvider",
            "features/perp/",
            "loop_perp_providers.dart",
        ):
            if marker in source:
                errors.append(
                    "lib/main.dart must not compose retained Perp capability "
                    f"`{marker}`"
                )

    manifest_path = root / "lib/core/navigation/route_manifest.dart"
    if manifest_path.is_file():
        manifest_source = strip_dart_comments(read_text(manifest_path))
        retired_start = manifest_source.find("static const List<String> retiredPaths")
        retired_end = manifest_source.find("];", retired_start)
        retired_block = manifest_source[retired_start:retired_end]
        retired_perp = len(re.findall(r"'/perp(?:/[a-z-]+)?'", retired_block))
        if retired_start < 0 or retired_perp != 12:
            errors.append(
                "Route manifest must list exactly 12 retired Perp paths as "
                f"unmounted history, found {retired_perp}"
            )
        mounted_block = manifest_source[:retired_start] + manifest_source[retired_end:]
        if "'/perp" in mounted_block:
            errors.append(
                "Route manifest must not map any slug or supplementary route to a Perp path"
            )
    if app_path.is_file() and "'/perp" in strip_dart_comments(read_text(app_path)):
        errors.append(
            "lib/app.dart must redirect retained Perp routes through the unmatched "
            "handler; no `/perp` path may be mounted or redirected"
        )

    # Step 5 deleted the Home slice, so the rule that it may not link to a
    # token route has no subject left. The file must not come back: Home, a
    # standalone notification centre and the Home security page are product
    # red lines, and their three locations stay in `retiredPaths`.
    if (root / "lib/features/home/home_screens.dart").is_file():
        errors.append(
            "lib/features/home/home_screens.dart is retired (decision 0057) and "
            "must not be restored"
        )

    # Only the canonical route contract may build a token location.
    market_root = root / "lib/features/market"
    if market_root.is_dir():
        for path in sorted(market_root.rglob("*.dart")):
            source = strip_dart_comments(read_text(path))
            if re.search(r"(?P<quote>['\"])/market/(?:token|chart)", source):
                errors.append(
                    f"{path.relative_to(root)} must build token locations through "
                    "MarketAssetRoute, never a raw path literal"
                )
    return errors


# Step 5 retired the C10 Preview fixture slice with `market_screens.dart`
# (decision 0057): `new-pairs` is now a whole-page unavailable projection that
# renders the server's own `reasonCode`, so there is no Preview pair, fixture
# age, quick-action rail or Preview-session selector left to fingerprint.


def check_new_pairs_preview_truth_contract(root: Path) -> list[str]:
    """Keep C10 sourceless: whole-page unavailable with the server's reason."""

    errors = require_fragments(
        root,
        {
            "lib/features/market/market_secondary_screens.dart": (
                "class NewPairsScreen",
                "marketNewPairsControllerProvider",
                "MarketNewPairsUnavailable",
            ),
            "lib/app.dart": (
                "path: '/market/new'",
                "NewPairsScreen(onBack: () => _popOrHome(context))",
            ),
            "lib/core/navigation/surface_catalog.dart": (
                "id: 'C10'",
                "Production waits for a reviewed listing-time source; static pairs remain exact-Preview only.",
            ),
            "test/s5_market_pages_test.dart": (
                "new-pairs is a whole-page unavailable with the reason",
                "smart-money never lists an address or a win rate",
            ),
            "AGENTS.md": (
                "Keep `new-pairs` and `smart-money` source-scoped.",
                "Client receipt time, first local observation, volume and canonical status never prove listing time or newness",
            ),
            "README.md": (
                "C10 New Pairs 已关闭正式会话中的演示事实泄漏",
                "公开 Spot 快照不包含 listing time",
            ),
            "docs/product/implementation-constraints.md": (
                "C10 New Pairs is unknown without a reviewed listing-time source.",
                "Only the exact Development Preview session may render its static pair and fixture-age examples.",
            ),
            "docs/product-decisions.md": (
                "C10 New Pairs has no approved listing-time source.",
                "The public Spot snapshot cannot establish that a pair is new.",
            ),
            "docs/decisions/0038-bound-new-pairs-to-exact-preview.md": (
                "# 0038 Bound New Pairs to Exact Preview",
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "## Evidence",
                "does not include listing time",
                "zero market and candle repository requests",
            ),
            "docs/failures/providerless-new-pairs-facts.md": (
                "# Providerless New Pairs Facts",
                "## Summary",
                "## Root Cause",
                "## Detection",
                "## Prevention",
                "## Evidence",
                "authenticated production sessions",
                "exact Preview session",
            ),
            "docs/harness/adoption-report.md": (
                "## New Pairs Exact-Preview Truth Boundary",
            ),
            "docs/phase-1/frontend-integration-report.md": (
                "## New Pairs Exact-Preview Truth Boundary",
            ),
        },
    )

    # Step 5 retired the C10 Preview slice: `market_screens.dart` and every
    # fixture pair, fixture age, quick-action rail and Preview-session
    # selector it carried are gone, so their reviewed source fingerprints
    # are retired with them.

    app_path = root / "lib/app.dart"
    if app_path.is_file():
        source = read_text(app_path)
        route_start = source.find("      GoRoute(\n        path: '/market/new',")
        route_end = source.find(
            "      GoRoute(\n        path: MarketAssetRoute.holdersPath,",
            route_start + 1,
        )
        if route_start < 0 or route_end < 0:
            errors.append("C10 must retain one bounded reviewed application route")
        else:
            route_source = source[route_start:route_end]
            for forbidden in (
                "state.extra",
                "queryParameters",
                "snapshotState",
                "MarketSnapshotState",
                "enterPreview(",
            ):
                if forbidden in route_source:
                    errors.append(
                        "C10 route must not inject Preview or recover fixture "
                        f"identity from `{forbidden}`"
                    )

    # Step 5 retired the Preview C10 evidence with the slice it exercised; the
    # mounted unavailable page is covered by test/s5_market_pages_test.dart.
    return errors


CHAT_SPOT_SNAPSHOT_TEST_MARKERS = {
    Path("test/chat_spot_snapshot_test.dart"): (
        "chat preview asset snapshot is spot-only and labels fixture facts",
        "chat preview spot card opens the public Spot market ledger",
        "chat Spot snapshot supports 390pt at 2x Dynamic Type",
    ),
}
CHAT_SPOT_SNAPSHOT_SOURCE_FINGERPRINTS = {
    "card": "e2adf5c9590d6c07bcc023439952cbbe9317ec642eeddef8a4ca9f3b6de7634c",
    "page": "3ef6f193083f4c829553570849783cf9fa515a8d721fc3f1ebf93dd3d8c69e7d",
    "content": "3137b2ee53f05f1399452dc235a3ead721603cd7f86e46300fecad9aa33044cd",
    "test": "1b0ceb55baafa0f6ff2ea5a8784dc656f7f34229b8bc9c37d01aa1ce69894fc0",
}


def check_chat_spot_snapshot_contract(root: Path) -> list[str]:
    """Keep the reachable E9 Chat fixture labelled, Spot-only, and non-mutating."""

    errors = require_fragments(
        root,
        {
            "lib/features/chat/widgets/chat_components.dart": (
                "ValueKey<String>('chat-spot-snapshot-semantics')",
                "ValueKey<String>('chat-spot-snapshot-card')",
                "label: 'ETH Spot market snapshot · 开发预览'",
                "'ETH spot market snapshot'",
                "'Shared at 14:12 · 演示数据'",
                "label: 'SPOT PREVIEW'",
                "ValueKey<String>('chat-spot-market-entry')",
                "onPressed: () => context.go('/market')",
                "label: const Text('Open Spot markets')",
                "ValueKey<String>('chat-spot-watch-unavailable')",
                "label: const Text('Watch unavailable')",
            ),
            "lib/features/chat/chat_preview_pages.dart": (
                "title: 'Spot market snapshot'",
                "Shared in chat · 开发预览",
                "const LoopContextRail(stage: LoopStage.discuss, compact: true)",
                "Reference price, 24h change, and volume are labelled 演示数据.",
                "LoopKeyValueRow(label: 'Market type', value: 'Spot')",
            ),
            "lib/features/chat/chat_content.dart": (
                "Weekly spot market roundtable",
                "transfer alerts are not connected in this preview.",
            ),
            "lib/core/navigation/surface_catalog.dart": (
                "A labelled Spot market Preview with no account, position, or execution meaning.",
            ),
            "test/chat_spot_snapshot_test.dart": (
                "chat preview asset snapshot is spot-only and labels fixture facts",
                "chat preview spot card opens the public Spot market ledger",
                "chat Spot snapshot supports 390pt at 2x Dynamic Type",
                "find.text('ETH position snapshot'), findsNothing",
                "find.text('Save setup'), findsNothing",
                "expect(semantics.properties.label, 'ETH Spot market snapshot · 开发预览')",
                "expect(watchButton.onPressed, isNull)",
                "find.byKey(const ValueKey<String>('public-spot-market-ledger'))",
                "TextScaler.linear(textScale)",
                "expect(tester.takeException(), isNull)",
            ),
            "test/chat_preview_route_guard_test.dart": (
                "production legacy Chat routes never mount preview fixtures",
                "'/preview/asset-message'",
                "find.byKey(const ValueKey<String>('chat-preview-route-blocked'))",
            ),
            "docs/product/implementation-constraints.md": (
                "The legacy E9 asset-message fixture is a visibly labelled Spot market Preview only.",
                "Its only enabled action opens the public Spot market ledger",
            ),
            "docs/decisions/0016-make-primary-market-spot-only.md": (
                "## Chat Preview Closure",
                "opens the public Spot market ledger at `/market`",
            ),
            "docs/failures/perp-semantics-in-chat-preview.md": (
                "## Root Cause",
                "## Detection",
                "## Prevention",
                "## Evidence",
            ),
        },
    )

    component_path = root / "lib/features/chat/widgets/chat_components.dart"
    page_path = root / "lib/features/chat/chat_preview_pages.dart"
    guarded_slices: list[tuple[str, str]] = []
    card_source = ""
    if component_path.is_file():
        source = strip_dart_comments(read_text(component_path))
        start = source.find("class AssetSnapshotMessageCard")
        end = source.find("class ChatComposer", start + 1)
        if start < 0 or end < 0:
            errors.append(
                "Chat E9 must retain one bounded AssetSnapshotMessageCard implementation"
            )
        else:
            card_source = source[start:end]
            guarded_slices.append((str(component_path.relative_to(root)), card_source))
            if normalized_dart_source_fingerprint(card_source) != (
                CHAT_SPOT_SNAPSHOT_SOURCE_FINGERPRINTS["card"]
            ):
                errors.append(
                    "Chat Spot Preview card must match its reviewed closed-source fingerprint"
                )

            executable_card = strip_dart_comments_and_strings(card_source)
            expected_component_calls = frozenset(
                {
                    "AssetSnapshotMessageCard",
                    "Column",
                    "EdgeInsets.all",
                    "Expanded",
                    "Icon",
                    "LayoutBuilder",
                    "LoopAssetMark",
                    "LoopCard",
                    "LoopMetric",
                    "LoopMiniChart",
                    "LoopStatusPill",
                    "MediaQuery.textScalerOf",
                    "OutlinedButton.icon",
                    "Row",
                    "Semantics",
                    "SizedBox",
                    "Text",
                    "Theme.of",
                    "ValueKey",
                    "_SpotSnapshotMetrics",
                }
            )
            component_calls = frozenset(
                re.findall(
                    r"\b([A-Z_]\w*(?:\.[A-Za-z_]\w*)?)"
                    r"\s*(?:<[^(){};]+>)?\s*\(",
                    executable_card,
                )
            )
            bare_lower_calls = frozenset(
                re.findall(
                    r"(?<![.\w])([a-z_]\w*)\s*(?:<[^(){};]+>)?\s*\(",
                    executable_card,
                )
            )
            qualified_lower_calls = frozenset(
                re.findall(
                    r"\b([a-z_]\w*\.[a-z_]\w*)\s*\(", executable_card
                )
            )
            chained_calls = frozenset(
                re.findall(r"\)\s*\.\s*([a-z_]\w*)\s*\(", executable_card)
            )
            if (
                component_calls != expected_component_calls
                or not bare_lower_calls.issubset(
                    {"build", "for", "if", "_SpotSnapshotMetrics"}
                )
                or not qualified_lower_calls.issubset({"context.go"})
                or not chained_calls.issubset({"scale"})
            ):
                errors.append(
                    "Chat Spot Preview composition must stay closed over its approved non-interactive component set"
                )
            callback_properties = re.findall(
                r"\b(on[A-Z]\w*)\s*:", executable_card
            )
            if callback_properties != ["onPressed", "onPressed"]:
                errors.append(
                    "Chat Spot Preview must own exactly one Market action and one disabled Watch control without another interaction callback"
                )
            forbidden_interactive_widgets = (
                "GestureDetector(",
                "InkWell(",
                "InkResponse(",
                "Listener(",
                "MouseRegion(",
                "Dismissible(",
                "Draggable(",
                "LongPressDraggable(",
                "Shortcuts(",
                "Actions(",
                "FocusableActionDetector(",
            )
            if any(
                marker in executable_card for marker in forbidden_interactive_widgets
            ):
                errors.append(
                    "Chat Spot Preview cannot add a second gesture, keyboard, pointer, or dismiss action"
                )
            if card_source.count("context.go('/market')") != 1:
                errors.append(
                    "Chat Spot Preview must navigate to the public `/market` ledger exactly once"
                )
            if any(
                marker in card_source
                for marker in (
                    "context.push(",
                    "context.push<",
                    "SpotMarketRoute.location(",
                    "/market/token",
                    "_showNotice(",
                )
            ):
                errors.append(
                    "Chat Spot Preview Market entry cannot invent a detail route, execute, or become a notice-only action"
                )
            watch_pattern = re.compile(
                r"ValueKey<String>\('chat-spot-watch-unavailable'\)"
                r"[\s\S]{0,180}?onPressed:\s*null\b"
            )
            if watch_pattern.search(card_source) is None:
                errors.append(
                    "Chat Spot Preview Watch control must remain explicitly disabled"
                )

    if page_path.is_file():
        source = strip_dart_comments(read_text(page_path))
        start = source.find("class AssetMessagePreviewPage")
        if start < 0:
            errors.append("Chat E9 must retain its guarded Preview page")
        else:
            next_class = re.search(r"\nclass\s+[A-Za-z_]\w*", source[start + 1 :])
            end = (
                start + 1 + next_class.start()
                if next_class is not None
                else len(source)
            )
            page_source = source[start:end]
            guarded_slices.append((str(page_path.relative_to(root)), page_source))
            if normalized_dart_source_fingerprint(page_source) != (
                CHAT_SPOT_SNAPSHOT_SOURCE_FINGERPRINTS["page"]
            ):
                errors.append(
                    "Chat E9 page must match its reviewed closed-source fingerprint"
                )
            page_callbacks = re.findall(
                r"\b(on[A-Z]\w*)\s*:",
                strip_dart_comments_and_strings(page_source),
            )
            if page_callbacks:
                errors.append(
                    "Chat E9 Preview page cannot wrap the Spot card in another interaction callback"
                )

    internal_string_values = frozenset(
        {
            "chat-spot-market-entry",
            "chat-spot-watch-unavailable",
            "chat-spot-snapshot-card",
            "chat-spot-snapshot-semantics",
        }
    )
    allowed_visible_values = {
        "lib/features/chat/widgets/chat_components.dart": frozenset(
            {
                "chat-spot-snapshot-semantics",
                "ETH Spot market snapshot · 开发预览",
                "chat-spot-snapshot-card",
                "ETH",
                "ETH spot market snapshot",
                "Shared at 14:12 · 演示数据",
                "SPOT PREVIEW",
                "ETH spot preview trend at the time it was shared",
                "chat-spot-market-entry",
                "/market",
                "Open Spot markets",
                "chat-spot-watch-unavailable",
                "Watch unavailable",
                "Reference",
                "$3,428",
                "24h change",
                "+3.8%",
                "24h volume",
                "$128.4M",
            }
        ),
        "lib/features/chat/chat_preview_pages.dart": frozenset(
            {
                "Shared in chat · 开发预览",
                "Spot market snapshot",
                "A labelled point-in-time fixture. Open Market for current public Testnet facts.",
                "Snapshot boundaries",
                "Preview facts are not live",
                "Reference price, 24h change, and volume are labelled 演示数据. Opening Market loads a separate current public Spot snapshot.",
                "Market type",
                "Spot",
                "Reference price",
                "$3,428",
                "24h volume at share",
                "$128.4M",
                "24h change at share",
                "+3.8%",
            }
        ),
    }
    prohibited_visible_patterns = (
        re.compile(
            r"\b(?:perp(?:etuals?)?|positions?|leverage|margin|pnl|roe|"
            r"liquidation|entry|size|returns?|profit|loss|orders?|"
            r"copy[- ]?trad(?:e|ing))\b",
            re.IGNORECASE,
        ),
        re.compile(
            r"^(?:long|short)$|\b(?:go|going|went)\s+(?:long|short)\b|"
            r"\b(?:long|short)\s+(?:position|setup|trade)\b",
            re.IGNORECASE,
        ),
        re.compile(
            r"持仓|仓位|做多|做空|杠杆|保证金|盈亏|收益率|爆仓|强平|"
            r"跟单|开仓|平仓|入场价"
        ),
        re.compile(
            r"\b(?:save setup|setup saved|order submitted|trade executed)\b",
            re.IGNORECASE,
        ),
    )
    for relative, guarded_source in guarded_slices:
        for content in dart_concatenated_string_contents(guarded_source):
            normalized = " ".join(content.split())
            if normalized not in allowed_visible_values[relative]:
                errors.append(
                    f"{relative} E9 visible content must use the reviewed Spot Preview fact allowlist, not `{normalized}`"
                )
            if normalized in internal_string_values:
                continue
            if any(pattern.search(normalized) for pattern in prohibited_visible_patterns):
                errors.append(
                    f"{relative} E9 visible content must remain Spot-only without `{normalized}`"
                )

    content_path = root / "lib/features/chat/chat_content.dart"
    if content_path.is_file():
        content_source = read_text(content_path)
        content_start = content_source.find("abstract final class ChatContent")
        content_end = content_source.find(
            "class MemoryCommunicationGateway", content_start + 1
        )
        if content_start < 0 or content_end < 0:
            errors.append("Chat fixture content must retain one bounded source slice")
        elif normalized_dart_source_fingerprint(
            content_source[content_start:content_end]
        ) != CHAT_SPOT_SNAPSHOT_SOURCE_FINGERPRINTS["content"]:
            errors.append(
                "Chat fixture content must match its reviewed closed-source fingerprint"
            )
        sensitive_fixture_topic = re.compile(
            r"\baddress(?:es)?\b|\balerts?\b|\bmonitor(?:ing|ed)?\b|"
            r"地址|提醒|监(?:控|测)|收藏",
            re.IGNORECASE,
        )
        approved_sensitive_fixture_copy = frozenset(
            {
                "I’m reviewing the address manually; transfer alerts are not connected in this preview.",
                "I found the same treasury movement. Want the address?",
            }
        )
        saved_address_claim = re.compile(
            r"\b(?:saved|stored|bookmarked)\b.{0,40}\baddress\b|"
            r"\baddress\b.{0,40}\b(?:saved|stored|bookmarked)\b",
            re.IGNORECASE,
        )
        positive_alert_claim = re.compile(
            r"\b(?:set|saved|enabled|activated)\b.{0,40}"
            r"\b(?:alerts?|monitoring)\b|"
            r"\b(?:alerts?|monitoring)\b.{0,40}"
            r"\b(?:active|enabled|connected|saved|set)\b",
            re.IGNORECASE,
        )
        negative_alert_state = re.compile(
            r"\b(?:alerts?|monitoring)\b.{0,24}\b(?:not|never)\b.{0,24}"
            r"\b(?:active|available|connected|enabled|saved|set)\b",
            re.IGNORECASE,
        )
        positioning_claim = re.compile(r"\bpositioning roundtable\b", re.IGNORECASE)
        for content in dart_concatenated_string_contents(read_text(content_path)):
            normalized = " ".join(content.split())
            claims_capability = bool(
                (
                    sensitive_fixture_topic.search(normalized)
                    and normalized not in approved_sensitive_fixture_copy
                )
                or saved_address_claim.search(normalized)
                or positioning_claim.search(normalized)
                or (
                    positive_alert_claim.search(normalized)
                    and not negative_alert_state.search(normalized)
                )
            )
            if claims_capability:
                errors.append(
                    "Chat Preview conversation cannot claim Perp positioning, saved addresses, or active alerts: "
                    f"`{normalized}`"
                )

    errors.extend(check_behavior_test_evidence(root, CHAT_SPOT_SNAPSHOT_TEST_MARKERS))

    test_path = root / "test/chat_spot_snapshot_test.dart"
    if test_path.is_file():
        raw_test_source = read_text(test_path)
        if normalized_dart_source_fingerprint(raw_test_source) != (
            CHAT_SPOT_SNAPSHOT_SOURCE_FINGERPRINTS["test"]
        ):
            errors.append(
                "test/chat_spot_snapshot_test.dart must match its reviewed executable evidence fingerprint"
            )
        test_source = strip_dart_comments(raw_test_source)
        executable_test_source = strip_dart_comments_and_strings(test_source)
        if re.search(
            r"\b(?:skip\s*:|markTestSkipped\s*\()", executable_test_source
        ):
            errors.append(
                "test/chat_spot_snapshot_test.dart contract tests cannot be skipped"
            )

        protected_test_symbols = frozenset({"expect", "test", "testWidgets"})
        shadowed_functions: set[str] = set()
        for match in re.finditer(
            r"\b(" + "|".join(sorted(protected_test_symbols)) + r")\s*\(",
            executable_test_source,
        ):
            opening = executable_test_source.find("(", match.start())
            depth = 0
            closing = -1
            for index in range(opening, len(executable_test_source)):
                character = executable_test_source[index]
                if character == "(":
                    depth += 1
                elif character == ")":
                    depth -= 1
                    if depth == 0:
                        closing = index
                        break
            if closing < 0:
                continue
            tail = executable_test_source[closing + 1 :].lstrip()
            if tail.startswith("async"):
                tail = tail[len("async") :].lstrip()
            if tail.startswith("{") or tail.startswith("=>"):
                shadowed_functions.add(match.group(1))
        shadowed_bindings = set(
            re.findall(
                r"\b(expect|test|testWidgets)\s*=",
                executable_test_source,
            )
        )
        shadowed_getters = set(
            re.findall(
                r"\bget\s+(expect|test|testWidgets)\b", executable_test_source
            )
        )
        shadowed_symbols = shadowed_functions | shadowed_bindings | shadowed_getters
        if shadowed_symbols:
            errors.append(
                "test/chat_spot_snapshot_test.dart cannot shadow flutter_test evidence symbols: "
                + ", ".join(sorted(shadowed_symbols))
            )
        test_starts = [
            match.start()
            for match in re.finditer(r"\btest(?:Widgets)?\s*\(", test_source)
        ]

        def named_test_body(marker: str) -> str | None:
            declaration = re.search(
                r"\btest(?:Widgets)?\s*\(\s*(['\"])"
                + re.escape(marker)
                + r"\1\s*,",
                test_source,
                re.DOTALL,
            )
            if declaration is None:
                return None
            next_test = next(
                (start for start in test_starts if start > declaration.start()),
                len(test_source),
            )
            segment = test_source[declaration.end() : next_test]
            executable_segment = strip_dart_comments_and_strings(segment)
            opening = executable_segment.find("{")
            if opening < 0:
                return segment
            depth = 0
            for index in range(opening, len(executable_segment)):
                character = executable_segment[index]
                if character == "{":
                    depth += 1
                elif character == "}":
                    depth -= 1
                    if depth == 0:
                        return segment[opening + 1 : index]
            return segment[opening + 1 :]

        exact_assertions = {
            "chat preview asset snapshot is spot-only and labels fixture facts": (
                r"expect\s*\(\s*find\.text\s*\(\s*'SPOT PREVIEW'\s*\)\s*,\s*findsOneWidget\s*\)",
                r"expect\s*\(\s*find\.text\s*\(\s*'Shared at 14:12 · 演示数据'\s*\)\s*,\s*findsOneWidget\s*\)",
                r"tester\.widget<Semantics>\s*\(\s*find\.byKey\s*\(\s*const\s+ValueKey<String>\s*\(\s*'chat-spot-snapshot-semantics'\s*\)",
                r"expect\s*\(\s*semantics\.properties\.label\s*,\s*'ETH Spot market snapshot · 开发预览'\s*\)",
                r"expect\s*\(\s*find\.text\s*\(\s*'ETH position snapshot'\s*\)\s*,\s*findsNothing\s*\)",
                r"expect\s*\(\s*find\.text\s*\(\s*'LONG'\s*\)\s*,\s*findsNothing\s*\)",
                r"expect\s*\(\s*find\.text\s*\(\s*'Entry'\s*\)\s*,\s*findsNothing\s*\)",
                r"expect\s*\(\s*find\.text\s*\(\s*'Save setup'\s*\)\s*,\s*findsNothing\s*\)",
                r"expect\s*\(\s*watchButton\.onPressed\s*,\s*isNull\s*\)",
            ),
            "chat preview spot card opens the public Spot market ledger": (
                r"tester\.tap\s*\(\s*find\.byKey\s*\(\s*const\s+ValueKey<String>\s*\(\s*'chat-spot-market-entry'\s*\)",
                r"expect\s*\(\s*find\.byKey\s*\(\s*const\s+ValueKey<String>\s*\(\s*'public-spot-market-ledger'\s*\)\s*\)\s*,\s*findsOneWidget",
            ),
            "chat Spot snapshot supports 390pt at 2x Dynamic Type": (
                r"_pumpSpotPreview\s*\(\s*tester\s*,\s*textScale:\s*2\s*\)",
                r"expect\s*\(\s*tester\.takeException\s*\(\s*\)\s*,\s*isNull\s*\)",
            ),
        }
        for marker, patterns in exact_assertions.items():
            body = named_test_body(marker)
            if body is None:
                continue
            missing_assertion = any(
                re.search(pattern, body, re.DOTALL) is None for pattern in patterns
            )
            executable_body = strip_dart_comments_and_strings(body)
            has_nested_or_conditional_evidence = bool(
                re.search(
                    r"\b(?:if|for|while|switch|try|catch|return|throw)\b",
                    executable_body,
                )
                or "{" in executable_body
                or "}" in executable_body
                or "=>" in executable_body
                or "?" in executable_body
            )
            if missing_assertion or has_nested_or_conditional_evidence:
                errors.append(
                    "test/chat_spot_snapshot_test.dart test "
                    f"`{marker}` must execute its exact Spot-only assertions directly"
                )
    return errors


CHAT_PREVIEW_REQUEST_TEST_MARKERS = {
    Path("test/chat_preview_message_requests_test.dart"): (
        "Preview requests transition once without changing conversations or messages",
        "Accept removes one Preview request without creating a Stream conversation",
        "Report removes a simulated request but never claims submission",
        "Ignore reaches a truthful empty state and clears the Inbox badge",
        "a request card disables every action while resolution is pending",
    ),
}
CHAT_PREVIEW_REQUEST_TEST_FINGERPRINT = (
    "aed18499ecd432806bd70742207106214ac6d8af2e5074fdbe1ab6991e3e4865"
)
CHAT_PREVIEW_REQUEST_SOURCE_FINGERPRINTS = {
    "page": "7816c49c960272acff1caa32f824a6edd5b55ec22b982a41f739c143a421f7e8",
    "gateway": "a2ed73bcb1f80ac4110aa8f48fcb5f3c68d2d2270028dbf246e37af43df24701",
    "inbox": "4b2ffcb9f2a69dbebde32b27aab185b8ab8136c37a23bb7cf176c22d4103a3e7",
}


def check_chat_preview_message_request_contract(root: Path) -> list[str]:
    """Keep legacy request triage process-local, exact-ID, and truthfully labelled."""

    errors = require_fragments(
        root,
        {
            "lib/integrations/communication/communication_gateway.dart": (
                "code: 'preview_request_not_pending'",
                "code: 'preview_request_reason_invalid'",
            ),
            "lib/features/chat/chat_content.dart": (
                "_PreviewMessageRequestResolution.acceptedLocally",
                "_PreviewMessageRequestResolution.ignoredLocally",
                "_PreviewMessageRequestResolution.removedAsUnsafeLocally",
                "if (current == null || !current.isPending)",
                "CommunicationFailure.previewRequestNotPending",
                "CommunicationFailure.previewRequestReasonInvalid",
            ),
            "lib/features/chat/v2/loop_stream_channel_surface.dart": (
                "enableMentionsOverlay: loopMentions.isEmpty",
                "customAutocompleteTriggers: loopMentions",
            ),
            "lib/features/chat/chat_inbox_page.dart": (
                "final requests = ref.watch(messageRequestsProvider);",
                "final requestCount = requests.hasValue ? requests.value!.length : null;",
                "'No preview requests'",
                "'1 preview request'",
                "'chat-preview-message-request-badge'",
            ),
            "lib/features/chat/chat_secondary_pages.dart": (
                "Development Preview only · 开发预览",
                "Accept does not create a Stream conversation",
                "Report does not submit a moderation report",
                "No simulated requests remain in this Development Preview.",
                "No Stream conversation was created.",
                "No sender interaction occurred.",
                "no report is submitted.",
                "No report was submitted.",
                "resolving ? null : onAccept",
                "resolving ? null : onIgnore",
                "resolving ? null : onReport",
            ),
            "lib/core/navigation/surface_catalog.dart": (
                "Development Preview-only local request triage; no Stream conversation or moderation submission.",
            ),
            "test/chat_preview_message_requests_test.dart": (
                "CommunicationFailure.previewRequestNotPending.code",
                "CommunicationFailure.previewRequestReasonInvalid.code",
                "No Stream conversation was created.",
                "No report was submitted.",
                "find.text('No preview requests')",
                "chat-preview-message-request-badge",
                "chat-preview-request-progress",
            ),
            "test/chat_preview_route_guard_test.dart": (
                "production legacy Chat routes never mount preview fixtures",
                "find.byKey(const ValueKey<String>('chat-preview-route-blocked'))",
            ),
            "docs/product/implementation-constraints.md": (
                "Legacy Message Requests are process-local Development Preview fixtures only.",
                "unknown and already resolved IDs fail.",
            ),
            "docs/failures/preview-message-request-fake-success.md": (
                "## Root Cause",
                "## Detection",
                "## Prevention",
                "## Evidence",
            ),
        },
    )

    page_path = root / "lib/features/chat/chat_secondary_pages.dart"
    if page_path.is_file():
        source = strip_dart_comments(read_text(page_path))
        start = source.find("class MessageRequestsPage")
        end = source.find("enum _SearchFilter", start + 1)
        if start < 0 or end < 0:
            errors.append("Chat Message Requests must retain one bounded Preview page")
        else:
            request_page = source[start:end]
            if normalized_dart_source_fingerprint(request_page) != (
                CHAT_PREVIEW_REQUEST_SOURCE_FINGERPRINTS["page"]
            ):
                errors.append(
                    "Chat Message Requests page must match its reviewed truth-source fingerprint"
                )
            forbidden_claims = (
                "Accepting a request starts a conversation",
                "Request accepted. You can now reply",
                "Report submitted and request removed",
                "New requests from people you do not know will appear here",
            )
            for claim in forbidden_claims:
                if claim in request_page:
                    errors.append(
                        f"Chat Message Requests cannot claim unsupported provider effect: `{claim}`"
                    )
            if re.search(r"['\"]/chat/", request_page) or any(
                marker in request_page
                for marker in ("StreamChannelRoute", "StreamChatChannelRoutePage")
            ):
                errors.append(
                    "Preview request resolution cannot navigate to a Chat conversation or Stream channel"
                )

    inbox_path = root / "lib/features/chat/chat_inbox_page.dart"
    if inbox_path.is_file():
        source = strip_dart_comments(read_text(inbox_path))
        start = source.find("class ChatInboxPage")
        end = source.find("class _ConversationLoading", start + 1)
        inbox = source[start:end] if start >= 0 and end >= 0 else source
        if start < 0 or end < 0:
            errors.append("Chat Inbox must retain one bounded Preview request-count slice")
        elif normalized_dart_source_fingerprint(inbox) != (
            CHAT_PREVIEW_REQUEST_SOURCE_FINGERPRINTS["inbox"]
        ):
            errors.append(
                "Chat Inbox request count must match its reviewed dynamic-source fingerprint"
            )
        if re.search(r"(?:const\s+)?Text\s*\(\s*['\"]2(?: requests)?['\"]", inbox):
            errors.append(
                "Chat Inbox request count must derive from messageRequestsProvider, never a fixed 2"
            )

    gateway_path = root / "lib/features/chat/chat_content.dart"
    if gateway_path.is_file():
        source = strip_dart_comments(read_text(gateway_path))
        start = source.find("class MemoryCommunicationGateway")
        end = source.find("enum _PreviewMessageRequestResolution", start + 1)
        if start < 0 or end < 0:
            errors.append(
                "MemoryCommunicationGateway must retain one bounded Preview request-state slice"
            )
        elif normalized_dart_source_fingerprint(source[start:end]) != (
            CHAT_PREVIEW_REQUEST_SOURCE_FINGERPRINTS["gateway"]
        ):
            errors.append(
                "Preview request gateway must match its reviewed exact-transition fingerprint"
            )
        if "_requests.removeWhere" in source:
            errors.append(
                "Preview request resolution must use exact pending-state transitions, not removeWhere success"
            )

    test_path = root / "test/chat_preview_message_requests_test.dart"
    if test_path.is_file() and normalized_dart_source_fingerprint(
        read_text(test_path)
    ) != CHAT_PREVIEW_REQUEST_TEST_FINGERPRINT:
        errors.append(
            "test/chat_preview_message_requests_test.dart must match its reviewed executable evidence fingerprint"
        )

    errors.extend(
        check_behavior_test_evidence(root, CHAT_PREVIEW_REQUEST_TEST_MARKERS)
    )
    return errors


CHAT_PREVIEW_CONVERSATION_ID_TEST_MARKERS = {
    Path("test/chat_preview_conversation_identity_test.dart"): (
        "Preview identity resolves only exact registered message targets",
        "Preview route query rejects missing duplicate control and overlong IDs",
        "Preview gateway rejects unknown read send and scoped search without mutation",
        "Preview deep links require an exact ID and never mount a fallback composer",
        "Conversation search keeps the exact Preview scope",
        "Group information preserves the exact Preview search scope",
        "Group information labels preferences as process-local Preview state",
        "Group information disables unsupported member and leave actions",
        "Unknown or kind-mismatched search results are not navigable",
        "Inbox refuses an unregistered same-kind Preview conversation",
    ),
}
CHAT_PREVIEW_CONVERSATION_ID_TEST_FINGERPRINT = (
    "a87079e5bdfaf6321f20537d89a657deec2e18d86d5944787e7e50f52fefa852"
)
CHAT_PREVIEW_CONVERSATION_ID_SOURCE_FINGERPRINTS = {
    "resolver": "9b441d2d8c58355db0d3bc47100f6d85534a4f4569a646126496a62b68520547",
    "primary_routes": "9a800ba14a805f9a0e5f62a611441da4c42aaf56eb3f3eba3eb87c34152ffef7",
    "secondary_routes": "cb31c8b5beb308a8a629bac006ab92372383c436482518da19ae7a2bbba22252",
    "conversation_pages": "4d71552865ef9c3f872da63d4cdcb9299468e3f07e0bafdf40f7e72f97f51a11",
    "group_info": "d967998206d33611981bbd5107e9b51975cbfbf2c69a121800b0584731a0b54c",
    "member_list": "9e34dccc196b4237baba7ea8a6b1ece71c297d010b1a5a8c7cd264d9419350bd",
    "search": "6684f9a8aae999ba5a780340283fee75a1df0bfba701e7f94652e8ccba02b96a",
    "inbox_navigation": "e854a63e6871f7c56b14a0671617413c3191670b656ccef4fa13fe8b0abe72fe",
    "gateway": "a2ed73bcb1f80ac4110aa8f48fcb5f3c68d2d2270028dbf246e37af43df24701",
    "home_notification": "7dacb554dd1ad92063d87548c5f0a34069b5643bf69dc2de83c7da820658ed85",
    "production_cid": "cd1ec47454a1c55cb2225b7e119b5f5f36ff61dbf6e1434edcaa26705b89f98a",
    "unavailable_page": "3476f8d0a2ad8d4e0e2922a926fc2177bfcfa88fceca55dbb39189c8ed3351ff",
}


def check_chat_preview_conversation_id_contract(root: Path) -> list[str]:
    """Keep local Preview message targets exact without altering Stream CIDs."""

    errors = require_fragments(
        root,
        {
            "lib/features/chat/preview_conversation_identity.dart": (
                "final values = uri.queryParametersAll['conversationId'];",
                "if (values == null || values.length != 1) return null;",
                "return target?.kind == kind ? target : null;",
                "ChatContent.groupId => group",
                "ChatContent.directId => direct",
                "_ => null",
                "Uri(",
                "queryParameters: <String, String>{'conversationId': id}",
            ),
            "lib/integrations/communication/communication_gateway.dart": (
                "code: 'preview_conversation_not_found'",
                "The exact Preview conversation is not available.",
            ),
            "lib/features/chat/chat_content.dart": (
                "ChatContent.groupId => _groupMessages",
                "ChatContent.directId => _directMessages",
                "CommunicationFailure.conversationNotFound",
                "conversationId != ChatContent.groupId",
                "conversationId != ChatContent.directId",
            ),
            "lib/features/chat/chat_inbox_page.dart": (
                "PreviewConversationIdentity.locationForSummary(",
                "conversationId: conversation.id",
                "kind: conversation.kind",
                "No fallback was opened.",
            ),
            "lib/features/chat/conversation_pages.dart": (
                "PreviewConversationIdentity.resolve(",
                "conversationId: conversationId",
                "PreviewConversationUnavailablePage",
                "context.push(target.searchLocation)",
                "conversationMessagesProvider(conversationId)",
                ".sendText(conversationId: conversationId, text: text)",
            ),
            "lib/features/chat/preview_conversation_unavailable_page.dart": (
                "key: const ValueKey<String>('preview-conversation-unavailable')",
                "The Preview did not substitute another group",
                "onPressed: () => context.go('/chat')",
            ),
            "lib/features/chat/chat_secondary_pages.dart": (
                "conversationId: widget.conversationId",
                "kind: ConversationKind.group",
                "if (target == null) return const PreviewConversationUnavailablePage();",
                "onPressed: () => context.push(target.searchLocation)",
                "Preview controls only",
                "do not read or write Stream notification settings",
                "if (!value) _mentionsOnly = false;",
                "preview-group-notifications",
                "preview-group-mentions-only",
                "No member actions",
                "preview-group-leave-unavailable",
                "Membership actions unavailable",
                "PreviewConversationIdentity.resolveMessage(conversationId)",
                "result.conversationId == scope.id",
                "conversationId: _scope?.id",
                "resolvedTarget?.kind == result.kind ? resolvedTarget : null",
                "target == null ? null : () => context.push(target.location)",
                "Preview conversation unavailable",
            ),
            "lib/app.dart": (
                "PreviewConversationIdentity.readSingleConversationId(",
                "PreviewConversationIdentity.hasConversationIdQuery(state.uri)",
                "path: '/chat/channel/:cid'",
                # Step 4 turned the CID deep link into a redirect onto the
                # surface its LOOP-assigned prefix names.
                "loopChatLocationForCid(state.pathParameters['cid'] ?? '')",
            ),
            # Step 5 deleted the Home slice, so the Preview notification
            # target it carried is retired with it (decision 0057).
            "test/chat_preview_conversation_identity_test.dart": (
                "CommunicationFailure.conversationNotFound.code",
                "another-group",
                "glyph-hunters&conversationId=sable-direct",
                "find.byTooltip('Send message'), findsNothing",
                "lastSearchConversationId, ChatContent.groupId",
                "Preview conversation unavailable. No fallback was opened.",
            ),
            "docs/product/implementation-constraints.md": (
                "Legacy Preview group and direct-message routes require one exact registered `conversationId`.",
                "The memory gateway never substitutes another fixture",
                "Legacy Preview group-information preferences are process-local layout state only.",
                "Member management and leaving remain disabled",
            ),
            "docs/decisions/0025-require-exact-preview-conversation-identity.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "## Evidence",
            ),
            "docs/failures/preview-conversation-id-fallback.md": (
                "## Root Cause",
                "## Detection",
                "## Prevention",
                "## Evidence",
            ),
            "docs/decisions/0039-close-preview-group-info-controls.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "## Evidence",
            ),
            "docs/failures/preview-group-info-controls-without-effects.md": (
                "## Root Cause",
                "## Detection",
                "## Prevention",
                "## Evidence",
            ),
            "lib/core/navigation/surface_catalog.dart": (
                "Exact-ID Preview group layout; preferences are process-local and membership actions are disabled.",
            ),
        },
    )

    page_path = root / "lib/features/chat/chat_secondary_pages.dart"
    if page_path.is_file():
        source = strip_dart_comments(read_text(page_path))
        start = source.find("class GroupInfoPage")
        end = source.find("class MessageRequestsPage", start + 1)
        if start < 0 or end < 0:
            errors.append(
                "Preview group information must retain one bounded control slice"
            )
        else:
            group_info = source[start:end]
            if "onPressed: () {}" in group_info or "Member options" in group_info:
                errors.append(
                    "Preview group member rows cannot expose an enabled placeholder action"
                )
            if "_confirmLeaveGroup" in group_info or "Leave group" in group_info:
                errors.append(
                    "Preview group membership cannot use a dialog-only Leave action"
                )
            if not re.search(
                r"key:\s*const ValueKey<String>\('preview-group-leave-unavailable'\)"
                r"[\s\S]{0,160}?onPressed:\s*null",
                group_info,
            ):
                errors.append(
                    "Preview group Leave must remain explicitly disabled without a Stream mutation"
                )
            if "if (!value) _mentionsOnly = false;" not in group_info:
                errors.append(
                    "Preview group preferences must clear dependent mentions-only local state"
                )
            if (
                "do not read or write Stream notification settings"
                not in group_info
            ):
                errors.append(
                    "Preview group preferences must disclose that no Stream setting is read or written"
                )
            if "New messages and group activity" in group_info:
                errors.append(
                    "Preview group preferences cannot imply provider notification delivery"
                )

        member_list_start = source.find("Future<void> _showMemberList")
        if member_list_start < 0:
            errors.append(
                "Preview group member list must retain one bounded control slice"
            )
        else:
            member_list = source[member_list_start:]
            if "onPressed: () {}" in member_list or "Member options" in member_list:
                errors.append(
                    "Preview group member list cannot expose an enabled placeholder action"
                )

    fingerprints = (
        (
            "lib/features/chat/preview_conversation_identity.dart",
            None,
            None,
            "resolver",
            "Preview conversation resolver",
        ),
        (
            "lib/app.dart",
            "path: '/chat/group'",
            "path: '/chat/voice'",
            "primary_routes",
            "Preview group/direct routes",
        ),
        (
            "lib/app.dart",
            "path: '/chat/group-info'",
            "path: '/chat/channel/:cid'",
            "secondary_routes",
            "Preview group-info/search routes",
        ),
        (
            "lib/features/chat/conversation_pages.dart",
            "class GroupChatPage",
            "class _PinnedMessageBanner",
            "conversation_pages",
            "Preview conversation pages",
        ),
        (
            "lib/features/chat/chat_secondary_pages.dart",
            "class GroupInfoPage",
            "Future<void> _showMemberList",
            "group_info",
            "Preview group information",
        ),
        (
            "lib/features/chat/chat_secondary_pages.dart",
            "Future<void> _showMemberList",
            None,
            "member_list",
            "Preview group member list",
        ),
        (
            "lib/features/chat/chat_secondary_pages.dart",
            "enum _SearchFilter",
            "class MeetingPlaceholderPage",
            "search",
            "Preview message search",
        ),
        (
            "lib/features/chat/chat_inbox_page.dart",
            "static void _openConversation",
            "class _ConversationLoading",
            "inbox_navigation",
            "Preview Inbox navigation",
        ),
        (
            "lib/features/chat/chat_content.dart",
            "class MemoryCommunicationGateway",
            "enum _PreviewMessageRequestResolution",
            "gateway",
            "Preview memory gateway",
        ),
        # Step 5 deleted the Home slice and its Preview notification target.
        (
            "lib/app.dart",
            "path: '/chat/channel/:cid'",
            "path: '/preview/token-card'",
            "production_cid",
            "Production Stream CID route",
        ),
        (
            "lib/features/chat/preview_conversation_unavailable_page.dart",
            None,
            None,
            "unavailable_page",
            "Preview unavailable page",
        ),
    )
    for relative, start_marker, end_marker, key, label in fingerprints:
        path = root / relative
        if not path.is_file():
            continue
        source = read_text(path)
        if start_marker is None:
            reviewed = source
        else:
            start = source.find(start_marker)
            end = (
                len(source)
                if end_marker is None
                else source.find(end_marker, start + 1)
            )
            if start < 0 or (end_marker is not None and end < 0):
                errors.append(f"{label} must retain one bounded reviewed source slice")
                continue
            reviewed = source[start:end]
        if normalized_dart_source_fingerprint(reviewed) != (
            CHAT_PREVIEW_CONVERSATION_ID_SOURCE_FINGERPRINTS[key]
        ):
            errors.append(f"{label} must match its reviewed exact-ID fingerprint")

    test_path = root / "test/chat_preview_conversation_identity_test.dart"
    if test_path.is_file() and normalized_dart_source_fingerprint(
        read_text(test_path)
    ) != CHAT_PREVIEW_CONVERSATION_ID_TEST_FINGERPRINT:
        errors.append(
            "test/chat_preview_conversation_identity_test.dart must match its reviewed executable evidence fingerprint"
        )

    errors.extend(
        check_behavior_test_evidence(
            root, CHAT_PREVIEW_CONVERSATION_ID_TEST_MARKERS
        )
    )
    return errors


SECURITY_CAPABILITY_TRUTH_TEST_MARKERS = {
    Path("test/security_capability_truthfulness_test.dart"): (
        "A11 exposes no providerless protection switch or secure-storage claim",
        "H5 states each protection method is off, with its reason",
        "production LoopApp A11 keeps every setup method unavailable",
        "production LoopApp H5 fails closed with no adapter",
        "A11 and H5 catalog copy reports current delivery truth",
    ),
}
SECURITY_CAPABILITY_TRUTH_EXECUTABLE_TEST_EVIDENCE = {
    Path("test/security_capability_truthfulness_test.dart"): {
        "A11 exposes no providerless protection switch or secure-storage claim": (
            r"\bfind\.byKey\s*\(\s*const\s+ValueKey<String>\s*\(",
            r"\bfind\.byType\s*\(\s*Switch\s*\)\s*,\s*findsNothing",
            r"\bfind\.textContaining\s*\([\s\S]*?\)\s*,\s*findsNothing",
            # Decision 0053: the continue-without-changes action is now the
            # page's single keyed primary button.
            r"\b_tap\s*\(\s*tester\s*,\s*find\.byKey\s*\(\s*const\s+"
            r"ValueKey<String>\s*\(",
            r"\bfind\.text\s*\([\s\S]*?\)\s*,\s*findsNWidgets\s*\(\s*3\s*\)",
            r"\bexpect\s*\(\s*destinations\s*,\s*<String>\s*\[",
        ),
        "H5 states each protection method is off, with its reason": (
            r"\bawait\s+pumpS8Page\s*\(",
            r"\bsecurity\s*:\s*FakeSecurityGateway\s*\(",
            r"\bfind\.textContaining\s*\([\s\S]*?\)\s*,\s*findsNothing",
            r"\bfor\s*\(\s*final\s+id\s+in\s+LoopSecurityCapabilityId\.values\s*\)",
            r"\bfindsNWidgets\s*\(\s*6\s*\)",
            r"\bexpect\s*\(\s*destinations\s*,\s*<String>\s*\[",
        ),
        "production LoopApp A11 keeps every setup method unavailable": (
            r"\bfinal\s+router\s*=\s*await\s+_pumpAuthenticatedLoopApp\s*\(",
            r"\brouter\.go\s*\(",
            r"\bfind\.byKey\s*\(\s*const\s+ValueKey<String>\s*\(",
            r"\bfind\.text\s*\([\s\S]*?\)\s*,\s*findsNothing",
            # Every reviewed A11 method stays unavailable in production: the
            # two Privy ones, and the device lock a widget test has no device
            # to open.
            r"\bfind\.text\s*\([\s\S]*?\)\s*,\s*findsNWidgets\s*\(\s*3\s*\)",
            r"\bfind\.byType\s*\(\s*Switch\s*\)\s*,\s*findsNothing",
        ),
        "production LoopApp H5 fails closed with no adapter": (
            r"\bfinal\s+router\s*=\s*await\s+_pumpAuthenticatedLoopApp\s*\(",
            r"\brouter\.go\s*\(",
            r"\bfind\.byKey\s*\(\s*const\s+ValueKey<String>\s*\(",
            r"\bfind\.text\s*\([\s\S]*?\)\s*,\s*findsNothing",
            r"\bfind\.textContaining\s*\([\s\S]*?\)\s*,\s*findsNothing",
        ),
        "A11 and H5 catalog copy reports current delivery truth": (
            r"\bfinal\s+a11\s*=\s*SurfaceCatalog\.byPath\s*\(",
            r"\bfinal\s+h5\s*=\s*SurfaceCatalog\.byPath\s*\(",
            r"\bexpect\s*\(\s*a11\.description\s*,\s*contains\s*\(",
            r"\bexpect\s*\(\s*h5\.description\s*,\s*contains\s*\(",
        ),
    },
}


APP_LOCK_TEST_MARKERS = {
    Path("test/app_lock_test.dart"): (
        "a stored on whose credential is gone is not enabled",
        "it is on only after the device said yes, and it persists",
        "turning it off needs the same proof as turning it on",
        "a credential removed under the lock opens it and turns it off",
        "a minute away closes the curtain",
        "a locked App is covered and offers one way through",
    ),
}


def check_app_lock_contract(root: Path) -> list[str]:
    """Keep the device-local lock the device's, and LOOP's storage empty.

    LOOP has no PIN of its own and must never acquire one: the lock asks the
    operating system, which owns the face, the fingerprint and the passcode
    behind them. What LOOP keeps is one boolean saying the owner turned it on.
    """

    errors = require_fragments(
        root,
        {
            "lib/features/security/app_lock/app_lock_models.dart": (
                "abstract interface class LoopDeviceAuthenticator",
                "abstract interface class LoopAppLockStore",
                "class UnavailableLoopDeviceAuthenticator",
                "loopDeviceAuthenticatorProvider",
                "loopAppLockStoreProvider",
            ),
            "lib/features/security/app_lock/app_lock_controller.dart": (
                "const loopAppLockGrace = Duration(seconds: 60)",
                "Future<bool> enable()",
                "Future<bool> disable()",
                "Future<bool> unlock()",
                "void onLeftForeground()",
                "void onEnteredForeground()",
            ),
            "lib/features/security/app_lock/app_lock_gate.dart": (
                "class LoopAppLockGate",
                "loop-app-lock-curtain",
                "loop-app-lock-unlock",
            ),
            "lib/integrations/device/local_auth_device_authenticator.dart": (
                "import 'package:local_auth/local_auth.dart';",
                "biometricOnly: false",
                "LocalAuthExceptionCode.noCredentialsSet",
            ),
            "lib/integrations/device/secure_storage_app_lock_store.dart": (
                "loop.app_lock.v1.enabled",
            ),
            "lib/main.dart": (
                "loopDeviceAuthenticatorProvider.overrideWithValue(",
                "loopAppLockStoreProvider.overrideWithValue(",
            ),
            "lib/app.dart": (
                # The curtain is the outermost LOOP widget, above the toast
                # host: a toast drawn over it would print a line of the App
                # on its own cover.
                "LoopAppLockGate(child: LoopToastHost(child: content))",
                "onLeftForeground()",
                "lock.onEnteredForeground()",
            ),
            "test/app_lock_test.dart": tuple(
                marker
                for markers in APP_LOCK_TEST_MARKERS.values()
                for marker in markers
            ),
        },
    )

    # The plugin is spoken to in exactly one file. A product page that imported
    # it could authenticate on its own and report whatever it liked.
    for path in sorted((root / "lib").rglob("*.dart")):
        if "package:local_auth" not in read_text(path):
            continue
        relative = path.relative_to(root).as_posix()
        if relative != "lib/integrations/device/local_auth_device_authenticator.dart":
            errors.append(f"only the device adapter may import local_auth: {relative}")

    # Nothing derived from a PIN may be persisted, because nothing is ever
    # seen. The store writes one of two characters under one key.
    store_path = root / "lib/integrations/device/secure_storage_app_lock_store.dart"
    if store_path.is_file():
        store = strip_dart_comments(read_text(store_path))
        if (
            re.search(
                r"write\(\s*key\s*:\s*key\s*,\s*value\s*:\s*enabled\s*\?\s*'1'\s*:\s*'0'\s*\)",
                store,
            )
            is None
        ):
            errors.append(
                "the app lock store must persist one boolean and nothing else"
            )
        for marker in ("pin", "Pin", "PIN", "passcode"):
            if marker in store:
                errors.append(
                    "the app lock store must not name a secret it never holds: "
                    + marker
                )

    manifest_path = root / "android/app/src/main/AndroidManifest.xml"
    manifest, manifest_errors = _parse_xml(manifest_path, "Android main manifest")
    errors.extend(manifest_errors)
    if manifest is not None:
        active = [
            permission
            for permission in manifest.findall("uses-permission")
            if permission.get(ANDROID_NAME) == "android.permission.USE_BIOMETRIC"
            and permission.get(ANDROID_TOOLS_NODE) != "remove"
        ]
        if len(active) != 1:
            errors.append(
                "the device lock requires exactly one active "
                "`android.permission.USE_BIOMETRIC` declaration"
            )

    activity_path = root / "android/app/src/main/kotlin/com/cywd/loop/MainActivity.kt"
    if activity_path.is_file():
        if "FlutterFragmentActivity" not in read_text(activity_path):
            errors.append(
                "the Android host must be a FlutterFragmentActivity: the system "
                "biometric prompt is a fragment"
            )
    else:
        errors.append("missing Android MainActivity")

    info_path = root / "ios/Runner/Info.plist"
    info, info_errors = _parse_plist(info_path, "iOS Runner Info.plist")
    errors.extend(info_errors)
    if info is not None:
        description = info.get("NSFaceIDUsageDescription")
        if not isinstance(description, str) or not description.strip():
            errors.append(
                "the device lock requires a non-empty NSFaceIDUsageDescription"
            )

    errors.extend(check_behavior_test_evidence(root, APP_LOCK_TEST_MARKERS))
    return errors


ACCOUNT_MFA_TEST_MARKERS = {
    Path("test/mfa_test.dart"): (
        "a provider that cannot be asked is unavailable, not empty",
        "an application with MFA switched off says exactly that",
        "a secret is not an enrolment",
        "the account is enrolled only by what the provider returned",
        "a refused removal leaves the method exactly where it was",
        "no provider behind the page is 不可用, never 未开启",
        # S64: a passkey belongs to a domain this build either has or has
        # not been given, and to an account the provider answers for. Both
        # facts stay the provider's, and neither is ever assumed.
        "a build with no domain credential asks the platform nothing",
        "the account has a passkey only because the provider said so",
        "a dismissed system prompt binds nothing and says so",
        "unbinding needs the device first, and then the provider",
        "an account with no passkey gets one before it is enrolled",
        "switching the factor off keeps the way back in",
        "a bound passkey says 已设置 and can be opened again",
    ),
}


def check_account_mfa_contract(root: Path) -> list[str]:
    """Keep the second factor the provider's, and its absence unclaimed.

    MFA lives at Privy. LOOP may report what Privy answered and may start the
    provider's own enrolment; it may never record an enrolment of its own, and
    it may never read "we could not ask" as "you have none".
    """

    errors = require_fragments(
        root,
        {
            "lib/features/security/mfa/mfa_models.dart": (
                "abstract interface class LoopMfaGateway",
                "class UnavailableLoopMfaGateway",
                "enum LoopMfaFailureKind",
                "notEnabled",
                "loopMfaGatewayProvider",
                # S64: what the provider holds is two lists, not one. A
                # passkey can be a way back in without being a second
                # factor, and the product may not read one as the other.
                "final class LoopPasskeyCredential",
                "final class LoopSecondFactorFacts",
                "passkeyDomainUnconfigured",
            ),
            "lib/features/security/mfa/mfa_controller.dart": (
                "enum LoopMfaPhase",
                "LoopMfaPhase.unavailable",
                "Future<void> beginTotp()",
                "Future<bool> submitTotp(String code)",
                "Future<bool> removeTotp()",
                "void cancelTotp()",
                "Future<bool> linkPasskey()",
                "Future<bool> unlinkPasskey(String credentialId)",
                "Future<bool> enablePasskeyMfa()",
                "Future<bool> disablePasskeyMfa()",
                # The domain credential is checked here, so a build without
                # one never asks the platform a question it can only answer
                # with an error nobody can act on.
                "bool _passkeyConfigured()",
                # An unbind is a way back in being taken away.
                "_confirmOwnerPresent(",
            ),
            "lib/features/security/mfa/mfa_sheet.dart": (
                "String loopMfaFailureText(",
                "mfa-sheet-secret",
                "mfa-sheet-code",
                "mfa-sheet-submit",
                "const loopPasskeyDomainPending",
                "mfa-sheet-passkey",
                "mfa-sheet-passkey-unavailable",
            ),
            "lib/features/security/mfa/passkey_sheet.dart": (
                "passkey-sheet-link",
                "passkey-sheet-confirm",
                "passkey-sheet-unlink",
                "passkey-sheet-unavailable",
                "controller.unlinkPasskey(confirming)",
            ),
            "lib/integrations/privy/privy_mfa_gateway.dart": (
                ".mfa.totp.enroll.generateSecret()",
                ".mfa.totp.enroll.submit(code)",
                ".mfa.totp.unenroll()",
                "class PrivyMfaFailureClassifier",
                "class LoopReleasingMfaListener",
                "resumeBlockedActions(",
                "mfaPrivy.passkey.link(",
                "mfaPrivy.passkey.unlink(",
                ".mfa.passkeys.enroll.submit(credentialIds)",
                ".mfa.passkeys.unenroll(",
                "static LoopMfaFailureKind ofPasskey(",
            ),
            "lib/app/app_config.dart": (
                "'LOOP_PASSKEY_RP_DOMAIN'",
                "String get passkeyRelyingPartyForCurrentBuild",
            ),
            "lib/main.dart": ("loopMfaGatewayProvider.overrideWith(",),
            "test/mfa_test.dart": tuple(
                marker
                for markers in ACCOUNT_MFA_TEST_MARKERS.values()
                for marker in markers
            ),
        },
    )

    # The controller may only publish an enrolment that arrived in the answer
    # to the call that changed it. A locally assembled list would be LOOP
    # deciding it had enrolled somebody.
    controller_path = root / "lib/features/security/mfa/mfa_controller.dart"
    if controller_path.is_file():
        controller = strip_dart_comments(read_text(controller_path))
        if re.search(
            r"enrollments\s*:\s*<LoopMfaEnrollment>\[[^\]]*LoopMfaEnrollment\(",
            controller,
        ):
            errors.append(
                "the MFA controller must not construct an enrolment of its own"
            )
        compact = re.sub(r"\s+", " ", controller)
        # S64 gave the controller two lists to publish instead of one, so it
        # has exactly one place that may say "known", and that place copies
        # the answer it was handed. Anything else would be LOOP deciding what
        # the account holds.
        if compact.count("phase: LoopMfaPhase.known") != 1:
            errors.append(
                "the MFA controller must have exactly one place that publishes "
                "a provider answer"
            )
        for marker in (
            "enrollments: List.unmodifiable(facts.enrollments)",
            "passkeys: List.unmodifiable(facts.passkeys)",
        ):
            if marker not in compact:
                errors.append(
                    "the MFA controller must publish the provider's own lists "
                    "verbatim: missing " + marker
                )
        if len(re.findall(r"_publish\(\s*facts", controller)) < 5:
            errors.append(
                "the MFA controller must publish after every read, enrolment, "
                "binding and removal"
            )

    # The SDK is spoken to in one file, like every other provider surface.
    for path in sorted((root / "lib").rglob("*.dart")):
        source = read_text(path)
        if not any(
            marker in source
            for marker in (
                "user.mfa.",
                ".mfa.totp",
                ".mfa.passkeys",
                ".passkey.link(",
                ".passkey.unlink(",
            )
        ):
            continue
        relative = path.relative_to(root).as_posix()
        if not relative.startswith("lib/integrations/privy/"):
            errors.append(
                f"only the Privy integration may call the SDK's MFA API: {relative}"
            )

    # A passkey belongs to a domain, and the domain is a build fact. One file
    # reads it and one gateway decides on it, so no page can talk itself into
    # offering a credential the platform would refuse.
    config_path = root / "lib/app/app_config.dart"
    if config_path.is_file():
        config = strip_dart_comments(read_text(config_path))
        if (
            re.search(
                r"passkeyRelyingPartyForCurrentBuild\s*=>\s*canInitializePrivy",
                config,
            )
            is None
        ):
            errors.append(
                "the passkey relying party must be gated on the provider this "
                "build can actually initialise"
            )
    entitlements_path = root / "ios/Runner/Runner.entitlements"
    if entitlements_path.is_file():
        entitlements = read_text(entitlements_path)
        domain_match = re.search(
            r"String\.fromEnvironment\(\s*'LOOP_PASSKEY_RP_DOMAIN'",
            read_text(config_path) if config_path.is_file() else "",
        )
        profile_path = root / "config/debug.json"
        domain = ""
        if profile_path.is_file():
            try:
                profile = json.loads(read_text(profile_path))
            except (OSError, UnicodeError, json.JSONDecodeError):
                profile = {}
            if isinstance(profile, dict):
                domain = str(profile.get("LOOP_PASSKEY_RP_DOMAIN") or "")
        if domain_match is None:
            errors.append(
                "AppConfig must be the one reader of the passkey relying party"
            )
        elif domain and f"webcredentials:{domain}" not in entitlements:
            errors.append(
                "iOS must claim the same passkey domain the build profile "
                f"configures: webcredentials:{domain}"
            )

    errors.extend(check_behavior_test_evidence(root, ACCOUNT_MFA_TEST_MARKERS))
    return errors


def check_security_capability_truth_contract(root: Path) -> list[str]:
    """Keep method availability separate from enrollment and stored state."""

    errors = require_fragments(
        root,
        {
            # Decision 0053 rebuilt A11 on the V2 design system in zh-CN.
            "lib/features/account/account_screens.dart": (
                "protection-setup-unavailable",
                "security-setup-continue",
                "LOOP 不会保存 PIN",
                # F2: what a page says about a method it does not offer is
                # said in the owner's words, and what it says about the one
                # method that is in force carries its evidence.
                "const walletAutomaticRecoveryEvidence",
                "const walletRecoveryProviderPending",
            ),
            # S8 (decision 0060) rebuilt H5 on `GET /v2/security/capabilities`
            # and `GET /v2/security/summary`: six methods that are off, each
            # with the server's own reason, and no local guess.
            # A method LOOP has not shipped and a method the account has not
            # enabled are different facts, and the page keeps a name for each.
            "lib/features/profile/security/security_screens.dart": (
                "security-capability-block",
                "security-method-",
                "_securityMethodOffLabel",
                "_securityMethodDeferredLabel",
            ),
            "lib/features/profile/security/security_models.dart": (
                "LoopSecurityCapabilityId",
                "providerAccessTerminated",
                "approvalCoverageFromBlockNumber",
            ),
            "lib/integrations/backend/v2/security/loop_v2_security_api.dart": (
                "'approvalCoverageFromBlockNumber',",
            ),
            "test/s8_api_contract_test.dart": (
                "a response claiming the provider was signed out is refused",
                "an effect other than auditOnly is refused",
                "a receipt for another session is refused",
                "decodes the approval coverage start block",
                "the register publishes no dependency version",
            ),
            "lib/core/navigation/surface_catalog.dart": (
                "no protection setting is saved until reviewed enrollment and storage adapters exist",
                "availability without claiming enrollment, recovery setup, or sign-in activity",
            ),
            "test/security_capability_truthfulness_test.dart": tuple(
                marker
                for markers in SECURITY_CAPABILITY_TRUTH_TEST_MARKERS.values()
                for marker in markers
            ),
            "test/s53_onboarding_sequence_test.dart": (
                "03 says 自动恢复 is on, and says why that is true",
                "03 explains an unavailable method in words an owner can use",
                "04 gives every closed protection a reason in plain words",
            ),
            "AGENTS.md": (
                "Capability availability never proves enrollment, configuration, enforcement, or secure persistence.",
            ),
            "README.md": (
                "Account/Profile 安全页已分离能力可用性与配置状态",
            ),
            "docs/product/implementation-constraints.md": (
                "Capability availability never proves that MFA, app lock, recovery, biometrics, passkeys, or an app PIN is enrolled, configured, enforced, or stored.",
            ),
            "docs/product-decisions.md": (
                "A11 and H5 distinguish capability availability from enrollment and stored protection state.",
            ),
            "docs/decisions/0040-separate-security-capability-from-enrollment.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "## Evidence",
            ),
            "docs/failures/providerless-protection-status-and-setup.md": (
                "## Summary",
                "## Root Cause",
                "## Detection",
                "## Prevention",
                "## Evidence",
            ),
            "docs/harness/adoption-report.md": (
                "## Security Capability and Enrollment Truth Boundary",
            ),
            "docs/phase-1/frontend-integration-report.md": (
                "## Security Capability and Enrollment Truth Boundary",
            ),
        },
    )

    account_path = root / "lib/features/account/account_screens.dart"
    if account_path.is_file():
        source = strip_dart_comments(read_text(account_path))
        start = source.find("class SecuritySetupScreen")
        end = source.find("class UnknownAccountScreen", start + 1)
        if start < 0 or end < 0:
            errors.append("A11 security setup must retain one bounded reviewed slice")
        else:
            setup = source[start:end]
            executable = strip_dart_comments_and_strings(setup)
            for marker in (
                "Save protection",
                "stored by the app",
                "Fallback protection",
                "保存保护设置",
                "由 App 保存",
            ):
                if marker in setup:
                    errors.append(
                        "A11 must not claim providerless protection persistence or save: "
                        + marker
                    )
            for pattern, label in (
                (r"\bStatefulWidget\b", "Stateful protection setup"),
                (r"\b_SecurityToggle\s*\(", "local protection toggle"),
                (r"\bSwitch\s*\(", "local protection switch"),
            ):
                if re.search(pattern, executable):
                    errors.append(f"A11 must not restore a providerless {label}")
            on_pressed = re.findall(r"\bonPressed\s*:", executable)
            if (
                len(on_pressed) != 1
                or re.search(r"\bonPressed\s*:\s*onContinue\b", executable)
                is None
            ):
                errors.append(
                    "A11 must preserve exactly one truthful continue-without-changes action"
                )
            # One protection on this page can actually be on: the device's
            # own lock, which the operating system enforces and answers for.
            # Everything else states an availability and never an enrolment,
            # so 已开启 may appear in the lock's row and nowhere else — and
            # that row has to read the lock's state rather than guess it.
            lock_start = setup.find("LoopRecordRow _appLockRow()")
            mfa_start = setup.find("LoopRecordRow _mfaRow()")
            row_start = setup.find("LoopRecordRow _row(")
            lock = (
                setup[lock_start:mfa_start]
                if 0 <= lock_start < mfa_start
                else ""
            )
            mfa = setup[mfa_start:row_start] if 0 <= mfa_start < row_start else ""
            if not lock:
                errors.append(
                    "A11 must keep its device lock row as one bounded reviewed slice"
                )
            if not mfa:
                errors.append(
                    "A11 must keep its MFA row as one bounded reviewed slice"
                )
            # Two rows on this page can be on, and each may only say so from
            # the answer its own owner gave: the device for the lock, the
            # login service for MFA.
            for marker in (
                "mfa?.enrollments",
                "LoopMfaPhase.known",
                "onOpenMfa",
            ):
                if mfa and marker not in mfa:
                    errors.append(
                        "A11's MFA row must report the provider's own answer: "
                        "missing " + marker
                    )
            if mfa and re.search(r"onTap\s*:\s*known\s*&&", mfa) is None:
                errors.append(
                    "A11's MFA row must offer its control only once the "
                    "provider has answered"
                )
            elsewhere = setup.replace(lock, "").replace(mfa, "")
            if re.search(r"'(?:已开启|已启用|已设置)'", elsewhere):
                errors.append(
                    "A11 must not present a capability as an enabled protection"
                )
            for marker in (
                "lock?.enabled",
                "lock?.isAvailable",
                "onToggleAppLock",
                "loopAppLockFactorText(",
            ):
                if lock and marker not in lock:
                    errors.append(
                        "A11's lock row must report the device lock it was "
                        "given: missing " + marker
                    )
            # The control is offered only while the device can be asked, and
            # the asking itself happens in the controller, never here.
            if lock and (
                re.search(
                    r"onTap\s*:\s*available\s*&&\s*!busy\s*\?\s*"
                    r"onToggleAppLock\s*:\s*null",
                    lock,
                )
                is None
            ):
                errors.append(
                    "A11's lock row must offer its control only while the "
                    "device can be asked"
                )

    # 03 is the other page that names protections. It may call exactly one
    # method enabled — the Privy embedded wallet's own default recovery — and
    # only while it also prints the sentence that makes that true and says
    # whose behaviour it is. Everything else on the page stays a capability.
    if account_path.is_file():
        source = strip_dart_comments(read_text(account_path))
        start = source.find("class WalletRecoveryScreen")
        end = source.find("class SecuritySetupScreen", start + 1)
        if start < 0 or end < 0:
            errors.append("03 recovery must retain one bounded reviewed slice")
        else:
            recovery = source[start:end]
            claims = re.findall(r"'(?:\u5df2\u5f00\u542f|\u5df2\u542f\u7528|\u5df2\u8bbe\u7f6e)'", recovery)
            if claims and "walletAutomaticRecoveryEvidence" not in recovery:
                errors.append(
                    "03 may call a recovery method enabled only where it also "
                    "shows the evidence sentence"
                )
            if (
                re.search(
                    r"WalletRecoveryMethod\.cloud\s*=>\s*"
                    r"walletAutomaticRecoveryEvidence",
                    recovery,
                )
                is None
            ):
                errors.append(
                    "03 must read 自动恢复's sentence off the evidence constant"
                )
            # An enabled method is reported, never offered: tapping it would
            # claim the owner chose something they did not.
            if re.search(r"onTap\s*:\s*selectable\s*\?", recovery) is None:
                errors.append(
                    "03 must offer only a selectable method, never an enabled one"
                )
            # F2: the step is not a dead end. 确认 continues with whatever is
            # true, so a build with nothing to enrol cannot trap the owner.
            if (
                re.search(
                    r"onPressed\s*:\s*blocked\s*\?\s*null\s*:\s*"
                    r"\(\)\s*=>\s*_decide\(_chosen\)",
                    recovery,
                )
                is None
            ):
                errors.append(
                    "03 must keep 确认 available whether or not a method was chosen"
                )

    evidence = re.search(
        r"const\s+walletAutomaticRecoveryEvidence\s*=\s*'([^']*)'",
        read_text(account_path) if account_path.is_file() else "",
    )
    if evidence is None:
        errors.append("the 自动恢复 evidence sentence must be one named constant")
    elif "Privy" not in evidence.group(1):
        errors.append("the 自动恢复 evidence sentence must name whose behaviour it is")

    security_path = root / "lib/features/profile/security/security_screens.dart"
    if security_path.is_file():
        source = strip_dart_comments(read_text(security_path))
        start = source.find("class SecurityCenterScreen")
        end = source.find("class _SecurityMethodGroup", start + 1)
        if start < 0 or end < 0:
            errors.append("H5 Security Center must retain one bounded reviewed slice")
        else:
            security = source[start:end]
            for marker in (
                "Core protections ready",
                "Add another protection",
                "\u9879\u4fdd\u62a4\u5df2\u5f00\u542f",
            ):
                if marker in security:
                    errors.append(
                        "H5 must not infer configured protection from capability "
                        "availability: " + marker
                    )
            if re.search(r"['\"]\s*\$?\w*\s*/\s*3", security):
                errors.append(
                    "H5 must not restore a capability-derived protection score"
                )
            if "onNavigate('security-setup')" in security:
                errors.append(
                    "H5 must not route MFA or App lock into providerless A11 setup"
                )
            if "onNavigate('seed-backup')" in security or "\u52a9\u8bb0\u8bcd" in security:
                errors.append(
                    "H5 must not restore a recovery-phrase surface or route"
                )
            for destination in ("devices", "notif-settings"):
                if f"onNavigate('{destination}')" not in security:
                    errors.append(
                        f"H5 must preserve its truthful `{destination}` "
                        "information route"
                    )
        row_start = source.find("class _SecurityMethodRow")
        row_end = source.find("class SecurityCenterScreen", row_start + 1)
        if row_start >= 0 and row_end > row_start:
            row = source[row_start:row_end]
            if re.search(
                r"LoopBadge\(\s*'(?:\u5df2\u5f00\u542f|\u5df2\u542f\u7528|\u5df2\u8bbe\u7f6e)'", row
            ):
                errors.append(
                    "H5 must not present a capability as an enabled protection"
                )
            if "loopReasonCodeText(capability.reasonCode)" not in row:
                errors.append(
                    "H5 must render the server's own reason for every method"
                )
        for destination in ("social-recovery", "key-export"):
            if (
                re.search(r"onNavigate\(\s*'" + re.escape(destination) + r"'", source)
                is None
            ):
                errors.append(
                    f"H5 must preserve its truthful `{destination}` "
                    "information route"
                )

    errors.extend(
        check_behavior_test_evidence(root, SECURITY_CAPABILITY_TRUTH_TEST_MARKERS)
    )
    errors.extend(
        check_named_executable_test_evidence(
            root, SECURITY_CAPABILITY_TRUTH_EXECUTABLE_TEST_EVIDENCE
        )
    )
    return errors


LOCAL_DISPLAY_PREFERENCES_TEST_MARKERS = {
    Path("test/loop_display_preferences_test.dart"): (
        "shared-preferences adapter uses one namespaced Boolean key",
        "missing device value starts disabled with persistence available",
        "read failure stays run-local without claiming persistence",
        "bootstrap catches a synchronous platform-store failure",
        "read retry restores an existing value instead of overwriting it",
        "read timeout fails open without blocking application startup",
        "persisted Reduce motion survives a controller reconstruction",
        "rapid changes serialize writes and retain the latest value",
        "write failure keeps the run value and exposes an exact retry",
        "write timeout leaves run-local truth while preserving write order",
        "controller rebuild queues behind an older in-flight write",
        "setting the current value does not issue a duplicate write",
    ),
    Path("test/local_settings_and_help_test.dart"): (
        "Reduce motion remains truthful when local saving is unavailable",
        "Retry reads the existing device preference after load failure",
        "restored device preference disables animations globally",
        "system animation setting remains stricter than stored false",
    ),
}
LOCAL_DISPLAY_PREFERENCES_EXECUTABLE_TEST_EVIDENCE = {
    Path("test/loop_display_preferences_test.dart"): {
        "shared-preferences adapter uses one namespaced Boolean key": (
            r"\bSharedPreferencesLoopDisplayStore\.forTesting\s*\(",
            r"\bawait\s+store\.readReduceMotion\s*\(",
            r"\bawait\s+store\.writeReduceMotion\s*\(",
            r"\bSharedPreferencesLoopDisplayStore\.reduceMotionKey\b",
        ),
        "missing device value starts disabled with persistence available": (
            r"\bloadLoopDisplayPreferences\s*\(",
            r"\bexpect\s*\(\s*loaded\.reduceMotion\s*,\s*isFalse",
            r"\bLoopDisplayPreferencesPersistence\.available\b",
        ),
        "read failure stays run-local without claiming persistence": (
            r"\bfailingReads\s*:\s*1\b",
            r"\bLoopDisplayPreferencesPersistence\.unavailable\b",
        ),
        "bootstrap catches a synchronous platform-store failure": (
            r"\bbootstrapSharedPreferencesDisplayPreferencesForTesting\s*\(",
            r"\bthrow\s+StateError\s*\(",
            r"\bisA<UnavailableLoopDisplayPreferencesStore>\s*\(",
        ),
        "read retry restores an existing value instead of overwriting it": (
            r"\bvalue\s*:\s*true\s*,\s*failingReads\s*:\s*1\b",
            r"\bretryPersistence\s*\(",
            r"\bexpect\s*\(\s*store\.writes\s*,\s*isEmpty",
        ),
        "read timeout fails open without blocking application startup": (
            r"\bCompleter<bool\?>\s*\(",
            r"\btimeout\s*:\s*Duration\.zero\b",
            r"\bLoopDisplayPreferencesPersistence\.unavailable\b",
        ),
        "persisted Reduce motion survives a controller reconstruction": (
            r"\bfirst\.dispose\s*\(",
            r"\bfinal\s+second\s*=\s*await\s+_containerFor\s*\(",
            r"\bsecond\.read\s*\(\s*loopDisplayPreferencesProvider\s*\)\.reduceMotion",
        ),
        "rapid changes serialize writes and retain the latest value": (
            r"\bCompleter<void>\s*\(",
            r"\bcontroller\.setReduceMotion\s*\(\s*true\s*\)",
            r"\bcontroller\.setReduceMotion\s*\(\s*false\s*\)",
            r"\bexpect\s*\(\s*store\.writes\s*,\s*<bool>\[\s*true\s*,\s*false\s*\]",
            r"\bFuture\.wait\s*\(",
        ),
        "write failure keeps the run value and exposes an exact retry": (
            r"\bfailingWrites\s*:\s*1\b",
            r"\bcontroller\.setReduceMotion\s*\(\s*true\s*\)",
            r"\bcontroller\.retryPersistence\s*\(",
            r"\bLoopDisplayPreferencesPersistence\.unavailable\b",
            r"\bLoopDisplayPreferencesPersistence\.available\b",
        ),
        "write timeout leaves run-local truth while preserving write order": (
            r"\bioTimeout\s*:\s*Duration\.zero\b",
            r"\bcontroller\.setReduceMotion\s*\(\s*true\s*\)",
            r"\bcontroller\.setReduceMotion\s*\(\s*false\s*\)",
            r"\bexpect\s*\(\s*store\.writes\s*,\s*<bool>\[\s*true\s*,\s*false\s*\]",
        ),
        "controller rebuild queues behind an older in-flight write": (
            r"\bcontainer\.invalidate\s*\(\s*loopDisplayPreferencesProvider\s*\)",
            r"\bfinal\s+newController\s*=\s*container\.read",
            r"\bexpect\s*\(\s*store\.writes\s*,\s*<bool>\[\s*true\s*,\s*true\s*,\s*false\s*\]",
        ),
        "setting the current value does not issue a duplicate write": (
            r"\bsetReduceMotion\s*\(\s*false\s*\)",
            r"\bexpect\s*\(\s*store\.writes\s*,\s*isEmpty",
        ),
    },
    Path("test/local_settings_and_help_test.dart"): {
        "Reduce motion remains truthful when local saving is unavailable": (
            r"\bfind\.byKey\s*\(\s*reduceMotionRow\s*\)",
            r"\btester\.tap\s*\(",
            r"\bcontainer\.read\s*\(\s*loopDisplayPreferencesProvider\s*\)\.reduceMotion",
            r"\bMediaQuery\.disableAnimationsOf\s*\(",
            r"\bfind\.text\s*\([\s\S]*?\)\s*,\s*findsOneWidget",
        ),
        "Retry reads the existing device preference after load failure": (
            r"\b_RecoveringDisplayStore\s*\(",
            r"\btester\.tap\s*\(",
            r"\bexpect\s*\(\s*store\.writes\s*,\s*isEmpty",
        ),
        "restored device preference disables animations globally": (
            r"\bLoopDisplayPreferences\s*\(\s*reduceMotion\s*:\s*true",
            r"\bMediaQuery\.disableAnimationsOf\s*\(",
            r"\bfind\.byKey\s*\(\s*reduceMotionRow\s*\)",
            r"\bfind\.text\s*\([\s\S]*?\)\s*,\s*findsOneWidget",
        ),
        "system animation setting remains stricter than stored false": (
            r"\bFakeAccessibilityFeatures\s*\(\s*disableAnimations\s*:\s*true",
            r"\bcontainer\.read\s*\(\s*loopDisplayPreferencesProvider\s*\)\.reduceMotion\s*,\s*isFalse",
            r"\bMediaQuery\.disableAnimationsOf\s*\(",
        ),
    },
}


def check_local_display_preferences_contract(root: Path) -> list[str]:
    """Keep device persistence narrow, non-sensitive, and truthful."""

    errors = require_fragments(
        root,
        {
            "lib/app/loop_display_preferences.dart": (
                "enum LoopDisplayPreferencesPersistence",
                "abstract interface class LoopDisplayPreferencesStore",
                "Future<bool?> readReduceMotion()",
                "Future<void> writeReduceMotion(bool value)",
                "Future<LoopDisplayPreferences> loadLoopDisplayPreferences(",
                "const loopDisplayPreferencesIoTimeout = Duration(seconds: 1)",
                "Future<void> setReduceMotion(bool value)",
                "Future<void> retryPersistence()",
                "final previous = _writeTail",
            ),
            "lib/integrations/personalization/shared_preferences_display_store.dart": (
                "class SharedPreferencesLoopDisplayStore",
                "SharedPreferencesAsync()",
                "loop.display.v1.reduce_motion",
                "readReduceMotion()",
                "writeReduceMotion(bool value)",
                "bootstrapSharedPreferencesDisplayPreferences(",
                "bootstrapSharedPreferencesDisplayPreferencesForTesting(",
            ),
            "lib/main.dart": (
                "await bootstrapSharedPreferencesDisplayPreferences()",
                "loopDisplayPreferencesStoreProvider.overrideWithValue(",
                "displayBootstrap.store",
                "loopDisplayPreferencesInitialProvider.overrideWithValue(",
                "displayBootstrap.initial",
            ),
            "lib/main_preview.dart": (
                "await bootstrapSharedPreferencesDisplayPreferences()",
                "loopDisplayPreferencesStoreProvider.overrideWithValue(",
                "displayBootstrap.store",
                "loopDisplayPreferencesInitialProvider.overrideWithValue(",
                "displayBootstrap.initial",
            ),
            "lib/app.dart": (
                "preferences.reduceMotion",
                "MediaQuery.disableAnimationsOf(context)",
                "copyWith(disableAnimations: true)",
            ),
            # S8 (decision 0060) rebuilt H12 on the V2 design system in zh-CN
            # and moved the two account values onto `GET /v2/settings`.
            "lib/features/profile/settings/settings_screen.dart": (
                "settings-reduce-motion",
                "settings-retry-display-storage",
                "\u672c\u673a\u4fdd\u5b58\u4e0d\u53ef\u7528",
                "settings-theme",
                "settings-language",
                "settings-display-currency",
            ),
            "test/loop_display_preferences_test.dart": tuple(
                marker
                for marker in LOCAL_DISPLAY_PREFERENCES_TEST_MARKERS[
                    Path("test/loop_display_preferences_test.dart")
                ]
            ),
            "AGENTS.md": (
                "Keep device-local display persistence limited to the non-sensitive `reduceMotion` Boolean",
            ),
            "README.md": (
                "General Settings 的 Reduce motion 已使用设备本地非敏感偏好持久化",
            ),
            "docs/product/implementation-constraints.md": (
                "Device-local display persistence contains only the non-sensitive `reduceMotion` Boolean",
            ),
            "docs/product-decisions.md": (
                "H12 persists only Reduce motion as one installation-scoped, non-sensitive Boolean",
            ),
            "docs/decisions/0042-persist-only-device-display-preferences.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "## Evidence",
            ),
            "docs/harness/adoption-report.md": (
                "## Device-Local Display Preferences",
            ),
            "docs/phase-1/frontend-integration-report.md": (
                "## Device-Local Display Preferences",
            ),
        },
    )

    allowed_importer = Path(
        "lib/integrations/personalization/shared_preferences_display_store.dart"
    )
    # Two reviewed adapters may touch device-local preferences, and no other
    # file may. The second one (S53) stores where the five-step account
    # opening got to; it is pinned just as narrowly by
    # `check_onboarding_sequence_contract`.
    allowed_importers = {
        allowed_importer,
        ONBOARDING_PROGRESS_STORE_OWNER,
    }
    lib_root = root / "lib"
    if lib_root.is_dir():
        for path in lib_root.rglob("*.dart"):
            relative = path.relative_to(root)
            source = strip_dart_comments(read_text(path))
            if "package:shared_preferences/shared_preferences.dart" in source:
                if relative not in allowed_importers:
                    errors.append(
                        "Shared Preferences must stay behind the reviewed display store adapter: "
                        + str(relative)
                    )

    adapter_path = root / allowed_importer
    if adapter_path.is_file():
        adapter_source = strip_dart_comments(read_text(adapter_path))
        adapter = strip_dart_comments_and_strings(adapter_source)
        imports = re.findall(
            r"^import\s+['\"]([^'\"]+)['\"](?:\s+show\s+[^;]+)?\s*;",
            adapter_source,
            flags=re.MULTILINE,
        )
        if imports != [
            "package:flutter/foundation.dart",
            "package:loop_mobile/app/loop_display_preferences.dart",
            "package:shared_preferences/shared_preferences.dart",
        ]:
            errors.append(
                "The display store adapter imports only Flutter annotations, its narrow port, and Shared Preferences"
            )
        if len(re.findall(r"\bstatic\s+const\s+String\s+\w+Key\s*=", adapter)) != 1:
            errors.append("The display store must declare exactly one preference key")
        expected_key_declaration = (
            "static const String reduceMotionKey = "
            "'loop.display.v1.reduce_motion';"
        )
        if expected_key_declaration not in adapter_source:
            errors.append(
                "The display store must retain its exact namespaced Boolean key"
            )
        adapter_without_imports = re.sub(
            r"^import\s+['\"][^'\"]+['\"](?:\s+show\s+[^;]+)?\s*;\s*",
            "",
            strip_dart_comments(adapter_source),
            flags=re.MULTILINE,
        )
        string_literals = [
            single or double
            for single, double in re.findall(
                r"'([^'\\]*(?:\\.[^'\\]*)*)'|\"([^\"\\]*(?:\\.[^\"\\]*)*)\"",
                adapter_without_imports,
            )
        ]
        if string_literals != ["loop.display.v1.reduce_motion"]:
            errors.append(
                "The display store may contain only the exact Reduce motion key literal"
            )
        preference_members = re.findall(r"\bpreferences\.(\w+)\b", adapter)
        if preference_members != ["getBool", "setBool"]:
            errors.append(
                "The display store may call only SharedPreferencesAsync getBool/setBool"
            )
        if len(re.findall(r"\bSharedPreferencesAsync\s*\(\s*\)", adapter)) != 1:
            errors.append(
                "The display store must create exactly one SharedPreferencesAsync adapter"
            )
        if len(re.findall(r"\b_readBool\s*\(\s*reduceMotionKey\s*\)", adapter)) != 1:
            errors.append(
                "The display store read must use only the exact Reduce motion key"
            )
        if len(
            re.findall(
                r"\b_writeBool\s*\(\s*reduceMotionKey\s*,\s*value\s*\)",
                adapter,
            )
        ) != 1:
            errors.append(
                "The display store write must use only the exact Reduce motion key"
            )
        if re.search(
            r"\b(?:clear|remove|getAll|getKeys|getString|setString|getInt|setInt|getDouble|setDouble|getStringList|setStringList)\s*\(",
            adapter,
        ):
            errors.append(
                "The display store may only read or write its exact Reduce motion key"
            )

    reviewed_consumers = {
        allowed_importer,
        Path("lib/main.dart"),
        Path("lib/main_preview.dart"),
    }
    if lib_root.is_dir():
        for path in lib_root.rglob("*.dart"):
            relative = path.relative_to(root)
            source = strip_dart_comments_and_strings(read_text(path))
            if (
                "SharedPreferencesLoopDisplayStore" in source
                and relative not in reviewed_consumers
            ):
                errors.append(
                    "The device display adapter may only be composed by reviewed app roots: "
                    + str(relative)
                )

    settings_path = root / "lib/features/profile/settings/settings_screen.dart"
    if settings_path.is_file():
        source = strip_dart_comments(read_text(settings_path))
        start = source.find("class _GeneralSettingsScreenState")
        if start < 0:
            errors.append("H12 Settings must retain one bounded reviewed slice")
        else:
            settings = source[start:]
            executable = strip_dart_comments_and_strings(settings)
            # Exactly one device-local control is implemented; everything else
            # is either a fixed server value or a navigation entry.
            if len(re.findall(r"\bsetReduceMotion\s*\(", executable)) != 1:
                errors.append(
                    "H12 must expose exactly one implemented display switch"
                )
            for key in (
                "settings-language",
                "settings-display-currency",
                "settings-theme",
            ):
                position = settings.find("ValueKey<String>('" + key + "')")
                row_start = settings.rfind("LoopRecordRow(", 0, position)
                row_end = settings.find("LoopRecordRow(", position + 1)
                if row_end < 0:
                    row_end = len(settings)
                row = (
                    settings[row_start:row_end]
                    if position >= 0 and row_start >= 0
                    else ""
                )
                if row == "" or re.search(r"\bonTap\s*:", row) is not None:
                    errors.append("H12 `" + key + "` must remain read-only")
            # The prototype's data-usage figure has no source, so the row is
            # absent rather than filled with an invented number.
            data_usage = "\u6570\u636e\u7528\u91cf"
            if data_usage in settings.replace('\u6ca1\u6709"' + data_usage + '"', ""):
                errors.append("H12 must not restore the sourceless data-usage row")

    errors.extend(
        check_behavior_test_evidence(root, LOCAL_DISPLAY_PREFERENCES_TEST_MARKERS)
    )
    errors.extend(
        check_named_executable_test_evidence(
            root, LOCAL_DISPLAY_PREFERENCES_EXECUTABLE_TEST_EVIDENCE
        )
    )
    return errors


BUILD_PROFILE_TEST_MARKERS = {
    Path("test/app_config_test.dart"): (
        "missing build profile and identifiers fail closed",
        "declared build profile must match Debug or Release runtime",
        "a profile mismatch gates every provider-backed capability",
        "build profile never widens the locked product security policy",
    ),
    Path("test/loop_bootstrap_providers_test.dart"): (
        "a build-profile mismatch gates backend and Stream composition",
    ),
    Path("test/privy_provider_test.dart"): (
        "the signing exit reads the centralized matching AppConfig",
        "a build-profile mismatch strips Privy provider inputs",
    ),
}


def check_onboarding_sequence_contract(root: Path) -> list[str]:
    """Keep the five-step account opening reachable, resumable and truthful."""

    errors = require_fragments(
        root,
        {
            # S53 (decision 0075): the prototype opens an account in five
            # numbered steps. Shipping only step 05 skipped three pages the
            # product promised (device report 2026-09-20).
            "lib/app/session/onboarding_sequence.dart": (
                "enum LoopOnboardingStep",
                "walletCreate(2, 'wallet-create',",
                "walletBackup(3, 'wallet-recovery',",
                "security(4, 'security-setup',",
                "loopId(5, 'loop-id-setup',",
                "static const total = 5",
                "abstract interface class LoopOnboardingProgressStore",
                "class UnavailableLoopOnboardingProgressStore",
                "loopOnboardingProgressStoreProvider",
                "Future<LoopOnboardingStep> begin(String principalKey)",
                "void moveTo(LoopOnboardingStep step)",
                "void recordRecoveryDecision(String? methodName)",
                "Future<void> complete({String? principalKey})",
                "void leave()",
            ),
            "lib/integrations/personalization/shared_preferences_onboarding_store.dart": (
                "class SharedPreferencesLoopOnboardingProgressStore",
                "SharedPreferencesAsync()",
                "loop.onboarding.v1.step.",
                "LoopOnboardingStep.tryParse(",
            ),
            "lib/features/account/wallet_creation_facts.dart": (
                "enum LoopWalletCreationPhase",
                "class LoopWalletCreationFacts",
                "static const Duration pollInterval = Duration(seconds: 2)",
                "static const int maximumAttempts = 30",
                "loopEmbeddedWalletWatchProvider",
                "loopWalletCreationFactsProvider",
                "directory.embedded.isNotEmpty",
            ),
            "lib/features/account/wallet_create_step_screen.dart": (
                "class WalletCreateStepScreen",
                "loopEmbeddedWalletWatchProvider.notifier).start()",
                "loopWalletCreationFactsProvider",
            ),
            "lib/app.dart": (
                # F1: the position is read before the landing is published
                # and the step is navigated to after it, so the launch gate
                # never opens on a sequence that has nowhere to be yet.
                "Future<void> _beginOnboardingSequence() async",
                "void _goToOnboardingStep()",
                "_onboardingStepScreen(",
                "LoopOnboardingStep? _onboardingStepFor(String id)",
                "loopOnboardingSequenceProvider.notifier).leave()",
            ),
            "lib/main.dart": (
                "loopOnboardingProgressStoreProvider.overrideWithValue(",
                "SharedPreferencesLoopOnboardingProgressStore()",
            ),
            "test/s53_onboarding_sequence_test.dart": (
                "a pending account lands on 02, not straight on 05",
                "a pending account never passes through Community",
                "a resumed account continues on its step, not through 02",
                "an active account goes straight to Community",
                "a profile that never answers stops waiting and says so",
                "a killed process reopens on the step it stopped on",
                "an active account never enters the sequence",
                "60 seconds without a wallet times out and never fails",
                'a refused read is never read as "you have no wallet"',
                "a seen wallet ticks the two steps it actually proves",
                "an unseen wallet leaves every step unfinished",
                "the key is namespaced and partitioned by account",
            ),
            "docs/decisions/0075-open-an-account-in-five-steps.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "## Evidence",
            ),
            "docs/product/implementation-constraints.md": (
                "The opening sequence stores a step name only",
            ),
            "docs/product-decisions.md": (
                "A pending account opens through all five prototype steps",
            ),
        },
    )

    # The 02 page may never tick a row it has not observed. Every completion
    # in the reviewed slice reads a fact off the facts object.
    account_path = root / "lib/features/account/account_screens.dart"
    if account_path.is_file():
        source = strip_dart_comments(read_text(account_path))
        start = source.find("class WalletCreateScreen")
        end = source.find("class WalletRecoveryScreen", start + 1)
        if start < 0 or end < 0:
            errors.append("the wallet-create step must stay one bounded slice")
        else:
            slice_ = source[start:end]
            for marker in (
                "facts.walletObserved",
                "facts.recoveryEnrolled",
                "facts.loopIdActivated",
                "wallet-create-step-",
            ):
                if marker not in slice_:
                    errors.append(
                        "the wallet-create step must read every tick off an "
                        "observation: missing " + marker
                    )
            if re.search(r"\bdone\s*:\s*true\b", slice_):
                errors.append(
                    "the wallet-create step must not hard-code a finished step"
                )

    adapter_path = root / ONBOARDING_PROGRESS_STORE_OWNER
    if adapter_path.is_file():
        adapter_source = strip_dart_comments(read_text(adapter_path))
        adapter = strip_dart_comments_and_strings(adapter_source)
        imports = re.findall(
            r"^import\s+['\"]([^'\"]+)['\"](?:\s+show\s+[^;]+)?\s*;",
            adapter_source,
            flags=re.MULTILINE,
        )
        if imports != [
            "package:flutter/foundation.dart",
            "package:loop_mobile/app/session/onboarding_sequence.dart",
            "package:shared_preferences/shared_preferences.dart",
        ]:
            errors.append(
                "the onboarding progress adapter imports only Flutter "
                "annotations, its narrow port, and Shared Preferences"
            )
        if "static const String keyPrefix = 'loop.onboarding.v1.step.';" not in (
            adapter_source
        ):
            errors.append(
                "the onboarding progress adapter must retain its exact "
                "namespaced key prefix"
            )
        preference_members = re.findall(r"\bpreferences\.(\w+)\b", adapter)
        if preference_members != ["getString", "setString", "remove"]:
            errors.append(
                "the onboarding progress adapter may call only "
                "SharedPreferencesAsync getString/setString/remove"
            )
        if len(re.findall(r"\bSharedPreferencesAsync\s*\(\s*\)", adapter)) != 1:
            errors.append(
                "the onboarding progress adapter must create exactly one "
                "SharedPreferencesAsync adapter"
            )
        if len(re.findall(r"\bstatic\s+const\s+String\s+\w+\s*=", adapter)) != 1:
            errors.append(
                "the onboarding progress adapter must declare exactly one key"
            )

    return errors


def check_build_profile_configuration_contract(root: Path) -> list[str]:
    """Keep Debug/Release client values centralized and fail-closed."""

    errors = require_fragments(
        root,
        {
            "lib/app/app_config.dart": (
                "enum LoopBuildMode { debug, release }",
                "const String.fromEnvironment('LOOP_BUILD_MODE')",
                "const String.fromEnvironment('PRIVY_APP_ID')",
                "const String.fromEnvironment('PRIVY_APP_CLIENT_ID')",
                "const String.fromEnvironment('REOWN_PROJECT_ID')",
                "const String.fromEnvironment('STREAM_API_KEY')",
                "const String.fromEnvironment('LOOP_BACKEND_BASE_URL')",
                "const bool.fromEnvironment('FIREBASE_CONFIGURED')",
                "configuredBuildMode == expectedBuildMode",
                "backendBaseUrlForCurrentBuild",
                "streamApiKeyForCurrentBuild",
                "canInitializeFirebase",
            ),
            ".vscode/launch.json": (
                '"name": "Loop"',
                '"flutterMode": "debug"',
                "--dart-define-from-file=config/debug.json",
            ),
            ".gitignore": (
                "/config/release.json",
                "/config/*.local.json",
            ),
            "lib/integrations/backend/loop_backend_providers.dart": (
                "config.backendBaseUrlForCurrentBuild",
            ),
            "lib/integrations/communication/stream_chat_providers.dart": (
                "config.streamApiKeyForCurrentBuild",
            ),
            "lib/integrations/communication/stream_video_providers.dart": (
                "config.streamApiKeyForCurrentBuild",
            ),
            "lib/integrations/privy/privy_provider.dart": (
                "ref.watch(appConfigProvider)",
                "config.canInitializePrivy",
            ),
            "lib/app/app_environment.dart": (
                "static const appEnvironment = AppEnvironment.development",
                "static const hyperliquidEnvironment = HyperliquidEnvironment.testnet",
                "static const mainnetEnabled = false",
                "static const withdrawalsEnabled = false",
                "static const automatedTradingEnabled = false",
                "static const spotExecutionEnabled = false",
            ),
            "docs/decisions/0044-separate-build-profiles-from-product-environments.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "LOOP_BUILD_MODE",
                "Debug versus Release is a distribution profile, not a product environment",
            ),
            "config/README.md": (
                "--dart-define-from-file=config/release.json",
                "Sentry DSN",
                "AppsFlyer Dev Key",
                "compiled into the application binary",
            ),
            "README.md": (
                "--dart-define-from-file=config/debug.json",
                "Debug/Release 只是构建配置轴",
            ),
            "docs/product/implementation-constraints.md": (
                "Debug/Profile versus Release is only a client build-profile axis",
            ),
            "docs/product-decisions.md": (
                "This profile is not a Production/Mainnet switch",
            ),
            "docs/harness/adoption-report.md": (
                "## Build Profile and Stream Token Client Update",
            ),
            "docs/phase-1/frontend-integration-report.md": (
                "## Build-Profile Configuration and Stream Token Loading",
            ),
        },
    )

    expected_profiles = {
        Path("config/debug.json"): {
            "LOOP_BUILD_MODE": "debug",
            "LOOP_CLIENT_VERSION": "0.1.0+1",
            "PRIVY_APP_ID": "cmt2t8k4n00780cjsxjqk0dkq",
            "PRIVY_APP_CLIENT_ID": "client-WY6ctzX8CSMMKhbvz8exuLovn1dTJyq8hReY1x63pBFfd",
            "REOWN_PROJECT_ID": "26a5cc1adad234fcdf7762b8d2a2b28d",
            "STREAM_API_KEY": "qpwjdy8zjbdu",
            "LOOP_BACKEND_BASE_URL": "https://api-dev.quant-dinger.cc",
            "LOOP_PASSKEY_RP_DOMAIN": "api-dev.quant-dinger.cc",
            "FIREBASE_CONFIGURED": "true",
        },
        Path("config/release.example.json"): {
            "LOOP_BUILD_MODE": "release",
            "LOOP_CLIENT_VERSION": "0.1.0+1",
            "PRIVY_APP_ID": "",
            "PRIVY_APP_CLIENT_ID": "",
            "REOWN_PROJECT_ID": "",
            "STREAM_API_KEY": "",
            "LOOP_BACKEND_BASE_URL": "",
            "LOOP_PASSKEY_RP_DOMAIN": "",
            "FIREBASE_CONFIGURED": "false",
        },
    }
    forbidden_key_markers = (
        "SECRET",
        "PRIVATE_KEY",
        "SERVICE_ACCOUNT",
        "SENTRY_AUTH_TOKEN",
        "APPSFLYER_S2S",
    )
    for relative, expected in expected_profiles.items():
        path = root / relative
        if not path.is_file():
            continue
        try:
            profile = json.loads(read_text(path))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            errors.append(f"client build profile is not valid JSON: {relative}: {error}")
            continue
        if profile != expected:
            errors.append(f"client build profile has drifted: {relative}")
        if isinstance(profile, dict):
            for key in profile:
                if isinstance(key, str) and any(
                    marker in key.upper() for marker in forbidden_key_markers
                ):
                    errors.append(
                        f"client build profile contains forbidden credential key: {relative}: {key}"
                    )

    lib_root = root / "lib"
    if lib_root.is_dir():
        owner = Path("lib/app/app_config.dart")
        for path in lib_root.rglob("*.dart"):
            relative = path.relative_to(root)
            if relative == owner:
                continue
            source = strip_dart_comments_and_strings(read_text(path))
            if re.search(r"\b(?:String|bool|int)\.fromEnvironment\s*\(", source):
                errors.append(
                    f"Dart build configuration must stay inside AppConfig: {relative}"
                )

    launch_path = root / ".vscode/launch.json"
    if launch_path.is_file():
        try:
            launch = json.loads(read_text(launch_path))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            errors.append(f"IDE launch configuration is not valid JSON: {error}")
        else:
            configurations = (
                launch.get("configurations") if isinstance(launch, dict) else None
            )
            loop_targets = (
                [
                    target
                    for target in configurations
                    if isinstance(target, dict) and target.get("name") == "Loop"
                ]
                if isinstance(configurations, list)
                else []
            )
            expected_tool_args = ["--dart-define-from-file=config/debug.json"]
            if (
                len(loop_targets) != 1
                or loop_targets[0].get("toolArgs") != expected_tool_args
            ):
                errors.append(
                    "The IDE Loop target must inject only the reviewed Debug profile file"
                )

    for candidate in ("config/release.json", "config/team.local.json"):
        result = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "check-ignore",
                "--no-index",
                "--quiet",
                "--",
                candidate,
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            errors.append(f"local client build profile must be ignored: {candidate}")

    errors.extend(check_behavior_test_evidence(root, BUILD_PROFILE_TEST_MARKERS))
    return errors


STREAM_TOKEN_CLIENT_TEST_MARKERS = {
    Path("test/loop_stream_token_repository_test.dart"): (
        "posts exact Chat and Video requests and returns only SDK token",
        "rejects response drift before exposing a token",
        "maps only strict sanitized backend errors",
        "malformed HTTP errors cannot trigger credential recovery",
        "status and public error code must match the exact contract",
        "rejects invalid local inputs before dispatch",
    ),
    Path("test/loop_stream_token_session_test.dart"): (
        "bootstraps first and passes a fresh bearer to the token route",
        "one 401 refreshes Privy access token exactly once",
        "a second 401 fails without requesting a third route token",
        "one bootstrap_required reauthorizes the same identity and replays",
        "401 and bootstrap recovery share bounded independent budgets",
        "a repeated bootstrap_required invalidates and fails closed",
        "wrong SDK user and 429 never enter a retry loop",
    ),
    Path("test/loop_bootstrap_providers_test.dart"): (
        "Chat and Video share bootstrap identity and request separate SDK tokens",
    ),
}


def check_stream_token_client_contract(root: Path) -> list[str]:
    """Keep Stream credentials backend-owned, bounded, and non-persisting."""

    errors = require_fragments(
        root,
        {
            "lib/integrations/backend/loop_stream_token.dart": (
                "enum LoopStreamTokenProduct",
                "abstract interface class LoopStreamTokenRepository",
            ),
            "lib/integrations/backend/loop_stream_token_repository.dart": (
                "LoopStreamTokenProduct.chat => '/v1/chat/token'",
                "LoopStreamTokenProduct.video => '/v1/video/token'",
                "'authorization': 'Bearer $accessToken'",
                "'api_key'",
                "'expires_at'",
                "'user'",
                "_expectedApiKey",
                "expectedStreamUserId",
                "_hasNoStore",
                "_parseErrorMetadata",
                "_isStableErrorCodeForStatus",
                "responseRequestIds.single != requestId",
                "Duration(minutes: 65)",
            ),
            "lib/integrations/backend/loop_stream_token_session.dart": (
                "var refreshedAuthentication = false",
                "var repeatedBootstrap = false",
                "failure.statusCode == 401",
                "failure.code == 'bootstrap_required'",
                "_bootstrapSession.invalidateAuthorization()",
                "identity.streamUserId != expectedStreamUserId",
            ),
            "lib/integrations/backend/loop_stream_token_providers.dart": (
                "ref.watch(loopBackendDioProvider)",
                "config.streamApiKeyForCurrentBuild",
                "loopStreamTokenSessionProvider",
            ),
            "lib/integrations/communication/stream_chat_providers.dart": (
                "LoopStreamTokenProduct.chat",
                "ref.watch(loopStreamTokenSessionProvider)",
            ),
            "lib/integrations/communication/stream_video_providers.dart": (
                "LoopStreamTokenProduct.video",
                "ref.watch(loopStreamTokenSessionProvider)",
            ),
            "docs/decisions/0045-connect-bounded-stream-user-token-loader.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "at most three token POSTs",
                "Audio Room locator",
            ),
            "README.md": (
                "POST /v1/chat/token",
                "POST /v1/video/token",
                "Token 不缓存、不落盘",
            ),
            "docs/product/implementation-constraints.md": (
                "Chat/Video user-token loaders may call only",
            ),
            "docs/product-decisions.md": (
                "one principal-bound, non-persisting loader",
            ),
        },
    )

    lib_root = root / "lib"
    if lib_root.is_dir():
        route_owner = Path(
            "lib/integrations/backend/loop_stream_token_repository.dart"
        )
        for route in ("/v1/chat/token", "/v1/video/token"):
            owners = []
            for path in lib_root.rglob("*.dart"):
                if route in read_text(path):
                    owners.append(path.relative_to(root))
            if owners and owners != [route_owner]:
                errors.append(
                    f"Stream token route must stay inside its strict backend repository: {route}: {owners}"
                )

        for path in lib_root.rglob("*.dart"):
            source = read_text(path)
            if "stream_token_contract_unavailable" in source:
                errors.append(
                    f"implemented Stream token contract regressed to unavailable: {path.relative_to(root)}"
                )

    for relative in (
        Path("lib/integrations/backend/loop_stream_token_repository.dart"),
        Path("lib/integrations/backend/loop_stream_token_session.dart"),
    ):
        path = root / relative
        if not path.is_file():
            continue
        source = strip_dart_comments_and_strings(read_text(path))
        for forbidden in (
            "SharedPreferences",
            "FlutterSecureStorage",
            "Hive",
            "base64Decode",
            "print(",
            "Log.",
        ):
            if forbidden in source:
                errors.append(
                    f"Stream tokens must not be persisted, decoded, or logged: {relative}: {forbidden}"
                )

    errors.extend(check_behavior_test_evidence(root, STREAM_TOKEN_CLIENT_TEST_MARKERS))
    return errors


V2_SESSION_TEST_MARKERS = {
    Path("test/app_config_test.dart"): (
        "V2 client version is strict SemVer and build-profile scoped",
    ),
    Path("test/loop_v2_meta_repository_test.dart"): (
        "client policy GET is credential-free and parses every gate",
        "strict policy rejects drift, reordered tabs, and invalid proof",
        "V2 metadata error requires exact code and request correlation",
    ),
    Path("test/loop_v2_meta_providers_test.dart"): (
        "missing backend origin composes no public metadata client",
        "snapshot starts policy and capabilities reads concurrently",
        "snapshot does not automatically retry a failed metadata read",
        "LoopApp starts D0 reads and a failure cannot block authenticated UI",
        "unavailable and pending D0 observations cannot bypass authentication",
    ),
    Path("test/loop_v2_session_api_test.dart"): (
        "account/me sends only its exact V2 business headers",
        "bootstrap sends persisted metadata and parses opaque IDs",
        "logout adds only the opaque session header",
        "strict success rejects extra fields and missing response proof",
        "V2 errors require the exact envelope and correlation proof",
    ),
    Path("test/loop_v2_session_coordinator_test.dart"): (
        "restored account reuses only a matching active local session",
        "account/me precedes a write-before-dispatch bootstrap",
        "ambiguous bootstrap reuses its exact persisted command",
        "a local/server identity mismatch fails closed without bootstrap",
        "logout persists before dispatch and clears a terminal result",
        "unknown logout retains and reuses the same command",
        "SESSION_NOT_FOUND is non-enumerating and terminal",
        "a later login reconciles an unconfirmed logout before new bootstrap",
        "logout quiescence waits for a dispatched bootstrap before revocation",
        "retirement cancels bootstrap before its write request is sent",
        "ACCOUNT_BOOTSTRAP_REQUIRED replaces a stale local active session",
        "ACCOUNT_BOOTSTRAP_REQUIRED discards stale active logout recovery",
        "logout retires a pending bootstrap before revoking its recovered session",
        "failed pending-bootstrap retirement is recovered before a fresh login",
    ),
    Path("test/loop_v2_session_store_test.dart"): (
        "creates one canonical device ID and reuses it",
        "round trips the exact owner journal without raw principal or tokens",
        "write validates the complete journal before touching storage",
        "journal state machine rejects overlapping bootstrap and logout",
        "malformed critical state fails closed instead of rotating IDs",
        "unknown journal fields and impossible logout state fail closed",
    ),
    Path("test/loop_session_controller_test.dart"): (
        "ordered logout keeps the local barrier while backend and Stream retire",
        "duplicate exit calls share one cleanup operation",
    ),
    Path("test/privy_login_screen_test.dart"): (
        "signing out blocks every login entry until backend cleanup really ends",
    ),
}
# S53: the only file allowed to store where the five-step account opening
# got to. The value is a step name partitioned by the opaque V2 owner
# partition — never a credential, an account resource or a claim that
# anything was enrolled.
ONBOARDING_PROGRESS_STORE_OWNER = Path(
    "lib/integrations/personalization/shared_preferences_onboarding_store.dart"
)
V2_SECURE_STORAGE_OWNER = Path(
    "lib/integrations/backend/v2/loop_v2_session_store.dart"
)
# The platform secure store has two owners and no more. The first keeps the
# V2 session journal — device id, tokens, everything a stolen device could be
# replayed with. The second keeps the application lock's single boolean and
# nothing else: LOOP never sees a PIN or a biometric template, so there is no
# secret there to leak, and `check_app_lock_contract` holds it to one of two
# characters under one key. A third owner is a decision, not an edit.
SECURE_STORAGE_OWNERS = frozenset(
    {
        V2_SECURE_STORAGE_OWNER,
        Path("lib/integrations/device/secure_storage_app_lock_store.dart"),
    }
)
# The activation journal (decision 0053) reuses the session store's secure
# facade instead of opening a second platform store. It may name the facade
# type, but only the owner above may import or instantiate the platform SDK.
V2_SECURE_FACADE_CONSUMERS = frozenset(
    {
        V2_SECURE_STORAGE_OWNER,
        Path("lib/integrations/backend/v2/profile/loop_v2_activation_store.dart"),
    }
)
V2_SECURE_JOURNAL_RUNTIME_USERS = frozenset(
    {
        V2_SECURE_STORAGE_OWNER,
        Path("lib/integrations/backend/v2/loop_v2_session_providers.dart"),
        Path("lib/integrations/backend/v2/profile/loop_v2_profile_providers.dart"),
    }
)
V2_SERIALIZED_JOURNAL_KEYS = (
    "deviceId",
    "idempotencyKey",
    "clientVersion",
    "platform",
    "contractVersion",
    "accountId",
    "sessionId",
    "streamUserId",
    "deviceId",
    "schemaVersion",
    "pendingBootstrap",
    "activeSession",
    "pendingLogout",
    "bootstrapRetirementRequested",
    "revocationUnconfirmed",
)
V2_PARSED_JOURNAL_KEYSETS = (
    (
        "schemaVersion",
        "pendingBootstrap",
        "activeSession",
        "pendingLogout",
        "bootstrapRetirementRequested",
        "revocationUnconfirmed",
    ),
    (
        "deviceId",
        "idempotencyKey",
        "clientVersion",
        "platform",
        "contractVersion",
    ),
    ("accountId", "sessionId", "streamUserId", "deviceId"),
)
V2_FORBIDDEN_PERSISTED_IDENTIFIERS = frozenset(
    {
        "accesstoken",
        "authtoken",
        "credential",
        "email",
        "mnemonic",
        "password",
        "phone",
        "phonenumber",
        "pin",
        "principal",
        "principalkey",
        "privatekey",
        "providerresponse",
        "rawprincipal",
        "refreshtoken",
        "seedphrase",
        "signature",
        "streamtoken",
        "wallet",
        "walletaccount",
        "walletaddress",
    }
)
V2_CLIENT_SEMVER_PATTERN = re.compile(
    r"^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\."
    r"(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*|"
    r"[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|"
    r"[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)


def check_v2_session_contract(root: Path) -> list[str]:
    """Lock D0/D1 V2 composition and its narrow secure journal boundary."""

    errors = require_fragments(
        root,
        {
            "harness.json": (
                "Flutter Secure Storage 10.3.1 / V2 device-session journal only",
                "LOOP_CLIENT_VERSION comes only from the matching Debug or Release build profile",
                "Secure storage is limited to the V2 device-session journal allowlist",
            ),
            "docs/decisions/0049-connect-v2-account-device-session.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "flutter_secure_storage` 10.3.1",
                "Supply client version through the matching build profile",
                "The raw principal is never written by LOOP",
                "tokens and the implemented social routes remain frozen V1 consumers",
            ),
            "lib/app/app_config.dart": (
                "const String.fromEnvironment('LOOP_CLIENT_VERSION')",
                "hasValidLoopClientVersion",
                "value.length >= 5",
                "value.length <= 64",
                "loopClientVersionForCurrentBuild",
            ),
            "lib/integrations/backend/v2/loop_v2_contract.dart": (
                "abstract final class LoopV2Contract",
                "static String validateSuccess(",
                "static LoopBackendFailure mapDioFailure(",
                "'correlationId'",
            ),
            "lib/integrations/backend/v2/loop_v2_meta_repository.dart": (
                "LoopDioFactory.createCredentialFreePublic(origin: origin)",
                "static const clientPolicyPath = '/v2/meta/client-policy'",
                "static const capabilitiesPath = '/v2/meta/capabilities'",
            ),
            "lib/integrations/backend/v2/loop_v2_meta_providers.dart": (
                "Future.wait<Object>(<Future<Object>>[",
                "retry: (retryCount, error) => null",
            ),
            "lib/integrations/backend/v2/loop_v2_session_api.dart": (
                "static const accountPath = '/v2/account/me'",
                "static const bootstrapPath = '/v2/session/bootstrap'",
                "static const logoutPath = '/v2/session/logout'",
                "'x-loop-client-version'",
                "'idempotency-key'",
            ),
            "lib/integrations/backend/v2/loop_v2_session_coordinator.dart": (
                "final class LoopV2BootstrapRepository implements LoopBootstrapRepository",
                "account = await _api.getAccount(",
                "await _store.writeOwnerJournal(_ownerPartition, journal);",
                "final result = await _api.bootstrap(",
                "final class LoopV2LogoutCoordinator",
                "Future<void> prepareForLogout()",
                "_rejectUndispatchedRetiredOperation();",
                "return _waitForInFlight();",
                "if (accountBootstrapRequired && local != null)",
                "if (journal?.bootstrapRetirementRequested == true)",
                "journal!.copyWith(bootstrapRetirementRequested: true)",
                "await _retirePendingBootstrap(",
            ),
            "lib/integrations/backend/v2/loop_v2_session_store.dart": (
                "import 'package:flutter_secure_storage/flutter_secure_storage.dart';",
                "abstract interface class LoopV2SecureKeyValueStore",
                "resetOnError: false",
                "storageNamespace: 'loop_backend_v2_session'",
                "accountName: 'com.cywd.loop.backend.v2.session'",
                "accessibility: KeychainAccessibility.unlocked_this_device",
                "synchronizable: false",
                "'https://quant-dinger.cc/loop/v2/privy-owner/$principal'",
                "static const _deviceIdKey = 'loop.backend.v2.device_id';",
                "static const _ownerKeyPrefix = 'loop.backend.v2.owner.';",
                "await _storage.write(_deviceIdKey, generated);",
                "final validated = _parseJournal(journal.toJson());",
                "await _storage.write(key, jsonEncode(validated.toJson()));",
                "(hasBootstrap && (hasActive || hasLogout || revocationUnconfirmed))",
                "(bootstrapRetirementRequested && !hasBootstrap)",
                "(revocationUnconfirmed && !hasLogout)",
            ),
            "lib/integrations/backend/v2/loop_v2_session_providers.dart": (
                "config.loopClientVersionForCurrentBuild",
                "return FlutterSecureLoopV2SessionJournalStore();",
                "DioLoopV2SessionApi(dio)",
            ),
            "lib/integrations/backend/loop_bootstrap_providers.dart": (
                "ref.watch(loopV2SessionApiProvider)",
                "ref.watch(loopV2ClientMetadataProvider)",
                "final repository = LoopV2BootstrapRepository(",
                "ref.watch(loopV2SessionJournalStoreProvider)",
                "ref.onDispose(repository.retire)",
            ),
            "lib/integrations/backend/loop_stream_token_repository.dart": (
                "LoopStreamTokenProduct.chat => '/v1/chat/token'",
                "LoopStreamTokenProduct.video => '/v1/video/token'",
            ),
            "lib/app.dart": (
                "bootstrapRepository.prepareForLogout()",
                "await bootstrapQuiescence;",
                "ref.listenManual(",
                "loopV2MetaSnapshotProvider,",
                "fireImmediately: true,",
            ),
            "lib/app/session/loop_session_controller.dart": (
                "LoopSessionMode.signingOut",
                "Future<void>? _exitOperation;",
                "if (_exitOperation != null || state.mode == LoopSessionMode.signingOut)",
                "final gateway = ref.read(privyAuthGatewayProvider);",
                "state = const LoopSessionState.signingOut();",
                "backendResult = await revokeBackend(principalKey);",
            ),
            "lib/features/account/privy_login_screen.dart": (
                "if (session.mode == LoopSessionMode.signingOut)",
                "return const PrivySessionSignOutScreen();",
                "key: const ValueKey<String>('privy-signing-out-screen')",
            ),
            "android/app/src/main/AndroidManifest.xml": (
                'android:allowBackup="false"',
            ),
            "ios/Runner/Runner.entitlements": (
                "<key>keychain-access-groups</key>",
                "<array/>",
            ),
        },
    )

    profile_versions: dict[Path, str] = {}
    for relative in (Path("config/debug.json"), Path("config/release.example.json")):
        path = root / relative
        if not path.is_file():
            continue
        try:
            profile = json.loads(read_text(path))
        except (OSError, UnicodeError, json.JSONDecodeError):
            continue
        version = profile.get("LOOP_CLIENT_VERSION") if isinstance(profile, dict) else None
        if not isinstance(version, str) or V2_CLIENT_SEMVER_PATTERN.fullmatch(version) is None:
            errors.append(
                f"{relative} must provide a strict SemVer LOOP_CLIENT_VERSION"
            )
        else:
            profile_versions[relative] = version

    pubspec_path = root / "pubspec.yaml"
    pubspec_version: str | None = None
    if pubspec_path.is_file():
        match = re.search(
            r"^version:\s*([^\s#]+)\s*$",
            read_text(pubspec_path),
            re.MULTILINE,
        )
        if match is not None:
            pubspec_version = match.group(1)
    expected_profile_paths = {
        Path("config/debug.json"),
        Path("config/release.example.json"),
    }
    if (
        pubspec_version is None
        or set(profile_versions) != expected_profile_paths
        or any(version != pubspec_version for version in profile_versions.values())
    ):
        errors.append(
            "Debug and Release LOOP_CLIENT_VERSION values must match each "
            "other and pubspec.yaml `version` exactly"
        )

    android_manifest_path = (
        root / "android/app/src/main/AndroidManifest.xml"
    )
    if android_manifest_path.is_file():
        try:
            manifest = ElementTree.parse(android_manifest_path).getroot()
        except ElementTree.ParseError as error:
            errors.append(f"Android manifest is invalid XML: {error}")
        else:
            application = manifest.find("application")
            allow_backup = (
                application.get(
                    "{http://schemas.android.com/apk/res/android}allowBackup"
                )
                if application is not None
                else None
            )
            if allow_backup != "false":
                errors.append(
                    "Android backup must remain disabled for the V2 device journal"
                )

    entitlements_path = root / "ios/Runner/Runner.entitlements"
    if entitlements_path.is_file():
        try:
            with entitlements_path.open("rb") as stream:
                entitlements = plistlib.load(stream)
        except (OSError, plistlib.InvalidFileException) as error:
            errors.append(f"iOS entitlements are invalid: {error}")
        else:
            if entitlements.get("keychain-access-groups") != []:
                errors.append(
                    "V2 journal must not opt into a shared iOS keychain access group"
                )

    lib_root = root / "lib"
    if lib_root.is_dir():
        for path in lib_root.rglob("*.dart"):
            relative = path.relative_to(root)
            source = strip_dart_comments(read_text(path))
            executable = strip_dart_comments_and_strings(source)
            if (
                "package:flutter_secure_storage/" in source
                and relative not in SECURE_STORAGE_OWNERS
            ):
                errors.append(
                    "flutter_secure_storage imports must stay inside a "
                    f"reviewed secure store: {relative}"
                )
            if (
                re.search(r"\bFlutterSecureStorage\b", executable)
                and relative not in SECURE_STORAGE_OWNERS
            ):
                errors.append(
                    "FlutterSecureStorage may be instantiated or typed only by "
                    f"a reviewed secure store: {relative}"
                )
            if re.search(
                r"\b(?:LoopV2SecureKeyValueStore|FlutterLoopV2SecureKeyValueStore)\b",
                executable,
            ) and relative not in V2_SECURE_FACADE_CONSUMERS:
                errors.append(
                    "the raw V2 secure key-value facade must not escape its "
                    f"session store: {relative}"
                )
            if (
                re.search(r"\bFlutterSecureLoopV2SessionJournalStore\b", executable)
                and relative not in V2_SECURE_JOURNAL_RUNTIME_USERS
            ):
                errors.append(
                    "the concrete secure journal may only be composed by its "
                    f"V2 provider: {relative}"
                )

    session_path = root / "lib/integrations/backend/v2/loop_v2_session.dart"
    if session_path.is_file():
        source = strip_dart_comments(read_text(session_path))
        serialized_keys = tuple(
            match.group(2)
            for match in re.finditer(
                r"(['\"])([A-Za-z][A-Za-z0-9_]*)\1\s*:", source
            )
        )
        if serialized_keys != V2_SERIALIZED_JOURNAL_KEYS:
            errors.append(
                "V2 secure journal serialization must preserve its exact "
                "device/command/opaque-session allowlist"
            )
        for key in serialized_keys:
            normalized = re.sub(r"[^a-z0-9]", "", key.casefold())
            if normalized in V2_FORBIDDEN_PERSISTED_IDENTIFIERS:
                errors.append(
                    f"V2 secure journal contains forbidden sensitive persisted field: {key}"
                )
        bodies = re.findall(
            r"Map<String,\s*Object\?>\s+toJson\(\)\s*=>\s*"
            r"<String,\s*Object\?>\{(.*?)\};",
            source,
            re.DOTALL,
        )
        if len(bodies) != 3:
            errors.append("V2 secure journal must keep exactly three reviewed serializers")
        for body in bodies:
            executable = strip_dart_comments_and_strings(body)
            identifiers = {
                re.sub(r"[^a-z0-9]", "", value.casefold())
                for value in re.findall(r"\b[A-Za-z][A-Za-z0-9_]*\b", executable)
            }
            forbidden = sorted(identifiers & V2_FORBIDDEN_PERSISTED_IDENTIFIERS)
            if forbidden:
                errors.append(
                    "V2 secure journal serializer references forbidden sensitive "
                    f"values: {', '.join(forbidden)}"
                )

    store_path = root / V2_SECURE_STORAGE_OWNER
    if store_path.is_file():
        source = strip_dart_comments(read_text(store_path))
        imports = tuple(
            re.findall(r"^import\s+['\"]([^'\"]+)['\"]\s*;", source, re.MULTILINE)
        )
        expected_imports = (
            "dart:convert",
            "package:flutter_secure_storage/flutter_secure_storage.dart",
            "package:loop_mobile/integrations/backend/v2/loop_v2_session.dart",
            "package:uuid/uuid.dart",
        )
        if imports != expected_imports:
            errors.append(
                "V2 session store imports must stay limited to conversion, "
                "secure storage, its journal model, and UUID"
            )
        blocks = re.findall(
            r"_strictMap\([^,]+,\s*const <String>\{(.*?)\}\s*\)",
            source,
            re.DOTALL,
        )
        parsed_keysets = tuple(
            tuple(
                re.findall(r"['\"]([A-Za-z][A-Za-z0-9_]*)['\"]", block)
            )
            for block in blocks
        )
        if parsed_keysets != V2_PARSED_JOURNAL_KEYSETS:
            errors.append(
                "V2 secure journal parsing must reject every field outside the "
                "reviewed allowlist"
            )
        executable = strip_dart_comments_and_strings(source)
        if len(re.findall(r"\bFlutterSecureStorage\s*\(", executable)) != 1:
            errors.append(
                "V2 session store must own exactly one raw secure-storage constructor"
            )
        platform_options = (
            "resetOnError: false",
            "storageNamespace: 'loop_backend_v2_session'",
            "accountName: 'com.cywd.loop.backend.v2.session'",
            "accessibility: KeychainAccessibility.unlocked_this_device",
            "synchronizable: false",
        )
        if any(source.count(option) != 1 for option in platform_options):
            errors.append(
                "V2 secure storage platform isolation options have drifted"
            )
        storage_operations = set(
            re.findall(r"\b_storage\.([A-Za-z][A-Za-z0-9_]*)\s*\(", executable)
        )
        if storage_operations != {"read", "write", "delete"}:
            errors.append(
                "V2 secure storage may use only read, write, and delete operations"
            )
        if len(re.findall(r"\b_storage\.write\s*\(", executable)) != 3:
            errors.append(
                "V2 secure storage must keep exactly the reviewed wrapper, "
                "device-ID, and owner-journal write sites"
            )

    coordinator_path = (
        root / "lib/integrations/backend/v2/loop_v2_session_coordinator.dart"
    )
    if coordinator_path.is_file():
        source = strip_dart_comments(read_text(coordinator_path))
        bootstrap_source, separator, logout_source = source.partition(
            "final class LoopV2LogoutCoordinator"
        )
        account_call = bootstrap_source.find("account = await _api.getAccount(")
        bootstrap_call = bootstrap_source.find("final result = await _api.bootstrap(")
        bootstrap_write = bootstrap_source.find(
            "await _store.writeOwnerJournal(_ownerPartition, journal);"
        )
        logout_write = logout_source.find(
            "await _store.writeOwnerJournal(ownerPartition, journal);"
        )
        logout_call = logout_source.find("await _api.logout(")
        if not (
            separator
            and
            0 <= account_call < bootstrap_write < bootstrap_call
            and 0 <= logout_write < logout_call
        ):
            errors.append(
                "V2 session commands must remain account-first and "
                "write-before-dispatch"
            )
        if source.count("final command = pending ?? _newCommand(deviceId);") != 2:
            errors.append(
                "V2 bootstrap and logout must each reuse an exact pending command"
            )
        if bootstrap_source.count("_rejectUndispatchedRetiredOperation();") != 4:
            errors.append(
                "V2 bootstrap retirement must guard logout reconciliation, "
                "pending-bootstrap retirement, journal, and dispatch boundaries"
            )
        for identity_guard in (
            "local.deviceId != deviceId",
            "local.accountId != account.accountId",
            "local.streamUserId != account.streamUserId",
        ):
            if source.count(identity_guard) != 1:
                errors.append(
                    "V2 active-session reuse must preserve device/account/Stream "
                    f"identity matching: {identity_guard}"
                )

    meta_provider_path = (
        root / "lib/integrations/backend/v2/loop_v2_meta_providers.dart"
    )
    meta_startup_path = root / "lib/app.dart"
    # Decision 0053: capability availability may be projected for display copy
    # (an unavailable reason code), through one pure projection that owns no
    # routing, authentication or request. It is the only other reader.
    capability_projection_path = (
        root / "lib/core/policy/loop_capability_projection.dart"
    )
    if lib_root.is_dir():
        for path in lib_root.rglob("*.dart"):
            if path == meta_provider_path:
                continue
            executable = strip_dart_comments_and_strings(read_text(path))
            references = executable.count("loopV2MetaSnapshotProvider")
            if references == 0:
                continue
            if path == capability_projection_path:
                observed = len(
                    re.findall(
                        r"ref\.watch\(loopV2MetaSnapshotProvider\)\.value",
                        executable,
                    )
                )
                if references != observed or observed == 0:
                    errors.append(
                        "the D0 projection may read the snapshot only as an "
                        "observed value"
                    )
                for forbidden in ("GoRouter", "context.go", "context.push",
                                  "Dio", "authorize("):
                    if forbidden in executable:
                        errors.append(
                            "the capability projection must stay pure: "
                            f"{forbidden} is not allowed"
                        )
                continue
            if path != meta_startup_path:
                errors.append(
                    "D0 metadata may only have one inert production root observer; "
                    "it must remain unused by "
                    f"production feature gates: {path.relative_to(root)}"
                )
                continue
            inert_startup_observer = re.search(
                r"ref\.listenManual\s*\(\s*loopV2MetaSnapshotProvider\s*,"
                r"\s*\([^)]*\)\s*\{\s*\}\s*,\s*fireImmediately\s*:\s*true\s*,?\s*\)",
                executable,
                re.DOTALL,
            )
            # S1 item 9: the two module-0 gate pages (force-update,
            # region-blocked) may read the same snapshot, but only inside the
            # bounded `_systemSurface` builder and only through the pure
            # LoopClientPolicyProjection. Routing, auth and every other
            # feature remain forbidden consumers.
            system_start = executable.find("Widget _systemSurface(")
            system_end = executable.find("\n}\n", system_start)
            system_slice = (
                executable[system_start:system_end]
                if system_start >= 0 and system_end >= 0
                else ""
            )
            page_reads = len(
                re.findall(
                    r"ref\.watch\(loopV2MetaSnapshotProvider\)\.value\?\.clientPolicy",
                    system_slice,
                )
            )
            outside_slice = (
                executable[:system_start] + executable[system_end:]
                if system_start >= 0 and system_end >= 0
                else executable
            )
            if (
                inert_startup_observer is None
                or outside_slice.count("loopV2MetaSnapshotProvider") != 1
                or system_slice.count("loopV2MetaSnapshotProvider") != page_reads
                or page_reads > 1
            ):
                errors.append(
                    "D0 metadata startup must remain one non-authorizing, "
                    "fire-immediate root observation"
                )
            if page_reads == 1 and "LoopClientPolicyProjection" not in system_slice:
                errors.append(
                    "System pages may consume D0 client policy only through "
                    "LoopClientPolicyProjection"
                )
            redirect_start = executable.find("redirect: (context, state) {")
            if redirect_start >= 0 and "loopV2MetaSnapshotProvider" in executable[
                redirect_start : executable.find("routes: <RouteBase>[", redirect_start)
            ]:
                errors.append(
                    "D0 metadata must not gate the router redirect"
                )

    provider_path = root / "lib/integrations/backend/loop_bootstrap_providers.dart"
    if provider_path.is_file():
        executable = strip_dart_comments_and_strings(read_text(provider_path))
        if "DioLoopBootstrapRepository" in executable:
            errors.append(
                "production bootstrap provider must not fall back to the frozen V1 "
                "DioLoopBootstrapRepository"
            )
        if len(re.findall(r"\bLoopV2BootstrapRepository\s*\(", executable)) != 1:
            errors.append(
                "production bootstrap provider must compose exactly one V2 repository"
            )

    session_controller_path = root / "lib/app/session/loop_session_controller.dart"
    if session_controller_path.is_file():
        executable = strip_dart_comments_and_strings(
            read_text(session_controller_path)
        )
        if re.search(
            r"revokeBackend\s*\(\s*principalKey\s*\)\s*\.timeout\s*\(",
            executable,
        ):
            errors.append(
                "V2 backend logout must not use a non-cancelling controller-level "
                "timeout that can outlive the sign-out barrier"
            )

    stream_path = root / "lib/integrations/backend/loop_stream_token_repository.dart"
    if stream_path.is_file():
        source = strip_dart_comments(read_text(stream_path))
        if "/v2/chat/token" in source or "/v2/video/token" in source:
            errors.append(
                "Stream Chat and Video token issuance must remain on the frozen V1 routes"
            )

    errors.extend(check_behavior_test_evidence(root, V2_SESSION_TEST_MARKERS))
    return errors


NETWORK_DIO_POLICY_TEST_MARKERS = {
    Path("test/loop_dio_factory_test.dart"): (
        "common clients use bounded defaults without credential headers",
        "credential-free public client accepts only its exact HTTPS origin",
        "credential-free public client rejects credential headers before dispatch",
        "backend client accepts request-local bearer only on its exact origin",
        "backend client rejects persistent authorization defaults",
        "every client rejects per-request redirect enablement",
        "factory rejects unsafe or non-origin configuration",
    ),
}
NETWORK_DIO_POLICY_EXECUTABLE_TEST_EVIDENCE = {
    Path("test/loop_dio_factory_test.dart"): {
        "common clients use bounded defaults without credential headers": (
            r"\bLoopDioFactory\.createCredentialFreePublic\s*\(",
            r"\bLoopDioFactory\.createLoopBackend\s*\(",
            r"\bexpect\s*\(\s*client\.options\.connectTimeout\s*,",
            r"\bexpect\s*\(\s*client\.options\.followRedirects\s*,\s*isFalse",
            r"\bexpect\s*\(\s*client\.options\.maxRedirects\s*,\s*0",
            r"\bclient\.options\.headers\.keys\.map\s*\(",
            r"\bisNot\s*\(\s*contains\s*\(",
        ),
        "credential-free public client accepts only its exact HTTPS origin": (
            r"\bLoopDioFactory\.createCredentialFreePublic\s*\(",
            r"\bawait\s+client\.post<Object\?>\s*\(",
            r"\bclient\.get<Object\?>\s*\(",
            r"\bthrowsA\s*\(\s*_boundaryViolation\s*\(\s*\)\s*\)",
            r"\bexpect\s*\(\s*dispatched\s*,\s*hasLength\s*\(\s*1\s*\)",
        ),
        "credential-free public client rejects credential headers before dispatch": (
            r"\bfor\s*\(\s*final\s+headers\s+in\s+<Map<String,\s*String>>\s*\[",
            r"\bclient\.get<Object\?>\s*\(.*?Options\s*\(\s*headers\s*:\s*headers\s*\)",
            r"\bthrowsA\s*\(\s*_boundaryViolation\s*\(\s*\)\s*\)",
            r"\bexpect\s*\(\s*dispatched\s*,\s*isEmpty",
        ),
        "backend client accepts request-local bearer only on its exact origin": (
            r"\bLoopDioFactory\.createLoopBackend\s*\(",
            r"\bclient\.post<Object\?>\s*\(",
            r"\bOptions\s*\(\s*headers\s*:\s*const\s+<String,\s*String>",
            r"\bthrowsA\s*\(\s*_boundaryViolation\s*\(\s*\)\s*\)",
            r"\bexpect\s*\(\s*dispatched\s*,\s*hasLength\s*\(\s*1\s*\)",
        ),
        "backend client rejects persistent authorization defaults": (
            r"\bLoopDioFactory\.createLoopBackend\s*\(",
            r"\bclient\.options\.headers\s*\[",
            r"\bclient\.post<Object\?>\s*\(",
            r"\bthrowsA\s*\(\s*_boundaryViolation\s*\(\s*\)\s*\)",
            r"\bexpect\s*\(\s*dispatched\s*,\s*isEmpty",
        ),
        "every client rejects per-request redirect enablement": (
            r"\bOptions\s*\(\s*followRedirects\s*:\s*true\s*\)",
            r"\bthrowsA\s*\(\s*_boundaryViolation\s*\(\s*\)\s*\)",
            r"\bexpect\s*\(\s*dispatched\s*,\s*isEmpty",
        ),
        "factory rejects unsafe or non-origin configuration": (
            r"\bfinal\s+invalidPublicOrigins\s*=\s*<Uri>\s*\[",
            r"\bfor\s*\(\s*final\s+origin\s+in\s+invalidPublicOrigins\s*\)",
            r"\bLoopDioFactory\.createCredentialFreePublic\s*\(\s*origin\s*:\s*origin\s*\)",
            r"\bthrowsArgumentError\b",
            r"\bfinal\s+loopback\s*=\s*LoopDioFactory\.createLoopBackend\s*\(",
            r"\bexpect\s*\(\s*loopback\.options\.baseUrl\s*,",
        ),
    },
}


def check_network_dio_policy_contract(root: Path) -> list[str]:
    """Keep production Dio construction separated by exact trust boundary."""

    errors = require_fragments(
        root,
        {
            "lib/core/network/loop_dio_factory.dart": (
                "abstract final class LoopDioFactory",
                "static Dio createCredentialFreePublic",
                "static Dio createLoopBackend",
                "connectTimeout: connectTimeout",
                "sendTimeout: sendTimeout",
                "receiveTimeout: receiveTimeout",
                "followRedirects: false",
                "maxRedirects: 0",
                "'proxy-authorization'",
                "'cookie'",
                "'x-api-key'",
            ),
            "lib/integrations/backend/loop_backend_providers.dart": (
                "LoopDioFactory.createLoopBackend(origin: endpoint.uri)",
            ),
            "lib/integrations/hyperliquid/hyperliquid_http_providers.dart": (
                "final hyperliquidPublicDioProvider = Provider<Dio>",
                "LoopDioFactory.createCredentialFreePublic(",
                "api.hyperliquid-testnet.xyz",
            ),
            "lib/integrations/hyperliquid/hyperliquid_spot_market_providers.dart": (
                "ref.watch(hyperliquidPublicDioProvider)",
            ),
            "lib/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart": (
                "ref.watch(hyperliquidPublicDioProvider)",
            ),
            "lib/integrations/hyperliquid/hyperliquid_market_providers.dart": (
                "LoopDioFactory.createCredentialFreePublic(",
            ),
            "test/loop_dio_factory_test.dart": tuple(
                marker
                for markers in NETWORK_DIO_POLICY_TEST_MARKERS.values()
                for marker in markers
            )
            + (
                "https://other.example.com/info",
                "http://public.example.com:443/info",
                "https://public.example.com:444/info",
                "Authorization': 'Bearer private-token",
                "Cookie': 'session=private-cookie",
                "X-Api-Key': 'private-api-key",
                "authorization': 'Bearer current-access-token",
                "Bearer persisted-token",
                "https://other.example.com/v1/bootstrap",
                "http://api.example.com:443/v1/bootstrap",
                "https://api.example.com:444/v1/bootstrap",
                "idempotency-key",
                "http://public.example.com/",
                "https://user@public.example.com/",
                "http://api.example.com/",
                "http://127.0.0.1:3000/",
            ),
            "AGENTS.md": (
                "Construct production Dio clients only through `LoopDioFactory`",
            ),
            "README.md": (
                "Dio 构造已收敛到双信任边界",
            ),
            "docs/product/implementation-constraints.md": (
                "Construct production Dio instances only through `LoopDioFactory`.",
            ),
            "docs/product-decisions.md": (
                "Production Dio construction uses two exact-origin profiles rather than one universal client.",
            ),
            "docs/decisions/0041-centralize-dio-trust-boundaries.md": (
                "## Status",
                "## Context",
                "## Decision",
                "## Consequences",
                "## Evidence",
            ),
            "docs/harness/adoption-report.md": (
                "## Dio Trust-Boundary Foundation",
            ),
            "docs/phase-1/frontend-integration-report.md": (
                "## Dio Trust-Boundary Foundation",
            ),
        },
    )

    factory_path = root / "lib/core/network/loop_dio_factory.dart"
    factory_source = ""
    if factory_path.is_file():
        factory_source = strip_dart_comments_and_strings(read_text(factory_path))
        if len(re.findall(r"\bDio\s*(?:\.new)?\s*\(", factory_source)) != 1:
            errors.append("LoopDioFactory must own exactly one production Dio constructor")
        if len(re.findall(r"\bBaseOptions\s*(?:\.new)?\s*\(", factory_source)) != 1:
            errors.append(
                "LoopDioFactory must own exactly one production BaseOptions constructor"
            )
        factory_imports = re.findall(
            r"^import\s+['\"]([^'\"]+)['\"]\s*;",
            strip_dart_comments(read_text(factory_path)),
            flags=re.MULTILINE,
        )
        if factory_imports != ["package:dio/dio.dart"]:
            errors.append(
                "LoopDioFactory imports only Dio; token, UUID, retry, and logging stay with their owners"
            )

    lib_root = root / "lib"
    if lib_root.is_dir():
        factory_consumers = {
            Path("lib/core/network/loop_dio_factory.dart"),
            Path("lib/integrations/backend/loop_backend_providers.dart"),
            Path(
                "lib/integrations/backend/v2/loop_v2_meta_repository.dart"
            ),
            Path(
                "lib/integrations/hyperliquid/hyperliquid_http_providers.dart"
            ),
            Path(
                "lib/integrations/hyperliquid/hyperliquid_market_providers.dart"
            ),
        }
        for path in lib_root.rglob("*.dart"):
            relative = path.relative_to(root)
            source = strip_dart_comments_and_strings(read_text(path))
            if relative != Path("lib/core/network/loop_dio_factory.dart"):
                if re.search(r"\bDio\s*(?:\.new)?\s*\(", source):
                    errors.append(
                        f"Production Dio construction must stay inside LoopDioFactory: {relative}"
                    )
                if re.search(r"\bBaseOptions\s*(?:\.new)?\s*\(", source):
                    errors.append(
                        f"Production BaseOptions construction must stay inside LoopDioFactory: {relative}"
                    )
                if re.search(
                    r"\binterceptors\s*\.\s*(?:add|addAll|insert)\s*\(",
                    source,
                ):
                    errors.append(
                        f"Production Dio interceptors must stay inside LoopDioFactory: {relative}"
                    )
            if "LoopDioFactory" in source and relative not in factory_consumers:
                errors.append(
                    f"Production network composition must stay in reviewed providers: {relative}"
                )
            guarded_source = strip_dart_comments(read_text(path))
            for forbidden in (
                "LogInterceptor",
                "PrettyDioLogger",
                "RetryInterceptor",
                "DioRetryInterceptor",
                "dio_smart_retry",
                "pretty_dio_logger",
            ):
                if forbidden in guarded_source:
                    errors.append(
                        f"Production networking must not add automatic retry or raw HTTP logging: {relative} contains {forbidden}"
                    )

        provider_profiles = {
            Path("lib/integrations/backend/loop_backend_providers.dart"): (
                "createLoopBackend",
                "createCredentialFreePublic",
            ),
            Path(
                "lib/integrations/backend/v2/loop_v2_meta_repository.dart"
            ): ("createCredentialFreePublic", "createLoopBackend"),
            Path(
                "lib/integrations/hyperliquid/hyperliquid_http_providers.dart"
            ): ("createCredentialFreePublic", "createLoopBackend"),
            Path(
                "lib/integrations/hyperliquid/hyperliquid_market_providers.dart"
            ): ("createCredentialFreePublic", "createLoopBackend"),
        }
        for relative, (required_profile, forbidden_profile) in provider_profiles.items():
            path = root / relative
            if not path.is_file():
                continue
            source = strip_dart_comments_and_strings(read_text(path))
            if source.count(f"LoopDioFactory.{required_profile}(") != 1 or (
                f"LoopDioFactory.{forbidden_profile}(" in source
            ):
                errors.append(
                    f"{relative} must use only the reviewed {required_profile} Dio profile"
                )

        hyperliquid_root = root / "lib/integrations/hyperliquid"
        if hyperliquid_root.is_dir():
            for path in hyperliquid_root.rglob("*.dart"):
                source = strip_dart_comments(read_text(path))
                if "'/exchange'" in source or '"/exchange"' in source:
                    errors.append(
                        "Direct Hyperliquid mobile adapters must remain public /info-only; "
                        f"found /exchange in {path.relative_to(root)}"
                    )

    errors.extend(check_behavior_test_evidence(root, NETWORK_DIO_POLICY_TEST_MARKERS))
    errors.extend(
        check_named_executable_test_evidence(
            root, NETWORK_DIO_POLICY_EXECUTABLE_TEST_EVIDENCE
        )
    )
    return errors


# Step 5 deleted `lib/features/home/home_screens.dart` (decision 0057) with the
# three screens it carried: Home, the standalone notification centre and the
# Home security activity page. All three are product red lines, so the two
# guards that used to police their copy — Home discovery/security and the B1/B2
# portfolio truth — are retired with their subject. What replaces them is
# stronger: `check_spot_only_product_contract` fails if the file returns at all,
# and `test/route_manifest_test.dart` proves the source is gone and that
# `/home/net-worth`, `/home/security` and `/notifications` stay in
# `retiredPaths`.


def check_spot_candle_contract(root: Path) -> list[str]:
    """Keep the mounted candle read bounded, exact, and discovery-only."""

    errors = require_fragments(
        root,
        {
            "docs/product/implementation-constraints.md": (
                "`1H/1h`, `4H/4h`, `1D/1d`, `1W/1w`, and `1M/1M`",
                "invalid or absent route index causes zero candle requests",
                "retains at most the latest 120 distinct rows",
                "`T - t` must equal that fixed duration minus one millisecond",
            ),
            "docs/decisions/0019-use-public-testnet-spot-candles.md": (
                "type: candleSnapshot",
                "`1M -> 1M`",
                "overlaps the requested window",
                "final candle can still be forming",
                "For every accepted row, `T - t` equals",
            ),
            # Step 5 retired the `spotIndex` route contract from decision 0036;
            # decision 0057 replaced it with the canonical CAIP `assetId`.
            "docs/decisions/0036-mount-public-spot-full-chart.md": (
                "causes zero candle requests and never substitutes ETH",
                "display symbols are not identity",
                "Drawing, calculated",
                "Pending chart work selects one I8",
                "C3 stays outside the current primary Shell",
                "a root deep link with no history returns explicitly to `/market`",
            ),
            "docs/decisions/0057-adopt-v2-chain-market-and-wallet-read.md": (
                "`MarketAssetRoute` and `WalletRoute` replace `SpotMarketRoute`",
                "The paths in the 93-route manifest are unchanged.",
                "`SpotCandleChart` becomes `LoopCandleChart(List<LoopCandle>)`",
            ),
            "lib/core/navigation/market_asset_route.dart": (
                "static const String chartPath = '/market/chart';",
                "static String chart(String assetId)",
                "static String? parse(Uri uri, String path)",
                "uri.queryParametersAll.length != 1",
                "uri.hasScheme",
                "uri.hasAuthority",
                "uri.fragment.isNotEmpty",
                "values.length != 1",
                r"r'^eip155:[1-9][0-9]{0,9}:(native|0x[0-9a-f]{40})$'",
                "if (!isCanonical(raw)) return null;",
                "uri.toString() != location(path, raw)",
            ),
            "lib/app.dart": (
                "path: MarketAssetRoute.chartPath",
                "MarketAssetRoute.chartPath,\n          ),",
            ),
            "lib/core/navigation/surface_catalog.dart": (
                "id: 'C3'",
                "Exact-index public Testnet Spot candles in portrait or landscape.",
            ),
            "lib/integrations/hyperliquid/hyperliquid_spot_candle.dart": (
                "enum HyperliquidSpotCandleInterval",
                "final class HyperliquidSpotCandleRequest",
                "final class HyperliquidSpotCandle",
                "final class HyperliquidSpotCandleSnapshot",
                "final HyperliquidSpotDecimal open;",
                "final HyperliquidSpotDecimal close;",
                "final HyperliquidSpotDecimal high;",
                "final HyperliquidSpotDecimal low;",
                "final HyperliquidSpotDecimal volume;",
                "final Duration candleDuration;",
            ),
            "lib/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart": (
                "api.hyperliquid-testnet.xyz",
                "'/info'",
                "'type': 'candleSnapshot'",
                "'coin': providerCoin",
                "'interval': interval.wireValue",
                "'startTime': requestedFromMilliseconds",
                "'endTime': requestedUntilMilliseconds",
                "static const maximumCandles = 120;",
                "final receivedAt = _now();",
                "final candlesByOpenTime = <int, HyperliquidSpotCandle>{};",
                "candlesByOpenTime[candle.openTime.millisecondsSinceEpoch] = candle;",
                "..sort((left, right) => left.openTime.compareTo(right.openTime));",
                "ordered.sublist(ordered.length - maximumCandles)",
                "closeTimeMilliseconds < requestedFrom.millisecondsSinceEpoch",
                "openTimeMilliseconds > requestedUntil.millisecondsSinceEpoch",
                "sourceCoin != providerCoin || sourceInterval != interval.wireValue",
                "openTimeMilliseconds + interval.candleDuration.inMilliseconds - 1",
                "closeTimeMilliseconds != expectedCloseTimeMilliseconds",
                "if (wireValue is! String) throw _invalidPayload();",
                "final value = Decimal.tryParse(wireValue);",
            ),
            "lib/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart": (
                "hyperliquidSpotMarketNetworkAllowedProvider",
                "FutureProvider.autoDispose",
                "HyperliquidSpotCandleRequest",
                "retry: (retryCount, error) => null",
            ),
            # Step 5 retired `market_screens.dart`, `spot_candle_section.dart`
            # and `spot_candle_chart.dart`. C3 is now `FullChartScreen` in
            # `market_secondary_screens.dart`, fed by `TokenCandleSection` and
            # drawn by the generalised `LoopCandleChart`.
            "lib/features/market/market_secondary_screens.dart": (
                "class FullChartScreen extends ConsumerStatefulWidget",
                "MarketAssetRoute.isCanonical(assetId)",
                "TokenCandleSection(",
                # S77a: EMA / MACD / RSI are not rendered at all, so there is
                # no disabled chip and no unavailable card to lock. What the
                # page must still state is which two indicators it does
                # compute and where they come from.
                "chart-full-interval-notice",
                "没有其他指标",
            ),
            "lib/features/market/token_screen.dart": (
                "class TokenCandleSection extends ConsumerStatefulWidget",
                "marketCandlesControllerProvider(request)",
                "MarketCandlesUnavailable(reasonCode: final reasonCode)",
                "LoopSkeletonType.chart",
            ),
            "lib/features/market/loop_candle_chart.dart": (
                "The model stays `Decimal`",
                "dimensionless visual ratio",
                "(value - lowest) / priceSpan",
                "final firstOpenTime = candles.first.openTime;",
                "final timeSpan = candles.last.openTime.difference(firstOpenTime);",
                "final elapsed = candle.openTime.difference(firstOpenTime).inMicroseconds;",
                "elapsed.clamp(0, timeSpan.inMicroseconds) / timeSpan.inMicroseconds",
                "final centerX = xFor(candle);",
                "final minimumBodyHeight = math.min(2.25, plot.height);",
                ".clamp(plot.top, plot.bottom - minimumBodyHeight)",
                "visibleTop + minimumBodyHeight",
                "if (candle.isOpen)",
            ),
            "test/hyperliquid_spot_candle_repository_test.dart": (
                "posts one bounded public Testnet request and preserves exact OHLCV",
                "uses the reviewed bounded window for every mounted period",
                "captures receipt time before parsing response rows",
                "accepts an overlapping first candle and gaps without fabrication",
                "rejects short and long durations for every mounted interval",
                "rejects numeric values and inconsistent candle identity",
                "sorts, deduplicates, and retains only the latest bounded rows",
                "rejects identifiers before issuing a provider request",
            ),
            "test/hyperliquid_spot_candle_providers_test.dart": (
                "restricted sessions never request public candle history",
                "equal provider coin and interval readers share one in-flight request",
                "different periods remain isolated family requests",
            ),
            "test/s5_market_pages_test.dart": (
                "the intervals map one to one onto the contract",
                "no control is offered for an indicator nobody draws",
                "changing the interval requests that exact interval",
                "an unavailable candle block states its reason",
                "go_router hands the page back the exact CAIP identity",
            ),
            "test/loop_candle_chart_test.dart": (
                "an empty series paints nothing and does not throw",
                "a flat series does not divide by a zero price span",
                "an open bucket repaints when its close moves",
                "a value survives a precision a double would lose",
            ),
            # Step 5 retired the two `SpotMarketRoute` C3 navigation tests and
            # the live-Spot half of the Preview experience test with the
            # screens they drove (decision 0057). `chart-full` evidence now
            # lives in the two S5 files above.
        },
    )

    interval_path = root / "lib/integrations/hyperliquid/hyperliquid_spot_candle.dart"
    if interval_path.is_file():
        source = read_text(interval_path)
        wire_values = re.findall(r"wireValue:\s*'([^']+)'", source)
        display_labels = re.findall(r"displayLabel:\s*'([^']+)'", source)
        candle_durations = re.findall(
            r"candleDuration:\s*Duration\(([^)]+)\)", source
        )
        if wire_values != ["1h", "4h", "1d", "1w", "1M"]:
            errors.append(
                "Spot candle wire periods must remain exactly 1h / 4h / 1d / 1w / 1M"
            )
        if display_labels != ["1H", "4H", "1D", "1W", "1M"]:
            errors.append(
                "Spot candle display periods must remain exactly 1H / 4H / 1D / 1W / 1M"
            )
        if candle_durations != [
            "hours: 1",
            "hours: 4",
            "days: 1",
            "days: 7",
            "days: 30",
        ]:
            errors.append(
                "Spot candle fixed durations must remain exactly 1h / 4h / 1d / 7d / 30d"
            )
        for fragment in (
            "lookback: Duration(hours: 120)",
            "lookback: Duration(hours: 480)",
            "lookback: Duration(days: 120)",
            "lookback: Duration(days: 840)",
            "lookback: Duration(days: 3600)",
        ):
            if fragment not in source:
                errors.append(
                    "Spot candle periods must preserve approximately 120 rows; "
                    f"missing `{fragment}`"
                )

    repository_path = (
        root
        / "lib/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart"
    )
    if repository_path.is_file():
        source = read_text(repository_path)
        if source.count("_dio.post<Object?>(") != 1:
            errors.append(
                "Spot candle repository must own exactly one public POST transport"
            )
        for forbidden in (
            "api.hyperliquid.xyz",
            "'type': 'spotMetaAndAssetCtxs'",
            "openTimeMilliseconds < requestedFrom.millisecondsSinceEpoch",
            "if (payload.isEmpty",
            "if (candlesByOpenTime.isEmpty",
            "if (ordered.isEmpty",
        ):
            if forbidden in source:
                errors.append(
                    "Spot candle repository must preserve Testnet-only, overlapping, "
                    f"empty-history semantics; found `{forbidden}`"
                )

    provider_path = (
        root
        / "lib/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart"
    )
    if provider_path.is_file():
        source = read_text(provider_path)
        for forbidden in ("Timer.periodic", "ref.invalidateSelf("):
            if forbidden in source:
                errors.append(
                    "Spot candles must not poll or automatically refresh; "
                    f"found `{forbidden}`"
                )

    preview_path = root / "lib/main_preview.dart"
    if preview_path.is_file() and (
        "hyperliquidSpotCandleRepositoryProvider.override" in read_text(preview_path)
    ):
        errors.append(
            "lib/main_preview.dart must not replace public Spot candles with a Preview repository"
        )

    # Step 5 retired `test/market_screen_test.dart` with the Hyperliquid Spot
    # detail screen it drove. `test/s5_market_pages_test.dart` now proves that
    # a malformed asset identity issues no candle request.

    app_path = root / "lib/app.dart"
    if app_path.is_file():
        source = read_text(app_path)
        route_start = source.find("        path: MarketAssetRoute.chartPath,")
        route_end = source.find("      GoRoute(\n        path: '/market/new',", route_start)
        if route_start < 0 or route_end < 0:
            errors.append("C3 must retain its exact reviewed application route")
        else:
            route_source = source[route_start:route_end]
            for forbidden in ("state.extra", "'ETH'", '"ETH"', "spotIndex"):
                if forbidden in route_source:
                    errors.append(
                        "C3 application route must not recover identity from "
                        f"navigation extras or a default asset: `{forbidden}`"
                    )
            shell_start = source.find("      ShellRoute(")
            shell_end = source.find("      ..._accountRoutes,", shell_start)
            if shell_start < route_start < shell_end:
                errors.append(
                    "C3 must remain a root full-screen route outside the five-destination Shell"
                )

    market_surface_path = root / "lib/features/market/market_secondary_screens.dart"
    if market_surface_path.is_file():
        source = read_text(market_surface_path)
        chart_start = source.find("class FullChartScreen")
        chart_end = source.find("class HolderDistributionScreen", chart_start)
        if chart_start < 0 or chart_end < 0:
            errors.append("C3 must retain one bounded full-chart source slice")
        else:
            chart_source = strip_dart_comments(source[chart_start:chart_end])
            for forbidden in (
                "MarketPreviewData",
                "MarketSnapshotState",
                "snapshotState",
                "state.extra",
                "SigningReviewSurface",
                "FilledButton",
            ):
                if forbidden in chart_source:
                    errors.append(
                        "C3 must remain real, read-only and free of Preview or "
                        f"fake-indicator fallback: `{forbidden}`"
                    )
            # Step 5 replaced C3's own Close handler with the application
            # router's `_popOrHome`.
            #
            # S77a changed how the missing tools are stated. A greyed EMA /
            # MACD / RSI chip with a reason behind it was still a control
            # offered for something nobody is building, and on the device it
            # read as three buttons that had broken. They are gone: the page
            # renders only what it draws, and its own notice names the two
            # indicators it computes and says there are no others. The lock
            # therefore checks the absence of the three names and the presence
            # of the sentence.
            for required in (
                "onBack: widget.onBack",
                "chart-full-interval-notice",
                "没有其他指标",
            ):
                if required not in chart_source:
                    errors.append(
                        "C3 must return through the application router and state "
                        f"what it can and cannot draw; missing `{required}`"
                    )
            for forbidden in ("'EMA'", "'MACD'", "'RSI'"):
                if forbidden in chart_source:
                    errors.append(
                        "C3 must not render a control for an indicator nothing "
                        f"draws; found `{forbidden}`"
                    )

    for relative in ("lib/features/market/loop_candle_chart.dart",):
        path = root / relative
        if not path.is_file():
            continue
        source = read_text(path)
        for forbidden in ("context.push(", "SigningReviewSurface", "FilledButton"):
            if forbidden in source:
                errors.append(
                    f"{relative} must remain read-only without execution navigation `{forbidden}`"
                )
        # `style-v2.css` publishes ink / lime / chalk and its `.kline-body`
        # rules are one hue: rising is solid Lime, falling is a hollow Chalk
        # outline. A candle painted in a second hue is a colour the design
        # system does not have (audit 2026-09-21 §D+ item 12).
        for forbidden in (
            "LoopColors.danger",
            "LoopColors.mint",
            "LoopColors.vapor",
            "Colors.red",
            "Colors.green",
        ):
            if forbidden in source:
                errors.append(
                    f"{relative} must paint one hue: rising Lime, falling a "
                    f"hollow Chalk outline; found `{forbidden}`"
                )
        for required in (
            "static const Color _upBody = LoopColors.lime;",
            "static const Color _downFill = Color(0x24F3F5EF);",
            "static const Color _downStroke = Color(0xC7F3F5EF);",
        ):
            if required not in source:
                errors.append(
                    f"{relative} must paint one hue: rising Lime, falling a "
                    f"hollow Chalk outline; missing `{required}`"
                )

    return errors


def check_wallet_identity_readiness_contract(root: Path) -> list[str]:
    """Keep real Privy wallet identity separate from funding and signing."""

    errors = require_fragments(
        root,
        {
            "docs/decisions/0020-mount-privy-wallet-readiness.md": (
                "wallet identity is not deposit or signing authority",
                "complete Embedded Ethereum wallet address",
                "No QR code",
            ),
            # Decision 0063 deleted `wallet_readiness.dart` and its unit test.
            # The model projected "does this session need a wallet" from the
            # Privy session alone, which cannot tell an empty `GET /v2/wallets`
            # from an unread one; the pages read the server's directory, and
            # `LoopWalletProvisioningController` owns the verified-session gate
            # the model used to state. Its last consumer went with the Preview
            # DApp browser in S8 (decision 0060), so nothing was rewired.
            # Step 5 retired `wallet_overview_screens.dart` and the Preview
            # `WalletManagerScreen` copy (decision 0057). Wallet identity is now
            # addressed only by the opaque `walletId`, and Receive renders a
            # real EIP-681 URI, so the Preview clipboard and no-QR locks are
            # retired with the screens that carried them.
            "lib/features/wallet/wallet_read_screens.dart": (
                "class WalletManagerScreen",
                "walletDirectoryControllerProvider",
                "地址不是账号标识",
                "wallet.truncatedAddress",
            ),
            # Decision 0063: the verified-session gate is now stated by
            # `LoopWalletProvisioningController`, and the wallet pages state
            # the empty answer from the server's own directory.
            "lib/app/session/wallet_provisioning_controller.dart": (
                "!session.canUseProviderBackedFeatures",
                "if (account.wallet != null) return;",
                "LoopWalletProvisioningStage.failed",
            ),
            "test/loop_session_controller_test.dart": (
                "a development preview session never asks Privy for a wallet",
                "an unverified session never asks Privy for a wallet",
                "a failed creation is a wallet fact, never a login one",
            ),
            # Step 6 replaced the Preview transfer draft with the typed
            # `SendDraft`, whose route guard is locked by the money-action
            # contract below (decision 0059).
            "lib/app.dart": (
                "state.extra is SendDraft ? null : '/wallet/send'",
                "draft is SendDraft && draft.isComplete",
            ),
            # Step 5 replaced the Privy-readiness Wallet, Receive and Manage
            # screens with the V2 wallet-read pages, so their widget evidence
            # moved to test/s5_wallet_pages_test.dart; only the
            # `WalletReadiness` model group survives in the old file.
            "test/s5_wallet_pages_test.dart": (
                "addresses are truncated and grouped by kind",
                "switching confirms first and sends the expected active id",
                "renders the QR, the address and the EIP-681 uri",
                "an archived wallet cannot be activated",
            ),
            # Step 6 replaced the local-draft boundary test with the real
            # signing exit: a preview intent is now refused by the wallet
            # gateway itself (decision 0059).
            "test/privy_adapter_test.dart": (
                "a locally built preview intent can never reach a wallet",
                "expect(signer.sendCalls, 0);",
            ),
            "test/app_navigation_test.dart": (
                "incomplete Send deep links return to asset selection",
            ),
        },
    )

    wallet_root = root / "lib/features/wallet"
    if wallet_root.is_dir():
        for path in wallet_root.rglob("*.dart"):
            if "package:privy_flutter" in read_text(path):
                errors.append(
                    f"{path.relative_to(root)} must use the session boundary, "
                    "not import the Privy SDK"
                )

    # Step 5 retired the Preview wallet-identity clipboard slice and the
    # fixture wallet list. The mounted Wallet pages read the V2 wallet module,
    # so the remaining rule is that a wallet is addressed only by its opaque
    # id and never by a client-chosen address literal.
    read_path = root / "lib/features/wallet/wallet_read_screens.dart"
    if read_path.is_file():
        source = strip_dart_comments(read_text(read_path))
        # The Preview clipboard flow — and its ban on SelectableText — retired
        # with `wallet_overview_screens.dart`: the receive address is now a
        # server fact bound to the opaque walletId, not a fabricated identity.
        for marker in ("Daily wallet", "Trading wallet", "0x71E4", "0x88C2"):
            if marker in source:
                errors.append(
                    "Mounted Wallet must not mix fixture identities with the "
                    f"server's wallet directory: {marker}"
                )
        if re.search(r"(?i)['\"]0x[0-9a-f]{40}['\"]", source):
            errors.append(
                "Mounted Wallet identity must come from the server's wallet "
                "directory, never an address literal"
            )
        if "walletSigningGatewayProvider" in source:
            errors.append(
                "Wallet existence must not enable the signing gateway"
            )

    return errors


def check_wallet_preview_route_contract(root: Path) -> list[str]:
    """Reject fabricated Wallet route context and capability claims."""

    errors = require_fragments(
        root,
        {
            "docs/decisions/0021-close-wallet-preview-orphan-routes.md": (
                "typed, immutable `WalletPreviewAsset`",
                "A naked or restored route returns to Wallet",
                "Remove the DApp fixture wallet",
            ),
            # Step 5 retired the Preview wallet-asset route (decision 0057):
            # `/wallet/asset` now carries the canonical CAIP `assetId` and reads
            # the V2 wallet module, so no typed Preview extra addresses it.
            # Step 6 retired `/preview/signing-review` and the Preview asset
            # collection with it: the signing exit now accepts only a
            # backend-canonical intent.
            "lib/app.dart": (
                "path: MarketAssetRoute.walletAssetPath",
                "MarketAssetRoute.walletAssetPath,\n          ),",
            ),
            "lib/features/wallet/wallet_read_screens.dart": (
                "class WalletAssetScreen",
                "MarketAssetRoute.isCanonical(assetId)",
            ),
            # S8 (decision 0060) replaced the Preview DApp browser with the
            # offline `dapp` review: no wallet identity is rendered at all, so
            # none can be invented.
            "lib/features/wallet/deferred_screens.dart": (
                "class DappReviewScreen",
                "LoopUrlReview.review(value)",
                "dapp-execution-unavailable",
                "dapp-reputation-unavailable",
            ),
            "lib/core/security/loop_url_review.dart": (
                "static const followsRedirects = false;",
                "LoopUrlFinding.notHttps",
                "LoopUrlFinding.confusableCharacters",
            ),
            "test/s8_deferred_pages_test.dart": (
                "a bare host is normalised and shown as read-only",
                "a non-HTTPS address is blocked with its reason",
                "an IDN homograph is blocked and its Latin reading named",
                "the page states that it never opens the address",
            ),
            "test/loop_url_review_test.dart": (
                "the review never resolves a redirect: the host is the typed host",
            ),
            "test/route_manifest_test.dart": (
                "Wallet manifest maps every slug to its mounted route",
            ),
        },
    )

    app_path = root / "lib/app.dart"
    if app_path.is_file():
        source = read_text(app_path)
        for marker in ("SigningIntent _previewIntent()", "_previewIntent()"):
            if marker in source:
                errors.append(
                    "Signing Review must never fabricate a fallback intent: "
                    f"{marker}"
                )

    read_path = root / "lib/features/wallet/wallet_read_screens.dart"
    if read_path.is_file():
        source = strip_dart_comments(read_text(read_path))
        detail_start = source.find("class WalletAssetScreen")
        detail_end = source.find("class ReceiveScreen", detail_start)
        detail_source = source[detail_start:detail_end]
        for marker in ("_AssetActivity", "Average cost", "Unrealized PnL"):
            if marker in detail_source:
                errors.append(
                    "Asset detail must not restore unbound portfolio fixtures: "
                    f"{marker}"
                )

    deferred_path = root / "lib/features/wallet/deferred_screens.dart"
    if deferred_path.is_file():
        source = read_text(deferred_path)
        dapp_start = source.find("class DappReviewScreen")
        dapp_source = source[dapp_start:] if dapp_start >= 0 else ""
        for marker in ("0x71E4", "Selected wallet", "\u5df2\u8fde\u63a5", "Blockaid"):
            if marker in dapp_source:
                errors.append(
                    "The DApp review must not invent a connection, a wallet "
                    f"identity or a reputation source: {marker}"
                )
        if re.search(r"(?i)0x[0-9a-f]{40}", dapp_source):
            errors.append(
                "The DApp review renders no wallet address; it reviews a URL "
                "and nothing else"
            )
        # Reviewing is local and read-only: no request may leave this page.
        for marker in ("Dio", "HttpClient", "launchUrl"):
            if marker in dapp_source:
                errors.append(
                    "The DApp review must never open or fetch the address: "
                    f"{marker}"
                )

    catalog_path = root / "lib/core/navigation/surface_catalog.dart"
    if catalog_path.is_file():
        source = read_text(catalog_path)
        wallet_start = source.find("// F · Wallet (20)")
        wallet_end = source.find("// G · Launchpad", wallet_start)
        wallet_source = source[wallet_start:wallet_end]
        for marker in (
            "supported accounts",
            "Holdings, cost basis and activity by chain",
            "Address, QR and network warning",
            "Provider quote, slippage and simulation",
            "Switch, rename and manage wallet capabilities",
            "Wallet-aware browser",
            "Review and revoke token permissions",
            "Enabled chains, testnets and RPC health",
        ):
            if marker in wallet_source:
                errors.append(
                    "Wallet catalog must report delivery truth, not a planned "
                    f"capability: {marker}"
                )

    return errors


def check_wallet_local_draft_contract(root: Path) -> list[str]:
    """Keep the exact amount lexicon, and keep local drafts out of a wallet.

    Step 6 replaced the Preview transfer and Swap drafts with server-prepared
    intents (decision 0059). What survives from decision 0022 is the part that
    still governs a real money action: the amount is exact text, never a
    `double`, and only a backend-canonical intent may reach the signing exit.
    """

    errors = require_fragments(
        root,
        {
            "docs/decisions/0022-bind-wallet-local-drafts-to-exact-snapshots.md": (
                "exact positive decimal String",
                "synchronous single-flight gate",
                "`IntentOrigin.backendCanonical`",
            ),
            "docs/failures/swap-preview-draft-divergence.md": (
                "## Summary",
                "## Root Cause",
                "## Detection",
                "## Prevention",
                "## Evidence",
            ),
            "lib/features/wallet/transfer_amount.dart": (
                "final class TransferAmount",
                "static const int maxWireLength = 128",
                "TransferAmount? tryParse(String source)",
            ),
            "test/transfer_amount_test.dart": (
                "accepts the exact maximum length and rejects longer values",
                "preserves trailing zeros in the display and future wire value",
                "rejects noncanonical, zero, signed, exponent, and spaced input",
            ),
        },
    )

    amount_path = root / "lib/features/wallet/transfer_amount.dart"
    if amount_path.is_file():
        source = strip_dart_comments(read_text(amount_path))
        if "maxWireLength = 128" not in source:
            errors.append("Transfer amount wire values must remain bounded to 128 characters")
        if (
            r"r'^(?:[1-9][0-9]*(?:\.[0-9]+)?|0\.[0-9]*[1-9][0-9]*)$'"
            not in source
        ):
            errors.append("Transfer amount must retain the exact positive-decimal regex")
        if "TransferAmount._(wire: source)" not in source:
            errors.append(
                "Transfer amount must preserve the accepted source String without normalization"
            )
        if (
            "final match = _wirePattern.firstMatch(source)" not in source
            or "match.start != 0 || match.end != source.length" not in source
        ):
            errors.append(
                "Transfer amount regex must consume the complete source String"
            )
        for marker in ("double.parse", ".toDouble()", "wire: value.toString()"):
            if marker in source:
                errors.append(
                    "Transfer amount must never round-trip through another numeric "
                    f"representation: {marker}"
                )

    intent_path = root / "lib/core/intent/signing_intent.dart"
    if intent_path.is_file():
        source = read_text(intent_path)
        for factory, following in (
            ("factory SigningIntent.swap", "factory SigningIntent.approval"),
            ("factory SigningIntent.transfer", "factory SigningIntent.swap"),
            ("factory SigningIntent.approval", "final String revision;"),
            ("factory SigningIntent.perpOrder", "factory SigningIntent.transfer"),
        ):
            start = source.find(factory)
            if start < 0:
                continue
            body = source[start : source.find(following, start)]
            if "origin: IntentOrigin.localPreview" not in body:
                errors.append(f"{factory} must remain a local Preview intent")

    return errors


def check_wallet_providerless_controls_contract(root: Path) -> list[str]:
    """Keep mounted Wallet Preview controls observable and fail-closed."""

    errors = require_fragments(
        root,
        {
            "docs/decisions/0023-close-providerless-wallet-controls.md": (
                "A selected filter renders only",
                "allowance examples visible, but disable revocation",
                "Transaction Result as an explicit state-layout Preview",
            ),
            "docs/failures/providerless-wallet-controls-without-effects.md": (
                "## Summary",
                "## Root Cause",
                "## Detection",
                "## Prevention",
                "## Evidence",
            ),
            # S8 (decision 0060) retired the Bridge Preview snapshot: there is
            # no bridge runtime, so the status page renders no route. S27d
            # (walkthrough C-19) retired the three pending step rows with it:
            # nobody observes those steps, so 完成 / 进行中 / 等待 are states
            # this page may not invent.
            #
            # S58 (visual audit 2026-09-20 §A.13, item 4) put the page's
            # skeleton back: C-19 had been implemented by replacing the whole
            # page with a centred `LoopPageBlock`, which took the primary and
            # the 步骤 heading down with the invented rows and left the page
            # unrecognisable. The prototype keeps a deferred page's shape and
            # states the reason inside it, so the lock now names the shape and
            # leaves the no-invented-step rule to the test below, which
            # asserts it directly.
            "lib/features/wallet/deferred_screens.dart": (
                "class BridgeScreen",
                "class BridgeStatusScreen",
                "bridge-status-folio",
                "bridge-status-page-block",
                "BRIDGE_RUNTIME_DEFERRED",
            ),
            "lib/features/wallet/wallet_preview_activity.dart": (
                "enum WalletPreviewActivityKind",
                "enum WalletPreviewActivityFilter",
                "activity.kind == WalletPreviewActivityKind.sent",
                "activity.kind == WalletPreviewActivityKind.received",
                "activity.kind == WalletPreviewActivityKind.swap",
                "static const all = <WalletPreviewActivity>",
                "List<WalletPreviewActivity>.unmodifiable(all.where(filter.includes))",
            ),
            # Step 5 retired the Preview wallet-history filter and the testnet
            # toggle with `TransactionHistoryScreen` and `NetworksScreen`
            # (decision 0057); step 6 retired the Preview approvals screen, the
            # Preview send-asset search and the Preview transaction-result
            # layout with the real money-action pages (decision 0059), and step
            # 8 retired the Bridge Preview snapshot with the deferred surfaces
            # (decision 0060).
            "test/wallet_preview_activity_test.dart": (
                "each history filter returns only its labelled Preview category",
            ),
            "test/app_navigation_test.dart": (
                "Bridge status is reachable on its own and stays pending",
            ),
            "test/s8_deferred_pages_test.dart": (
                "bridge offers no amount, no route and no fee",
                "bridge-status keeps its skeleton and invents no step",
            ),
        },
    )

    bridge_path = root / "lib/features/wallet/deferred_screens.dart"
    if bridge_path.is_file():
        source = read_text(bridge_path)
        bridge_start = source.find("class BridgeScreen")
        bridge_end = source.find("class DappReviewScreen", bridge_start)
        bridge_source = (
            source[bridge_start:bridge_end] if bridge_start >= 0 else ""
        )
        # There is no bridge runtime, so no amount, route, fee, ETA or observed
        # step may be rendered.
        for marker in (
            "USDC",
            "Ethereum",
            "Base",
            "'Source confirmed'",
            "complete: true",
            "998.4",
        ):
            if marker in bridge_source:
                errors.append(
                    "Bridge has no runtime: it must not render a route, an "
                    f"amount or an observed step: {marker}"
                )
        status_probe_start = bridge_source.find("class BridgeStatusScreen")
        if (
            status_probe_start >= 0
            and "LoopBadge('等待')" in bridge_source[status_probe_start:]
        ):
            errors.append(
                "Bridge progress has no observer, so it may not draw a step in "
                "any state, pending included"
            )
        status_start = bridge_source.find("class BridgeStatusScreen")
        status_source = bridge_source[status_start:] if status_start >= 0 else ""
        if re.search(r"\bonPressed\s*:\s*onOpenWallet\b", status_source) is None:
            errors.append(
                "Bridge progress may offer only the truthful return-to-wallet "
                "action"
            )

    errors.extend(
        check_behavior_test_evidence(
            root,
            WALLET_PROVIDERLESS_CONTROL_BEHAVIOR_TEST_MARKERS,
        )
    )
    errors.extend(
        check_named_executable_test_evidence(
            root,
            WALLET_PROVIDERLESS_CONTROL_EXECUTABLE_TEST_EVIDENCE,
        )
    )

    return errors


def require_fragments(root: Path, contracts: dict[str, tuple[str, ...]]) -> list[str]:
    errors: list[str] = []
    for relative, fragments in contracts.items():
        path = root / relative
        if not path.is_file():
            errors.append(f"missing compatibility contract file: {relative}")
            continue
        text = read_text(path)
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{relative} is missing locked value `{fragment}`")
    return errors


def check_native_matrix(root: Path) -> list[str]:
    errors = require_fragments(
        root,
        {
            ".metadata": ('revision: "6655482ec06e547f90abf8ae7590466f4415978d"',),
            "bin/loop-sdk": (
                "LOOP_FLUTTER_ROOT",
                "6655482ec06e547f90abf8ae7590466f4415978d",
                '\"dartSdkVersion\": \"3.13.1\"',
            ),
            "android/settings.gradle.kts": (
                'id("com.android.application") version "8.13.2" apply false',
                'id("org.jetbrains.kotlin.android") version "2.3.20" apply false',
            ),
            "android/gradle/wrapper/gradle-wrapper.properties": ("gradle-8.14-all.zip",),
            "android/app/build.gradle.kts": (
                'id("org.jetbrains.kotlin.android")',
                'namespace = "com.cywd.loop"',
                'applicationId = "com.cywd.loop"',
                "compileSdk = 36",
                "minSdk = 28",
                "targetSdk = 36",
                "JavaVersion.VERSION_17",
                "JvmTarget.JVM_17",
            ),
            "android/build.gradle.kts": (
                "afterEvaluate",
                'plugins.hasPlugin("com.android.library")',
                "extensions.configure<com.android.build.api.dsl.LibraryExtension>",
                "compileSdk = 36",
            ),
            "android/app/src/main/kotlin/com/cywd/loop/MainActivity.kt": ("package com.cywd.loop",),
            "ios/Podfile": ("platform :ios, '17.0'",),
            "ios/Podfile.lock": (
                "shared_preferences_foundation",
                "local_auth_darwin",
                "COCOAPODS: 1.",
            ),
            "ios/Runner.xcodeproj/project.pbxproj": (
                "PRODUCT_BUNDLE_IDENTIFIER = com.cywd.loop;",
                "PRODUCT_BUNDLE_IDENTIFIER = com.cywd.loop.RunnerTests;",
            ),
            "ios/Runner/Info.plist": ("<string>Loop</string>", "<string>loop</string>"),
        },
    )
    for relative in ("bin/flutter", "bin/dart", "bin/loop-sdk"):
        path = root / relative
        if path.is_file() and not path.stat().st_mode & 0o111:
            errors.append(f"{relative} must be executable")

    xcode = root / "ios/Runner.xcodeproj/project.pbxproj"
    if xcode.is_file():
        text = read_text(xcode)
        targets = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", text)
        if not targets or any(target != "17.0" for target in targets):
            errors.append(f"every iOS deployment target must be 17.0, found {sorted(set(targets))}")
        if "FlutterGeneratedPluginSwiftPackage" in text or "XCLocalSwiftPackageReference" in text:
            errors.append("iOS project still contains Flutter Swift Package Manager references")
    android_app = root / "android/app/build.gradle.kts"
    if android_app.is_file() and 'signingConfigs.getByName("debug")' in read_text(android_app):
        errors.append("Android release must not fall back to the development debug signing key")
    return errors


def check_android_release_network_contract(root: Path) -> list[str]:
    """Require Release networking for production HTTPS adapters."""

    manifest_path = root / "android/app/src/main/AndroidManifest.xml"
    manifest, errors = _parse_xml(manifest_path, "Android main manifest")
    if manifest is None:
        return errors

    active = [
        permission
        for permission in manifest.findall("uses-permission")
        if permission.get(ANDROID_NAME) == ANDROID_INTERNET_PERMISSION
        and permission.get(ANDROID_TOOLS_NODE) != "remove"
    ]
    if len(active) != 1:
        errors.append(
            "Android Release must explicitly declare active permission "
            f"`{ANDROID_INTERNET_PERMISSION}` exactly once"
        )
    return errors


def _parse_xml(path: Path, label: str) -> tuple[ElementTree.Element | None, list[str]]:
    if not path.is_file():
        return None, [f"missing {label}: {path.relative_to(path.parents[3])}"]
    try:
        return ElementTree.parse(path).getroot(), []
    except (OSError, ElementTree.ParseError) as error:
        return None, [f"{label} is not valid XML: {error}"]


def _parse_plist(path: Path, label: str) -> tuple[dict[str, Any] | None, list[str]]:
    if not path.is_file():
        return None, [f"missing {label}: {path}"]
    try:
        with path.open("rb") as stream:
            value = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as error:
        return None, [f"{label} is not a valid property list: {error}"]
    if not isinstance(value, dict):
        return None, [f"{label} must contain a dictionary"]
    return value, []


def check_reown_identity_contract(root: Path) -> list[str]:
    """Keep Reown an EVM-only signer for Privy credentials, never identity."""

    errors: list[str] = []

    config_path = root / "lib/app/app_config.dart"
    if not config_path.is_file():
        errors.append("missing Reown identity config: lib/app/app_config.dart")
    else:
        config = read_text(config_path)
        for field, define in (
            ("privyAppClientId", "PRIVY_APP_CLIENT_ID"),
            ("reownProjectId", "REOWN_PROJECT_ID"),
        ):
            match = re.search(
                rf"\b{field}\s*:\s*(?:const\s+)?String\.fromEnvironment\(\s*"
                rf"['\"]{define}['\"](?P<tail>[^)]*)\)",
                config,
                re.DOTALL,
            )
            tail = match.group("tail").strip() if match else None
            if match is None or tail not in ("", ","):
                errors.append(
                    f"AppConfig `{field}` must read `{define}` directly from "
                    "--dart-define without a compiled default"
                )

        expected_constants = {
            "privyOAuthScheme": PRIVY_OAUTH_SCHEME,
            "reownWalletScheme": REOWN_WALLET_SCHEME,
            "reownMetadataUrl": "https://quant-dinger.cc",
            "reownIconUrl": (
                "https://placehold.co/512x512/111827/FFFFFF.png?text=LOOP"
            ),
        }
        for name, value in expected_constants.items():
            if not re.search(
                rf"\b{re.escape(name)}\s*=\s*['\"]{re.escape(value)}['\"]",
                config,
                re.DOTALL,
            ):
                errors.append(
                    f"AppConfig must preserve `{name}` as client-safe value `{value}`"
                )

        for forbidden in (
            "PRIVY_APP_SECRET",
            "PRIVY_SECRET",
            "APPLE_CLIENT_SECRET",
            "APPLE_PRIVATE_KEY",
            "GOOGLE_CLIENT_SECRET",
            "REOWN_SECRET",
        ):
            if forbidden in config:
                errors.append(
                    f"AppConfig must not contain privileged credential `{forbidden}`"
                )

    connector_path = root / REOWN_CONNECTOR_PATH
    if not connector_path.is_file():
        errors.append(f"missing Reown connector: {REOWN_CONNECTOR_PATH}")
        connector = ""
    else:
        connector = read_text(connector_path)

    if connector and REOWN_SDK_IMPORT not in connector:
        errors.append("The reviewed Reown connector must own the AppKit SDK import")

    required_connector_fragments = (
        "this.initializationTimeout = const Duration(seconds: 30)",
        "ExternalWalletInitializationGate(",
        "bool get hasRetainedOwner => _owner != null",
        "on TimeoutException",
        "reconnect: (owner) => owner.reconnectRelay()",
        "namespace: NetworkUtils.eip155",
        "NetworkUtils.eip155: RequiredNamespace(",
        "method: 'personal_sign'",
        "chainId: 'eip155:${identity.chainId}'",
        "url: AppConfig.reownMetadataUrl",
        "icons: <String>[AppConfig.reownIconUrl]",
        "native: '${AppConfig.reownWalletScheme}://'",
        "siweConfig: null",
        "email: false",
        "socials: const <AppKitSocialOption>[]",
        "enableAnalytics: false",
        "linkMode: false",
    )
    for fragment in required_connector_fragments:
        if fragment not in connector:
            errors.append(
                "Reown must remain EVM-only with provider auth, analytics, "
                f"SIWE and Link Mode disabled (`{fragment}`)"
            )

    method_blocks = re.findall(
        r"\bmethods:\s*const\s*<String>\s*\[(?P<body>.*?)\]",
        connector,
        re.DOTALL,
    )
    method_sets = [
        re.findall(r"['\"]([^'\"]+)['\"]", body) for body in method_blocks
    ]
    if not method_sets or any(methods != ["personal_sign"] for methods in method_sets):
        errors.append(
            "Every Reown namespace proposal must allow exactly `personal_sign`"
        )

    namespace_proposals = re.findall(
        r"(NetworkUtils\.[A-Za-z_]\w*|['\"][^'\"]+['\"]):\s*"
        r"RequiredNamespace\s*\(",
        connector,
    )
    if namespace_proposals != ["NetworkUtils.eip155"]:
        errors.append(
            "Reown must propose exactly one `NetworkUtils.eip155` namespace"
        )

    request_methods = re.findall(
        r"\bmethod:\s*['\"]([^'\"]+)['\"]",
        connector,
    )
    if request_methods != ["personal_sign"]:
        errors.append("Every Reown wallet request must use exactly `personal_sign`")

    network_namespaces = set(
        re.findall(r"\bNetworkUtils\.([A-Za-z_]\w*)", connector)
    )
    if network_namespaces != {"eip155"} or re.search(
        r"['\"]solana:", connector
    ):
        errors.append(
            "The Reown connector must use only the `eip155` namespace and never Solana"
        )

    excluded = re.search(
        r"excludedWalletIds:\s*const\s*<String>\s*\{(?P<body>.*?)\}",
        connector,
        re.DOTALL,
    )
    excluded_body = excluded.group("body") if excluded else ""
    for wallet_id, expected_value in REOWN_EXCLUDED_WALLET_IDS.items():
        if wallet_id not in excluded_body:
            errors.append(
                "Reown's initial EVM-only wallet list must exclude "
                f"the reviewed Solana-capable wallet id `{wallet_id}`"
            )
        if not re.search(
            rf"\b{re.escape(wallet_id)}\s*=\s*['\"]{expected_value}['\"]",
            connector,
        ):
            errors.append(
                "Reown's excluded-wallet constants must preserve the reviewed "
                f"WalletGuide id for `{wallet_id}`"
            )

    lib_root = root / "lib"
    if lib_root.is_dir():
        for path in sorted(lib_root.rglob("*.dart")):
            source = read_text(path)
            relative = path.relative_to(root)
            if "package:reown_appkit/" in source and relative != REOWN_CONNECTOR_PATH:
                errors.append(
                    "The Reown SDK import must stay inside the reviewed connector, "
                    f"found in {relative}"
                )
            is_forbidden_boundary = (
                relative in REOWN_FORBIDDEN_IMPORT_FILES
                or any(parent in relative.parents for parent in REOWN_FORBIDDEN_IMPORT_ROOTS)
            )
            if is_forbidden_boundary and (
                "package:reown_appkit/" in source
                or "loop_mobile/integrations/reown/" in source
            ):
                errors.append(
                    "Reown must not enter wallet signing, trading, Perp, Market, "
                    f"or Hyperliquid boundaries: {relative}"
                )

    errors.extend(
        require_fragments(
            root,
            {
                "lib/integrations/privy/privy_auth_gateway.dart": (
                    "PrivyOAuthLoginProvider.google => OAuthProvider.google",
                    "PrivyOAuthLoginProvider.apple => OAuthProvider.apple",
                    "appUrlScheme: AppConfig.privyOAuthScheme",
                ),
                "lib/integrations/reown/external_wallet_credential_gateway.dart": (
                    "_privy.generateSiweMessage(request)",
                    "ExternalWalletCredentialIntent.login => _privy.loginWithSiwe(",
                    "ExternalWalletCredentialIntent.link => _privy.linkWithSiwe(",
                ),
                "docs/decisions/0043-use-reown-only-for-privy-external-evm-credentials.md": (
                    "Pin `reown_appkit` exactly at 1.8.4.",
                    "EVM connection and `personal_sign` transport",
                    "Disable AppKit Email, Social, Embedded Wallet, AppKit SIWE, analytics, and",
                    "Link Mode.",
                    "credentials; they are not LOOP trading",
                ),
                "docs/open-source-attribution.md": (
                    "reown_appkit",
                    "1.8.4",
                    "Reown Community License",
                ),
                "test/app_config_test.dart": (
                    "external wallet requires an exact public Reown project ID",
                ),
                "test/external_wallet_credential_gateway_test.dart": (
                    "parses only canonical EVM CAIP-10 accounts",
                    "encodes the exact UTF-8 SIWE message for personal_sign",
                    "maps concrete Reown rejection installation and callback errors",
                    "initialization timeout reuses one owner and reconnects on retry",
                    "signed-out intent signs and forwards exact params to SIWE login",
                    "authenticated intent can only link to the expected principal",
                    "link without a principal never opens the wallet connector",
                ),
                "test/identity_auth_controller_test.dart": (
                    "Google OAuth uses the shared lease and accepts the Privy account",
                    "Apple login remains unavailable outside iOS",
                    "signed-out wallet connection always selects SIWE login",
                    "authenticated wallet connection only links current principal",
                    "a cross-account link result is rejected without rotating session",
                    "wallet ownership and cancellation errors stay explicit",
                    "OTP in flight suppresses OAuth and wallet operations",
                ),
                "test/privy_login_screen_test.dart": (
                    "keeps Email and exposes Google plus external EVM wallet login",
                    "shows Apple only for the iOS composition",
                    "one OAuth operation disables every authentication action",
                ),
                "test/post_auth_bootstrap_coordinator_test.dart": (
                    "requests once per login principal but not for a credential link",
                    "logout permits a later login by the same principal to bootstrap",
                    "restricted and preview sessions never request bootstrap",
                    "temporary restoring or unverified state does not duplicate bootstrap",
                ),
            },
        )
    )

    manifest_path = root / "android/app/src/main/AndroidManifest.xml"
    manifest, manifest_errors = _parse_xml(manifest_path, "Android main manifest")
    errors.extend(manifest_errors)
    if manifest is not None:
        application = manifest.find("application")
        if application is None:
            errors.append("Android main manifest must contain an application element")
        else:
            activities = list(application.findall("activity"))
            by_name: dict[str, list[ElementTree.Element]] = {}
            scheme_owners: dict[str, list[str]] = {}
            for activity in activities:
                name = activity.get(ANDROID_NAME, "")
                by_name.setdefault(name, []).append(activity)
                for intent_filter in activity.findall("intent-filter"):
                    for data in intent_filter.findall("data"):
                        scheme = data.get(ANDROID_SCHEME)
                        if scheme:
                            scheme_owners.setdefault(scheme, []).append(name)

            expected_owners = {
                PRIVY_OAUTH_SCHEME: "io.privy.sdk.oAuth.PrivyRedirectActivity",
                REOWN_WALLET_SCHEME: ".MainActivity",
            }
            for scheme, owner in expected_owners.items():
                if scheme_owners.get(scheme) != [owner]:
                    errors.append(
                        f"Android scheme `{scheme}` must belong exactly once to `{owner}`, "
                        f"found {scheme_owners.get(scheme, [])}"
                    )

            privy_activities = by_name.get(
                "io.privy.sdk.oAuth.PrivyRedirectActivity", []
            )
            if len(privy_activities) != 1 or privy_activities[0].get(
                ANDROID_EXPORTED
            ) != "true":
                errors.append(
                    "Android must expose exactly one PrivyRedirectActivity for OAuth callbacks"
                )

            main_activities = by_name.get(".MainActivity", [])
            if len(main_activities) != 1:
                errors.append("Android must contain exactly one LOOP MainActivity")
            else:
                deep_link_flags = [
                    item.get(ANDROID_VALUE)
                    for item in main_activities[0].findall("meta-data")
                    if item.get(ANDROID_NAME) == "flutter_deeplinking_enabled"
                ]
                if deep_link_flags != ["false"]:
                    errors.append(
                        "Android MainActivity must set `flutter_deeplinking_enabled` "
                        "to false exactly once"
                    )

        queries = manifest.find("queries")
        packages = (
            [item.get(ANDROID_NAME, "") for item in queries.findall("package")]
            if queries is not None
            else []
        )
        if len(packages) != len(ANDROID_REOWN_WALLET_PACKAGES) or frozenset(
            packages
        ) != ANDROID_REOWN_WALLET_PACKAGES:
            errors.append(
                "Android wallet package queries must be exactly MetaMask, Trust, "
                f"and Rainbow: {sorted(ANDROID_REOWN_WALLET_PACKAGES)}"
            )

    info_path = root / "ios/Runner/Info.plist"
    info, info_errors = _parse_plist(info_path, "iOS Runner Info.plist")
    errors.extend(info_errors)
    if info is not None:
        raw_url_types = info.get("CFBundleURLTypes")
        url_types = raw_url_types if isinstance(raw_url_types, list) else []
        scheme_groups: list[list[str]] = []
        for item in url_types:
            if not isinstance(item, dict):
                continue
            schemes = item.get("CFBundleURLSchemes")
            if isinstance(schemes, list) and all(
                isinstance(scheme, str) for scheme in schemes
            ):
                scheme_groups.append(schemes)

        for scheme in (PRIVY_OAUTH_SCHEME, REOWN_WALLET_SCHEME):
            owners = [group for group in scheme_groups if scheme in group]
            if len(owners) != 1:
                errors.append(
                    f"iOS URL scheme `{scheme}` must be registered exactly once"
                )
        if any(
            PRIVY_OAUTH_SCHEME in group and REOWN_WALLET_SCHEME in group
            for group in scheme_groups
        ):
            errors.append("iOS Privy and Reown schemes must use separate URL types")

        query_schemes = info.get("LSApplicationQueriesSchemes")
        if (
            not isinstance(query_schemes, list)
            or len(query_schemes) != len(IOS_REOWN_WALLET_SCHEMES)
            or frozenset(query_schemes) != IOS_REOWN_WALLET_SCHEMES
        ):
            errors.append(
                "iOS wallet query schemes must be exactly MetaMask, Trust, and Rainbow"
            )

    entitlements_path = root / "ios/Runner/Runner.entitlements"
    entitlements, entitlement_errors = _parse_plist(
        entitlements_path, "iOS Runner entitlements"
    )
    errors.extend(entitlement_errors)
    if entitlements is not None and entitlements.get(
        "com.apple.developer.applesignin"
    ) != ["Default"]:
        errors.append(
            "Runner entitlements must enable Sign in with Apple as `Default`"
        )

    project_path = root / "ios/Runner.xcodeproj/project.pbxproj"
    if not project_path.is_file():
        errors.append("missing iOS Xcode project for Sign in with Apple")
    else:
        project = read_text(project_path)
        if not re.search(
            r"com\.apple\.SignInWithApple\s*=\s*\{\s*enabled\s*=\s*1;\s*\};",
            project,
            re.DOTALL,
        ):
            errors.append("Runner target must enable the Sign in with Apple capability")
        build_settings = re.findall(
            r"buildSettings\s*=\s*\{(?P<body>.*?)\n\s*\};",
            project,
            re.DOTALL,
        )
        runner_settings = [
            body
            for body in build_settings
            if "INFOPLIST_FILE = Runner/Info.plist;" in body
        ]
        if len(runner_settings) != 3 or any(
            "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" not in body
            for body in runner_settings
        ):
            errors.append(
                "Every Runner Debug, Release, and Profile configuration must "
                "use Runner/Runner.entitlements"
            )

    return errors


def _require_android_removals(
    elements: list[ElementTree.Element],
    expected_names: frozenset[str],
    label: str,
) -> list[str]:
    errors: list[str] = []
    by_name: dict[str, list[ElementTree.Element]] = {}
    for element in elements:
        name = element.get(ANDROID_NAME)
        if name:
            by_name.setdefault(name, []).append(element)
    for name in sorted(expected_names):
        matches = by_name.get(name, [])
        if not any(element.get(ANDROID_TOOLS_NODE) == "remove" for element in matches):
            errors.append(f"Android foreground Audio Room must remove {label} `{name}` with tools:node=\"remove\"")
        if any(element.get(ANDROID_TOOLS_NODE) != "remove" for element in matches):
            errors.append(f"Android foreground Audio Room must not activate {label} `{name}`")
    return errors


def check_audio_room_native_contract(root: Path) -> list[str]:
    """Keep the first Audio Room slice microphone-only and foreground-only."""

    errors: list[str] = []
    for relative in ("pubspec.yaml", "pubspec.lock"):
        package_file = root / relative
        if package_file.is_file() and "stream_video_push_notification" in read_text(package_file):
            errors.append(
                f"Foreground Audio Room must not link the auto-registering "
                f"`stream_video_push_notification` plugin in {relative}"
            )
    manifest_path = root / "android/app/src/main/AndroidManifest.xml"
    manifest, manifest_errors = _parse_xml(manifest_path, "Android main manifest")
    errors.extend(manifest_errors)
    if manifest is not None:
        permissions = list(manifest.findall("uses-permission"))
        by_name: dict[str, list[ElementTree.Element]] = {}
        for permission in permissions:
            name = permission.get(ANDROID_NAME)
            if name:
                by_name.setdefault(name, []).append(permission)

        for name in sorted(ANDROID_AUDIO_ROOM_PERMISSIONS):
            active = [
                permission
                for permission in by_name.get(name, [])
                if permission.get(ANDROID_TOOLS_NODE) != "remove"
            ]
            if len(active) != 1:
                errors.append(
                    f"Android foreground Audio Room must explicitly declare active permission `{name}` exactly once"
                )

        for name in sorted(ANDROID_AUDIO_ROOM_FORBIDDEN_ACTIVE_PERMISSIONS):
            if any(
                permission.get(ANDROID_TOOLS_NODE) != "remove"
                for permission in by_name.get(name, [])
            ):
                errors.append(f"Android foreground Audio Room must not activate permission `{name}`")

        errors.extend(
            _require_android_removals(
                permissions,
                ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS,
                "permission",
            )
        )
        errors.extend(
            _require_android_removals(
                list(manifest.findall("permission")),
                ANDROID_AUDIO_ROOM_REMOVED_DECLARED_PERMISSIONS,
                "declared permission",
            )
        )

        for feature in manifest.findall("uses-feature"):
            name = feature.get(ANDROID_NAME, "")
            if name.startswith("android.hardware.camera") and feature.get(ANDROID_TOOLS_NODE) != "remove":
                errors.append(f"Android foreground Audio Room must not activate camera feature `{name}`")

        application = manifest.find("application")
        if application is None:
            errors.append("Android main manifest must contain an application element")
        else:
            for tag, names in ANDROID_AUDIO_ROOM_REMOVED_COMPONENTS.items():
                errors.extend(
                    _require_android_removals(
                        list(application.findall(tag)),
                        names,
                        tag,
                    )
                )

    info_path = root / "ios/Runner/Info.plist"
    info, info_errors = _parse_plist(info_path, "iOS Runner Info.plist")
    errors.extend(info_errors)
    if info is not None:
        microphone_description = info.get("NSMicrophoneUsageDescription")
        if not isinstance(microphone_description, str) or not microphone_description.strip():
            errors.append("iOS foreground Audio Room requires a non-empty NSMicrophoneUsageDescription")
        # S70: push replaced the blanket refusal. The array is checked rather
        # than merely allowed, because `audio` or `voip` in it would turn
        # Audio Room into a background call without a single Dart change.
        if info.get("UIBackgroundModes") != list(IOS_PUSH_BACKGROUND_MODES):
            errors.append(
                "iOS must declare UIBackgroundModes as exactly "
                f"{list(IOS_PUSH_BACKGROUND_MODES)}, found "
                f"{info.get('UIBackgroundModes')!r}"
            )

    ios_root = root / "ios"
    if ios_root.is_dir():
        for path in sorted(ios_root.rglob("*.entitlements")):
            entitlements, entitlement_errors = _parse_plist(
                path,
                f"iOS entitlements {path.relative_to(root)}",
            )
            errors.extend(entitlement_errors)
            if entitlements is None:
                continue
            for key in sorted(IOS_AUDIO_ROOM_FORBIDDEN_ENTITLEMENTS.intersection(entitlements)):
                errors.append(
                    f"iOS foreground Audio Room must not declare entitlement `{key}` in {path.relative_to(root)}"
                )

    runner_root = root / "ios/Runner"
    if runner_root.is_dir():
        for path in sorted(runner_root.rglob("*.swift")):
            text = read_text(path)
            for marker in IOS_AUDIO_ROOM_FORBIDDEN_RUNNER_MARKERS:
                if marker in text:
                    errors.append(
                        f"iOS foreground Audio Room must not initialize CallKit/PushKit in "
                        f"{path.relative_to(root)} (`{marker}`)"
                    )

    xcode_project = root / "ios/Runner.xcodeproj/project.pbxproj"
    if xcode_project.is_file():
        text = read_text(xcode_project)
        for capability in ("com.apple.BackgroundModes", "com.apple.Push"):
            if capability in text:
                errors.append(f"iOS foreground Audio Room must not enable Xcode capability `{capability}`")
    return errors


def markdown_sections(path: Path) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in read_text(path).splitlines():
        match = re.fullmatch(r"##\s+(.+?)\s*", line)
        if match:
            current = match.group(1).strip()
            sections.setdefault(current, [])
        elif current:
            sections[current].append(line)
    return {name: "\n".join(lines).strip() for name, lines in sections.items()}


def check_chat_camera_contract(root: Path) -> list[str]:
    """Hold the chat camera to the one permission the ruling bought it."""

    errors: list[str] = []
    manifest_path = root / "android/app/src/main/AndroidManifest.xml"
    manifest, manifest_errors = _parse_xml(manifest_path, "Android main manifest")
    errors.extend(manifest_errors)
    if manifest is not None:
        active = [
            permission
            for permission in manifest.findall("uses-permission")
            if permission.get(ANDROID_NAME) == ANDROID_CHAT_CAMERA_PERMISSION
            and permission.get(ANDROID_TOOLS_NODE) != "remove"
        ]
        if len(active) != 1:
            errors.append(
                "chat camera requires exactly one active "
                f"`{ANDROID_CHAT_CAMERA_PERMISSION}` declaration"
            )

    info_path = root / "ios/Runner/Info.plist"
    info, info_errors = _parse_plist(info_path, "iOS Runner Info.plist")
    errors.extend(info_errors)
    if info is not None:
        description = info.get(IOS_CHAT_CAMERA_USAGE_KEY)
        if not isinstance(description, str) or not description.strip():
            errors.append(
                f"chat camera requires a non-empty {IOS_CHAT_CAMERA_USAGE_KEY}"
            )
        elif not any(word in description for word in ("相机", "拍照")):
            errors.append(
                f"{IOS_CHAT_CAMERA_USAGE_KEY} must tell the member, in Chinese, "
                "what the camera is for"
            )

    errors.extend(require_fragments(root, CHAT_CAMERA_CONTRACTS))
    errors.extend(check_behavior_test_evidence(root, CHAT_CAMERA_TEST_MARKERS))
    return errors


# ---------------------------------------------------------------------------
# S52 · the Token Card a chat message earns by naming a contract address
# ---------------------------------------------------------------------------

CHAT_TOKEN_CARD_DETECTION_PATH = Path(
    "lib/features/chat/token_card/chat_token_detection.dart"
)
CHAT_TOKEN_CARD_CACHE_PATH = Path(
    "lib/features/chat/token_card/chat_token_card_cache.dart"
)
CHAT_TOKEN_CARD_VIEW_PATH = Path("lib/features/chat/token_card/chat_token_card.dart")
CHAT_TOKEN_CARD_MESSAGE_PATH = Path(
    "lib/features/chat/group_alias/group_alias_stream_message_identity.dart"
)
CHAT_TOKEN_CARD_SURFACE_PATH = Path(
    "lib/features/chat/v2/loop_stream_channel_surface.dart"
)
CHAT_TOKEN_CARD_TEST_PATH = Path("test/s52_chat_token_card_test.dart")
CHAT_TOKEN_CARD_MODELS_PATH = Path("lib/features/chain/chain_models.dart")
CHAT_TOKEN_CARD_CODEC_PATH = Path(
    "lib/integrations/backend/v2/loop_v2_chain_codec.dart"
)
# An address the registry does not carry is answered by a provider lookup, and
# the three things that answer can be missing are the three the client must not
# invent: the ticker, the name and the precision.
CHAT_TOKEN_CARD_UNREGISTERED_MODEL_FRAGMENTS = (
    "unregistered('unregistered'",
    "unavailable('unavailable'",
    "providerLookup('provider_lookup')",
    "final String? symbol;",
    "final int? decimals;",
)
# S57: the asset endpoint answers one address in two shapes, and the second
# carries no identity at all — only a status and a reason. They are separate
# types so a surface cannot read a ticker, an address or a precision that was
# never reported, and the settled half stays non-nullable for the first.
MARKET_ASSET_IDENTITY_PATH = Path("lib/features/market/market_read_models.dart")
MARKET_ASSET_IDENTITY_FRAGMENTS = (
    "sealed class MarketAssetIdentity",
    "final class MarketAssetIdentitySettled extends MarketAssetIdentity",
    "final class MarketAssetIdentityUnavailable extends MarketAssetIdentity",
    "final MarketAssetIdentity asset;",
)
MARKET_ASSET_IDENTITY_CODEC_PATH = Path(
    "lib/integrations/backend/v2/market/loop_v2_market_api.dart"
)
MARKET_ASSET_IDENTITY_CODEC_FRAGMENTS = (
    "static MarketAssetIdentity _assetIdentity(Object? raw, String assetId)",
    "MarketAssetIdentityUnavailable(",
)
CHAT_TOKEN_CARD_UNREGISTERED_CODEC_FRAGMENTS = (
    "optionalText(map, 'symbol', maxLength: 32)",
    "optionalInt(map, 'decimals', maximum: 36)",
)
CHAT_TOKEN_CARD_COMPOSER_SCREENS = (
    Path("lib/features/chat/v2/community_chat_screen.dart"),
    Path("lib/features/chat/v2/group_screens.dart"),
    Path("lib/features/chat/v2/direct_message_screen.dart"),
)
# A 20-byte address is the only thing a message may be read for. The two
# boundaries are the rule, not decoration: without them the first 40 hex
# characters of a 32-byte hash read as somebody else's contract.
CHAT_TOKEN_CARD_PATTERN_FRAGMENTS = (
    "(?<![0-9A-Za-z])",
    "0x[0-9a-fA-F]{40}",
    "(?![0-9a-fA-F])",
)
CHAT_TOKEN_CARD_BEHAVIOR_MARKERS = (
    "a ticker is never an identity",
    "a hash, a truncation and a glued word are not addresses",
    "a message opens at most three cards, in writing order",
    "while the read is in flight nothing is claimed",
    "a read asset carries identity, quote, metrics and facts",
    "an unregistered address is answered, and says so",
    "buy and sell stay on the card and state why they are shut",
    "an address the registry does not carry says exactly that",
    "an address nothing could describe says so, not a ticker",
    "a closed provider renders the reason, not a figure",
    "an offline device says so and keeps the retry",
    "three bubbles naming the same contract are one read",
)


def check_chat_token_card_contract(root: Path) -> list[str]:
    """S52: a pasted contract address opens a card, and nothing else does.

    The message itself is never rewritten and never carries a fact, so every
    figure on the card comes from a read this client performed through the
    market port — the same port the token page reads — and every state the
    read can land in has a card that states it.
    """

    errors: list[str] = []
    required = (
        CHAT_TOKEN_CARD_DETECTION_PATH,
        CHAT_TOKEN_CARD_CACHE_PATH,
        CHAT_TOKEN_CARD_VIEW_PATH,
        CHAT_TOKEN_CARD_TEST_PATH,
    )
    for relative in required:
        if not (root / relative).is_file():
            errors.append(
                f"{relative} is missing; the chat Token Card is detection, "
                "one cached read and one view, and none of the three may "
                "disappear on its own"
            )
    if errors:
        return errors

    detection = read_text(root / CHAT_TOKEN_CARD_DETECTION_PATH)
    detection_code = strip_dart_comments(detection)
    if detection_code.count("RegExp(") != 1:
        errors.append(
            f"{CHAT_TOKEN_CARD_DETECTION_PATH} declares more than one "
            "matcher; a message is read for a contract address and for "
            "nothing else, so a second pattern is a second identity"
        )
    for fragment in CHAT_TOKEN_CARD_PATTERN_FRAGMENTS:
        if fragment not in detection_code:
            errors.append(
                f"{CHAT_TOKEN_CARD_DETECTION_PATH} no longer bounds the "
                f"address with `{fragment}`; an unbounded match reads the "
                "first 40 hex characters of a transaction hash as a contract"
            )
    if "loopChatTokenCardsPerMessage = 3;" not in detection_code:
        errors.append(
            f"{CHAT_TOKEN_CARD_DETECTION_PATH} no longer bounds how many "
            "cards one message opens; a pasted list would bury the message "
            "it was written under"
        )

    # No second detector anywhere in chat: one rule, one place.
    for path in sorted((root / "lib" / "features" / "chat").rglob("*.dart")):
        relative = path.relative_to(root)
        if relative == CHAT_TOKEN_CARD_DETECTION_PATH:
            continue
        if "[0-9a-fA-F]{40}" in strip_dart_comments(read_text(path)):
            errors.append(
                f"{relative} writes its own contract-address matcher; "
                "detection lives in "
                f"{CHAT_TOKEN_CARD_DETECTION_PATH} alone"
            )

    cache = strip_dart_comments(read_text(root / CHAT_TOKEN_CARD_CACHE_PATH))
    if "ref.read(marketReadGatewayProvider)" not in cache:
        errors.append(
            f"{CHAT_TOKEN_CARD_CACHE_PATH} no longer reads through the market "
            "port; a chat card may not reach a transport of its own"
        )
    if "Duration(seconds: 60)" not in cache:
        errors.append(
            f"{CHAT_TOKEN_CARD_CACHE_PATH} no longer holds an answer for a "
            "bounded time; without it a scrolled list re-reads one contract "
            "per frame"
        )
    for fragment in ("Dio", "'/v2/"):
        if fragment in cache:
            errors.append(
                f"{CHAT_TOKEN_CARD_CACHE_PATH} contains `{fragment}`; the "
                "feature layer states what it needs and the adapter decides "
                "how it is fetched"
            )

    view = strip_dart_comments(read_text(root / CHAT_TOKEN_CARD_VIEW_PATH))
    if "LoopV2CapabilityId.privySwap" not in view:
        errors.append(
            f"{CHAT_TOKEN_CARD_VIEW_PATH} no longer reads the swap gate; "
            "买入 and 卖出 must be shut by the same gate the wallet reads, "
            "not by a sentence of this card's own"
        )
    for action in ("const LoopTokenCardAction('买入', buy: true)", "const LoopTokenCardAction('卖出')"):
        if action not in view:
            errors.append(
                f"{CHAT_TOKEN_CARD_VIEW_PATH} no longer renders {action}; a "
                "money action on a chat card stays visible and stays "
                "unpressable, because hiding it answers a question the gate "
                "did not answer"
            )
    if "TokenCardSparklineView(" not in view:
        errors.append(
            f"{CHAT_TOKEN_CARD_VIEW_PATH} no longer draws the 1H line "
            "through the shared Token Card sparkline; a card that draws its "
            "own shape can draw one that is not a price"
        )
    for fragment in S7_SIGNING_MARKERS:
        if fragment in view:
            errors.append(
                f"{CHAT_TOKEN_CARD_VIEW_PATH} contains `{fragment}`; a chat "
                "card opens no signing entry"
            )

    message_item = strip_dart_comments(
        read_text(root / CHAT_TOKEN_CARD_MESSAGE_PATH)
    )
    for fragment in ("loopDetectChatTokenAddresses(", "ChatTokenCard("):
        if fragment not in message_item:
            errors.append(
                f"{CHAT_TOKEN_CARD_MESSAGE_PATH} no longer puts a card under "
                f"the bubble (`{fragment}` is gone); recognition that no "
                "message reaches is recognition that does not exist"
            )

    surface = read_text(root / CHAT_TOKEN_CARD_SURFACE_PATH)
    hint = re.search(
        r"const String loopChatComposerHint = '([^']*)';", surface
    )
    if hint is None:
        errors.append(
            f"{CHAT_TOKEN_CARD_SURFACE_PATH} no longer declares "
            "loopChatComposerHint; every conversation promises the same "
            "thing in the same words"
        )
    else:
        if "贴合约地址" not in hint.group(1):
            errors.append(
                "loopChatComposerHint no longer tells the writer that a "
                "pasted contract address is read; a composer that does not "
                "say it leaves the card unexplained"
            )
        if "AI" in hint.group(1):
            errors.append(
                "loopChatComposerHint promises an assistant; there is no "
                "Community AI to ask, so the composer may not offer one"
            )
    for relative in CHAT_TOKEN_CARD_COMPOSER_SCREENS:
        path = root / relative
        if not path.is_file():
            continue
        screen = strip_dart_comments(read_text(path))
        if "composerHint: loopChatComposerHint" not in screen:
            errors.append(
                f"{relative} writes its own composer placeholder; the three "
                "conversations promise the same thing, so they read one "
                "constant"
            )

    models = strip_dart_comments(read_text(root / CHAT_TOKEN_CARD_MODELS_PATH))
    for fragment in CHAT_TOKEN_CARD_UNREGISTERED_MODEL_FRAGMENTS:
        if fragment not in models:
            errors.append(
                f"{CHAT_TOKEN_CARD_MODELS_PATH} no longer carries "
                f"`{fragment}`; an address answered by a provider lookup has "
                "a status, a source and three fields that may be absent, and "
                "a client that cannot express one of them invents it instead"
            )
    codec = strip_dart_comments(read_text(root / CHAT_TOKEN_CARD_CODEC_PATH))
    for fragment in CHAT_TOKEN_CARD_UNREGISTERED_CODEC_FRAGMENTS:
        if fragment not in codec:
            errors.append(
                f"{CHAT_TOKEN_CARD_CODEC_PATH} requires `{fragment}` to be "
                "present on the wire; a provider that reports no ticker and "
                "no precision would then drop the whole asset"
            )
    for fragment in ("LoopAssetStatus.unregistered", "MarketAssetIdentityUnavailable"):
        if fragment not in view:
            errors.append(
                f"{CHAT_TOKEN_CARD_VIEW_PATH} no longer reads "
                f"`{fragment}`; an address outside the registry would then be "
                "presented exactly like a listed one"
            )
    identity = strip_dart_comments(read_text(root / MARKET_ASSET_IDENTITY_PATH))
    for fragment in MARKET_ASSET_IDENTITY_FRAGMENTS:
        if fragment not in identity:
            errors.append(
                f"{MARKET_ASSET_IDENTITY_PATH} no longer carries "
                f"`{fragment}`; an answer that could describe nothing would "
                "then be held as an asset whose every field is null, and a "
                "surface would print a ticker no provider reported"
            )
    asset_codec = strip_dart_comments(
        read_text(root / MARKET_ASSET_IDENTITY_CODEC_PATH)
    )
    for fragment in MARKET_ASSET_IDENTITY_CODEC_FRAGMENTS:
        if fragment not in asset_codec:
            errors.append(
                f"{MARKET_ASSET_IDENTITY_CODEC_PATH} no longer carries "
                f"`{fragment}`; a 200 whose asset block states only a status "
                "and a reason would be refused as an invalid payload"
            )
    errors.extend(
        check_behavior_test_evidence(
            root,
            {CHAT_TOKEN_CARD_TEST_PATH: CHAT_TOKEN_CARD_BEHAVIOR_MARKERS},
        )
    )
    return errors


def check_records(root: Path) -> list[str]:
    errors: list[str] = []
    for path in sorted((root / "docs/decisions").glob("*.md")):
        if not re.fullmatch(r"[0-9]{4}-[a-z0-9]+(?:-[a-z0-9]+)*\.md", path.name):
            errors.append(f"decision filename is invalid: {path.relative_to(root)}")
        sections = markdown_sections(path)
        for name in DECISION_SECTIONS:
            if not sections.get(name):
                errors.append(f"{path.relative_to(root)} requires non-empty `## {name}`")
    for path in sorted((root / "docs/failures").glob("*.md")):
        sections = markdown_sections(path)
        for name in FAILURE_SECTIONS:
            if not sections.get(name):
                errors.append(f"{path.relative_to(root)} requires non-empty `## {name}`")
    adoption = root / "docs/harness/adoption-report.md"
    if adoption.is_file():
        sections = markdown_sections(adoption)
        for name in ADOPTION_SECTIONS:
            if not sections.get(name):
                errors.append(f"{adoption.relative_to(root)} requires non-empty `## {name}`")
    return errors


def check_product_contract(root: Path) -> list[str]:
    errors = require_fragments(
        root,
        {
            "README.md": (
                "Repository phase: `active`.",
                "Community / Mining / Launch / Market / Wallet",
                "harness.json",
                "python3 scripts/check_harness.py",
            ),
            "AGENTS.md": (
                "Repository phase: `active`.",
                "Community / Mining / Launch / Market / Wallet",
                "Community is the post-login home",
                "python3 scripts/check_harness.py",
            ),
            "docs/product/implementation-constraints.md": (
                "Never use `double` for trading calculations.",
                "A client timeout is not a confirmed failure",
                "`while (hasMore)`/recursive full-history fetches",
                "Stream `Call`, `CallState`, and its push notification manager are the call source of truth.",
                "Generate a new UUID call ID for every outgoing call.",
            ),
            "lib/app/app_config.dart": (
                "const String.fromEnvironment('PRIVY_APP_CLIENT_ID')",
                "const String.fromEnvironment('REOWN_PROJECT_ID')",
                "const String.fromEnvironment('STREAM_API_KEY')",
                "const String.fromEnvironment('LOOP_BACKEND_BASE_URL')",
            ),
            "config/debug.json": (
                "cmt2t8k4n00780cjsxjqk0dkq",
                "qpwjdy8zjbdu",
                "https://api-dev.quant-dinger.cc",
            ),
            "lib/integrations/communication/stream_video_sdk_session.dart": (
                "muteAudioWhenInBackground: false",
                "muteVideoWhenInBackground: false",
                "keepConnectionsAliveWhenInBackground: false",
            ),
            "lib/integrations/privy/privy_auth_gateway.dart": (
                "required String expectedPrivyUserId",
                "_walletCreationOwner != expectedPrivyUserId",
                "PrivyWalletCreationResult _walletCreationResult",
            ),
            "lib/app/session/loop_session_controller.dart": (
                "expectedPrivyUserId: requestedPrincipal",
                "creation.privyUserId != requestedPrincipal",
            ),
            "lib/features/chat/calls/audio_room_call.dart": (
                "Future<void> retireForBackground()",
                "AudioRoomCallCommandCoordinator",
                "unawaited(_suspendAudioIgnoringFailure())",
                "unawaited(_muteIgnoringFailure())",
                "await _leave()",
                "await _microphoneTail",
                "await _muteIgnoringFailure()",
                "_microphoneEnableRequested",
                "bool get retirementStarted",
                "getTrack(trackIdPrefix, SfuTrackType.audio)",
                "activeCalls.asStream().firstWhere",
                "identical(candidate, _call)",
                "return _commands.retire()",
            ),
            "lib/features/chat/calls/stream_voice_room_page.dart": (
                # A media failure is not a membership failure: the account is
                # still in the room, and the surface says so before it offers
                # the connection back.
                "已加入，语音连接失败",
                "重新连接语音",
                "AppLifecycleState.paused",
                "AppLifecycleState.hidden",
                "AppLifecycleState.detached",
                "_retireForBackground()",
                "_resumeAfterBackgroundRetirement",
                # The retry the reader is offered after a failed retirement.
                # It is written in the product's own language like every other
                # sentence on the surface.
                "重试收尾",
            ),
            "lib/features/chat/calls/stream_foreground_call_view.dart": (
                "required this.retirementStarted",
                "需要先重试退出",
            ),
        },
    )
    profile, profile_errors = load_profile(root)
    errors.extend(profile_errors)
    if profile:
        purpose = profile.get("project", {}).get("purpose")
        if isinstance(purpose, str):
            # Decision 0048 is the scoped navigation override. The canonical
            # runtime purpose is mirrored in the user-facing repository README.
            for relative in ("README.md", "AGENTS.md"):
                if purpose not in read_text(root / relative):
                    errors.append(f"{relative} must mirror the harness project purpose")
    errors.extend(
        check_behavior_test_evidence(
            root,
            {
                Path("test/loop_session_controller_test.dart"): (
                    "a prior principal wallet future cannot attach to the current principal",
                ),
            },
        )
    )
    return errors


ROUTE_MANIFEST_JSON_PATH = Path("docs/product/routes-manifest.json")
ROUTE_MANIFEST_DART_PATH = Path("lib/core/navigation/route_manifest.dart")
ROUTE_MANIFEST_APP_PATH = Path("lib/app.dart")
# Locations retired by decision 0050. None may be mounted, redirected or
# pushed from the application router again.
ROUTE_MANIFEST_RETIRED_LITERALS = (
    "'/onboarding'",
    "'/notifications'",
    "'/onramp'",
    "'/pay/receive'",
    "'/pay/confirm'",
    "'/auth/wallet/seed'",
    "'/auth/wallet/seed/verify'",
    "'/auth/wallet/import'",
    "'/auth/profile'",
    "'/profile/recovery'",
    "'/profile/copy'",
    "'/profile/rewards'",
    "'/home/net-worth'",
    "'/home/security'",
    "'/chat/meeting'",
    "'/wallet/transaction'",
    "'/wallet/dapps'",
    "'/wallet/protection'",
    "'/inventory'",
)


def check_route_manifest_contract(root: Path) -> list[str]:
    """Keep the Dart route table equal to the frozen 93-route manifest."""

    errors: list[str] = []
    json_path = root / ROUTE_MANIFEST_JSON_PATH
    dart_path = root / ROUTE_MANIFEST_DART_PATH
    if not json_path.is_file() or not dart_path.is_file():
        return errors
    try:
        manifest = json.loads(read_text(json_path))
    except json.JSONDecodeError as error:
        return [f"{ROUTE_MANIFEST_JSON_PATH} is invalid JSON: {error}"]
    expected_slugs = [
        item["slug"]
        for module in manifest.get("modules", {}).values()
        for item in module
    ]
    if manifest.get("count") != 93 or len(expected_slugs) != 93:
        errors.append(f"{ROUTE_MANIFEST_JSON_PATH} must describe exactly 93 routes")
    if manifest.get("tabs") != ["community", "mining", "launch", "market", "wallet"]:
        errors.append(f"{ROUTE_MANIFEST_JSON_PATH} must keep the five tabs in order")
    if manifest.get("defaultRoute") != "community":
        errors.append(f"{ROUTE_MANIFEST_JSON_PATH} must land on community")
    if [name.title() for name in manifest.get("tabs", [])] != PRIMARY_DESTINATIONS:
        errors.append("harness primary destinations must mirror the manifest tabs")

    dart_source = strip_dart_comments(read_text(dart_path))
    entries_start = dart_source.find("static const List<LoopRouteEntry> entries")
    entries_end = dart_source.find("];", entries_start)
    entries_block = dart_source[entries_start:entries_end]
    dart_slugs = re.findall(r"slug:\s*'([a-z0-9-]+)'", entries_block)
    if dart_slugs != expected_slugs:
        errors.append(
            "lib/core/navigation/route_manifest.dart entries must list the 93 manifest "
            "slugs in manifest order"
        )
    dart_paths = re.findall(r"\bpath:\s*'([^']+)'", entries_block)
    if len(set(dart_paths)) != len(dart_paths) or len(dart_paths) != len(dart_slugs):
        errors.append("Route manifest must map every slug to exactly one unique path")
    for literal in ROUTE_MANIFEST_RETIRED_LITERALS:
        if literal in entries_block.replace("legacyPath: " + literal, ""):
            errors.append(f"Route manifest must not map a slug to retired path {literal}")

    app_path = root / ROUTE_MANIFEST_APP_PATH
    if app_path.is_file():
        app_source = strip_dart_comments(read_text(app_path))
        for literal in ROUTE_MANIFEST_RETIRED_LITERALS:
            if literal in app_source:
                errors.append(
                    f"lib/app.dart must not mount or redirect retired route {literal}"
                )
        for marker in (
            "_pendingManifestRoutes",
            "LoopRouteManifest.withStatus(",
            "LoopPendingSurface(entry: entry)",
        ):
            if marker not in app_source:
                errors.append(
                    "lib/app.dart must mount every unimplemented manifest slug through "
                    f"the pending surface; missing `{marker}`"
                )

    shell_path = root / "lib/features/shell/loop_shell.dart"
    if shell_path.is_file():
        shell_source = strip_dart_comments(read_text(shell_path))
        start = shell_source.find("static const _destinations")
        end = shell_source.find("  ];", start)
        shell_paths = re.findall(r"'(/[a-z]+)'", shell_source[start:end])
        if shell_paths != ["/" + slug for slug in manifest.get("tabs", [])]:
            errors.append("LoopShell destinations must follow the manifest tab order")
    return errors


S3_COMMUNITY_TEST_MARKERS = {
    Path("test/community_social_pages_test.dart"): (
        "a result opens through its destination kind",
        "an asset result opens the token page by its assetId",
        "the two deferred domains show their server reason",
    ),
    Path("test/community_pages_test.dart"): (
        "a row renders exactly the commands the server published",
        "an owner row renders whatever the server published for it",
        "a muted row renders the restore the server published",
        "a member with no viewer permission has no row action",
    ),
}


def check_v2_community_truth_contract(root: Path) -> list[str]:
    """Keep S3 navigation and governance visibility server-decided."""

    errors = require_fragments(
        root,
        {
            # `search` may only navigate by the server's destination kind: a
            # route assembled from display copy would be an invented fact.
            # `assetDetail` (backend decision 0071) is the one destination
            # that carries a parameter, and the token page is opened with
            # that `assetId` — never with the symbol printed on the row.
            "lib/features/community/search_screen.dart": (
                "switch (result.destination)",
                "case SearchCommunityProfileDestination():",
                "case SearchPublicProfileDestination():",
                "case SearchAssetDestination(:final assetId):",
                "widget.onOpenAsset?.call(assetId)",
                "PublicProfileIdentity.fromSearchSnapshot(",
            ),
            # Governance visibility is decided per row by the server and
            # rendered verbatim; the permission matrix is never re-implemented
            # on the client, and a viewer-level flag never becomes a row's
            # command.
            "lib/features/community/community_members_screen.dart": (
                "for (final action in entry.actions)",
                "showPublicProfileSheet<CommunityGovernanceAction>(",
                "confirmCommunityAction(",
            ),
            # The wire enum carries the server's own action names, so a row's
            # list cannot be reinterpreted on the way in.
            "lib/features/community/community_models.dart": (
                "enum CommunityGovernanceAction {",
                "promote('assignAdmin')",
                "demote('revokeAdmin')",
                "transfer('transferOwnership')",
                "final List<CommunityGovernanceAction> actions;",
            ),
            # Strict on the way in: an absent, unknown, repeated, or
            # malformed governance list is a contract break, never a
            # partially rendered one.
            "lib/integrations/backend/v2/loop_v2_projection_codec.dart": (
                "'actions',",
                "actions: governanceActions(item['actions']),",
                "CommunityGovernanceAction.tryParse(entry)",
            ),
            "lib/features/community/community_widgets.dart": (
                "Future<bool> confirmCommunityAction(",
            ),
        },
    )

    members = root / "lib/features/community/community_members_screen.dart"
    if members.is_file():
        source = strip_dart_comments(read_text(members))
        # A viewer-level flag carries no target. Mapping one onto a row is how
        # an admin came to be offered a mute and a ban against another admin
        # that the server's matrix had always refused, so no such flag and no
        # locally built command list may exist in this screen at all.
        for forbidden in (
            "canMute",
            "canInviteAdmin",
            "canGovern",
            "isActionable",
            "List<CommunityGovernanceAction> ",
        ):
            if forbidden in source:
                errors.append(
                    "community-members must not derive a row's governance "
                    f"commands on the client; found `{forbidden}`"
                )
        # `canBan` is viewer-level standing: it opens the banned segment and
        # decides nothing about a row.
        if source.count("canBan") > 1:
            errors.append(
                "community-members may read `canBan` only to open the banned "
                "segment, never to decide a row's commands"
            )
        start = source.find(
            "actions: <PublicProfileSheetAction<CommunityGovernanceAction>>["
        )
        end = source.find("\n      ],", start)
        if start < 0 or end < 0:
            errors.append(
                "community-members must build its sheet actions from one "
                "inspectable server-published list"
            )
        else:
            block = source[start:end]
            if "for (final action in entry.actions)" not in block:
                errors.append(
                    "community-members must render the server's per-row "
                    "`entry.actions` verbatim"
                )
            # Narrowing the published list would put a second, weaker copy of
            # the permission matrix back on the client.
            for forbidden in ("viewer", "if (", "role", "status"):
                if forbidden in block:
                    errors.append(
                        "community-members must not filter the server's "
                        f"per-row action list; found `{forbidden}`"
                    )

    search = root / "lib/features/community/search_screen.dart"
    if search.is_file():
        source = strip_dart_comments(read_text(search))
        for forbidden in ("result.title ==", "'/community/profile?id='", "Uri.parse("):
            if forbidden in source:
                errors.append(
                    "search must navigate only by `destination.kind`; found "
                    f"`{forbidden}`"
                )

    errors.extend(check_behavior_test_evidence(root, S3_COMMUNITY_TEST_MARKERS))
    return errors


COMMUNITY_AI_TEST_MARKERS = {
    Path("test/community_ai_test.dart"): (
        "the overview read carries no idempotency key and decodes whole",
        "a knowledge count the rows do not support is refused",
        "a quota refusal names the budget it was measured against",
        "the same question replays one key; a new question takes a new one",
        "the five states each render their own block",
        "the open page states its sources, brief and abilities",
        "a cited handle opens the source it names",
        "every answer can be reported once, by reason",
    ),
}

# The prototype's 「知识库 14 篇文档」 and its 42-message figure have no backend
# (loop-api decision 0066 §6): LOOP ingests no documents, so a document count
# is not a fact this client may render, and the discussion figure is the
# server's `brief.messageCount` or nothing at all.
COMMUNITY_AI_FORBIDDEN_COPY = ("知识库", "篇文档")


def check_community_ai_contract(root: Path) -> list[str]:
    """Keep Community AI on the server's own answers (decision 0066)."""

    errors = require_fragments(
        root,
        {
            # Strict on the way in: the three routes are decoded against the
            # frozen key sets, and the two writes carry the 429 the model
            # budgets answer with.
            "lib/integrations/backend/v2/community/loop_v2_community_ai_api.dart": (
                "'$communitiesPath/$id/ai/overview'",
                "'$communitiesPath/$id/ai/ask'",
                "'$communitiesPath/$id/ai/answers/$answer/report'",
                "allowedCodes: LoopV2ModuleRequest.communityAiWriteErrors,",
                "if (sourceCount != sources.length) LoopV2ProjectionCodec.invalid();",
                "if (answer.isEmpty && refusal == null) LoopV2ProjectionCodec.invalid();",
            ),
            # One question is one logical operation: the key is bound to the
            # question's own text, so an identical retry replays the stored
            # answer instead of spending a second model call.
            "lib/integrations/backend/v2/community/dio_loop_v2_community_ai_gateway.dart": (
                "'community-ai-ask:$communityId:${question.trim()}'",
                "if (!communityOutcomeIsUnresolved(failure.kind)) {",
            ),
            # Every model-written block carries the model and the time, every
            # answer can be reported, and the disclaimer never leaves the foot
            # of the page.
            "lib/features/community/community_ai_screen.dart": (
                "_CommunityAiGeneratedMark(",
                "'community-ai-report-${answer.answerId}'",
                "showCommunityAiReportSheet(",
                "communityAiKnowledgeLine(overview.knowledge)",
                "_CommunityAiDisclaimer(",
            ),
            "lib/features/community/community_ai_models.dart": (
                "String communityAiBriefHeading(CommunityAiBriefAvailable brief)",
                "'今日至少 ${brief.messageCount} 条讨论'",
                "List<CommunityAiAnswerRun> communityAiAnswerRuns(",
            ),
            # A Preview composition must not answer for a model: decision 0066
            # forbids a sentence no model wrote.
            "lib/features/community/community_ai_gateway.dart": (
                "final class UnavailableCommunityAiGateway implements CommunityAiGateway",
            ),
        },
    )

    for relative in (
        "lib/features/community/community_ai_screen.dart",
        "lib/features/community/community_ai_models.dart",
    ):
        path = root / relative
        if not path.is_file():
            continue
        source = strip_dart_comments(read_text(path))
        for forbidden in COMMUNITY_AI_FORBIDDEN_COPY:
            if forbidden in source:
                errors.append(
                    f"{relative} must not publish a document count for "
                    f"Community AI; found `{forbidden}`"
                )

    preview = root / "lib/main_preview.dart"
    if preview.is_file() and "communityAiGatewayProvider" in read_text(preview):
        errors.append(
            "main_preview.dart must leave Community AI closed: a Preview "
            "answer is a sentence no model wrote"
        )

    errors.extend(check_behavior_test_evidence(root, COMMUNITY_AI_TEST_MARKERS))
    return errors


COMMUNITY_LOGO_CALL_SITES = (
    # The Community home's joined list — the one surface that already drew a
    # preset, and the only one, which is what the device reported.
    "lib/features/community/community_screen.dart",
    # Discovery and the community record's identity row share one row builder.
    "lib/features/community/community_widgets.dart",
    # The community record folio.
    "lib/features/community/community_profile_screen.dart",
    # The member directory folio: every row on that page is a person, so the
    # community's own face is the only thing that says whose directory it is.
    "lib/features/community/community_members_screen.dart",
    # Global search results.
    "lib/features/community/search_screen.dart",
    # Forward targets: a community's official channel is that community.
    "lib/features/chat/v2/chat_forward_screens.dart",
    # The mining community board and one community's mining panel.
    "lib/features/mining/mining_secondary_screens.dart",
)

COMMUNITY_LOGO_TEST_MARKERS = {
    Path("test/community_logo_test.dart"): (
        "01..12 each resolve to their own atlas cell",
        "every published preset draws its image, not initials",
        "a community with no preset draws its own initials",
        "one id always gets one ground, whatever its name becomes",
        "no ground is one of the surfaces the tile lands on",
        "every ground clears 4.5:1 between its letters and its fill",
        "home, discovery, the record and the member directory agree",
    ),
}


def _lossy_webp_size(data: bytes) -> tuple[int, int]:
    """Width and height of a simple lossy (`VP8 `) WebP."""

    if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError("not a RIFF/WEBP container")
    if data[12:16] != b"VP8 ":
        raise ValueError(f"unsupported WebP chunk {data[12:16]!r}")
    if data[23:26] != b"\x9d\x01\x2a":
        raise ValueError("missing VP8 key-frame sync code")
    width, height = struct.unpack("<HH", data[26:30])
    return width & 0x3FFF, height & 0x3FFF


def check_community_identity_contract(root: Path) -> list[str]:
    """One community, one face, on every page that names it.

    A community arrives with `avatar:preset/community-01..12`. The frozen
    prototype drew four of those twelve, and only the Community home drew even
    those: every other surface rendered initials, so on the device no community
    icon was visible anywhere (report 2026-09-21). The atlas now carries all
    twelve cells and one widget draws all of them, which is what this check
    holds in place.
    """

    errors = require_fragments(
        root,
        {
            # The grid and the twelve cells are one fact: a 4x3 declaration
            # with eight cells missing would silently crop the wrong image.
            "lib/core/assets/loop_assets.dart": (
                "communities(LoopAssetPaths.communities, columns: 4, rows: 3)",
                *(f"'community-{slot:02d}': LoopIdentitySlot(" for slot in range(5, 13)),
            ),
            "lib/features/community/community_logo.dart": (
                "class CommunityLogo extends StatelessWidget",
                "const int communityLogoPresetCount = 12;",
                "String? communityLogoSlotFor(String? logoRef)",
                "int communityLogoHash(String identity)",
                "CommunityLogoGround communityLogoGroundFor(String identity)",
            ),
            **{
                relative: ("CommunityLogo(",)
                for relative in COMMUNITY_LOGO_CALL_SITES
            },
        },
    )

    atlas = root / "assets/communities/loop-community-atlas.webp"
    if not atlas.is_file():
        errors.append(f"{atlas.relative_to(root)} is missing")
    else:
        try:
            width, height = _lossy_webp_size(atlas.read_bytes())
        except (ValueError, struct.error) as error:
            errors.append(f"{atlas.relative_to(root)} could not be read: {error}")
        else:
            # Twelve square cells. The crop is computed from the grid at render
            # time, so a sheet with a different aspect hands every community a
            # slice of two marks.
            if width % 4 or height % 3 or width // 4 != height // 3:
                errors.append(
                    f"{atlas.relative_to(root)} must be a 4x3 grid of square "
                    f"cells for the twelve community presets, got {width}x{height}"
                )

    logo = root / "lib/features/community/community_logo.dart"
    if logo.is_file():
        source = read_text(logo)
        executable = strip_dart_comments(source)
        # Six grounds, and each one names the colour it is mixed from rather
        # than introducing a hue the palette does not have.
        grounds = re.findall(r"CommunityLogoGround\(\s*id: '([a-z-]+)'", executable)
        if len(grounds) != 6 or len(set(grounds)) != 6:
            errors.append(
                "community_logo must offer exactly six distinct monogram "
                f"grounds; found {grounds}"
            )
        # `String.hashCode` is not a published value: a face derived from it
        # could differ between two runs of the same build.
        if ".hashCode" in executable:
            errors.append(
                "a community's ground must come from the stable FNV hash, "
                "never from `String.hashCode`"
            )
        if "assets/communities/src" not in source:
            errors.append(
                "community_logo must record where the eight badge sources live"
            )

    # The two widgets this one replaced drew initials for every community on
    # every page but one. Neither may come back.
    features = root / "lib/features"
    for path in sorted(features.rglob("*.dart")):
        text = strip_dart_comments(read_text(path))
        for retired in ("CommunityLogoTile", "CommunityLogoAvatar"):
            if retired in text:
                errors.append(
                    f"{path.relative_to(root)} still draws `{retired}`; every "
                    "community identity goes through `CommunityLogo`"
                )

    errors.extend(check_behavior_test_evidence(root, COMMUNITY_LOGO_TEST_MARKERS))
    return errors


def check_v2_primary_navigation_contract(root: Path) -> list[str]:
    """Lock the runtime V2 shell without pretending the legacy catalog is migrated."""

    errors: list[str] = []
    normalized_contracts = {
        "docs/decisions/0048-adopt-v2-five-destination-ui-foundation.md": (
            "Community, Mining, Launch, Market and Wallet",
            "`/home` and `/launchpad` only as",
            "103-surface catalog as legacy migration inventory",
            "reviewed backend V2 roadmap maps Pay to D21",
            "Do not call, mock or pre-empt the backend D0/D1 `/v2` contract",
        ),
        "docs/product-decisions.md": (
            "Community,\n  Mining, Launch, Market and Wallet",
            "`/home` and `/launchpad` are compatibility redirects",
        ),
        "docs/product/implementation-constraints.md": (
            "Community, Mining, Launch, Market and Wallet",
            "`/home` and `/launchpad` are compatibility redirects only",
        ),
        "lib/features/community/community_screen.dart": (
            "class CommunityScreen",
            "'/chat'",
            "'/profile'",
        ),
        # The page states the formula is unapproved in the user's words; the
        # backend step id it used to cite is banned copy (decision 0070).
        "lib/features/mining/mining_screen.dart": (
            "class MiningScreen",
            "挖矿公式还没有批准的版本",
        ),
        # Step 5 moved the Wallet destination to the V2 read-only screens. The
        # prototype's four funds-action entries stay in place and each opens
        # its own manifest slug; every destination owns its unavailable state
        # (ruling of 2026-09-08), so this page never speaks for four others.
        "lib/features/wallet/wallet_read_screens.dart": (
            "ValueKey<String>('wallet-pay-entry')",
            "ValueKey<String>('wallet-swap-entry')",
            "ValueKey<String>('wallet-send-entry')",
            "ValueKey<String>('wallet-bridge-entry')",
        ),
    }
    for relative, fragments in normalized_contracts.items():
        path = root / relative
        if not path.is_file():
            errors.append(f"missing compatibility contract file: {relative}")
            continue
        contract_source = read_text(path)
        if path.suffix == ".dart":
            contract_source = strip_dart_comments(contract_source)
        normalized = " ".join(contract_source.split())
        for fragment in fragments:
            if " ".join(fragment.split()) not in normalized:
                errors.append(f"{relative} is missing locked V2 contract `{fragment}`")

    shell_path = root / "lib/features/shell/loop_shell.dart"
    if shell_path.is_file():
        source = strip_dart_comments(read_text(shell_path))
        start = source.find("static const _destinations")
        end = source.find("  ];", start)
        if start < 0 or end < 0:
            errors.append("LoopShell must retain one inspectable destination list")
        else:
            block = source[start:end]
            markers = (
                ("'社区'", "'/community'"),
                ("'挖矿'", "'/mining'"),
                ("'Launch'", "'/launch'"),
                ("'行情'", "'/market'"),
                ("'钱包'", "'/wallet'"),
            )
            positions: list[int] = []
            for label, path in markers:
                label_at = block.find(label)
                path_at = block.find(path, label_at)
                if label_at < 0 or path_at < 0:
                    errors.append(
                        f"LoopShell must retain the V2 destination {label} at {path}"
                    )
                else:
                    positions.append(label_at)
            if len(positions) == len(markers) and positions != sorted(positions):
                errors.append("LoopShell V2 destinations must retain their reviewed order")
            for forbidden in (
                "'Home'",
                "'Chat'",
                "'Profile'",
                "'首页'",
                "'聊天'",
                "'/launchpad'",
            ):
                if forbidden in block:
                    errors.append(
                        "LoopShell must not restore the retired primary destination "
                        f"{forbidden}"
                    )
            if block.count("_LoopDestination(") != 5:
                errors.append("LoopShell must expose exactly five primary destinations")
        if "ChatMiniVoiceBar" in source:
            errors.append(
                "LoopShell must not present an idle Audio Room bar across every V2 tab"
            )

    app_path = root / "lib/app.dart"
    if app_path.is_file():
        source = strip_dart_comments(read_text(app_path))
        compact_source = re.sub(r"\s+", " ", source).strip()
        shell_start = compact_source.find("ShellRoute(")
        first_root_after_shell = re.search(
            r"GoRoute\s*\(\s*path\s*:\s*'/home'",
            compact_source[shell_start + 1 :] if shell_start >= 0 else "",
        )
        shell_end = (
            shell_start + 1 + first_root_after_shell.start()
            if shell_start >= 0 and first_root_after_shell is not None
            else -1
        )
        if shell_start < 0 or shell_end < 0:
            errors.append("lib/app.dart must retain an inspectable V2 ShellRoute")
        else:
            shell = compact_source[shell_start:shell_end]
            for path in ("/community", "/mining", "/launch", "/market", "/wallet"):
                if re.search(rf"path\s*:\s*'{re.escape(path)}'", shell) is None:
                    errors.append(f"V2 ShellRoute must own `{path}`")
            for path in ("/home", "/launchpad", "/chat", "/profile"):
                if re.search(rf"path\s*:\s*'{re.escape(path)}'", shell) is not None:
                    errors.append(f"V2 ShellRoute must not own legacy child `{path}`")

        def has_direct_redirect(path: str, destination: str) -> bool:
            # A redirect body may record the routing error first, but it must
            # end by returning exactly the reviewed destination.
            return (
                re.search(
                    rf"GoRoute\s*\(\s*path\s*:\s*'{re.escape(path)}'\s*,\s*"
                    rf"redirect\s*:\s*\([^)]*\)\s*"
                    rf"(?:=>\s*'{re.escape(destination)}'|"
                    rf"\{{\s*(?:routingErrors\.record\([^;]*\);\s*)?"
                    rf"return\s*'{re.escape(destination)}'\s*;\s*\}})"
                    rf"\s*,?\s*\)",
                    compact_source,
                    flags=re.DOTALL,
                )
                is not None
            )
        unmatched = re.search(
            r"GoRoute\s*\(\s*path\s*:\s*'/:unmatched\(\.\*\)'\s*,\s*redirect\s*:\s*"
            r"\([^)]*\)\s*\{\s*routingErrors\.record\(state\.uri\.toString\(\)\);",
            compact_source,
        )
        if unmatched is None:
            errors.append(
                "unmatched locations must be recorded in LoopRoutingErrorLog before "
                "returning to Community"
            )

        # Decision 0053: `auth-otp` became a real credential route, so the
        # gate names the credential set explicitly.
        #
        # F1 (device report 2026-09-21): a verified session used to leave the
        # credential pages for Community before `GET /v2/profile` had said
        # whether the account was active, so a pending account saw one
        # Community frame and was then pulled into step 02. The gate now
        # holds every verified session on the launch page until the profile
        # answers, and hands it over to the step the account is actually on
        # — never through Community.
        if re.search(
            r"if\s*\(\s*loopPostAuthHoldsAtLaunch\(\s*session\s*:\s*session\s*,"
            r"\s*landing\s*:\s*readProfileLanding\(\)\s*,?\s*\)\s*\)\s*\{\s*"
            r"return\s*location\s*==\s*'/splash'\s*\?\s*null\s*:\s*'/splash'\s*;",
            compact_source,
        ) is None:
            errors.append(
                "a verified session must wait on the launch page until "
                "`GET /v2/profile` answers"
            )
        if re.search(
            r"if\s*\(\s*credentialRoutes\.contains\(location\)\s*\|\|\s*"
            r"location\s*==\s*'/splash'\s*\)\s*\{\s*"
            r"final\s+step\s*=\s*readOnboarding\(\)\.step\s*;\s*"
            r"return\s+step\s*==\s*null\s*\?\s*'/community'\s*:\s*"
            r"LoopRouteManifest\.pathFor\(step\.slug\)\s*;",
            compact_source,
        ) is None:
            errors.append(
                "a decided landing must hand the credential and launch pages "
                "to the account's own step, or to Community"
            )
        credential_routes = re.search(
            r"const\s+credentialRoutes\s*=\s*<String>\{([^}]*)\}", compact_source
        )
        if credential_routes is None or sorted(
            value.strip().strip("'")
            for value in credential_routes.group(1).split(",")
            if value.strip()
        ) != ["/auth", "/auth/otp"]:
            errors.append(
                "the authenticated gate must cover exactly the two credential "
                "routes `/auth` and `/auth/otp`"
            )
        signed_out_routes = re.search(
            r"const\s+signedOutRoutes\s*=\s*<String>\{([^}]*)\}", compact_source
        )
        if signed_out_routes is None or sorted(
            value.strip().strip("'")
            for value in signed_out_routes.group(1).split(",")
            if value.strip()
        ) != ["/auth", "/auth/otp", "/auth/wallet", "/splash"]:
            errors.append(
                "signed-out sessions may reach only the reviewed pre-login "
                "locations"
            )
        for path, destination in (
            ("/", "/community"),
            ("/home", "/community"),
            ("/launchpad", "/launch"),
            ("/:unmatched(.*)", "/community"),
        ):
            if not has_direct_redirect(path, destination):
                errors.append(
                    f"V2 app routes must redirect `{path}` to `{destination}`"
                )
        for path in ("/chat", "/profile"):
            if re.search(rf"path\s*:\s*'{re.escape(path)}'", compact_source) is None:
                errors.append(f"V2 app routes must retain child route `{path}`")

        profile_start = source.find("Widget _profileScreen(")
        profile_end = source.find("String _accountPath(", profile_start)
        profile_slice = source[
            profile_start : profile_end if profile_end >= 0 else len(source)
        ]
        # Decision 0053: the Profile root's back control is the shared topbar
        # button supplied through `onBack`; the fallback destination is still
        # Community and still direct-link safe.
        profile_fallback_fragments = (
            "onBack: back,",
            "Navigator.of(context).canPop()",
            "context.pop();",
            "context.go(LoopRouteManifest.defaultPath);",
        )
        if profile_start < 0 or profile_end < 0 or any(
            fragment not in profile_slice
            for fragment in profile_fallback_fragments
        ):
            errors.append(
                "Profile root must expose a direct-link fallback that returns to Community"
            )

    chat_path = root / "lib/features/chat/stream_chat_inbox_page.dart"
    if chat_path.is_file():
        source = strip_dart_comments(read_text(chat_path))
        chat_start = source.find("class StreamChatInboxPage")
        chat_end = source.find("class StreamChatChannelRoutePage", chat_start)
        chat_slice = source[
            chat_start : chat_end if chat_end >= 0 else len(source)
        ]
        chat_fallback_fragments = (
            "ValueKey<String>('stream-chat-back-to-community')",
            "Navigator.of(context).canPop()",
            "context.pop();",
            "context.go('/community');",
        )
        if chat_start < 0 or chat_end < 0 or any(
            fragment not in chat_slice for fragment in chat_fallback_fragments
        ):
            errors.append(
                "Chat root must expose a direct-link fallback that returns to Community"
            )
    else:
        errors.append(
            "missing compatibility contract file: lib/features/chat/stream_chat_inbox_page.dart"
        )

    manifest_path = root / "lib/core/navigation/route_manifest.dart"
    if manifest_path.is_file():
        source = strip_dart_comments(read_text(manifest_path))
        start = source.find("static const List<String> tabSlugs")
        end = source.find("];", start)
        if start < 0 or end < 0:
            errors.append("LoopRouteManifest must expose runtime tabSlugs")
        else:
            block = source[start:end]
            expected = ["community", "mining", "launch", "market", "wallet"]
            positions = [block.find(f"'{slug}'") for slug in expected]
            if any(position < 0 for position in positions):
                errors.append("LoopRouteManifest tabSlugs must contain all five V2 slugs")
            elif positions != sorted(positions):
                errors.append("LoopRouteManifest tabSlugs must retain V2 order")
            for retired in ("home", "launchpad", "chat", "profile"):
                if f"'{retired}'" in block:
                    errors.append(
                        f"LoopRouteManifest tabSlugs must not retain `{retired}`"
                    )

    return errors


def check_chat_attachment_contract(root: Path) -> list[str]:
    """Keep preview conversations out of production and token cards fail-closed."""

    errors = require_fragments(
        root,
        {
            "lib/app.dart": (
                "LoopStreamTokenCardAttachmentBuilder()",
                "LoopStreamTokenCardMessagePreviewFormatter()",
                "configData: loopStreamChatConfiguration",
            ),
            "lib/features/chat/chat_preview_route_guard.dart": (
                "gateway.mode == CommunicationMode.preview",
                "chat-preview-route-blocked",
                "Offline preview only",
            ),
            "lib/features/chat/attachments/token_card_attachment.dart": (
                "static const String attachmentType = 'token_card';",
                "static const String schema = 'token_card.v1';",
                "extraData.length != extraDataKeys.length",
                "!extraData.keys.every(extraDataKeys.contains)",
            ),
            "lib/features/chat/attachments/stream_token_card_attachment_builder.dart": (
                "extends StreamAttachmentWidgetBuilder",
                "LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard",
                "LoopStreamTokenCardAttachmentPolicy.tryParse",
                "LoopTokenCardViewState.unavailable",
                "LoopTokenCardViewState.malformed",
                "This builder performs no network request",
            ),
            "lib/features/chat/attachments/stream_token_card_attachment_policy.dart": (
                "attachment.rawType == LoopTokenCardAttachment.attachmentType",
                "_hasIdentifierOnlyTopLevelFields",
                "materialized.length != 1",
            ),
            "lib/features/chat/attachments/stream_token_card_message_preview_formatter.dart": (
                "extends StreamMessagePreviewFormatter",
                "LoopStreamTokenCardAttachmentPolicy.containsRawTokenCard",
                "unsupportedTokenCardLabel",
                "formatMessageSemanticsLabel",
                "formatDraftMessageSemanticsLabel",
            ),
            "lib/features/chat/widgets/token_card_view.dart": (
                "Current facts unavailable",
                "The message stores identifiers only",
                "开发预览",
            ),
            "test/stream_token_card_attachment_builder_test.dart": (
                "official Stream message renderer uses the configured builder",
                "raw token card cannot escape into the default link renderer",
                "find.byType(StreamLinkPreviewAttachment), findsNothing",
                "find.text('Buy'), findsNothing",
            ),
            "test/stream_token_card_message_preview_formatter_test.dart": (
                "compact Stream preview hides malicious token-card fields",
                "draft preview also strips token-card attachment fields",
                "find.textContaining('attacker.example'), findsNothing",
            ),
        },
    )

    app_path = root / "lib/app.dart"
    if app_path.is_file():
        app_text = strip_dart_comments(read_text(app_path))
        for route in CHAT_PREVIEW_ONLY_ROUTES:
            route_marker = f"path: '{route}'"
            starts = [match.start() for match in re.finditer(re.escape(route_marker), app_text)]
            if not starts:
                errors.append(f"lib/app.dart must preserve preview-only route `{route}`")
                continue
            if len(starts) != 1:
                errors.append(
                    f"lib/app.dart preview-only route `{route}` must be declared exactly once"
                )
                continue
            start = starts[0]
            next_route = app_text.find("GoRoute(", start + len(route_marker))
            route_block = app_text[start : next_route if next_route >= 0 else len(app_text)]
            first_builder = re.search(r"\bbuilder\s*:", route_block)
            tail = route_block[first_builder.start() :] if first_builder else ""
            # Step 4 gave each of these slugs a V2 production surface. The
            # Preview branch of `_chatSurface` still owns the fixture page and
            # must stay behind the guard; `/chat/voice` has no fixture guard
            # because its Preview page is itself the labelled lobby.
            guarded_builder = re.match(
                r"builder\s*:\s*\([^)]*\)\s*=>\s*(?:const\s+)?"
                r"(?:ChatPreviewRouteGuard|_chatSurface)\s*\(",
                tail,
            )
            if guarded_builder is None or (
                "_chatSurface(" in tail
                and "ChatPreviewRouteGuard(" not in tail
            ):
                errors.append(
                    f"lib/app.dart preview-only route `{route}` must be wrapped by ChatPreviewRouteGuard"
                )

    model_path = root / "lib/features/chat/attachments/token_card_attachment.dart"
    if model_path.is_file():
        model_text = read_text(model_path)
        match = re.search(
            r"static const Set<String> extraDataKeys\s*=\s*<String>\{(?P<body>.*?)\};",
            model_text,
            re.DOTALL,
        )
        if match is None:
            errors.append("token_card.v1 must declare a static exact extraDataKeys set")
        else:
            actual_keys = frozenset(re.findall(r"'([^']+)'", match.group("body")))
            if actual_keys != TOKEN_CARD_EXTRA_DATA_KEYS:
                errors.append(
                    "token_card.v1 extraDataKeys must be exactly identifier-only: "
                    f"expected {sorted(TOKEN_CARD_EXTRA_DATA_KEYS)}, found {sorted(actual_keys)}"
                )
            residual = re.sub(r"'[^']+'", "", match.group("body"))
            if re.sub(r"[\s,]", "", residual):
                errors.append(
                    "token_card.v1 extraDataKeys must contain only the five literal keys; "
                    "spreads and computed entries are forbidden"
                )

    for relative, allowed_imports in TOKEN_CARD_RENDER_IMPORTS.items():
        render_path = root / relative
        if not render_path.is_file():
            continue
        render_text = read_text(render_path)
        executable_text = strip_dart_comments(render_text)
        directives = tuple(
            re.finditer(
                r"^\s*(?P<kind>import|export|part)\b(?P<body>.*?);",
                executable_text,
                re.MULTILINE | re.DOTALL,
            )
        )
        actual_imports: list[str] = []
        invalid_directives: list[str] = []
        for directive in directives:
            body = " ".join(directive.group("body").split())
            if directive.group("kind") != "import":
                invalid_directives.append(directive.group(0).strip())
                continue
            actual_imports.append(body)
        actual_import_set = frozenset(actual_imports)
        if (
            invalid_directives
            or len(actual_imports) != len(actual_import_set)
            or actual_import_set != allowed_imports
        ):
            errors.append(
                f"{relative} imports must stay on the reviewed synchronous allowlist: "
                f"expected {sorted(allowed_imports)}, found {sorted(actual_imports)}"
            )
        forbidden_builder_fragments = (
            "Future<",
            " async",
            "await ",
            "Dio",
            "package:http",
            "dart:io",
            "HttpClient",
            "StreamMessageListView",
            "StreamChat.",
            "StreamChatCore",
            "StreamChatClient",
            "StreamChannel.",
            ".client",
            "getMessage(",
            "queryChannels(",
            "Image.network(",
            "NetworkImage",
            "FadeInImage",
            "NetworkAssetBundle",
        )
        for fragment in forbidden_builder_fragments:
            if fragment in executable_text:
                errors.append(
                    "Stream token-card rendering must stay synchronous and must not create a "
                    f"second message/network source in {render_path.relative_to(root)} (`{fragment}`)"
                )
    return errors


def check_production_chat_audio_room_entry(root: Path) -> list[str]:
    """Keep every Audio Room a community resource with a server-owned locator.

    Step 4 replaced decision 0024's generic inbox entry: a room now belongs to
    one community, so the lobby is reached from a community record and the
    inbox must not offer a locator it does not have. Decision 0005's provider
    evidence still closes the whole page while it is pending.
    """

    errors = require_fragments(
        root,
        {
            "lib/features/chat/stream_chat_inbox_page.dart": (
                "class StreamChatInboxPage extends ConsumerWidget",
                "const ChatCreateMenuButton()",
            ),
            "lib/features/chat/voice_room_page.dart": (
                "gateway.mode == CommunicationMode.production",
                "return const StreamVoiceRoomPage();",
            ),
            "lib/features/chat/v2/voice_room_screens.dart": (
                "capability.evidencePending",
                "voiceroom-evidence-pending",
                "AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING",
                # The authorized room is handed straight to the reviewed lobby,
                # so no scoped provider can resolve to the fail-closed default.
                "child: StreamVoiceRoomPage(",
                "target: target,",
                "inline: true,",
                # Joining a voice room is one decision: the LOOP grant and the
                # connection it authorizes belong to the same command, and so
                # do the disconnect and the leave that end them.
                "autoConnect: true,",
                "onExitRequested: onExitRequested,",
                "await _mediaLink.disconnect()",
                # Decision 0052 gives the page the roster the room resource
                # never carried, so the row commands are the server's own list
                # and a row it published none for opens nothing. 移出发言 lives
                # on a speaker row now; it is no longer declared unavailable.
                "voiceroom-member-command-",
                "member.commands.isEmpty",
            ),
            "test/stream_chat_inbox_page_test.dart": (
                "the generic Chat inbox no longer offers an Audio Room without a community",
                "find.text('ETH Macro Room'), findsNothing",
                "find.text('Connected'), findsNothing",
            ),
            # S77d: the two views follow `#scr-voiceroom` and
            # `#scr-voiceroom-full`. The table of five figures is gone from
            # both, every figure counts the host, and the host's exit is a
            # control rather than a paragraph about a control that is not
            # there.
            "test/s77d_voice_room_prototype_test.dart": (
                "the host is counted as one of the people who may be heard",
                "the table of figures and the repeated notes are gone",
                "the host is given 结束房间, not a paragraph about 离开",
                "an ended room says so in words, and asks nothing",
                "a community with no live room says so in both places",
                "the host gets the speakers, the queue and the controls",
                "a listener sees the room and none of the host controls",
                "a room whose only voice is the host is not an empty list",
            ),
            "test/communication_pages_test.dart": (
                "a pending role evidence closes the whole page",
                "a listener sees no host control",
                "a host sees the host controls and the queue",
                "a host sees exactly the commands the server sent per row",
                "a plain member gets no row command at all",
                "an empty roster is not the same state as an unreadable one",
                "an unobserved participant count is never printed as 0",
                "joining the room is the same step as hearing it",
                "a failed connection keeps the membership and offers it back",
                "leaving drops the audio before it releases the membership",
            ),
            "docs/decisions/0024-expose-production-audio-room-from-chat.md": (
                "The entry performs no provider operation",
                "No authorized room assigned",
            ),
        },
    )

    inbox_path = root / "lib/features/chat/stream_chat_inbox_page.dart"
    if inbox_path.is_file():
        inbox = strip_dart_comments(read_text(inbox_path))
        if "'stream-audio-room-entry'" in inbox:
            errors.append(
                "the generic Chat inbox must not offer an Audio Room entry without a community"
            )

    errors.extend(
        check_behavior_test_evidence(
            root,
            {
                Path("test/stream_chat_inbox_page_test.dart"): (
                    "the generic Chat inbox no longer offers an Audio Room without a community",
                ),
                Path("test/communication_pages_test.dart"): (
                    "a pending role evidence closes the whole page",
                    "a listener sees no host control",
                    "a host sees the host controls and the queue",
                ),
                Path("test/s77d_voice_room_prototype_test.dart"): (
                    "the table of figures and the repeated notes are gone",
                    "the host gets the speakers, the queue and the controls",
                ),
            },
        )
    )
    return errors

TYPOGRAPHY_GUARDED_TREES = ("lib/features", "lib/widgets")
TYPOGRAPHY_GUARD_ALLOWLIST = (
    "lib/core/theme/loop_theme.dart",
    "lib/integrations/communication/stream_chat_appearance.dart",
)
TYPOGRAPHY_FORBIDDEN_LITERALS = {
    "fontSize:": "a size belongs to a band step in LoopType / LoopTypography",
    "fontWeight:": (
        "a weight belongs to a band; restate one with "
        "LoopTypography.withWeight so the variable Sora axis moves too"
    ),
    "fontFamily:": (
        "a family belongs to LoopFonts; a page never names Sora, "
        "IBM Plex Mono, Noto Sans SC or 'monospace' itself"
    ),
}


def check_typography_band_contract(root: Path) -> list[str]:
    """Keep every page on the seven type bands (decision 0069).

    The prototype's Latin voice (Sora) has no CJK coverage and the bundled
    Noto Sans SC statics are matched by weight, so a hand-written `fontSize`
    or `fontWeight` produces a 中英 line whose two halves disagree. Sizes,
    weights and families therefore live only in `LoopTypography` / `LoopType`.
    """

    errors: list[str] = []
    for tree in TYPOGRAPHY_GUARDED_TREES:
        tree_root = root / tree
        if not tree_root.is_dir():
            continue
        for path in sorted(tree_root.rglob("*.dart")):
            relative = path.relative_to(root)
            if relative.as_posix() in TYPOGRAPHY_GUARD_ALLOWLIST:
                continue
            executable = strip_dart_comments(read_text(path))
            for literal, reason in TYPOGRAPHY_FORBIDDEN_LITERALS.items():
                if literal in executable:
                    errors.append(
                        f"{relative} hand-writes `{literal}`: {reason}"
                    )

    # The bundled font files and their licences have to stay registered, or
    # every Han glyph silently falls back to whatever the device installs.
    fonts_dir = root / "assets" / "fonts"
    pubspec = read_text(root / "pubspec.yaml") if (root / "pubspec.yaml").is_file() else ""
    for asset in (
        "NotoSansSC-Regular.ttf",
        "NotoSansSC-Medium.ttf",
        "NotoSansSC-Bold.ttf",
        "OFL-NotoSansSC.txt",
    ):
        if not (fonts_dir / asset).is_file():
            errors.append(f"assets/fonts/{asset} is missing; CJK text has no bundled face")
        elif asset.endswith(".ttf") and f"assets/fonts/{asset}" not in pubspec:
            errors.append(f"assets/fonts/{asset} is not registered in pubspec.yaml")
    if "family: Noto Sans SC" not in pubspec:
        errors.append("pubspec.yaml does not declare the `Noto Sans SC` family")
    return errors


# ---------------------------------------------------------------------------
# Light grounds (S16e) — a colour is only wrong relative to what is under it
# ---------------------------------------------------------------------------

# Every soft token in `LoopColors` is the Chalk hue with its alpha turned down,
# because the palette is authored for the Ink page. Painted on a Chalk card or
# a Lime folio they are Chalk on Chalk: the widget still lays out, still takes
# its 200px, and is simply not there. Nothing in the code reads wrong and no
# test that only renders the Ink page can see it, so the rule is held here.
DARK_GROUND_ONLY_TOKENS: dict[str, str] = {
    "LoopColors.bg2": "Chalk at 2.5%",
    "LoopColors.panel": "Chalk at 5.5%",
    "LoopColors.card2": "Chalk at 10%",
    "LoopColors.card": "Chalk at 6%",
    "LoopColors.line2": "Chalk at 22%",
    "LoopColors.line": "Chalk at 13%",
    "LoopColors.text2": "Chalk at 68%",
    "LoopColors.text3": "Chalk at 58%",
    "LoopColors.textSecondary": "Chalk at 68%",
    "LoopColors.textTertiary": "Chalk at 58%",
    "LoopDepth.liftPrimaryEdge": "Chalk at 10%",
    "LoopDepth.liftCardEdge": "Chalk at 5.5%",
    "LoopDepth.innerEdge": "Chalk at 4%",
}

# The containers that paint an opaque light fill and then hand a slot to
# somebody else's widget. Each one has to declare the ground it paints, or the
# guest reads the page's Chalk and `LoopGround` derives the wrong ink.
LIGHT_GROUND_CONTAINERS: dict[str, tuple[str, ...]] = {
    "LoopChalkCard": ("child",),
    "LoopLedgerCard": ("child",),
    "LoopFolioPrimary": ("trailing",),
    "LoopTokenCard": (),
}

# A widget slot is a `Widget` the caller supplies; a class that paints a light
# fill and owns one of these is a light ground whether or not it was thought of
# as one.
_WIDGET_SLOT_FIELD = re.compile(r"\bfinal\s+(?:List<Widget>|Widget)\??\s+\w+\s*;")
_OPAQUE_LIGHT_FILL = re.compile(
    r"(?:color|backgroundColor|fillColor)\s*:\s*(?:const\s+)?"
    r"LoopColors\.(?:chalk|lime|limeHighlight)\b(?!\s*\.withValues)"
)
_LIGHT_GROUND_EXEMPT_CLASSES = frozenset(
    {
        # The tab bar paints Chalk but builds every cell itself, naming both
        # Ink weights; it takes no widget from a caller.
        "LoopTabBar",
        # The toast is its own content: one glyph and one line, both Ink.
        "LoopToastView",
        # The record row's Lime is `.row-choice.is-chosen::before`: a 3px
        # selection edge down the leading side of the row. It carries nothing
        # — the caller's `leading` and the row's own text sit beside it on the
        # dark row fill — so it is a mark, not a ground.
        "LoopRecordRow",
    }
)


def _dart_match_bracket(source: str, start: int) -> int:
    """Index just past the bracket opened at [start]."""

    depth = 0
    index = start
    while index < len(source):
        if source[index] in "([{":
            depth += 1
        elif source[index] in ")]}":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return len(source)


def _dart_named_argument_spans(
    source: str, open_paren: int, close: int, name: str
) -> list[tuple[int, int]]:
    """Spans of every `name:` value at the top level of one call."""

    spans: list[tuple[int, int]] = []
    depth = 0
    index = open_paren
    prefix = f"{name}:"
    while index < close:
        character = source[index]
        if character in "([{":
            depth += 1
        elif character in ")]}":
            depth -= 1
        elif (
            depth == 1
            and source.startswith(prefix, index)
            and not (source[index - 1].isalnum() or source[index - 1] == "_")
        ):
            value = index + len(prefix)
            end = value
            inner = 0
            while end < close:
                if source[end] in "([{":
                    inner += 1
                elif source[end] in ")]}":
                    if inner == 0:
                        break
                    inner -= 1
                elif source[end] == "," and inner == 0:
                    break
                end += 1
            spans.append((value, end))
        index += 1
    return spans


def _dart_class_spans(source: str) -> list[tuple[str, int, int]]:
    """`(name, start, end)` for every class body in one file."""

    spans: list[tuple[str, int, int]] = []
    for match in re.finditer(r"\bclass\s+(_?\w+)", source):
        brace = source.find("{", match.end())
        if brace < 0:
            continue
        spans.append((match.group(1), match.start(), _dart_match_bracket(source, brace)))
    return spans


def check_light_ground_contract(root: Path) -> list[str]:
    """Keep a dark-ground colour off a light ground (S16d/S16e).

    Three rules, because the failure has three doors:

    1. every registered light container declares its ground with a
       `DefaultTextStyle` and an `IconTheme`, which is what makes `LoopGround`
       derive the right ink for whatever it was handed;
    2. no class paints an opaque Chalk/Lime fill, own a widget slot and stay
       off the register, so a new light card cannot arrive unnoticed;
    3. no dark-ground-only token is named inside a light container's slot.
    """

    errors: list[str] = []
    lib = root / "lib"
    if not lib.is_dir():
        return errors

    sources: dict[Path, str] = {}
    for path in sorted(lib.rglob("*.dart")):
        if path.relative_to(root).as_posix().startswith("lib/integrations/hyperliquid/"):
            continue
        sources[path] = strip_dart_comments_and_strings(read_text(path))

    declared: set[str] = set()
    registered = set(LIGHT_GROUND_CONTAINERS)
    for path, source in sources.items():
        relative = path.relative_to(root)
        for name, start, end in _dart_class_spans(source):
            body = source[start:end]
            if name in registered:
                missing = [
                    fragment
                    for fragment in ("DefaultTextStyle", "IconTheme")
                    if fragment not in body
                ]
                if missing:
                    errors.append(
                        f"{relative}: {name} paints a light ground but does not "
                        f"declare it ({', '.join(missing)} missing); every "
                        "descendant then reads the page's Chalk and a derived "
                        "colour is silently wrong"
                    )
                else:
                    declared.add(name)
                continue
            if _OPAQUE_LIGHT_FILL.search(body) and _WIDGET_SLOT_FIELD.search(body):
                if name in _LIGHT_GROUND_EXEMPT_CLASSES:
                    continue
                errors.append(
                    f"{relative}: {name} paints an opaque Chalk/Lime fill and "
                    "takes a widget from its caller, so it is a light ground; "
                    "register it in LIGHT_GROUND_CONTAINERS and declare its "
                    "DefaultTextStyle and IconTheme"
                )

    for name in registered:
        if name not in declared and not any(
            name in error for error in errors
        ):
            errors.append(
                f"lib: LIGHT_GROUND_CONTAINERS names {name}, which no longer "
                "exists; the register and the widgets have to agree"
            )

    for path, source in sources.items():
        relative = path.relative_to(root)
        for container, slots in LIGHT_GROUND_CONTAINERS.items():
            if not slots:
                continue
            for match in re.finditer(rf"\b{re.escape(container)}\s*\(", source):
                open_paren = match.end() - 1
                close = _dart_match_bracket(source, open_paren)
                for slot in slots:
                    for value_start, value_end in _dart_named_argument_spans(
                        source, open_paren, close, slot
                    ):
                        segment = source[value_start:value_end]
                        for token, weight in DARK_GROUND_ONLY_TOKENS.items():
                            if re.search(rf"{re.escape(token)}\b", segment):
                                line = source.count("\n", 0, value_start) + 1
                                errors.append(
                                    f"{relative}:{line} names `{token}` "
                                    f"({weight}) inside {container}'s `{slot}`; "
                                    "on that ground it paints nothing — derive "
                                    "it with LoopGround instead"
                                )
    return errors


# `MaterialApp` with no `theme:` is Material 3's own palette: `#6750A4`
# actions and `#1D1B20` copy on a `#FEF7FF` page. LOOP never paints that
# frame, because `LoopApp` always hands `LoopTheme.dark` down, so a test that
# mounts a page that way is not looking at the product.
_MATERIAL_APP = re.compile(r"\bMaterialApp(?:\.\w+)?\s*\(")
_PAGE_CLASS = re.compile(r"\bclass\s+(\w+(?:Screen|Page))\b")
_THEME_ARGUMENT = re.compile(r"\btheme\s*:\s*([\w.]+)")
_PRODUCT_THEME = "LoopTheme.dark"


def loop_page_class_names(root: Path) -> set[str]:
    """The page-level widget classes, named the way a mount site names them.

    Read out of `lib/features/` rather than listed here, so a page added next
    year is covered by the same rule without anybody maintaining a register.
    The layout primitives in `lib/widgets/` are deliberately out: `LoopFocusPage`
    is a shape a page is built from, not a page.
    """

    names = {"LoopApp"}
    features = root / "lib" / "features"
    if not features.is_dir():
        return names
    for path in sorted(features.rglob("*.dart")):
        source = strip_dart_comments_and_strings(read_text(path))
        names.update(match.group(1) for match in _PAGE_CLASS.finditer(source))
    return names


def check_page_mount_theme_contract(root: Path) -> list[str]:
    """A page is mounted under the theme the product mounts it under (S19).

    The render probe can only judge the frame a test actually paints. A test
    that mounts a page in a bare `MaterialApp` paints Material's defaults, and
    then every statement the test appears to make about colour — including
    the probe's — is about a frame the application cannot produce. This is
    static: it reads the mount site, not the render.
    """

    errors: list[str] = []
    names = loop_page_class_names(root)
    # Only `LoopApp` resolved: no `lib/features/` to read, so there is no page
    # set to check against and the rule has nothing to say.
    if len(names) <= 1:
        return errors
    # A page can be mounted through a named constructor
    # (`SystemSurfaceScreen.fromId('force-update')`), which is how the two
    # module-0 gates escaped review.
    constructors = {
        name: re.compile(rf"\b{name}\s*(?:\.\s*\w+\s*)?\(") for name in names
    }

    for area in ("lib", "test"):
        directory = root / area
        if not directory.is_dir():
            continue
        for path in sorted(directory.rglob("*.dart")):
            source = strip_dart_comments_and_strings(read_text(path))
            if "MaterialApp" not in source:
                continue
            relative = path.relative_to(root)
            for match in _MATERIAL_APP.finditer(source):
                arguments = source[
                    match.end() : _dart_match_bracket(source, match.end() - 1)
                ]
                mounted = sorted(
                    name
                    for name, pattern in constructors.items()
                    if pattern.search(arguments)
                )
                if not mounted:
                    continue
                theme = _THEME_ARGUMENT.search(arguments)
                if theme is not None and theme.group(1) == _PRODUCT_THEME:
                    continue
                line = source.count("\n", 0, match.start()) + 1
                stated = "no theme" if theme is None else f"`{theme.group(1)}`"
                errors.append(
                    f"{relative}:{line} mounts {', '.join(mounted)} with "
                    f"{stated}; a page is only ever rendered under "
                    f"`theme: {_PRODUCT_THEME}`, so any other mount paints a "
                    "frame the application cannot produce — Material's own "
                    "palette on Material's own surface — and neither the test "
                    "nor the ground probe is then looking at LOOP"
                )
    return errors


# A page harness is the one place every page test goes through, so it is also
# the one place the render probe can be armed for pages nobody has written yet.
# A harness that mounts a page without arming it is a hole that reopens
# silently, which is exactly how the light-ground bug shipped the first time.
_PUMP_FUNCTION = re.compile(r"\bFuture<[^>{}]*>\s+(pump\w*)\s*\(")


def check_ground_probe_armed(root: Path) -> list[str]:
    """Every page harness arms the render probe (S16f).

    `loopArmGroundProbe` watches every frame a test paints and fails when
    something it painted is not there on the ground it landed on. Calling it
    from the harnesses rather than from the tests is what makes it apply to
    pages that do not exist yet: a new page test reuses a harness, and is
    covered without opting in.
    """

    errors: list[str] = []
    support = root / "test" / "support"
    if not support.is_dir():
        return errors

    probe = support / "loop_ground_probe.dart"
    if not probe.is_file():
        errors.append(
            "test/support/loop_ground_probe.dart is missing; the render probe "
            "is the only guard that sees an indirectly passed widget on a "
            "light ground"
        )
        return errors
    if "void loopArmGroundProbe(" not in read_text(probe):
        errors.append(
            "test/support/loop_ground_probe.dart no longer defines "
            "loopArmGroundProbe; the page harnesses arm it by that name"
        )

    armed = 0
    for path in sorted(support.glob("*.dart")):
        if path.name == "loop_ground_probe.dart":
            continue
        source = strip_dart_comments_and_strings(read_text(path))
        relative = path.relative_to(root)
        for match in _PUMP_FUNCTION.finditer(source):
            # The parameter list opens its own brace for named arguments, so
            # the body starts after the closing parenthesis, not before it.
            parameters = _dart_match_bracket(source, match.end() - 1)
            brace = source.find("{", parameters)
            if brace < 0:
                continue
            body = source[brace : _dart_match_bracket(source, brace)]
            if "tester.pumpWidget(" not in body:
                continue
            if "loopArmGroundProbe(" in body:
                armed += 1
                continue
            line = source.count("\n", 0, match.start()) + 1
            errors.append(
                f"{relative}:{line} {match.group(1)} mounts a page but does "
                "not call loopArmGroundProbe(tester); every page test goes "
                "through a harness, so an unarmed harness is a whole slice of "
                "the application the ground probe stops watching"
            )
    if not errors and armed == 0:
        errors.append(
            "test/support: no harness arms the ground probe; the probe only "
            "covers the pages a harness mounts"
        )
    return errors


# The one file that may mount a page and not be watched, with the reason.
#
# This is not a list of files that are allowed to skip the probe; it is a list
# of files whose subject *is* the probe, and which therefore paint, on purpose,
# the frames the probe exists to reject. `test/s16e_ground_test.dart` is
# deliberately absent: it mounts shared components on three grounds, never a
# page, so the rule does not reach it — and if it ever mounts one, the guard
# should say so rather than have been quietly excused in advance.
GROUND_PROBE_UNWATCHED_TESTS = {
    "test/s16f_probe_test.dart": (
        "the probe's own test. It paints Chalk on Chalk, an invisible Badge "
        "and an undeclared seam because those are the findings it pins, and "
        "reads them back through `loopProbeGround` directly. Watching its "
        "frames would fail it for painting its own counter-examples."
    ),
}


def check_self_mounted_pages_watched(root: Path) -> list[str]:
    """A file that mounts a page itself watches its own frames (S19).

    `check_ground_probe_armed` holds the harnesses, which is what makes a page
    written next year covered without opting in. It cannot reach a file that
    calls `tester.pumpWidget` itself — and 22 of those rendered pages nobody
    looked at until S19. The rule is the same statement as the harness one,
    written for the other half: if a file mounts a page, the file is watched.
    """

    errors: list[str] = []
    tests = root / "test"
    if not tests.is_dir():
        return errors
    names = loop_page_class_names(root)
    if len(names) <= 1:
        return errors
    constructors = [
        re.compile(rf"\b{name}\s*(?:\.\s*\w+\s*)?\(") for name in names
    ]

    for path in sorted(tests.rglob("*.dart")):
        relative = path.relative_to(root)
        posix = relative.as_posix()
        # The harnesses are held by `check_ground_probe_armed`, and they arm
        # the probe per mount rather than per file.
        if posix.startswith("test/support/"):
            continue
        source = strip_dart_comments_and_strings(read_text(path))
        if "tester.pumpWidget(" not in source:
            continue
        if not any(pattern.search(source) for pattern in constructors):
            continue
        if "loopWatchGround(" in source:
            continue
        if posix in GROUND_PROBE_UNWATCHED_TESTS:
            continue
        errors.append(
            f"{relative} mounts a page through its own `tester.pumpWidget` "
            "but never calls loopWatchGround(); the page harnesses arm the "
            "probe for everybody else, so a self-mounted page is a rendered "
            "page nothing is looking at. Add `loopWatchGround();` at the top "
            "of `main`. If this file paints a frame the probe is meant to "
            "reject — which today is true of the probe's own test and "
            "nothing else — it belongs in GROUND_PROBE_UNWATCHED_TESTS with "
            "its reason, and adding an entry there needs the main agent's "
            "confirmation."
        )

    for posix, reason in GROUND_PROBE_UNWATCHED_TESTS.items():
        if not (root / posix).is_file():
            errors.append(
                f"{posix} is excused from the ground probe but no longer "
                "exists; an excuse outlives the file it was written for and "
                "then excuses the next file to take the name"
            )
        elif len(reason) < 40:
            errors.append(
                f"{posix} is excused from the ground probe without stating "
                "why; an unwatched page test is a claim, and a claim needs a "
                "reason a reviewer can disagree with"
            )
    return errors


def check_source_guards(root: Path) -> list[str]:
    forbidden = {
        "PrivyLogLevel.debug": "Privy debug logging can expose OTPs and access tokens",
        "PrivyLogLevel.verbose": "Privy verbose logging can expose OTPs and access tokens",
        ".devToken(": "Stream development tokens bypass backend identity validation",
        "connectGuestUser(": "Stream guest users bypass the Privy identity boundary",
        # S70: the configuration now exists, so the question is no longer
        # whether Firebase may start but who may start it. One owner, so a
        # second `initializeApp` cannot race the first and leave two apps.
        "Firebase.initializeApp(": (
            "Firebase may only be initialized by the one reviewed provider ingress, "
            f"{NOTIFICATION_PROVIDER_INGRESS_PATH}"
        ),
    }
    exempt = {"Firebase.initializeApp(": {NOTIFICATION_PROVIDER_INGRESS_PATH}}
    errors: list[str] = []
    for path in sorted((root / "lib").rglob("*.dart")):
        text = read_text(path)
        relative = path.relative_to(root)
        for fragment, reason in forbidden.items():
            if fragment in text and relative not in exempt.get(fragment, frozenset()):
                errors.append(f"{relative} contains forbidden `{fragment}`: {reason}")
    return errors


# ---------------------------------------------------------------------------
# User-visible copy (decision 0070)
# ---------------------------------------------------------------------------

# A literal is user-visible zh-CN copy when it carries a CJK ideograph. Wire
# constants, `reasonCode` keys and env-var names never do, so the vocabulary
# rules below apply to copy only and leave the transport layer alone.
CJK_CHARACTER = re.compile(r"[\u4e00-\u9fff]")

# Step ids never belong on a screen, in any language.
COPY_STEP_ID = (
    re.compile(r"[（(]D\d+[)）]"),
    re.compile(r"(?<![A-Za-z0-9_])[DS]\d+ ·"),
)

# These only fire inside zh-CN copy; the same fragments are legitimate as wire
# constants and as the keys of a `reasonCode` -> sentence map.
COPY_INTERNAL_VOCABULARY = (
    (re.compile(r"rule:"), "a rule id"),
    (re.compile(r"_PENDING\b|_UNAVAILABLE\b"), "a reason code"),
    (re.compile(r"口径|观测|投影|聚合"), "internal vocabulary"),
)

# Diagnostics are written for engineers, never rendered on a surface.
COPY_LOGGING_CALLS = ("debugPrint(", "developer.log(", "assert(", "LoopLog.")

# Every Dart interpolation inside a literal: `${expression}` or `$path`.
COPY_INTERPOLATION = re.compile(
    r"\$\{(?P<braced>[^{}]*)\}|\$(?P<plain>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)"
)

# Identifiers inside one interpolated expression.
COPY_EXPRESSION_SEGMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

# Field and getter names that carry a backend identifier rather than a fact a
# reader can act on: `marketTrendingV1`, `MININGFORMULAV1-DRAFT`,
# `walletGasReserveV1`, `MINING_FORMULA_BASELINE_PENDING`. A name ending in one
# of these is the identifier itself; a plain `version` is the numeric CAS
# version of the reader's own resource and stays available as small print.
COPY_IDENTIFIER_SUFFIXES = (
    "reasoncode",
    "configversion",
    "formulaversion",
    "ruleversion",
    "policyversion",
    "pendingversion",
    "ruleid",
    "policyid",
    "configid",
    "formulaid",
    "capabilityid",
)

# `about` is the one surface whose subject is the published configuration
# versions themselves, so it renders them as its own content.
COPY_IDENTIFIER_ALLOWLIST = ("lib/features/profile/about/about_screen.dart",)

# The named arguments that put a bare value on the screen without a literal
# around it: `stamp: overview.rules.configVersion` renders the identifier just
# as plainly as `'规则 $configVersion'` does.
COPY_TEXT_SLOT = re.compile(
    r"(?<![A-Za-z0-9_])(?:title|subtitle|label|message|reason|stamp|caption"
    r"|heading|kicker|trailing|trailingCaption|semanticLabel|text|summary"
    r"|body|value|note)\s*:\s*(?P<expression>[^,\n]*)"
)

# `x == null` / `x != null` decides which branch renders; it is not the value
# that renders, so the name inside a null test never counts.
COPY_NULL_TEST = re.compile(r"[A-Za-z_][A-Za-z0-9_.?]*\s*[!=]=\s*null")


def _dart_string_literals(source: str) -> list[tuple[int, str]]:
    """Every Dart string literal in `source`, as `(line, body)` pairs.

    Comments are skipped so a `// D19` note never counts as copy.
    """

    literals: list[tuple[int, str]] = []
    index = 0
    line = 1
    length = len(source)
    while index < length:
        character = source[index]
        if character == "\n":
            line += 1
            index += 1
            continue
        if source.startswith("//", index):
            while index < length and source[index] != "\n":
                index += 1
            continue
        if source.startswith("/*", index):
            depth = 1
            index += 2
            while index < length and depth:
                if source[index] == "\n":
                    line += 1
                if source.startswith("/*", index):
                    depth += 1
                    index += 2
                    continue
                if source.startswith("*/", index):
                    depth -= 1
                    index += 2
                    continue
                index += 1
            continue
        if character in "'\"":
            raw = index > 0 and source[index - 1] == "r"
            quote = character * 3 if source.startswith(character * 3, index) else character
            opened = line
            index += len(quote)
            body: list[str] = []
            while index < length:
                if source[index] == "\\" and not raw:
                    if source[index + 1 : index + 2] == "\n":
                        line += 1
                    body.append(source[index : index + 2])
                    index += 2
                    continue
                if source.startswith(quote, index):
                    index += len(quote)
                    break
                if source[index] == "\n":
                    line += 1
                    if len(quote) == 1:
                        break
                body.append(source[index])
                index += 1
            literals.append((opened, "".join(body)))
            continue
        index += 1
    return literals


def _copy_interpolated_identifier(literal: str) -> str | None:
    """The first backend identifier this literal interpolates, if any.

    A literal fails when it interpolates a *value* whose name carries a rule,
    formula, configuration, policy or capability identifier
    (`COPY_IDENTIFIER_SUFFIXES`) — that is how `待批准（MININGFORMULAV1-DRAFT）`,
    `规则 marketTrendingV1` and `配置 walletGasReserveV1` reached a screen while
    every literal on those lines stayed clean.

    Two forms are deliberately not values and stay legal:

    * an interpolation containing `(` is a call. `${launchReasonCodeText(code)}`
      and `${blockReasonText(entry.reasonCode)}` are the approved mapping
      functions — they turn a code into a sentence, so the code never lands on
      the screen. Reaching inside a call is the guard's blind spot, and the
      review checklist in `docs/copy-glossary.md` owns it.
    * a name ending in a bare `version` (`resource.version`,
      `project.materialVersion`) is the numeric version of the reader's own
      resource, which §3 of the glossary keeps as small print.
    """

    for match in COPY_INTERPOLATION.finditer(literal):
        expression = match.group("braced") or match.group("plain") or ""
        identifier = _copy_expression_identifier(expression)
        if identifier is not None:
            return identifier
    return None


def _copy_expression_identifier(expression: str) -> str | None:
    """The backend identifier this expression renders, if any.

    An expression containing `(` is a call and is left alone: a mapping
    function is how a code becomes a sentence. A name inside `== null` is a
    branch test rather than the value that reaches the screen.
    """

    if "(" in expression:
        return None
    for segment in COPY_EXPRESSION_SEGMENT.findall(
        COPY_NULL_TEST.sub(" ", expression)
    ):
        if segment.lower().endswith(COPY_IDENTIFIER_SUFFIXES):
            return segment
    return None


def _copy_slot_identifiers(source: str) -> list[tuple[int, str, str]]:
    """`(line, slot, identifier)` for every text slot handed a raw identifier.

    A widget argument needs no literal to put a value on a screen:
    `stamp: overview.rules.configVersion` and
    `trailing: eligibility.configVersion` render the identifier directly. Only
    the first line of a slot's expression is read, so a name that a multi-line
    ternary reaches is the review checklist's problem, not the guard's.
    """

    found: list[tuple[int, str, str]] = []
    for number, line in enumerate(
        strip_dart_comments_and_strings(source).splitlines(), start=1
    ):
        for match in COPY_TEXT_SLOT.finditer(line):
            identifier = _copy_expression_identifier(match.group("expression"))
            if identifier is not None:
                found.append((number, match.group(0).split(":")[0].strip(), identifier))
    return found


def check_user_visible_copy(root: Path) -> list[str]:
    """Keep internal identifiers and internal vocabulary out of the UI.

    Step ids (`D19`), rule ids (`rule:…`), reason codes and the words 口径 /
    观测 / 投影 / 聚合 are how the product talks to itself. `docs/copy-glossary.md`
    holds the replacement table; a screen says what cannot be done now instead.

    Literal text is only half of it. A sentence assembled at runtime —
    `'待批准（${summary.formula.pendingVersion}）'` — reads as clean source and
    still puts a backend identifier on the screen, so
    `_copy_interpolated_identifier` checks what each zh-CN literal interpolates
    as well as what it spells out, and `_copy_slot_identifiers` checks the text
    slots that render a value with no literal around it at all.
    """

    errors: list[str] = []
    for path in sorted((root / "lib").rglob("*.dart")):
        source = read_text(path)
        lines = source.splitlines()
        relative = path.relative_to(root)
        if relative.as_posix() not in COPY_IDENTIFIER_ALLOWLIST:
            for line, slot, identifier in _copy_slot_identifiers(source):
                errors.append(
                    f"{relative}:{line} hands `{identifier}` straight to `{slot}`: "
                    "a rule, formula, configuration or policy identifier belongs "
                    "in a LoopDisclosure, not on a screen"
                )
        for line, literal in _dart_string_literals(source):
            physical = lines[line - 1] if 0 < line <= len(lines) else ""
            if any(call in physical for call in COPY_LOGGING_CALLS):
                continue
            excerpt = literal if len(literal) <= 60 else f"{literal[:60]}…"
            for pattern in COPY_STEP_ID:
                if pattern.search(literal):
                    errors.append(
                        f"{relative}:{line} shows a step id in `{excerpt}`: "
                        "user-visible copy carries no D-numbers"
                    )
                    break
            if not CJK_CHARACTER.search(literal):
                continue
            if relative.as_posix() not in COPY_IDENTIFIER_ALLOWLIST:
                interpolated = _copy_interpolated_identifier(literal)
                if interpolated is not None:
                    errors.append(
                        f"{relative}:{line} interpolates `{interpolated}` into "
                        f"`{excerpt}`: a rule, formula, configuration or policy "
                        "identifier belongs in a LoopDisclosure, not in a sentence"
                    )
            for pattern, label in COPY_INTERNAL_VOCABULARY:
                if pattern.search(literal):
                    errors.append(
                        f"{relative}:{line} shows {label} in `{excerpt}`: "
                        "see docs/copy-glossary.md for the replacement"
                    )
    return errors


# A chat identity that is never a name. LOOP upserts every account to Stream as
# `{ id }` alone, so `User.name` is empty and the SDK's getter answers with
# `User.id` — `loop_` plus the LOOP row key, identical in every room the
# account is in (device report 2026-09-19 · F5). Either one reaching a `Text`
# puts an internal primary key on the screen.
STREAM_USER_IDENTITY_FIELD = re.compile(
    r"(?<![A-Za-z0-9_])"
    r"(?:\w*[Uu]ser|sender|author|member|currentUser)\w*\s*[!?]?\s*"
    r"\.\s*(?:name|id)(?![A-Za-z0-9_])"
)

# The widgets that draw their first positional argument.
STREAM_TEXT_WIDGET_CALL = re.compile(
    r"(?<![A-Za-z0-9_$.])(Text|SelectableText)\s*\("
)

# The direct-message top bar is the one place a conversation is named after the
# person on the other end, and it does so from LOOP's own profile record
# (`identity.displayName` / `identity.loopId`), never from a Stream `User`.
# Listed so the exception is written down rather than implied.
STREAM_USER_TEXT_ALLOWLIST = ("lib/features/chat/v2/direct_message_screen.dart",)


def _dart_call_arguments(source: str, open_index: int) -> str | None:
    """The text between one `(` and its match, or None when unbalanced."""

    depth = 0
    index = open_index
    quote: str | None = None
    while index < len(source):
        char = source[index]
        if quote is not None:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
            index += 1
            continue
        if char in "'\"":
            quote = char
        elif char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                return source[open_index + 1 : index]
        index += 1
    return None


def _first_positional_argument(arguments: str) -> str | None:
    """The first argument of a call, when it is positional."""

    depth = 0
    quote: str | None = None
    index = 0
    while index < len(arguments):
        char = arguments[index]
        if quote is not None:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
            index += 1
            continue
        if char in "'\"":
            quote = char
        elif char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "," and depth == 0:
            break
        index += 1
    first = arguments[:index]
    # `Text(key: ..., ...)` has no positional first argument at all.
    if re.match(r"\s*[A-Za-z_][A-Za-z0-9_]*\s*:(?!:)", first):
        return None
    return first


def check_stream_user_identity_rendering(root: Path) -> list[str]:
    """Keep the Stream account id and account name off the screen.

    Device report 2026-09-19 · F5. `User.name` is empty for every LOOP account
    and `User.id` is the LOOP row key, so both read as
    `loop_3bb585972e3145e7b5f0957803a824ed` in all twenty of an account's
    rooms. A name on a chat surface is the label that channel resolved —
    today the group Alias projection carried on the channel's own member,
    read back through `loopStreamDisplayLabelOf` — and a member with no label
    is not named at all.

    Only the drawn argument counts: routing on `user.id`, keying on it, or
    comparing it is how Stream's own widgets work.
    """

    errors: list[str] = []
    for path in sorted((root / "lib").rglob("*.dart")):
        relative = path.relative_to(root).as_posix()
        if relative in STREAM_USER_TEXT_ALLOWLIST:
            continue
        source = read_text(path)
        for match in STREAM_TEXT_WIDGET_CALL.finditer(source):
            arguments = _dart_call_arguments(source, match.end() - 1)
            if arguments is None:
                continue
            first = _first_positional_argument(arguments)
            if first is None:
                continue
            found = STREAM_USER_IDENTITY_FIELD.search(first)
            if found is None:
                continue
            line = source.count("\n", 0, match.start()) + 1
            errors.append(
                f"{relative}:{line} draws `{found.group(0).strip()}`: a Stream "
                "account id or account name is the same string in every room, "
                "so a chat surface prints the label the channel resolved "
                "(loopStreamDisplayLabelOf) or no name at all"
            )
    return errors


def check_notification_contract(root: Path) -> list[str]:
    """Keep provider callbacks behind one adapter and routing provider-neutral."""

    errors: list[str] = []
    router_path = root / NOTIFICATION_ROUTER_PATH
    if not router_path.is_file():
        errors.append(f"missing centralized notification router: {NOTIFICATION_ROUTER_PATH}")
    else:
        executable = strip_dart_comments(read_text(router_path))
        executable_code = strip_dart_comments_and_strings(read_text(router_path))
        directives = list(
            re.finditer(
                r"^\s*(?P<kind>import|export|part)\s+(?P<body>[^;]+);",
                executable,
                re.MULTILINE,
            )
        )
        actual_imports: list[str] = []
        invalid_directives: list[str] = []
        for directive in directives:
            body = " ".join(directive.group("body").split())
            if directive.group("kind") != "import":
                invalid_directives.append(directive.group(0).strip())
                continue
            actual_imports.append(body)
        actual_import_set = frozenset(actual_imports)
        if (
            invalid_directives
            or len(actual_imports) != len(actual_import_set)
            or actual_import_set != NOTIFICATION_ROUTER_IMPORTS
        ):
            errors.append(
                "notification routing imports must stay on the provider-neutral allowlist: "
                f"expected {sorted(NOTIFICATION_ROUTER_IMPORTS)}, found {sorted(actual_imports)}"
            )

        required_fragments = (
            "class LoopNotificationRouter",
            # The exact four keys of decision 0067, and the only version.
            "static const String eventVersion = '1'",
            "'type'",
            "'entityRef'",
            "'contextRoute'",
            "'eventVersion'",
            "'price_alert_triggered'",
            "'security_event'",
            "'community_voice_room_started'",
            # The asset comes from the feed record, never from the payload, and
            # only a canonical CAIP identity may address the token page.
            "MarketAssetRoute.isCanonical(assetId)",
            "String get location => MarketAssetRoute.token(assetId)",
            "String get location => MarketAssetRoute.alertsPath",
            "context.contextRoute == pointer.contextRoute.wireName",
            "LoopNotificationIngress.foreground",
            "LoopNotificationIngress.background",
            "LoopNotificationIngress.interaction",
            "LoopNotificationSessionMode.authenticated",
            "LoopNotificationDisposition.duplicateInteraction",
            "String get location => '/chat/voice'",
            "String get location => '/profile/devices'",
        )
        for fragment in required_fragments:
            if fragment not in executable:
                errors.append(
                    "centralized notification routing contract is missing reviewed fragment "
                    f"`{fragment}`"
                )

        forbidden_fragments = (
            "package:firebase",
            "package:stream_chat",
            "package:stream_video",
            "package:go_router",
            "FirebaseMessaging",
            "RemoteMessage",
            "BuildContext",
            "Navigator",
            "dart:io",
            "debugPrint(",
            "print(",
            "data['route']",
            'data["route"]',
            "data['path']",
            'data["path"]',
            # The payload names a destination family, never a destination: the
            # parameters belong to the feed record the client reads back.
            "data['contextParams']",
            'data["contextParams"]',
            "data['assetId']",
            'data["assetId"]',
            "deep_link",
            "call_cid",
            "room_id",
        )
        for fragment in forbidden_fragments:
            if fragment in executable:
                errors.append(
                    "centralized notification routing must reject provider SDKs, payload "
                    f"routes, room locators, and payload logging (`{fragment}`)"
                )

        kind_match = re.search(
            r"enum\s+LoopPushNotificationType\s*\{(?P<body>.*?);",
            executable_code,
            re.DOTALL,
        )
        kind_members = (
            frozenset(
                re.findall(r"^\s*(\w+)\s*\(", kind_match.group("body"), re.MULTILINE)
            )
            if kind_match
            else frozenset()
        )
        route_match = re.search(
            r"enum\s+LoopNotificationContextRoute\s*\{(?P<body>.*?);",
            executable_code,
            re.DOTALL,
        )
        route_members = (
            frozenset(
                re.findall(
                    r"^\s*(\w+)\s*\(", route_match.group("body"), re.MULTILINE
                )
            )
            if route_match
            else frozenset()
        )
        if route_members != NOTIFICATION_CONTEXT_ROUTE_MEMBERS:
            errors.append(
                "notification context routes must stay on the reviewed allowlist: "
                f"expected {sorted(NOTIFICATION_CONTEXT_ROUTE_MEMBERS)}, "
                f"found {sorted(route_members)}"
            )
        if kind_members != NOTIFICATION_KIND_MEMBERS:
            errors.append(
                "notification kinds must stay on the reviewed four-kind allowlist: "
                f"expected {sorted(NOTIFICATION_KIND_MEMBERS)}, found {sorted(kind_members)}"
            )

        intent_classes = frozenset(
            re.findall(
                r"final\s+class\s+(\w+)\s+extends\s+LoopNotificationNavigationIntent\b",
                executable_code,
            )
        )
        if intent_classes != NOTIFICATION_INTENT_CLASSES:
            errors.append(
                "notification intents must stay on the reviewed four-class allowlist: "
                f"expected {sorted(NOTIFICATION_INTENT_CLASSES)}, "
                f"found {sorted(intent_classes)}"
            )

        route_literals = frozenset(
            match.group("route")
            for match in re.finditer(
                r"(?P<quote>['\"])(?P<route>/[^'\"\r\n]*)(?P=quote)",
                executable,
            )
        )
        if route_literals != NOTIFICATION_ROUTE_LITERALS:
            errors.append(
                "notification route literals must stay on the reviewed three-route allowlist: "
                f"expected {sorted(NOTIFICATION_ROUTE_LITERALS)}, "
                f"found {sorted(route_literals)}"
            )

    event_source_path = root / NOTIFICATION_EVENT_SOURCE_PATH
    if not event_source_path.is_file():
        errors.append(
            f"missing production notification event source: {NOTIFICATION_EVENT_SOURCE_PATH}"
        )
    else:
        source = strip_dart_comments(read_text(event_source_path))
        source_code = strip_dart_comments_and_strings(read_text(event_source_path))
        source_kind_match = re.search(
            r"enum\s+LoopNotificationSourceEventKind\s*\{(?P<body>[^}]*)\}",
            source_code,
            re.DOTALL,
        )
        source_kind_members = (
            frozenset(
                member.strip()
                for member in source_kind_match.group("body").split(",")
                if member.strip()
            )
            if source_kind_match
            else frozenset()
        )
        if source_kind_members != NOTIFICATION_SOURCE_EVENT_KIND_MEMBERS:
            errors.append(
                "notification source events must stay on the reviewed foreground, "
                "background, and interaction allowlist"
            )

        if not re.search(
            r"Map<String,\s*Object\?>\s*\.\s*unmodifiable\s*\(\s*data\s*\)",
            source,
        ):
            errors.append(
                "notification source events must defensively copy their untrusted data"
            )

        disabled_provider_pattern = re.compile(
            r"final\s+loopNotificationEventSourceProvider\s*=\s*"
            r"Provider<LoopNotificationEventSource>\s*\(\s*"
            r"\(\s*ref\s*\)\s*=>\s*const\s+DisabledLoopNotificationEventSource\s*"
            r"\(\s*\)\s*,?\s*\)\s*;",
            re.DOTALL,
        )
        if disabled_provider_pattern.search(source) is None:
            errors.append(
                "production notification source provider must default directly to "
                "DisabledLoopNotificationEventSource"
            )

        disabled_source_contracts = (
            r"final\s+class\s+DisabledLoopNotificationEventSource\s+"
            r"implements\s+LoopNotificationEventSource",
            r"loadInitialInteraction\s*\(\s*\)\s*async\s*=>\s*null\s*;",
            r"const\s+Stream<LoopNotificationSourceEvent>\s*\.\s*empty\s*\(\s*\)",
        )
        if any(
            re.search(pattern, source, re.DOTALL) is None
            for pattern in disabled_source_contracts
        ):
            errors.append(
                "DisabledLoopNotificationEventSource must expose no initial interaction "
                "and an empty event stream"
            )

    coordinator_path = root / NOTIFICATION_COORDINATOR_PATH
    if not coordinator_path.is_file():
        errors.append(
            f"missing root notification coordinator: {NOTIFICATION_COORDINATOR_PATH}"
        )
    else:
        coordinator = strip_dart_comments(read_text(coordinator_path))
        coordinator_code = strip_dart_comments_and_strings(
            read_text(coordinator_path)
        )
        context_match = re.search(
            r"LoopNotificationSessionContext\s+_currentContext\s*\(\s*\)\s*\{"
            r"(?P<body>.*?)\n\s*\}\s*\n\s*\n\s*void\s+_defer\s*\(",
            coordinator,
            re.DOTALL,
        )
        context_body = context_match.group("body") if context_match else ""
        # Decision 0067 took the recipient out of the payload, so there is
        # nothing left to compare a stream user id against. The context is now
        # produced only after the same two facts as before — a real
        # authenticated session and a backend-verified bootstrap identity — and
        # carries neither of them onward.
        authenticated_context_pattern = re.compile(
            r"return\s+const\s+LoopNotificationSessionContext\s*\.\s*"
            r"authenticated\s*\(\s*\)\s*;"
        )
        authenticated_context_calls = tuple(
            re.finditer(
                r"LoopNotificationSessionContext\s*\.\s*authenticated\s*\(",
                coordinator_code,
            )
        )
        if (
            context_match is None
            or "_readSession()" not in context_body
            or "session.mode != LoopSessionMode.authenticated" not in context_body
            or "_readBootstrapSession()?.identity" not in context_body
            or authenticated_context_pattern.search(context_body) is None
            or len(authenticated_context_calls) != 1
        ):
            errors.append(
                "notification coordinator authenticated context must come only from a "
                "real authenticated session and a verified bootstrap identity"
            )
        # The tap is confirmed against the account's own feed before anything
        # opens. Without this the payload would be the only source of a
        # destination again, which is exactly what 0067 forbids.
        for fragment in (
            "await _resolveContext(pointer)",
            "LoopNotificationRouter.resolve(pointer, context: context)",
            "_currentContext().mode != LoopNotificationSessionMode.authenticated",
        ):
            if fragment not in coordinator:
                errors.append(
                    "notification coordinator must confirm a pointer against the "
                    f"current account's feed before navigating (`{fragment}`)"
                )

        resolution_match = re.search(
            r"Future<void>\s+_resolveIdentity\s*\(\s*\{"
            r"(?P<parameters>.*?)\}\s*\)\s*async\s*\{"
            r"(?P<body>.*?)\n\s*\}\s*\n\s*\n\s*void\s+_retryDeferredInteraction",
            coordinator,
            re.DOTALL,
        )
        resolution_parameters = (
            resolution_match.group("parameters") if resolution_match else ""
        )
        resolution_body = resolution_match.group("body") if resolution_match else ""
        authorization_position = resolution_body.find(
            "await bootstrap.authorize()"
        )
        current_slot_position = resolution_body.find(
            "final deferred = _deferredInteraction;"
        )
        if (
            resolution_match is None
            or "_DeferredInteraction" in resolution_parameters
            or "LoopNotificationSourceEvent" in resolution_parameters
            or authorization_position < 0
            or current_slot_position <= authorization_position
        ):
            errors.append(
                "notification identity resolution must not retain a deferred payload "
                "while authorization is in flight; it must read the current slot after await"
            )

        default_wait_match = re.search(
            r"Duration\s+restoringWait\s*=\s*const\s+Duration\s*\(\s*"
            r"(?P<unit>seconds|minutes)\s*:\s*(?P<value>\d+)\s*\)",
            coordinator,
        )
        default_wait_seconds: int | None = None
        if default_wait_match:
            default_wait_seconds = int(default_wait_match.group("value"))
            if default_wait_match.group("unit") == "minutes":
                default_wait_seconds *= 60
        bounded_wait = (
            default_wait_seconds is not None
            and 0 < default_wait_seconds <= 60
            and re.search(
                r"restoringWait\s*>\s*const\s+Duration\s*\(\s*minutes\s*:\s*1\s*\)",
                coordinator,
            )
            is not None
            and re.search(
                r"Timer\s*\(\s*_restoringWait\s*,\s*_clearDeferredInteraction\s*\)",
                coordinator,
            )
            is not None
        )
        single_deferred_slot = (
            len(
                re.findall(
                    r"_DeferredInteraction\?\s+_deferredInteraction\s*;",
                    coordinator_code,
                )
            )
            == 1
            and len(
                re.findall(
                    r"_deferredInteraction\s*=\s*_DeferredInteraction\s*\(",
                    coordinator_code,
                )
            )
            == 1
            and re.search(
                r"(?:List|Queue|Set|Map)\s*<[^>]*_DeferredInteraction",
                coordinator_code,
            )
            is None
            and (
                re.search(
                    r"if\s*\(\s*_deferredInteraction\s*!=\s*null\s*\)\s*return\s*;",
                    coordinator_code,
                )
                is not None
                or (
                    "_identityGeneration += 1;" in coordinator_code
                    and "_deferredTimer?.cancel();" in coordinator_code
                )
            )
        )
        if not bounded_wait or not single_deferred_slot:
            errors.append(
                "notification coordinator may retain at most one deferred interaction "
                "for a positive wait no longer than one minute"
            )

    application_path = root / NOTIFICATION_APPLICATION_PATH
    if not application_path.is_file():
        errors.append(
            f"missing production notification composition root: {NOTIFICATION_APPLICATION_PATH}"
        )
    else:
        application = strip_dart_comments(read_text(application_path))
        application_code = strip_dart_comments_and_strings(
            read_text(application_path)
        )
        production_bindings = (
            r"source\s*:\s*ref\s*\.\s*read\s*\(\s*"
            r"loopNotificationEventSourceProvider\s*\)",
            r"readSession\s*:\s*\(\s*\)\s*=>\s*ref\s*\.\s*read\s*"
            r"\(\s*loopSessionProvider\s*\)",
            r"readBootstrapSession\s*:\s*\(\s*\)\s*=>\s*ref\s*\.\s*read\s*"
            r"\(\s*loopBootstrapSessionProvider\s*\)",
        )
        if any(
            re.search(pattern, application, re.DOTALL) is None
            for pattern in production_bindings
        ):
            errors.append(
                "production notification coordinator must bind the disabled source and "
                "real root session/bootstrap providers"
            )
        typed_navigation_pattern = re.compile(
            r"navigate\s*:\s*\(\s*intent\s*\)\s*=>\s*router\s*\.\s*go\s*"
            r"\(\s*intent\s*\.\s*location\s*\)\s*,"
        )
        if (
            len(
                NOTIFICATION_COORDINATOR_CONSTRUCTION_PATTERN.findall(
                    application_code
                )
            )
            != 1
            or len(typed_navigation_pattern.findall(application)) != 1
        ):
            errors.append(
                "production must construct exactly one notification coordinator and "
                "perform exactly one typed root navigation"
            )

    # S70: the provider ingress exists now, so the rule changed from "never
    # override" to "override exactly once, and only for a build that actually
    # started Firebase". The default in the source file stays disabled, which
    # is what every other composition — tests, the offline Preview entry point,
    # a build with no configuration — still gets.
    production_entrypoint = root / "lib/main.dart"
    if production_entrypoint.is_file():
        production = strip_dart_comments(read_text(production_entrypoint))
        production_code = strip_dart_comments_and_strings(
            read_text(production_entrypoint)
        )
        overrides = re.findall(
            r"\bloopNotificationEventSourceProvider\s*\.\s*override\w*",
            production_code,
        )
        gated = (
            "config.canInitializeFirebase" in production_code
            and "LoopFirebaseIngress.ensureApp(" in production_code
            and "if (firebaseApp != null)" in production_code
        )
        if len(overrides) != 1 or not gated:
            errors.append(
                "lib/main.dart must override the notification source exactly once, "
                "behind `config.canInitializeFirebase` and a successful "
                "`LoopFirebaseIngress.ensureApp()`"
            )
        if (
            "loopNotificationEventSourceProvider.overrideWithValue(\n"
            "            FirebaseLoopNotificationEventSource.forDefaultApp(),"
        ) not in production:
            errors.append(
                "lib/main.dart must mount the reviewed Firebase notification ingress "
                "as the production event source"
            )

    preview_entrypoint = root / "lib/main_preview.dart"
    if preview_entrypoint.is_file():
        preview = strip_dart_comments_and_strings(read_text(preview_entrypoint))
        for marker in (
            "loopNotificationEventSourceProvider",
            "loopPushTokenSourceProvider",
            "pushDeviceGatewayProvider",
            "LoopFirebaseIngress",
            "firebaseConfigured: true",
        ):
            if marker in preview:
                errors.append(
                    "the offline Preview entry point must not reach a push provider "
                    f"(`{marker}`); Preview has no account and no device to register"
                )

    lib_root = root / "lib"
    if lib_root.is_dir():
        for path in sorted(lib_root.rglob("*.dart")):
            executable = strip_dart_comments(read_text(path))
            executable_code = strip_dart_comments_and_strings(read_text(path))
            relative = path.relative_to(root)
            for marker in NOTIFICATION_PROVIDER_IMPORT_MARKERS:
                if (
                    marker in executable
                    and relative not in NOTIFICATION_PROVIDER_IMPORT_ALLOWED_PATHS
                ):
                    errors.append(
                        f"{relative} imports notification provider SDK `{marker}`; only the "
                        "compatibility probe and centralized provider ingress may import it"
                    )
            if relative not in NOTIFICATION_ROUTER_CONSUMER_PATHS:
                if NOTIFICATION_ROUTER_IMPORT in executable:
                    errors.append(
                        f"{relative} imports the notification router directly; only "
                        f"{NOTIFICATION_COORDINATOR_PATH} may bind it to application identity"
                    )
                if NOTIFICATION_ROUTER_CONSTRUCTION_PATTERN.search(executable_code):
                    errors.append(
                        f"{relative} constructs notification routing identity directly; only "
                        f"{NOTIFICATION_COORDINATOR_PATH} may derive it from verified bootstrap state"
                    )
            if relative not in NOTIFICATION_COORDINATOR_CONSUMER_PATHS:
                if NOTIFICATION_COORDINATOR_IMPORT in executable:
                    errors.append(
                        f"{relative} imports the notification coordinator directly; only "
                        f"{NOTIFICATION_APPLICATION_PATH} may consume it"
                    )
                if NOTIFICATION_COORDINATOR_CONSTRUCTION_PATTERN.search(
                    executable_code
                ):
                    errors.append(
                        f"{relative} constructs a competing notification coordinator; only "
                        f"{NOTIFICATION_APPLICATION_PATH} may own it"
                    )
            for pattern, marker in NOTIFICATION_GLOBAL_INGRESS_PATTERNS:
                if (
                    pattern.search(executable_code)
                    and relative != NOTIFICATION_PROVIDER_INGRESS_PATH
                ):
                    errors.append(
                        f"{relative} contains global notification ingress `{marker}`; "
                        f"only {NOTIFICATION_PROVIDER_INGRESS_PATH} may own provider callbacks"
                    )
    return errors


def check_s5_truth_contract(root: Path) -> list[str]:
    """Lock the step-5 truth rules recorded by decision 0057."""

    errors: list[str] = []

    # 1. Every S5 port stays fail-closed until a real adapter is mounted.
    for relative, provider, port, unavailable in S5_PORT_DEFAULTS:
        path = root / relative
        if not path.is_file():
            errors.append(f"missing S5 port: {relative}")
            continue
        source = strip_dart_comments(read_text(path))
        default_pattern = re.compile(
            rf"final\s+{re.escape(provider)}\s*=\s*Provider<{re.escape(port)}>\s*"
            rf"\(\s*\(\s*ref\s*\)\s*=>\s*const\s+{re.escape(unavailable)}\s*"
            r"\(\s*\)\s*,?\s*\)\s*;",
            re.DOTALL,
        )
        if default_pattern.search(source) is None:
            errors.append(
                f"{provider} must default directly to const {unavailable}(); an "
                "S5 port is unavailable until lib/main.dart mounts its adapter"
            )

    # 2. The capability enum follows the contract's 31 ids, in contract order.
    meta_path = root / S5_CAPABILITY_META_PATH
    if meta_path.is_file():
        meta_source = strip_dart_comments(read_text(meta_path))
        enum_match = re.search(
            r"enum\s+LoopV2CapabilityId\s*\{(?P<body>.*?);",
            meta_source,
            re.DOTALL,
        )
        declared = (
            tuple(
                member
                for member, _, wire in re.findall(
                    r"\b(\w+)\((['\"])([^'\"]*)\2\)",
                    enum_match.group("body"),
                )
                if member == wire
            )
            if enum_match
            else ()
        )
        if declared != S5_CAPABILITY_IDS:
            errors.append(
                "LoopV2CapabilityId must list exactly the contract's "
                f"{len(S5_CAPABILITY_IDS)} ids in contract order; found "
                f"{len(declared)}"
            )

    # 3. Every buy/sell/swap control is gated on `capability.swappable` and
    #    nothing else. The backend pins it to false until D15. The word may
    #    appear exactly twice: the Token Card's action row and the entry
    #    button, both reading the same flag directly.
    token_path = root / S5_TOKEN_SURFACE_PATH
    if token_path.is_file():
        token_source = strip_dart_comments(read_text(token_path))
        gate_at = token_source.find(S5_SWAP_GATE)
        entry_at = token_source.find(S5_SWAP_ENTRY_KEY)
        if (
            gate_at < 0
            or entry_at < gate_at
            or token_source.count("swappable") != 2
            or token_source.count("capability.swappable") != 2
            or S5_SWAP_CARD_GATE not in token_source
            or token_source.count(S5_SWAP_ENTRY_KEY) != 1
        ):
            errors.append(
                "the Swap entry point must be gated on exactly one "
                f"`{S5_SWAP_GATE}`, and the Token Card's 买入 / 卖出 on "
                f"exactly one `{S5_SWAP_CARD_GATE}`"
            )
        else:
            guarded = token_source[gate_at + len(S5_SWAP_GATE) : entry_at]
            for forbidden in ("&&", "||", "if (", "isPreview", "canUse"):
                if forbidden in guarded:
                    errors.append(
                        "the Swap entry point must be gated on "
                        "`capability.swappable` and nothing else; found "
                        f"`{forbidden}`"
                    )

    # 4. `lib/integrations/hyperliquid/**` stays unmounted history.
    mounted_paths = [root / "lib/app.dart", root / "lib/main.dart"]
    features_root = root / "lib" / "features"
    if features_root.is_dir():
        mounted_paths.extend(sorted(features_root.rglob("*.dart")))
    exempt_root = root / S5_HYPERLIQUID_UNMOUNTED_EXEMPT_ROOT
    for path in mounted_paths:
        if not path.is_file() or exempt_root in path.parents:
            continue
        executable = strip_dart_comments(read_text(path))
        if re.search(
            r"^\s*import\s+['\"]" + re.escape(S5_HYPERLIQUID_IMPORT_ROOT),
            executable,
            re.MULTILINE,
        ):
            errors.append(
                f"{path.relative_to(root)} imports the retained Hyperliquid "
                "adapters; lib/integrations/hyperliquid/** must stay unmounted "
                "history"
            )

    # 5. The receive QR encoder added no dependency.
    qr_path = root / S5_QR_ENCODER_PATH
    if qr_path.is_file():
        qr_source = strip_dart_comments(read_text(qr_path))
        qr_imports = frozenset(
            " ".join(match.group("body").split())
            for match in re.finditer(
                r"^\s*import\s+(?P<body>[^;]+);", qr_source, re.MULTILINE
            )
        )
        if qr_imports != S5_QR_ENCODER_IMPORTS:
            errors.append(
                "the receive QR encoder must import nothing beyond "
                f"{sorted(S5_QR_ENCODER_IMPORTS)}, found {sorted(qr_imports)}"
            )

    return errors


def check_s7_truth_contract(root: Path) -> list[str]:
    """Lock the step-7 truth rules recorded by decision 0058."""

    errors: list[str] = []

    # 1. Every S7 port stays fail-closed until a real adapter is mounted.
    for relative, provider, port, unavailable in S7_PORT_DEFAULTS:
        path = root / relative
        if not path.is_file():
            errors.append(f"missing S7 port: {relative}")
            continue
        source = strip_dart_comments(read_text(path))
        default_pattern = re.compile(
            rf"final\s+{re.escape(provider)}\s*=\s*Provider<{re.escape(port)}>\s*"
            rf"\(\s*\(\s*ref\s*\)\s*=>\s*const\s+{re.escape(unavailable)}\s*"
            r"\(\s*\)\s*,?\s*\)\s*;",
            re.DOTALL,
        )
        if default_pattern.search(source) is None:
            errors.append(
                f"{provider} must default directly to const {unavailable}(); an "
                "S7 port is unavailable until lib/main.dart mounts its adapter"
            )

    # 2. The em dash is the only S7 placeholder, and it is declared once.
    contract_path = root / S7_CONTRACT_PATH
    if not contract_path.is_file():
        errors.append(f"missing S7 contract: {S7_CONTRACT_PATH}")
    elif S7_MISSING_FIGURE_MARKER not in read_text(contract_path):
        errors.append(
            "lib/features/launch/launch_contract.dart must declare "
            f"`{S7_MISSING_FIGURE_MARKER}`; an S7 metric with no source renders "
            "the em dash and the server's reasonCode, never 0"
        )

    # 3. The prototype口径 the missing 02 document retires never reaches a
    #    mounted Launch, Mining or Referral surface.
    for relative_root in S7_SURFACE_ROOTS:
        surface_root = root / relative_root
        if not surface_root.is_dir():
            errors.append(f"missing S7 surface root: {relative_root}")
            continue
        for path in sorted(surface_root.rglob("*.dart")):
            source = strip_dart_comments(read_text(path))
            for retired in S7_RETIRED_PROTOTYPE_COPY:
                if retired in source:
                    errors.append(
                        f"{path.relative_to(root)} states `{retired}`; the "
                        "Launch contract baseline is undelivered, so no supply, "
                        "tax, cap or address口径 may be rendered"
                    )

    # 4. The graduated Token Card carries no ecosystem-tax label.
    for relative in S7_TOKEN_CARD_PATHS:
        path = root / relative
        if not path.is_file():
            errors.append(f"missing Token Card source: {relative}")
            continue
        if "生态税" in strip_dart_comments(read_text(path)):
            errors.append(
                f"{relative} labels a 生态税 metric; LoopTokenCard.graduated "
                "carries no ecosystem tax while the Launch contract baseline "
                "is undelivered"
            )

    # 5. No Launch surface constructs a transaction or opens the signing sheet.
    #    `loop-stake` is non-executable as a whole page and `launch-trade`
    #    disables its main action on the server's own refusal.
    action_path = root / S7_NON_EXECUTABLE_PATH
    if not action_path.is_file():
        errors.append(f"missing S7 action surface: {S7_NON_EXECUTABLE_PATH}")
    else:
        action_source = strip_dart_comments(read_text(action_path))
        for marker in S7_SIGNING_MARKERS:
            if marker in action_source:
                errors.append(
                    f"{S7_NON_EXECUTABLE_PATH} references `{marker}`; no Launch "
                    "surface may open a signing sheet while the contract "
                    "baseline is undelivered"
                )

    return errors


S6_MONEY_ACTION_PATHS = (
    Path("lib/features/wallet/money_actions_models.dart"),
    Path("lib/features/wallet/money_actions_gateway.dart"),
    Path("lib/features/wallet/money_actions_controllers.dart"),
    Path("lib/features/wallet/money_actions_signing.dart"),
    Path("lib/features/wallet/money_actions_widgets.dart"),
    Path("lib/features/wallet/send_screens.dart"),
    Path("lib/features/wallet/swap_screens.dart"),
    Path("lib/features/wallet/approval_screens.dart"),
    Path("lib/features/wallet/tx_result_screen.dart"),
)
# The exact `eth_sendTransaction` parameter keys, in contract order. The client
# rebuilds the object verbatim and may not add, drop or rename a field.
S6_UNSIGNED_TRANSACTION_KEYS = (
    "chainId",
    "from",
    "to",
    "data",
    "value",
    "gas",
    "nonce",
    "type",
    "maxFeePerGas",
    "maxPriorityFeePerGas",
    "gasPrice",
)


def check_s6_money_action_contract(root: Path) -> list[str]:
    """Lock the step-6 money-action truth rules (decision 0059)."""

    errors = require_fragments(
        root,
        {
            "lib/core/intent/signing_intent.dart": (
                "factory SigningIntent.backendCanonical",
                "required String payloadDigest",
                "sealed class SigningPayload",
                "final class DeviceTransactionPayload extends SigningPayload",
                "final class AuthorizationSignaturePayload extends SigningPayload",
            ),
            "lib/integrations/privy/wallet_signing_gateway.dart": (
                "String? walletHandoffRefusal(",
                "if (intent.isLocalPreview) return 'canonical_intent_required';",
            ),
            "lib/integrations/privy/privy_device_signer.dart": (
                "eth_sendTransaction",
                "generateAuthorizationSignature",
                "privy_wallet_mismatch",
            ),
            "lib/features/wallet/money_actions_signing.dart": (
                "if (!intent.canSignAt(now))",
                "if (!intent.payloadMatchesReview)",
                "SigningIntent.backendCanonical(",
            ),
            "lib/features/wallet/tx_result_screen.dart": (
                "intent.state == LoopIntentState.confirmed",
            ),
            # The approval inventory is only complete from its coverage start:
            # the page states that height rather than implying full history.
            "lib/features/wallet/money_actions_models.dart": (
                "approvalCoverageFromBlockNumber",
            ),
            "lib/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart": (
                "'approvalCoverageFromBlockNumber',",
            ),
            "lib/features/wallet/approval_screens.dart": (
                "授权记录自区块 ",
            ),
            # A refusal is only explainable when the rule is named, and the
            # scalar slots it travels in are read through an allowlist.
            "lib/integrations/backend/loop_backend_failure.dart": (
                "final class LoopFailureDetails",
                "static LoopFailureDetails? tryRead(Object? raw)",
            ),
            "lib/integrations/privy/privy_device_signer.dart": (
                "String privyWalletFailureCode(String message)",
                "return 'wallet_outcome_unknown';",
            ),
        },
    )

    # 6. The signing exit locks once the wallet has been opened.
    sheet_path = root / "lib/features/wallet/money_actions_widgets.dart"
    if sheet_path.is_file():
        source = strip_dart_comments(read_text(sheet_path))
        for fragment, message in (
            (
                "isDismissible: false",
                "the signing sheet must not be dismissible by a tap or a drag",
            ),
            (
                "canPop: _state != LoopSignSheetState.signing",
                "the signing sheet must refuse to pop while the wallet is open",
            ),
            (
                "widget.latch?.enteredSigning = true",
                "the signing sheet must record that the wallet was opened, so a "
                "torn-down sheet cannot read as a cancellation",
            ),
        ):
            if fragment not in source:
                errors.append(message)
        confirm_start = source.find("Future<void> _confirm()")
        confirm_end = source.find("Widget build(BuildContext context)", confirm_start)
        confirm = source[confirm_start:confirm_end] if confirm_start >= 0 else ""
        refused_at = confirm.find("case MoneySignStatus.reportRefused:")
        next_case = confirm.find("case MoneySignStatus.", refused_at + 10)
        branch = confirm[refused_at:next_case] if refused_at >= 0 else ""
        if not branch:
            errors.append(
                "the signing sheet must handle MoneySignStatus.reportRefused"
            )
        elif "_submitted = false" in branch:
            errors.append(
                "a refused report must never re-enable the confirmation: the "
                "wallet already produced a result"
            )

    # 7. Nothing after a successful handoff may report that nothing happened.
    signer_path = root / "lib/features/wallet/money_actions_signing.dart"
    if signer_path.is_file():
        source = strip_dart_comments(read_text(signer_path))
        marker = source.find("final produced = handoff.value!;")
        if marker < 0:
            errors.append(
                "the signing exit must bind the wallet result before reporting "
                "it, so every later failure is known to follow a broadcast"
            )
        else:
            after = source[marker:]
            if "MoneySignStatus.walletRejected" in after:
                errors.append(
                    "a failure after a successful handoff must never project as "
                    "walletRejected: the wallet already produced a result"
                )
            if after.count("MoneySignStatus.reportRefused") < 2:
                errors.append(
                    "both the failure and the catch-all after a handoff must "
                    "project as reportRefused"
                )

    # 1. `backendCanonical` is the only origin a wallet may ever receive, and
    #    only one factory may produce it.
    intent_path = root / "lib/core/intent/signing_intent.dart"
    if intent_path.is_file():
        source = strip_dart_comments(read_text(intent_path))
        if source.count("origin: IntentOrigin.backendCanonical") != 1:
            errors.append(
                "exactly one SigningIntent factory may set "
                "IntentOrigin.backendCanonical"
            )
        for marker in (
            "payload != null",
            "payloadDigest != null",
        ):
            if marker not in source:
                errors.append(
                    "allowsWalletHandoff must require a canonical payload and "
                    f"its digest: {marker}"
                )

    # 2. The signed transaction is rebuilt with the contract's exact keys.
    models_path = root / "lib/features/wallet/money_actions_models.dart"
    if models_path.is_file():
        source = strip_dart_comments(read_text(models_path))
        start = source.find("Map<String, Object?> toWire()")
        wire = source[start : source.find("}", start)] if start >= 0 else ""
        declared = tuple(re.findall(r"'([A-Za-z]+)':", wire))
        if declared != S6_UNSIGNED_TRANSACTION_KEYS:
            errors.append(
                "LoopUnsignedTransaction.toWire must emit exactly the "
                f"contract's {len(S6_UNSIGNED_TRANSACTION_KEYS)} keys in order; "
                f"found {list(declared)}"
            )

    # 3. The money-action feature files stay port-only: no transport, no route
    #    literal, no fixture.
    for relative in S6_MONEY_ACTION_PATHS:
        path = root / relative
        if not path.is_file():
            errors.append(f"missing S6 money-action file: {relative}")
            continue
        source = strip_dart_comments(read_text(path))
        for marker in ("package:dio/", "'/v2/", '"/v2/', "演示数据"):
            if marker in source:
                errors.append(
                    f"{relative} must stay a port consumer without transport "
                    f"or fixture detail: {marker}"
                )

    # 4. Unlimited approval travels only with its acknowledgement.
    api_path = root / (
        "lib/integrations/backend/v2/wallet_intents/"
        "loop_v2_wallet_intents_api.dart"
    )
    if api_path.is_file():
        source = strip_dart_comments(read_text(api_path))
        if (
            "if (allowance is LoopUnlimitedAllowanceRequest)\n"
            "        'acknowledgeUnlimited': true," not in source
            and "'acknowledgeUnlimited': true" not in source
        ):
            errors.append(
                "an unlimited allowance must carry acknowledgeUnlimited: true"
            )
        if "'acknowledgeUnlimited': false" in source:
            errors.append(
                "acknowledgeUnlimited is a confirmation, never a default false"
            )

    # 5. The Swap confirmation waits on the capability *and* its evidence.
    swap_path = root / "lib/features/wallet/swap_screens.dart"
    if swap_path.is_file():
        source = strip_dart_comments(read_text(swap_path))
        if "capability.isUsable" not in source:
            errors.append(
                "the Swap confirmation must be gated on capability.isUsable, "
                "which folds in the pending device evidence"
            )
        if "兑换还在验证中" not in source:
            errors.append(
                "the Swap confirmation must name the pending device evidence"
            )

    return errors


# --- S9 · dual chain slots (decision 0062 / loop-api 0038) -------------------
# LOOP has exactly two named chain slots. The primary chain never moves; the
# Launch slot alone may point at the BSC testnet, and it is published by the
# backend rather than chosen by the client.
S9_CHAIN_IDS_PATH = Path("lib/core/chain/loop_chain_ids.dart")
S9_PRIMARY_CHAIN_ID = "eip155:56"
# Every `eip155:<reference>` the identity file names, so the closed set is
# checked as a set rather than against a blocklist someone has to keep current.
S9_CHAIN_REFERENCE_PATTERN = re.compile(r"eip155:(\d+)")
S9_ALLOWED_CHAIN_REFERENCES = {56, 97}
S9_LAUNCH_TESTNET_CHAIN_ID = "eip155:97"
# The testnet chain id is declared once. Every other file names the constant,
# so a new surface cannot acquire a second chain by pasting a literal.
S9_TESTNET_LITERAL_ALLOWED = (Path("lib/core/chain/loop_chain_ids.dart"),)
# Market, Watchlist, Swap, Send and approvals are bound to the primary chain.
# None of them may reference the Launch slot, its badge or its explanation.
S9_PRIMARY_ONLY_PATHS = (
    Path("lib/features/market"),
    Path("lib/features/wallet/swap_screens.dart"),
    Path("lib/features/wallet/send_screens.dart"),
    Path("lib/features/wallet/approval_screens.dart"),
)
S9_TESTNET_MARKERS = (
    "loopLaunchTestnetChainId",
    "LoopTestnetBadge",
    "loopTestnetBadgeLabel",
    "LoopTestnetNotice",
    S9_LAUNCH_TESTNET_CHAIN_ID,
)
# The signing exit carries the chain and refuses to leave the primary chain
# for anything but a Launch intent.
S9_SIGNING_INTENT_PATH = Path("lib/core/intent/signing_intent.dart")
S9_SIGNING_INTENT_MARKERS = (
    "IntentKind.launchPurchase",
    "chainIsPermitted",
    "launchPurchase",
)
# privy_flutter 0.10.1 exposes no chain-selection call, so the device signer
# fails closed off the primary chain instead of broadcasting blind.
S9_DEVICE_SIGNER_PATH = Path("lib/integrations/privy/privy_device_signer.dart")
S9_DEVICE_SIGNER_MARKERS = (
    "privy_chain_switch_unsupported",
    "privy_chain_mismatch",
)
# Money intents are locked to the primary chain by the transport itself.
S9_INTENT_CODEC_PATH = Path(
    "lib/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart"
)


def check_s9_dual_chain_contract(root: Path) -> list[str]:
    """Lock the two chain slots recorded by decision 0062."""

    errors: list[str] = []

    # 1. The chain identities are declared once, and there are exactly two.
    chain_ids_path = root / S9_CHAIN_IDS_PATH
    if not chain_ids_path.is_file():
        errors.append(f"missing chain identity source: {S9_CHAIN_IDS_PATH}")
    else:
        source = strip_dart_comments(read_text(chain_ids_path))
        for expected in (
            f"const String loopPrimaryChainId = '{S9_PRIMARY_CHAIN_ID}';",
            "const String loopLaunchTestnetChainId = "
            f"'{S9_LAUNCH_TESTNET_CHAIN_ID}';",
        ):
            if expected not in source:
                errors.append(
                    f"{S9_CHAIN_IDS_PATH} must declare `{expected}`; the two "
                    "chain slots are named constants, never inline literals"
                )
        # Every EIP-155 reference the file names, deduplicated. Enumerating a
        # blocklist would only catch the chains someone thought of; the whole
        # rule is that the set is closed, so the set itself is what is checked.
        references = {
            int(match)
            for match in S9_CHAIN_REFERENCE_PATTERN.findall(source)
        }
        if references != S9_ALLOWED_CHAIN_REFERENCES:
            unexpected = sorted(references - S9_ALLOWED_CHAIN_REFERENCES)
            missing = sorted(S9_ALLOWED_CHAIN_REFERENCES - references)
            errors.append(
                f"{S9_CHAIN_IDS_PATH} names EIP-155 chains "
                f"{sorted(references)}; LOOP has exactly two chain slots "
                f"({sorted(S9_ALLOWED_CHAIN_REFERENCES)}) and no chain list"
                + (f"; unexpected {unexpected}" if unexpected else "")
                + (f"; missing {missing}" if missing else "")
            )

    # 2. The testnet literal exists in exactly one file.
    lib_root = root / "lib"
    if lib_root.is_dir():
        for path in sorted(lib_root.rglob("*.dart")):
            relative = path.relative_to(root)
            if relative in S9_TESTNET_LITERAL_ALLOWED:
                continue
            if S9_LAUNCH_TESTNET_CHAIN_ID in strip_dart_comments(
                read_text(path)
            ):
                errors.append(
                    f"{relative} writes the literal "
                    f"`{S9_LAUNCH_TESTNET_CHAIN_ID}`; use "
                    "loopLaunchTestnetChainId so the slot stays declared once"
                )

    # 3. The primary-chain surfaces never learn about the Launch slot.
    for relative in S9_PRIMARY_ONLY_PATHS:
        target = root / relative
        if not target.exists():
            errors.append(f"missing primary-chain surface: {relative}")
            continue
        paths = (
            sorted(target.rglob("*.dart")) if target.is_dir() else [target]
        )
        for path in paths:
            source = strip_dart_comments(read_text(path))
            for marker in S9_TESTNET_MARKERS:
                if marker in source:
                    errors.append(
                        f"{path.relative_to(root)} references `{marker}`; "
                        "Market, Watchlist, Swap, Send and approvals are bound "
                        "to the primary chain and never render the Launch slot"
                    )

    # 4. The signing intent carries its chain and refuses to leave the primary
    #    chain for anything but a Launch intent.
    intent_path = root / S9_SIGNING_INTENT_PATH
    if not intent_path.is_file():
        errors.append(f"missing signing intent: {S9_SIGNING_INTENT_PATH}")
    else:
        source = strip_dart_comments(read_text(intent_path))
        for marker in S9_SIGNING_INTENT_MARKERS:
            if marker not in source:
                errors.append(
                    f"{S9_SIGNING_INTENT_PATH} must declare `{marker}`; only a "
                    "Launch intent may ever be signed off the primary chain"
                )

    # 5. The device signer fails closed on a chain it cannot select.
    signer_path = root / S9_DEVICE_SIGNER_PATH
    if not signer_path.is_file():
        errors.append(f"missing device signer: {S9_DEVICE_SIGNER_PATH}")
    else:
        source = strip_dart_comments(read_text(signer_path))
        for marker in S9_DEVICE_SIGNER_MARKERS:
            if marker not in source:
                errors.append(
                    f"{S9_DEVICE_SIGNER_PATH} must refuse with `{marker}`; "
                    "privy_flutter 0.10.1 exposes no chain-selection call, so "
                    "a non-primary chain fails closed"
                )

    # 6. The money-intent transport pins the primary chain.
    codec_path = root / S9_INTENT_CODEC_PATH
    if not codec_path.is_file():
        errors.append(f"missing intent codec: {S9_INTENT_CODEC_PATH}")
    else:
        source = strip_dart_comments(read_text(codec_path))
        if "_primaryChainId(" not in source or (
            "_primaryChainReference(" not in source
        ):
            errors.append(
                f"{S9_INTENT_CODEC_PATH} must pin send/approve/revoke/swap to "
                "the primary chain; a money payload on another chain is an "
                "invalid payload, not a signable one"
            )

    return errors


def check_providerless_application_contract(root: Path) -> list[str]:
    """Keep transport and deterministic fakes outside production features."""

    errors: list[str] = []
    features_root = root / "lib" / "features"
    if features_root.is_dir():
        for path in sorted(features_root.rglob("*.dart")):
            executable = strip_dart_comments(read_text(path))
            relative = path.relative_to(root)
            executable_code = strip_dart_comments_and_strings(read_text(path))
            for marker in FEATURE_TRANSPORT_FORBIDDEN_IMPORTS:
                if marker in executable:
                    errors.append(
                        f"{relative} imports transport `{marker}`; providerless feature "
                        "logic must depend on a narrow port"
                    )
            if FEATURE_TRANSPORT_FORBIDDEN_TYPE_PATTERN.search(executable_code):
                errors.append(
                    f"{relative} names the transport type `Dio`; feature logic must "
                    "depend on a narrow port"
                )
            route_literal = FEATURE_BACKEND_ROUTE_PATTERN.search(executable)
            if route_literal:
                version = route_literal.group("version")
                errors.append(
                    f"{relative} contains a LOOP backend route literal; `/v{version}/` "
                    "paths belong only in integration adapters"
                )

    production_main = root / "lib" / "main.dart"
    if production_main.is_file():
        executable = strip_dart_comments(read_text(production_main))
        for marker in PRODUCTION_FIXTURE_MARKERS:
            if marker in executable:
                errors.append(
                    f"lib/main.dart composes preview fixture `{marker}`; deterministic "
                    "fakes belong only in tests or lib/main_preview.dart"
                )
    return errors


def check_watchlist_application_contract(root: Path) -> list[str]:
    """Keep providerless Watchlist state owner-local and fail-closed."""

    errors: list[str] = []
    gateway_path = root / WATCHLIST_GATEWAY_PATH
    if gateway_path.is_file():
        gateway = strip_dart_comments(read_text(gateway_path))
        default_pattern = re.compile(
            r"final\s+watchlistGatewayProvider\s*=\s*Provider<WatchlistGateway>\s*"
            r"\(\s*\(\s*ref\s*\)\s*=>\s*const\s+UnavailableWatchlistGateway\s*"
            r"\(\s*\)\s*,?\s*\)\s*;",
            re.DOTALL,
        )
        if default_pattern.search(gateway) is None:
            errors.append(
                "Watchlist production provider must default directly to "
                "const UnavailableWatchlistGateway()"
            )

    models_path = root / WATCHLIST_MODELS_PATH
    if models_path.is_file():
        models_code = strip_dart_comments_and_strings(read_text(models_path))
        volatile_members = sorted(
            set(WATCHLIST_VOLATILE_FACT_MEMBER_PATTERN.findall(models_code))
        )
        if volatile_members:
            errors.append(
                "Watchlist models may contain only owner-local ordered asset "
                "references, not volatile market facts: "
                + ", ".join(volatile_members)
            )

    # The Preview Watchlist adapter and its composition rule retired with
    # step 5; the port's fail-closed default is guarded by
    # `check_s5_truth_contract`.
    return errors


def check_profile_application_contract(root: Path) -> list[str]:
    """Keep Profile presentation exact, unavailable, and evidence-backed."""

    errors: list[str] = []
    gateway_path = root / PROFILE_GATEWAY_PATH
    if gateway_path.is_file():
        gateway = strip_dart_comments(read_text(gateway_path))
        default_pattern = re.compile(
            r"final\s+profileGatewayProvider\s*=\s*Provider<ProfileGateway>\s*"
            r"\(\s*\(\s*ref\s*\)\s*=>\s*const\s+UnavailableProfileGateway\s*"
            r"\(\s*\)\s*,?\s*\)\s*;",
            re.DOTALL,
        )
        if default_pattern.search(gateway) is None:
            errors.append(
                "Profile production provider must default directly to "
                "const UnavailableProfileGateway()"
            )

    models_path = root / PROFILE_MODELS_PATH
    if models_path.is_file():
        models_code = strip_dart_comments_and_strings(read_text(models_path))
        actual_values_fields = dart_class_fields(models_code, "ProfileValues")
        # Decision 0053: the V2 profile resource adds bio and the closed
        # interest enumeration. The set stays exact so an unreviewed field
        # cannot appear.
        expected_values_fields = {
            ("final", "String?", "alias"),
            ("final", "String?", "avatarRef"),
            ("final", "String?", "bio"),
            ("final", "List<ProfileInterest>", "interests"),
        }
        if actual_values_fields != expected_values_fields:
            rendered_fields = ", ".join(
                f"{modifiers} {field_type} {name}".strip()
                for modifiers, field_type, name in sorted(
                    actual_values_fields or set()
                )
            ) or "none"
            errors.append(
                "ProfileValues fields must be exactly nullable String alias, "
                "nullable String avatarRef, nullable String bio and a closed "
                "ProfileInterest list; found: " + rendered_fields
            )
        actual_resource_fields = dart_class_fields(
            models_code, "ProfileResource"
        )
        # Decision 0053: the server-owned identity fields join the resource.
        # loopId stays nullable only because the frozen V1 transport has none.
        expected_resource_fields = {
            ("final", "int", "version"),
            ("final", "ProfileValues", "values"),
            ("final", "DateTime?", "updatedAt"),
            ("final", "String?", "loopId"),
            ("final", "ProfileStatus", "profileStatus"),
            ("final", "DateTime?", "activatedAt"),
        }
        if actual_resource_fields != expected_resource_fields:
            rendered_fields = ", ".join(
                f"{modifiers} {field_type} {name}".strip()
                for modifiers, field_type, name in sorted(
                    actual_resource_fields or set()
                )
            ) or "none"
            errors.append(
                "ProfileResource fields must be exactly final int version, "
                "final ProfileValues values, final nullable DateTime updatedAt, "
                "final nullable String loopId, final ProfileStatus "
                "profileStatus and final nullable DateTime activatedAt; "
                "found: " + rendered_fields
            )

    # Decision 0053: the Profile edit surface lives in profile_v2_screens.
    surface_path = root / PROFILE_V2_SURFACE_PATH
    if surface_path.is_file():
        surface = strip_dart_comments(read_text(surface_path))
        # Constraint 10: a Preview session must say so on every V2 page that
        # reads an owner resource, and the label must be derived from the
        # gateway mode so it can never appear in production.
        if "String? loopPreviewKicker(bool isPreview)" not in surface:
            errors.append(
                "the V2 Profile pages must derive the Preview label from a "
                "single mode projection"
            )
        # The build lives in the State class, so the slice starts there.
        for page, mode in (
            ("class _ProfileHomeScreenState", "ProfileMode.preview"),
            ("class _ProfileEditScreenState", "ProfileMode.preview"),
            ("class _PrivacyCenterScreenState", "PrivacyMode.preview"),
        ):
            page_start = surface.find(page)
            page_end = surface.find("\nclass ", page_start + 1)
            page_slice = (
                surface[page_start : page_end if page_end > 0 else len(surface)]
                if page_start >= 0
                else ""
            )
            if (
                f"state.mode == {mode}" not in page_slice
                or "loopPreviewKicker(" not in page_slice
                or "LoopPreviewModeNotice(" not in page_slice
            ):
                errors.append(
                    f"{page[7:]} must label a Preview session with both the "
                    "kicker and the visible notice"
                )
        if re.search(r"['\"]开发预览['\"]", surface) and (
            "isPreview ? '开发预览' : null" not in surface
        ):
            errors.append(
                "the Preview label must never be written outside the mode "
                "projection"
            )
        edit_start = surface.find("class ProfileEditScreen")
        privacy_start = surface.find("class PrivacyCenterScreen", edit_start)
        edit_surface = (
            surface[edit_start:privacy_start]
            if edit_start >= 0 and privacy_start > edit_start
            else ""
        )
        if not edit_surface:
            errors.append(
                "Profile edit must remain one bounded reviewed surface in "
                f"{PROFILE_V2_SURFACE_PATH}"
            )
        if re.search(r"\b(?:ScaffoldMessenger|SnackBar)\b", edit_surface):
            errors.append(
                "Profile edit must derive save evidence from ProfileState and "
                "must not emit ad-hoc SnackBar success announcements"
            )

    preview_root = root / PROFILE_PREVIEW_ROOT_PATH
    if preview_root.is_file():
        preview_code = strip_dart_comments_and_strings(read_text(preview_root))
        if len(PROFILE_MEMORY_CONSTRUCTION_PATTERN.findall(preview_code)) != 1:
            errors.append(
                "lib/main_preview.dart must compose exactly one explicit "
                "MemoryProfileGateway"
            )

    lib_root = root / "lib"
    if lib_root.is_dir():
        allowed = frozenset({PROFILE_MEMORY_GATEWAY_PATH, PROFILE_PREVIEW_ROOT_PATH})
        for path in sorted(lib_root.rglob("*.dart")):
            relative = path.relative_to(root)
            if relative in allowed:
                continue
            executable_code = strip_dart_comments_and_strings(read_text(path))
            if PROFILE_MEMORY_REFERENCE_PATTERN.search(executable_code):
                errors.append(
                    f"{relative} references MemoryProfileGateway; the fake may "
                    "only be defined by its integration and composed by "
                    "lib/main_preview.dart"
                )

    profile_feature_root = root / "lib" / "features" / "profile"
    if profile_feature_root.is_dir():
        for path in sorted(profile_feature_root.rglob("*.dart")):
            source = read_text(path)
            if contains_positive_profile_save_language(source):
                errors.append(
                    f"{path.relative_to(root)} contains positive Profile save "
                    "language; committed-resource state is the only allowed "
                    "save evidence"
                )
    return errors


def check_privacy_application_contract(root: Path) -> list[str]:
    """Keep Privacy preferences exact, unavailable, and non-authoritative."""

    errors: list[str] = []
    gateway_path = root / PRIVACY_GATEWAY_PATH
    if gateway_path.is_file():
        gateway = strip_dart_comments(read_text(gateway_path))
        default_pattern = re.compile(
            r"final\s+privacyGatewayProvider\s*=\s*Provider<PrivacyGateway>\s*"
            r"\(\s*\(\s*ref\s*\)\s*=>\s*const\s+UnavailablePrivacyGateway\s*"
            r"\(\s*\)\s*,?\s*\)\s*;",
            re.DOTALL,
        )
        if default_pattern.search(gateway) is None:
            errors.append(
                "Privacy production provider must default directly to "
                "const UnavailablePrivacyGateway()"
            )

    models_path = root / PRIVACY_MODELS_PATH
    if models_path.is_file():
        models_source = strip_dart_comments(read_text(models_path))
        models_code = strip_dart_comments_and_strings(models_source)
        # Decision 0053: V2 privacy replaced the copy-trade preference with a
        # closed audience enumeration and four independent visibility facets.
        # Copytrade is retired and must never reappear here.
        if re.search(r"\bCopyTradeVisibility\b", models_code):
            errors.append(
                "copy-trade visibility is retired and must not return to the "
                "Privacy contract"
            )
        audience_match = re.search(
            r"enum\s+PrivacyAudience\s*\{(?P<body>.*?)\s*;",
            models_source,
            re.DOTALL,
        )
        audience_members = (
            {
                re.split(r"[(\s]", member.strip(), maxsplit=1)[0]
                for member in audience_match.group("body").split(",")
                if member.strip()
            }
            if audience_match
            else set()
        )
        if audience_members != set(PRIVACY_AUDIENCE_WIRE_VALUES):
            errors.append(
                "PrivacyAudience must contain exactly self and everyone"
            )
        audience_wire_values = {
            member: wire_value
            for member, _, wire_value in re.findall(
                r"\b(\w+)\((['\"])([^'\"]*)\2\)",
                audience_match.group("body") if audience_match else "",
            )
        }
        if audience_wire_values != PRIVACY_AUDIENCE_WIRE_VALUES:
            errors.append(
                "PrivacyAudience wire values must map exactly to self and "
                "everyone"
            )
        facet_match = re.search(
            r"enum\s+PrivacyVisibilityFacet\s*\{(?P<body>.*?)\s*;",
            models_source,
            re.DOTALL,
        )
        facet_wire_values = [
            wire_value
            for _, _, wire_value in re.findall(
                r"\b(\w+)\((['\"])([^'\"]*)\2\s*,",
                facet_match.group("body") if facet_match else "",
            )
        ]
        if facet_wire_values != list(PRIVACY_VISIBILITY_FACETS):
            errors.append(
                "PrivacyVisibilityFacet must be exactly totalAssets, "
                "miningPower, communities and tradeHistory, in contract order"
            )
        actual_visibility_fields = dart_class_fields(
            models_code, "PrivacyVisibility"
        )
        expected_visibility_fields = {
            ("final", "PrivacyAudience", facet)
            for facet in PRIVACY_VISIBILITY_FACETS
        }
        if actual_visibility_fields != expected_visibility_fields:
            errors.append(
                "PrivacyVisibility must hold exactly one PrivacyAudience per "
                "reviewed facet"
            )

        gate_match = re.search(
            r"enum\s+PrivacySocialGate\s*\{(?P<body>.*?)\s*;",
            models_source,
            re.DOTALL,
        )
        gate_wire_values = {
            wire_value: open_value
            for _, _, wire_value, _, open_value in re.findall(
                r"\b(\w+)\((['\"])([^'\"]*)\2\s*,\s*(['\"])([^'\"]*)\4",
                gate_match.group("body") if gate_match else "",
            )
        }
        if gate_wire_values != PRIVACY_SOCIAL_GATES:
            errors.append(
                "PrivacySocialGate must be exactly friendRequests (enabled), "
                "directMessages (friends) and groupInvites (friends)"
            )
        if not re.search(
            r"static\s+const\s+String\s+closedWireValue\s*=\s*'disabled'",
            models_source,
        ):
            errors.append(
                "PrivacySocialGate must keep disabled as the only closed wire "
                "value"
            )
        actual_gate_fields = dart_class_fields(
            models_code, "PrivacySocialGates"
        )
        expected_gate_fields = {
            ("final", "bool", gate) for gate in PRIVACY_SOCIAL_GATES
        }
        if actual_gate_fields != expected_gate_fields:
            errors.append(
                "PrivacySocialGates must hold exactly one bool per reviewed "
                "gate"
            )
        # A missing server row means open, so the client's version-0
        # projection reports the gates the admission checks already apply.
        defaults_match = re.search(
            r"const\s+PrivacySocialGates\.defaults\(\)\s*:(?P<body>.*?);",
            models_source,
            re.DOTALL,
        )
        defaults_body = defaults_match.group("body") if defaults_match else ""
        if any(
            not re.search(rf"\b{gate}\s*=\s*true\b", defaults_body)
            for gate in PRIVACY_SOCIAL_GATES
        ):
            errors.append(
                "PrivacySocialGates defaults must be open on every gate "
                "(decision 0070)"
            )

        actual_values_fields = dart_class_fields(models_code, "PrivacyValues")
        expected_values_fields = {
            ("final", "bool", "discoverable"),
            ("final", "bool", "anonymousMode"),
            ("final", "PrivacyVisibility", "visibility"),
            ("final", "PrivacySocialGates", "social"),
        }
        if actual_values_fields != expected_values_fields:
            rendered_fields = ", ".join(
                f"{modifiers} {field_type} {name}".strip()
                for modifiers, field_type, name in sorted(
                    actual_values_fields or set()
                )
            ) or "none"
            errors.append(
                "PrivacyValues fields must be exactly final bool discoverable, "
                "final bool anonymousMode, final PrivacyVisibility visibility "
                "and final PrivacySocialGates social; found: "
                + rendered_fields
            )

        actual_resource_fields = dart_class_fields(
            models_code, "PrivacyResource"
        )
        expected_resource_fields = {
            ("final", "int", "version"),
            ("final", "PrivacyValues", "values"),
            ("final", "DateTime?", "updatedAt"),
        }
        if actual_resource_fields != expected_resource_fields:
            rendered_fields = ", ".join(
                f"{modifiers} {field_type} {name}".strip()
                for modifiers, field_type, name in sorted(
                    actual_resource_fields or set()
                )
            ) or "none"
            errors.append(
                "PrivacyResource fields must be exactly final int version, "
                "final PrivacyValues values, and final nullable DateTime "
                "updatedAt; found: "
                + rendered_fields
            )

    surface_path = root / PRIVACY_SURFACE_PATH
    if surface_path.is_file():
        surface = strip_dart_comments(read_text(surface_path))
        privacy_start = surface.find("class _PrivacyCenter")
        privacy_end = surface.find("class _PrivacyModeBanner", privacy_start)
        privacy_surface = (
            surface[privacy_start:privacy_end]
            if privacy_start >= 0 and privacy_end > privacy_start
            else ""
        )
        for marker in PRIVACY_LEGACY_MARKERS:
            if marker in privacy_surface:
                errors.append(
                    "Privacy Center contains removed non-contract state or copy: "
                    + marker
                )
        if re.search(r"\b(?:ScaffoldMessenger|SnackBar)\b", privacy_surface):
            errors.append(
                "Privacy Center must derive commit evidence from PrivacyState "
                "and must not emit ad-hoc SnackBar announcements"
            )

        copy_start = surface.find("class _CopyTradePermissions")
        copy_end = surface.find("class _SecurityCenter", copy_start)
        copy_surface = (
            surface[copy_start:copy_end]
            if copy_start >= 0 and copy_end > copy_start
            else ""
        )
        copy_executable = strip_dart_comments_and_strings(copy_surface)
        if PRIVACY_COPY_INTERACTION_PATTERN.search(copy_executable):
            errors.append(
                "Copy-trade permissions must remain a non-actionable truthful "
                "placeholder until an authorization contract exists"
            )
        for marker in PRIVACY_COPY_PERMISSION_MARKERS:
            if marker in copy_surface:
                errors.append(
                    "Copy-trade placeholder contains unsupported permission UI: "
                    + marker
                )

    preview_root = root / PRIVACY_PREVIEW_ROOT_PATH
    if preview_root.is_file():
        preview_code = strip_dart_comments_and_strings(read_text(preview_root))
        if len(PRIVACY_MEMORY_CONSTRUCTION_PATTERN.findall(preview_code)) != 1:
            errors.append(
                "lib/main_preview.dart must compose exactly one explicit "
                "MemoryPrivacyGateway"
            )

    lib_root = root / "lib"
    if lib_root.is_dir():
        allowed = frozenset({
            PRIVACY_MEMORY_GATEWAY_PATH,
            PRIVACY_PREVIEW_ROOT_PATH,
        })
        for path in sorted(lib_root.rglob("*.dart")):
            relative = path.relative_to(root)
            if relative in allowed:
                continue
            executable_code = strip_dart_comments_and_strings(read_text(path))
            if PRIVACY_MEMORY_REFERENCE_PATTERN.search(executable_code):
                errors.append(
                    f"{relative} references MemoryPrivacyGateway; the fake may "
                    "only be defined by its integration and composed by "
                    "lib/main_preview.dart"
                )

    profile_feature_root = root / "lib" / "features" / "profile"
    # Step 5 gave `notif-settings` its own contract: it commits under a version
    # CAS and reports the resource the server returned, which the Privacy
    # commit rule — written for a surface with no committed resource at all —
    # would misread. `check_notification_preferences_application_contract` owns
    # that page's copy.
    notification_preferences_root = (
        profile_feature_root / "notification_preferences"
    )
    if profile_feature_root.is_dir():
        for path in sorted(profile_feature_root.rglob("*.dart")):
            if notification_preferences_root in path.parents:
                continue
            source = read_text(path)
            if contains_positive_privacy_commit_language(source):
                errors.append(
                    f"{path.relative_to(root)} contains positive Privacy commit "
                    "language; committed-resource state is the only allowed "
                    "evidence"
                )

    errors.extend(check_behavior_test_evidence(root, PRIVACY_BEHAVIOR_TEST_MARKERS))
    return errors


def check_notification_preferences_application_contract(root: Path) -> list[str]:
    """Keep H9 preferences exact, fail-closed, and delivery-neutral.

    Step 5 retired the V1 module (gateway, models, controller and Preview
    adapter) with decision 0057: `notif-settings` is now the V2 ten-category
    page behind `NotificationsGateway`, whose fail-closed default is guarded by
    `check_s5_truth_contract`. What survives here is the copy contract.
    """

    errors: list[str] = []
    surface_path = root / NOTIFICATION_PREFERENCES_SURFACE_PATH
    if not surface_path.is_file():
        return [
            "missing notification preferences surface: "
            f"{NOTIFICATION_PREFERENCES_SURFACE_PATH}"
        ]

    surface = strip_dart_comments(read_text(surface_path))
    executable_surface = strip_dart_comments_and_strings(surface)
    visible_strings = dart_concatenated_string_contents(surface)
    for marker in NOTIFICATION_PREFERENCES_LEGACY_MARKERS:
        present = (
            marker in executable_surface
            if marker.startswith("_")
            else any(marker in content for content in visible_strings)
        )
        if present:
            errors.append(
                "Notification Preferences contains removed local or "
                "non-contract H9 state/copy: " + marker
            )

    feature_root = root / "lib" / "features" / "profile" / "notification_preferences"
    if feature_root.is_dir():
        for path in sorted(feature_root.rglob("*.dart")):
            source = read_text(path)
            relative = path.relative_to(root)
            # A delivery claim has no evidence at all: `push` is permanently
            # `PUSH_RUNTIME_DEFERRED`, so nothing may say a notification is
            # enabled, connected, or on its way.
            if contains_positive_notification_delivery_language(source):
                errors.append(
                    f"{relative} contains positive delivery language; "
                    "PUSH_RUNTIME_DEFERRED never becomes a delivery claim"
                )
            # A save claim is allowed only where it reports the resource the
            # server committed under the version CAS, on a page that also
            # states delivery is unavailable.
            if contains_positive_notification_preferences_commit_language(
                source
            ) and not notification_preferences_commit_evidence(source):
                errors.append(
                    f"{relative} announces a save without a committed "
                    "resource; a stored intent never proves a commit"
                )

    # The reviewed page must keep both halves of that truth visible.
    for marker in NOTIFICATION_PREFERENCES_DELIVERY_TRUTH_MARKERS:
        if marker not in surface:
            errors.append(
                "Notification Preferences must state that delivery is "
                f"unavailable; missing `{marker}`"
            )
    for fragment in (
        "LoopV2CapabilityId.notificationsFeed",
        "notificationPreferencesControllerProvider",
        "resource.lockedFor(category)",
    ):
        if fragment not in surface:
            errors.append(
                "Notification Preferences is missing its reviewed V2 contract "
                f"value `{fragment}`"
            )

    errors.extend(
        check_behavior_test_evidence(
            root, NOTIFICATION_PREFERENCES_BEHAVIOR_TEST_MARKERS
        )
    )
    return errors



def check_perp_positions_application_contract(root: Path) -> list[str]:
    """Keep production D4 principal-bound, short-lived, and preview-free."""

    errors: list[str] = []
    for relative, markers in PERP_POSITIONS_BEHAVIOR_TEST_MARKERS.items():
        configured = PERP_POSITIONS_EXECUTABLE_TEST_EVIDENCE.get(relative, {})
        missing = sorted(set(markers).difference(configured))
        unexpected = sorted(set(configured).difference(markers))
        if missing or unexpected:
            errors.append(
                f"{relative} Perp Positions behavior/evidence keys differ: "
                f"missing={missing}, unexpected={unexpected}"
            )

    errors.extend(require_fragments(
        root,
        {
            str(PERP_POSITIONS_CONTROLLER_PATH): (
                "static const int initialLimit = 2;",
                "gateway.listPositions(limit: initialLimit)",
                "gateway.listPositions(cursor: cursor)",
                "PerpGatewayFailureKind.walletBindingRequired",
                "void expireIfNeeded()",
                "_generation += 1;",
            ),
            str(PERP_POSITIONS_SURFACE_PATH): (
                "ref.watch(developmentPreviewEnabledProvider)",
                "perp-preview-positions",
                "开发预览",
                "perp-live-positions",
                "perp-position-live-unavailable",
                "Review in Perp account",
                "await context.push<void>('/perp/account');",
                "LOADED · FRESH",
                "perp-positions-status-live-region",
                "No preview position is substituted in production.",
            ),
        },
    ))

    controller_path = root / PERP_POSITIONS_CONTROLLER_PATH
    if controller_path.is_file():
        controller_source = strip_dart_comments(read_text(controller_path))
        controller_code = strip_dart_comments_and_strings(controller_source)
        if re.search(r"\bbindWallet\s*\(", controller_code):
            errors.append(
                "Perp Positions controller must never perform wallet binding"
            )
        if "package:dio/" in controller_source or re.search(
            r"(['\"])/v1/", controller_source
        ):
            errors.append(
                "Perp Positions controller must use PerpPrivateGateway, not a direct transport"
            )
        initial_calls = re.findall(
            r"\.listPositions\s*\(\s*limit\s*:\s*initialLimit\s*\)",
            controller_code,
        )
        continuation_calls = re.findall(
            r"\.listPositions\s*\(\s*cursor\s*:\s*cursor\s*\)",
            controller_code,
        )
        if len(initial_calls) != 1:
            errors.append(
                "Perp Positions must issue exactly one bounded initial-read call site"
            )
        if len(continuation_calls) != 1:
            errors.append(
                "Perp Positions continuation must have exactly one cursor-only call site"
            )
        expire_start = controller_code.find("void _expireProjection()")
        expire_end = controller_code.find("bool _isCurrent", expire_start)
        expire_body = controller_code[expire_start:expire_end]
        if (
            expire_start < 0
            or expire_end < 0
            or re.search(r"\b_operation\s*=\s*null\s*;", expire_body) is None
        ):
            errors.append(
                "Perp Positions expiry must release a retired logical single-flight"
            )

    surface_path = root / PERP_POSITIONS_SURFACE_PATH
    if surface_path.is_file():
        surface_source = strip_dart_comments(read_text(surface_path))
        surface_code = strip_dart_comments_and_strings(surface_source)
        d4_start = surface_code.find("class PerpPositionsScreen")
        d4_end = surface_code.find("class _PerpPositionsPreview", d4_start)
        d4_selector = surface_code[d4_start:d4_end]
        if d4_start < 0 or d4_end < 0 or re.search(
            r"if\s*\(\s*ref\.watch\s*\(\s*"
            r"developmentPreviewEnabledProvider\s*\)\s*\)\s*\{\s*"
            r"return\s+_PerpPositionsPreview\s*\([^;]*;\s*\}\s*"
            r"return\s+const\s+_PerpPositionsLive\s*\(\s*\)\s*;",
            d4_selector,
            re.DOTALL,
        ) is None:
            errors.append(
                "PerpPositionsScreen must select Preview only when the explicit "
                "development flag is true"
            )

        d5_start = surface_code.find("class PerpPositionScreen")
        d5_end = surface_code.find("class _PerpPositionLiveUnavailable", d5_start)
        d5_selector = surface_code[d5_start:d5_end]
        if d5_start < 0 or d5_end < 0 or re.search(
            r"if\s*\(\s*!\s*ref\.watch\s*\(\s*"
            r"developmentPreviewEnabledProvider\s*\)\s*\)\s*\{\s*"
            r"return\s+const\s+_PerpPositionLiveUnavailable\s*\(\s*\)\s*;\s*\}",
            d5_selector,
            re.DOTALL,
        ) is None:
            errors.append(
                "PerpPositionScreen must fail closed unless the explicit "
                "development Preview flag is true"
            )

        live_start = surface_source.find("class _PerpPositionsLive")
        live_end = surface_source.find("class _PositionCard", live_start)
        if live_start < 0 or live_end < 0:
            errors.append(
                "Perp Positions surface must preserve separate production and Preview classes"
            )
        else:
            live_source = surface_source[live_start:live_end]
            for marker in (
                "PerpPreviewData",
                "_PositionCard(",
                "context.push('/perp/position')",
                "bindWallet(",
                "32.4%",
                "Mark price",
                "Close position unavailable",
            ):
                if marker in live_source:
                    errors.append(
                        "Live Perp Positions must not reference preview, detail, or "
                        f"binding marker: {marker}"
                    )
            if ".toDouble(" in strip_dart_comments_and_strings(live_source):
                errors.append(
                    "Live Perp Positions must render Decimal values without double conversion"
                )

        detail_start = surface_source.find("class _PerpPositionLiveUnavailable")
        detail_end = surface_source.find("class _DisabledPositionAction", detail_start)
        if detail_start < 0 or detail_end < 0:
            errors.append(
                "Production D5 must preserve its explicit unavailable boundary"
            )
        else:
            detail_source = surface_source[detail_start:detail_end]
            for marker in (
                "PerpPreviewData",
                "ETH-PERP",
                "4,630.50",
                "Close position unavailable",
            ):
                if marker in detail_source:
                    errors.append(
                        "Production D5 must fail closed without preview marker: "
                        f"{marker}"
                    )

    errors.extend(
        check_behavior_test_evidence(root, PERP_POSITIONS_BEHAVIOR_TEST_MARKERS)
    )
    errors.extend(
        check_named_executable_test_evidence(
            root, PERP_POSITIONS_EXECUTABLE_TEST_EVIDENCE
        )
    )
    return errors


FRIEND_FRONTEND_TEST_MARKERS = {
    Path("test/friend_feature_test.dart"): (
        "friend inputs allow shared aliases but reject duplicate identities and non-v4 IDs",
        "Preview request becomes pending but never becomes an accepted friend",
        "search results retire after the page stops listening",
        "unknown friend request stays frozen after a search refresh",
        "unknown friend request survives route disposal in this session",
        "Preview group creation is idempotent and never returns a Stream CID",
        "unknown group outcome freezes the draft and is never resubmitted",
        "unknown group draft survives route disposal in this session",
        "production group receipt without a Chat CID stays unconfirmed",
        "production friend surfaces fail closed without controls",
        "gateway rotation clears visible friend and group text",
        "Preview can search an alias and send a pending request",
        "Preview selects accepted friends and creates no Stream channel",
        "production group success requires a canonical CID and routes to guarded Chat",
        "Chat add menu exposes create-group and add-friend routes",
        "Profile exposes 好友请求 and the retired friend routes fail closed",
    ),
    Path("test/friend_request_feature_test.dart"): (
        "loads incoming and outgoing first pages and paginates each list independently",
        "accept and reject remove only the decided incoming request",
        "unknown decision keeps one operation and permits reconciliation only",
        "accept refreshes a mounted friend directory",
        "Preview cannot opt into production friend-request behavior",
    ),
    Path("test/loop_social_authenticated_session_test.dart"): (
        "refreshes one proven 401 exactly once",
        "401 refresh and bootstrap recovery have independent one-use budgets",
        "a second 401 fails without loading a third request token",
        "a second bootstrap_required is not recovered again",
        "dispose wins a race with an in-flight authenticated request",
    ),
    Path("test/loop_social_repository_test.dart"): (
        "uses exact first/cursor queries and parses nullable aliases plus all relationships",
        "sends exact idempotency headers and bodies for all commands",
        "validates social operation id, kind, and terminal invariants",
        "accepts 202 proof and uses the greater retry delay",
        "accepts terminal group members as an unordered set payload",
        "fails closed on malformed 200/202 operation envelopes",
    ),
    Path("test/loop_social_friend_gateway_test.dart"): (
        "ambiguous friend command queries operation then replays exact UUID/body",
        "a failed reconciliation query never replays the write",
        "a rate-limited reconciliation keeps the original operation uncertain",
        "ordinary read connection failure is never automatically replayed",
        "group creation accepts backend member order as an unordered set",
        "malformed committed POST payload reconciles before any replay",
        "chat polling deadline includes request time, not only delays",
        "operator_required is terminal and repeated intent never allocates another channel",
        "direct_channel_unavailable is an operator hold and never starts a second allocation",
    ),
    Path("test/social_privacy_controller_test.dart"): (
        "loads, edits the complete fixed set, and discards",
        "version conflict freezes the draft until reload succeeds",
        "gateway rotation retires old load and accepts only the new owner",
        "gateway rotation retires an old save without clearing a new save",
    ),
    # Decision 0053: the surface retired; the evidence is now its retirement.
    Path("test/social_privacy_presentation_screen_test.dart"): (
        "social-privacy is no longer a Profile surface",
        "the retired location is recorded as information, not a route",
        "production composition no longer mounts the V1 gateway",
    ),
    Path("test/group_alias_models_test.dart"): (
        "rejects non-canonical IDs and every Stream/direct identifier",
        "requires a 2-40 code-point search prefix and a 1-20 limit",
        "rejects duplicate IDs, duplicate Aliases, and oversized pages",
    ),
    Path("test/group_alias_controller_test.dart"): (
        "replays the exact committed Alias to confirm pending projection",
        "retains unknown PUT and permits only exact-value convergence",
        "reload cannot erase an unresolved exact PUT candidate",
        "server immutable failure requires reload before another PUT",
        "retains an in-flight PUT after its last listener is removed",
    ),
    Path("test/group_alias_stream_message_identity_test.dart"): (
        "accepts only the canonical immutable v1 fields",
        "rejects malformed, future, or ambiguous LOOP fields",
        "display sanitizer closes every visible Stream user projection",
        "official default message item shows the group Alias in channel and thread layouts",
        "missing projection renders the neutral group-member label",
        "current member projection updates the mounted default item",
        "a direct channel names its peer from the page, not from Stream",
        "a direct bubble with no published peer never draws an id",
        "a named direct row reads the peer LOOP recorded",
        "a peer with no public profile reads as a deactivated account",
        "a direct row LOOP has no answer for stays neutral",
        "a private row marks what the reader sent, as a group row does",
        "group user mention candidates are hidden and cannot be selected",
        "group conversation labels never fall back to member identity",
        "group channel chrome hides stock typing and global identities",
        "every inbox cell is named by LOOP, never by a Stream identity projection",
    ),
    Path("test/group_alias_mention_autocomplete_test.dart"): (
        "a candidate is the Alias this channel resolved, never Stream",
        "the query is an Alias prefix, matched without case",
        "a member with no Alias, and the member themselves, are absent",
        "every LOOP channel installs its own `@`, never the stock one",
        "the candidate is the published peer, never Stream",
        "without a published peer, or a room of two, there is nobody",
        "the private mention link leaves with the message",
        "a private candidate row shows the peer and types it",
        "a private `@` with no published peer offers nothing",
        "a group candidate row shows the Alias and its initial",
        "typing an Alias prefix narrows the group candidates",
        "tapping a candidate types the Alias and keeps the link",
        "a bubble draws the Alias for a mention, never the Stream id",
        "Stream drops a mention whose token is the channel Alias",
        "naming the mentioned member with the Alias keeps the link",
        "an edit is prepared the same way, from the live roster",
        "only a group or community channel is prepared",
        "the candidate card is a surface, not a wash",
    ),
    Path("test/group_alias_resolver_test.dart"): (
        "keeps only the validated messaging channel ID",
        "rejects direct, malformed, unsafe, and oversized CIDs with zero resolver calls",
        "single-flights resolution and publishes a copied 200 group ID",
        "an unavailable-mode gateway fails closed without a call",
    ),
    Path("test/dio_loop_group_alias_gateway_test.dart"): (
        "sends the exact authenticated group-only requests",
        "rejects account identity fields and strict response-proof drift",
        "keeps an attempted PUT outcome unknown on transport, projection, or response-proof loss",
        "uses the session one-401 refresh budget",
        "uses the session one-bootstrap recovery budget",
    ),
    Path("test/dio_loop_group_alias_resolver_gateway_test.dart"): (
        "sends the exact authenticated resolver request",
        "requires an exact body and strict response proof",
        "rejects a known direct CID locally without token or HTTP work",
        "uses the session one-401 refresh budget",
        "uses the session one-bootstrap recovery budget",
    ),
    Path("test/dio_loop_personalization_gateways_test.dart"): (
        "send exact authenticated GET and full-CAS PUT requests",
        "requires a strict no-store success envelope",
        # Decision 0053 retired the V1 privacy adapter; two live V1 resources
        # remain (profile and social privacy).
        "maps exact CAS conflicts for both live resources",
        "one strict 401 obtains a current token and then succeeds",
        "one bootstrap_required response reauthorizes then succeeds",
    ),
    Path("test/loop_personalization_providers_test.dart"): (
        # Decision 0053: the V2 gateways also need client metadata.
        "missing transport, client metadata, or owner stays unavailable",
        "verified owner and backend produce lazy production gateways",
        "principal and backend-provider rotation replace every gateway",
    ),
    Path("test/loop_group_alias_providers_test.dart"): (
        "missing backend or verified owner stays fail closed",
        "verified owner and backend produce one lazy production adapter",
        "owner and backend rotation replace the production adapter",
    ),
    Path("test/social_ui_safety_edges_test.dart"): (
        "group operator-required survives route disposal and blocks reset or a second UUID",
        "direct operator-required is target-scoped and never allocates a second intent for that target",
        "invalid route group ID fails closed with zero gateway calls",
        "group Alias search renders only the Alias and no identity fields",
    ),
}


def check_friend_frontend_contract(root: Path) -> list[str]:
    """Keep decision 0047's authenticated social boundary fail-closed."""

    errors = require_fragments(
        root,
        {
            "lib/features/chat/friends/chat_create_menu_button.dart": (
                "ValueKey<String>('chat-create-menu')",
                "ValueKey<String>('chat-create-group-menu-item')",
                "ValueKey<String>('chat-add-friend-menu-item')",
                "label: '创建群组'",
                "label: '添加好友'",
                "context.push('/chat/groups/create')",
                # Step 3 folded the V1 alias search into the V2 global search.
                "context.push('/search')",
            ),
            "lib/features/chat/friends/friend_models.dart": (
                "factory FriendProfileRef.fromPublicProfileId(String value)",
                "final String profileCode;",
                "final String? accountAlias;",
                "outgoingPending",
                "incomingPending",
                "groupMinimumSelectedFriends = 2",
                "groupMaximumSelectedFriends = 29",
                "validateFriendOperationId",
                "String get operationId => requestId;",
                "address.id.startsWith('loop_group_')",
                "address.id.startsWith('loop_direct_')",
                "setEquals(other.friendRefs.toSet(), friendRefs.toSet())",
            ),
            "lib/features/chat/friends/friend_gateway.dart": (
                "abstract interface class FriendGateway",
                "abstract interface class LoopSocialFriendGateway",
                "final class UnavailableFriendGateway",
                "(ref) => const UnavailableFriendGateway()",
                "sendFriendRequestCommand",
                "loadFriendRequests",
                "decideFriendRequest",
                "createDirectChannel",
            ),
            "lib/features/chat/friends/friend_controllers.dart": (
                "const Uuid().v4()",
                "FriendGatewayFailureKind.outcomeUnknown",
                "NotifierProvider.autoDispose",
                "_unresolvedWriteKeepAlive ??= ref.keepAlive()",
                "Future<void> reconcileRequest",
                "Future<void> reconcile()",
                "CreatedDirectFriendChannel",
            ),
            "lib/features/chat/friends/friend_request_controller.dart": (
                "FriendRequestDirection.incoming",
                "FriendRequestDirection.outgoing",
                "const Uuid().v4()",
                "_unresolvedWriteKeepAlive ??= ref.keepAlive()",
                "reconcileDecision",
            ),
            "lib/features/chat/friends/friend_request_screen.dart": (
                "ValueKey<String>('friend-requests-incoming-empty')",
                "ValueKey<String>('friend-requests-outgoing-empty')",
                "ValueKey<String>('friend-decision-reconcile')",
            ),
            "lib/features/chat/friends/friend_screens.dart": (
                "ValueKey<String>('friends-service-unavailable')",
                "ValueKey<String>('friend-search-unavailable')",
                "ValueKey<String>('friend-group-unavailable')",
                "ValueKey<String>('friend-group-open-channel')",
                "ValueKey<String>('friend-direct-reconcile')",
                "ValueKey<String>('friend-request-reconcile')",
                "ValueKey<String>('friend-group-reconcile')",
                "ref.listenManual<FriendSearchState>",
                "ref.listenManual<FriendGroupState>",
            ),
            "lib/features/chat/group_alias/group_alias_models.dart": (
                "final class GroupId",
                "final class GroupAliasStreamChannelId",
                "factory GroupAliasStreamChannelId.fromCid(String cid)",
                "address.id.startsWith('loop_direct_')",
                "String get wireValue => _value;",
                "final class GroupAliasId",
            ),
            "lib/features/chat/group_alias/group_alias_gateway.dart": (
                "abstract interface class GroupAliasGateway",
                "abstract interface class GroupAliasResolverGateway",
                "Future<GroupId> resolveGroup(GroupAliasStreamChannelId channelId)",
            ),
            "lib/features/chat/group_alias/group_alias_controller.dart": (
                "_outcomeUnknownKeepAlive ??= ref.keepAlive()",
                "groupAliasResolverControllerProvider",
                "groupAliasSearchControllerProvider",
            ),
            "lib/features/chat/group_alias/group_alias_screen.dart": (
                "class GroupAliasChannelRoutePage",
                "GroupAliasStreamChannelId.fromCid(routeCid)",
                "class GroupAliasPage",
            ),
            "lib/features/chat/group_alias/group_alias_stream_message_identity.dart": (
                "loopGroupMemberNeutralLabel = '成员'",
                "loopGroupConversationNeutralLabel = '群聊'",
                "parseLoopGroupAliasMemberProjection",
                "if (!setEquals(projectionFields, _aliasProjectionFields)) return null;",
                "resolveLoopGroupMessageSenderLabel",
                "resolveLoopGroupConversationLabel",
                "sanitizeLoopGroupMessageForDisplay",
                "loopStreamGroupMessageItemBuilder",
                "loopStreamGroupMentionItemBuilder",
                # Decision 0055 · R13-5. A group `@` names candidates from the
                # same member projection the bubble does, so the row can be
                # offered at all; Stream's own overlay is turned off wherever
                # this trigger is installed.
                "resolveLoopGroupMentionCandidates",
                "loopGroupMentionAutocompleteTrigger",
                "loopChannelAutocompleteTriggers",
                "loopStreamChannelListIdentityItem",
                "class LoopStreamGroupChannelHeader",
                "class LoopStreamGroupChannelPage",
                "ValueKey<String>('loop-group-channel-neutral-avatar')",
                "onUserAvatarTap: null",
                "onMentionTap: null",
            ),
            "lib/features/profile/social_privacy/social_privacy_models.dart": (
                "friendRequests = FriendRequestsPreference.disabled",
                "groupInvites = GroupInvitesPreference.disabled",
                "directMessages = DirectMessagesPreference.disabled",
            ),
            "lib/features/profile/social_privacy/social_privacy_gateway.dart": (
                "abstract interface class SocialPrivacyGateway",
                "final class UnavailableSocialPrivacyGateway",
            ),
            "lib/features/profile/social_privacy/social_privacy_controller.dart": (
                "SocialPrivacyGatewayFailureKind.versionConflict",
                "requiresReload: true",
            ),
            "lib/integrations/backend/loop_authenticated_session.dart": (
                "final class LoopAuthenticatedSession",
                "var refreshedAuthentication = false",
                "var repeatedBootstrap = false",
                "failure.statusCode == 401",
                "failure.code == 'bootstrap_required'",
            ),
            "lib/integrations/backend/loop_authenticated_providers.dart": (
                "final loopAuthenticatedSessionProvider",
                "ref.onDispose(session.dispose)",
            ),
            "lib/integrations/social/loop_social_repository.dart": (
                "final class DioLoopSocialRepository",
                "'/v1/friends'",
                "'/v1/friends/search'",
                "'/v1/friend-requests'",
                "'/v1/social/operations/$operationId'",
                "'/v1/chat/operations/$operationId'",
                "'/v1/chat/groups'",
                "'/v1/chat/direct-channels'",
                "'target_public_profile_id': targetProfileRef.wireValue",
                "'friend_public_profile_ids': selected",
                "'idempotency-key': operationId",
                "_groupChannelIdPattern.hasMatch(address.id)",
                "_directChannelIdPattern.hasMatch(address.id)",
                "_decodePayload",
                "_socialOperationErrorCodes",
            ),
            "lib/integrations/social/dio_loop_social_friend_gateway.dart": (
                "final class DioLoopSocialFriendGateway",
                "_querySocialOrNull",
                "_queryChatOrNull",
                "social_operation_not_found",
                "chat_operation_not_found",
                "_maximumChatPollingAttempts",
                "_monotonicNow() - startedAt",
                "FriendGatewayFailureKind.operatorRequired",
            ),
            "lib/integrations/social/loop_social_providers.dart": (
                "final loopProductionFriendGatewayProvider",
                "DioLoopSocialFriendGateway(session, repository)",
                "ref.onDispose(gateway.dispose)",
            ),
            "lib/integrations/social/dio_loop_group_alias_gateway.dart": (
                "implements GroupAliasGateway, GroupAliasResolverGateway",
                "'/v1/chat/groups/resolve'",
                "'stream_channel_id': channelId.wireValue",
            ),
            "lib/integrations/social/loop_group_alias_providers.dart": (
                "final loopGroupAliasGatewayProvider",
                "DioLoopGroupAliasGateway(dio: dio, session: session)",
            ),
            "lib/integrations/personalization/dio_loop_personalization_gateways.dart": (
                "final class DioLoopSocialPrivacyGateway",
                "static const _socialPrivacyPath = '/v1/profile/social-privacy'",
                "expectedVersion: expectedVersion",
            ),
            "lib/integrations/personalization/loop_personalization_providers.dart": (
                "final loopSocialPrivacyGatewayProvider",
                "DioLoopSocialPrivacyGateway(dio: dio, session: session)",
            ),
            "lib/integrations/social/memory_friend_gateway.dart": (
                "final class MemoryFriendGateway implements FriendGateway",
                "FriendGatewayMode get mode => FriendGatewayMode.preview",
                "relationship: FriendRelationship.requestPending",
                "streamCid: null",
                "_groupReceipts[requestId]",
            ),
            "lib/integrations/personalization/memory_social_privacy_gateway.dart": (
                "final class MemorySocialPrivacyGateway implements SocialPrivacyGateway",
                "SocialPrivacyMode get mode => SocialPrivacyMode.preview",
            ),
            "lib/features/chat/stream_chat_inbox_page.dart": (
                "const ChatCreateMenuButton()",
                "class StreamGroupAliasChannelRoutePage extends ConsumerWidget",
                "GroupAliasStreamChannelId.fromCid(cid)",
                "class _ExistingMemberGroupAliasPage extends StatefulWidget",
                "Future<Channel?> _load() => _loadExistingMemberChannel(",
                "return GroupAliasChannelRoutePage(routeCid: widget.cid);",
                "client.queryChannelsOnline(",
                "Filter.equal('cid', cid)",
                "Filter.in_('members', <Object>[userId])",
                "channel.membership?.userId != userId",
                "No existing Stream channel membership was confirmed",
                "GroupAliasStreamChannelId.fromCid(widget.cid)",
                "LoopStreamGroupChannelPage(",
                "loopStreamChannelListIdentityItem(defaultItem)",
                "'/chat/channel/${Uri.encodeComponent(widget.cid)}/alias'",
            ),
            "lib/features/chat/chat_inbox_page.dart": (
                "const ChatCreateMenuButton()",
            ),
            # Decision 0053: the Profile root moved to profile_v2_screens; the
            # Social privacy entry retired with the V2 privacy resource.
            "lib/features/profile/profile_v2_screens.dart": (
                # Step 3: the friend list retired; only the request inbox stays.
                "title: '好友请求'",
                "onTap: () => widget.onNavigate('friend-requests')",
                "onTap: () => widget.onNavigate('connections')",
                "onTap: () => widget.onNavigate('privacy')",
            ),
            "lib/app.dart": (
                "messageItem: loopStreamGroupMessageItemBuilder",
                "mentionItem: loopStreamGroupMentionItemBuilder",
                "path: '/chat/groups/create'",
                "path: '/chat/groups/:groupId/alias'",
                # Step 4: `/chat/friends/requests` was folded into the
                # `dm-requests` page and `/chat/channel/:cid/alias` into
                # `group-info`, which resolves the LOOP group itself. Both are
                # informational retirements now, so neither may be mounted.
                "'friend-requests' => LoopRouteManifest.pathFor('dm-requests')",
                # Decision 0053: the retired V1 social-privacy destination
                # resolves to the V2 Privacy centre instead of a dead route.
                "'social-privacy' => LoopRouteManifest.pathFor('privacy')",
            ),
            "lib/main.dart": (
                "friendGatewayProvider.overrideWith(",
                "ref.watch(loopProductionFriendGatewayProvider)",
                "groupAliasGatewayProvider.overrideWith(",
                "ref.watch(loopGroupAliasGatewayProvider)",
            ),
            "lib/main_preview.dart": (
                "friendGatewayProvider.overrideWithValue(MemoryFriendGateway())",
                "socialPrivacyGatewayProvider.overrideWithValue(",
                "MemorySocialPrivacyGateway(",
            ),
            "docs/decisions/0046-model-friends-and-group-creation-before-transport.md": (
                "## Status",
                "Superseded for production transport and wire identity by decision 0047",
            ),
            "docs/decisions/0047-connect-backend-social-and-server-created-chat.md": (
                "Accepted on 2026-08-31",
                "`public_profile_id` is the stable, opaque UUID",
                "`profile_code` is the immutable, globally unique 10-character Crockford",
                "matching social or Chat operation before any replay",
                "`messaging:loop_group_*` CID; member IDs are an unordered set",
                "canonical `messaging:loop_direct_*` CID",
                "submit only its validated channel ID (not the full CID)",
                "The resolver has no `Idempotency-Key`",
            ),
            "README.md": (
                "正式入口现装配 principal-bound LOOP 社交适配器",
                "`public_profile_id` 是唯一命令目标",
                "先查询 operation",
            ),
            "docs/product/implementation-constraints.md": (
                "`public_profile_id` is the stable opaque UUID and only client-visible friend/group/direct command target",
                "queries its owning operation first",
                "exact online Stream channel-list result filtered by that CID and current membership",
            ),
            "docs/product-decisions.md": (
                "production now uses the reviewed principal-bound LOOP social adapter",
                "`public_profile_id` is the only command target",
                "backend's fixed `messaging:loop_direct_*` CID",
            ),
            "test/stream_chat_inbox_page_test.dart": (
                "channel route lookup requires an exact CID and current membership",
                "the retired CID-addressed Alias route never reaches a resolver",
            ),
        },
    )

    feature_roots = (
        root / "lib/features/chat/friends",
        root / "lib/features/chat/group_alias",
        root / "lib/features/profile/social_privacy",
    )
    stream_presentation_path = Path(
        "lib/features/chat/group_alias/group_alias_stream_message_identity.dart"
    )
    for feature_root in feature_roots:
        if not feature_root.is_dir():
            continue
        for path in feature_root.rglob("*.dart"):
            source = strip_dart_comments(read_text(path))
            if "package:dio/" in source or re.search(r"['\"]/v1/", source):
                errors.append(
                    "Social feature code must stay behind narrow ports, not a direct HTTP transport: "
                    + str(path.relative_to(root))
                )
            relative = path.relative_to(root)
            uses_stream_sdk = "package:stream_chat" in source
            if (uses_stream_sdk and relative != stream_presentation_path) or re.search(
                r"\bclient\s*\.\s*channel\s*\(", source
            ):
                errors.append(
                    "Social feature code may use Stream types only in the reviewed group-Alias presentation adapter and must never create channels directly: "
                    + str(path.relative_to(root))
                )

    friend_feature_root = root / "lib/features/chat/friends"
    controllers_path = friend_feature_root / "friend_controllers.dart"
    if controllers_path.is_file():
        controllers = strip_dart_comments(read_text(controllers_path))
        if controllers.count("ref.keepAlive()") < 3:
            errors.append(
                "Friend request, group-create, and direct-create controllers must retain unresolved writes with ref.keepAlive()"
            )
        if "error.kind == FriendGatewayFailureKind.unexpected" in controllers:
            errors.append(
                "Typed unexpected write failures must remain definitive; only outcomeUnknown may freeze"
            )

    request_controller_path = friend_feature_root / "friend_request_controller.dart"
    if request_controller_path.is_file() and "ref.keepAlive()" not in strip_dart_comments(
        read_text(request_controller_path)
    ):
        errors.append(
            "Friend-request decisions must retain unresolved writes with ref.keepAlive()"
        )

    alias_controller_path = (
        root / "lib/features/chat/group_alias/group_alias_controller.dart"
    )
    if alias_controller_path.is_file():
        alias_controller = strip_dart_comments(read_text(alias_controller_path))
        put_start = alias_controller.find("Future<void> _startPut")
        put_end = alias_controller.find("Future<void> _performPut", put_start + 1)
        put_section = (
            alias_controller[put_start:put_end]
            if put_start >= 0 and put_end > put_start
            else ""
        )
        retain_index = put_section.find("_retainOutcomeUnknown();")
        dispatch_index = put_section.find("_performPut(")
        if retain_index < 0 or dispatch_index <= retain_index:
            errors.append(
                "Group-Alias controller must keepAlive before dispatching an immutable PUT"
            )

    screens_path = friend_feature_root / "friend_screens.dart"
    if screens_path.is_file():
        screens = strip_dart_comments(read_text(screens_path))
        if screens.count("ref.listenManual<FriendGateway>") < 2:
            errors.append(
                "Friend search and group text must both clear on principal-bound gateway rotation"
            )

    stream_route_path = root / "lib/features/chat/stream_chat_inbox_page.dart"
    if stream_route_path.is_file():
        stream_route = strip_dart_comments(read_text(stream_route_path))
        if "client.channel(" in stream_route:
            errors.append(
                "String-addressed Chat routes must not call client.channel before existing membership is queried"
            )
        group_gate_start = stream_route.find(
            "class StreamGroupAliasChannelRoutePage"
        )
        group_gate_end = stream_route.find(
            "class _ExistingMemberStreamChannelPage", group_gate_start + 1
        )
        group_gate = (
            stream_route[group_gate_start:group_gate_end]
            if group_gate_start >= 0 and group_gate_end > group_gate_start
            else ""
        )
        group_query_index = group_gate.find("_loadExistingMemberChannel(")
        group_proof_index = group_gate.find(
            "if (snapshot.hasError || snapshot.data == null)",
            group_query_index + 1,
        )
        group_resolver_index = group_gate.find(
            "GroupAliasChannelRoutePage(routeCid: widget.cid)",
            group_proof_index + 1,
        )
        if (
            group_query_index < 0
            or group_proof_index <= group_query_index
            or group_resolver_index <= group_proof_index
        ):
            errors.append(
                "Alias route must prove exact Stream membership before mounting the LOOP group resolver"
            )

        member_route_start = stream_route.find(
            "class _ExistingMemberStreamChannelPage"
        )
        member_route = (
            stream_route[member_route_start:]
            if member_route_start >= 0
            else ""
        )
        proof_index = member_route.find(
            "if (snapshot.hasError || snapshot.data == null)"
        )
        alias_index = member_route.find(
            "GroupAliasStreamChannelId.fromCid(widget.cid)", proof_index + 1
        )
        if proof_index < 0 or alias_index <= proof_index:
            errors.append(
                "Group-Alias navigation from a Stream channel must stay behind the exact membership result"
            )

        safe_page_assignment_match = re.search(
            r"final\s+usesGroupIdentity\s*=\s*"
            r"loopStreamChannelUsesGroupMessageAlias\s*\(\s*widget\.cid\s*,?\s*\)\s*;",
            member_route[alias_index + 1 :],
            re.DOTALL,
        )
        safe_page_assignment = (
            alias_index + 1 + safe_page_assignment_match.start()
            if safe_page_assignment_match is not None
            else -1
        )
        safe_page_index = member_route.find(
            "? LoopStreamGroupChannelPage(", safe_page_assignment + 1
        )
        direct_page_index = member_route.find(
            ": const StreamChannelPage()", safe_page_index + 1
        )
        if (
            safe_page_assignment < 0
            or safe_page_index <= safe_page_assignment
            or direct_page_index <= safe_page_index
        ):
            errors.append(
                "Group Stream channel routes must select the safe page after membership proof while direct channels keep the official page"
            )

        if re.search(
            r"itemBuilder\s*:\s*\([^)]*\bdefaultItem\b[^)]*\)\s*=>\s*"
            r"loopStreamChannelListIdentityItem\s*\(\s*defaultItem\s*\)",
            stream_route,
            re.DOTALL,
        ) is None:
            errors.append(
                "Group Stream channel list must route every official default item through the safe identity item"
            )

    app_path = root / "lib/app.dart"
    if app_path.is_file():
        app_source = strip_dart_comments(read_text(app_path))
        # Step 4 retired the CID-addressed Alias entry: `group-info` resolves
        # the LOOP group itself, so no route may hand an untrusted CID to the
        # resolver.
        if (
            "path: '/chat/channel/:cid/alias'" in app_source
            or "StreamGroupAliasChannelRoutePage(" in app_source
            or "=> GroupAliasChannelRoutePage(" in app_source
        ):
            errors.append(
                "the retired CID-addressed Alias route must not be mounted again"
            )

    repository_path = root / "lib/integrations/social/loop_social_repository.dart"
    if repository_path.is_file():
        repository = strip_dart_comments(read_text(repository_path))

        for marker in (
            "_groupChannelIdPattern.hasMatch(address.id)",
            "_directChannelIdPattern.hasMatch(address.id)",
            "on InvalidFriendContractException",
            "LoopBackendFailureKind.invalidPayload",
            "_socialOperationErrorCodes.contains(errorCode)",
        ):
            if marker not in repository:
                errors.append(
                    "Social response parsing must fail closed on identity/CID/operation drift: "
                    + marker
                )

        def command_section(start: str, end: str) -> str:
            start_index = repository.find(start)
            end_index = repository.find(end, start_index + 1)
            if start_index < 0 or end_index < 0:
                return ""
            return repository[start_index:end_index]

        command_sections = (
            command_section("Future<LoopSocialOperation> sendFriendRequest", "Future<LoopSocialOperation> decideFriendRequest"),
            command_section("Future<LoopSocialOperation> decideFriendRequest", "Future<LoopChatOperation> getChatOperation"),
            command_section("Future<LoopChatOperation> createGroup", "Future<LoopChatOperation> createDirectChannel"),
            command_section("Future<LoopChatOperation> createDirectChannel", "Future<Response<Object?>> _get"),
        )
        for section in command_sections:
            if not section:
                errors.append(
                    "LOOP social command methods must remain structurally inspectable"
                )
                continue
            if "profile_code" in section or "stream_user_id" in section:
                errors.append(
                    "Social commands must target public_profile_id only, never profile_code or Stream identity"
                )

    production_gateway_path = (
        root / "lib/integrations/social/dio_loop_social_friend_gateway.dart"
    )
    if production_gateway_path.is_file():
        production_gateway = strip_dart_comments(read_text(production_gateway_path))
        reconciliation_sections = (
            (
                "Future<LoopSocialOperation> _runSocialCommand",
                "final Set<String> _attemptedOperationIds",
                "_querySocialOrNull(operationId, kind)",
            ),
            (
                "Future<LoopChatOperation> _runChatCommand",
                "Future<LoopChatOperation?> _queryChatOrNull",
                "_queryChatOrNull(operationId, kind)",
            ),
        )
        for start, end, query in reconciliation_sections:
            start_index = production_gateway.find(start)
            end_index = production_gateway.find(end, start_index + 1)
            section = (
                production_gateway[start_index:end_index]
                if start_index >= 0 and end_index > start_index
                else ""
            )
            catch_index = section.find("catch (error)")
            query_index = section.find(query, catch_index + 1)
            replay_index = section.find(
                "await _session.execute(post)", query_index + len(query)
            )
            if catch_index < 0 or query_index < 0 or replay_index <= query_index:
                errors.append(
                    "Ambiguous social commands must query their operation before exact replay"
                )

        for query_name, not_found_code in (
            ("_querySocialOrNull", "social_operation_not_found"),
            ("_queryChatOrNull", "chat_operation_not_found"),
        ):
            start_index = production_gateway.find(
                f"Future<Loop{'Social' if 'Social' in query_name else 'Chat'}Operation?> {query_name}"
            )
            end_index = production_gateway.find("\n  Future<", start_index + 1)
            section = (
                production_gateway[start_index:end_index]
                if start_index >= 0 and end_index > start_index
                else ""
            )
            if (
                "error.statusCode == 404" not in section
                or f"error.code == '{not_found_code}'" not in section
                or "throw _outcomeUnknown(operationId);" not in section
            ):
                errors.append(
                    f"{query_name} may authorize replay only for exact {not_found_code}"
                )

        poll_start = production_gateway.find("Future<LoopChatOperation> _pollChat")
        poll_end = production_gateway.find(
            "LoopChatOperationResult _requireSucceededChat", poll_start + 1
        )
        poll_section = (
            production_gateway[poll_start:poll_end]
            if poll_start >= 0 and poll_end > poll_start
            else ""
        )
        if (
            "_monotonicNow() - startedAt" not in poll_section
            or "_maximumChatPollingAttempts" not in poll_section
        ):
            errors.append(
                "Chat operation polling must be bounded by wall-clock time and attempts"
            )

    stream_identity_path = (
        root
        / "lib/features/chat/group_alias/group_alias_stream_message_identity.dart"
    )
    if stream_identity_path.is_file():
        stream_identity = strip_dart_comments(read_text(stream_identity_path))
        for forbidden in (
            "return user.name",
            "return user.id",
            "onUserAvatarTap: props.onUserAvatarTap",
            "onMentionTap: props.onMentionTap",
        ):
            if forbidden in stream_identity:
                errors.append(
                    "Group Stream identity presentation must never fall back to global identity: "
                    + forbidden
                )

        projection_start = stream_identity.find(
            "String? parseLoopGroupAliasMemberProjection"
        )
        projection_end = stream_identity.find(
            "String resolveLoopGroupMessageSenderLabel", projection_start + 1
        )
        projection_section = (
            stream_identity[projection_start:projection_end]
            if projection_start >= 0 and projection_end > projection_start
            else ""
        )
        if any(
            marker not in projection_section
            for marker in (
                "key.startsWith('loop_group_alias')",
                "setEquals(projectionFields, _aliasProjectionFields)",
                "version is! int",
                "version != 1",
                "GroupAliasId.fromWire(rawId)",
                "normalized != rawAlias",
            )
        ):
            errors.append(
                "Group Stream Alias projection must require the exact immutable v1 field set and canonical values"
            )

        # Decision 0065 gave the direct branch its own cell so the inbox
        # timestamp can carry LOOP's Chinese 24-hour formatter. The dispatcher
        # still discriminates on the same Alias predicate, and the two cells
        # are scanned separately — but since R14-1 neither of them may name a
        # row from a Stream identity projection: `StreamChannelName` /
        # `StreamChannelAvatar` derive a 1:1 row from the peer's `User.name`,
        # which answers `User.id` for every LOOP account, and drew
        # `loop_7e25…` in the inbox.
        dispatch_start = stream_identity.find(
            "Widget loopStreamChannelListIdentityItem"
        )
        dispatch_end = stream_identity.find(
            "class _LoopStreamDirectChannelListItem", dispatch_start + 1
        )
        dispatch_section = (
            stream_identity[dispatch_start:dispatch_end]
            if dispatch_start >= 0 and dispatch_end > dispatch_start
            else ""
        )
        if any(
            marker not in dispatch_section
            for marker in (
                "loopStreamChannelUsesGroupMessageAlias(defaultItem.props.channel.cid)",
                "_LoopStreamDirectChannelListItem(props: defaultItem.props)",
                "_LoopStreamGroupChannelListItem(props: defaultItem.props)",
            )
        ):
            errors.append(
                "Group Stream channel list must route group cells to the safe item and direct cells to the official one"
            )

        direct_item_start = stream_identity.find(
            "class _LoopStreamDirectChannelListItem"
        )
        direct_item_end = stream_identity.find(
            "class _LoopStreamGroupChannelListItem", direct_item_start + 1
        )
        direct_item_section = (
            stream_identity[direct_item_start:direct_item_end]
            if direct_item_start >= 0 and direct_item_end > direct_item_start
            else ""
        )
        # R15-1. The row's name comes from LOOP's own direct-channel index
        # (decision 0056) through the one resolver, and the avatar initial is
        # taken from that same title. Both must come from `identity`: reading
        # anything else here is how `loop_7e25…` reached the inbox.
        if any(
            marker not in direct_item_section
            for marker in (
                "resolveLoopDirectRowIdentity(",
                "directory: LoopDirectChannelDirectoryScope.maybeOf(context)",
                "title: Text(identity.title)",
                # S58c: the tile is LOOP's own `.row-ico`, not a `CircleAvatar`
                # taking the Material scheme's primary, and its initials still
                # come from the resolved title and nothing else.
                "label: identity.initial",
                "LoopInitialsAvatar(",
                "ValueKey<String>('loop-direct-channel-avatar')",
                "message: lastMessage,",
                "channel: loopDirectPreviewChannel(channelState.channel)",
            )
        ):
            errors.append(
                "Direct Stream channel list item must name its row from LOOP's direct-channel index"
            )
        for forbidden in (
            "StreamChannelName(",
            "StreamChannelAvatar(",
            "StreamTypingIndicator(",
            "ChannelListTileSubtitle(",
        ):
            if forbidden in direct_item_section:
                errors.append(
                    "Direct Stream channel list item must not name a row from a Stream identity projection: "
                    + forbidden
                )

        list_item_start = stream_identity.find(
            "class _LoopStreamGroupChannelListItem"
        )
        list_item_end = stream_identity.find(
            "class LoopStreamGroupChannelHeader", list_item_start + 1
        )
        list_item_section = (
            stream_identity[list_item_start:list_item_end]
            if list_item_start >= 0 and list_item_end > list_item_start
            else ""
        )
        if any(
            marker not in list_item_section
            for marker in (
                "sanitizeLoopGroupMessageForDisplay(",
                "resolveLoopGroupConversationLabel(",
                # S58c: as above — the group cell's tile is the reviewed group
                # label's initials on `--card2`, never a provider avatar and
                # never the scheme's primary as a solid disc.
                "avatar: LoopInitialsAvatar(",
                "label: label,",
                "'loop-group-channel-neutral-avatar'",
                "StreamMessagePreviewText(",
            )
        ):
            errors.append(
                "Group Stream channel list item must sanitize its preview and use a neutral group identity"
            )

        # Every inbox timestamp goes through the one LOOP formatter, so no cell
        # falls back to Stream's 12-hour clock or English weekday.
        if "ChannelLastMessageDate(" in stream_identity and any(
            marker not in stream_identity
            for marker in (
                "Widget loopStreamChannelListTimestamp(Channel channel) =>",
                "formatter: (context, date) => loopStreamChannelListDateLabel(date)",
            )
        ):
            errors.append(
                "Stream channel list timestamps must use the LOOP 24-hour Chinese formatter"
            )
        if stream_identity.count(
            "StreamChannelListTile("
        ) != stream_identity.count("loopStreamChannelListTimestamp(channel)"):
            errors.append(
                "Every Stream channel list tile must pass the LOOP timestamp formatter"
            )

        safe_page_start = stream_identity.find("class LoopStreamGroupChannelPage")
        safe_page_end = stream_identity.find(
            "Message sanitizeLoopGroupMessageForDisplay", safe_page_start + 1
        )
        safe_page_section = (
            stream_identity[safe_page_start:safe_page_end]
            if safe_page_start >= 0 and safe_page_end > safe_page_start
            else ""
        )
        if any(
            marker not in safe_page_section
            for marker in (
                "LoopStreamGroupChannelHeader(",
                "StreamMessageListView(",
                "StreamMessageComposer(",
                "threadBuilder:",
                "enableVoiceRecording: false",
            )
        ):
            errors.append(
                "Group Stream channel page must preserve official messaging behavior behind safe group chrome"
            )

        for forbidden in (
            "StreamChannelName(",
            "StreamChannelAvatar(",
            "StreamTypingIndicator(",
        ):
            if forbidden in list_item_section or forbidden in safe_page_section:
                errors.append(
                    "Group Stream list and channel chrome must not restore stock global identity projections: "
                    + forbidden
                )

    # R14-2. A group `@` types the channel Alias, and `Message.toJson` drops
    # any mention whose token it cannot find in the body, so every composer
    # has to name the mentioned member with that Alias on the way out or the
    # mention leaves as plain text. One rule for every composer LOOP mounts.
    for relative in (
        "lib/features/chat/group_alias/group_alias_stream_message_identity.dart",
        "lib/features/chat/v2/loop_stream_channel_surface.dart",
    ):
        composer_path = root / relative
        if not composer_path.is_file():
            continue
        composer_source = strip_dart_comments(read_text(composer_path))
        for index in re.finditer(r"StreamMessageComposer\(", composer_source):
            arguments = _dart_call_arguments(composer_source, index.end() - 1)
            if arguments is None or "preMessageSending:" not in arguments:
                errors.append(
                    "Every LOOP composer must prepare a group mention before sending: "
                    + relative
                )
        if "loopPrepareChannelMessageForSend(" not in composer_source:
            errors.append(
                "Every LOOP composer must prepare a group mention before sending: "
                + relative
            )

    # R14-4. The `@` card is drawn over the conversation, so it cannot be one
    # of the page's translucent panels: `backgroundElevation1` is LOOP's 6%
    # chalk wash and the messages underneath read straight through it.
    overlay_path = (
        root
        / "lib/features/chat/group_alias/group_alias_stream_message_identity.dart"
    )
    if overlay_path.is_file():
        overlay_source = strip_dart_comments(read_text(overlay_path))
        options_start = overlay_source.find(
            "StreamAutocompleteOptions<LoopGroupMentionCandidate>("
        )
        if options_start >= 0:
            options_arguments = _dart_call_arguments(
                overlay_source,
                overlay_source.index("(", options_start),
            )
            if (
                options_arguments is None
                or "color: context.streamColorScheme.backgroundElevation3"
                not in options_arguments
            ):
                errors.append(
                    "The group mention overlay must be drawn on an opaque ground, not a translucent page panel"
                )

    mention_identity_path = (
        root
        / "lib/features/chat/group_alias/group_alias_stream_message_identity.dart"
    )
    if mention_identity_path.is_file():
        mention_identity = strip_dart_comments(read_text(mention_identity_path))
        send_start = mention_identity.find("Message prepareLoopGroupMentionsForSend")
        send_end = mention_identity.find(
            "Message loopPrepareChannelMessageForSend", send_start + 1
        )
        send_section = (
            mention_identity[send_start:send_end]
            if send_start >= 0 and send_end > send_start
            else ""
        )
        if "copyWith(mentionedUsers: named)" not in send_section:
            errors.append(
                "A group mention must be kept by naming the mentioned member, not by rewriting the message body"
            )
        if "text:" in send_section:
            errors.append(
                "A group mention must never write a Stream id into the message body"
            )

    # R15-5. Stream's draft feature uploads the composer on every keystroke
    # and restores it on the next visit, so a channel opened with a stray `@`
    # left over from an earlier session. LOOP never designed for either half,
    # and a restored LOOP `@` carries no roster to read its channel-scoped
    # name back with. A conversation opens with an empty composer.
    stream_config_path = root / "lib/app.dart"
    if stream_config_path.is_file():
        stream_config = strip_dart_comments(read_text(stream_config_path))
        config_start = stream_config.find("StreamChatConfigurationData(")
        if config_start < 0:
            errors.append(
                "The Stream configuration LOOP mounts must stay in app.dart"
            )
        else:
            config_arguments = _dart_call_arguments(
                stream_config,
                stream_config.index("(", config_start),
            )
            if (
                config_arguments is None
                or "draftMessagesEnabled: false" not in config_arguments
            ):
                errors.append(
                    "A LOOP conversation must open with an empty composer, not a restored provider draft"
                )

    # R14-3. A direct conversation is named by LOOP's own profile record or
    # not at all, and the only construction site of a `DirectMessageTarget`
    # has to carry one: passing the id alone left `identity` null on every
    # device visit, so the header read the literal 「私聊」 and the `@` row
    # failed closed with nothing to offer.
    direct_screen_path = root / "lib/features/chat/v2/direct_message_screen.dart"
    if direct_screen_path.is_file():
        direct_screen = strip_dart_comments(read_text(direct_screen_path))
        if any(
            marker not in direct_screen
            for marker in (
                "identity?.displayName ?? '私聊'",
                "LoopDirectPeerScope(displayName: peer, child: surface)",
            )
        ):
            errors.append(
                "The direct conversation page must name its peer from the passed profile and publish it to the Stream widgets"
            )

    # R15-1. Every place in the product that opens a direct conversation hands
    # over the peer's public profile. Passing the id alone is what left the
    # header reading the literal 「私聊」 with no `@` candidates at all.
    for relative in (
        "lib/app.dart",
        "lib/features/chat/stream_chat_inbox_page.dart",
    ):
        target_path = root / relative
        if not target_path.is_file():
            continue
        target_source = strip_dart_comments(read_text(target_path))
        for index in re.finditer(r"DirectMessageTarget\(", target_source):
            arguments = _dart_call_arguments(target_source, index.end() - 1)
            if arguments is None or "identity:" not in arguments:
                errors.append(
                    "Opening a direct conversation must carry the peer's public profile, not the id alone"
                )

    # R15-1. The inbox reads LOOP's own direct-channel index, publishes it to
    # the rows, and carries the same profile into the page it opens. The name
    # travels as typed navigation state only: a deep link must never be able
    # to name a conversation, so the location it builds carries the CID alone.
    inbox_path = root / "lib/features/chat/stream_chat_inbox_page.dart"
    if inbox_path.is_file():
        inbox_source = strip_dart_comments(read_text(inbox_path))
        if any(
            marker not in inbox_source
            for marker in (
                "ref.watch(directChannelDirectoryProvider)",
                "LoopDirectChannelDirectoryScope(",
                "resolveLoopDirectRowIdentity(cid: cid, directory: directory)",
                "loopInboxChannelDestination(",
                "location: '/chat/dm?cid=$encoded'",
                "location: '/chat/channel/$encoded'",
            )
        ):
            errors.append(
                "The inbox must name a direct row from LOOP's index and open it with that same profile"
            )
        for forbidden in ("alias", "displayName", "loopId"):
            if f"$encoded&{forbidden}" in inbox_source or (
                f"?{forbidden}=" in inbox_source
            ):
                errors.append(
                    "A direct conversation's name must never travel in the URL: "
                    + forbidden
                )

    # Decision 0056. The index the inbox names its rows from is decoded
    # strictly: an unknown field, a non-direct CID or the same CID twice would
    # each let a row claim a person the server did not name.
    direct_index_path = (
        root
        / "lib/integrations/backend/v2/communication/loop_v2_communication_codec.dart"
    )
    if direct_index_path.is_file():
        direct_index = strip_dart_comments(read_text(direct_index_path))
        index_start = direct_index.find(
            "static DirectChannelPage directChannels("
        )
        index_section = (
            direct_index[index_start:] if index_start >= 0 else ""
        )
        if any(
            marker not in index_section
            for marker in (
                "LoopV2Contract.strictMap(raw, const <String>{",
                "pattern: directCidPattern,",
                "if (!seen.add(streamCid)) _invalid();",
                "LoopV2ProjectionCodec.profile(rawPeer)",
            )
        ):
            errors.append(
                "The direct-channel index must be decoded strictly, with one peer per direct CID"
            )

    alias_transport_path = (
        root / "lib/integrations/social/dio_loop_group_alias_gateway.dart"
    )
    if alias_transport_path.is_file():
        alias_transport = strip_dart_comments(read_text(alias_transport_path))
        if "'stream_channel_id': channelId.cid" in alias_transport:
            errors.append(
                "Group-Alias resolver must send the validated channel ID, not the full CID"
            )
        if re.search(r"['\"]idempotency-key['\"]\s*:", alias_transport, re.IGNORECASE):
            errors.append(
                "Group-Alias resolver and immutable Alias endpoints must not send Idempotency-Key"
            )

    memory_path = root / "lib/integrations/social/memory_friend_gateway.dart"
    if memory_path.is_file():
        memory = strip_dart_comments(read_text(memory_path))
        for forbidden in (
            "package:stream_chat",
            "StreamChatClient",
            "queryChannels(",
            ".channel(",
            "createChannel(",
        ):
            if forbidden in memory:
                errors.append(
                    "The Preview friend gateway must never own a Stream operation: "
                    + forbidden
                )

    production_root = root / "lib/main.dart"
    if production_root.is_file():
        production = strip_dart_comments(read_text(production_root))
        if "MemoryFriendGateway" in production or "MemorySocialPrivacyGateway" in production:
            errors.append(
                "The production composition root must never install social Preview memory gateways"
            )
        # Decision 0053 retired V1 Social Privacy: the production root must
        # leave the port at its fail-closed default instead of mounting it.
        if "socialPrivacyGatewayProvider" in production:
            errors.append(
                "the retired V1 Social Privacy port must not be mounted in "
                "the production composition root"
            )
        for marker in (
            "ref.watch(loopProductionFriendGatewayProvider)",
            "ref.watch(loopGroupAliasGatewayProvider)",
        ):
            if marker not in production:
                errors.append(
                    "Production social override is required through an integrations adapter: "
                    + marker
                )

    if (root / "lib").is_dir():
        memory_implementations = {
            "MemoryFriendGateway": Path(
                "lib/integrations/social/memory_friend_gateway.dart"
            ),
            "MemorySocialPrivacyGateway": Path(
                "lib/integrations/personalization/memory_social_privacy_gateway.dart"
            ),
        }
        for path in (root / "lib").rglob("*.dart"):
            relative = path.relative_to(root)
            source = strip_dart_comments(read_text(path))
            for marker, implementation in memory_implementations.items():
                if relative in {Path("lib/main_preview.dart"), implementation}:
                    continue
                if marker in source:
                    errors.append(
                        f"{marker} may be composed only by the explicit Preview root: "
                        + str(relative)
                    )

    errors.extend(check_behavior_test_evidence(root, FRIEND_FRONTEND_TEST_MARKERS))
    return errors


LAUNCH_ICON_FOREGROUNDS = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}


def _png_header(data: bytes) -> tuple[int, int, int, int, int]:
    """Returns (width, height, bit_depth, colour_type, interlace)."""
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("not a PNG")
    width, height = int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")
    return width, height, data[24], data[25], data[28]


def _png_rgba_rows(data: bytes) -> list[bytes]:
    """Decodes a non-interlaced 8-bit RGBA PNG into unfiltered rows."""
    width, height, bit_depth, colour_type, interlace = _png_header(data)
    if (bit_depth, colour_type, interlace) != (8, 6, 0):
        raise ValueError(
            f"expected 8-bit RGBA non-interlaced, got depth={bit_depth} "
            f"colour_type={colour_type} interlace={interlace}"
        )
    payload = bytearray()
    offset = 8
    while offset < len(data):
        length = int.from_bytes(data[offset : offset + 4], "big")
        kind = data[offset + 4 : offset + 8]
        if kind == b"IDAT":
            payload += data[offset + 8 : offset + 8 + length]
        offset += 12 + length
    raw = zlib.decompress(bytes(payload))
    stride = width * 4
    rows: list[bytes] = []
    previous = bytearray(stride)
    for index in range(height):
        start = index * (stride + 1)
        filter_type = raw[start]
        line = bytearray(raw[start + 1 : start + 1 + stride])
        for position in range(stride):
            left = line[position - 4] if position >= 4 else 0
            up = previous[position]
            upper_left = previous[position - 4] if position >= 4 else 0
            if filter_type == 1:
                line[position] = (line[position] + left) & 0xFF
            elif filter_type == 2:
                line[position] = (line[position] + up) & 0xFF
            elif filter_type == 3:
                line[position] = (line[position] + ((left + up) >> 1)) & 0xFF
            elif filter_type == 4:
                estimate = left + up - upper_left
                distance_left = abs(estimate - left)
                distance_up = abs(estimate - up)
                distance_upper_left = abs(estimate - upper_left)
                if distance_left <= distance_up and distance_left <= distance_upper_left:
                    predictor = left
                elif distance_up <= distance_upper_left:
                    predictor = up
                else:
                    predictor = upper_left
                line[position] = (line[position] + predictor) & 0xFF
        rows.append(bytes(line))
        previous = line
    return rows


def check_launch_icon_contract(root: Path) -> list[str]:
    """The adaptive foreground carries the mark only; any baked plate is cropped
    into an octagon by the launcher and Android 12+ splash circular masks."""
    errors: list[str] = []
    res = root / "android/app/src/main/res"
    for bucket, expected in LAUNCH_ICON_FOREGROUNDS.items():
        path = res / f"mipmap-{bucket}/ic_launcher_foreground.png"
        if not path.is_file():
            errors.append(f"{path} is missing")
            continue
        data = path.read_bytes()
        try:
            width, height, bit_depth, colour_type, _ = _png_header(data)
        except ValueError as error:
            errors.append(f"{path} is not a readable PNG: {error}")
            continue
        if (width, height) != (expected, expected):
            errors.append(
                f"{path} must be {expected}x{expected} (108dp adaptive canvas), got {width}x{height}"
            )
        if (bit_depth, colour_type) != (8, 6):
            errors.append(
                f"{path} must stay 8-bit RGBA so the mark can sit on transparency"
            )
    smallest = res / "mipmap-mdpi/ic_launcher_foreground.png"
    if smallest.is_file():
        try:
            rows = _png_rgba_rows(smallest.read_bytes())
        except (ValueError, zlib.error) as error:
            errors.append(f"{smallest} could not be decoded: {error}")
            rows = []
        if rows:
            corners = {
                "top-left": rows[0][0:4],
                "top-right": rows[0][-4:],
                "bottom-left": rows[-1][0:4],
                "bottom-right": rows[-1][-4:],
            }
            for name, pixel in corners.items():
                if pixel[3] != 0:
                    errors.append(
                        f"{smallest} {name} corner must be fully transparent, got rgba{tuple(pixel)}"
                    )
            for row in rows:
                for position in range(0, len(row), 4):
                    red, green, blue, alpha = row[position : position + 4]
                    if alpha == 255 and red > 250 and green > 250 and blue > 250:
                        errors.append(
                            f"{smallest} contains opaque white pixels: the adaptive "
                            "foreground must not bake a plate behind the mark"
                        )
                        break
                else:
                    continue
                break
    splash = res / "values-v31/styles.xml"
    if splash.is_file():
        text = splash.read_text(encoding="utf-8")
        if "@mipmap/ic_launcher_foreground" not in text:
            errors.append(
                f"{splash} must point windowSplashScreenAnimatedIcon at the plate-free foreground"
            )
        if "windowSplashScreenBackground\">@color/loop_ink" not in text.replace("'", '"'):
            errors.append(
                f"{splash} must keep windowSplashScreenBackground on @color/loop_ink"
            )
    for launch in (res / "drawable/launch_background.xml", res / "drawable-v21/launch_background.xml"):
        if launch.is_file() and "@color/loop_ink" not in launch.read_text(encoding="utf-8"):
            errors.append(f"{launch} must keep the pre-Android-12 launch frame on LOOP Ink")
    return errors


PUSH_REGISTRATION_PATHS = (
    "lib/firebase_options.dart",
    "lib/features/notifications/push_device_gateway.dart",
    "lib/integrations/backend/v2/notifications/loop_v2_push_device_api.dart",
    "lib/integrations/notifications/firebase_notification_ingress.dart",
    "lib/integrations/notifications/loop_push_token_source.dart",
    "lib/integrations/communication/stream_push_device_registrar.dart",
    "lib/app/notifications/loop_push_registration_coordinator.dart",
    "lib/app/notifications/loop_push_registration_providers.dart",
    "android/app/google-services.json",
    "ios/Runner/GoogleService-Info.plist",
    "ios/Runner/Localizable.strings",
    "test/firebase_push_registration_test.dart",
)
# Decision 0067 sends only localization keys; every visible word is the
# client's. Android resource names cannot contain `.`, so the same six strings
# are spelled two ways — that is a constraint of the platform, not a second
# vocabulary, and both spellings are checked here so one cannot drift.
PUSH_COPY_EVENTS = (
    "priceAlertTriggered",
    "securityEvent",
    "communityVoiceRoomStarted",
)
# A format specifier here would mean the server supplies part of the sentence,
# which is the one thing the copy rule exists to prevent.
PUSH_COPY_FORBIDDEN_SUBSTITUTIONS = ("%@", "%s", "%d", "%1$", "%2$")
# The Firebase project LOOP's two mobile applications belong to. Every one of
# these appears in three places — the Android JSON, the iOS plist and
# `firebase_options.dart` — and a build where they disagree initialises one
# project in Dart and another in the native SDK.
FIREBASE_PROJECT_ID = "loop-d4746"
FIREBASE_SENDER_ID = "225868941577"
FIREBASE_ANDROID_APP_ID = "1:225868941577:android:fe779e131119af7c64abd8"
FIREBASE_IOS_APP_ID = "1:225868941577:ios:7d96d5ce4f5679a464abd8"
FIREBASE_APPLICATION_ID = "com.cywd.loop"
# What the Stream dashboard calls the two push configurations of the LOOP app.
# Stream routes by these names; a value here that no longer exists in the
# dashboard stops chat pushes without any error anybody can see.
STREAM_PUSH_PROVIDER_NAMES = ("firebase", "LOOPAPNS")


def check_push_registration_contract(root: Path) -> list[str]:
    """Lock the S70 push slice: one owner, one project, one device per account."""

    errors: list[str] = []
    for relative in PUSH_REGISTRATION_PATHS:
        if not (root / relative).is_file():
            errors.append(f"missing push registration path: {relative}")

    # 1. One Firebase project, spelled the same way in all three files.
    options_path = root / FIREBASE_OPTIONS_PATH
    if options_path.is_file():
        options = strip_dart_comments(read_text(options_path))
        for fragment in (
            f"projectId = '{FIREBASE_PROJECT_ID}'",
            f"appId: '{FIREBASE_ANDROID_APP_ID}'",
            f"appId: '{FIREBASE_IOS_APP_ID}'",
            f"messagingSenderId: '{FIREBASE_SENDER_ID}'",
            f"iosBundleId: '{FIREBASE_APPLICATION_ID}'",
        ):
            if fragment not in options:
                errors.append(
                    f"{FIREBASE_OPTIONS_PATH} must carry the reviewed Firebase value "
                    f"`{fragment}`"
                )
        if "Firebase.initializeApp" in options:
            errors.append(
                f"{FIREBASE_OPTIONS_PATH} declares options only; initialization "
                f"belongs to {NOTIFICATION_PROVIDER_INGRESS_PATH}"
            )

    android_config = root / "android/app/google-services.json"
    if android_config.is_file():
        try:
            payload = json.loads(read_text(android_config))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            errors.append(f"android/app/google-services.json is not valid JSON: {error}")
        else:
            info = payload.get("project_info", {}) if isinstance(payload, dict) else {}
            if info.get("project_id") != FIREBASE_PROJECT_ID:
                errors.append(
                    "android/app/google-services.json must name Firebase project "
                    f"{FIREBASE_PROJECT_ID}"
                )
            if info.get("project_number") != FIREBASE_SENDER_ID:
                errors.append(
                    "android/app/google-services.json must carry sender id "
                    f"{FIREBASE_SENDER_ID}"
                )
            clients = payload.get("client", []) if isinstance(payload, dict) else []
            packages = {
                client.get("client_info", {})
                .get("android_client_info", {})
                .get("package_name")
                for client in clients
                if isinstance(client, dict)
            }
            if packages != {FIREBASE_APPLICATION_ID}:
                errors.append(
                    "android/app/google-services.json must describe exactly the "
                    f"{FIREBASE_APPLICATION_ID} application, found {sorted(packages)}"
                )

    ios_config, ios_errors = _parse_plist(
        root / "ios/Runner/GoogleService-Info.plist",
        "iOS GoogleService-Info.plist",
    )
    errors.extend(ios_errors)
    if ios_config is not None:
        for key, expected in (
            ("PROJECT_ID", FIREBASE_PROJECT_ID),
            ("GCM_SENDER_ID", FIREBASE_SENDER_ID),
            ("BUNDLE_ID", FIREBASE_APPLICATION_ID),
            ("GOOGLE_APP_ID", FIREBASE_IOS_APP_ID),
        ):
            if ios_config.get(key) != expected:
                errors.append(
                    f"ios/Runner/GoogleService-Info.plist `{key}` must be `{expected}`, "
                    f"found {ios_config.get(key)!r}"
                )
        if ios_config.get("IS_GCM_ENABLED") is not True:
            errors.append(
                "ios/Runner/GoogleService-Info.plist must keep messaging enabled"
            )
    # The plist has to be in the Runner target's resources, or the native SDK
    # finds no configuration on the device and reports it there instead of here.
    xcode_project = root / "ios/Runner.xcodeproj/project.pbxproj"
    if xcode_project.is_file():
        project = read_text(xcode_project)
        if "GoogleService-Info.plist in Resources" not in project:
            errors.append(
                "ios/Runner.xcodeproj must copy GoogleService-Info.plist into the "
                "Runner target's resources"
            )

    # 2. The Android build actually reads that JSON, and the manifest can show
    #    a notification at all.
    settings_gradle = root / "android/settings.gradle.kts"
    if settings_gradle.is_file() and (
        'id("com.google.gms.google-services")' not in read_text(settings_gradle)
    ):
        errors.append(
            "android/settings.gradle.kts must declare the google-services plugin "
            "version, or google-services.json is never read"
        )
    app_gradle = root / "android/app/build.gradle.kts"
    if app_gradle.is_file() and (
        'id("com.google.gms.google-services")' not in read_text(app_gradle)
    ):
        errors.append("android/app/build.gradle.kts must apply the google-services plugin")

    manifest, manifest_errors = _parse_xml(
        root / "android/app/src/main/AndroidManifest.xml",
        "Android main manifest",
    )
    errors.extend(manifest_errors)
    if manifest is not None:
        active = [
            permission
            for permission in manifest.findall("uses-permission")
            if permission.get(ANDROID_NAME) == ANDROID_PUSH_PERMISSION
            and permission.get(ANDROID_TOOLS_NODE) != "remove"
        ]
        if len(active) != 1:
            errors.append(
                "Android push requires exactly one active "
                f"`{ANDROID_PUSH_PERMISSION}` declaration"
            )
        application = manifest.find("application")
        declared = (
            {
                meta.get(ANDROID_NAME): (
                    meta.get("{http://schemas.android.com/apk/res/android}value")
                    or meta.get("{http://schemas.android.com/apk/res/android}resource")
                )
                for meta in application.findall("meta-data")
            }
            if application is not None
            else {}
        )
        for name, expected in ANDROID_PUSH_MANIFEST_META.items():
            if declared.get(name) != expected:
                errors.append(
                    f"Android manifest must point `{name}` at `{expected}`, found "
                    f"{declared.get(name)!r}"
                )
    for relative, fragment in (
        (
            "android/app/src/main/res/values/strings.xml",
            'name="loop_notification_channel_id"',
        ),
        ("android/app/src/main/res/values/colors.xml", 'name="loop_lime"'),
        ("android/app/src/main/res/drawable/ic_loop_notification.xml", "<vector"),
        (
            "android/app/src/main/kotlin/com/cywd/loop/MainActivity.kt",
            "createNotificationChannel(",
        ),
    ):
        path = root / relative
        if path.is_file() and fragment not in read_text(path):
            errors.append(
                f"{relative} must supply the default notification channel resource "
                f"`{fragment}`"
            )

    # 3. The ingress stays the only Firebase owner, and stays narrow.
    ingress_path = root / NOTIFICATION_PROVIDER_INGRESS_PATH
    if ingress_path.is_file():
        ingress = strip_dart_comments(read_text(ingress_path))
        for fragment in (
            "Firebase.initializeApp(options: options)",
            "DefaultFirebaseOptions.currentPlatformOrNull",
            "FirebaseMessaging.onMessage",
            "FirebaseMessaging.onMessageOpenedApp",
            "_messaging.getInitialMessage()",
            "Map<String, Object?>.of(message.data)",
            "alert: false",
        ):
            if fragment not in ingress:
                errors.append(
                    "the Firebase ingress must keep reviewed behaviour "
                    f"`{fragment}`"
                )
        for fragment in (
            "onBackgroundMessage",
            "PushKit",
            "CallKit",
            "message.notification",
            "debugPrint(",
            "print(",
        ):
            if fragment in ingress:
                errors.append(
                    "the Firebase ingress must not own a background handler, VoIP "
                    f"push, provider display copy or payload logging (`{fragment}`)"
                )

    # 4. The device registration is a port with a fail-closed default, and the
    #    transport names exactly one route.
    port_path = root / "lib/features/notifications/push_device_gateway.dart"
    if port_path.is_file():
        port = strip_dart_comments(read_text(port_path))
        default_pattern = re.compile(
            r"final\s+pushDeviceGatewayProvider\s*=\s*Provider<PushDeviceGateway>\s*"
            r"\(\s*\(\s*ref\s*\)\s*=>\s*const\s+UnavailablePushDeviceGateway\s*"
            r"\(\s*\)\s*,?\s*\)\s*;",
            re.DOTALL,
        )
        if default_pattern.search(port) is None:
            errors.append(
                "pushDeviceGatewayProvider must default to "
                "UnavailablePushDeviceGateway"
            )
    api_path = root / "lib/integrations/backend/v2/notifications/loop_v2_push_device_api.dart"
    if api_path.is_file():
        api = strip_dart_comments(read_text(api_path))
        if "pushTokenPath = '/v2/devices/push-token'" not in api:
            errors.append(
                "the push device transport must address `/v2/devices/push-token`"
            )
        for fragment in (
            "LoopV2Contract.validateSuccess(response, statusCode: 200)",
            # The whole logout header set, one fresh key per attempt, and a
            # `200` that is read rather than assumed.
            "...command.headers",
            "requireTrue(root, 'registered')",
            "requireFalse(root, 'registered')",
            "requireTimestamp(root, 'observedAt')",
            "optionalTimestamp(root, 'revokedAt')",
            "LoopPushTokenRegistration.firebaseProvider",
        ):
            if fragment not in api:
                errors.append(
                    "the push device transport must strictly decode its `200` "
                    f"(`{fragment}`)"
                )

    # 5. The push copy belongs to the client, in both spellings.
    android_strings_path = root / "android/app/src/main/res/values/strings.xml"
    ios_strings_path = root / "ios/Runner/Localizable.strings"
    android_strings = (
        read_text(android_strings_path) if android_strings_path.is_file() else ""
    )
    ios_strings = read_text(ios_strings_path) if ios_strings_path.is_file() else ""
    for event in PUSH_COPY_EVENTS:
        for part in ("title", "body"):
            android_name = f'name="push_{event}_{part}"'
            ios_key = f'"push.{event}.{part}"'
            if android_strings and android_name not in android_strings:
                errors.append(
                    f"android strings.xml must define the push copy {android_name}"
                )
            if ios_strings and ios_key not in ios_strings:
                errors.append(
                    f"ios Localizable.strings must define the push copy {ios_key}"
                )
    for table, label in ((android_strings, "android"), (ios_strings, "ios")):
        for marker in PUSH_COPY_FORBIDDEN_SUBSTITUTIONS:
            if marker in table:
                errors.append(
                    f"{label} push copy must not take a substitution (`{marker}`); "
                    "a notification says what kind of thing happened, and the "
                    "server supplies no part of the sentence"
                )
    if xcode_project.is_file() and (
        "Localizable.strings in Resources" not in read_text(xcode_project)
    ):
        errors.append(
            "ios/Runner.xcodeproj must copy Localizable.strings into the Runner "
            "target's resources, or `loc-key` resolves to the key itself"
        )

    # 6. Registration waits for the capability, and sign-out drops it first.
    coordinator_path = root / "lib/app/notifications/loop_push_registration_coordinator.dart"
    if coordinator_path.is_file():
        coordinator = strip_dart_comments(read_text(coordinator_path))
        for fragment in (
            "if (!_readPushCapabilityAvailable()) {",
            "_record(LoopPushRegistrationGate.capabilityUnavailable);",
            "_runtimeDeferred = true;",
            "if (_askedPrincipal != principal)",
            # Decision 0076: the permission is asked for once the account has
            # arrived in Community, not at the moment it becomes addressable.
            # Both paths that can register carry the same gate, because the
            # provider issues its first token by itself.
            "if (!_readCommunityReached()) {",
            # A refusal is read again, never asked again: the owner was told
            # to change it in the system settings, and `requestPermission`
            # would report the stale answer for the rest of the install.
            "_permission = await _source.currentPermission();",
        ):
            if fragment not in coordinator:
                errors.append(
                    "push registration must wait for the capability and for the "
                    "arrival in Community, ask the device once per account, read "
                    "a refusal rather than repeat it, and stop after a deferred "
                    f"runtime (`{fragment}`)"
                )
        if coordinator.count("if (!_readCommunityReached()) {") != 2:
            errors.append(
                "both registration paths — the synchronisation and the provider's "
                "own token refresh — must wait for the arrival in Community "
                "(decision 0076)"
            )
        arrival_gate = coordinator.find("_readCommunityReached()")
        prompt = coordinator.find("_source.requestPermission()")
        if arrival_gate < 0 or prompt < 0 or arrival_gate > prompt:
            errors.append(
                "the arrival in Community must be checked before the device is "
                "asked for the notification permission (decision 0076)"
            )
        # A composition with no push provider says so itself, rather than
        # reporting whichever account condition happened to be read first.
        source_gate = coordinator.find("if (!_source.isEnabled) {")
        later_gates = {
            "the platform": coordinator.find("if (platform == null) {"),
            "the account": coordinator.find("if (principal == null) {"),
            "the arrival in Community": arrival_gate,
            "the capability": coordinator.find(
                "if (!_readPushCapabilityAvailable()) {"
            ),
        }
        if source_gate < 0:
            errors.append(
                "a build with no push provider must be the first thing the "
                "registration reports (`if (!_source.isEnabled) {`)"
            )
        else:
            for name, position in later_gates.items():
                if 0 <= position < source_gate:
                    errors.append(
                        "a build with no push provider must be reported before "
                        f"{name} is looked at, or a device with no Firebase "
                        "describes itself as an account that is not ready yet"
                    )

    # 7. Stream's two configurations are named once, where a rename is visible.
    registrar_path = root / "lib/integrations/communication/stream_push_device_registrar.dart"
    if registrar_path.is_file():
        registrar = strip_dart_comments(read_text(registrar_path))
        for name in STREAM_PUSH_PROVIDER_NAMES:
            if f"'{name}'" not in registrar:
                errors.append(
                    "the Stream push registrar must name dashboard configuration "
                    f"`{name}`"
                )
        if "pushProviderName: device.provider.configurationName" not in registrar:
            errors.append(
                "the Stream push registrar must send the dashboard configuration "
                "name with every device"
            )

    # 6. Sign-out drops the registration while the credentials still exist.
    application_path = root / "lib/app.dart"
    if application_path.is_file():
        application = strip_dart_comments(read_text(application_path))
        revoke = application.find("revokeForSignOut()")
        exit_call = application.find(".exit(")
        if revoke < 0 or exit_call < 0 or revoke > exit_call:
            errors.append(
                "lib/app.dart must revoke the push registration before "
                "`LoopSessionController.exit`, while the session that created it "
                "still exists"
            )
        # S73: the session turns authenticated before the LOOP identity behind
        # it exists, and the bootstrap owner is published once and filled in
        # afterwards. Without an explicit re-ask at the moment the backend
        # agrees the account exists, the registration stops at "no account"
        # for the rest of the run and the device is never asked for the
        # notification permission at all.
        #
        # Comments are blanked rather than removed, so the check reads the
        # code that follows with its whitespace collapsed, and it is anchored
        # to the end of the guard clause rather than to a window.
        authorized = re.search(
            r"authorization\s*!=\s*LoopBootstrapAuthorization\.authorized"
            r"\s*\)\s*\{\s*return;\s*\}",
            re.sub(r"\s+", " ", application),
        )
        collapsed = re.sub(r"\s+", " ", application)
        if authorized is None or not collapsed[authorized.end() :].lstrip().startswith(
            "pushRegistrationCoordinator.onIdentityMayHaveChanged();"
        ):
            errors.append(
                "lib/app.dart must re-evaluate the push registration once the "
                "backend has agreed the account exists, or no device is ever "
                "asked for the notification permission"
            )
        # Decision 0076: the arrival is the landing `GET /v2/profile`
        # produced, not a location — a deep link under `/community/…` is an
        # arrival too. Both places the answer can become Community mark it,
        # and leaving the account takes it away again.
        for fragment in (
            "if (next.landing == LoopProfileLanding.community) "
            "_onCommunityArrival();",
            "ref.read(loopCommunityArrivalProvider.notifier).landed()",
            "ref.read(loopCommunityArrivalProvider.notifier).leave();",
        ):
            if fragment not in collapsed:
                errors.append(
                    "lib/app.dart must mark the arrival in Community from the "
                    f"landing the profile read published (`{fragment}`)"
                )
        if collapsed.count("_onCommunityArrival();") < 2:
            errors.append(
                "both paths into Community — the published landing and the end "
                "of the five-step opening — must mark the arrival (decision "
                "0076)"
            )
        if re.search(
            r"matchedLocation\s*==\s*(LoopRouteManifest\.defaultPath|'/community')",
            collapsed,
        ):
            errors.append(
                "the arrival in Community must not be read from a route "
                "location: a deep link under `/community/…` would never arrive"
            )
        # Decision 0076: the landing says where the account belongs; only the
        # shell can say a page was drawn. Acting on the landing alone raises
        # the dialog over the page the owner is still looking at — the launch
        # page on a restored session, 创建 LOOP ID at the end of the opening.
        for fragment in (
            "LoopProductFrameReporter(",
            "ref.read(loopCommunityArrivalProvider.notifier).productDrawn()",
        ):
            if fragment not in collapsed:
                errors.append(
                    "lib/app.dart must take the drawn product frame as the "
                    f"other half of the arrival (`{fragment}`)"
                )
    return errors


def check_secret_paths(paths: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in paths:
        name = path.name.casefold()
        if name == ".env" or (name.startswith(".env.") and not name.endswith((".example", ".sample", ".template"))):
            errors.append(f"repository environment-secret file is forbidden: {path}")
        if path.suffix.casefold() in {".key", ".p8", ".p12", ".pem"}:
            errors.append(f"repository privileged-credential path is forbidden: {path}")
        if any(marker in name for marker in ("firebase-adminsdk", "service-account", "service_account")):
            errors.append(f"repository privileged-credential path is forbidden: {path}")
    return errors


def check_gitignore(root: Path) -> list[str]:
    expectations = {".env": True, ".env.local": True, ".env.example": False, ".gitnexus/index": True}
    errors: list[str] = []
    for candidate, expected in expectations.items():
        result = subprocess.run(
            ["git", "-C", str(root), "check-ignore", "--no-index", "--quiet", "--", candidate],
            check=False,
        )
        ignored = result.returncode == 0
        if result.returncode not in (0, 1):
            errors.append(f"unable to evaluate .gitignore for `{candidate}`")
        elif ignored != expected:
            errors.append(f".gitignore expectation failed for `{candidate}`")
    return errors


def check_gitnexusignore(root: Path) -> list[str]:
    """Keep generated native and frozen reference trees out of code impact."""

    path = root / ".gitnexusignore"
    if not path.is_file():
        return ["missing GitNexus source-boundary file: .gitnexusignore"]
    rules = {
        line.strip()
        for line in read_text(path).splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    errors: list[str] = []
    for required in ("ios/Pods/", "reference/legacy-prototype/"):
        if required not in rules:
            errors.append(
                ".gitnexusignore must exclude generated or frozen source tree "
                f"`{required}`"
            )
    return errors


def validate(root: Path = ROOT) -> list[str]:
    errors = check_required_files(root)
    profile, profile_errors = load_profile(root)
    errors.extend(profile_errors)
    if profile:
        errors.extend(check_profile(root, profile))
    errors.extend(check_dependency_pins(root))
    errors.extend(check_spot_only_product_contract(root))
    errors.extend(check_new_pairs_preview_truth_contract(root))
    errors.extend(check_chat_spot_snapshot_contract(root))
    errors.extend(check_chat_preview_message_request_contract(root))
    errors.extend(check_chat_preview_conversation_id_contract(root))
    errors.extend(check_security_capability_truth_contract(root))
    errors.extend(check_app_lock_contract(root))
    errors.extend(check_account_mfa_contract(root))
    errors.extend(check_local_display_preferences_contract(root))
    errors.extend(check_onboarding_sequence_contract(root))
    errors.extend(check_build_profile_configuration_contract(root))
    errors.extend(check_network_dio_policy_contract(root))
    errors.extend(check_stream_token_client_contract(root))
    errors.extend(check_v2_session_contract(root))
    errors.extend(check_spot_candle_contract(root))
    errors.extend(check_wallet_identity_readiness_contract(root))
    errors.extend(check_wallet_preview_route_contract(root))
    errors.extend(check_wallet_local_draft_contract(root))
    errors.extend(check_wallet_providerless_controls_contract(root))
    errors.extend(check_native_matrix(root))
    errors.extend(check_android_release_network_contract(root))
    errors.extend(check_reown_identity_contract(root))
    errors.extend(check_audio_room_native_contract(root))
    errors.extend(check_chat_camera_contract(root))
    errors.extend(check_chat_token_card_contract(root))
    errors.extend(check_product_contract(root))
    errors.extend(check_v2_primary_navigation_contract(root))
    errors.extend(check_v2_community_truth_contract(root))
    errors.extend(check_community_ai_contract(root))
    errors.extend(check_community_identity_contract(root))
    errors.extend(check_route_manifest_contract(root))
    errors.extend(check_chat_attachment_contract(root))
    errors.extend(check_production_chat_audio_room_entry(root))
    errors.extend(check_friend_frontend_contract(root))
    errors.extend(check_notification_contract(root))
    errors.extend(check_push_registration_contract(root))
    errors.extend(check_s5_truth_contract(root))
    errors.extend(check_s6_money_action_contract(root))
    errors.extend(check_s7_truth_contract(root))
    errors.extend(check_s9_dual_chain_contract(root))
    errors.extend(check_providerless_application_contract(root))
    errors.extend(check_watchlist_application_contract(root))
    errors.extend(check_profile_application_contract(root))
    errors.extend(check_privacy_application_contract(root))
    errors.extend(check_notification_preferences_application_contract(root))
    errors.extend(check_perp_positions_application_contract(root))
    errors.extend(check_source_guards(root))
    errors.extend(check_user_visible_copy(root))
    errors.extend(check_stream_user_identity_rendering(root))
    errors.extend(check_typography_band_contract(root))
    errors.extend(check_light_ground_contract(root))
    errors.extend(check_page_mount_theme_contract(root))
    errors.extend(check_ground_probe_armed(root))
    errors.extend(check_self_mounted_pages_watched(root))
    errors.extend(check_records(root))
    errors.extend(check_launch_icon_contract(root))
    visible, visible_error = git_visible_paths(root)
    if visible_error:
        errors.append(f"unable to inspect Git-visible paths: {visible_error}")
    else:
        errors.extend(check_secret_paths(visible))
    errors.extend(check_gitignore(root))
    errors.extend(check_gitnexusignore(root))
    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("Harness check failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(
        "Harness check passed: profile, five-destination V2 contract, "
        "V2 community truth, one community face on every page, pins, "
        "Spot-only product, New Pairs source-scoped truth, Chat snapshot, Preview request truth and exact conversation identity, security capability truth, provider-owned MFA, device-local application lock, device-local display preferences, five-step account opening, Dio trust boundaries, bounded candle, Wallet identity, Wallet route, local draft, "
        "S5 chain/market/wallet-read truth, S6 money-action truth, "
        "S7 launch/mining/referral truth, S9 dual chain slots, "
        "seven-band typography with bundled Noto Sans SC, "
        "declared light grounds, pages mounted under the product theme, "
        "armed page ground probe, watched self-mounted pages, "
        "plate-free launch icon, "
        "build-profile isolation, bounded Stream token loading, providerless control boundaries, production Audio Room entry, Debug-only routine "
        "verification, authenticated social/friend/group boundaries, records, user-visible copy, "
        "channel-resolved chat names, recognised chat contract addresses, "
        "and secret rules are consistent."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
