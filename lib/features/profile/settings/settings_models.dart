import 'package:flutter/foundation.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// `GET/PUT /v2/settings` (decision 0037).
///
/// Both account values are fixed constants in this step and are read-only in
/// the UI. `reduceMotion` and `theme` are named by [LoopAccountSettingsPolicy]
/// as device-local; sending either is a `400`.
@immutable
final class LoopAccountSettingsValues {
  const LoopAccountSettingsValues({
    required this.displayCurrency,
    required this.language,
  });

  static const fixedDisplayCurrency = 'USD';
  static const fixedLanguage = 'zh-CN';

  final String displayCurrency;
  final String language;

  /// Human label for the account's language value: the language's own name
  /// (decision 0281). The app language itself is device-local
  /// (`loopLocaleProvider`), not this value.
  String get languageLabel => language == fixedLanguage
      ? LoopL10n.nativeName(LoopL10n.simplifiedChinese)
      : language;
}

@immutable
final class LoopAccountSettingsPolicy {
  LoopAccountSettingsPolicy({
    required this.configVersion,
    required this.fixed,
    required List<String> localOnly,
  }) : localOnly = List<String>.unmodifiable(localOnly);

  final String configVersion;
  final LoopAccountSettingsValues fixed;

  /// `reduceMotion`, `theme`. The server rejects both.
  final List<String> localOnly;
}

@immutable
final class LoopAccountSettings {
  const LoopAccountSettings({
    required this.values,
    required this.version,
    required this.updatedAt,
    required this.policy,
  });

  final LoopAccountSettingsValues values;

  /// `0` means no row was ever written; the read did not create one.
  final int version;
  final DateTime? updatedAt;
  final LoopAccountSettingsPolicy policy;
}
