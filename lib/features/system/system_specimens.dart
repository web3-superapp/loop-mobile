import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
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
String get loopComponentSpecimenLabel =>
    LoopL10n.current.system_specimensLoopComponentSpecimenLabel;

/// The same eyebrow for a *state* page whose specimen reads like a claim.
///
/// `当前设备离线` and `03:00–05:00 UTC` are sentences about now. Drawn as
/// specimens they need the stronger label.
String get loopStateSpecimenLabel =>
    LoopL10n.current.system_specimensLoopStateSpecimenLabel;

/// The five Token Cards and four signing sheets of the frozen prototype
/// (`token-card-states.html`, `sign-sheet-states.html`; figures from its
/// `FX` table).
///
/// [sourceLabel] is what the page prints above its folio. It defaults to
/// 组件样例 — the specification pages' own label — and `lib/main_preview.dart`
/// passes 演示数据 · 开发预览 so a Development Preview build still says which
/// root it is running.
LoopSystemShowcase buildLoopSystemSpecimens({String? sourceLabel}) {
  return LoopSystemShowcase(
    sourceLabel: sourceLabel ?? loopComponentSpecimenLabel,
    tokenCards: <LoopTokenCardShowcaseItem>[
      LoopTokenCardShowcaseItem(
        label: LoopL10n.current.system_specimensLabel,
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
          metrics: <LoopTokenMetric>[
            LoopTokenMetric(LoopL10n.current.common_marketCap, r'$3.4B'),
            LoopTokenMetric(LoopL10n.current.common_liquidity, r'$18.2M'),
            LoopTokenMetric(LoopL10n.current.common_holders, '284,912'),
          ],
          communityLine: LoopL10n.current.system_specimensCommunityLine,
          chartRangeLabel: LoopL10n.current.system_specimensChartRangeLabel,
          chart: LoopSparkline(
            closes: _specimenCloses,
            semanticLabel: LoopL10n.current.system_specimensSemanticLabel,
            color: LoopPriceMove.up.color,
          ),
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction(LoopL10n.current.common_buy, buy: true),
          LoopTokenCardAction(LoopL10n.current.common_sell),
          LoopTokenCardAction(LoopL10n.current.system_surfacesSkeletonChart),
          LoopTokenCardAction(LoopL10n.current.common_community),
        ],
      ),
      LoopTokenCardShowcaseItem(
        label: LoopL10n.current.system_specimensLabel2,
        state: LoopTokenCardState.loading,
        model: LoopTokenCardModel(
          symbol: 'PEPE',
          identifier: '0x6982...1933',
          metrics: <LoopTokenMetric>[
            LoopTokenMetric(
              LoopL10n.current.common_marketCap,
              LoopL10n.current.common_waitingForData,
            ),
            LoopTokenMetric(
              LoopL10n.current.common_liquidity,
              LoopL10n.current.common_waitingForData,
            ),
            LoopTokenMetric(
              LoopL10n.current.common_holders,
              LoopL10n.current.common_waitingForData,
            ),
          ],
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction(LoopL10n.current.common_buy, buy: true),
          LoopTokenCardAction(LoopL10n.current.system_surfacesSkeletonChart),
          LoopTokenCardAction(LoopL10n.current.common_community),
        ],
      ),
      LoopTokenCardShowcaseItem(
        label: LoopL10n.current.system_specimensLabel3,
        state: LoopTokenCardState.graduated,
        model: LoopTokenCardModel(
          symbol: 'BONEZ',
          identifier: '...9B2ELOOP',
          price: r'$0.0024',
          change: '+712%',
          move: LoopPriceMove.up,
          badge: LoopL10n.current.common_graduated,
          metrics: <LoopTokenMetric>[
            LoopTokenMetric(LoopL10n.current.common_marketCap, r'$2.4M'),
            LoopTokenMetric(
              LoopL10n.current.common_liquidity,
              r'$412K',
              accent: true,
            ),
            LoopTokenMetric(LoopL10n.current.common_holders, '4,120'),
          ],
          communityIcon: 'graduate',
          communityLine: LoopL10n.current.system_specimensCommunityLine2,
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction(LoopL10n.current.common_buy, buy: true),
          LoopTokenCardAction(LoopL10n.current.common_sell),
          LoopTokenCardAction(
            LoopL10n.current.system_specimensLoopTokenCardAction,
          ),
        ],
      ),
      LoopTokenCardShowcaseItem(
        label: LoopL10n.current.system_specimensLabel4,
        state: LoopTokenCardState.partial,
        model: LoopTokenCardModel(
          symbol: 'UNKNOWN',
          identifier: '0x9c4b...7f82',
          price: r'$0.000004',
          metrics: <LoopTokenMetric>[
            LoopTokenMetric(
              LoopL10n.current.common_marketCap,
              LoopL10n.current.common_dataUnavailable,
            ),
            LoopTokenMetric(
              LoopL10n.current.common_liquidity,
              LoopL10n.current.common_dataUnavailable,
            ),
            LoopTokenMetric(
              LoopL10n.current.common_holders,
              LoopL10n.current.common_dataUnavailable,
            ),
          ],
          communityIcon: 'info',
          communityLine: LoopL10n.current.system_specimensCommunityLine3,
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction(
            LoopL10n.current.system_specimensLoopTokenCardAction2,
          ),
          LoopTokenCardAction(
            LoopL10n.current.system_specimensLoopTokenCardAction3,
          ),
        ],
      ),
      LoopTokenCardShowcaseItem(
        label: LoopL10n.current.system_specimensLabel5,
        state: LoopTokenCardState.risk,
        model: LoopTokenCardModel(
          symbol: 'PEPE',
          identifier: '0x3f8a...2b91',
          price: r'$0.0000079',
          change: '+842%',
          move: LoopPriceMove.up,
          riskFacts: <LoopTokenRiskFact>[
            LoopTokenRiskFact(
              fact: LoopL10n.current.system_specimensFact,
              source: 'GoPlus',
              observedLabel: LoopL10n.current.system_specimensObservedLabel,
            ),
            LoopTokenRiskFact(
              fact: LoopL10n.current.system_specimensFact2,
              source: LoopL10n.current.system_specimensSource,
              observedLabel: LoopL10n.current.system_specimensObservedLabel,
            ),
          ],
          metrics: <LoopTokenMetric>[
            LoopTokenMetric(LoopL10n.current.common_marketCap, r'$142K'),
            LoopTokenMetric(LoopL10n.current.common_liquidity, r'$8,200'),
            LoopTokenMetric(LoopL10n.current.common_holders, '84'),
          ],
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction(
            LoopL10n.current.system_specimensLoopTokenCardAction4,
            buy: true,
          ),
          LoopTokenCardAction(
            LoopL10n.current.system_specimensLoopTokenCardAction5,
          ),
          LoopTokenCardAction(LoopL10n.current.common_report),
        ],
      ),
    ],
    signSheets: <LoopSignSheetShowcaseItem>[
      LoopSignSheetShowcaseItem(
        label: LoopL10n.current.system_specimensLabel6,
        state: LoopSignSheetState.pending,
        facts: <LoopSignFact>[
          LoopSignFact(LoopL10n.current.common_actions, 'Swap'),
          LoopSignFact(LoopL10n.current.common_assets, '0.5 ETH → USDC'),
          LoopSignFact(LoopL10n.current.common_network, 'BSC'),
          LoopSignFact(
            LoopL10n.current.system_specimensLoopSignFact,
            '0.0012 BNB',
          ),
          LoopSignFact(
            LoopL10n.current.common_simulationResult,
            LoopL10n.current.system_specimensLoopSignFact2,
          ),
        ],
      ),
      LoopSignSheetShowcaseItem(
        label: LoopL10n.current.system_specimensLabel7,
        state: LoopSignSheetState.simulationFailed,
        facts: <LoopSignFact>[
          LoopSignFact(LoopL10n.current.common_actions, 'Swap'),
          LoopSignFact(
            LoopL10n.current.common_simulationResult,
            LoopL10n.current.system_specimensLoopSignFact3,
            down: true,
          ),
        ],
        reason: LoopL10n.current.system_specimensReason,
      ),
      LoopSignSheetShowcaseItem(
        label: LoopL10n.current.system_specimensLabel8,
        state: LoopSignSheetState.signing,
        facts: <LoopSignFact>[],
      ),
      LoopSignSheetShowcaseItem(
        label: LoopL10n.current.system_specimensLabel9,
        state: LoopSignSheetState.policyRejected,
        facts: <LoopSignFact>[
          LoopSignFact(
            LoopL10n.current.common_actions,
            LoopL10n.current.system_specimensLoopSignFact4,
          ),
          LoopSignFact(
            LoopL10n.current.system_specimensLoopSignFact5,
            LoopL10n.current.system_specimensLoopSignFact6,
            down: true,
          ),
        ],
        reason: LoopL10n.current.system_specimensReason2,
      ),
    ],
  );
}

/// The Development Preview alias. It exists so the explicit Preview root
/// keeps naming its own label rather than relying on the default.
LoopSystemShowcase buildLoopSystemShowcasePreview() => buildLoopSystemSpecimens(
  sourceLabel: LoopL10n.current.system_specimensSourceLabel,
);

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
