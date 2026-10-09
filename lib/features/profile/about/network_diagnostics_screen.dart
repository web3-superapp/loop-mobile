import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_backend_identity.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_controller.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_models.dart';
import 'package:loop_mobile/integrations/diagnostics/loop_network_probe.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';

/// Opens 网络诊断 over 关于 (decision 0102). It is a pushed child page, not a
/// route: the route manifest stays at 93 entries.
Future<void> openNetworkDiagnostics(BuildContext context) {
  final navigator = Navigator.of(context);
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  Widget page(BuildContext context) =>
      NetworkDiagnosticsScreen(onBack: () => Navigator.of(context).maybePop());
  return navigator.push<void>(
    reduceMotion
        ? PageRouteBuilder<void>(
            settings: const RouteSettings(name: 'about/network-diagnostics'),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (context, _, _) => page(context),
          )
        : MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'about/network-diagnostics'),
            builder: page,
          ),
  );
}

/// 网络诊断 · action archetype, dashboard layout.
///
/// States: idle (未开始, nothing sent yet), running (each row 探测中),
/// done (per-row 成功 / 超时 / 失败), offline (every sent probe failed — a
/// notice asks the reader to check the connection), not configured (a row
/// this build has no address for). There is no permission state: the page
/// needs no session and no system permission.
class NetworkDiagnosticsScreen extends ConsumerWidget {
  const NetworkDiagnosticsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  static const LoopLayoutMode layoutMode = LoopLayoutMode.dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(networkDiagnosticsControllerProvider);
    final controller = ref.read(networkDiagnosticsControllerProvider.notifier);
    final running = state.phase == NetworkDiagnosticsPhase.running;
    final done = state.phase == NetworkDiagnosticsPhase.done;
    final sent = state.results
        .where((result) => result.target.isConfigured)
        .length;
    final heading = switch (state.phase) {
      NetworkDiagnosticsPhase.idle => '未开始',
      NetworkDiagnosticsPhase.running => '诊断中',
      NetworkDiagnosticsPhase.done => '$sent 项中 ${state.okCount} 项可达',
    };

    return LoopDashboardPage(
      key: const ValueKey<String>('network-diagnostics-screen'),
      archetype: LoopPageArchetype.action,
      title: '网络诊断',
      onBack: onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('network-diagnostics-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: 'NETWORK CHECK',
        heading: heading,
        caption: '这个页面只测连通性和耗时，不发送账号信息。',
        // Seconds, one decimal: the stamp upper-cases its text, and a
        // unit in Latin letters would read as 「MS」.
        stamp: state.total == null
            ? null
            : '总耗时 ${(state.total!.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
      ),
      sections: <Widget>[
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('network-diagnostics-start'),
              label: switch (state.phase) {
                NetworkDiagnosticsPhase.idle => '开始诊断',
                NetworkDiagnosticsPhase.running => '正在诊断',
                NetworkDiagnosticsPhase.done => '重新诊断',
              },
              primary: true,
              onPressed: running ? null : () => unawaited(controller.start()),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (state.allSentFailed)
          const LoopNotice(
            key: ValueKey<String>('network-diagnostics-offline'),
            icon: 'offline',
            tone: LoopNoticeTone.warn,
            title: '所有探测都没有连上',
            body: '请先确认这台设备已经联网，再重新诊断。',
          ),
        const LoopLabel('探测项'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (var index = 0; index < state.results.length; index++)
              _row(state.results[index], index, state.results.length),
          ],
        ),
        const LoopProvenanceFooter(text: '每项单独限时 8 秒，全部探测同时发出，最长 15 秒。'),
        const LoopLabel('结果'),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('network-diagnostics-copy'),
              label: '复制诊断结果',
              onPressed: done ? () => unawaited(_copy(context, ref)) : null,
            ),
            LoopButton(
              key: const ValueKey<String>('network-diagnostics-share'),
              label: '分享',
              onPressed: done ? () => unawaited(_share(context, ref)) : null,
            ),
          ],
        ),
        const LoopProvenanceFooter(
          key: ValueKey<String>('network-diagnostics-privacy'),
          text: '结果只留在这台设备上，不会上传；复制或分享由你决定。',
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  LoopRecordRow _row(NetworkProbeResult result, int index, int count) {
    final target = result.target;
    final badgeKind = switch (result.status) {
      NetworkProbeStatus.ok || NetworkProbeStatus.reachable => LoopBadgeKind.up,
      NetworkProbeStatus.timeout ||
      NetworkProbeStatus.failed => LoopBadgeKind.down,
      _ => LoopBadgeKind.mute,
    };
    final detail = result.reason.isEmpty ? target.purpose : result.reason;
    return LoopRecordRow(
      key: ValueKey<String>('network-probe-${target.id}'),
      title: target.name,
      subtitle: '${target.host}\n$detail',
      subtitleMaxLines: 2,
      trailingBadge: LoopBadge(
        networkProbeStatusLabel(result.status),
        key: ValueKey<String>('network-probe-${target.id}-status'),
        kind: badgeKind,
      ),
      trailing: result.elapsed == null
          ? null
          : '${result.elapsed!.inMilliseconds} ms',
      position: count == 1
          ? LoopRowPosition.single
          : index == 0
          ? LoopRowPosition.first
          : index == count - 1
          ? LoopRowPosition.last
          : LoopRowPosition.middle,
    );
  }

  static String reportText(WidgetRef ref) {
    final state = ref.read(networkDiagnosticsControllerProvider);
    final config = ref.read(appConfigProvider);
    final version = config.loopClientVersionForCurrentBuild;
    final declared = config.declaredBuildModeName.isEmpty
        ? '未声明'
        : config.declaredBuildModeName;
    final host = loopBackendHost(config.backendBaseUrl);
    return networkDiagnosticsReport(
      context: NetworkDiagnosticsContext(
        appVersion: version.isEmpty ? '未配置' : version,
        buildMode: '声明 $declared · 运行时 ${loopRuntimeBuildMode()}',
        serverHost: host == null ? '未配置' : '$host（${loopBackendTier(host)}）',
        platform: ref.read(networkDiagnosticsPlatformProvider),
      ),
      results: state.results,
      startedAt: state.startedAt ?? DateTime.now(),
      total: state.total,
    );
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final text = reportText(ref);
    await LoopCopy.text(context, text, message: '诊断结果已复制');
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final text = reportText(ref);
    final shared = await ref.read(networkDiagnosticsShareProvider)(text);
    if (shared || !context.mounted) return;
    LoopToast.show(context, message: '无法打开分享，可以改用复制', kind: LoopToastKind.warn);
  }
}
