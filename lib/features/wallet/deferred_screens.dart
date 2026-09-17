import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/security/loop_url_review.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The four D21 surfaces: `pay`, `bridge`, `bridge-status` and `dapp`.
///
/// Each one exists as an entry point and states the server's own deferred
/// reason. None of them holds an amount, a route, a fee, a progress source or
/// an executable action, and none of them is backed by a preview fixture.

String _reasonFor(LoopCapabilityProjection capability, String fallback) =>
    capability.reasonCode ?? fallback;

/// `pay` · reached from Wallet. `PAY_RUNTIME_DEFERRED`.
class PayScreen extends ConsumerWidget {
  const PayScreen({super.key, this.onBack});

  static const deferredReasonCode = 'PAY_RUNTIME_DEFERRED';

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.pay),
    );
    return LoopDashboardPage(
      key: const ValueKey<String>('pay-screen'),
      archetype: LoopPageArchetype.listing,
      title: 'Pay',
      onBack: onBack,
      primary: const LoopFolioPrimary(
        key: ValueKey<String>('pay-folio'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        kicker: 'SCAN TO PAY',
        heading: '扫码支付尚未开放',
        caption: '扫码支付还没有开放，这里不会打开相机，也不会生成收款码。',
      ),
      sections: <Widget>[
        LoopUnavailableCard(
          key: const ValueKey<String>('pay-unavailable'),
          label: 'Pay 尚未开放',
          reasonCode: _reasonFor(capability, deferredReasonCode),
        ),
        const LoopNotice(
          key: ValueKey<String>('pay-why-notice'),
          icon: 'info',
          title: '为什么现在不做',
          body: '支付涉及合规与支付商准入，需要独立评估。先把社区、挖矿与 Launch 的闭环跑通。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
        const LoopNotice(
          key: ValueKey<String>('pay-signing-notice'),
          icon: 'shield',
          title: '扫码不会直接发起签名',
          body: '即使这个能力开放，识别结果也只会先展示金额、网络与收款方，再进入统一签名出口。',
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// `bridge` · `BRIDGE_RUNTIME_DEFERRED`. No amount input and no route.
class BridgeScreen extends ConsumerWidget {
  const BridgeScreen({super.key, this.onBack, this.onOpenStatus});

  static const deferredReasonCode = 'BRIDGE_RUNTIME_DEFERRED';

  final VoidCallback? onBack;
  final VoidCallback? onOpenStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.bridge),
    );
    return LoopDashboardPage(
      key: const ValueKey<String>('bridge-screen'),
      archetype: LoopPageArchetype.action,
      title: '跨链',
      onBack: onBack,
      primary: const LoopFolioPrimary(
        key: ValueKey<String>('bridge-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: 'BRIDGE INTENT',
        heading: '跨链尚未开放',
        caption: '跨链还没有开放，这里不显示来源链、目标链、数量、费用与到账时间。',
      ),
      sections: <Widget>[
        LoopUnavailableCard(
          key: const ValueKey<String>('bridge-unavailable'),
          label: '跨链尚未开放',
          reasonCode: _reasonFor(capability, deferredReasonCode),
        ),
        const LoopNotice(
          key: ValueKey<String>('bridge-scope-notice'),
          icon: 'info',
          title: '这里不会出现预估数字',
          body:
              '跨链费、到账数量与预计时间只能由真实路由给出。没有路由就没有这些数字，'
              '这一页不会用示例数据代替它们。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
        if (onOpenStatus != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('bridge-open-status'),
              label: '查看跨链进度',
              block: true,
              onPressed: onOpenStatus,
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// `bridge-status` · one whole-page state, because there is no progress.
///
/// The page used to carry a folio heading, an unavailable card, three step
/// rows badged 等待 and a footnote — and then most of a screen of black under
/// them (C-19). None of the three steps is observed by anybody: nothing is
/// transferring, so 等待 was a state the page invented for a run that does not
/// exist, and the heading above it could only repeat the card below it. The
/// whole page is the server's one reason, centred in the space the page owns,
/// with the only next step that leads anywhere.
class BridgeStatusScreen extends ConsumerWidget {
  const BridgeStatusScreen({super.key, this.onBack, this.onOpenWallet});

  static const deferredReasonCode = 'BRIDGE_RUNTIME_DEFERRED';

  final VoidCallback? onBack;
  final VoidCallback? onOpenWallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.bridge),
    );
    return LoopDashboardPage(
      key: const ValueKey<String>('bridge-status-screen'),
      archetype: LoopPageArchetype.state,
      title: '跨链进度',
      onBack: onBack,
      // Replaced by the block below; the page has no primary region of its
      // own because it has no reading to head.
      primary: const SizedBox.shrink(),
      block: LoopPageBlock(
        key: const ValueKey<String>('bridge-status-page-block'),
        // 读不到 would say LOOP tried and failed. Nothing was tried, because
        // bridging has not been built.
        title: '跨链进度尚未开放',
        message: loopReasonCodeText(_reasonFor(capability, deferredReasonCode)),
        action: onOpenWallet == null
            ? null
            : LoopButton(
                key: const ValueKey<String>('bridge-status-back-to-wallet'),
                label: '返回钱包',
                onPressed: onOpenWallet,
              ),
      ),
      sections: const <Widget>[],
    );
  }
}

/// `dapp` · local, offline URL review. Connecting and signing stay disabled.
class DappReviewScreen extends ConsumerStatefulWidget {
  const DappReviewScreen({super.key, this.onBack});

  static const deferredReasonCode = 'DAPP_EXECUTION_RUNTIME_DEFERRED';
  static const reputationReasonCode = 'DAPP_REPUTATION_PROVIDER_NOT_CONFIGURED';

  final VoidCallback? onBack;

  @override
  ConsumerState<DappReviewScreen> createState() => _DappReviewScreenState();
}

class _DappReviewScreenState extends ConsumerState<DappReviewScreen> {
  final TextEditingController _address = TextEditingController();
  LoopUrlReview _review = LoopUrlReview.review('');

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _review = LoopUrlReview.review(value));
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.dappExecution),
    );
    final typed = _address.text.trim();
    final review = _review;

    return LoopDashboardPage(
      key: const ValueKey<String>('dapp-screen'),
      archetype: LoopPageArchetype.action,
      title: 'DApp 核对',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('dapp-folio'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.action,
        kicker: 'DAPP REVIEW · READ ONLY',
        heading: switch (review.verdict) {
          LoopUrlVerdict.normalized => review.host!,
          LoopUrlVerdict.flagged => review.host!,
          LoopUrlVerdict.blocked => typed.isEmpty ? '输入一个网址' : '这个网址不能使用',
        },
        caption: '核对完全在本机完成：不会打开这个网址，不会跟随跳转，也不会连接钱包。',
      ),
      sections: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const ValueKey<String>('dapp-address-field'),
            controller: _address,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: '输入网址，例如 app.example.org',
            ),
          ),
        ),
        const LoopLabel('本地核对'),
        if (typed.isEmpty)
          const LoopEmpty(
            key: ValueKey<String>('dapp-review-empty'),
            message: '还没有可核对的网址',
            reason: '输入网址后，这里会显示规范化结果与发现的问题。',
          )
        else ...<Widget>[
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('dapp-review-typed'),
                title: '你输入的',
                subtitle: review.input,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('dapp-review-canonical'),
                title: '规范化结果',
                subtitle: review.canonical?.toString() ?? '无法规范化，已阻止',
                trailingBadge: LoopBadge(
                  switch (review.verdict) {
                    LoopUrlVerdict.normalized => '可读',
                    LoopUrlVerdict.flagged => '需注意',
                    LoopUrlVerdict.blocked => '已阻止',
                  },
                  kind: switch (review.verdict) {
                    LoopUrlVerdict.normalized => LoopBadgeKind.up,
                    LoopUrlVerdict.flagged => LoopBadgeKind.mining,
                    LoopUrlVerdict.blocked => LoopBadgeKind.mute,
                  },
                ),
                position: LoopRowPosition.last,
              ),
            ],
          ),
          if (review.confusableReading != null)
            LoopNotice(
              key: const ValueKey<String>('dapp-confusable-notice'),
              icon: 'phishing',
              tone: LoopNoticeTone.danger,
              title: '这个域名在冒充另一个域名',
              body:
                  '它看起来像 ${review.confusableReading}，但其中有不是拉丁字母的同形字符。'
                  '这是最常见的钓鱼手法，已阻止。',
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            ),
          const LoopLabel('发现'),
          if (review.findings.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('dapp-findings-empty'),
              icon: 'check',
              message: '没有发现问题',
              reason: '这只说明地址本身规范；它不代表这个站点可信。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final finding in review.findings)
                  LoopRecordRow(
                    key: ValueKey<String>('dapp-finding-${finding.name}'),
                    title: finding.explanation,
                    subtitle: finding.isBlocking ? '阻止' : '提示',
                    trailingBadge: LoopBadge(
                      finding.isBlocking ? '阻止' : '提示',
                      kind: finding.isBlocking
                          ? LoopBadgeKind.mute
                          : LoopBadgeKind.mining,
                    ),
                    position: LoopRowPosition.middle,
                  ),
              ],
            ),
        ],
        const LoopLabel('域名信誉'),
        // With no address typed there is nothing to look up: 「读不到」 named a
        // failed read that never happened. The unavailable card is for a
        // domain that exists and has no reputation to show.
        if (typed.isEmpty)
          const LoopEmpty(
            key: ValueKey<String>('dapp-reputation-empty'),
            message: '还没有可查询的域名',
            reason: '输入网址后再核对；这一项不会凭空给出结论。',
          )
        else
          const LoopUnavailableCard(
            key: ValueKey<String>('dapp-reputation-unavailable'),
            label: '读不到域名信誉',
            reasonCode: DappReviewScreen.reputationReasonCode,
          ),
        const LoopLabel('连接与签名'),
        LoopUnavailableCard(
          key: const ValueKey<String>('dapp-execution-unavailable'),
          label: '连接钱包与签名尚未开放',
          reasonCode: _reasonFor(
            capability,
            DappReviewScreen.deferredReasonCode,
          ),
        ),
        // 连接钱包 and 签名请求 used to stand here as two dead buttons, and
        // the signing one was painted as the page's primary action. A tap got
        // nothing back, because there is nothing behind either of them: the
        // card above already states that connecting and signing are not open.
        // An action that cannot run is not offered as a button.
        const LoopNotice(
          key: ValueKey<String>('dapp-no-fetch-notice'),
          icon: 'shield',
          title: '这一页不会打开网址',
          body:
              '核对是纯本地计算：没有请求、没有 DNS 解析，也不会跟随任何跳转，'
              '所以你看到的域名一定是你输入的那个。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
