import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';

/// The switch values from before decision 0112: community rooms show the
/// issued persona and small groups the group Alias.
const LoopFeatureSwitchValues legacyChatIdentitySwitches =
    LoopFeatureSwitchValues(
      groupAliasVisible: true,
      communityChatRealIdentity: false,
    );

/// Pumps [widget] under the pre-0112 chat identity, for the tests that pin
/// the channel-scoped naming rules which still hold when the switches are
/// turned back.
Future<void> pumpWithLegacyChatIdentity(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          loopFeatureSwitchesProvider.overrideWithValue(
            legacyChatIdentitySwitches,
          ),
        ],
        child: widget,
      ),
    );
