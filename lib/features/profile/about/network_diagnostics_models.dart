import 'dart:typed_data';

import 'package:loop_mobile/l10n/loop_l10n.dart';

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
  NetworkProbeStatus.idle =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsIdle,
  NetworkProbeStatus.running =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsRunning,
  NetworkProbeStatus.ok => LoopL10n.current.common_success,
  NetworkProbeStatus.reachable =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsReachable,
  NetworkProbeStatus.timeout =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsTimeout,
  NetworkProbeStatus.failed => LoopL10n.current.common_failed,
  NetworkProbeStatus.notConfigured => LoopL10n.current.common_notConfigured,
};

String networkProbeFaultText(NetworkProbeFaultKind kind) => switch (kind) {
  NetworkProbeFaultKind.timeout =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsTimeout2,
  NetworkProbeFaultKind.dns =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsDns,
  NetworkProbeFaultKind.connect =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsConnect,
  NetworkProbeFaultKind.tls =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsTls,
  NetworkProbeFaultKind.blocked =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsBlocked,
  NetworkProbeFaultKind.other =>
    LoopL10n.current.profileAbout_networkDiagnosticsModelsOther,
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
      : LoopL10n.current.profileAbout_networkDiagnosticsModelsS(
          firstElapsed.inMilliseconds,
        );
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
                : LoopL10n.current.profileAbout_networkDiagnosticsModelsReason(
                    reused,
                    statusCode,
                  ),
          );
        case NetworkProbeJudge.image:
          final image = is2xx && _looksLikeImage(body);
          return NetworkProbeResult(
            target: target,
            status: image ? NetworkProbeStatus.ok : NetworkProbeStatus.failed,
            elapsed: elapsed,
            reason: image
                ? LoopL10n.current.profileAbout_networkDiagnosticsModelsReason2(
                    _bytesText(body.length),
                    statusCode,
                  )
                : LoopL10n.current.profileAbout_networkDiagnosticsModelsReason3(
                    statusCode,
                  ),
          );
        case NetworkProbeJudge.jsonRpcBlock:
          final block = _jsonRpcBlockNumber(body);
          return NetworkProbeResult(
            target: target,
            status: NetworkProbeStatus.reachable,
            elapsed: elapsed,
            reason: block == null
                ? 'HTTP $statusCode'
                : LoopL10n.current.profileAbout_networkDiagnosticsModelsReason4(
                    block,
                    statusCode,
                  ),
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
    LoopL10n
        .current
        .profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport,
    LoopL10n.current
        .profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport2(
          networkDiagnosticsTimestamp(startedAt),
        ),
    LoopL10n.current
        .profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport3(
          context.appVersion,
        ),
    LoopL10n.current
        .profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport4(
          context.buildMode,
        ),
    LoopL10n.current
        .profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport5(
          context.serverHost,
        ),
    LoopL10n.current
        .profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport6(
          context.platform,
        ),
    if (total != null)
      LoopL10n.current
          .profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport7(
            total.inMilliseconds,
          ),
    LoopL10n.current
        .profileAbout_networkDiagnosticsModelsNetworkDiagnosticsReport8(
          okCount,
          results.length,
        ),
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
