import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The read-only answers a cold start may draw before the network answers
/// (decision 0095).
///
/// Four reads qualify by decision 0095 — the wallet (its directory and the
/// balances of the active wallet), the community index, the market overview
/// and the Launch catalogue. Decision 0132 adds two that never change under
/// the reader: a wallet's receive addresses, and the owner's own face (alias
/// and avatar reference) for the heads that draw it. Nothing a signature, a
/// write or a figure check depends on is ever stored here: the signing exit
/// re-reads what it signs, and the profile editor never opens on the face.
abstract final class LoopSnapshotResource {
  static const String walletDirectory = 'wallet.directory';
  static const String marketOverview = 'market.overview';
  static const String communityHome = 'community.home';
  static const String launchOverview = 'launch.overview';

  /// The owner's alias and avatar reference (decision 0132). Display only.
  static const String ownerFace = 'profile.face';

  static const String _walletBalancesPrefix = 'wallet.balances.';
  static const String _walletReceivePrefix = 'wallet.receive.';

  /// The balances of one wallet, addressed by its opaque id.
  static String walletBalances(String walletId) =>
      '$_walletBalancesPrefix$walletId';

  /// The wallet id a balances resource names, or `null` for any other one.
  static String? walletIdOf(String resource) =>
      resource.startsWith(_walletBalancesPrefix)
      ? resource.substring(_walletBalancesPrefix.length)
      : null;

  /// The receive addresses of one wallet, addressed by its opaque id
  /// (decision 0132).
  static String walletReceive(String walletId) =>
      '$_walletReceivePrefix$walletId';

  /// The wallet id a receive resource names, or `null` for any other one.
  static String? receiveWalletIdOf(String resource) =>
      resource.startsWith(_walletReceivePrefix)
      ? resource.substring(_walletReceivePrefix.length)
      : null;

  static bool isKnown(String resource) =>
      resource == walletDirectory ||
      resource == marketOverview ||
      resource == communityHome ||
      resource == launchOverview ||
      resource == ownerFace ||
      (walletIdOf(resource)?.isNotEmpty ?? false) ||
      (receiveWalletIdOf(resource)?.isNotEmpty ?? false);

  /// Whether [resource] describes something that does not move while the
  /// reader looks away (decision 0132): a wallet's receive addresses and the
  /// owner's own face. Such an answer is drawn however old it is and every
  /// time a page opens without one, because an old copy of it is still true;
  /// the live read behind it replaces it the moment it lands.
  static bool isStable(String resource) =>
      resource == ownerFace ||
      (receiveWalletIdOf(resource)?.isNotEmpty ?? false);
}

/// How long a read is kept, and how old it may be before it is not drawn.
abstract final class LoopSnapshotPolicy {
  /// A snapshot older than this is not drawn on a cold start: the page loads
  /// as a skeleton instead, because an answer that old reads as the present.
  static const Duration maxAge = Duration(minutes: 10);

  /// How long a read controller keeps its last answer in memory after the
  /// last page that showed it went away.
  static const Duration memoryRetention = Duration(minutes: 5);

  /// A page revisited sooner than this after its last answer does not issue
  /// another read. It is short enough that a real return is always a
  /// refresh, and long enough that bouncing between two tabs is not a storm.
  static const Duration revisitFloor = Duration(seconds: 10);

  /// How long a [LoopSnapshotResource.isStable] answer is kept drawable.
  static const Duration stableMaxAge = Duration(days: 30);

  /// The age limit for [resource].
  static Duration maxAgeFor(String resource) =>
      LoopSnapshotResource.isStable(resource) ? stableMaxAge : maxAge;

  /// Storage is bounded: one account, a handful of resources.
  static const int maxEntries = 24;
}

/// One stored answer: the body exactly as LOOP returned it, and the moment
/// this device received it.
///
/// The body is re-decoded through the same strict decoder a live answer goes
/// through, so a snapshot can never carry a shape the live path would refuse.
@immutable
final class LoopSnapshotRecord {
  const LoopSnapshotRecord({
    required this.accountKey,
    required this.resource,
    required this.body,
    required this.observedAt,
  });

  /// A fingerprint of the account this answer belongs to (never the raw id).
  final String accountKey;
  final String resource;

  /// JSON-compatible body: maps, lists, strings, numbers, booleans, null.
  final Object? body;

  /// When this device received the answer (UTC).
  final DateTime observedAt;

  Duration ageAt(DateTime now) => now.toUtc().difference(observedAt.toUtc());

  Map<String, Object?> toJson() => <String, Object?>{
    'account': accountKey,
    'resource': resource,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'body': body,
  };

  static LoopSnapshotRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final account = raw['account'];
    final resource = raw['resource'];
    final observed = raw['observedAt'];
    if (account is! String ||
        account.isEmpty ||
        resource is! String ||
        !LoopSnapshotResource.isKnown(resource) ||
        observed is! String) {
      return null;
    }
    final observedAt = DateTime.tryParse(observed);
    if (observedAt == null) return null;
    return LoopSnapshotRecord(
      accountKey: account,
      resource: resource,
      body: raw['body'],
      observedAt: observedAt.toUtc(),
    );
  }
}

/// The account fingerprint a snapshot is filed under.
///
/// FNV-1a over the UTF-8 bytes: the file names which account an answer
/// belongs to without carrying the account id itself.
String loopSnapshotAccountKey(String principal) {
  // 64-bit arithmetic wraps on the VM, which is what FNV-1a relies on.
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  for (final byte in utf8.encode(principal)) {
    hash ^= byte;
    hash *= prime;
  }
  String half(int value) => value.toRadixString(16).padLeft(8, '0');
  return half((hash >>> 32) & 0xFFFFFFFF) + half(hash & 0xFFFFFFFF);
}

/// Device-local storage for the four cold-start snapshots.
abstract interface class LoopSnapshotStore {
  /// The stored answer for [resource], if it belongs to [accountKey].
  LoopSnapshotRecord? read(String accountKey, String resource);

  /// Stores [record] when it belongs to the bound account; drops it otherwise.
  void write(LoopSnapshotRecord record);

  /// Binds the store to one account. Every answer another account left
  /// behind is removed first.
  void bind(String accountKey);

  /// Removes everything, and unbinds. Sign-out calls this.
  Future<void> clear();
}

/// The in-memory store; the file store builds on it.
class MemoryLoopSnapshotStore implements LoopSnapshotStore {
  MemoryLoopSnapshotStore({Iterable<LoopSnapshotRecord> initial = const []}) {
    for (final record in initial) {
      _entries[record.resource] = record;
    }
  }

  final Map<String, LoopSnapshotRecord> _entries =
      <String, LoopSnapshotRecord>{};
  String? _bound;

  @visibleForTesting
  Iterable<LoopSnapshotRecord> get records => _entries.values;

  String? get boundAccount => _bound;

  @override
  LoopSnapshotRecord? read(String accountKey, String resource) {
    final record = _entries[resource];
    if (record == null || record.accountKey != accountKey) return null;
    return record;
  }

  @override
  void write(LoopSnapshotRecord record) {
    // An answer that arrives after the account changed belongs to nobody
    // who is signed in now.
    if (_bound == null || record.accountKey != _bound) return;
    if (!LoopSnapshotResource.isKnown(record.resource)) return;
    _entries.remove(record.resource);
    _entries[record.resource] = record;
    while (_entries.length > LoopSnapshotPolicy.maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    changed();
  }

  @override
  void bind(String accountKey) {
    if (_bound == accountKey) return;
    _bound = accountKey;
    final before = _entries.length;
    _entries.removeWhere((_, record) => record.accountKey != accountKey);
    if (_entries.length != before) changed();
  }

  @override
  Future<void> clear() {
    _bound = null;
    _entries.clear();
    return changed();
  }

  /// Called after every mutation. The file store persists here.
  @protected
  Future<void> changed() => Future<void>.value();
}

/// The snapshot store backed by one JSON file in the app's private
/// application-support directory (decision 0095, S88b).
///
/// It is a cache, not a record: a read that fails leaves the store empty, and
/// a write that fails leaves the in-memory copy serving this run. Nothing here
/// is ever a reason for a page to show less than it would without it.
final class FileLoopSnapshotStore extends MemoryLoopSnapshotStore {
  FileLoopSnapshotStore._(this._file, {super.initial});

  static const String fileName = 'loop_read_snapshots_v1.json';
  static const int _version = 1;

  final File _file;
  Future<void> _writing = Future<void>.value();

  /// Opens the store for production: the file lives in the application
  /// support directory, which is private to the app, survives a restart on
  /// both iOS and Android and is not purged like a cache directory.
  ///
  /// `Directory.systemTemp` is not used: on Android the process has no
  /// `TMPDIR`, so it resolves to a location the app cannot write, and the
  /// store silently never persisted (S88b).
  ///
  /// A directory that cannot be located, created or written yields the
  /// in-memory store with one debug log line; nothing here ever fails the
  /// launch. [locate] and [createDirectory] are replaced by tests.
  ///
  /// Every step is bounded by [timeout] except creating the directory, which
  /// gets [createTimeout] (decision 0101, S94b): on a first launch it is the
  /// one step that really touches the file system, and it is the step that
  /// decides whether the store persists at all.
  static Future<LoopSnapshotStore> openPersistent({
    Future<Directory> Function() locate = getApplicationSupportDirectory,
    Future<void> Function(Directory directory) createDirectory =
        _createDirectory,
    Duration timeout = const Duration(milliseconds: 400),
    Duration createTimeout = const Duration(milliseconds: 1000),
  }) async {
    try {
      final directory = await locate().timeout(timeout);
      await createDirectory(directory).timeout(createTimeout);
      final probe = File(
        '${directory.path}${Platform.pathSeparator}$fileName.probe',
      );
      // No `flush`: the probe asks whether the directory takes a file, not
      // whether the disk has synced one. An fsync before the first frame
      // measured ~400 ms on the Android emulator — exactly the step bound —
      // so the store silently fell back to memory and no cold start ever
      // opened on a snapshot (decision 0101).
      await probe.writeAsString('').timeout(timeout);
      await probe.delete().timeout(timeout);
      return await open(directory: directory, timeout: timeout);
    } on Object catch (error) {
      debugPrint(
        'LoopSnapshotStore: snapshot directory unavailable, '
        'keeping snapshots in memory only ($error)',
      );
      return MemoryLoopSnapshotStore();
    }
  }

  static Future<void> _createDirectory(Directory directory) =>
      directory.create(recursive: true);

  /// Opens the store in [directory], reading what an earlier run left behind.
  /// Bounded: a slow disk never holds the first frame.
  static Future<FileLoopSnapshotStore> open({
    required Directory directory,
    Duration timeout = const Duration(milliseconds: 400),
  }) async {
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    var initial = const <LoopSnapshotRecord>[];
    try {
      if (await file.exists().timeout(timeout)) {
        final text = await file.readAsString().timeout(timeout);
        initial = _decode(text);
      }
    } on Object catch (error) {
      debugPrint('LoopSnapshotStore: stored snapshots unreadable ($error)');
      initial = const <LoopSnapshotRecord>[];
    }
    return FileLoopSnapshotStore._(file, initial: initial);
  }

  static List<LoopSnapshotRecord> _decode(String text) {
    final root = jsonDecode(text);
    if (root is! Map || root['version'] != _version) {
      return const <LoopSnapshotRecord>[];
    }
    final entries = root['entries'];
    if (entries is! List) return const <LoopSnapshotRecord>[];
    return <LoopSnapshotRecord>[
      for (final raw in entries.take(LoopSnapshotPolicy.maxEntries))
        ?LoopSnapshotRecord.fromJson(raw),
    ];
  }

  @override
  Future<void> changed() {
    final snapshot = <Object?>[for (final record in records) record.toJson()];
    final empty = snapshot.isEmpty;
    _writing = _writing.then((_) async {
      try {
        if (empty) {
          if (await _file.exists()) await _file.delete();
          return;
        }
        final staging = File('${_file.path}.tmp');
        await staging.writeAsString(
          jsonEncode(<String, Object?>{
            'version': _version,
            'entries': snapshot,
          }),
          flush: true,
        );
        await staging.rename(_file.path);
      } on Object {
        // A cache that cannot be written is a cache that is not there next
        // time; this run keeps serving from memory.
      }
    });
    return _writing;
  }
}

/// One snapshot decoded back into the value its read controller holds.
@immutable
final class LoopRestoredSnapshot {
  const LoopRestoredSnapshot({required this.value, required this.observedAt});

  final Object value;

  /// When this device received the answer the value was decoded from.
  final DateTime observedAt;
}

/// Turns a stored answer back into a value, through the live decoder.
///
/// Returns `null` for anything missing, anything older than
/// [LoopSnapshotPolicy.maxAge], anything filed under another account and
/// anything the decoder refuses.
abstract interface class LoopSnapshotRestorer {
  LoopRestoredSnapshot? restore(String resource);
}

/// The store. `null` — the default, and every Preview and test build — means
/// nothing is persisted and a cold start always loads as a skeleton.
final loopSnapshotStoreProvider = Provider<LoopSnapshotStore?>((ref) => null);

/// The account the read controllers are serving. When it changes every
/// retained read is dropped, so one account never sees another's answers.
final loopAccountScopeProvider = Provider<String?>((ref) => null);

/// The cold-start decoder. `null` means no snapshot is ever drawn.
final loopSnapshotRestorerProvider = Provider<LoopSnapshotRestorer?>(
  (ref) => null,
);

/// The clock the read retention measures ages against. Tests replace it.
final loopReadClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
