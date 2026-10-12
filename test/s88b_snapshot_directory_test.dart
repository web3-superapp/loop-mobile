import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';

/// S88b: the production store lives in the application-support directory and
/// never depends on `TMPDIR`; a directory it cannot use leaves it in memory.
void main() {
  LoopSnapshotRecord record(String account) => LoopSnapshotRecord(
    accountKey: account,
    resource: LoopSnapshotResource.marketOverview,
    body: <String, Object?>{'rows': 3, 'label': 'ok'},
    observedAt: DateTime.utc(2026, 9, 27, 8),
  );

  test('a written snapshot survives a new instance in the located '
      'directory', () async {
    final directory = await Directory.systemTemp.createTemp('s88b-store');
    addTearDown(() => directory.delete(recursive: true));
    final support = Directory(
      '${directory.path}${Platform.pathSeparator}support',
    );

    final first = await FileLoopSnapshotStore.openPersistent(
      locate: () async => support,
    );
    expect(first, isA<FileLoopSnapshotStore>());
    first.bind('acct');
    first.write(record('acct'));
    await (first as FileLoopSnapshotStore).changed();

    final file = File(
      '${support.path}${Platform.pathSeparator}${FileLoopSnapshotStore.fileName}',
    );
    expect(file.existsSync(), isTrue);
    // The writability probe leaves nothing behind.
    expect(
      support.listSync().map((entry) => entry.uri.pathSegments.last),
      <String>[FileLoopSnapshotStore.fileName],
    );

    final second = await FileLoopSnapshotStore.openPersistent(
      locate: () async => support,
    );
    final restored = second.read('acct', LoopSnapshotResource.marketOverview);
    expect(restored, isNotNull);
    expect(restored!.body, <String, Object?>{'rows': 3, 'label': 'ok'});
    expect(restored.observedAt, DateTime.utc(2026, 9, 27, 8));
  });

  test('a directory that cannot be created falls back to memory', () async {
    final directory = await Directory.systemTemp.createTemp('s88b-bad');
    addTearDown(() => directory.delete(recursive: true));
    // A regular file stands where the directory should be: nothing under it
    // can be created, whichever user runs the test.
    final blocker = File('${directory.path}${Platform.pathSeparator}blocker')
      ..writeAsStringSync('x');
    final unusable = Directory(
      '${blocker.path}${Platform.pathSeparator}support',
    );

    final store = await FileLoopSnapshotStore.openPersistent(
      locate: () async => unusable,
    );
    expect(store, isA<MemoryLoopSnapshotStore>());
    expect(store, isNot(isA<FileLoopSnapshotStore>()));
    // It still serves this run from memory.
    store.bind('acct');
    store.write(record('acct'));
    expect(store.read('acct', LoopSnapshotResource.marketOverview), isNotNull);
  });

  test('a directory that cannot be located falls back to memory', () async {
    final store = await FileLoopSnapshotStore.openPersistent(
      locate: () async => throw const FileSystemException('no support dir'),
    );
    expect(store, isA<MemoryLoopSnapshotStore>());
    expect(store, isNot(isA<FileLoopSnapshotStore>()));
  });

  test('a locator that never answers is bounded and falls back', () async {
    final store = await FileLoopSnapshotStore.openPersistent(
      locate: () => Future<Directory>.delayed(
        const Duration(seconds: 5),
        () => Directory.systemTemp,
      ),
      locateTimeout: const Duration(milliseconds: 20),
    );
    expect(store, isNot(isA<FileLoopSnapshotStore>()));
  });

  // The bounds are measured on the test's clock, not the host's: under
  // `testWidgets` every Timer is fake, and the probe and the read go to an
  // in-memory file that answers at once. A loaded host used to blow the 20 ms
  // step bound on the real disk and drop to memory (2026-10-12).
  testWidgets('a slow locator inside its own bound still opens the file '
      'store', (tester) async {
    LoopSnapshotStore? store;
    Object? failure;
    IOOverrides.runZoned(() {
      FileLoopSnapshotStore.openPersistent(
        // Slower than the per-step bound, faster than the locate bound: the
        // platform channel answers late on a loaded cold start (S123f).
        locate: () => Future<Directory>.delayed(
          const Duration(milliseconds: 60),
          () => Directory('/loop-s88b-slow'),
        ),
        createDirectory: (_) async {},
        timeout: const Duration(milliseconds: 20),
        locateTimeout: const Duration(milliseconds: 500),
      ).then(
        (value) => store = value,
        onError: (Object error) {
          failure = error;
        },
      );
    }, createFile: _InstantFile.new);

    // Past the per-step bound, still waiting on the locator.
    await tester.pump(const Duration(milliseconds: 59));
    expect(store, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(failure, isNull);
    expect(store, isA<FileLoopSnapshotStore>());
  });
}

/// A file that takes the probe and holds no snapshots, answering on the next
/// microtask so only the fake clock decides the bounds.
final class _InstantFile implements File {
  _InstantFile(this.path);

  @override
  final String path;

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async => this;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async => this;

  @override
  Future<bool> exists() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not faked');
}
