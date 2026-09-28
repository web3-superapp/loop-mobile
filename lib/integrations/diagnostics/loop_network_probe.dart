import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_models.dart';
import 'package:share_plus/share_plus.dart';

/// Network diagnostics transport (decision 0102).
///
/// Every origin gets its own Dio client from [LoopDioFactory] for the length
/// of one run: no Authorization header is ever set, none of the session,
/// retry or token layers is involved, and redirects stay off. The LOOP origin
/// uses the backend profile only because a Development build may point at a
/// loopback `http` origin; nothing on it carries a credential either.
final class LoopDioNetworkProbeTransport implements NetworkProbeTransport {
  const LoopDioNetworkProbeTransport({
    required this.loopOrigin,
    this.adapterFactory,
  });

  /// The configured LOOP origin, or null when this build has none.
  final Uri? loopOrigin;

  /// Replaces the platform adapter (tests).
  final HttpClientAdapter Function()? adapterFactory;

  @override
  NetworkProbeSession open({required Duration requestTimeout}) =>
      _LoopDioProbeSession(
        loopOrigin: loopOrigin,
        adapterFactory: adapterFactory,
        timeout: requestTimeout,
      );
}

final class _LoopDioProbeSession implements NetworkProbeSession {
  _LoopDioProbeSession({
    required this.loopOrigin,
    required this.adapterFactory,
    required this.timeout,
  });

  final Uri? loopOrigin;
  final HttpClientAdapter Function()? adapterFactory;
  final Duration timeout;
  final Map<String, Dio> _clients = <String, Dio>{};
  final CancelToken _cancel = CancelToken();
  bool _closed = false;

  Dio _clientFor(Uri url) {
    final origin = Uri(scheme: url.scheme, host: url.host, port: url.port);
    final key = origin.toString();
    return _clients.putIfAbsent(key, () {
      final loop = loopOrigin;
      final isLoop =
          loop != null &&
          loop.scheme == origin.scheme &&
          loop.host == origin.host &&
          loop.port == origin.port;
      final client = isLoop
          ? LoopDioFactory.createLoopBackend(origin: origin)
          : LoopDioFactory.createCredentialFreePublic(origin: origin);
      client.options
        ..connectTimeout = timeout
        ..sendTimeout = timeout
        ..receiveTimeout = timeout
        ..responseType = ResponseType.bytes
        ..validateStatus = (_) => true;
      final adapter = adapterFactory;
      if (adapter != null) client.httpClientAdapter = adapter();
      return client;
    });
  }

  @override
  Future<NetworkProbeOutcome> send(NetworkProbeRequest request) async {
    if (_closed) return const NetworkProbeFault(NetworkProbeFaultKind.other);
    try {
      final client = _clientFor(request.url);
      final path = request.url.hasQuery
          ? '${request.url.path}?${request.url.query}'
          : request.url.path;
      final response = await client.request<List<int>>(
        path.isEmpty ? '/' : path,
        data: request.method == NetworkProbeMethod.post
            ? request.jsonBody
            : null,
        cancelToken: _cancel,
        options: Options(
          method: request.method == NetworkProbeMethod.post ? 'POST' : 'GET',
          contentType: request.method == NetworkProbeMethod.post
              ? Headers.jsonContentType
              : null,
        ),
      );
      final data = response.data;
      return NetworkProbeReply(
        statusCode: response.statusCode ?? 0,
        body: data == null
            ? Uint8List(0)
            : (data is Uint8List ? data : Uint8List.fromList(data)),
      );
    } on DioException catch (error) {
      return NetworkProbeFault(_faultOf(error));
    } on ArgumentError {
      // LoopDioFactory refused the origin (for example plain http to a host
      // that is not loopback): nothing was sent.
      return const NetworkProbeFault(NetworkProbeFaultKind.blocked);
    } catch (_) {
      return const NetworkProbeFault(NetworkProbeFaultKind.other);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (!_cancel.isCancelled) _cancel.cancel();
    for (final client in _clients.values) {
      client.close(force: true);
    }
    _clients.clear();
  }
}

NetworkProbeFaultKind _faultOf(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.cancel:
      return NetworkProbeFaultKind.timeout;
    case DioExceptionType.badCertificate:
      return NetworkProbeFaultKind.tls;
    case DioExceptionType.badResponse:
    case DioExceptionType.transformTimeout:
      return NetworkProbeFaultKind.other;
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      final cause = error.error;
      if (cause is LoopHttpBoundaryViolation) {
        return NetworkProbeFaultKind.blocked;
      }
      if (cause is HandshakeException || cause is TlsException) {
        return NetworkProbeFaultKind.tls;
      }
      if (cause is SocketException) {
        final message = cause.message.toLowerCase();
        final os = cause.osError?.message.toLowerCase() ?? '';
        if (message.contains('host lookup') ||
            os.contains('nodename') ||
            os.contains('no address associated')) {
          return NetworkProbeFaultKind.dns;
        }
        if (message.contains('timed out') || os.contains('timed out')) {
          return NetworkProbeFaultKind.timeout;
        }
        return NetworkProbeFaultKind.connect;
      }
      return NetworkProbeFaultKind.other;
  }
}

/// The LOOP origin of [baseUrl] (scheme, host, port), or null.
Uri? loopDiagnosticsOrigin(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return Uri(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    port: uri.port,
  );
}

/// The probe list, in page order.
List<NetworkProbeTarget> loopNetworkDiagnosticTargets({
  required String backendBaseUrl,
  required String privyAppId,
}) {
  final loop = loopDiagnosticsOrigin(backendBaseUrl);
  final privy = privyAppId.trim();
  final loopHost = loop == null
      ? '未配置'
      : (loop.hasPort && loop.port != 443 && loop.port != 80
            ? '${loop.host}:${loop.port}'
            : loop.host);
  final capabilities = loop?.replace(path: '/v2/meta/capabilities');
  return <NetworkProbeTarget>[
    NetworkProbeTarget(
      id: 'loop-ready',
      name: 'LOOP 服务 · 就绪',
      purpose: '应用的主要数据',
      host: loopHost,
      judge: NetworkProbeJudge.success2xx,
      steps: loop == null
          ? const <NetworkProbeRequest>[]
          : <NetworkProbeRequest>[
              NetworkProbeRequest(url: loop.replace(path: '/health/ready')),
            ],
    ),
    NetworkProbeTarget(
      id: 'loop-capabilities',
      name: 'LOOP 服务 · 能力清单',
      purpose: '连续请求两次，记第二次（复用连接）',
      host: loopHost,
      judge: NetworkProbeJudge.success2xx,
      steps: capabilities == null
          ? const <NetworkProbeRequest>[]
          : <NetworkProbeRequest>[
              NetworkProbeRequest(url: capabilities),
              NetworkProbeRequest(url: capabilities),
            ],
    ),
    NetworkProbeTarget(
      id: 'privy',
      name: '登录服务 Privy',
      purpose: '登录与内置钱包',
      host: 'auth.privy.io',
      judge: NetworkProbeJudge.anyResponse,
      steps: privy.isEmpty
          ? const <NetworkProbeRequest>[]
          : <NetworkProbeRequest>[
              NetworkProbeRequest(
                url: Uri(
                  scheme: 'https',
                  host: 'auth.privy.io',
                  pathSegments: <String>['api', 'v1', 'apps', privy],
                ),
              ),
            ],
    ),
    NetworkProbeTarget(
      id: 'stream-chat',
      name: '聊天服务 Stream',
      purpose: '会话与消息',
      host: 'chat.stream-io-api.com',
      judge: NetworkProbeJudge.anyResponse,
      steps: <NetworkProbeRequest>[
        NetworkProbeRequest(url: Uri.parse('https://chat.stream-io-api.com/')),
      ],
    ),
    NetworkProbeTarget(
      id: 'stream-video',
      name: '语音服务 Stream',
      purpose: '语音房',
      host: 'video.stream-io-api.com',
      judge: NetworkProbeJudge.anyResponse,
      steps: <NetworkProbeRequest>[
        NetworkProbeRequest(url: Uri.parse('https://video.stream-io-api.com/')),
      ],
    ),
    NetworkProbeTarget(
      id: 'token-icons',
      name: '代币图标',
      purpose: '图标图片源',
      host: 'raw.githubusercontent.com',
      judge: NetworkProbeJudge.image,
      steps: <NetworkProbeRequest>[
        NetworkProbeRequest(
          url: Uri.parse(
            'https://raw.githubusercontent.com/trustwallet/assets/master/'
            'blockchains/smartchain/info/logo.png',
          ),
        ),
      ],
    ),
    NetworkProbeTarget(
      id: 'firebase',
      name: '推送服务 Firebase',
      purpose: '系统推送通知',
      host: 'firebaseinstallations.googleapis.com',
      judge: NetworkProbeJudge.anyResponse,
      steps: <NetworkProbeRequest>[
        NetworkProbeRequest(
          url: Uri.parse('https://firebaseinstallations.googleapis.com/'),
        ),
      ],
    ),
    NetworkProbeTarget(
      id: 'bsc-rpc',
      name: 'BSC 主网节点',
      purpose: '仅供参考，应用不直接连接节点',
      host: 'bsc-dataseed.bnbchain.org',
      judge: NetworkProbeJudge.jsonRpcBlock,
      steps: <NetworkProbeRequest>[
        NetworkProbeRequest(
          url: Uri.parse('https://bsc-dataseed.bnbchain.org/'),
          method: NetworkProbeMethod.post,
          jsonBody:
              '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}',
        ),
      ],
    ),
    NetworkProbeTarget(
      id: 'baseline',
      name: '网络基线 Apple',
      purpose: '域名解析与安全连接的对照',
      host: 'www.apple.com',
      judge: NetworkProbeJudge.anyResponse,
      steps: <NetworkProbeRequest>[
        NetworkProbeRequest(
          url: Uri.parse('https://www.apple.com/library/test/success.html'),
        ),
      ],
    ),
  ];
}

/// The backend the network layer actually uses for this build.
final networkDiagnosticsTargetsProvider = Provider<List<NetworkProbeTarget>>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  return loopNetworkDiagnosticTargets(
    backendBaseUrl: config.backendBaseUrlForCurrentBuild,
    privyAppId: config.privyAppId,
  );
});

final networkProbeTransportProvider = Provider<NetworkProbeTransport>((ref) {
  final config = ref.watch(appConfigProvider);
  return LoopDioNetworkProbeTransport(
    loopOrigin: loopDiagnosticsOrigin(config.backendBaseUrlForCurrentBuild),
  );
});

/// `Android 14 …` / `iOS 18.1 …`, as the operating system reports itself.
final networkDiagnosticsPlatformProvider = Provider<String>((ref) {
  try {
    final name = switch (Platform.operatingSystem) {
      'android' => 'Android',
      'ios' => 'iOS',
      'macos' => 'macOS',
      final other => other,
    };
    return '$name · ${Platform.operatingSystemVersion}';
  } catch (_) {
    return '未知';
  }
});

/// Hands the report text to the system share sheet. Returns false when the
/// sheet could not be shown. Nothing is uploaded to a LOOP service.
typedef NetworkDiagnosticsShare = Future<bool> Function(String text);

final networkDiagnosticsShareProvider = Provider<NetworkDiagnosticsShare>(
  (ref) => (text) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: 'LOOP 网络诊断'),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  },
);
