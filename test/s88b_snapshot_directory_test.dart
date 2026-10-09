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

  test(
    'a slow locator inside its own bound still opens the file store',
    () async {
      final support = Directory.systemTemp.createTempSync('loop-s88b-slow-');
      addTearDown(() => support.deleteSync(recursive: true));
      final store = await FileLoopSnapshotStore.openPersistent(
        // Slower than the per-step bound, faster than the locate bound: the
        // platform channel answers late on a loaded cold start (S123f).
        locate: () => Future<Directory>.delayed(
          const Duration(milliseconds: 60),
          () => support,
        ),
        timeout: const Duration(milliseconds: 20),
        locateTimeout: const Duration(milliseconds: 500),
      );
      expect(store, isA<FileLoopSnapshotStore>());
    },
  );
}
