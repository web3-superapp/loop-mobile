import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/profile/about/about_screen.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_controller.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_models.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_screen.dart';
import 'package:loop_mobile/integrations/diagnostics/loop_network_probe.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s8_harness.dart';

/// Decision 0102 · 网络诊断. The real Dio transport runs against a fake HTTP
/// adapter: nothing leaves the test process.

const _png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];

enum _Behaviour { ok, hang, dnsFailure, refused, http503 }

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.behaviourFor, this.log);

  final _Behaviour Function(Uri uri) behaviourFor;
  final List<RequestOptions> log;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    log.add(options);
    // Let every probe dispatch before any answers.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    switch (behaviourFor(options.uri)) {
      case _Behaviour.hang:
        // Never answers; released only when the run closes its session.
        await (cancelFuture ?? Completer<void>().future);
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: 'closed',
        );
      case _Behaviour.dnsFailure:
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'lookup',
          error: const SocketException('Failed host lookup: x'),
        );
      case _Behaviour.refused:
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
          error: const SocketException('Connection refused'),
        );
      case _Behaviour.http503:
        return ResponseBody.fromString('{}', 503);
      case _Behaviour.ok:
        final host = options.uri.host;
        if (host == 'raw.githubusercontent.com') {
          return ResponseBody.fromBytes(_png, 200);
        }
        if (host == 'bsc-dataseed.bnbchain.org') {
          return ResponseBody.fromString(
            '{"jsonrpc":"2.0","id":1,"result":"0x10"}',
            200,
          );
        }
        if (host == 'firebaseinstallations.googleapis.com') {
          return ResponseBody.fromString('not found', 404);
        }
        return ResponseBody.fromString('{}', 200);
    }
  }

  @override
  void close({bool force = false}) {}
}

AppConfig _config({String backend = 'https://api-dev.example.com'}) =>
    AppConfig(
      privyAppId: 'privy-app-test',
      privyAppClientId: '',
      streamApiKey: '',
      backendBaseUrl: backend,
      firebaseConfigured: false,
      declaredBuildModeName: 'debug',
    );

List<Override> _overrides({
  required _Behaviour Function(Uri uri) behaviour,
  required List<RequestOptions> log,
  String backend = 'https://api-dev.example.com',
  List<String>? shared,
}) => <Override>[
  appConfigProvider.overrideWithValue(_config(backend: backend)),
  networkProbeTransportProvider.overrideWith(
    (ref) => LoopDioNetworkProbeTransport(
      loopOrigin: loopDiagnosticsOrigin(backend),
      adapterFactory: () => _FakeAdapter(behaviour, log),
    ),
  ),
  networkDiagnosticsPlatformProvider.overrideWithValue('Android · test'),
  networkDiagnosticsShareProvider.overrideWithValue((text) async {
    shared?.add(text);
    return true;
  }),
];

Finder _status(String id) =>
    find.byKey(ValueKey<String>('network-probe-$id-status'));

Finder _row(String id) => find.byKey(ValueKey<String>('network-probe-$id'));

String _badge(WidgetTester tester, String id) {
  final text = tester.widget<Text>(
    find.descendant(of: _status(id), matching: find.byType(Text)),
  );
  return text.data!;
}

Future<void> _start(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('network-diagnostics-start')),
  );
  await tester.pump();
}

const _ids = <String>[
  'loop-ready',
  'loop-capabilities',
  'privy',
  'stream-chat',
  'stream-video',
  'token-icons',
  'firebase',
  'bsc-rpc',
  'baseline',
];

void main() {
  test('targets: nine probes, the reviewed hosts and methods', () {
    final targets = loopNetworkDiagnosticTargets(
      backendBaseUrl: 'https://api-dev.example.com/',
      privyAppId: 'app-1',
    );
    expect(targets.map((target) => target.id), _ids);
    final byId = {for (final target in targets) target.id: target};
    expect(
      byId['loop-ready']!.steps.single.url.toString(),
      'https://api-dev.example.com/health/ready',
    );
    expect(byId['loop-capabilities']!.steps, hasLength(2));
    expect(
      byId['privy']!.steps.single.url.toString(),
      'https://auth.privy.io/api/v1/apps/app-1',
    );
    expect(byId['bsc-rpc']!.steps.single.method, NetworkProbeMethod.post);
    expect(byId['bsc-rpc']!.steps.single.jsonBody, contains('eth_blockNumber'));

    final bare = loopNetworkDiagnosticTargets(
      backendBaseUrl: '',
      privyAppId: '',
    );
    expect(
      bare.where((target) => !target.isConfigured).map((t) => t.id),
      <String>['loop-ready', 'loop-capabilities', 'privy'],
    );
  });

  testWidgets('idle: nothing is sent until 开始诊断', (tester) async {
    final log = <RequestOptions>[];
    await pumpS8Page(
      tester,
      const NetworkDiagnosticsScreen(),
      overrides: _overrides(behaviour: (_) => _Behaviour.ok, log: log),
    );
    expect(find.text('这个页面只测连通性和耗时，不发送账号信息。'), findsOneWidget);
    for (final id in _ids) {
      expect(_badge(tester, id), '未开始');
    }
    expect(log, isEmpty);
    final copy = tester.widget<LoopButton>(
      find.byKey(const ValueKey<String>('network-diagnostics-copy')),
    );
    expect(copy.onPressed, isNull);
  });

  testWidgets('success: all probes are sent in parallel and render 成功', (
    tester,
  ) async {
    final log = <RequestOptions>[];
    await pumpS8Page(
      tester,
      const NetworkDiagnosticsScreen(),
      overrides: _overrides(behaviour: (_) => _Behaviour.ok, log: log),
    );
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 1));
    // Every probe's first request is out before any has answered.
    expect(log, hasLength(9));
    expect(_badge(tester, 'firebase'), '探测中');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    for (final id in _ids) {
      expect(_badge(tester, id), '成功', reason: id);
    }
    // The capabilities probe asked twice; nothing carried a credential.
    expect(
      log.where((request) => request.uri.path.endsWith('/capabilities')),
      hasLength(2),
    );
    for (final request in log) {
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
    }
    final rpc = log.singleWhere(
      (request) => request.uri.host == 'bsc-dataseed.bnbchain.org',
    );
    expect(rpc.method, 'POST');
    expect(
      find.descendant(
        of: _row('token-icons'),
        matching: find.textContaining('图片 11 B'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _row('bsc-rpc'),
        matching: find.textContaining('区块 16'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _row('loop-capabilities'),
        matching: find.textContaining('复用连接'),
      ),
      findsOneWidget,
    );
    expect(find.text('9 项中 9 项可达'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('network-diagnostics-offline')),
      findsNothing,
    );
  });

  testWidgets('timeout: a hanging probe is 超时 after its own 8 s', (
    tester,
  ) async {
    final log = <RequestOptions>[];
    await pumpS8Page(
      tester,
      const NetworkDiagnosticsScreen(),
      overrides: _overrides(
        behaviour: (uri) => uri.host == 'firebaseinstallations.googleapis.com'
            ? _Behaviour.hang
            : _Behaviour.ok,
        log: log,
      ),
    );
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_badge(tester, 'firebase'), '探测中');
    expect(_badge(tester, 'baseline'), '成功');
    await tester.pump(NetworkDiagnosticsController.perProbeTimeout);
    await tester.pumpAndSettle();
    expect(_badge(tester, 'firebase'), '超时');
    expect(
      find.descendant(
        of: _row('firebase'),
        matching: find.textContaining('超时'),
      ),
      findsWidgets,
    );
    expect(find.text('9 项中 8 项可达'), findsOneWidget);
  });

  testWidgets('failure: 无法连接 with a short reason; LOOP non-2xx is 失败', (
    tester,
  ) async {
    final log = <RequestOptions>[];
    await pumpS8Page(
      tester,
      const NetworkDiagnosticsScreen(),
      overrides: _overrides(
        behaviour: (uri) => switch (uri.host) {
          'auth.privy.io' => _Behaviour.dnsFailure,
          'chat.stream-io-api.com' => _Behaviour.refused,
          'api-dev.example.com' => _Behaviour.http503,
          _ => _Behaviour.ok,
        },
        log: log,
      ),
    );
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(_badge(tester, 'privy'), '失败');
    expect(
      find.descendant(
        of: _row('privy'),
        matching: find.textContaining('域名解析失败'),
      ),
      findsOneWidget,
    );
    expect(_badge(tester, 'stream-chat'), '失败');
    expect(
      find.descendant(
        of: _row('stream-chat'),
        matching: find.textContaining('无法连接'),
      ),
      findsOneWidget,
    );
    expect(_badge(tester, 'loop-ready'), '失败');
    expect(
      find.descendant(
        of: _row('loop-ready'),
        matching: find.textContaining('HTTP 503'),
      ),
      findsOneWidget,
    );
    expect(_badge(tester, 'baseline'), '成功');
  });

  testWidgets('offline: every probe fails, a notice says so', (tester) async {
    final log = <RequestOptions>[];
    await pumpS8Page(
      tester,
      const NetworkDiagnosticsScreen(),
      overrides: _overrides(behaviour: (_) => _Behaviour.dnsFailure, log: log),
    );
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('network-diagnostics-offline')),
      findsOneWidget,
    );
    expect(find.text('9 项中 0 项可达'), findsOneWidget);
  });

  testWidgets('not configured: no backend, the LOOP rows are not sent', (
    tester,
  ) async {
    final log = <RequestOptions>[];
    await pumpS8Page(
      tester,
      const NetworkDiagnosticsScreen(),
      overrides: _overrides(
        behaviour: (_) => _Behaviour.ok,
        log: log,
        backend: '',
      ),
    );
    expect(_badge(tester, 'loop-ready'), '未配置');
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(_badge(tester, 'loop-ready'), '未配置');
    expect(_badge(tester, 'loop-capabilities'), '未配置');
    expect(
      log.where((request) => request.uri.host.contains('example')),
      isEmpty,
    );
    expect(find.text('7 项中 7 项可达'), findsOneWidget);
  });

  testWidgets('copy and share hand over the same text with every probe', (
    tester,
  ) async {
    final log = <RequestOptions>[];
    final shared = <String>[];
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpS8Page(
      tester,
      const NetworkDiagnosticsScreen(),
      overrides: _overrides(
        behaviour: (uri) => uri.host == 'chat.stream-io-api.com'
            ? _Behaviour.refused
            : _Behaviour.ok,
        log: log,
        shared: shared,
      ),
    );
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('network-diagnostics-copy')),
    );
    await tester.pump();
    expect(find.text('诊断结果已复制'), findsOneWidget);
    final text = copied!;
    for (final fragment in <String>[
      'LOOP 网络诊断',
      'App 版本：0.1.0+1',
      '构建模式：声明 debug',
      '服务端主机：api-dev.example.com（DEV）',
      '平台：Android · test',
      '时间：',
      '总耗时：',
      '[成功] LOOP 服务 · 就绪 (api-dev.example.com)',
      '[成功] LOOP 服务 · 能力清单',
      '[成功] 登录服务 Privy (auth.privy.io)',
      '[失败] 聊天服务 Stream (chat.stream-io-api.com)',
      '[成功] 语音服务 Stream (video.stream-io-api.com)',
      '[成功] 代币图标 (raw.githubusercontent.com)',
      '[成功] 推送服务 Firebase (firebaseinstallations.googleapis.com)',
      '[成功] BSC 主网节点 (bsc-dataseed.bnbchain.org)',
      '[成功] 网络基线 Apple (www.apple.com)',
    ]) {
      expect(text, contains(fragment));
    }
    // No account material and no full Privy URL.
    expect(text, isNot(contains('privy-app-test')));
    expect(text, isNot(contains('翻墙')));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(
      find.byKey(const ValueKey<String>('network-diagnostics-share')),
    );
    await tester.pumpAndSettle();
    expect(shared.single, text);
  });

  testWidgets('关于 → 网络诊断 pushes the page', (tester) async {
    final log = <RequestOptions>[];
    await pumpS8Page(
      tester,
      const AboutScreen(),
      about: FakeAboutGateway(),
      overrides: _overrides(behaviour: (_) => _Behaviour.ok, log: log),
    );
    final entry = find.byKey(
      const ValueKey<String>('about-network-diagnostics'),
    );
    await scrollToS8Section(tester, entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('network-diagnostics-screen')),
      findsOneWidget,
    );
    expect(log, isEmpty);
  });

  test('report text is neutral and lists hosts only', () {
    final targets = loopNetworkDiagnosticTargets(
      backendBaseUrl: 'https://api-dev.example.com',
      privyAppId: 'secretish-app',
    );
    final text = networkDiagnosticsReport(
      context: const NetworkDiagnosticsContext(
        appVersion: '1.0.0+6',
        buildMode: 'release',
        serverHost: 'api-dev.example.com',
        platform: 'iOS · 18',
      ),
      results: <NetworkProbeResult>[
        for (final target in targets)
          NetworkProbeResult(
            target: target,
            status: NetworkProbeStatus.timeout,
            elapsed: const Duration(seconds: 8),
            reason: networkProbeFaultText(NetworkProbeFaultKind.timeout),
          ),
      ],
      startedAt: DateTime.utc(2026, 9, 28, 6),
      total: const Duration(seconds: 8),
    );
    expect(text, contains('9 项中 0 项可达'));
    expect(text, contains('[超时] 代币图标 (raw.githubusercontent.com) 8000 ms'));
    expect(text, contains('2026-09-28 06:00:00 +00:00'));
    expect(text, isNot(contains('secretish-app')));
    expect(text, isNot(contains('被墙')));
  });
}
