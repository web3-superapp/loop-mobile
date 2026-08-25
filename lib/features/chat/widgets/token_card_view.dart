import 'package:flutter/material.dart'
    show
        Alignment,
        Border,
        BoxDecoration,
        BoxShape,
        BuildContext,
        ClipRRect,
        Column,
        Color,
        Container,
        CrossAxisAlignment,
        DecoratedBox,
        EdgeInsets,
        Expanded,
        FontWeight,
        Icon,
        IconData,
        Icons,
        MainAxisSize,
        OutlinedButton,
        Padding,
        Positioned,
        Row,
        Semantics,
        SizedBox,
        Stack,
        StatelessWidget,
        Text,
        TextOverflow,
        Theme,
        ValueKey,
        Widget,
        immutable;
import 'package:loop_mobile/core/theme/loop_theme.dart'
    show LoopColors, LoopRadius;
import 'package:loop_mobile/features/chat/attachments/token_card_attachment.dart';

enum LoopTokenCardViewState {
  unavailable,
  malformed,
  previewReady,
  previewBlocked,
  previewStale,
}

enum LoopTokenCardTone { neutral, conversation, warning, danger }

@immutable
final class LoopTokenCardPreviewFact {
  const LoopTokenCardPreviewFact({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final LoopTokenCardTone tone;
  final IconData icon;
}

/// Read-only presentation for a permanent Stream token-card reference.
///
/// Production currently uses only [LoopTokenCardViewState.unavailable] and
/// [LoopTokenCardViewState.malformed]. Rich facts are accepted exclusively as
/// visibly labelled development-preview fixtures until a fresh backend facts
/// projection is implemented.
class LoopTokenCardView extends StatelessWidget {
  const LoopTokenCardView({
    required this.state,
    super.key,
    this.reference,
    this.previewPrice,
    this.previewChange,
    this.previewSource,
    this.previewFacts = const <LoopTokenCardPreviewFact>[],
  });

  final LoopTokenCardViewState state;
  final LoopTokenCardAttachment? reference;
  final String? previewPrice;
  final String? previewChange;
  final String? previewSource;
  final List<LoopTokenCardPreviewFact> previewFacts;

  @override
  Widget build(BuildContext context) {
    final requiresPreviewFacts =
        state == LoopTokenCardViewState.previewReady ||
        state == LoopTokenCardViewState.previewBlocked;
    if (state == LoopTokenCardViewState.malformed ||
        this.reference == null ||
        (requiresPreviewFacts &&
            (previewPrice == null || previewSource == null))) {
      return const _TokenCardFrame(
        key: ValueKey<String>('token-card-malformed'),
        tone: LoopTokenCardTone.neutral,
        child: _TokenCardNotice(
          title: 'Unsupported token card',
          message: 'This attachment does not match LOOP token_card.v1 and no token facts or action were displayed.',
          icon: Icons.report_gmailerrorred_outlined,
        ),
      );
    }

    final reference = this.reference!;
    final showPreviewFacts = requiresPreviewFacts;
    final preview =
        showPreviewFacts || state == LoopTokenCardViewState.previewStale;
    final blocked = state == LoopTokenCardViewState.previewBlocked;
    final tone = blocked
        ? LoopTokenCardTone.danger
        : LoopTokenCardTone.conversation;

    return Semantics(
      label: '${reference.assetId} token reference on ${reference.chainId}',
      child: _TokenCardFrame(
        key: ValueKey<String>('token-card-${state.name}'),
        tone: tone,
        accent: true,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _TokenCardAssetMark(
                  symbol: reference.assetId,
                  size: 42,
                  color: blocked ? LoopColors.danger : LoopColors.chat,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        reference.assetId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${reference.chainId} · ${reference.compactContract}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                if (preview)
                  const _TokenCardStatusPill(
                    label: '开发预览',
                    tone: LoopTokenCardTone.conversation,
                    icon: Icons.visibility_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 13),
            if (showPreviewFacts) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      previewPrice!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (previewChange != null)
                    Text(
                      previewChange!,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: LoopColors.mint),
                    ),
                ],
              ),
              if (previewFacts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Column(
                  children: <Widget>[
                    for (final fact in previewFacts) ...<Widget>[
                      _TokenCardPreviewFactTile(fact: fact),
                      if (fact != previewFacts.last) const SizedBox(height: 6),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                previewSource!,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 10),
              Text(
                blocked
                    ? 'Preview blocking facts disable every prototype action.'
                    : 'Preview facts are visual fixtures and cannot trigger a trade or watchlist mutation.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const _TokenCardPreviewActions(),
            ] else ...<Widget>[_buildProductionNotice(context, reference)],
          ],
        ),
      ),
    );
  }

  Widget _buildProductionNotice(
    BuildContext context,
    LoopTokenCardAttachment reference,
  ) {
    if (state == LoopTokenCardViewState.previewStale) {
      return const _TokenCardNotice(
        title: 'Preview facts expired',
        message: 'Stale price and contract facts were cleared. No trading action is available.',
        icon: Icons.history_toggle_off_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _TokenCardNotice(
          title: 'Current facts unavailable',
          message: 'LOOP has not received a fresh backend price and contract-facts projection. The message stores identifiers only, so no price, risk claim, Buy, or Watch action is shown.',
          icon: Icons.cloud_off_outlined,
        ),
        const SizedBox(height: 10),
        Text(
          'Reference snapshot ${_formatUtc(reference.snapshotAt)}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }

  static String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)} UTC';
  }
}

class _TokenCardPreviewFactTile extends StatelessWidget {
  const _TokenCardPreviewFactTile({required this.fact});

  final LoopTokenCardPreviewFact fact;

  @override
  Widget build(BuildContext context) {
    final color = _tokenCardToneColor(fact.tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: LoopRadius.medium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(fact.icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              fact.label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

Color _tokenCardToneColor(LoopTokenCardTone tone) => switch (tone) {
  LoopTokenCardTone.neutral => LoopColors.vapor,
  LoopTokenCardTone.conversation => LoopColors.chat,
  LoopTokenCardTone.warning => LoopColors.warning,
  LoopTokenCardTone.danger => LoopColors.danger,
};

class _TokenCardFrame extends StatelessWidget {
  const _TokenCardFrame({
    required this.child,
    required this.tone,
    super.key,
    this.accent = false,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final LoopTokenCardTone tone;
  final bool accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = _tokenCardToneColor(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LoopColors.basalt.withValues(alpha: 0.94),
        borderRadius: LoopRadius.medium,
        border: Border.all(
          color: accent ? color.withValues(alpha: 0.42) : LoopColors.line,
        ),
      ),
      child: ClipRRect(
        borderRadius: LoopRadius.medium,
        child: Stack(
          children: <Widget>[
            if (accent)
              Positioned(
                left: 0,
                top: 12,
                bottom: 12,
                child: Container(width: 3, color: color),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _TokenCardAssetMark extends StatelessWidget {
  const _TokenCardAssetMark({
    required this.symbol,
    required this.color,
    required this.size,
  });

  final String symbol;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = String.fromCharCode(symbol.runes.first);
    return Semantics(
      label: '$symbol asset',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.13),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Text(
          mark,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TokenCardStatusPill extends StatelessWidget {
  const _TokenCardStatusPill({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final LoopTokenCardTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = _tokenCardToneColor(tone);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: LoopRadius.pill,
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenCardPreviewActions extends StatelessWidget {
  const _TokenCardPreviewActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Prototype actions · unavailable in development preview',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        for (final action in const <(IconData, String)>[
          (Icons.show_chart_rounded, 'Chart'),
          (Icons.bookmark_add_outlined, 'Watch'),
          (Icons.shopping_bag_outlined, 'Buy'),
        ]) ...<Widget>[
          OutlinedButton.icon(
            onPressed: null,
            icon: Icon(action.$1),
            label: Text(action.$2),
          ),
          if (action.$2 != 'Buy') const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TokenCardNotice extends StatelessWidget {
  const _TokenCardNotice({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 19, color: LoopColors.vapor),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
