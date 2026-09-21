import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/mining/loop_v2_mining_api.dart';

import 'support/s7_page_harness.dart';

/// 算力明细 rendered from the response the Development stack actually sent.
///
/// The device acceptance of 2026-09-21 found this page stuck on the offline
/// card while the tab beside it had just read its own figures (visual audit
/// §I.3). The api log shows why: none of the three attempts reached the API at
/// all, so the failure was below the client and the page reported it
/// correctly. What the run could not show is that the answer, when it does
/// arrive, renders — the payload carries `stale`, a `latestAttempt` with an
/// unread holding, a proxied price and a pinned pair address, all of which the
/// strict decoder may refuse.
///
/// So this test takes the recorded answer, puts it through the real decoder,
/// and mounts the real page on the result. It skips when the capture is not
/// on the machine: the capture is a developer artifact, not a fixture.
const _token = 'preflight.access.token';
const _clientVersion = '1.0.0';

String get _captureRoot =>
    Platform.environment['LOOP_PREFLIGHT_DIR'] ??
    '../docs/integration/preflight-2026-09-16/responses';

final class _ReplayAdapter implements HttpClientAdapter {
  _ReplayAdapter(this.record);

  final Map<String, Object?> record;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final rawHeaders = (record['headers'] as Map?) ?? const <String, Object?>{};
    final headers = <String, List<String>>{};
    rawHeaders.forEach((key, value) {
      final name = '$key'.toLowerCase();
      if (value is List) {
        headers[name] = value.map((e) => '$e').toList();
      } else if (value != null) {
        headers[name] = <String>['$value'];
      }
    });
    headers.putIfAbsent(
      Headers.contentTypeHeader,
      () => <String>[Headers.jsonContentType],
    );
    return ResponseBody.fromString(
      jsonEncode(record['body']),
      record['status']! as int,
      headers: headers,
    );
  }
}

Map<String, Object?>? _load(String slug) {
  final file = File('$_captureRoot/cy/$slug.json');
  if (!file.existsSync()) return null;
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

LoopV2MiningApi _api(Map<String, Object?> record) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.example'));
  dio.httpClientAdapter = _ReplayAdapter(record);
  return DioLoopV2MiningApi(dio);
}

Future<MiningAssets> _recordedAssets(Map<String, Object?> record) =>
    _api(record).getAssets(accessToken: _token, clientVersion: _clientVersion);

Future<MiningSummary> _recordedSummary(Map<String, Object?> record) =>
    _api(record).getSummary(accessToken: _token, clientVersion: _clientVersion);

/// The mining port with one recorded answer in it. Every other read fails
/// closed, so nothing on the page can come from a fixture.
final class _RecordedMiningGateway implements MiningGateway {
  _RecordedMiningGateway(this.assets, {this.summary});

  final MiningAssets assets;
  final MiningSummary? summary;

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  Future<Never> _closed() =>
      Future<Never>.error(const LaunchException(LaunchFailureKind.unavailable));

  @override
  Future<MiningAssets> loadAssets() => Future<MiningAssets>.value(assets);

  @override
  Future<MiningSummary> loadSummary() {
    final value = summary;
    return value == null ? _closed() : Future<MiningSummary>.value(value);
  }

  @override
  Future<MiningRewards> loadRewards() => _closed();

  @override
  Future<MiningRank> loadRank(MiningRankScope scope) => _closed();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) => _closed();

  @override
  Future<MiningRules> loadRules() => _closed();
}

void main() {
  final record = _load('v2_mining_assets');
  final summaryRecord = _load('v2_mining_summary');

  group('mining · the recorded answers', skip: record == null, () {
    // The decodes run outside the widget tests: Dio owns real timers, and a
    // widget test's fake clock would never let them fire.
    late final MiningAssets assets;
    late final MiningSummary? summary;
    setUpAll(() async {
      assets = await _recordedAssets(record!);
      summary = summaryRecord == null
          ? null
          : await _recordedSummary(summaryRecord);
    });

    testWidgets('the real payload decodes and the page renders it', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: _RecordedMiningGateway(assets),
      );

      // The failure the device saw is a transport state, and it is not this
      // one: nothing about this answer puts the page on the offline card.
      expect(
        find.byKey(const ValueKey<String>('mining-assets-state-offline')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-assets-state-error')),
        findsNothing,
      );
      expect(find.text('离线 · 显示缓存'), findsNothing);

      // The two weighted holdings the snapshot priced, each with the
      // expression that produced its power.
      for (final assetId in <String>[
        'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
        'eip155:56:native',
      ]) {
        final row = find.byKey(ValueKey<String>('mining-assets-row-$assetId'));
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: assetId);
      }
      expect(find.textContaining(r'0 × $762.28 × 1×'), findsNWidgets(2));
      // Decision 0044: the chain's own coin is priced through a declared
      // proxy, and the row says whose price it is.
      expect(find.textContaining('代理价，来自 WBNB'), findsOneWidget);

      // Decision 0057: a later run did not finish, so the page keeps the last
      // complete snapshot and dates it, naming the holding that stopped the
      // next one by the symbol the same answer carries.
      final stale = find.byKey(const ValueKey<String>('mining-stale-assets'));
      await scrollToS7Section(tester, stale);
      expect(stale, findsOneWidget);
      expect(find.textContaining('USDT 的参考价不够新'), findsOneWidget);

      // The two the snapshot skipped, each with the server's own reason.
      for (final assetId in <String>[
        'eip155:56:0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
        'eip155:56:0x55d398326f99059ff775485246999027b3197955',
      ]) {
        final row = find.byKey(
          ValueKey<String>('mining-assets-excluded-$assetId'),
        );
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: assetId);
      }
    });

    testWidgets('the tab reads the same answer, so the detail page is not a '
        'second chance to fail', (tester) async {
      // The audit's sequence — the tab reads, the detail page does not — can
      // no longer leave the detail page empty: both pages read 算力明细 from
      // the same provider, and a value the tab already holds is what the
      // detail page opens on.
      if (summary == null) return;
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: _RecordedMiningGateway(assets, summary: summary),
      );

      // The tab's own answer: a settled zero under the development baseline,
      // with its unit, and the three readings the reward authority closes.
      final hero = find.byKey(const ValueKey<String>('mining-summary-hero'));
      expect(hero, findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('mining-summary-hero-power')),
            )
            .textSpan!
            .toPlainText(),
        '0 H',
      );

      // And 算力明细 on the same screen, from the same read the detail page
      // opens on.
      final composition = find.byKey(
        const ValueKey<String>('mining-composition'),
      );
      await scrollToS7Section(tester, composition);
      expect(composition, findsOneWidget);
      expect(find.textContaining(r'× $762.28 ×'), findsWidgets);
    });
  });
}
