import 'package:decimal/decimal.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

/// The mono eyebrow a component-specification page wears.
///
/// `token-card-states` and `sign-sheet-states` are the only pages whose job
/// is the component itself: the prototype draws five real Token Cards and
/// four real signing sheets on them, and the audit of 2026-09-21 (§K.8, §K.9,
/// §D+ item 14) found LOOP rendering a hero that promised 「5 种卡片状态」 over
/// a body with none. A specimen is not an observation, so it does not wait
/// for one — it is labelled instead, and the label sits above the folio where
/// it frames everything under it rather than pushing the content down.
const String loopComponentSpecimenLabel = '组件样例';

/// The same eyebrow for a *state* page whose specimen reads like a claim.
///
/// `当前设备离线` and `03:00–05:00 UTC` are sentences about now. Drawn as
/// specimens they need the stronger label.
const String loopStateSpecimenLabel = '组件样例 · 不是当前状态';

/// The five Token Cards and four signing sheets of the frozen prototype
/// (`token-card-states.html`, `sign-sheet-states.html`; figures from its
/// `FX` table).
///
/// [sourceLabel] is what the page prints above its folio. It defaults to
/// 组件样例 — the specification pages' own label — and `lib/main_preview.dart`
/// passes 演示数据 · 开发预览 so a Development Preview build still says which
/// root it is running.
LoopSystemShowcase buildLoopSystemSpecimens({
  String sourceLabel = loopComponentSpecimenLabel,
}) {
  return LoopSystemShowcase(
    sourceLabel: sourceLabel,
    tokenCards: <LoopTokenCardShowcaseItem>[
      LoopTokenCardShowcaseItem(
        label: '态 1 · 正常',
        state: LoopTokenCardState.normal,
        // The prototype draws the normal state, and only it, on Chalk.
        chalk: true,
        // The frozen prototype's own `FX.pepe` row, not the inline HTML
        // defaults it overwrites at runtime.
        model: LoopTokenCardModel(
          symbol: 'PEPE',
          identifier: '0x6982…1933',
          price: r'$0.0000082',
          change: '+12.4%',
          move: LoopPriceMove.up,
          metrics: const <LoopTokenMetric>[
            LoopTokenMetric('市值', r'$3.4B'),
            LoopTokenMetric('流动性', r'$18.2M'),
            LoopTokenMetric('持有人', '284,912'),
          ],
          communityLine: 'LOOP 社区 128,420 成员 · 0.35×',
          chartRangeLabel: '1H · 固定演示',
          chart: LoopSparkline(
            closes: _specimenCloses,
            semanticLabel: 'PEPE 1 小时走势 · 组件样例',
            color: LoopColors.lime,
          ),
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
          move: LoopPriceMove.up,
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
          move: LoopPriceMove.up,
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

/// The Development Preview alias. It exists so the explicit Preview root
/// keeps naming its own label rather than relying on the default.
LoopSystemShowcase buildLoopSystemShowcasePreview() =>
    buildLoopSystemSpecimens(sourceLabel: '演示数据 · 开发预览');

/// The 24 hourly closes the normal card's line draws.
///
/// A fixed series, like the prototype's `1H · 固定演示`: a specification page
/// must draw the same shape every time it is opened, so it never reads a
/// market. Nothing outside this card may reuse these numbers — they are a
/// line's geometry, not a quote.
final List<Decimal> _specimenCloses = List<Decimal>.unmodifiable(
  <String>[
    '0.0000071',
    '0.0000069',
    '0.0000072',
    '0.0000070',
    '0.0000074',
    '0.0000073',
    '0.0000076',
    '0.0000075',
    '0.0000078',
    '0.0000077',
    '0.0000074',
    '0.0000076',
    '0.0000079',
    '0.0000078',
    '0.0000081',
    '0.0000080',
    '0.0000079',
    '0.0000082',
    '0.0000081',
    '0.0000083',
    '0.0000082',
    '0.0000084',
    '0.0000083',
    '0.0000082',
  ].map(Decimal.parse),
);
