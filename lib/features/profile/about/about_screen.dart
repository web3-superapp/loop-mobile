import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/about/about_controller.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
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

    return LoopDashboardPage(
      key: const ValueKey<String>('about-screen'),
      archetype: LoopPageArchetype.record,
      title: '关于',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('about-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'PRODUCT RECORD',
        heading: clientVersion.isEmpty ? 'LOOP' : 'LOOP · $clientVersion',
        caption: '版本与构建号由本机读取；服务端只下发合约版本、规则快照与开源清单。',
        stamp: about == null ? null : 'CONTRACT ${about.contractVersion}',
      ),
      sections: <Widget>[
        const LoopLabel('本机构建'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('about-client-version'),
              title: '客户端版本',
              subtitle: clientVersion.isEmpty
                  ? '构建配置里没有合法的版本号，这里不编造一个'
                  : '由 --dart-define 的构建配置读取，不上传给服务端',
              trailing: clientVersion.isEmpty ? null : clientVersion,
              trailingBadge: clientVersion.isEmpty
                  ? const LoopBadge('未配置')
                  : null,
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('about-build-mode'),
              title: '构建模式',
              subtitle: '声明的构建模式与运行时是否一致',
              trailing: config.declaredModeMatchesRuntime ? '一致' : '不一致',
              position: LoopRowPosition.last,
            ),
          ],
        ),
        if (state.value == null)
          LoopChainStateBlock(
            keyPrefix: 'about',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '读不到服务端的产品记录',
            skeleton: LoopSkeletonType.detail,
            onRetry: () =>
                unawaited(ref.read(aboutControllerProvider.notifier).reload()),
          )
        else ...<Widget>[
          const LoopLabel('法务'),
          _AboutTermsBlock(termsGate: about!.termsGate),
          const LoopLabel('规则快照'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final entry in about.configVersions)
                LoopRecordRow(
                  key: ValueKey<String>('about-config-${entry.module}'),
                  title: entry.module,
                  // The version is long, so it goes on its own line rather
                  // than into the fixed-width value column.
                  subtitle: entry.effectiveAt == null
                      ? entry.configVersion
                      : '${entry.configVersion} · 生效于 '
                            '${loopRelativeTime(entry.effectiveAt!)}',
                  position: LoopRowPosition.middle,
                ),
            ],
          ),
          LoopProvenanceFooter(
            key: const ValueKey<String>('about-config-note'),
            text: '规则快照只用于展示；客户端不会把任何一个版本固定下来。',
          ),
          const LoopLabel('开源许可'),
          LoopNotice(
            key: const ValueKey<String>('about-open-source-summary'),
            icon: 'book',
            title: about.openSource.source,
            body: about.openSource.summary,
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final entry in about.openSource.entries)
                LoopRecordRow(
                  key: ValueKey<String>('about-open-source-${entry.name}'),
                  title: entry.name,
                  subtitle: entry.purpose,
                  trailing: entry.license,
                  position: LoopRowPosition.middle,
                ),
            ],
          ),
          LoopProvenanceFooter(
            key: const ValueKey<String>('about-open-source-note'),
            text: '清单不下发版本号，因此这里不显示任何依赖版本。',
          ),
        ],
        const LoopLabel('风险提示'),
        const LoopNotice(
          key: ValueKey<String>('about-risk-notice'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '加密资产风险',
          body:
              '加密资产价格波动剧烈，可能损失全部本金。LOOP 是非托管工具，不提供投资建议，'
              '不对任何交易结果负责。挖矿产出取决于全网算力竞争，不构成收益承诺。',
        ),
        if (about != null)
          LoopUnavailableCard(
            key: const ValueKey<String>('about-client-build-note'),
            label: '服务端不发布客户端版本',
            reasonCode: about.clientBuildReasonCode,
          ),
        const SizedBox(height: 20),
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
      return LoopUnavailableCard(
        key: const ValueKey<String>('about-terms-unavailable'),
        label: '用户协议、隐私政策与风险披露没有文档地址',
        reasonCode: termsGate.reasonCode,
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('about-terms-version'),
          title: '协议版本',
          subtitle: '服务端已下发版本槽位；文档地址本步仍未下发，所以这里没有可打开的链接。',
          trailing: termsGate.requiredVersion,
        ),
      ],
    );
  }
}
