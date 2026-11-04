/// The open-source components **this app** ships, and the Chinese name of each
/// rule snapshot the server publishes.
///
/// 关于 used to print the server's own register: the card title was the
/// repository path `docs/open-source-attribution.md`, the body was an English
/// paragraph about `pnpm-lock.yaml`, and the rows were Fastify and
/// `@privy-io/node` — the backend's dependencies, which no reader of a phone
/// screen has any relationship with. The same page printed the raw rule keys
/// `productPolicy` / `clientPolicy` / `bscWriteCanary` as titles.
///
/// So the register rendered here is the client's own, maintained beside
/// `docs/open-source-attribution.md` in this repository and matching the direct
/// dependencies pinned in `pubspec.yaml` / `pubspec.lock`; and the rule list is
/// translated through [loopAboutModuleName], whose table is
/// `loop-api/docs/frontend-v2-meta-api.md` (decision 0049).
library;

import 'package:loop_mobile/features/profile/about/about_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// Direct dependencies of this Flutter client. Versions are deliberately absent
/// — the build's lockfile is the only exact record, and a version printed here
/// could disagree with the binary the reader is holding.
List<LoopOpenSourceEntry> get loopClientOpenSourceEntries =>
    <LoopOpenSourceEntry>[
      LoopOpenSourceEntry(
        name: 'Flutter / Dart',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose,
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'dio',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose2,
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'decimal',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose3,
        license: 'Apache-2.0',
      ),
      LoopOpenSourceEntry(
        name: 'flutter_riverpod',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose4,
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'go_router',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose5,
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'privy_flutter',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose6,
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'reown_appkit',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose7,
        license: 'Reown Community License',
      ),
      LoopOpenSourceEntry(
        name: 'stream_chat_flutter',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose8,
        license: 'Stream Source Code License',
      ),
      LoopOpenSourceEntry(
        name: 'stream_chat_persistence',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose9,
        license: 'Stream Source Code License',
      ),
      LoopOpenSourceEntry(
        name: 'stream_video_flutter',
        purpose: LoopL10n.current.common_voiceRooms,
        license: 'Stream Source Code License',
      ),
      LoopOpenSourceEntry(
        name: 'firebase_core / firebase_messaging',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose10,
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'flutter_secure_storage',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose11,
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'shared_preferences',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose12,
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'connectivity_plus',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose13,
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'flutter_svg',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose14,
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'share_plus',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose15,
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'url_launcher',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose16,
        license: 'BSD-3-Clause',
      ),
      LoopOpenSourceEntry(
        name: 'uuid',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose17,
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'cupertino_icons',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose18,
        license: 'MIT',
      ),
      LoopOpenSourceEntry(
        name: 'IBM Plex Mono / Noto Sans SC',
        purpose: LoopL10n.current.profileAbout_clientRegisterPurpose19,
        license: 'SIL OFL 1.1',
      ),
    ];

/// The name under which a rule the client has never heard of is listed.
///
/// The published key is a module identifier, not a name, and the number of
/// rows is the server's to decide (decision 0049): a key this client cannot
/// translate is still a rule that is in force, so the row stays and carries
/// everything except the identifier.
String get loopAboutUnknownModuleName =>
    LoopL10n.current.profileAbout_clientRegisterLoopAboutUnknownModuleName;

/// The user-facing name of one published rule snapshot, or `null` when this
/// client has no name for the key.
///
/// The table is the one in `loop-api/docs/frontend-v2-meta-api.md`. An unknown
/// key returns `null` rather than falling back to itself: printing an internal
/// identifier is the defect this function exists to close.
String? loopAboutModuleName(String module) => switch (module) {
  'productPolicy' => LoopL10n.current.profileAbout_clientRegisterSwitch,
  'clientPolicy' => LoopL10n.current.profileAbout_clientRegisterSwitch2,
  'sessionPolicy' => LoopL10n.current.profileAbout_clientRegisterSwitch3,
  'community' => LoopL10n.current.profileAbout_clientRegisterSwitch4,
  'marketTrending' => LoopL10n.current.profileAbout_clientRegisterSwitch5,
  'deviceRisk' => LoopL10n.current.profileAbout_clientRegisterSwitch6,
  'accountSettings' => LoopL10n.current.profileAbout_clientRegisterSwitch7,
  'support' => LoopL10n.current.profileAbout_clientRegisterSwitch8,
  'swapPolicy' => LoopL10n.current.profileAbout_clientRegisterSwitch9,
  'bscWriteCanary' => LoopL10n.current.profileAbout_clientRegisterSwitch10,
  _ => null,
};

/// What each named rule decides, in one line.
String? loopAboutModuleDescription(String module) => switch (module) {
  'productPolicy' => LoopL10n.current.profileAbout_clientRegisterSwitch11,
  'clientPolicy' => LoopL10n.current.profileAbout_clientRegisterSwitch12,
  'sessionPolicy' => LoopL10n.current.profileAbout_clientRegisterSwitch13,
  'community' => LoopL10n.current.profileAbout_clientRegisterSwitch14,
  'marketTrending' => LoopL10n.current.profileAbout_clientRegisterSwitch15,
  'deviceRisk' => LoopL10n.current.profileAbout_clientRegisterSwitch16,
  'accountSettings' => LoopL10n.current.profileAbout_clientRegisterSwitch17,
  'support' => LoopL10n.current.profileAbout_clientRegisterSwitch18,
  'swapPolicy' => LoopL10n.current.profileAbout_clientRegisterSwitch19,
  'bscWriteCanary' => LoopL10n.current.profileAbout_clientRegisterSwitch20,
  _ => null,
};
