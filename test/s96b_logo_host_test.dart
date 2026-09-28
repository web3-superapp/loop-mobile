// S96b · the LOOP image proxy is an accepted logo host (decision 0089).
//
// Since S96 every `logo.url` names this build's own backend:
// `<LOOP_BACKEND_BASE_URL>/v2/market/logos/eip155:56/<address|native>.png`.
// The codec accepts exactly that — same origin as the network layer, the
// proxy path, HTTPS (plain HTTP only for a loopback Development origin) — and
// keeps the three external hosts. The tile decodes the bytes it receives, so
// a `.png` carrying JPEG or WebP draws, and a `404` from the proxy is a
// remembered failure like any other.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

const _address = '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';
const _missing = '0x0000000000000000000000000000000000000001';

Map<String, Object?> _logo(String url, {String source = 'dexscreener'}) =>
    <String, Object?>{
      'status': 'available',
      'url': url,
      'source': source,
      'observedAt': null,
    };

String? _decode(String url) => LoopV2ChainCodec.logoUrl(_logo(url));

/// A 6 x 6 JPEG (converted from the bundled app icon by `sips`).
final List<int> _jpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAA'
  'GgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAABqADAAQAAAABAAAABgAAAAD/7QA4'
  'UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs'
  '+EJ+/8AAEQgABgAGAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYH'
  'CAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNC'
  'scEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVm'
  'Z2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TF'
  'xsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEA'
  'AAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEH'
  'YXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJ'
  'SlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ip'
  'qrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMA'
  'AgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4O'
  'Dg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQ'
  'EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A'
  '/EXWPE/hrUfDGm6JYeHINPv7PYZr5HZpLjahVtyngbidxx6cVxWYf7lQL1p1TyoLn//Z',
);

final class _RealSockets extends HttpOverrides {}

void main() {
  tearDown(() => LoopV2ChainCodec.debugSetLogoOrigin(null));

  group('codec · backend origin', () {
    test('the build backend origin serves the proxy path', () {
      LoopV2ChainCodec.debugSetLogoOrigin('https://api-dev.quant-dinger.cc');
      const base = 'https://api-dev.quant-dinger.cc/v2/market/logos/eip155:56';
      expect(_decode('$base/$_address.png'), '$base/$_address.png');
      expect(_decode('$base/native.png'), '$base/native.png');
      // The same origin written with its default port is the same origin.
      expect(
        _decode(
          'https://api-dev.quant-dinger.cc:443/v2/market/logos/'
          'eip155:56/native.png',
        ),
        isNotNull,
      );
    });

    test('each build accepts its own origin, not another stack', () {
      LoopV2ChainCodec.debugSetLogoOrigin(
        'https://api-staging.quant-dinger.cc/',
      );
      expect(
        _decode(
          'https://api-staging.quant-dinger.cc/v2/market/logos/'
          'eip155:56/native.png',
        ),
        isNotNull,
      );
      // A dev URL inside a staging build is not this build's backend.
      expect(
        _decode(
          'https://api-dev.quant-dinger.cc/v2/market/logos/'
          'eip155:56/native.png',
        ),
        isNull,
      );
    });

    test('same origin, any other path is refused', () {
      LoopV2ChainCodec.debugSetLogoOrigin('https://api-dev.quant-dinger.cc');
      const origin = 'https://api-dev.quant-dinger.cc';
      for (final path in <String>[
        '/v2/market/overview',
        '/v2/profile',
        '/v2/market/logos/',
        '/v1/market/logos/eip155:56/native.png',
        '/v2/market/logos/eip155:97/native.png',
        '/v2/market/logos/eip155:56/native.svg',
        '/v2/market/logos/eip155:56/0xBB4CDB9CBD36B01BD1CBAEBF2DE08D9173BC095C.png',
        '/v2/market/logos/eip155:56/../../profile.png',
        '/v2/market/logos/eip155:56/native.png?size=64',
        '/v2/market/logos/eip155:56/native.png#x',
        '/prefix/v2/market/logos/eip155:56/native.png',
      ]) {
        expect(_decode('$origin$path'), isNull, reason: path);
      }
    });

    test('scheme, port and credentials must match the origin', () {
      LoopV2ChainCodec.debugSetLogoOrigin('https://api-dev.quant-dinger.cc');
      for (final url in <String>[
        'http://api-dev.quant-dinger.cc/v2/market/logos/eip155:56/native.png',
        'https://api-dev.quant-dinger.cc:8443/v2/market/logos/eip155:56/native.png',
        'https://u:p@api-dev.quant-dinger.cc/v2/market/logos/eip155:56/native.png',
        'https://evil.api-dev.quant-dinger.cc/v2/market/logos/eip155:56/native.png',
      ]) {
        expect(_decode(url), isNull, reason: url);
      }
    });

    test('a loopback Development origin may be plain HTTP', () {
      LoopV2ChainCodec.debugSetLogoOrigin('http://127.0.0.1:3100');
      const url = 'http://127.0.0.1:3100/v2/market/logos/eip155:56/native.png';
      expect(_decode(url), url);
      expect(loopRemoteLogoUri(url)?.toString(), url);
      // Another loopback port is another origin.
      expect(
        _decode('http://127.0.0.1:3101/v2/market/logos/eip155:56/native.png'),
        isNull,
      );
      // Plain HTTP stays refused for any host that is not loopback.
      expect(loopRemoteLogoUri('http://api-dev.quant-dinger.cc/a.png'), isNull);
    });

    test('a build without a backend accepts only the external hosts', () {
      LoopV2ChainCodec.debugSetLogoOrigin('');
      expect(
        _decode(
          'https://api-dev.quant-dinger.cc/v2/market/logos/'
          'eip155:56/native.png',
        ),
        isNull,
      );
      expect(
        _decode('https://dd.dexscreener.com/ds-data/tokens/bsc/a.png'),
        isNotNull,
      );
    });
  });

  group('codec · external hosts', () {
    setUp(
      () => LoopV2ChainCodec.debugSetLogoOrigin(
        'https://api-dev.quant-dinger.cc',
      ),
    );

    test('the three external hosts are still accepted', () {
      for (final url in <String>[
        'https://cdn.dexscreener.com/cms/images/a.png',
        'https://dd.dexscreener.com/ds-data/tokens/bsc/$_address.png',
        'https://raw.githubusercontent.com/trustwallet/assets/master/'
            'blockchains/smartchain/info/logo.png',
      ]) {
        expect(_decode(url), url, reason: url);
      }
    });

    test('any other host is refused', () {
      for (final url in <String>[
        'https://evil.example.com/v2/market/logos/eip155:56/native.png',
        'https://api.quant-dinger.cc.evil.example/v2/market/logos/'
            'eip155:56/native.png',
        'https://githubusercontent.com/a.png',
        'http://raw.githubusercontent.com/a.png',
        'https://raw.githubusercontent.com:8443/a.png',
      ]) {
        expect(_decode(url), isNull, reason: url);
      }
    });
  });

  // The widget binding answers every HttpClient with a 400; these tests talk
  // to a real loopback server standing in for the proxy, so they opt back
  // into real sockets and resolve the exact provider the tile builds.
  group('tile · proxy bytes', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late HttpServer server;
    late String origin;
    final asked = <String>[];

    setUpAll(() async {
      final webp = await File('assets/brand/loop-app-icon-u3d.webp')
          .readAsBytes();
      // The extension is always `.png`; the bytes are what they are, and the
      // declared type is not what decides either.
      final answers = <String, (int, String, List<int>)>{
        '/v2/market/logos/eip155:56/native.png': (200, 'image/png', _jpeg),
        '/v2/market/logos/eip155:56/$_address.png': (200, 'image/png', webp),
        '/v2/market/logos/eip155:56/$_missing.png': (
          404,
          'application/json',
          utf8.encode('{"code":"NOT_FOUND"}'),
        ),
      };
      await HttpOverrides.runWithHttpOverrides(() async {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final client = HttpClient();
        painting.debugNetworkImageHttpClientProvider = () => client;
      }, _RealSockets());
      server.listen((request) async {
        asked.add(request.uri.path);
        final answer = answers[request.uri.path]!;
        request.response.statusCode = answer.$1;
        request.response.headers.contentType = ContentType.parse(answer.$2);
        request.response.add(answer.$3);
        await request.response.close();
      });
      origin = 'http://127.0.0.1:${server.port}';
    });
    tearDownAll(() async {
      painting.debugNetworkImageHttpClientProvider = null;
      await server.close(force: true);
    });
    setUp(() {
      asked.clear();
      LoopV2ChainCodec.debugSetLogoOrigin(origin);
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    });

    /// Resolves [url] the way `LoopTokenLogo` does: the tile's own URL gate,
    /// then `ResizeImage(NetworkImage)` at 32 px.
    Future<ImageInfo> load(String url) {
      final uri = loopRemoteLogoUri(url);
      expect(uri, isNotNull);
      final provider = ResizeImage.resizeIfNeeded(
        32,
        32,
        NetworkImage(uri.toString()),
      );
      final done = Completer<ImageInfo>();
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (info, _) {
                if (!done.isCompleted) done.complete(info);
              },
              onError: (error, stack) {
                if (!done.isCompleted) done.completeError(error, stack);
              },
            ),
          );
      return done.future.timeout(const Duration(seconds: 10));
    }

    for (final (label, file) in <(String, String)>[
      ('JPEG', 'native.png'),
      ('WebP', '$_address.png'),
    ]) {
      test('a .png that carries $label decodes from its bytes', () async {
        final url = LoopV2ChainCodec.logoUrl(
          _logo('$origin/v2/market/logos/eip155:56/$file'),
        )!;
        final info = await load(url);
        expect(info.image.width, greaterThan(0));
        expect(asked, <String>['/v2/market/logos/eip155:56/$file']);
        info.dispose();
      });
    }

    test('a proxy 404 is a definite failure (kept 10 minutes)', () async {
      final url = LoopV2ChainCodec.logoUrl(
        _logo('$origin/v2/market/logos/eip155:56/$_missing.png'),
      )!;
      Object? error;
      try {
        await load(url);
      } on Object catch (caught) {
        error = caught;
      }
      expect(error, isA<NetworkImageLoadException>());
      expect((error! as NetworkImageLoadException).statusCode, 404);
      // The classification the tile's failure memory uses (0101 S94b).
      expect(loopLogoFailureIsDefinite(error), isTrue);
      expect(LoopTokenLogo.failureRetryAfter, const Duration(minutes: 10));
    });
  });
}
