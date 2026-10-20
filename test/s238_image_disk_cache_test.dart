// S238-mobile · decision 0215: the image disk cache, the loader in front of
// it, the prefetch, and the bundled first-frame logos.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/cache/loop_image_disk_cache.dart';
import 'package:loop_mobile/core/crypto/loop_sha256.dart';
import 'package:loop_mobile/integrations/media/loop_image_fetch.dart';
import 'package:loop_mobile/integrations/media/loop_image_loader.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_media_image.dart';

Uint8List _bytes(int length, [int fill = 7]) =>
    Uint8List.fromList(List<int>.filled(length, fill));

final class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('loop-s238-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('SHA-256', () {
    test('matches the FIPS 180-4 vectors', () {
      expect(
        loopSha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        loopSha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        loopSha256Hex(
          'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('a file name carries no address', () {
      const url = 'https://api.example/v2/market/logos/eip155:56/native.png';
      final key = LoopImageDiskCache.keyFor(url);
      expect(key, hasLength(64));
      expect(key, isNot(contains('native')));
    });
  });

  group('Cache-Control', () {
    test('max-age, no-cache and no-store are honoured', () {
      expect(
        loopParseCacheControl('public, max-age=86400').maxAge,
        const Duration(days: 1),
      );
      expect(
        loopParseCacheControl('public, max-age=31536000, immutable').maxAge,
        const Duration(days: 365),
      );
      expect(loopParseCacheControl(null).maxAge, isNull);
      expect(loopParseCacheControl('s-maxage=60').maxAge, isNull);
      expect(
        loopParseCacheControl('max-age=600, no-cache').maxAge,
        Duration.zero,
      );
      expect(loopParseCacheControl('no-store').noStore, isTrue);
    });
  });

  group('LoopImageDiskCache', () {
    test('a miss is null, a write is a hit with its lifetime', () async {
      final clock = _Clock(DateTime.utc(2026, 10, 20));
      final cache = LoopImageDiskCache(
        directory: () async => root,
        clock: clock.call,
      );
      expect(await cache.read('https://a.example/1.png'), isNull);

      await cache.write(
        'https://a.example/1.png',
        _bytes(10),
        maxAge: const Duration(hours: 1),
      );
      final hit = await cache.read('https://a.example/1.png');
      expect(hit?.bytes, _bytes(10));
      expect(hit!.isFreshAt(clock.now), isTrue);
      clock.advance(const Duration(hours: 2));
      expect(hit.isFreshAt(clock.now), isFalse);

      final folder = Directory('${root.path}/${LoopImageDiskCache.folder}');
      final names = folder.listSync().map((e) => e.uri.pathSegments.last);
      expect(names.every((name) => !name.contains('a.example')), isTrue);
    });

    test('a copy without a server lifetime never goes stale', () async {
      final cache = LoopImageDiskCache(directory: () async => root);
      await cache.write('https://a.example/m.webp', _bytes(4));
      final hit = await cache.read('https://a.example/m.webp');
      expect(hit!.isFreshAt(DateTime.utc(2100)), isTrue);
    });

    test(
      'the folder is trimmed to its bound, least recently used first',
      () async {
        final clock = _Clock(DateTime.utc(2026, 10, 20));
        final cache = LoopImageDiskCache(
          directory: () async => root,
          clock: clock.call,
          maxBytes: 250,
        );
        await cache.write('https://a.example/1', _bytes(100, 1));
        clock.advance(const Duration(minutes: 1));
        await cache.write('https://a.example/2', _bytes(100, 2));
        clock.advance(const Duration(minutes: 1));
        // Reading 1 makes it the most recently used; 2 is now the oldest.
        expect(await cache.read('https://a.example/1'), isNotNull);
        await pumpEventQueue();
        clock.advance(const Duration(minutes: 1));
        await cache.write('https://a.example/3', _bytes(100, 3));

        expect(await cache.read('https://a.example/2'), isNull);
        expect(
          (await cache.read('https://a.example/1'))?.bytes,
          _bytes(100, 1),
        );
        expect(
          (await cache.read('https://a.example/3'))?.bytes,
          _bytes(100, 3),
        );
        final folder = Directory('${root.path}/${LoopImageDiskCache.folder}');
        final kept = folder
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.img'))
            .fold<int>(0, (sum, file) => sum + file.lengthSync());
        expect(kept, lessThanOrEqualTo(250));
      },
    );

    test('a directory that cannot be found means no copy', () async {
      final cache = LoopImageDiskCache(directory: () async => null);
      await cache.write('https://a.example/1', _bytes(4));
      expect(await cache.read('https://a.example/1'), isNull);
    });
  });

  group('LoopImageLoader', () {
    late _Clock clock;
    late LoopImageDiskCache cache;
    late List<Uri> asked;
    late Future<LoopImageDownload> Function(Uri uri) answer;

    LoopImageLoader loader() => LoopImageLoader(
      cache: cache,
      clock: clock.call,
      download: (uri) {
        asked.add(uri);
        return answer(uri);
      },
    );

    setUp(() {
      clock = _Clock(DateTime.utc(2026, 10, 20));
      cache = LoopImageDiskCache(
        directory: () async => root,
        clock: clock.call,
      );
      asked = <Uri>[];
      answer = (uri) async => LoopImageDownload(
        bytes: _bytes(8, 1),
        maxAge: const Duration(days: 1),
      );
    });

    test(
      'a miss downloads and keeps the copy; a fresh hit does not ask',
      () async {
        final subject = loader();
        const url = 'https://a.example/logo.png';
        final first = await subject.load(url);
        expect(first.bytes, _bytes(8, 1));
        expect(first.refreshed, isNull);
        expect(asked, hasLength(1));

        final second = await subject.load(url);
        expect(second.bytes, _bytes(8, 1));
        expect(second.refreshed, isNull);
        expect(asked, hasLength(1));
        expect((await cache.read(url))?.maxAge, const Duration(days: 1));
      },
    );

    test(
      'a stale copy is drawn at once and refreshed in the background',
      () async {
        final subject = loader();
        const url = 'https://a.example/logo.png';
        await subject.load(url);
        clock.advance(const Duration(days: 2));
        answer = (uri) async => LoopImageDownload(
          bytes: _bytes(8, 2),
          maxAge: const Duration(days: 1),
        );

        final load = await subject.load(url);
        expect(load.bytes, _bytes(8, 1), reason: 'the old picture first');
        expect(await load.refreshed, _bytes(8, 2));
        final kept = await cache.read(url);
        expect(kept?.bytes, _bytes(8, 2));
        expect(kept!.isFreshAt(clock.now), isTrue);
      },
    );

    test('a refresh with the same bytes reports no change', () async {
      final subject = loader();
      const url = 'https://a.example/logo.png';
      await subject.load(url);
      clock.advance(const Duration(days: 2));
      final load = await subject.load(url);
      expect(await load.refreshed, isNull);
    });

    test('the network failing keeps the stale copy', () async {
      final subject = loader();
      const url = 'https://a.example/logo.png';
      await subject.load(url);
      clock.advance(const Duration(days: 2));
      answer = (uri) async =>
          throw const SocketException('Connection timed out');

      final load = await subject.load(url);
      expect(load.bytes, _bytes(8, 1));
      expect(await load.refreshed, isNull);
      expect((await cache.read(url))?.bytes, _bytes(8, 1));
    });

    test('no copy and a failing network is the error', () async {
      final subject = loader();
      answer = (uri) async =>
          throw NetworkImageLoadException(statusCode: 404, uri: uri);
      await expectLater(
        subject.load('https://a.example/none.png'),
        throwsA(isA<NetworkImageLoadException>()),
      );
      expect(await cache.read('https://a.example/none.png'), isNull);
    });

    test('no-store is drawn but not kept', () async {
      final subject = loader();
      answer = (uri) async =>
          LoopImageDownload(bytes: _bytes(8, 3), noStore: true);
      final load = await subject.load('https://a.example/private.png');
      expect(load.bytes, _bytes(8, 3));
      expect(await cache.read('https://a.example/private.png'), isNull);
    });

    test('concurrent loads of one address share one download', () async {
      final subject = loader();
      final gate = Completer<void>();
      answer = (uri) async {
        await gate.future;
        return LoopImageDownload(bytes: _bytes(8, 4));
      };
      final a = subject.fetch('https://a.example/x.png');
      final b = subject.fetch('https://a.example/x.png');
      gate.complete();
      expect(await a, await b);
      expect(asked, hasLength(1));
    });

    test(
      'prefetch asks at most four at a time and only the first rows',
      () async {
        final subject = loader();
        var running = 0;
        var peak = 0;
        answer = (uri) async {
          running++;
          peak = running > peak ? running : peak;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          return LoopImageDownload(bytes: _bytes(4, 5));
        };
        final urls = <String>[
          for (var i = 0; i < 40; i++) 'https://a.example/$i.png',
          'https://a.example/0.png',
        ];
        await subject.prefetch(urls);
        expect(peak, lessThanOrEqualTo(loopImagePrefetchConcurrency));
        expect(peak, greaterThan(1));
        expect(asked, hasLength(loopImagePrefetchLimit));

        // Everything it fetched is fresh now: a second pass asks nothing.
        asked.clear();
        await subject.prefetch(urls);
        expect(asked, isEmpty);
      },
    );

    test('only addresses the client fetches from are prefetched', () {
      expect(loopImageAddressAllowed('https://a.example/x.png'), isTrue);
      expect(loopImageAddressAllowed('http://a.example/x.png'), isFalse);
      expect(loopImageAddressAllowed('http://127.0.0.1/x.png'), isTrue);
      expect(loopImageAddressAllowed('ftp://a.example/x.png'), isFalse);
      expect(loopImageAddressAllowed('not a url'), isFalse);
    });
  });

  group('LoopMediaImage', () {
    Future<Uint8List> png(Color color) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
          .drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = color);
      final image = await recorder.endRecording().toImage(2, 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    }

    testWidgets('a stale copy is drawn, then replaced by the refresh', (
      tester,
    ) async {
      final clock = _Clock(DateTime.utc(2026, 10, 20));
      final cache = LoopImageDiskCache(
        directory: () async => root,
        clock: clock.call,
      );
      final oldPng = (await tester.runAsync(
        () => png(const Color(0xFFB8FF20)),
      ))!;
      final newPng = (await tester.runAsync(
        () => png(const Color(0xFF050604)),
      ))!;
      final refresh = Completer<LoopImageDownload>();
      final previous = LoopImageLoader.instance;
      LoopImageLoader.instance = LoopImageLoader(
        cache: cache,
        clock: clock.call,
        download: (uri) => refresh.future,
      );
      addTearDown(() => LoopImageLoader.instance = previous);
      const url = 'https://a.example/v2/market/logos/eip155:56/native.png';
      await tester.runAsync(
        () => cache.write(url, oldPng, maxAge: const Duration(hours: 1)),
      );
      clock.advance(const Duration(hours: 2));

      final frames = <ImageInfo>[];
      final listener = ImageStreamListener((info, _) => frames.add(info));
      final stream = (await tester.runAsync(() async {
        final stream = const LoopMediaImage(url)
            .resolve(ImageConfiguration.empty);
        stream.addListener(listener);
        return stream;
      }))!;
      addTearDown(() => stream.removeListener(listener));

      await tester.runAsync(() async {
        for (var i = 0; i < 50 && frames.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(frames, hasLength(1), reason: 'the stale copy, at once');

      refresh.complete(
        LoopImageDownload(bytes: newPng, maxAge: const Duration(days: 1)),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && frames.length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(frames, hasLength(2), reason: 'the refresh replaces the frame');
      final kept = await tester.runAsync(() => cache.read(url));
      expect(kept?.bytes, newPng);
    });
  });

  group('LoopMediaImage recovery', () {
    testWidgets('a copy that no longer decodes is replaced by a download', (
      tester,
    ) async {
      final cache = LoopImageDiskCache(directory: () async => root);
      final good = (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 3, 3),
          Paint()..color = const Color(0xFFB8FF20),
        );
        final image = await recorder.endRecording().toImage(3, 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      }))!;
      var downloads = 0;
      final previous = LoopImageLoader.instance;
      LoopImageLoader.instance = LoopImageLoader(
        cache: cache,
        download: (uri) async {
          downloads++;
          return LoopImageDownload(bytes: good);
        },
      );
      addTearDown(() => LoopImageLoader.instance = previous);
      const url = 'https://a.example/v2/media/corrupt.webp';
      await tester.runAsync(
        () => cache.write(url, _bytes(32, 9), maxAge: const Duration(days: 9)),
      );

      final frames = <ImageInfo>[];
      final listener = ImageStreamListener((info, _) => frames.add(info));
      final stream = (await tester.runAsync(() async {
        final stream = const LoopMediaImage(url)
            .resolve(ImageConfiguration.empty);
        stream.addListener(listener);
        return stream;
      }))!;
      addTearDown(() => stream.removeListener(listener));
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && frames.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(frames, hasLength(1));
      expect(frames.single.image.width, 3);
      expect(downloads, 1);
      expect((await tester.runAsync(() => cache.read(url)))?.bytes, good);
    });
  });

  group('bundled first-frame logos', () {
    test('every bundled drawing exists', () {
      for (final file in LoopTokenAssets.byAddress.values) {
        expect(
          File(LoopAssetPaths.token(file)).existsSync(),
          isTrue,
          reason: file,
        );
      }
      for (final file in LoopNetworkAssets.byId.values) {
        expect(File(LoopAssetPaths.network(file)).existsSync(), isTrue);
      }
    });

    test('the logo proxy address picks the drawing, not the symbol', () {
      expect(
        LoopTokenAssets.pathForLogoUrl(
          'https://api.example/v2/market/logos/eip155:56/native.png',
        ),
        'assets/tokens/bnb.svg',
      );
      expect(
        LoopTokenAssets.pathForLogoUrl(
          'https://api.example/v2/market/logos/eip155%3A56/'
          '0x55D398326F99059FF775485246999027B3197955.webp',
        ),
        'assets/tokens/usdt.svg',
      );
      // A look-alike: right symbol, unknown address.
      expect(
        LoopTokenAssets.pathForLogoUrl(
          'https://api.example/v2/market/logos/eip155:56/'
          '0x0000000000000000000000000000000000000001.png',
        ),
        isNull,
      );
      expect(LoopTokenAssets.pathForLogoUrl(null), isNull);
      expect(
        LoopTokenAssets.pathForLogoUrl('https://cdn.example/eth.png'),
        isNull,
      );
    });

    test('networks are found by CAIP-2 id', () {
      expect(
        LoopNetworkAssets.pathForId('eip155:56'),
        'assets/networks/bsc.svg',
      );
      expect(
        LoopNetworkAssets.pathForId('eip155:1'),
        'assets/networks/ethereum.svg',
      );
      expect(
        LoopNetworkAssets.pathForId('eip155:8453'),
        'assets/networks/base.svg',
      );
    });

    String? svgAsset(WidgetTester tester) {
      final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
      if (pictures.isEmpty) return null;
      final loader = pictures.first.bytesLoader;
      return loader is SvgAssetLoader ? loader.assetName : null;
    }

    testWidgets('a mainstream token draws its bundled art while loading', (
      tester,
    ) async {
      final never = Completer<ui.Codec>();
      debugLoopTokenLogoImageProvider = (url) => _PendingImage(never.future);
      addTearDown(debugResetLoopTokenLogoFailures);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: LoopTokenLogo(
              assetSymbol: 'ETH',
              logoUrl:
                  'https://api.example/v2/market/logos/eip155:56/'
                  '0x2170ed0880ac9a755fd29b2688956bd959f933f8.png',
            ),
          ),
        ),
      );
      expect(svgAsset(tester), 'assets/tokens/eth.svg');
    });

    testWidgets('a look-alike ticker keeps the monogram', (tester) async {
      final never = Completer<ui.Codec>();
      debugLoopTokenLogoImageProvider = (url) => _PendingImage(never.future);
      addTearDown(debugResetLoopTokenLogoFailures);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: LoopTokenLogo(
              assetSymbol: 'ETH',
              logoUrl:
                  'https://api.example/v2/market/logos/eip155:56/'
                  '0x00000000000000000000000000000000000000e7.png',
            ),
          ),
        ),
      );
      expect(svgAsset(tester), isNull);
      expect(find.text('ET'), findsOneWidget);
    });
  });
}

/// An image that never finishes loading.
final class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage(this.codec);

  final Future<ui.Codec> codec;

  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PendingImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: codec, scale: 1);
}
