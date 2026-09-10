import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Token Card states (prototype `token-card-states`, `.tcard-signature`).
enum LoopTokenCardState {
  /// Identity, quote, fixed chart, three metrics, community and actions.
  normal,

  /// Identifying: placeholders everywhere, actions disabled.
  loading,

  /// LOOP Launch asset that graduated: Lime border. It carries no ecosystem
  /// tax metric: no tax rate exists until the Launch contract baseline is
  /// delivered, so the owner supplies only figures it can prove.
  graduated,

  /// Partial data: metrics unavailable, trading disabled.
  partial,

  /// Risk facts: a facts bar listing each fact with source and observation
  /// time. Facts only — no verdict.
  risk,
}

/// One risk fact with its source and observation time. The card never
/// renders "dangerous" / "unsafe"; the reader judges.
@immutable
final class LoopTokenRiskFact {
  const LoopTokenRiskFact({
    required this.fact,
    required this.source,
    required this.observedLabel,
  });

  final String fact;
  final String source;
  final String observedLabel;
}

@immutable
final class LoopTokenMetric {
  const LoopTokenMetric(this.label, this.value, {this.accent = false});

  final String label;
  final String value;

  /// `.launch-accent` on the value.
  final bool accent;
}

/// View model consumed by [LoopTokenCard]. Every string is display-ready;
/// figures are preformatted by the owner. `null` means "not available" and
/// renders as the owner's placeholder copy, never as `0`.
@immutable
final class LoopTokenCardModel {
  const LoopTokenCardModel({
    required this.symbol,
    required this.identifier,
    this.price,
    this.priceReason,
    this.change,
    this.changeUp,
    this.metrics = const <LoopTokenMetric>[],
    this.communityLine,
    this.communityIcon = 'chat',
    this.badge,
    this.riskFacts = const <LoopTokenRiskFact>[],
    this.chartRangeLabel,
    this.chart,
  });

  final String symbol;

  /// Short contract / identifier line under the symbol.
  final String identifier;
  final String? price;

  /// Why there is no [price]. Rendered in place of the figure when the owner
  /// has no readable quote, so the slot never falls back to an em dash — an
  /// unavailable fact states its reason or says nothing at all.
  final String? priceReason;
  final String? change;
  final bool? changeUp;
  final List<LoopTokenMetric> metrics;
  final String? communityLine;
  final String communityIcon;
  final String? badge;
  final List<LoopTokenRiskFact> riskFacts;
  final String? chartRangeLabel;

  /// Owner-supplied chart (Graphite ground, Lime line). Null hides the slot.
  final Widget? chart;
}

@immutable
final class LoopTokenCardAction {
  const LoopTokenCardAction(this.label, {this.onTap, this.buy = false});

  final String label;
  final VoidCallback? onTap;

  /// `.buy`: Lime label.
  final bool buy;
}

/// The signature Token Card.
class LoopTokenCard extends StatelessWidget {
  const LoopTokenCard({
    required this.state,
    required this.model,
    super.key,
    this.actions = const <LoopTokenCardAction>[],
    this.chalk = false,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final LoopTokenCardState state;
  final LoopTokenCardModel model;
  final List<LoopTokenCardAction> actions;

  /// `.tcard.chalk-card`.
  final bool chalk;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final muted = state == LoopTokenCardState.loading;
    final foreground = chalk ? LoopColors.ink : LoopColors.chalk;
    final secondary = chalk ? LoopColors.inkText3 : LoopColors.text3;
    final cellGround = chalk ? const Color(0x0E050604) : LoopColors.ink;
    final stateLabel = switch (state) {
      LoopTokenCardState.normal => '正常',
      LoopTokenCardState.loading => '识别中',
      LoopTokenCardState.graduated => '已毕业',
      LoopTokenCardState.partial => '数据缺失',
      LoopTokenCardState.risk => '风险事实',
    };
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        label: '${model.symbol} Token Card · $stateLabel',
        explicitChildNodes: true,
        child: Container(
          key: ValueKey<String>('loop-token-card-${state.name}'),
          decoration: BoxDecoration(
            color: chalk ? LoopColors.chalk : LoopColors.graphite,
            gradient: chalk
                ? null
                : const RadialGradient(
                    center: Alignment(-0.88, -1.16),
                    radius: 1.4,
                    colors: <Color>[Color(0x13B8FF20), Color(0x00B8FF20)],
                    stops: <double>[0, 0.58],
                  ),
            borderRadius: LoopRadius.card,
            border: Border.all(
              color: state == LoopTokenCardState.graduated
                  ? LoopColors.lime.withValues(alpha: 0.32)
                  : LoopColors.chalk.withValues(alpha: 0.16),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0xA8050604),
                offset: Offset(0, 22),
                blurRadius: 56,
              ),
              BoxShadow(
                color: Color(0x70050604),
                offset: Offset(0, 6),
                blurRadius: 16,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              // `.tcard-signature::before`: the Lime signal rail.
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: LoopColors.lime,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Head(
                    model: model,
                    state: state,
                    foreground: foreground,
                    secondary: secondary,
                    muted: muted,
                  ),
                  if (state == LoopTokenCardState.risk &&
                      model.riskFacts.isNotEmpty)
                    _RiskBar(facts: model.riskFacts, foreground: foreground),
                  // The prototype draws a `tcard-chart` only in the two states
                  // that have a series: 正常 and 已毕业. 识别中 / 数据缺失 /
                  // 风险事实 carry no chart slot at all.
                  if ((state == LoopTokenCardState.normal ||
                          state == LoopTokenCardState.graduated) &&
                      model.chart != null)
                    _Chart(model: model, chalk: chalk),
                  if (model.metrics.isNotEmpty)
                    _Metrics(
                      metrics: model.metrics,
                      cellGround: cellGround,
                      valueColor: state == LoopTokenCardState.partial || muted
                          ? secondary
                          : foreground,
                      labelColor: secondary,
                    ),
                  if (model.communityLine != null)
                    _CommunityLine(
                      icon: model.communityIcon,
                      text: model.communityLine!,
                      color: chalk ? LoopColors.inkText2 : LoopColors.text2,
                      accent: state == LoopTokenCardState.graduated,
                    ),
                  if (actions.isNotEmpty)
                    _Actions(
                      actions: actions,
                      disabled: muted,
                      cellGround: cellGround,
                      foreground: chalk ? LoopColors.ink : LoopColors.text2,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({
    required this.model,
    required this.state,
    required this.foreground,
    required this.secondary,
    required this.muted,
  });

  final LoopTokenCardModel model;
  final LoopTokenCardState state;
  final Color foreground;
  final Color secondary;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final logo = switch (state) {
      LoopTokenCardState.loading => Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: LoopColors.card2,
          borderRadius: LoopRadius.control,
        ),
        child: Text(
          '⋯',
          style: LoopTypography.figure(17, height: 1.15, color: secondary),
        ),
      ),
      LoopTokenCardState.partial => _GlyphLogo(icon: 'question'),
      LoopTokenCardState.risk => _GlyphLogo(icon: 'phishing'),
      _ => LoopTokenLogo(assetSymbol: model.symbol, size: 52),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
      child: Row(
        children: <Widget>[
          logo,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Wrap so a badge drops below the symbol at large text
                // instead of overflowing the head row.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      state == LoopTokenCardState.loading
                          ? '识别中…'
                          : model.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.label(
                        14,
                        weight: FontWeight.w700,
                        color: muted ? secondary : foreground,
                      ),
                    ),
                    if (model.badge != null)
                      LoopBadge(model.badge!, kind: LoopBadgeKind.launch),
                  ],
                ),
                Text(
                  model.identifier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopTypography.figure(
                    11,
                    weight: FontWeight.w500,
                    color: secondary,
                  ),
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
                if (state == LoopTokenCardState.loading)
                  Text(
                    '识别中',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.figure(
                      17,
                      height: 1.15,
                      color: secondary,
                    ),
                  )
                else if (model.price != null)
                  Text(
                    model.price!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.figure(
                      17,
                      height: 1.15,
                      color: muted ? secondary : foreground,
                    ),
                  )
                // No quote and a stated reason: the reason is the fact. No
                // quote and no reason: the slot stays empty rather than
                // inventing an em dash the owner never claimed.
                else if (model.priceReason != null)
                  Text(
                    model.priceReason!,
                    key: const ValueKey<String>('loop-token-card-price-reason'),
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.caption(11, color: secondary),
                  ),
                // A card that never read the 24h fact says nothing about it;
                // only an owner that did read one supplies [change].
                if (model.change != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      model.change!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.figure(
                        11,
                        color: switch (model.changeUp) {
                          true => LoopColors.lime,
                          false => LoopColors.chalk,
                          null => secondary,
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlyphLogo extends StatelessWidget {
  const _GlyphLogo({required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: LoopColors.card2,
        borderRadius: LoopRadius.control,
      ),
      child: LoopIcon(icon, size: 19),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.model, required this.chalk});

  final LoopTokenCardModel model;
  final bool chalk;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (model.chartRangeLabel != null)
              SizedBox(
                height: 18,
                child: Text(
                  model.chartRangeLabel!,
                  style: LoopTypography.eyebrow(
                    11,
                    color: chalk ? LoopColors.inkText2 : LoopColors.muted,
                  ),
                ),
              ),
            Expanded(child: model.chart!),
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.metrics,
    required this.cellGround,
    required this.valueColor,
    required this.labelColor,
  });

  final List<LoopTokenMetric> metrics;
  final Color cellGround;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LoopColors.line,
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < metrics.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 1),
            Expanded(
              child: Container(
                color: cellGround,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      metrics[index].label.toUpperCase(),
                      style: LoopTypography.caption(11, color: labelColor),
                    ),
                    Text(
                      metrics[index].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.figure(
                        13,
                        color: metrics[index].accent
                            ? LoopColors.lime
                            : valueColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityLine extends StatelessWidget {
  const _CommunityLine({
    required this.icon,
    required this.text,
    required this.color,
    required this.accent,
  });

  final String icon;
  final String text;
  final Color color;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        children: <Widget>[
          LoopIcon(icon, size: 17, color: accent ? LoopColors.lime : color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: LoopTypography.caption(11, color: color)),
          ),
        ],
      ),
    );
  }
}

class _RiskBar extends StatelessWidget {
  const _RiskBar({required this.facts, required this.foreground});

  final List<LoopTokenRiskFact> facts;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('loop-token-card-risk-facts'),
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
      decoration: const BoxDecoration(
        color: LoopColors.card2,
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: LoopColors.chalk,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final fact in facts)
                  Text(
                    '${fact.fact} —— 来源 ${fact.source}，观察于 ${fact.observedLabel}',
                    style: LoopTypography.caption(11, color: foreground),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.actions,
    required this.disabled,
    required this.cellGround,
    required this.foreground,
  });

  final List<LoopTokenCardAction> actions;
  final bool disabled;
  final Color cellGround;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LoopColors.line,
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < actions.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 1),
            Expanded(
              child: Semantics(
                button: true,
                enabled: !disabled && actions[index].onTap != null,
                label: actions[index].label,
                child: Material(
                  color: cellGround,
                  child: InkWell(
                    onTap: disabled ? null : actions[index].onTap,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: LoopTouch.minimum,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      alignment: Alignment.center,
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: disabled || actions[index].onTap == null
                              ? 0.4
                              : 1,
                          child: Text(
                            actions[index].label,
                            textAlign: TextAlign.center,
                            style: LoopTypography.label(
                              12,
                              weight: FontWeight.w700,
                              color: actions[index].buy
                                  ? LoopColors.lime
                                  : foreground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
