#!/usr/bin/env python3
"""Validate Loop Mobile's repository-level engineering harness."""

from __future__ import annotations

import json
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PRIMARY_DESTINATIONS = ["Home", "Market", "Launch", "Chat", "Wallet", "Profile"]
PINNED_DEPENDENCIES = {
    "cupertino_icons": "1.0.8",
    "decimal": "3.2.6",
    "dio": "5.11.0",
    "firebase_core": "4.13.0",
    "firebase_messaging": "16.5.0",
    "flutter_lints": "6.0.0",
    "flutter_riverpod": "3.4.2",
    "go_router": "17.5.0",
    "privy_flutter": "0.10.1",
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
    "docs/failures/flutter-gradle-version-floor.md",
    "docs/failures/providerless-notification-fixtures.md",
    "docs/failures/privy-android-compile-sdk.md",
    "docs/failures/principal-agnostic-wallet-single-flight.md",
    "docs/failures/production-chat-preview-route-leak.md",
    "docs/failures/sqlite3-native-hook-download.md",
    "docs/failures/swiftpm-file-picker-cold-cache.md",
    "docs/harness/adoption-report.md",
    "docs/open-source-attribution.md",
    "docs/phase-0/compatibility-report.md",
    "docs/phase-1/frontend-integration-report.md",
    "lib/core/navigation/stream_channel_route.dart",
    "lib/app/loop_display_preferences.dart",
    "lib/app/notifications/loop_notification_coordinator.dart",
    "lib/integrations/notifications/loop_notification_event_source.dart",
    "lib/integrations/notifications/loop_notification_router.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_market.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_market_providers.dart",
    "lib/integrations/hyperliquid/hyperliquid_spot_market_repository.dart",
    "lib/features/market/watchlist/watchlist_controller.dart",
    "lib/features/market/watchlist/watchlist_gateway.dart",
    "lib/features/market/watchlist/watchlist_models.dart",
    "lib/integrations/personalization/memory_watchlist_gateway.dart",
    "lib/features/profile/presentation/profile_controller.dart",
    "lib/features/profile/presentation/profile_gateway.dart",
    "lib/features/profile/presentation/profile_models.dart",
    "lib/integrations/personalization/memory_profile_gateway.dart",
    "lib/features/profile/privacy/privacy_controller.dart",
    "lib/features/profile/privacy/privacy_gateway.dart",
    "lib/features/profile/privacy/privacy_models.dart",
    "lib/integrations/personalization/memory_privacy_gateway.dart",
    "lib/features/profile/notification_preferences/notification_preferences_controller.dart",
    "lib/features/profile/notification_preferences/notification_preferences_gateway.dart",
    "lib/features/profile/notification_preferences/notification_preferences_models.dart",
    "lib/integrations/personalization/memory_notification_preferences_gateway.dart",
    "lib/features/perp/account/perp_account_controller.dart",
    "lib/features/perp/perp_portfolio_screens.dart",
    "lib/features/perp/positions/perp_positions_controller.dart",
    "lib/features/perp/private/perp_private_gateway.dart",
    "lib/features/perp/private/perp_private_models.dart",
    "lib/integrations/backend/loop_perp_providers.dart",
    "lib/integrations/backend/loop_perp_repository.dart",
    "lib/integrations/backend/loop_perp_session.dart",
    "test/app_notification_coordinator_test.dart",
    "test/loop_notification_coordinator_test.dart",
    "test/loop_notification_router_test.dart",
    "test/development_preview_experience_test.dart",
    "test/hyperliquid_spot_market_repository_test.dart",
    "test/local_settings_and_help_test.dart",
    "test/market_screen_test.dart",
    "test/notifications_screen_test.dart",
    "test/watchlist_controller_test.dart",
    "test/watchlist_editor_screen_test.dart",
    "test/watchlist_models_test.dart",
    "test/profile_controller_test.dart",
    "test/profile_models_test.dart",
    "test/profile_presentation_screen_test.dart",
    "test/privacy_controller_test.dart",
    "test/privacy_models_test.dart",
    "test/privacy_presentation_screen_test.dart",
    "test/notification_preferences_controller_test.dart",
    "test/notification_preferences_models_test.dart",
    "test/notification_preferences_screen_test.dart",
    "test/loop_perp_providers_test.dart",
    "test/loop_perp_repository_test.dart",
    "test/loop_perp_session_test.dart",
    "test/perp_account_controller_test.dart",
    "test/perp_account_screen_test.dart",
    "test/perp_positions_controller_test.dart",
    "test/perp_positions_screen_test.dart",
)
CHAT_PREVIEW_ONLY_ROUTES = (
    "/chat/group",
    "/chat/dm",
    "/chat/group-info",
    "/chat/requests",
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
                "LoopColors, LoopRadius"
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
ANDROID_TOOLS_NODE = "{http://schemas.android.com/tools}node"
ANDROID_INTERNET_PERMISSION = "android.permission.INTERNET"
ANDROID_AUDIO_ROOM_PERMISSIONS = frozenset(
    {
        "android.permission.RECORD_AUDIO",
        "android.permission.MODIFY_AUDIO_SETTINGS",
    }
)
ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS = frozenset(
    {
        "android.permission.POST_NOTIFICATIONS",
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
ANDROID_AUDIO_ROOM_FORBIDDEN_ACTIVE_PERMISSIONS = frozenset(
    {*ANDROID_AUDIO_ROOM_REMOVED_PERMISSIONS, "android.permission.CAMERA"}
)
IOS_AUDIO_ROOM_FORBIDDEN_ENTITLEMENTS = frozenset(
    {
        "aps-environment",
        "com.apple.developer.aps-environment",
        "com.apple.developer.background-modes",
        "com.apple.developer.usernotifications.communication",
        "com.apple.developer.voip",
    }
)
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
NOTIFICATION_ROUTER_IMPORTS = frozenset(
    {
        "'dart:collection'",
        "'package:loop_mobile/core/navigation/stream_channel_route.dart'",
    }
)
NOTIFICATION_PROVIDER_IMPORT_ALLOWED_PATHS = frozenset(
    {
        Path("lib/app/bootstrap/sdk_compatibility.dart"),
        NOTIFICATION_PROVIDER_INGRESS_PATH,
    }
)
NOTIFICATION_PROVIDER_IMPORT_MARKERS = (
    "package:firebase_core/firebase_core.dart",
    "package:firebase_messaging/firebase_messaging.dart",
)
NOTIFICATION_KIND_MEMBERS = frozenset(
    {"chatMessage", "audioRoomActivity", "systemNotice"}
)
NOTIFICATION_SOURCE_EVENT_KIND_MEMBERS = frozenset(
    {"foreground", "background", "interaction"}
)
NOTIFICATION_INTENT_CLASSES = frozenset(
    {
        "LoopChatNotificationIntent",
        "LoopAudioRoomNotificationIntent",
        "LoopNotificationCenterIntent",
    }
)
NOTIFICATION_ROUTE_LITERALS = frozenset(
    {
        "/chat/channel/${Uri.encodeComponent(channel.cid)}",
        "/chat/voice",
        "/notifications",
    }
)
NOTIFICATION_ROUTER_CONSUMER_PATHS = frozenset(
    {NOTIFICATION_ROUTER_PATH, NOTIFICATION_COORDINATOR_PATH}
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
FEATURE_BACKEND_ROUTE_PATTERN = re.compile(r"(?P<quote>['\"])/v1/")
PRODUCTION_FIXTURE_MARKERS = (
    "MemoryCommunicationGateway(",
    "MemoryNotificationPreferencesGateway",
    "MemoryPrivacyGateway",
    "MemoryProfileGateway",
    "MemoryWatchlistGateway(",
    "HyperliquidFixtureAdapter(",
    "PrivyFixtureAdapter(",
)
WATCHLIST_GATEWAY_PATH = Path(
    "lib/features/market/watchlist/watchlist_gateway.dart"
)
WATCHLIST_MODELS_PATH = Path(
    "lib/features/market/watchlist/watchlist_models.dart"
)
WATCHLIST_MEMORY_GATEWAY_PATH = Path(
    "lib/integrations/personalization/memory_watchlist_gateway.dart"
)
WATCHLIST_PREVIEW_ROOT_PATH = Path("lib/main_preview.dart")
WATCHLIST_MEMORY_CONSTRUCTION_PATTERN = re.compile(
    r"\bMemoryWatchlistGateway\s*\("
)
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
PRIVACY_VISIBILITY_WIRE_VALUES = {
    "private": "private",
    "followers": "followers",
    "public": "public",
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
PRIVACY_BEHAVIOR_TEST_MARKERS = {
    Path("test/privacy_models_test.dart"): (
        "uses the exact fail-closed backend defaults",
        "round-trips only the reviewed copy-trade visibility values",
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
        "production Privacy fails closed without controls or preview claims",
        "Preview edits both exact preferences and commits only advanced evidence",
        "version conflict preserves both draft fields until reload",
        "mounted Privacy replaces the old owner after gateway rotation",
        "Privacy supports a 390pt screen at 2x Dynamic Type",
        "legacy H3 controls and fake Copy permission save are absent",
    ),
}
NOTIFICATION_PREFERENCES_GATEWAY_PATH = Path(
    "lib/features/profile/notification_preferences/notification_preferences_gateway.dart"
)
NOTIFICATION_PREFERENCES_MODELS_PATH = Path(
    "lib/features/profile/notification_preferences/notification_preferences_models.dart"
)
NOTIFICATION_PREFERENCES_MEMORY_GATEWAY_PATH = Path(
    "lib/integrations/personalization/memory_notification_preferences_gateway.dart"
)
NOTIFICATION_PREFERENCES_SURFACE_PATH = Path(
    "lib/features/profile/profile_screens.dart"
)
NOTIFICATION_PREFERENCES_PREVIEW_ROOT_PATH = Path("lib/main_preview.dart")
NOTIFICATION_PREFERENCES_MEMORY_CONSTRUCTION_PATTERN = re.compile(
    r"\bMemoryNotificationPreferencesGateway\s*\("
)
NOTIFICATION_PREFERENCES_MEMORY_REFERENCE_PATTERN = re.compile(
    r"\bMemoryNotificationPreferencesGateway\b"
)
NOTIFICATION_PREFERENCE_EVENT_WIRE_VALUES = {
    "priceAlertTriggered": "price_alert_triggered",
    "providerActivityProjected": "provider_activity_projected",
    "securityNotice": "security_notice",
    "supportUpdate": "support_update",
}
NOTIFICATION_DELIVERY_STATE_WIRE_VALUES = {"unavailable": "unavailable"}
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
    r"(?:已保存|保存成功|已提交|提交成功|已应用|应用成功|已生效)|"
    r"(?:通知|提醒).{0,8}(?:已开启|已启用|已连接|将会送达|将收到)"
)
NOTIFICATION_PREFERENCES_BEHAVIOR_TEST_MARKERS = {
    Path("test/notification_preferences_models_test.dart"): (
        "uses the exact disabled backend defaults",
        "round-trips only the four notification event wire values",
        "keeps delivery permanently unavailable",
        "enforces notification preference resource version bounds",
    ),
    Path("test/notification_preferences_controller_test.dart"): (
        "production defaults directly unavailable",
        "load and save are single-flight and save the complete fixed set",
        "version conflict freezes the draft until reload succeeds",
        "an ambiguous save retries the same version and converges",
        "gateway rotation and disposal retire late work safely",
    ),
    Path("test/notification_preferences_screen_test.dart"): (
        "production Notification Preferences fails closed without controls or preview claims",
        "Preview edits the exact four preferences and commits only advanced evidence",
        "version conflict preserves the preference draft until reload",
        "mounted Notification Preferences replaces the old owner after gateway rotation",
        "Notification Preferences supports a 390pt screen at 2x Dynamic Type",
        "legacy H9 categories and fake delivery claims are absent",
    ),
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


def dart_enum_members(source: str, enum_name: str) -> set[str] | None:
    """Return enhanced-enum members declared before the first semicolon."""

    match = re.search(
        rf"\benum\s+{re.escape(enum_name)}\s*\{{(?P<body>.*?)\s*;",
        source,
        re.DOTALL,
    )
    if match is None:
        return None
    members = {
        member.strip()
        for member in match.group("body").split(",")
        if member.strip()
    }
    return members


def dart_enum_wire_mappings(
    source: str, enum_name: str
) -> tuple[dict[str, str], dict[str, str], bool]:
    """Read a fail-closed enhanced enum's forward and reverse wire switches."""

    enum_match = re.search(rf"\benum\s+{re.escape(enum_name)}\b", source)
    if enum_match is None:
        return {}, {}, False
    next_declaration = re.search(
        r"\b(?:enum|class)\s+[A-Za-z_]\w*\b", source[enum_match.end() :]
    )
    section_end = (
        enum_match.end() + next_declaration.start()
        if next_declaration is not None
        else len(source)
    )
    enum_source = source[enum_match.start() : section_end]
    wire_getter_match = re.search(
        r"String\s+get\s+wireValue\s*=>\s*switch\s*\(\s*this\s*\)\s*"
        r"\{(?P<body>.*?)\}\s*;",
        enum_source,
        re.DOTALL,
    )
    if wire_getter_match is not None:
        forward_wire_values = {
            member: wire_value
            for member, _, wire_value in re.findall(
                rf"\b{re.escape(enum_name)}\.(\w+)\s*=>\s*(['\"])([^'\"]*)\2",
                wire_getter_match.group("body"),
            )
        }
    else:
        direct_wire_match = re.search(
            r"String\s+get\s+wireValue\s*=>\s*(['\"])([^'\"]*)\1\s*;",
            enum_source,
        )
        members = dart_enum_members(
            strip_dart_comments_and_strings(enum_source), enum_name
        )
        forward_wire_values = (
            {next(iter(members)): direct_wire_match.group(2)}
            if direct_wire_match is not None and members is not None and len(members) == 1
            else {}
        )
    from_wire_match = re.search(
        rf"static\s+{re.escape(enum_name)}\s+fromWire\s*"
        r"\(\s*String\s+\w+\s*\)\s*=>\s*switch\s*\([^)]*\)\s*"
        r"\{(?P<body>.*?)\}\s*;",
        enum_source,
        re.DOTALL,
    )
    reverse_wire_values = (
        {
            wire_value: member
            for _, wire_value, member in re.findall(
                rf"(['\"])([^'\"]*)\1\s*=>\s*{re.escape(enum_name)}\.(\w+)\b",
                from_wire_match.group("body"),
            )
        }
        if from_wire_match
        else {}
    )
    rejects_unknown = bool(
        from_wire_match
        and re.search(r"\b_\s*=>\s*throw\b", from_wire_match.group("body"))
    )
    return forward_wire_values, reverse_wire_values, rejects_unknown


def contains_positive_notification_preferences_language(source: str) -> bool:
    """Reject save or delivery success claims unsupported by production evidence."""

    for content in dart_concatenated_string_contents(source):
        normalized = " ".join(content.split())
        normalized_word = normalized.casefold().rstrip(".!?…")
        if normalized_word in {
            "saved",
            "committed",
            "applied",
            "delivered",
            "delivery connected",
            "notifications enabled",
            "保存成功",
        }:
            return True
        if NOTIFICATION_PREFERENCES_POSITIVE_COMMIT_PATTERN.search(normalized):
            return True
        if NOTIFICATION_PREFERENCES_POSITIVE_DELIVERY_PATTERN.search(normalized):
            return True
        if NOTIFICATION_PREFERENCES_POSITIVE_CJK_PATTERN.search(normalized):
            return True
    return False


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
        errors.append("harness.json must preserve Home / Market / Launch / Chat / Wallet / Profile in order")

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
    "lib/features/home/home_screens.dart",
    "lib/features/wallet/wallet_overview_screens.dart",
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
            "lib/features/market/market_screens.dart": (
                "hyperliquidSpotMarketsProvider",
                "TESTNET · SPOT · 实时公共数据 · 只读",
                "class LegacyPerpetualMarketScreen",
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
                "explicit Preview shows live public Spot and an interactive offline Chat",
            ),
            "test/hyperliquid_spot_market_repository_test.dart": (
                "joins sparse tokens and shuffled",
                "contexts by provider coin",
            ),
        },
    )

    for relative in SPOT_ONLY_PRIMARY_PATHS:
        path = root / relative
        if path.is_file() and "/perp" in read_text(path):
            errors.append(
                f"{relative} must not mount a retained Perp product route"
            )

    market_path = root / "lib/features/market/market_screens.dart"
    if market_path.is_file():
        source = read_text(market_path)
        boundary = source.find("class LegacyPerpetualMarketScreen")
        if boundary < 0:
            errors.append(
                "Market must keep retained Perp history behind an explicit legacy boundary"
            )
        else:
            mounted_source = source[:boundary]
            for marker in ("/perp", "hyperliquidMarketsProvider"):
                if marker in mounted_source:
                    errors.append(
                        "Mounted Market must remain Spot-only without legacy marker "
                        f"`{marker}`"
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
            "ios/Podfile.lock": ("COCOAPODS: 1.16.2",),
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
        if "NSCameraUsageDescription" in info:
            errors.append("iOS foreground Audio Room must not declare NSCameraUsageDescription")
        if "UIBackgroundModes" in info:
            errors.append("iOS foreground Audio Room must not declare UIBackgroundModes")

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
                "Home / Market / Launch / Chat / Wallet / Profile",
                "harness.json",
                "python3 scripts/check_harness.py",
            ),
            "AGENTS.md": (
                "Repository phase: `active`.",
                "Home / Market / Launch / Chat / Wallet / Profile",
                "Launchpad remains a first-class destination",
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
                "cmt2t8k4n00780cjsxjqk0dkq",
                "client-WY6ctzX8CSMMKhbvz8exuLovn1dTJyq8hReY1x63pBFfd",
                "qpwjdy8zjbdu",
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
                "AppLifecycleState.paused",
                "AppLifecycleState.hidden",
                "AppLifecycleState.detached",
                "_retireForBackground()",
                "_resumeAfterBackgroundRetirement",
                "Retry cleanup",
            ),
            "lib/features/chat/calls/stream_foreground_call_view.dart": (
                "required this.retirementStarted",
                "Leave retry required",
            ),
        },
    )
    profile, profile_errors = load_profile(root)
    errors.extend(profile_errors)
    if profile:
        purpose = profile.get("project", {}).get("purpose")
        if isinstance(purpose, str):
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


def check_chat_attachment_contract(root: Path) -> list[str]:
    """Keep preview conversations out of production and token cards fail-closed."""

    errors = require_fragments(
        root,
        {
            "lib/app.dart": (
                "LoopStreamTokenCardAttachmentBuilder()",
                "LoopStreamTokenCardMessagePreviewFormatter()",
                "configData: _loopStreamConfiguration",
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
            guarded_builder = re.match(
                r"builder\s*:\s*\([^)]*\)\s*=>\s*const\s+ChatPreviewRouteGuard\s*\(",
                route_block[first_builder.start() :] if first_builder else "",
            )
            if guarded_builder is None:
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


def check_source_guards(root: Path) -> list[str]:
    forbidden = {
        "PrivyLogLevel.debug": "Privy debug logging can expose OTPs and access tokens",
        "PrivyLogLevel.verbose": "Privy verbose logging can expose OTPs and access tokens",
        ".devToken(": "Stream development tokens bypass backend identity validation",
        "connectGuestUser(": "Stream guest users bypass the Privy identity boundary",
        "Firebase.initializeApp(": "Firebase must wait for real mobile configs and push-provider names",
    }
    errors: list[str] = []
    for path in sorted((root / "lib").rglob("*.dart")):
        text = read_text(path)
        for fragment, reason in forbidden.items():
            if fragment in text:
                errors.append(f"{path.relative_to(root)} contains forbidden `{fragment}`: {reason}")
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
            "static const String schema = 'notification.v1'",
            "static const String chatMessageKind = 'chat.message'",
            "static const String audioRoomActivityKind = 'audio_room.activity'",
            "static const String systemNoticeKind = 'system.notice'",
            "'recipient_stream_user_id'",
            "LoopNotificationIngress.foreground",
            "LoopNotificationIngress.background",
            "LoopNotificationIngress.interaction",
            "LoopNotificationSessionMode.authenticated",
            "LoopNotificationDisposition.duplicateInteraction",
            "Uri.encodeComponent(channel.cid)",
            "String get location => '/chat/voice'",
            "String get location => '/notifications'",
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
            r"enum\s+_LoopNotificationKind\s*\{(?P<body>[^}]*)\}",
            executable_code,
            re.DOTALL,
        )
        kind_members = (
            frozenset(
                member.strip()
                for member in kind_match.group("body").split(",")
                if member.strip()
            )
            if kind_match
            else frozenset()
        )
        if kind_members != NOTIFICATION_KIND_MEMBERS:
            errors.append(
                "notification kinds must stay on the reviewed three-kind allowlist: "
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
                "notification intents must stay on the reviewed three-class allowlist: "
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
        authenticated_context_pattern = re.compile(
            r"return\s+LoopNotificationSessionContext\s*\.\s*authenticated\s*"
            r"\(\s*identity\s*\.\s*streamUserId\s*\)\s*;"
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
                "real authenticated session and bootstrap-derived stream identity"
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

    production_entrypoint = root / "lib/main.dart"
    if production_entrypoint.is_file():
        production_code = strip_dart_comments_and_strings(
            read_text(production_entrypoint)
        )
        if re.search(
            r"\bloopNotificationEventSourceProvider\s*\.\s*override",
            production_code,
        ):
            errors.append(
                "lib/main.dart must not override the disabled production notification "
                "source before provider ingress is reviewed"
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


def check_providerless_application_contract(root: Path) -> list[str]:
    """Keep transport and deterministic fakes outside production features."""

    errors: list[str] = []
    features_root = root / "lib" / "features"
    if features_root.is_dir():
        for path in sorted(features_root.rglob("*.dart")):
            executable = strip_dart_comments(read_text(path))
            relative = path.relative_to(root)
            for marker in FEATURE_TRANSPORT_FORBIDDEN_IMPORTS:
                if marker in executable:
                    errors.append(
                        f"{relative} imports transport `{marker}`; providerless feature "
                        "logic must depend on a narrow port"
                    )
            if FEATURE_BACKEND_ROUTE_PATTERN.search(executable):
                errors.append(
                    f"{relative} contains a LOOP backend route literal; `/v1/` paths "
                    "belong only in integration adapters"
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

    preview_root = root / WATCHLIST_PREVIEW_ROOT_PATH
    if preview_root.is_file():
        preview_code = strip_dart_comments_and_strings(read_text(preview_root))
        if len(WATCHLIST_MEMORY_CONSTRUCTION_PATTERN.findall(preview_code)) != 1:
            errors.append(
                "lib/main_preview.dart must compose exactly one explicit "
                "MemoryWatchlistGateway"
            )

    lib_root = root / "lib"
    if lib_root.is_dir():
        allowed = frozenset(
            {WATCHLIST_MEMORY_GATEWAY_PATH, WATCHLIST_PREVIEW_ROOT_PATH}
        )
        for path in sorted(lib_root.rglob("*.dart")):
            relative = path.relative_to(root)
            if relative in allowed:
                continue
            executable_code = strip_dart_comments_and_strings(read_text(path))
            if WATCHLIST_MEMORY_CONSTRUCTION_PATTERN.search(executable_code):
                errors.append(
                    f"{relative} constructs MemoryWatchlistGateway; the fake may "
                    "only be defined by its integration and composed by "
                    "lib/main_preview.dart"
                )
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
        expected_values_fields = {
            ("final", "String?", "alias"),
            ("final", "String?", "avatarRef"),
        }
        if actual_values_fields != expected_values_fields:
            rendered_fields = ", ".join(
                f"{modifiers} {field_type} {name}".strip()
                for modifiers, field_type, name in sorted(
                    actual_values_fields or set()
                )
            ) or "none"
            errors.append(
                "ProfileValues fields must be exactly nullable String alias "
                "and nullable String avatarRef; found: " + rendered_fields
            )
        actual_resource_fields = dart_class_fields(
            models_code, "ProfileResource"
        )
        expected_resource_fields = {
            ("final", "int", "version"),
            ("final", "ProfileValues", "values"),
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
                "ProfileResource fields must be exactly final int version, "
                "final ProfileValues values, and final nullable DateTime "
                "updatedAt; found: " + rendered_fields
            )

    surface_path = root / PROFILE_SURFACE_PATH
    if surface_path.is_file():
        surface = strip_dart_comments(read_text(surface_path))
        edit_start = surface.find("class _ProfileEdit")
        privacy_start = surface.find("class _PrivacyCenter", edit_start)
        edit_surface = (
            surface[edit_start:privacy_start]
            if edit_start >= 0 and privacy_start > edit_start
            else ""
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
        visibility_match = re.search(
            r"enum\s+CopyTradeVisibility\s*\{(?P<body>.*?)\s*;",
            models_code,
            re.DOTALL,
        )
        visibility_members = (
            {
                member.strip()
                for member in visibility_match.group("body").split(",")
                if member.strip()
            }
            if visibility_match
            else set()
        )
        if visibility_members != {"private", "followers", "public"}:
            errors.append(
                "CopyTradeVisibility must contain exactly private, followers, "
                "and public"
            )

        wire_getter_match = re.search(
            r"String\s+get\s+wireValue\s*=>\s*switch\s*\(\s*this\s*\)\s*"
            r"\{(?P<body>.*?)\}\s*;",
            models_source,
            re.DOTALL,
        )
        forward_wire_values = (
            {
                member: wire_value
                for member, _, wire_value in re.findall(
                    r"\bCopyTradeVisibility\.(\w+)\s*=>\s*(['\"])([^'\"]*)\2",
                    wire_getter_match.group("body"),
                )
            }
            if wire_getter_match
            else {}
        )
        from_wire_match = re.search(
            r"static\s+CopyTradeVisibility\s+fromWire\s*\(\s*String\s+\w+\s*"
            r"\)\s*=>\s*switch\s*\([^)]*\)\s*\{(?P<body>.*?)\}\s*;",
            models_source,
            re.DOTALL,
        )
        reverse_wire_values = (
            {
                wire_value: member
                for _, wire_value, member in re.findall(
                    r"(['\"])([^'\"]*)\1\s*=>\s*CopyTradeVisibility\.(\w+)\b",
                    from_wire_match.group("body"),
                )
            }
            if from_wire_match
            else {}
        )
        expected_reverse_wire_values = {
            wire_value: member
            for member, wire_value in PRIVACY_VISIBILITY_WIRE_VALUES.items()
        }
        if (
            forward_wire_values != PRIVACY_VISIBILITY_WIRE_VALUES
            or reverse_wire_values != expected_reverse_wire_values
        ):
            errors.append(
                "CopyTradeVisibility wire values must map exactly to private, "
                "followers, and public in both directions"
            )

        actual_values_fields = dart_class_fields(models_code, "PrivacyValues")
        expected_values_fields = {
            ("final", "bool", "discoverable"),
            ("final", "CopyTradeVisibility", "copyTradeVisibility"),
        }
        if actual_values_fields != expected_values_fields:
            rendered_fields = ", ".join(
                f"{modifiers} {field_type} {name}".strip()
                for modifiers, field_type, name in sorted(
                    actual_values_fields or set()
                )
            ) or "none"
            errors.append(
                "PrivacyValues fields must be exactly final bool discoverable "
                "and final CopyTradeVisibility copyTradeVisibility; found: "
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
    if profile_feature_root.is_dir():
        for path in sorted(profile_feature_root.rglob("*.dart")):
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
    """Keep H9 preferences exact, fail-closed, and delivery-neutral."""

    errors: list[str] = []
    gateway_path = root / NOTIFICATION_PREFERENCES_GATEWAY_PATH
    if gateway_path.is_file():
        gateway = strip_dart_comments(read_text(gateway_path))
        default_pattern = re.compile(
            r"final\s+notificationPreferencesGatewayProvider\s*=\s*"
            r"Provider<NotificationPreferencesGateway>\s*"
            r"\(\s*\(\s*ref\s*\)\s*=>\s*const\s+"
            r"UnavailableNotificationPreferencesGateway\s*"
            r"\(\s*\)\s*,?\s*\)\s*;",
            re.DOTALL,
        )
        if default_pattern.search(gateway) is None:
            errors.append(
                "Notification Preferences production provider must default "
                "directly to const UnavailableNotificationPreferencesGateway()"
            )

    models_path = root / NOTIFICATION_PREFERENCES_MODELS_PATH
    if models_path.is_file():
        models_source = strip_dart_comments(read_text(models_path))
        models_code = strip_dart_comments_and_strings(models_source)

        event_members = dart_enum_members(
            models_code, "NotificationPreferenceEvent"
        )
        expected_event_members = set(NOTIFICATION_PREFERENCE_EVENT_WIRE_VALUES)
        if event_members != expected_event_members:
            errors.append(
                "NotificationPreferenceEvent must contain exactly "
                "priceAlertTriggered, providerActivityProjected, "
                "securityNotice, and supportUpdate"
            )
        event_forward, event_reverse, event_rejects_unknown = (
            dart_enum_wire_mappings(models_source, "NotificationPreferenceEvent")
        )
        expected_event_reverse = {
            wire_value: member
            for member, wire_value in NOTIFICATION_PREFERENCE_EVENT_WIRE_VALUES.items()
        }
        if (
            event_forward != NOTIFICATION_PREFERENCE_EVENT_WIRE_VALUES
            or event_reverse != expected_event_reverse
            or not event_rejects_unknown
        ):
            errors.append(
                "NotificationPreferenceEvent wire values must map exactly in "
                "both directions and reject unknown values"
            )

        delivery_members = dart_enum_members(
            models_code, "NotificationDeliveryState"
        )
        if delivery_members != set(NOTIFICATION_DELIVERY_STATE_WIRE_VALUES):
            errors.append(
                "NotificationDeliveryState must contain only unavailable"
            )
        delivery_forward, delivery_reverse, delivery_rejects_unknown = (
            dart_enum_wire_mappings(models_source, "NotificationDeliveryState")
        )
        expected_delivery_reverse = {
            wire_value: member
            for member, wire_value in NOTIFICATION_DELIVERY_STATE_WIRE_VALUES.items()
        }
        if (
            delivery_forward != NOTIFICATION_DELIVERY_STATE_WIRE_VALUES
            or delivery_reverse != expected_delivery_reverse
            or not delivery_rejects_unknown
        ):
            errors.append(
                "NotificationDeliveryState wire values must map only "
                "unavailable in both directions and reject unknown values"
            )

        actual_values_fields = dart_class_fields(
            models_code, "NotificationPreferenceValues"
        )
        expected_values_fields = {
            ("final", "bool", member)
            for member in NOTIFICATION_PREFERENCE_EVENT_WIRE_VALUES
        }
        if actual_values_fields != expected_values_fields:
            rendered_fields = ", ".join(
                f"{modifiers} {field_type} {name}".strip()
                for modifiers, field_type, name in sorted(
                    actual_values_fields or set()
                )
            ) or "none"
            errors.append(
                "NotificationPreferenceValues fields must be exactly four "
                "final bool fields matching the fixed events; found: "
                + rendered_fields
            )

        actual_resource_fields = dart_class_fields(
            models_code, "NotificationPreferencesResource"
        )
        expected_resource_fields = {
            ("final", "int", "version"),
            ("final", "NotificationPreferenceValues", "values"),
            ("final", "NotificationDeliveryState", "delivery"),
        }
        if actual_resource_fields != expected_resource_fields:
            rendered_fields = ", ".join(
                f"{modifiers} {field_type} {name}".strip()
                for modifiers, field_type, name in sorted(
                    actual_resource_fields or set()
                )
            ) or "none"
            errors.append(
                "NotificationPreferencesResource fields must be exactly final "
                "int version, final NotificationPreferenceValues values, and "
                "final NotificationDeliveryState delivery; found: "
                + rendered_fields
            )

    surface_path = root / NOTIFICATION_PREFERENCES_SURFACE_PATH
    if surface_path.is_file():
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
        if contains_positive_notification_preferences_language(surface):
            errors.append(
                "Notification Preferences contains positive save or delivery "
                "language; a stored intent never proves provider delivery"
            )

    feature_root = (
        root / "lib" / "features" / "profile" / "notification_preferences"
    )
    if feature_root.is_dir():
        for path in sorted(feature_root.rglob("*.dart")):
            if contains_positive_notification_preferences_language(
                read_text(path)
            ):
                errors.append(
                    f"{path.relative_to(root)} contains positive save or "
                    "delivery language; a stored intent never proves "
                    "provider delivery"
                )

    preview_root = root / NOTIFICATION_PREFERENCES_PREVIEW_ROOT_PATH
    if preview_root.is_file():
        preview_code = strip_dart_comments_and_strings(read_text(preview_root))
        if (
            len(
                NOTIFICATION_PREFERENCES_MEMORY_CONSTRUCTION_PATTERN.findall(
                    preview_code
                )
            )
            != 1
        ):
            errors.append(
                "lib/main_preview.dart must compose exactly one explicit "
                "MemoryNotificationPreferencesGateway"
            )

    lib_root = root / "lib"
    if lib_root.is_dir():
        allowed = frozenset({
            NOTIFICATION_PREFERENCES_MEMORY_GATEWAY_PATH,
            NOTIFICATION_PREFERENCES_PREVIEW_ROOT_PATH,
        })
        for path in sorted(lib_root.rglob("*.dart")):
            relative = path.relative_to(root)
            if relative in allowed:
                continue
            executable_code = strip_dart_comments_and_strings(read_text(path))
            if NOTIFICATION_PREFERENCES_MEMORY_REFERENCE_PATTERN.search(
                executable_code
            ):
                errors.append(
                    f"{relative} references MemoryNotificationPreferencesGateway; "
                    "the fake may only be defined by its integration and "
                    "composed once by lib/main_preview.dart"
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


def validate(root: Path = ROOT) -> list[str]:
    errors = check_required_files(root)
    profile, profile_errors = load_profile(root)
    errors.extend(profile_errors)
    if profile:
        errors.extend(check_profile(root, profile))
    errors.extend(check_dependency_pins(root))
    errors.extend(check_spot_only_product_contract(root))
    errors.extend(check_native_matrix(root))
    errors.extend(check_android_release_network_contract(root))
    errors.extend(check_audio_room_native_contract(root))
    errors.extend(check_product_contract(root))
    errors.extend(check_chat_attachment_contract(root))
    errors.extend(check_notification_contract(root))
    errors.extend(check_providerless_application_contract(root))
    errors.extend(check_watchlist_application_contract(root))
    errors.extend(check_profile_application_contract(root))
    errors.extend(check_privacy_application_contract(root))
    errors.extend(check_notification_preferences_application_contract(root))
    errors.extend(check_perp_positions_application_contract(root))
    errors.extend(check_source_guards(root))
    errors.extend(check_records(root))
    visible, visible_error = git_visible_paths(root)
    if visible_error:
        errors.append(f"unable to inspect Git-visible paths: {visible_error}")
    else:
        errors.extend(check_secret_paths(visible))
    errors.extend(check_gitignore(root))
    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("Harness check failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(
        "Harness check passed: profile, six-destination contract, pins, "
        "Spot-only product boundary, Debug-only routine verification, records, "
        "and secret rules are consistent."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
