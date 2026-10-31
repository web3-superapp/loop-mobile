import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

/// The chat's Token Card face (S326 · decision 0256, UX-014).
///
/// It reads the same [LoopTokenCardModel] the shared [LoopTokenCard] does and
/// keeps its keys, but draws fewer colour blocks: one card ground; inside it
/// the 「自动识别到代币」 line, the head (logo, name, address; price and move on
/// the right), the contract facts as a dotted list with the source and time
/// on the same line, the 1H chart as one clear inner block, the three
/// figures larger and on the card itself, the community line, the small
/// print, and the four actions as the app's own [LoopButton]s — the ones
/// that cannot be taken disabled, not hidden.
///
/// It lives in the chat feature because the shared card is shared with the
/// system specimens and attachments, which this batch does not touch.
class ChatTokenCardView extends StatelessWidget {
  const ChatTokenCardView({
    required this.state,
    required this.model,
    super.key,
    this.kicker,
    this.kickerKey,
    this.actions = const <LoopTokenCardAction>[],
    this.margin = const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      0,
      LoopSpacing.page,
      12,
    ),
  });

  final LoopTokenCardState state;
  final LoopTokenCardModel model;

  /// The small line at the card's top (「自动识别到代币」).
  final String? kicker;
  final Key? kickerKey;
  final List<LoopTokenCardAction> actions;
  final EdgeInsets margin;

  /// The inner padding of the card.
  static const double inset = 16;

  @override
  Widget build(BuildContext context) {
    final muted = state == LoopTokenCardState.loading;
    final stateLabel = switch (state) {
      LoopTokenCardState.normal => '正常',
      LoopTokenCardState.loading => '识别中',
      LoopTokenCardState.graduated => '已毕业',
      LoopTokenCardState.partial => '数据缺失',
      LoopTokenCardState.risk => '风险事实',
    };
    final chartShown =
        (state == LoopTokenCardState.normal ||
            state == LoopTokenCardState.graduated) &&
        model.chart != null;
    final line = Divider(
      height: 1,
      thickness: 1,
      color: LoopGround.hairlineOf(context),
    );
    final kicker = this.kicker;
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        label: '${model.symbol} Token Card · $stateLabel',
        explicitChildNodes: true,
        child: Container(
          key: ValueKey<String>('loop-token-card-${state.name}'),
          decoration: BoxDecoration(
            color: LoopColors.card,
            borderRadius: LoopRadius.card,
            border: Border.all(
              color: state == LoopTokenCardState.graduated
                  ? LoopColors.purpleLine
                  : LoopColors.line,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(inset, 14, inset, inset),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: LoopColors.chalk),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (kicker != null) ...<Widget>[
                  Text(
                    kicker,
                    key: kickerKey,
                    style: LoopType.captionSm.copyWith(
                      color: LoopColors.text3,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _Head(model: model, state: state, muted: muted),
                const SizedBox(height: 14),
                line,
                if (model.riskFacts.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _Facts(facts: model.riskFacts),
                ],
                if (chartShown) ...<Widget>[
                  const SizedBox(height: 12),
                  _ChartBlock(model: model),
                ],
                if (model.metrics.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _Metrics(
                    metrics: model.metrics,
                    quiet: state == LoopTokenCardState.partial || muted,
                  ),
                ],
                if (model.communityLine != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _Community(
                    icon: model.communityIcon,
                    text: model.communityLine!,
                    accent: state == LoopTokenCardState.graduated,
                  ),
                ],
                if (model.footnotes.isNotEmpty ||
                    model.provenance.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _Footnotes(
                    lines: model.footnotes,
                    provenance: model.provenance,
                  ),
                ],
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _Actions(actions: actions, disabled: muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.model, required this.state, required this.muted});

  final LoopTokenCardModel model;
  final LoopTokenCardState state;
  final bool muted;

  static const double logo = 44;

  @override
  Widget build(BuildContext context) {
    final secondary = LoopColors.text3;
    final Widget face = switch (state) {
      LoopTokenCardState.loading => _GlyphFace(
        child: Text('⋯', style: LoopType.figureMd.copyWith(color: secondary)),
      ),
      LoopTokenCardState.partial => const _GlyphFace(
        child: LoopIcon('question', size: 19, color: LoopColors.chalk),
      ),
      LoopTokenCardState.risk => const _GlyphFace(
        child: LoopIcon('phishing', size: 19, color: LoopColors.chalk),
      ),
      _ => LoopTokenLogo(
        assetSymbol: model.symbol,
        logoUrl: model.logoUrl,
        size: logo,
      ),
    };
    final change = model.change;
    return Row(
      children: <Widget>[
        face,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    muted ? '识别中…' : model.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.withWeight(
                      LoopType.title,
                      FontWeight.w700,
                    ).copyWith(color: muted ? secondary : LoopColors.chalk),
                  ),
                  if (model.badge != null)
                    LoopBadge(model.badge!, kind: LoopBadgeKind.launch),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                model.identifier,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopTypography.withWeight(
                  LoopType.figureXs,
                  FontWeight.w500,
                ).copyWith(color: secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (muted)
                Text(
                  '识别中',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.figureMd.copyWith(color: secondary),
                )
              else if (model.price != null)
                Text(
                  model.price!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopTypography.figure(20),
                )
              else if (model.priceReason != null)
                Text(
                  model.priceReason!,
                  key: const ValueKey<String>('loop-token-card-price-reason'),
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.captionSm.copyWith(color: secondary),
                ),
              if (change != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    change,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        LoopTypography.withWeight(
                          LoopType.figureXs,
                          FontWeight.w600,
                        ).copyWith(
                          color: model.move == LoopPriceMove.unread
                              ? secondary
                              : model.move.color,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlyphFace extends StatelessWidget {
  const _GlyphFace({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: _Head.logo,
    height: _Head.logo,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: LoopColors.card2,
      shape: BoxShape.circle,
    ),
    child: child,
  );
}

/// The contract facts: a dot, the fact, then the source and the time on the
/// same line in the quieter ink.
class _Facts extends StatelessWidget {
  const _Facts({required this.facts});

  final List<LoopTokenRiskFact> facts;

  @override
  Widget build(BuildContext context) {
    final quiet = LoopType.captionSm.copyWith(
      color: LoopColors.text3,
      fontSize: 12,
    );
    return Column(
      key: const ValueKey<String>('loop-token-card-risk-facts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (index, fact) in facts.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: LoopColors.chalk,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: fact.fact,
                        style: LoopTypography.withWeight(
                          LoopType.captionSm,
                          FontWeight.w600,
                        ).copyWith(color: LoopColors.chalk, fontSize: 13),
                      ),
                      TextSpan(
                        text: ' —— 来源 ${fact.source}，观察于 ${fact.observedLabel}',
                        style: quiet,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The 1H line as one inner block: its title, then the line (or, with no
/// line, the one sentence the owner's chart says, centred).
class _ChartBlock extends StatelessWidget {
  const _ChartBlock({required this.model});

  final LoopTokenCardModel model;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('chat-token-card-chart-block'),
    height: 116,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: const BoxDecoration(
      color: LoopColors.bg2,
      borderRadius: LoopRadius.control,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (model.chartRangeLabel != null)
          Text(
            model.chartRangeLabel!,
            style: LoopTypography.withWeight(
              LoopType.captionSm,
              FontWeight.w600,
            ).copyWith(color: LoopColors.text2, fontSize: 12),
          ),
        const SizedBox(height: 6),
        Expanded(child: model.chart!),
      ],
    ),
  );
}

/// The three figures, on the card itself: a small label over a larger
/// figure.
class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics, required this.quiet});

  final List<LoopTokenMetric> metrics;
  final bool quiet;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('chat-token-card-metrics'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (var index = 0; index < metrics.length; index++) ...<Widget>[
        if (index > 0) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                metrics[index].label,
                style: LoopType.captionSm.copyWith(
                  color: LoopColors.text3,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metrics[index].value,
                  maxLines: 1,
                  style:
                      LoopTypography.figure(
                        quiet ? 15 : 19,
                        weight: quiet ? FontWeight.w500 : FontWeight.w700,
                      ).copyWith(
                        color: quiet
                            ? LoopColors.text3
                            : metrics[index].accent
                            ? LoopColors.lime
                            : LoopColors.chalk,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _Community extends StatelessWidget {
  const _Community({
    required this.icon,
    required this.text,
    required this.accent,
  });

  final String icon;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      LoopIcon(
        icon,
        size: 18,
        color: accent ? LoopColors.lime : LoopColors.text2,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: LoopType.captionSm.copyWith(color: LoopColors.text2),
        ),
      ),
    ],
  );
}

class _Footnotes extends StatelessWidget {
  const _Footnotes({required this.lines, required this.provenance});

  final List<String> lines;
  final List<String> provenance;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('loop-token-card-footnotes'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final line in lines)
                Text(
                  line,
                  style: LoopType.captionSm.copyWith(
                    color: LoopColors.text3,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (provenance.isNotEmpty)
        LoopInfoTrigger(
          key: const ValueKey<String>('loop-token-card-provenance'),
          semanticsLabel: '${provenance.join('；')}，查看数据来源说明',
          onTap: () => unawaited(
            showLoopInfoSheet(
              context,
              title: '数据来源',
              sheetKey: 'loop-token-card-provenance-sheet',
              notes: <LoopInfoNote>[
                for (final line in provenance) LoopInfoNote(body: line),
              ],
            ),
          ),
        ),
    ],
  );
}

/// The four actions as [LoopButton]s in one row: an action with no tap is
/// the disabled button; 买入 is the primary one when it can be taken.
class _Actions extends StatelessWidget {
  const _Actions({required this.actions, required this.disabled});

  final List<LoopTokenCardAction> actions;
  final bool disabled;

  /// Narrower than this, a button keeps its own width and is scaled down to
  /// the cell instead of wrapping its word.
  static const double comfortable = 80;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('chat-token-card-actions'),
    children: <Widget>[
      for (var index = 0; index < actions.length; index++) ...<Widget>[
        if (index > 0) const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final action = actions[index];
              final onTap = disabled ? null : action.onTap;
              Widget button({required bool block}) => LoopButton(
                key: ValueKey<String>('chat-token-card-action-${action.label}'),
                label: action.label,
                primary: action.buy,
                block: block,
                onPressed: onTap,
              );
              if (box.maxWidth >= comfortable) return button(block: true);
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: button(block: false),
              );
            },
          ),
        ),
      ],
    ],
  );
}
