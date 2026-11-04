import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/app/loop_locale.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadString = Future<String?> Function(String key);
typedef _WriteString = Future<void> Function(String key, String value);

/// Device-local storage for the application language only (decision 0281).
///
/// One key, one language tag; never an account resource.
class SharedPreferencesLoopLocaleStore implements LoopLocaleStore {
  factory SharedPreferencesLoopLocaleStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesLoopLocaleStore.forTesting(
      preferences.getString,
      preferences.setString,
    );
  }

  @visibleForTesting
  const SharedPreferencesLoopLocaleStore.forTesting(
    this._readString,
    this._writeString,
  );

  static const String localeKey = 'loop.locale';

  final _ReadString _readString;
  final _WriteString _writeString;

  @override
  Future<String?> readLocaleTag() => _readString(localeKey);

  @override
  Future<void> writeLocaleTag(String tag) => _writeString(localeKey, tag);
}

/// Opens the store and reads the stored language before the first frame.
Future<LoopLocaleBootstrap> bootstrapSharedPreferencesLocale({
  Duration timeout = loopLocaleIoTimeout,
}) => bootstrapSharedPreferencesLocaleForTesting(
  SharedPreferencesLoopLocaleStore.new,
  timeout: timeout,
);

@visibleForTesting
Future<LoopLocaleBootstrap> bootstrapSharedPreferencesLocaleForTesting(
  LoopLocaleStore Function() createStore, {
  Duration timeout = loopLocaleIoTimeout,
}) async {
  try {
    final store = createStore();
    return (
      initial: await loadLoopLocale(store, timeout: timeout),
      store: store,
    );
  } on Object {
    return (
      initial: LoopL10n.fallbackLocale,
      store: const UnavailableLoopLocaleStore(),
    );
  }
}
