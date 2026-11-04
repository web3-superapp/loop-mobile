import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/about/about_client_register.dart';
import 'package:loop_mobile/features/profile/about/about_controller.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_screen.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `about` · the public server record plus the locally read client build.
///
/// The server publishes contract and rule-snapshot versions and the
/// open-source register; the version and build number come from this device.
/// The prototype's four legal document links have no URL on the wire, so they
/// render as a version slot with the server's own reason instead.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aboutControllerProvider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(aboutControllerProvider.notifier).load());
        }
      });
    }
    final about = state.value;
    final config = ref.watch(appConfigProvider);
    final clientVersion = config.loopClientVersionForCurrentBuild;

    // Decision 0126: flat sections; the version that the folio printed
    // stays in the 本机构建 row it was already in.
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('about-screen'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.common_aboutSection,
        onBack: widget.onBack,
        // The prototype's order: 法务 first, then the risk disclosure — the one
        // compliance text this page owns. Build and policy rows are this
        // build's own additions and follow (audit 2026-09-21 §J.14).
        sections: <Widget>[
          LoopLabel(context.l10n.profileAbout_screenLoopLabel),
          if (state.value == null)
            LoopChainStateBlock(
              keyPrefix: 'about',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: context.l10n.profileAbout_screenEmptyMessage,
              skeleton: LoopSkeletonType.detail,
              onRetry: () => unawaited(
                ref.read(aboutControllerProvider.notifier).reload(),
              ),
            )
          else
            _AboutTermsBlock(termsGate: about!.termsGate),
          LoopLabel(context.l10n.profileAbout_screenLoopLabel2),
          LoopNotice(
            key: ValueKey<String>('about-risk-notice'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: context.l10n.profileAbout_screenAboutRiskNoticeTitle,
            body: context.l10n.profileAbout_screenAboutRiskNoticeBody,
          ),
          LoopLabel(context.l10n.profileAbout_screenLoopLabel3),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('about-client-version'),
                title: context.l10n.profileAbout_screenAboutClientVersionTitle,
                subtitle: clientVersion.isEmpty
                    ? context.l10n.profileAbout_screenAboutClientVersionSubtitle
                    : context
                          .l10n
                          .profileAbout_screenAboutClientVersionSubtitle2,
                trailing: clientVersion.isEmpty ? null : clientVersion,
                trailingBadge: clientVersion.isEmpty
                    ? LoopBadge(context.l10n.common_notConfigured)
                    : null,
                position: LoopRowPosition.first,
              ),
              // S237 · decision 0204: 服务端（环境标签与主机名）and 构建模式
              // moved to 网络诊断, behind the test-hints switch.
              LoopRecordRow(
                key: const ValueKey<String>('about-network-diagnostics'),
                title: context
                    .l10n
                    .profileAbout_screenAboutNetworkDiagnosticsTitle,
                // Decision 0102: a pushed child page, not one of the 93 routes.
                subtitle: context
                    .l10n
                    .profileAbout_screenAboutNetworkDiagnosticsSubtitle,
                onTap: () => unawaited(openNetworkDiagnostics(context)),
                position: LoopRowPosition.last,
              ),
            ],
          ),
          if (about != null) ...<Widget>[
            LoopLabel(context.l10n.profileAbout_screenLoopLabel4),
            _AboutRulesBlock(versions: about.configVersions),
            LoopProvenanceFooter(
              key: const ValueKey<String>('about-config-note'),
              label: context.l10n.common_about,
              title: context.l10n.common_about,
              text: context.l10n.profileAbout_screenAboutConfigNoteText,
            ),
          ],
          // S278 · decision 0236: the summary card and the closing note are
          // the (i) beside the section title.
          LoopInfoLabel(
            context.l10n.profileAbout_screenAboutOpenSourceInfo,
            info: LoopInfoButton(
              key: ValueKey<String>('about-open-source-info'),
              title: context.l10n.profileAbout_screenAboutOpenSourceInfoTitle,
              sheetKey: 'about-open-source-info-sheet',
              notes: <LoopInfoNote>[
                LoopInfoNote(
                  key: ValueKey<String>('about-open-source-summary'),
                  body: context
                      .l10n
                      .profileAbout_screenAboutOpenSourceSummaryBody,
                ),
                LoopInfoNote(
                  key: ValueKey<String>('about-open-source-note'),
                  body: context.l10n.profileAbout_screenAboutOpenSourceNoteBody,
                ),
              ],
            ),
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final entry in loopClientOpenSourceEntries)
                LoopRecordRow(
                  key: ValueKey<String>('about-open-source-${entry.name}'),
                  title: entry.name,
                  // The licence rides in the subtitle rather than the value
                  // column: a vendor agreement's name is wider than that column
                  // and would be cut, and the licence is the point of the row.
                  subtitle: '${entry.purpose} · ${entry.license}',
                  subtitleMaxLines: 2,
                  position: LoopRowPosition.middle,
                ),
            ],
          ),
          if (about != null)
            LoopUnavailableLine(
              key: const ValueKey<String>('about-client-build-note'),
              label: context.l10n.profileAbout_screenAboutClientBuildNoteLabel,
              reasonCode: about.clientBuildReasonCode,
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// 当前规则 · the published rule snapshots, named in the reader's language.
///
/// The server sends its own keys and decides how many rows there are: a
/// deployment without an operator override publishes no `clientPolicy`, and
/// one with chain writes off publishes no `bscWriteCanary` (decision 0049).
/// Every row the server sends is listed, but never under its key — a rule this
/// client cannot translate is listed as 其他规则 with its version, which is the
/// part a reader can compare, and the identifier stays off the screen.
class _AboutRulesBlock extends StatelessWidget {
  const _AboutRulesBlock({required this.versions});

  final List<LoopAboutConfigVersion> versions;

  @override
  Widget build(BuildContext context) {
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (final entry in versions)
          LoopRecordRow(
            key: ValueKey<String>('about-config-${entry.module}'),
            title:
                loopAboutModuleName(entry.module) ?? loopAboutUnknownModuleName,
            // The description reads on its own line; the snapshot version and
            // the time it took effect follow on the second, so neither is
            // ellipsised away.
            subtitle: <String>[
              ?loopAboutModuleDescription(entry.module),
              <String>[
                context.l10n.profileAbout_screenLoopRecordRow(
                  entry.configVersion,
                ),
                if (entry.effectiveAt != null)
                  context.l10n.profileAbout_screenLoopRecordRow2(
                    loopRelativeTime(entry.effectiveAt!),
                  ),
              ].join(' · '),
            ].join('\n'),
            subtitleMaxLines: 2,
            position: LoopRowPosition.middle,
          ),
      ],
    );
  }
}

class _AboutTermsBlock extends StatelessWidget {
  const _AboutTermsBlock({required this.termsGate});

  final LoopAboutTermsGate termsGate;

  @override
  Widget build(BuildContext context) {
    if (!termsGate.isAvailable) {
      return LoopUnavailableLine(
        key: const ValueKey<String>('about-terms-unavailable'),
        label: context.l10n.profileAbout_screenAboutTermsUnavailableLabel,
        reasonCode: termsGate.reasonCode,
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('about-terms-version'),
          title: context.l10n.profileAbout_screenAboutTermsVersionTitle,
          subtitle: context.l10n.profileAbout_screenAboutTermsVersionSubtitle,
          trailing: termsGate.requiredVersion,
        ),
      ],
    );
  }
}
