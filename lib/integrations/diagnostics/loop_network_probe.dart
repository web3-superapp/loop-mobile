import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

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
      ? LoopL10n.current.common_notConfigured
      : (loop.hasPort && loop.port != 443 && loop.port != 80
            ? '${loop.host}:${loop.port}'
            : loop.host);
  final capabilities = loop?.replace(path: '/v2/meta/capabilities');
  return <NetworkProbeTarget>[
    NetworkProbeTarget(
      id: 'loop-ready',
      name: LoopL10n.current.integrations_networkProbeName,
      purpose: LoopL10n.current.integrations_networkProbePurpose,
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
      name: LoopL10n.current.integrations_networkProbeName2,
      purpose: LoopL10n.current.integrations_networkProbePurpose2,
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
      name: LoopL10n.current.integrations_networkProbeName3,
      purpose: LoopL10n.current.integrations_networkProbePurpose3,
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
      name: LoopL10n.current.integrations_networkProbeName4,
      purpose: LoopL10n.current.integrations_networkProbePurpose4,
      host: 'chat.stream-io-api.com',
      judge: NetworkProbeJudge.anyResponse,
      steps: <NetworkProbeRequest>[
        NetworkProbeRequest(url: Uri.parse('https://chat.stream-io-api.com/')),
      ],
    ),
    NetworkProbeTarget(
      id: 'stream-video',
      name: LoopL10n.current.integrations_networkProbeName5,
      purpose: LoopL10n.current.common_voiceRooms,
      host: 'video.stream-io-api.com',
      judge: NetworkProbeJudge.anyResponse,
      steps: <NetworkProbeRequest>[
        NetworkProbeRequest(url: Uri.parse('https://video.stream-io-api.com/')),
      ],
    ),
    NetworkProbeTarget(
      id: 'token-icons',
      name: LoopL10n.current.integrations_networkProbeName6,
      purpose: LoopL10n.current.integrations_networkProbePurpose5,
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
      name: LoopL10n.current.integrations_networkProbeName7,
      purpose: LoopL10n.current.integrations_networkProbePurpose6,
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
      name: LoopL10n.current.integrations_networkProbeName8,
      purpose: LoopL10n.current.integrations_networkProbePurpose7,
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
      name: LoopL10n.current.integrations_networkProbeName9,
      purpose: LoopL10n.current.integrations_networkProbePurpose8,
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
    return LoopL10n.current.common_unknown;
  }
});

/// Hands the report text to the system share sheet. Returns false when the
/// sheet could not be shown. Nothing is uploaded to a LOOP service.
typedef NetworkDiagnosticsShare = Future<bool> Function(String text);

final networkDiagnosticsShareProvider = Provider<NetworkDiagnosticsShare>(
  (ref) => (text) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: LoopL10n.current.integrations_networkProbeSubject,
        ),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  },
);
