import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// How long a locale read or write may take before the app goes on without
/// it (the same bound the display preferences use).
const loopLocaleIoTimeout = Duration(seconds: 1);

/// Where this installation keeps the language the reader picked
/// (decision 0281). One device-local value; never an account resource.
abstract interface class LoopLocaleStore {
  /// The stored tag (`en`, `zh-CN`), or null when nothing was picked yet.
  Future<String?> readLocaleTag();

  Future<void> writeLocaleTag(String tag);
}

/// The store a build without device storage gets: nothing is remembered,
/// and the app stays in English.
class UnavailableLoopLocaleStore implements LoopLocaleStore {
  const UnavailableLoopLocaleStore();

  @override
  Future<String?> readLocaleTag() =>
      Future<String?>.error(UnsupportedError('local_locale_unavailable'));

  @override
  Future<void> writeLocaleTag(String tag) =>
      Future<void>.error(UnsupportedError('local_locale_unavailable'));
}

typedef LoopLocaleBootstrap = ({Locale initial, LoopLocaleStore store});

final loopLocaleStoreProvider = Provider<LoopLocaleStore>(
  (ref) => const UnavailableLoopLocaleStore(),
);

/// The language the app opens in: what an earlier run stored, read before
/// the first frame so a Chinese reader never sees an English flash.
final loopLocaleInitialProvider = Provider<Locale>(
  (ref) => LoopL10n.fallbackLocale,
);

/// Reads the stored language, bounded; anything unreadable or unknown is
/// English.
Future<Locale> loadLoopLocale(
  LoopLocaleStore store, {
  Duration timeout = loopLocaleIoTimeout,
}) async {
  try {
    final tag = await store.readLocaleTag().timeout(timeout);
    return LoopL10n.fromTag(tag) ?? LoopL10n.fallbackLocale;
  } on Object {
    return LoopL10n.fallbackLocale;
  }
}

/// The application language (decision 0281): English unless the reader
/// picked 简体中文 in 设置 · Language. A pick takes effect at once and is kept
/// on the device under `loop.locale`.
class LoopLocaleController extends Notifier<Locale> {
  late LoopLocaleStore _store;

  @override
  Locale build() {
    _store = ref.watch(loopLocaleStoreProvider);
    final initial = LoopL10n.resolve(ref.watch(loopLocaleInitialProvider));
    LoopL10n.use(initial);
    return initial;
  }

  /// Switches the app to [locale] now and remembers it. A failed write keeps
  /// the switch for this run.
  Future<void> setLocale(Locale locale) async {
    final resolved = LoopL10n.resolve(locale);
    if (resolved == state) return;
    LoopL10n.use(resolved);
    state = resolved;
    try {
      await _store
          .writeLocaleTag(LoopL10n.tagOf(resolved))
          .timeout(loopLocaleIoTimeout);
    } on Object {
      // The language still applies for this run.
    }
  }
}

final loopLocaleProvider = NotifierProvider<LoopLocaleController, Locale>(
  LoopLocaleController.new,
);
