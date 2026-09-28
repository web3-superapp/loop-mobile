import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_models.dart';
import 'package:loop_mobile/integrations/diagnostics/loop_network_probe.dart';

enum NetworkDiagnosticsPhase { idle, running, done }

final class NetworkDiagnosticsState {
  const NetworkDiagnosticsState({
    required this.phase,
    required this.results,
    this.startedAt,
    this.total,
  });

  final NetworkDiagnosticsPhase phase;
  final List<NetworkProbeResult> results;
  final DateTime? startedAt;
  final Duration? total;

  /// Rows that got through: 成功 and 可达 alike.
  int get okCount => results.where((result) => result.status.isReached).length;

  /// Every probe that was sent failed or timed out: most likely this device
  /// has no network at all.
  bool get allSentFailed {
    final sent = results.where((result) => result.target.isConfigured);
    return phase == NetworkDiagnosticsPhase.done &&
        sent.isNotEmpty &&
        sent.every(
          (result) =>
              result.status == NetworkProbeStatus.failed ||
              result.status == NetworkProbeStatus.timeout,
        );
  }
}

/// Runs every probe at once. Each probe has [perProbeTimeout] for all of its
/// steps; the run as a whole stops at [runTimeout], and anything still
/// running then is reported as a timeout. No failure leaves this controller.
final class NetworkDiagnosticsController
    extends Notifier<NetworkDiagnosticsState> {
  static const perProbeTimeout = Duration(seconds: 8);
  static const runTimeout = Duration(seconds: 15);

  int _run = 0;
  NetworkProbeSession? _session;

  @override
  NetworkDiagnosticsState build() {
    ref.onDispose(() {
      _run++;
      _session?.close();
      _session = null;
    });
    final targets = ref.watch(networkDiagnosticsTargetsProvider);
    return NetworkDiagnosticsState(
      phase: NetworkDiagnosticsPhase.idle,
      results: <NetworkProbeResult>[
        for (final target in targets)
          NetworkProbeResult(
            target: target,
            status: target.isConfigured
                ? NetworkProbeStatus.idle
                : NetworkProbeStatus.notConfigured,
            reason: target.isConfigured ? '' : '这个构建没有配置地址，未探测',
          ),
      ],
    );
  }

  Future<void> start() async {
    if (state.phase == NetworkDiagnosticsPhase.running) return;
    final run = ++_run;
    _session?.close();
    final session = ref
        .read(networkProbeTransportProvider)
        .open(requestTimeout: perProbeTimeout);
    _session = session;
    final started = DateTime.now();
    final clock = Stopwatch()..start();
    final targets = state.results.map((result) => result.target).toList();
    state = NetworkDiagnosticsState(
      phase: NetworkDiagnosticsPhase.running,
      startedAt: started,
      results: <NetworkProbeResult>[
        for (final target in targets)
          NetworkProbeResult(
            target: target,
            status: target.isConfigured
                ? NetworkProbeStatus.running
                : NetworkProbeStatus.notConfigured,
            reason: target.isConfigured ? '' : '这个构建没有配置地址，未探测',
          ),
      ],
    );

    void record(int index, NetworkProbeResult result) {
      if (run != _run || state.phase != NetworkDiagnosticsPhase.running) {
        return;
      }
      final results = List<NetworkProbeResult>.of(state.results);
      results[index] = result;
      state = NetworkDiagnosticsState(
        phase: state.phase,
        startedAt: state.startedAt,
        results: results,
      );
    }

    final probes = <Future<void>>[
      for (var index = 0; index < targets.length; index++)
        if (targets[index].isConfigured)
          _probe(
            session,
            targets[index],
          ).then((result) => record(index, result)),
    ];
    await Future.wait(probes).timeout(runTimeout, onTimeout: () => <void>[]);
    session.close();
    if (run != _run) return;
    if (identical(_session, session)) _session = null;
    clock.stop();
    state = NetworkDiagnosticsState(
      phase: NetworkDiagnosticsPhase.done,
      startedAt: started,
      total: clock.elapsed,
      results: <NetworkProbeResult>[
        for (final result in state.results)
          result.status == NetworkProbeStatus.running
              ? result.copyWith(
                  status: NetworkProbeStatus.timeout,
                  reason: networkProbeFaultText(NetworkProbeFaultKind.timeout),
                )
              : result,
      ],
    );
  }

  Future<NetworkProbeResult> _probe(
    NetworkProbeSession session,
    NetworkProbeTarget target,
  ) async {
    final watch = Stopwatch()..start();
    Duration? firstElapsed;
    Future<NetworkProbeResult> steps() async {
      NetworkProbeOutcome outcome = const NetworkProbeFault(
        NetworkProbeFaultKind.other,
      );
      var elapsed = Duration.zero;
      for (var step = 0; step < target.steps.length; step++) {
        final stepWatch = Stopwatch()..start();
        outcome = await session.send(target.steps[step]);
        stepWatch.stop();
        elapsed = stepWatch.elapsed;
        if (outcome is NetworkProbeFault) {
          // A failure on the first step is the result; the reuse
          // measurement only means something after a success.
          return judgeNetworkProbe(
            target: target,
            outcome: outcome,
            elapsed: watch.elapsed,
          );
        }
        if (step == 0 && target.steps.length > 1) firstElapsed = elapsed;
      }
      return judgeNetworkProbe(
        target: target,
        outcome: outcome,
        elapsed: elapsed,
        firstElapsed: firstElapsed,
      );
    }

    try {
      return await steps().timeout(
        perProbeTimeout,
        onTimeout: () => NetworkProbeResult(
          target: target,
          status: NetworkProbeStatus.timeout,
          elapsed: perProbeTimeout,
          reason: networkProbeFaultText(NetworkProbeFaultKind.timeout),
        ),
      );
    } catch (_) {
      return NetworkProbeResult(
        target: target,
        status: NetworkProbeStatus.failed,
        elapsed: watch.elapsed,
        reason: networkProbeFaultText(NetworkProbeFaultKind.other),
      );
    }
  }
}

final networkDiagnosticsControllerProvider =
    NotifierProvider.autoDispose<
      NetworkDiagnosticsController,
      NetworkDiagnosticsState
    >(NetworkDiagnosticsController.new);
