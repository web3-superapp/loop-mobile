import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_backend_identity.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_controller.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_models.dart';
import 'package:loop_mobile/integrations/diagnostics/loop_network_probe.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
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
      NetworkDiagnosticsPhase.idle =>
        context.l10n.profileAbout_networkDiagnosticsModelsIdle,
      NetworkDiagnosticsPhase.running =>
        context.l10n.profileAbout_networkDiagnosticsRunning,
      NetworkDiagnosticsPhase.done =>
        context.l10n.profileAbout_networkDiagnosticsDone(state.okCount, sent),
    };

    return LoopDashboardPage(
      key: const ValueKey<String>('network-diagnostics-screen'),
      archetype: LoopPageArchetype.action,
      title: context.l10n.profileAbout_screenAboutNetworkDiagnosticsTitle,
      onBack: onBack,
      primary: LoopFolioPrimary(
        ring: false,
        key: const ValueKey<String>('network-diagnostics-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: context
            .l10n
            .profileAbout_networkDiagnosticsNetworkDiagnosticsFolioKicker,
        heading: heading,
        caption: context
            .l10n
            .profileAbout_networkDiagnosticsNetworkDiagnosticsFolioCaption,
        // Seconds, one decimal: the stamp upper-cases its text, and a
        // unit in Latin letters would read as 「MS」.
        stamp: state.total == null
            ? null
            : context.l10n
                  .profileAbout_networkDiagnosticsNetworkDiagnosticsFolioStamp(
                    (state.total!.inMilliseconds / 1000).toStringAsFixed(1),
                  ),
      ),
      sections: <Widget>[
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('network-diagnostics-start'),
              label: switch (state.phase) {
                NetworkDiagnosticsPhase.idle =>
                  context.l10n.profileAbout_networkDiagnosticsIdle,
                NetworkDiagnosticsPhase.running =>
                  context.l10n.profileAbout_networkDiagnosticsRunning2,
                NetworkDiagnosticsPhase.done =>
                  context.l10n.profileAbout_networkDiagnosticsDone2,
              },
              primary: true,
              onPressed: running ? null : () => unawaited(controller.start()),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (state.allSentFailed)
          LoopNotice(
            key: ValueKey<String>('network-diagnostics-offline'),
            icon: 'offline',
            tone: LoopNoticeTone.warn,
            title: context
                .l10n
                .profileAbout_networkDiagnosticsNetworkDiagnosticsOfflineTitle,
            body: context
                .l10n
                .profileAbout_networkDiagnosticsNetworkDiagnosticsOfflineBody,
          ),
        // S237 · decision 0204: the build's backend (with its DEV / STAGING
        // tier and host name) and build mode, moved here from 关于 and
        // drawn only while the test-hints switch is on.
        if (loopTestHintsVisible) ..._buildRows(ref),
        LoopLabel(context.l10n.profileAbout_networkDiagnosticsLoopLabel),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (var index = 0; index < state.results.length; index++)
              _row(state.results[index], index, state.results.length),
          ],
        ),
        LoopProvenanceFooter(
          label: context.l10n.common_about,
          title: context.l10n.profileAbout_networkDiagnosticsTitle,
          text: context.l10n.profileAbout_networkDiagnosticsText,
        ),
        LoopLabel(context.l10n.profileAbout_networkDiagnosticsLoopLabel2),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('network-diagnostics-copy'),
              label: context
                  .l10n
                  .profileAbout_networkDiagnosticsNetworkDiagnosticsCopyLabel,
              onPressed: done ? () => unawaited(_copy(context, ref)) : null,
            ),
            LoopButton(
              key: const ValueKey<String>('network-diagnostics-share'),
              label: context.l10n.common_share,
              onPressed: done ? () => unawaited(_share(context, ref)) : null,
            ),
          ],
        ),
        LoopProvenanceFooter(
          key: ValueKey<String>('network-diagnostics-privacy'),
          label: context.l10n.common_about,
          title: context
              .l10n
              .profileAbout_networkDiagnosticsNetworkDiagnosticsPrivacyTitle,
          text: context
              .l10n
              .profileAbout_networkDiagnosticsNetworkDiagnosticsPrivacyText,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _buildRows(WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final backendHost = loopBackendHost(config.backendBaseUrl);
    final declaredMode = config.declaredBuildModeName.isEmpty
        ? LoopL10n.current.profileAbout_networkDiagnosticsBuildRows
        : config.declaredBuildModeName;
    return <Widget>[
      LoopLabel(LoopL10n.current.profileAbout_screenLoopLabel3),
      LoopRecordGroup(
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('about-backend-host'),
            title: LoopL10n
                .current
                .profileAbout_networkDiagnosticsAboutBackendHostTitle,
            // Decision 0100: which backend this build was pointed at, read
            // from the build configuration; no request is made for it.
            subtitle: backendHost == null
                ? LoopL10n
                      .current
                      .profileAbout_networkDiagnosticsAboutBackendHostSubtitle
                : LoopL10n.current
                      .profileAbout_networkDiagnosticsAboutBackendHostSubtitle2(
                        loopBackendTier(backendHost),
                      ),
            trailing: backendHost,
            trailingBadge: backendHost == null
                ? LoopBadge(LoopL10n.current.common_notConfigured)
                : null,
            position: LoopRowPosition.first,
          ),
          LoopRecordRow(
            key: const ValueKey<String>('about-build-mode'),
            title: LoopL10n
                .current
                .profileAbout_networkDiagnosticsAboutBuildModeTitle,
            subtitle: LoopL10n.current
                .profileAbout_networkDiagnosticsAboutBuildModeSubtitle(
                  config.declaredModeMatchesRuntime
                      ? LoopL10n
                            .current
                            .profileAbout_networkDiagnosticsModeMatch
                      : LoopL10n
                            .current
                            .profileAbout_networkDiagnosticsModeMismatch,
                  declaredMode,
                  loopRuntimeBuildMode(),
                ),
            trailing: declaredMode,
            position: LoopRowPosition.last,
          ),
        ],
      ),
    ];
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
      // Decision 0204: a host such as api-staging.… is a test hint; with the
      // switch off the row says what the probe is for, not where it went.
      subtitle: loopTestHintsVisible ? '${target.host}\n$detail' : detail,
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
        ? LoopL10n.current.profileAbout_networkDiagnosticsBuildRows
        : config.declaredBuildModeName;
    final host = loopBackendHost(config.backendBaseUrl);
    return networkDiagnosticsReport(
      context: NetworkDiagnosticsContext(
        appVersion: version.isEmpty
            ? LoopL10n.current.common_notConfigured
            : version,
        buildMode: LoopL10n.current.profileAbout_networkDiagnosticsBuildMode(
          declared,
          loopRuntimeBuildMode(),
        ),
        serverHost: host == null
            ? LoopL10n.current.common_notConfigured
            : loopTestHintsVisible
            ? LoopL10n.current.profileAbout_networkDiagnosticsHostTier(
                host,
                loopBackendTier(host),
              )
            : host,
        platform: ref.read(networkDiagnosticsPlatformProvider),
      ),
      results: state.results,
      startedAt: state.startedAt ?? DateTime.now(),
      total: state.total,
    );
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final text = reportText(ref);
    await LoopCopy.text(
      context,
      text,
      message: context.l10n.profileAbout_networkDiagnosticsMessage,
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final text = reportText(ref);
    final shared = await ref.read(networkDiagnosticsShareProvider)(text);
    if (shared || !context.mounted) return;
    LoopToast.show(
      context,
      message: context.l10n.profileAbout_networkDiagnosticsMessage2,
      kind: LoopToastKind.warn,
    );
  }
}
