import 'package:flutter/widgets.dart';
import 'package:loop_mobile/l10n/gen/loop_localizations.dart';

export 'package:loop_mobile/l10n/gen/loop_localizations.dart';

/// LOOP's copy, in the reader's language (decision 0281).
///
/// Two ways in, one rule between them:
///
/// * `context.l10n.<key>` wherever a [BuildContext] below the app's
///   `Localizations` is in hand — every `build`, every builder callback. It
///   registers the dependency, so a language switch rebuilds the widget.
/// * `LoopL10n.current.<key>` where there is no context: view models,
///   gateway error mapping, notification copy, formatters, `State` fields
///   initialised before the first `build`. It is the same instance the app's
///   `Localizations` resolved, kept in step by [LoopLocaleController] and the
///   app builder; it does not rebuild anything by itself.
///
/// Never cache either value in a `static`/top-level `final`: the language can
/// change while the app runs.
abstract final class LoopL10n {
  static const Locale english = Locale('en');
  static const Locale simplifiedChinese = Locale('zh', 'CN');

  /// The default and the template language: the app opens in English
  /// whatever the device is set to.
  static const Locale fallbackLocale = english;

  /// The languages the app offers, in the order the picker lists them.
  static const List<Locale> supportedLocales = <Locale>[
    english,
    simplifiedChinese,
  ];

  static const LocalizationsDelegate<LoopLocalizations> delegate =
      LoopLocalizations.delegate;

  static LoopLocalizations _current = lookupLoopLocalizations(fallbackLocale);
  static Locale _currentLocale = fallbackLocale;

  /// The copy for the language the app currently shows.
  static LoopLocalizations get current => _current;

  /// The locale [current] answers for.
  static Locale get currentLocale => _currentLocale;

  /// Points [current] at [locale]'s copy. Called by the locale controller
  /// when the reader picks a language and by the app builder whenever the
  /// resolved `Localizations` locale differs; tests call it to run a case in
  /// Chinese (and [debugReset] afterwards).
  static void use(Locale locale) {
    final resolved = resolve(locale);
    if (resolved == _currentLocale) return;
    _currentLocale = resolved;
    _current = lookupLoopLocalizations(resolved);
  }

  /// Back to English, for test tear-down.
  @visibleForTesting
  static void debugReset() => use(fallbackLocale);

  /// The supported locale that answers for [locale]: Chinese for any `zh`
  /// tag, English for everything else.
  static Locale resolve(Locale? locale) =>
      locale?.languageCode == simplifiedChinese.languageCode
      ? simplifiedChinese
      : english;

  /// How a language names itself in the picker. Deliberately not
  /// translated: a reader looking for their language reads its own name.
  static String nativeName(Locale locale) =>
      resolve(locale) == simplifiedChinese ? '简体中文' : 'English';

  /// The stored tag for [locale] (`en`, `zh-CN`).
  static String tagOf(Locale locale) => resolve(locale).toLanguageTag();

  /// The locale a stored tag names, or null when it names none LOOP offers.
  static Locale? fromTag(String? tag) {
    if (tag == null) return null;
    for (final locale in supportedLocales) {
      if (locale.toLanguageTag() == tag) return locale;
    }
    return null;
  }
}

/// `context.l10n` (decision 0281).
extension LoopL10nContext on BuildContext {
  /// The copy for the language this context's `Localizations` resolved.
  ///
  /// Falls back to [LoopL10n.current] when no LOOP delegate is installed
  /// above this context — a test that pumps a bare `MaterialApp`, a route
  /// built before the app's `Localizations` — so a page never throws for want
  /// of a delegate and still prints the app's current language.
  LoopLocalizations get l10n =>
      Localizations.of<LoopLocalizations>(this, LoopLocalizations) ??
      LoopL10n.current;
}
