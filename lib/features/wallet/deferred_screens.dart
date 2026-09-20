import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/security/loop_url_review.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
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
      // Chalk primary with the CAMERA stamp, as the prototype has it. A
      // deferred capability is still a page with a shape (audit §A.14).
      primary: const LoopFolioPrimary(
        key: ValueKey<String>('pay-folio'),
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.listing,
        kicker: 'SCAN TO PAY',
        heading: '扫码支付',
        caption: '识别结果不会直接发起签名；金额、网络与收款方会再次展示。',
        stamp: 'CAMERA',
      ),
      sections: <Widget>[
        // The prototype keeps the viewfinder's room, with the reason in it.
        LoopPlaceholderStage(
          key: const ValueKey<String>('pay-unavailable'),
          icon: 'camera',
          title: 'Pay',
          badge: 'Coming soon',
          body: loopReasonCodeText(_reasonFor(capability, deferredReasonCode)),
        ),
        const LoopNotice(
          key: ValueKey<String>('pay-why-notice'),
          icon: 'info',
          title: '为什么现在不做',
          body: '支付涉及合规与支付商准入，需要独立评估。先把社区、挖矿与 Launch 的闭环跑通。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        caption: '先选来源链、目标链与数量，再显示预计费用和到账时间。',
        stamp: 'REVIEW',
      ),
      sections: <Widget>[
        // The prototype's 从 / 到 boxes keep their room. Each figure is a
        // dash: a bridge fee, a receive amount and an ETA can only come from a
        // real route, and there is none.
        const LoopFigureBox(
          key: ValueKey<String>('bridge-from'),
          caption: '从',
          figure: loopFigureDash,
        ),
        const LoopFigureBox(
          key: ValueKey<String>('bridge-to'),
          caption: '到',
          figure: loopFigureDash,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: LoopButton(
            key: const ValueKey<String>('bridge-start'),
            label: '开始跨链',
            primary: true,
            block: true,
            // Disabled, with the shape the prototype gives the action.
            onPressed: null,
          ),
        ),
        LoopUnavailableCard(
          key: const ValueKey<String>('bridge-unavailable'),
          label: '跨链尚未开放',
          reasonCode: _reasonFor(capability, deferredReasonCode),
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
        const LoopNotice(
          key: ValueKey<String>('bridge-scope-notice'),
          icon: 'info',
          title: '这里不会出现预估数字',
          body:
              '跨链费、到账数量与预计时间只能由真实路由给出。没有路由就没有这些数字，'
              '这一页不会用示例数据代替它们。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
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
      primary: const LoopFolioPrimary(
        key: ValueKey<String>('bridge-status-folio'),
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.state,
        kicker: 'BRIDGE PROGRESS',
        heading: '跨链进度尚未开放',
        caption: '源链确认、桥接中和目标链到账是三个独立状态。',
        stamp: 'NOT OPEN',
      ),
      sections: <Widget>[
        // The prototype's 步骤 group keeps its heading. Its three rows do not
        // appear: nothing is in flight, so 完成 / 进行中 / 等待 would be three
        // states this page invented for a transfer that does not exist. The
        // group states the one fact there is.
        const LoopLabel('步骤'),
        LoopEmpty(
          key: const ValueKey<String>('bridge-status-page-block'),
          icon: 'warn',
          // 读不到 would say LOOP tried and failed. Nothing was tried,
          // because bridging has not been built.
          message: '还没有可跟踪的跨链',
          reason: loopReasonCodeText(
            _reasonFor(capability, deferredReasonCode),
          ),
        ),
        if (onOpenWallet != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: LoopButton(
              key: const ValueKey<String>('bridge-status-back-to-wallet'),
              label: '返回钱包',
              block: true,
              onPressed: onOpenWallet,
            ),
          ),
        const LoopNotice(
          key: ValueKey<String>('bridge-status-leave-notice'),
          icon: 'info',
          title: '可以离开此页',
          body: '跨链开放后会在后台继续，完成后推送通知，也可以从交易历史查看。',
        ),
        const SizedBox(height: 20),
      ],
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
      // The prototype puts the address bar at the top of the page, where a
      // browser puts it, and the Chalk review card under it (audit §A.9).
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopOmnibox(
            key: const ValueKey<String>('dapp-omnibox'),
            fieldKey: const ValueKey<String>('dapp-address-field'),
            controller: _address,
            hintText: '搜索资产 / 社区 / 用户 / Launch / DApp / 网址',
            trailingKey: 'GLOBAL',
            onChanged: _onChanged,
          ),
          LoopFolioPrimary(
            key: const ValueKey<String>('dapp-folio'),
            variant: LoopFolioVariant.chalk,
            archetype: LoopFolioArchetype.action,
            kicker: 'DAPP REVIEW · READ ONLY',
            heading: switch (review.verdict) {
              LoopUrlVerdict.normalized => review.host!,
              LoopUrlVerdict.flagged => review.host!,
              LoopUrlVerdict.blocked =>
                typed.isEmpty ? '还没有可核对的网址' : '这个网址不能使用',
            },
            caption: '核对完全在本机完成：不会打开这个网址，不会跟随跳转，也不会连接钱包。',
            stamp: switch (review.verdict) {
              LoopUrlVerdict.normalized => 'EXACT ORIGIN',
              LoopUrlVerdict.flagged => 'CHECK ORIGIN',
              LoopUrlVerdict.blocked => typed.isEmpty ? null : 'BLOCKED',
            },
          ),
        ],
      ),
      sections: <Widget>[
        // The prototype's chip row. It carries only what this page knows
        // without asking anybody: the origin it normalised and the one chain
        // the product is bound to. Gas price and open-approval counts are two
        // more reads, and this page makes none.
        if (review.canonical != null)
          LoopChipRow(
            key: const ValueKey<String>('dapp-chips'),
            children: <Widget>[
              LoopBadge(review.host!),
              LoopBadge(loopChainName(loopPrimaryChainId)),
              LoopBadge(
                switch (review.verdict) {
                  LoopUrlVerdict.normalized => '规范化完成',
                  LoopUrlVerdict.flagged => '需注意',
                  LoopUrlVerdict.blocked => '已阻止',
                },
                kind: switch (review.verdict) {
                  LoopUrlVerdict.normalized => LoopBadgeKind.up,
                  LoopUrlVerdict.flagged => LoopBadgeKind.mining,
                  LoopUrlVerdict.blocked => LoopBadgeKind.mute,
                },
              ),
            ],
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
        const LoopDisclosure(
          key: ValueKey<String>('dapp-scope-disclosure'),
          summary: '这一页不会打开网址',
          child: LoopNotice(
            key: ValueKey<String>('dapp-no-fetch-notice'),
            icon: 'shield',
            title: '这一页不会打开网址',
            body:
                '核对是纯本地计算：没有请求、没有 DNS 解析，也不会跟随任何跳转，'
                '所以你看到的域名一定是你输入的那个。',
            margin: EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
