import 'dart:typed_data';

/// Network diagnostics (decision 0102): what each probe asks, what came back,
/// and how the reader is told. Nothing here performs a request; the transport
/// port below is implemented under `lib/integrations/diagnostics/`.

/// How a probe's reply is judged.
enum NetworkProbeJudge {
  /// Any HTTP response means the host is reachable.
  anyResponse,

  /// The LOOP service must answer 2xx to count as working.
  success2xx,

  /// A 2xx whose body is an image.
  image,

  /// Any response is reachable; a JSON-RPC block number is read if present.
  jsonRpcBlock,
}

enum NetworkProbeMethod { get, post }

/// One HTTP request a probe makes. [jsonBody] is sent only with POST.
final class NetworkProbeRequest {
  const NetworkProbeRequest({
    required this.url,
    this.method = NetworkProbeMethod.get,
    this.jsonBody,
  });

  final Uri url;
  final NetworkProbeMethod method;
  final String? jsonBody;
}

/// One row of the page.
///
/// [steps] run one after another on the same connection pool; the row reports
/// the last step's time, so a two-step probe measures a reused connection.
/// Empty [steps] means the build carries no address for this service.
final class NetworkProbeTarget {
  const NetworkProbeTarget({
    required this.id,
    required this.name,
    required this.purpose,
    required this.host,
    required this.steps,
    required this.judge,
  });

  final String id;
  final String name;

  /// One short phrase on what the service is for.
  final String purpose;

  /// Shown on the row and in the copied text; never a full URL.
  final String host;
  final List<NetworkProbeRequest> steps;
  final NetworkProbeJudge judge;

  bool get isConfigured => steps.isNotEmpty;
}

/// Why a request produced no HTTP response.
enum NetworkProbeFaultKind {
  timeout,
  dns,
  connect,
  tls,

  /// The request was refused on this device before it was sent (an address
  /// the network rules do not allow).
  blocked,
  other,
}

/// What the transport saw for one request. The transport never throws.
sealed class NetworkProbeOutcome {
  const NetworkProbeOutcome();
}

final class NetworkProbeReply extends NetworkProbeOutcome {
  const NetworkProbeReply({required this.statusCode, required this.body});

  final int statusCode;
  final Uint8List body;
}

final class NetworkProbeFault extends NetworkProbeOutcome {
  const NetworkProbeFault(this.kind);

  final NetworkProbeFaultKind kind;
}

/// A set of requests that may share connections. Closing it abandons
/// anything still in flight.
abstract interface class NetworkProbeSession {
  Future<NetworkProbeOutcome> send(NetworkProbeRequest request);

  void close();
}

/// The port: opens one session per diagnostic run.
abstract interface class NetworkProbeTransport {
  NetworkProbeSession open({required Duration requestTimeout});
}

/// [ok]: the expected content came back (LOOP 2xx, an image). [reachable]:
/// a third-party host answered with some HTTP response, which is all this
/// page asks of it.
enum NetworkProbeStatus {
  idle,
  running,
  ok,
  reachable,
  timeout,
  failed,
  notConfigured;

  bool get isReached => this == ok || this == reachable;
}

final class NetworkProbeResult {
  const NetworkProbeResult({
    required this.target,
    required this.status,
    this.elapsed,
    this.reason = '',
  });

  final NetworkProbeTarget target;
  final NetworkProbeStatus status;

  /// The measured time of the reported request; null before it finishes and
  /// for a probe that was never sent.
  final Duration? elapsed;
  final String reason;

  NetworkProbeResult copyWith({
    required NetworkProbeStatus status,
    Duration? elapsed,
    String reason = '',
  }) => NetworkProbeResult(
    target: target,
    status: status,
    elapsed: elapsed,
    reason: reason,
  );
}

String networkProbeStatusLabel(NetworkProbeStatus status) => switch (status) {
  NetworkProbeStatus.idle => '未开始',
  NetworkProbeStatus.running => '探测中',
  NetworkProbeStatus.ok => '成功',
  NetworkProbeStatus.reachable => '可达',
  NetworkProbeStatus.timeout => '超时',
  NetworkProbeStatus.failed => '失败',
  NetworkProbeStatus.notConfigured => '未配置',
};

String networkProbeFaultText(NetworkProbeFaultKind kind) => switch (kind) {
  NetworkProbeFaultKind.timeout => '超时，规定时间内没有响应',
  NetworkProbeFaultKind.dns => '无法连接：域名解析失败',
  NetworkProbeFaultKind.connect => '无法连接：连接被拒绝或中断',
  NetworkProbeFaultKind.tls => '无法连接：安全连接握手失败',
  NetworkProbeFaultKind.blocked => '未发出：地址不符合本机网络规则',
  NetworkProbeFaultKind.other => '无法连接',
};

/// Judges a finished probe. [first] is the first step's outcome when the
/// probe had more than one step (the reused-connection measurement).
NetworkProbeResult judgeNetworkProbe({
  required NetworkProbeTarget target,
  required NetworkProbeOutcome outcome,
  required Duration elapsed,
  Duration? firstElapsed,
}) {
  final reused = firstElapsed == null
      ? ''
      : ' · 首次 ${firstElapsed.inMilliseconds} ms，复用连接';
  switch (outcome) {
    case NetworkProbeFault(:final kind):
      return NetworkProbeResult(
        target: target,
        status: kind == NetworkProbeFaultKind.timeout
            ? NetworkProbeStatus.timeout
            : NetworkProbeStatus.failed,
        elapsed: elapsed,
        reason: networkProbeFaultText(kind),
      );
    case NetworkProbeReply(:final statusCode, :final body):
      final is2xx = statusCode >= 200 && statusCode < 300;
      switch (target.judge) {
        case NetworkProbeJudge.anyResponse:
          return NetworkProbeResult(
            target: target,
            status: NetworkProbeStatus.reachable,
            elapsed: elapsed,
            reason: 'HTTP $statusCode$reused',
          );
        case NetworkProbeJudge.success2xx:
          return NetworkProbeResult(
            target: target,
            status: is2xx ? NetworkProbeStatus.ok : NetworkProbeStatus.failed,
            elapsed: elapsed,
            reason: is2xx
                ? 'HTTP $statusCode$reused'
                : '已连上，但服务返回 HTTP $statusCode$reused',
          );
        case NetworkProbeJudge.image:
          final image = is2xx && _looksLikeImage(body);
          return NetworkProbeResult(
            target: target,
            status: image ? NetworkProbeStatus.ok : NetworkProbeStatus.failed,
            elapsed: elapsed,
            reason: image
                ? 'HTTP $statusCode · 图片 ${_bytesText(body.length)}'
                : '已连上，但没有拿到图片 · HTTP $statusCode',
          );
        case NetworkProbeJudge.jsonRpcBlock:
          final block = _jsonRpcBlockNumber(body);
          return NetworkProbeResult(
            target: target,
            status: NetworkProbeStatus.reachable,
            elapsed: elapsed,
            reason: block == null
                ? 'HTTP $statusCode'
                : 'HTTP $statusCode · 区块 $block',
          );
      }
  }
}

bool _looksLikeImage(Uint8List body) {
  bool starts(List<int> signature) {
    if (body.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (body[index] != signature[index]) return false;
    }
    return true;
  }

  return starts(const <int>[0x89, 0x50, 0x4E, 0x47]) || // PNG
      starts(const <int>[0xFF, 0xD8, 0xFF]) || // JPEG
      starts(const <int>[0x47, 0x49, 0x46]) || // GIF
      starts(const <int>[0x52, 0x49, 0x46, 0x46]); // RIFF (WebP)
}

String _bytesText(int length) =>
    length < 1024 ? '$length B' : '${(length / 1024).toStringAsFixed(1)} KB';

/// Reads `"result":"0x…"` without a JSON dependency on the body's shape.
String? _jsonRpcBlockNumber(Uint8List body) {
  if (body.length > 4096) return null;
  final text = String.fromCharCodes(body);
  final match = RegExp(r'"result"\s*:\s*"0x([0-9a-fA-F]{1,16})"')
      .firstMatch(text);
  if (match == null) return null;
  final value = int.tryParse(match.group(1)!, radix: 16);
  return value?.toString();
}

/// The facts printed above the per-probe lines in the copied text.
final class NetworkDiagnosticsContext {
  const NetworkDiagnosticsContext({
    required this.appVersion,
    required this.buildMode,
    required this.serverHost,
    required this.platform,
  });

  final String appVersion;
  final String buildMode;
  final String serverHost;
  final String platform;
}

/// Local time with its UTC offset, e.g. `2026-09-28 14:03:22 +08:00`.
String networkDiagnosticsTimestamp(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  final offset = time.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)} '
      '$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}

/// The plain text the 复制 / 分享 actions hand over. It names hosts, never
/// full URLs, and carries no account information.
String networkDiagnosticsReport({
  required NetworkDiagnosticsContext context,
  required List<NetworkProbeResult> results,
  required DateTime startedAt,
  required Duration? total,
}) {
  final okCount = results.where((result) => result.status.isReached).length;
  final lines = <String>[
    'LOOP 网络诊断',
    '时间：${networkDiagnosticsTimestamp(startedAt)}',
    'App 版本：${context.appVersion}',
    '构建模式：${context.buildMode}',
    '服务端主机：${context.serverHost}',
    '平台：${context.platform}',
    if (total != null) '总耗时：${total.inMilliseconds} ms',
    '结果：${results.length} 项中 $okCount 项可达',
    '',
    for (final result in results)
      <String>[
        '[${networkProbeStatusLabel(result.status)}]',
        result.target.name,
        '(${result.target.host})',
        result.elapsed == null ? '-' : '${result.elapsed!.inMilliseconds} ms',
        if (result.reason.isNotEmpty) result.reason,
      ].join(' '),
  ];
  return lines.join('\n');
}
