import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

/// Development Preview showcase fixtures for `token-card-states` and
/// `sign-sheet-states` (values from the frozen prototype `FX`). Only
/// `lib/main_preview.dart` may inject this; production never constructs it.
LoopSystemShowcase buildLoopSystemShowcasePreview() {
  return LoopSystemShowcase(
    sourceLabel: '演示数据 · 开发预览',
    tokenCards: <LoopTokenCardShowcaseItem>[
      LoopTokenCardShowcaseItem(
        label: '态 1 · 正常',
        state: LoopTokenCardState.normal,
        model: const LoopTokenCardModel(
          symbol: 'PEPE',
          identifier: '0x6982…1933',
          price: r'$0.000013',
          change: '+4.8%',
          changeUp: true,
          metrics: <LoopTokenMetric>[
            LoopTokenMetric('市值', r'$5.4B'),
            LoopTokenMetric('流动性', r'$42.8M'),
            LoopTokenMetric('持有人', '418K'),
          ],
          communityLine: 'LOOP 社区 128K 成员 · 0.35×',
          chartRangeLabel: '1H · 固定演示',
        ),
        actions: const <LoopTokenCardAction>[
          LoopTokenCardAction('买入', buy: true),
          LoopTokenCardAction('卖出'),
          LoopTokenCardAction('图表'),
          LoopTokenCardAction('社区'),
        ],
      ),
      const LoopTokenCardShowcaseItem(
        label: '态 2 · 识别中',
        state: LoopTokenCardState.loading,
        model: LoopTokenCardModel(
          symbol: 'PEPE',
          identifier: '0x6982...1933',
          metrics: <LoopTokenMetric>[
            LoopTokenMetric('市值', '等待数据'),
            LoopTokenMetric('流动性', '等待数据'),
            LoopTokenMetric('持有人', '等待数据'),
          ],
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction('买入', buy: true),
          LoopTokenCardAction('图表'),
          LoopTokenCardAction('社区'),
        ],
      ),
      const LoopTokenCardShowcaseItem(
        label: '态 3 · 已毕业（LOOP Launch 资产）',
        state: LoopTokenCardState.graduated,
        model: LoopTokenCardModel(
          symbol: 'BONEZ',
          identifier: '...9B2ELOOP',
          price: r'$0.0024',
          change: '+712%',
          changeUp: true,
          badge: 'GRADUATED',
          metrics: <LoopTokenMetric>[
            LoopTokenMetric('市值', r'$2.4M'),
            LoopTokenMetric('流动性', r'$412K', accent: true),
            LoopTokenMetric('持有人', '4,120'),
          ],
          communityIcon: 'graduate',
          communityLine: '08-22 毕业 · 外盘流动性已建立',
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction('买入', buy: true),
          LoopTokenCardAction('卖出'),
          LoopTokenCardAction('毕业详情'),
        ],
      ),
      const LoopTokenCardShowcaseItem(
        label: '态 4 · 数据缺失',
        state: LoopTokenCardState.partial,
        model: LoopTokenCardModel(
          symbol: 'UNKNOWN',
          identifier: '0x9c4b...7f82',
          price: r'$0.000004',
          metrics: <LoopTokenMetric>[
            LoopTokenMetric('市值', '数据不可得'),
            LoopTokenMetric('流动性', '数据不可得'),
            LoopTokenMetric('持有人', '数据不可得'),
          ],
          communityIcon: 'info',
          communityLine: '该代币未加入 LOOP 社区，无 Mining Weight',
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction('查看合约'),
          LoopTokenCardAction('交易不可用'),
        ],
      ),
      const LoopTokenCardShowcaseItem(
        label: '态 5 · 风险事实红条',
        state: LoopTokenCardState.risk,
        model: LoopTokenCardModel(
          symbol: 'PEPE',
          identifier: '0x3f8a...2b91',
          price: r'$0.0000079',
          change: '+842%',
          changeUp: true,
          riskFacts: <LoopTokenRiskFact>[
            LoopTokenRiskFact(
              fact: '该合约含 mint 函数，发行方可增发',
              source: 'GoPlus',
              observedLabel: '2 分钟前',
            ),
            LoopTokenRiskFact(
              fact: '合约地址与 PEPE 官方不一致',
              source: '链上比对',
              observedLabel: '2 分钟前',
            ),
          ],
          metrics: <LoopTokenMetric>[
            LoopTokenMetric('市值', r'$142K'),
            LoopTokenMetric('流动性', r'$8,200'),
            LoopTokenMetric('持有人', '84'),
          ],
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction('确认事实后买入', buy: true),
          LoopTokenCardAction('查看全部事实'),
          LoopTokenCardAction('举报'),
        ],
      ),
    ],
    signSheets: const <LoopSignSheetShowcaseItem>[
      LoopSignSheetShowcaseItem(
        label: '态 1 · 待确认（正常）',
        state: LoopSignSheetState.pending,
        facts: <LoopSignFact>[
          LoopSignFact('操作', 'Swap'),
          LoopSignFact('资产', '0.5 ETH → USDC'),
          LoopSignFact('网络', 'BSC'),
          LoopSignFact('费用', '0.0012 BNB'),
          LoopSignFact('模拟结果', '通过'),
        ],
      ),
      LoopSignSheetShowcaseItem(
        label: '态 2 · 模拟失败',
        state: LoopSignSheetState.simulationFailed,
        facts: <LoopSignFact>[
          LoopSignFact('操作', 'Swap'),
          LoopSignFact('模拟结果', '失败 · 无法预演', down: true),
        ],
        reason: '模拟服务未返回可验证结果。当前不能确认；可重试模拟或取消操作。',
      ),
      LoopSignSheetShowcaseItem(
        label: '态 3 · 签名中',
        state: LoopSignSheetState.signing,
        facts: <LoopSignFact>[],
      ),
      LoopSignSheetShowcaseItem(
        label: '态 4 · 被策略拒绝',
        state: LoopSignSheetState.policyRejected,
        facts: <LoopSignFact>[
          LoopSignFact('操作', '转账 5,000 USDC'),
          LoopSignFact('结果', '被拒绝', down: true),
        ],
        reason: '超过你设置的单笔转账上限 \$1,000。这是你自己配置的钱包策略 —— 可在安全中心调整，或降低本次金额。',
      ),
    ],
  );
}
