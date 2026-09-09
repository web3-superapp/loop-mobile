import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/bridge_preview_snapshot.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class BridgeScreen extends StatelessWidget {
  const BridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const snapshot = BridgePreviewSnapshot.demo;
    return LoopPage(
      title: 'Bridge',
      eyebrow: '开发预览',
      subtitle: 'Cross-chain routing will be supplied by the selected provider; LOOP does not operate a bridge.',
      bottom: LoopActionDock(
        child: FilledButton(
          onPressed: () =>
              context.push('/wallet/bridge/status', extra: snapshot),
          child: const Text('Preview route status'),
        ),
      ),
      children: <Widget>[
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'From', value: snapshot.sourceLabel),
              LoopKeyValueRow(label: 'To', value: snapshot.destinationLabel),
              LoopKeyValueRow(
                label: 'Estimated time',
                value: snapshot.estimatedTimeLabel,
              ),
              LoopKeyValueRow(
                label: 'Estimated fees',
                value: snapshot.estimatedFeesLabel,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Route preview only',
          message: 'Production routing credentials are not configured. No bridge request will be submitted.',
          icon: Icons.lock_outline_rounded,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class BridgeStatusScreen extends StatefulWidget {
  const BridgeStatusScreen({required this.snapshot, super.key});

  final BridgePreviewSnapshot snapshot;

  @override
  State<BridgeStatusScreen> createState() => _BridgeStatusScreenState();
}

class _BridgeStatusScreenState extends State<BridgeStatusScreen> {
  late BridgePreviewSnapshot snapshot;

  @override
  void initState() {
    super.initState();
    snapshot = widget.snapshot;
  }

  @override
  void didUpdateWidget(BridgeStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      snapshot = widget.snapshot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Bridge progress',
      eyebrow: '开发预览',
      subtitle: 'State transitions below are simulated. No provider reference exists.',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Preview state',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Switch(
              value: snapshot.needsClaim,
              onChanged: (value) =>
                  setState(() => snapshot = snapshot.withNeedsClaim(value)),
            ),
            Text('Needs claim', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 14),
        for (final step in snapshot.progressSteps)
          _BridgeStep(
            index: step.index,
            title: step.title,
            detail: step.detail,
            complete: step.complete,
            warning: step.warning,
          ),
        const SizedBox(height: 18),
        if (snapshot.needsClaim)
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Claim provider not connected'),
          )
        else
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('No provider status'),
          ),
      ],
    );
  }
}

class _BridgeStep extends StatelessWidget {
  const _BridgeStep({
    required this.index,
    required this.title,
    required this.detail,
    required this.complete,
    this.warning = false,
  });

  final String index;
  final String title;
  final String detail;
  final bool complete;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? LoopColors.warning
        : (complete ? LoopColors.mint : LoopColors.vapor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LoopCard(
        accent: complete || warning,
        tone: warning
            ? LoopTone.warning
            : (complete ? LoopTone.positive : LoopTone.neutral),
        child: Row(
          children: <Widget>[
            Text(index, style: context.dataStyle.copyWith(color: color)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(
              complete
                  ? Icons.check_circle_rounded
                  : (warning
                        ? Icons.warning_amber_rounded
                        : Icons.more_horiz_rounded),
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
