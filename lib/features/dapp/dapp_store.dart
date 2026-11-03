import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One visited or saved page: its URL and the title it had at the time.
@immutable
final class DappPageEntry {
  const DappPageEntry({required this.url, required this.title});

  /// Canonical `https` URL.
  final String url;

  /// The page title when it was recorded; display text only.
  final String title;

  Uri get uri => Uri.parse(url);

  String get host => uri.host;

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'title': title,
  };

  static DappPageEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url'];
    final title = raw['title'];
    if (url is! String || url.length > 2048) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return DappPageEntry(
      url: url,
      title: title is String && title.length <= 200 ? title : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DappPageEntry && other.url == url && other.title == title;

  @override
  int get hashCode => Object.hash(url, title);
}

/// Everything the browser keeps on this device (decision 0270): the last 20
/// pages, the saved pages, and the origins the owner connected. None of it is
/// an account resource and none of it holds a key, a balance or a signature.
@immutable
final class DappBrowserLocalState {
  DappBrowserLocalState({
    List<DappPageEntry> recents = const <DappPageEntry>[],
    List<DappPageEntry> bookmarks = const <DappPageEntry>[],
    Set<String> connectedOrigins = const <String>{},
  }) : recents = List<DappPageEntry>.unmodifiable(recents),
       bookmarks = List<DappPageEntry>.unmodifiable(bookmarks),
       connectedOrigins = Set<String>.unmodifiable(connectedOrigins);

  static const int maximumRecents = 20;
  static const int maximumBookmarks = 100;
  static const int maximumConnections = 200;

  final List<DappPageEntry> recents;
  final List<DappPageEntry> bookmarks;
  final Set<String> connectedOrigins;

  bool isBookmarked(String url) => bookmarks.any((entry) => entry.url == url);

  bool isConnected(String origin) => connectedOrigins.contains(origin);

  /// [entry] first, any older visit of the same URL dropped, at most 20.
  DappBrowserLocalState visited(DappPageEntry entry) => DappBrowserLocalState(
    recents: <DappPageEntry>[
      entry,
      ...recents.where((item) => item.url != entry.url),
    ].take(maximumRecents).toList(growable: false),
    bookmarks: bookmarks,
    connectedOrigins: connectedOrigins,
  );

  DappBrowserLocalState toggledBookmark(DappPageEntry entry) =>
      DappBrowserLocalState(
        recents: recents,
        bookmarks: isBookmarked(entry.url)
            ? bookmarks.where((item) => item.url != entry.url).toList()
            : <DappPageEntry>[
                entry,
                ...bookmarks,
              ].take(maximumBookmarks).toList(growable: false),
        connectedOrigins: connectedOrigins,
      );

  DappBrowserLocalState withConnection(String origin, {required bool on}) =>
      DappBrowserLocalState(
        recents: recents,
        bookmarks: bookmarks,
        connectedOrigins: on
            ? <String>{...connectedOrigins.take(maximumConnections - 1), origin}
            : connectedOrigins.where((item) => item != origin).toSet(),
      );

  DappBrowserLocalState withoutRecents() => DappBrowserLocalState(
    bookmarks: bookmarks,
    connectedOrigins: connectedOrigins,
  );

  String encode() => jsonEncode(<String, Object?>{
    'v': 1,
    'recents': <Object?>[for (final entry in recents) entry.toJson()],
    'bookmarks': <Object?>[for (final entry in bookmarks) entry.toJson()],
    'connections': connectedOrigins.toList(growable: false),
  });

  /// A stored value this build cannot read is an empty state, never an error.
  static DappBrowserLocalState decode(String? raw) {
    if (raw == null || raw.isEmpty) return DappBrowserLocalState();
    try {
      final map = jsonDecode(raw);
      if (map is! Map || map['v'] != 1) return DappBrowserLocalState();
      List<DappPageEntry> entries(Object? list, int maximum) => <DappPageEntry>[
        if (list is List)
          for (final item in list.take(maximum)) ?DappPageEntry.tryParse(item),
      ];
      final connections = map['connections'];
      return DappBrowserLocalState(
        recents: entries(map['recents'], maximumRecents),
        bookmarks: entries(map['bookmarks'], maximumBookmarks),
        connectedOrigins: <String>{
          if (connections is List)
            for (final item in connections.take(maximumConnections))
              if (item is String && _originPattern.hasMatch(item)) item,
        },
      );
    } on Object {
      return DappBrowserLocalState();
    }
  }

  static final RegExp _originPattern = RegExp(r'^https://[^/\s]+$');
}

/// Where [DappBrowserLocalState] lives. Production keeps it in one
/// SharedPreferences key; the default keeps it for this run only.
abstract interface class DappBrowserStore {
  bool get persistent;

  Future<DappBrowserLocalState> read();

  Future<void> write(DappBrowserLocalState state);
}

final class MemoryDappBrowserStore implements DappBrowserStore {
  MemoryDappBrowserStore([DappBrowserLocalState? initial])
    : _state = initial ?? DappBrowserLocalState();

  DappBrowserLocalState _state;

  @override
  bool get persistent => false;

  @override
  Future<DappBrowserLocalState> read() async => _state;

  @override
  Future<void> write(DappBrowserLocalState state) async => _state = state;
}

final dappBrowserStoreProvider = Provider<DappBrowserStore>(
  (ref) => MemoryDappBrowserStore(),
);

/// The browser's local state, read once and written through on each change.
final class DappBrowserLocalController
    extends AsyncNotifier<DappBrowserLocalState> {
  @override
  Future<DappBrowserLocalState> build() =>
      ref.read(dappBrowserStoreProvider).read();

  Future<void> _apply(
    DappBrowserLocalState Function(DappBrowserLocalState) change,
  ) async {
    final current = state.value ?? await future;
    final next = change(current);
    state = AsyncData<DappBrowserLocalState>(next);
    await ref.read(dappBrowserStoreProvider).write(next);
  }

  Future<void> recordVisit(DappPageEntry entry) =>
      _apply((current) => current.visited(entry));

  Future<void> toggleBookmark(DappPageEntry entry) =>
      _apply((current) => current.toggledBookmark(entry));

  Future<void> setConnected(String origin, {required bool connected}) =>
      _apply((current) => current.withConnection(origin, on: connected));

  Future<void> clearRecents() => _apply((current) => current.withoutRecents());
}

final dappBrowserLocalProvider =
    AsyncNotifierProvider<DappBrowserLocalController, DappBrowserLocalState>(
      DappBrowserLocalController.new,
    );
