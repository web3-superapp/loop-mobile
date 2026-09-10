import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// Placeholder mounted for every manifest route whose page is not connected.
///
/// It tells the truth and nothing else: which page this is, which module and
/// implementation step will deliver it, and how to get back. It renders no
/// figure, fixture or fake control. The [LoopPendingSurface.unavailable]
/// variant is used for pages the product deliberately keeps fail-closed
/// (currently only Pay).
class LoopPendingSurface extends StatelessWidget {
  const LoopPendingSurface({required this.entry, super.key})
    : _unavailable = false;

  const LoopPendingSurface.unavailable({required this.entry, super.key})
    : _unavailable = true;

  final LoopRouteEntry entry;
  final bool _unavailable;

  static const String pendingHeadline = '该页面还没有开放';
  static const String unavailableHeadline = 'Pay 暂不可用';

  /// Pay is the only fail-closed manifest page in this step; the wording is
  /// shared with the Wallet entry card so both tell the same truth.
  static const String unavailableMessage =
      'Pay 尚未开放。此页面不会扫码、不会请求相机权限、不会收集支付信息，也不会提交任何交易。';

  String get sourceLine => '所属模块：${entry.module.label}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomInset = math.max(LoopLayout.childPageBottomMinimum, safeBottom);
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      key: ValueKey<String>('loop-pending-${entry.slug}'),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Topbar(
              title: entry.title,
              kicker: entry.slug,
              onBack: () {
                if (canPop) {
                  context.pop();
                } else {
                  context.go(LoopRouteManifest.defaultPath);
                }
              },
              backLabel: canPop ? '返回' : '返回社区',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  LoopSpacing.tight,
                  LoopSpacing.page,
                  bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: LoopColors.card,
                        borderRadius: LoopRadius.card,
                        border: Border.all(color: LoopColors.line),
                        boxShadow: LoopDepth.liftCard,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: LoopTouch.minimum,
                                height: LoopTouch.minimum,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: LoopColors.limeSoft,
                                  borderRadius: LoopRadius.inner,
                                ),
                                child: LoopIcon(
                                  _unavailable ? 'lock' : 'info',
                                  color: LoopColors.lime,
                                ),
                              ),
                              const SizedBox(width: LoopSpacing.card),
                              Expanded(
                                child: Text(
                                  _unavailable
                                      ? unavailableHeadline
                                      : pendingHeadline,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: LoopSpacing.card),
                          Text(
                            _unavailable
                                ? unavailableMessage
                                : '「${entry.title}」还没有开放，这里暂时不显示任何内容，也不能执行任何操作。',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: LoopSpacing.tight),
                          Text(
                            sourceLine,
                            key: const ValueKey<String>('loop-pending-source'),
                            style: LoopTypography.withWeight(
                              LoopType.bodySm,
                              FontWeight.w600,
                            ).copyWith(color: LoopColors.chalk),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: LoopSpacing.group),
                    _Row(label: 'ROUTE', value: entry.path),
                    _Row(label: 'PROTOTYPE', value: '#${entry.slug}'),
                    _Row(label: 'MODULE', value: entry.module.manifestKey),
                    if (entry.legacyPath != null)
                      _Row(label: 'LEGACY PATH', value: entry.legacyPath!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({
    required this.title,
    required this.kicker,
    required this.onBack,
    required this.backLabel,
  });

  final String title;
  final String kicker;
  final VoidCallback onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        6,
        LoopSpacing.page,
        0,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey<String>('loop-pending-back'),
              tooltip: backLabel,
              onPressed: onBack,
              constraints: const BoxConstraints.tightFor(
                width: LoopTouch.minimum,
                height: LoopTouch.minimum,
              ),
              icon: const LoopIcon('back'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(kicker, style: LoopMono.label),
                  Text(
                    title,
                    style: theme.textTheme.headlineLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LoopSpacing.card,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        children: <Widget>[
          Text(label, style: LoopMono.label),
          const Spacer(),
          Text(value, style: LoopMono.value),
        ],
      ),
    );
  }
}
