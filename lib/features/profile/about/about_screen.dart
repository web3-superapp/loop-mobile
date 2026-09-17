import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/about/about_client_register.dart';
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
        caption: '版本与构建号来自这台设备；协议版本、规则与开源清单由 LOOP 提供。',
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
                  : '来自这台设备的构建配置，不会上传',
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
            emptyMessage: '暂时读不到产品记录',
            skeleton: LoopSkeletonType.detail,
            onRetry: () =>
                unawaited(ref.read(aboutControllerProvider.notifier).reload()),
          )
        else ...<Widget>[
          const LoopLabel('法务'),
          _AboutTermsBlock(termsGate: about!.termsGate),
          const LoopLabel('当前规则'),
          _AboutRulesBlock(versions: about.configVersions),
          LoopProvenanceFooter(
            key: const ValueKey<String>('about-config-note'),
            text: '这里只用于查看，不会固定任何一个版本。',
          ),
        ],
        const LoopLabel('开源许可'),
        const LoopNotice(
          key: ValueKey<String>('about-open-source-summary'),
          icon: 'book',
          title: '本应用使用的开源组件',
          body:
              '下面是 LOOP 手机客户端直接依赖的开源组件与它们各自的许可；'
              '精确版本由这次构建的锁定文件记录。LOOP 服务端使用的组件不在这一页。',
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
        const LoopProvenanceFooter(
          key: ValueKey<String>('about-open-source-note'),
          text: '组件版本以本次构建的锁定文件为准，这一页不显示版本号。',
        ),
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
            label: 'LOOP 不发布客户端版本',
            reasonCode: about.clientBuildReasonCode,
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// 当前规则 · the published rule snapshots, named in the reader's language.
///
/// The server sends its own keys. Only the rules this client can name are
/// listed: an unknown key is an internal identifier, and `bscWriteCanary` is
/// the staged-rollout switch of a mechanism that has not been announced.
class _AboutRulesBlock extends StatelessWidget {
  const _AboutRulesBlock({required this.versions});

  final List<LoopAboutConfigVersion> versions;

  @override
  Widget build(BuildContext context) {
    final named = <(LoopAboutConfigVersion, String)>[
      for (final entry in versions)
        if (loopAboutModuleName(entry.module) case final String name)
          (entry, name),
    ];
    if (named.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('about-config-empty'),
        icon: 'info',
        message: '没有可以展示的规则',
        reason: '这次下发的规则都还没有对外的名字。',
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (final (entry, name) in named)
          LoopRecordRow(
            key: ValueKey<String>('about-config-${entry.module}'),
            title: name,
            // The description reads on its own line; the snapshot version and
            // the time it took effect follow on the second, so neither is
            // ellipsised away.
            subtitle: <String>[
              ?loopAboutModuleDescription(entry.module),
              <String>[
                '版本 ${entry.configVersion}',
                if (entry.effectiveAt != null)
                  '生效于 ${loopRelativeTime(entry.effectiveAt!)}',
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
          subtitle: '已经有版本号，但还没有可打开的文档链接。',
          trailing: termsGate.requiredVersion,
        ),
      ],
    );
  }
}
