import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_overview_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';

import 'support/launch2_fixtures.dart';

/// Decision 0206 (backend 0164, contracts 0016): the read side decodes a
/// ticker / symbol by the same four.meme rule the form writes with.
const String _family = '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}';
const String _england =
    '\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}';

/// Tickers the server must never send: empty, a control character, 21
/// units, an edge space.
final List<String> _bad = <String>[
  '',
  'DO\u{0007}GE',
  '中' * 21,
  ' DOGE',
  'DOGE ',
  'a\u{202E}b',
];

final Matcher _invalidPayload = throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

Map<String, Object?> _copy(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

Object? _creatorBody(String name) => (jsonDecode(
  File('test/fixtures/s135-launch2-creator/$name.json').readAsStringSync(),
) as Map<String, Object?>)['body'];

Map<String, Object?> _activity(String ticker) => <String, Object?>{
  'kind': 'curve_buy',
  'instanceId': l2InstanceA,
  'ticker': ticker,
  'name': 'Doge on LOOP',
  'logoUrl': null,
  'actor': null,
  'amountUsd1': '20',
  'at': l2Now.toIso8601String(),
  'transactionHash': '0x${'a' * 64}',
};

void main() {
  group('launch2 list and detail', () {
    test('a Chinese ticker decodes as sent', () {
      final page = LoopV2Launch2Codec.page(
        l2PageJson(<Map<String, Object?>>[l2RowJson(ticker: '狗狗币')]),
        mediaUrl: (_) => null,
      );
      expect(page.items.single.ticker, '狗狗币');
      final body = l2DetailJson();
      (body['instance']! as Map<String, Object?>)['ticker'] = _family;
      expect(
        LoopV2Launch2Codec.detail(body, mediaUrl: (_) => null).row.ticker,
        _family,
      );
    });

    test('a ticker off the rule is an invalid payload', () {
      for (final ticker in _bad) {
        expect(
          () => LoopV2Launch2Codec.page(
            l2PageJson(<Map<String, Object?>>[l2RowJson(ticker: ticker)]),
            mediaUrl: (_) => null,
          ),
          _invalidPayload,
          reason: ticker,
        );
        final body = l2DetailJson();
        (body['instance']! as Map<String, Object?>)['ticker'] = ticker;
        expect(
          () => LoopV2Launch2Codec.detail(body, mediaUrl: (_) => null),
          _invalidPayload,
          reason: ticker,
        );
      }
    });

    test('a position keeps a ZWJ ticker whole', () {
      final json = l2PositionsJson();
      ((json['positions']! as List<Object?>).single!
              as Map<String, Object?>)['ticker'] =
          _family;
      final positions = LoopV2Launch2Codec.positions(
        json,
        mediaUrl: (_) => null,
      );
      expect(positions.items.single.ticker, _family);
    });
  });

  group('overview tape', () {
    test('a Chinese ticker is read; a bad one drops only its line', () {
      final overview = LoopV2Launch2OverviewCodec.overview(<String, Object?>{
        'activity': <Object?>[
          _activity('狗狗币'),
          for (final ticker in _bad) _activity(ticker),
          _activity(r'$1'),
        ],
      }, mediaUrl: (_) => null);
      expect(overview.activity.map((item) => item.ticker), <String>[
        '狗狗币',
        r'$1',
      ]);
    });
  });

  group('creator config and signing request', () {
    test('a Chinese ticker decodes in both', () {
      final config = _copy(_creatorBody('hooks_config_draft'));
      ((config['draft']! as Map)['config']! as Map)['ticker'] = '狗狗币';
      expect(
        LoopV2Launch2CreatorCodec.configEnvelope(
          config,
          projectId: l2ProjectId,
        ).draft!.ticker,
        '狗狗币',
      );
      final request = _copy(_creatorBody('hooks_signing_request'));
      (request['request']! as Map)['ticker'] = '狗狗币';
      ((request['typedData']! as Map)['message']! as Map)['ticker'] = '狗狗币';
      expect(LoopV2Launch2CreatorCodec.signingRequest(request).ticker, '狗狗币');
    });

    test('a ticker off the rule is an invalid payload in both', () {
      for (final ticker in _bad) {
        final config = _copy(_creatorBody('hooks_config_draft'));
        ((config['draft']! as Map)['config']! as Map)['ticker'] = ticker;
        expect(
          () => LoopV2Launch2CreatorCodec.configEnvelope(
            config,
            projectId: l2ProjectId,
          ),
          _invalidPayload,
          reason: ticker,
        );
        final request = _copy(_creatorBody('hooks_signing_request'));
        (request['request']! as Map)['ticker'] = ticker;
        ((request['typedData']! as Map)['message']! as Map)['ticker'] = ticker;
        expect(
          () => LoopV2Launch2CreatorCodec.signingRequest(request),
          _invalidPayload,
          reason: ticker,
        );
      }
    });
  });

  group('S7 launch codec', () {
    test('requireTicker takes the rule and refuses what is off it', () {
      for (final ticker in <String>['狗狗币', r'$1', 'doge', _family]) {
        expect(
          LoopV2S7Codec.requireTicker(<String, Object?>{
            'ticker': ticker,
          }, 'ticker'),
          ticker,
        );
      }
      for (final ticker in _bad) {
        expect(
          () => LoopV2S7Codec.requireTicker(<String, Object?>{
            'ticker': ticker,
          }, 'ticker'),
          _invalidPayload,
          reason: ticker,
        );
      }
    });
  });

  group('symbols across codecs keep ZWJ and tag flags', () {
    test('chain, projection and S7 symbols take the ticker rule', () {
      for (final symbol in <String>['USD1', '狗狗币', _family, _england]) {
        final source = <String, Object?>{'symbol': symbol};
        expect(LoopV2ChainCodec.requireSymbol(source, 'symbol'), symbol);
        expect(LoopV2ProjectionCodec.requireSymbol(source, 'symbol'), symbol);
        expect(LoopV2S7Codec.optionalSymbol(source, 'symbol'), symbol);
      }
      // The field's own bound stays (a wallet asset's 32).
      final long = <String, Object?>{'symbol': 'A' * 32};
      expect(LoopV2ChainCodec.requireSymbol(long, 'symbol'), 'A' * 32);
      expect(
        () => LoopV2ChainCodec.requireSymbol(<String, Object?>{
          'symbol': 'A' * 33,
        }, 'symbol'),
        _invalidPayload,
      );
      for (final symbol in <String>[
        '',
        ' USD1',
        'US\u{200B}D1',
        'a\u{202E}b',
        '\u{200D}X',
      ]) {
        final source = <String, Object?>{'symbol': symbol};
        expect(
          () => LoopV2ChainCodec.requireSymbol(source, 'symbol'),
          _invalidPayload,
          reason: symbol,
        );
        expect(
          () => LoopV2ProjectionCodec.requireSymbol(source, 'symbol'),
          throwsA(isA<LoopBackendFailure>()),
          reason: symbol,
        );
      }
    });

    test('a community bound asset with a ZWJ symbol decodes', () {
      final asset = LoopV2ProjectionCodec.communityBoundAsset(<String, Object?>{
        'assetId': 'eip155:97:0x${'a' * 40}',
        'symbol': _family,
        'name': null,
        'logoUrl': null,
        'hasRegisteredPool': true,
      });
      expect(asset!.symbol, _family);
    });

    test('provider text keeps emoji joiners only when asked', () {
      expect(LoopV2ChainCodec.sanitizeProviderText(_family), isNot(_family));
      expect(
        LoopV2ChainCodec.sanitizeProviderText(_family, keepEmojiJoiners: true),
        _family,
      );
      expect(
        LoopV2ChainCodec.sanitizeProviderText(
          'a\u{202E}b\u{200B}',
          keepEmojiJoiners: true,
        ),
        'ab',
      );
    });
  });
}
