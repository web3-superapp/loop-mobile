import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';

/// What 最近访问 keeps of a visited page: its origin and path, never the
/// query or the fragment, which may carry a session or an invitation
/// (S346 · M4). 收藏 keeps the full URL the owner chose to save.
String dappRecentUrl(Uri url) => Uri(
  scheme: url.scheme,
  host: url.host,
  port: url.hasPort ? url.port : null,
  path: url.path,
).toString();

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

/// Everything the browser keeps on this device for one account (decision
/// 0270, S346 · M3): the last 20 pages, the saved pages, and the sites the
/// owner connected, each to one wallet. None of it is an account resource
/// and none of it holds a key, a balance or a signature.
@immutable
final class DappBrowserLocalState {
  DappBrowserLocalState({
    List<DappPageEntry> recents = const <DappPageEntry>[],
    List<DappPageEntry> bookmarks = const <DappPageEntry>[],
    Set<String> connections = const <String>{},
  }) : recents = List<DappPageEntry>.unmodifiable(recents),
       bookmarks = List<DappPageEntry>.unmodifiable(bookmarks),
       connections = Set<String>.unmodifiable(connections);

  static const int maximumRecents = 20;
  static const int maximumBookmarks = 100;
  static const int maximumConnections = 200;

  final List<DappPageEntry> recents;
  final List<DappPageEntry> bookmarks;

  /// `walletId|origin` for every site connected to a wallet.
  final Set<String> connections;

  static String connectionKey(String walletId, String origin) =>
      '$walletId|$origin';

  bool isBookmarked(String url) => bookmarks.any((entry) => entry.url == url);

  bool isConnected(String walletId, String origin) =>
      connections.contains(connectionKey(walletId, origin));

  /// [entry] first, reduced to origin and path, any older visit of the same
  /// page dropped, at most 20.
  DappBrowserLocalState visited(DappPageEntry entry) {
    final kept = DappPageEntry(
      url: dappRecentUrl(entry.uri),
      title: entry.title,
    );
    return DappBrowserLocalState(
      recents: <DappPageEntry>[
        kept,
        ...recents.where((item) => item.url != kept.url),
      ].take(maximumRecents).toList(growable: false),
      bookmarks: bookmarks,
      connections: connections,
    );
  }

  DappBrowserLocalState toggledBookmark(DappPageEntry entry) =>
      DappBrowserLocalState(
        recents: recents,
        bookmarks: isBookmarked(entry.url)
            ? bookmarks.where((item) => item.url != entry.url).toList()
            : <DappPageEntry>[
                entry,
                ...bookmarks,
              ].take(maximumBookmarks).toList(growable: false),
        connections: connections,
      );

  DappBrowserLocalState withConnection(
    String walletId,
    String origin, {
    required bool on,
  }) {
    final key = connectionKey(walletId, origin);
    return DappBrowserLocalState(
      recents: recents,
      bookmarks: bookmarks,
      connections: on
          ? <String>{
              ...connections
                  .where((item) => item != key)
                  .take(maximumConnections - 1),
              key,
            }
          : connections.where((item) => item != key).toSet(),
    );
  }

  DappBrowserLocalState withoutRecents() =>
      DappBrowserLocalState(bookmarks: bookmarks, connections: connections);

  String encode() => jsonEncode(<String, Object?>{
    'v': 2,
    'recents': <Object?>[for (final entry in recents) entry.toJson()],
    'bookmarks': <Object?>[for (final entry in bookmarks) entry.toJson()],
    'connections': connections.toList(growable: false),
  });

  /// A stored value this build cannot read is an empty state, never an error.
  static DappBrowserLocalState decode(String? raw) {
    if (raw == null || raw.isEmpty) return DappBrowserLocalState();
    try {
      final map = jsonDecode(raw);
      if (map is! Map || map['v'] != 2) return DappBrowserLocalState();
      List<DappPageEntry> entries(Object? list, int maximum) => <DappPageEntry>[
        if (list is List)
          for (final item in list.take(maximum)) ?DappPageEntry.tryParse(item),
      ];
      final connections = map['connections'];
      return DappBrowserLocalState(
        recents: <DappPageEntry>[
          for (final entry in entries(map['recents'], maximumRecents))
            DappPageEntry(url: dappRecentUrl(entry.uri), title: entry.title),
        ],
        bookmarks: entries(map['bookmarks'], maximumBookmarks),
        connections: <String>{
          if (connections is List)
            for (final item in connections.take(maximumConnections))
              if (item is String && _connectionPattern.hasMatch(item)) item,
        },
      );
    } on Object {
      return DappBrowserLocalState();
    }
  }

  static final RegExp _connectionPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    r'\|https://[^/\s|]+$',
  );
}

/// Where [DappBrowserLocalState] lives, one partition per account.
/// Production keeps it in SharedPreferences under an opaque per-account key;
/// the default keeps it for this run only. Without an account (`null`)
/// nothing is read or kept.
abstract interface class DappBrowserStore {
  bool get persistent;

  Future<DappBrowserLocalState> read(String? account);

  Future<void> write(String? account, DappBrowserLocalState state);

  /// Sign-out: the account's connected sites and recent pages are dropped;
  /// its saved pages stay in its own partition.
  Future<void> forgetAccount(String account);
}

final class MemoryDappBrowserStore implements DappBrowserStore {
  MemoryDappBrowserStore([Map<String, DappBrowserLocalState>? initial])
    : _states = <String, DappBrowserLocalState>{...?initial};

  final Map<String, DappBrowserLocalState> _states;

  @override
  bool get persistent => false;

  @override
  Future<DappBrowserLocalState> read(String? account) async => account == null
      ? DappBrowserLocalState()
      : _states[account] ?? DappBrowserLocalState();

  @override
  Future<void> write(String? account, DappBrowserLocalState state) async {
    if (account != null) _states[account] = state;
  }

  @override
  Future<void> forgetAccount(String account) async {
    final state = _states[account];
    if (state == null) return;
    _states[account] = DappBrowserLocalState(bookmarks: state.bookmarks);
  }
}

final dappBrowserStoreProvider = Provider<DappBrowserStore>(
  (ref) => MemoryDappBrowserStore(),
);

/// The browser's local state for the signed-in account, read once per
/// account and written through on each change.
final class DappBrowserLocalController
    extends AsyncNotifier<DappBrowserLocalState> {
  String? _account;

  @override
  Future<DappBrowserLocalState> build() {
    final account = ref.watch(loopAccountScopeProvider);
    _account = account;
    return ref.read(dappBrowserStoreProvider).read(account);
  }

  Future<void> _apply(
    DappBrowserLocalState Function(DappBrowserLocalState) change,
  ) async {
    final account = _account;
    final current = state.value ?? await future;
    final next = change(current);
    state = AsyncData<DappBrowserLocalState>(next);
    await ref.read(dappBrowserStoreProvider).write(account, next);
  }

  Future<void> recordVisit(DappPageEntry entry) =>
      _apply((current) => current.visited(entry));

  Future<void> toggleBookmark(DappPageEntry entry) =>
      _apply((current) => current.toggledBookmark(entry));

  Future<void> setConnected(
    String walletId,
    String origin, {
    required bool connected,
  }) => _apply(
    (current) => current.withConnection(walletId, origin, on: connected),
  );

  Future<void> clearRecents() => _apply((current) => current.withoutRecents());
}

final dappBrowserLocalProvider =
    AsyncNotifierProvider<DappBrowserLocalController, DappBrowserLocalState>(
      DappBrowserLocalController.new,
    );

/// Sign-out (S346 · M3): drops the leaving account's connected sites and
/// recent pages. Bounded; sign-out never waits on it for long.
Future<void> dappForgetAccount(DappBrowserStore store, String? account) async {
  if (account == null) return;
  try {
    await store.forgetAccount(account).timeout(const Duration(seconds: 2));
  } on Object {
    // The partition is the account's own; nobody else reads it.
  }
}
