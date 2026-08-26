import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class CatalogSurfaceScreen extends StatelessWidget {
  const CatalogSurfaceScreen({required this.surface, super.key});

  final AppSurface surface;

  @override
  Widget build(BuildContext context) {
    if (_isPaymentSurface(surface)) {
      return _PayComingSoonScreen(surface: surface);
    }
    final tone = _toneForModule(surface.module);
    return LoopPage(
      title: surface.title,
      eyebrow: '${surface.id} · ${_priorityLabel(surface.priority)}',
      subtitle: surface.description,
      actions: <Widget>[
        IconButton(
          onPressed: () => context.push('/inventory'),
          tooltip: 'Open UI inventory',
          icon: const Icon(Icons.grid_view_rounded),
        ),
        const SizedBox(width: 4),
      ],
      children: <Widget>[
        if (surface.retainedHistory)
          const LoopStateCard(
            title: 'Outside the current product',
            message: 'This surface is retained only as implementation history. LOOP is Spot-only and does not mount perpetual product behavior.',
            icon: Icons.archive_outlined,
            tone: LoopTone.warning,
          )
        else if (surface.deferred)
          LoopStateCard(
            title: 'Outside the current release',
            message: _deferredMessage(surface),
            icon: Icons.schedule_rounded,
            tone: surface.module == SurfaceModule.home
                ? LoopTone.warning
                : LoopTone.neutral,
          )
        else ...<Widget>[
          _SurfacePreview(surface: surface, tone: tone),
          const LoopSectionLabel('Product state'),
          LoopCard(
            child: Column(
              children: <Widget>[
                LoopKeyValueRow(label: 'Surface', value: surface.id),
                LoopKeyValueRow(label: 'Route', value: surface.path),
                LoopKeyValueRow(
                  label: 'Product priority',
                  value: _priorityLabel(surface.priority),
                ),
                LoopKeyValueRow(
                  label: 'Data state',
                  value: 'Preview · not live',
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const LoopStateCard(
            title: 'Safe preview data',
            message: 'Values on this catalog surface illustrate layout and states. No provider request or wallet mutation was made.',
            icon: Icons.visibility_outlined,
          ),
        ],
      ],
    );
  }

  static LoopTone _toneForModule(SurfaceModule module) => switch (module) {
    SurfaceModule.market ||
    SurfaceModule.perp ||
    SurfaceModule.launchpad => LoopTone.market,
    SurfaceModule.chat => LoopTone.conversation,
    SurfaceModule.wallet => LoopTone.positive,
    SurfaceModule.system => LoopTone.warning,
    _ => LoopTone.neutral,
  };

  static String _priorityLabel(ProductPriority priority) => switch (priority) {
    ProductPriority.a => 'A priority',
    ProductPriority.b => 'B priority',
    ProductPriority.c => 'C priority',
  };

  static String _deferredMessage(AppSurface surface) {
    return '${surface.title} stays visible in the product map, but no control on this preview claims the capability is live.';
  }

  static bool _isPaymentSurface(AppSurface surface) =>
      surface.path.startsWith('/pay') || surface.path == '/onramp';
}

class _PayComingSoonScreen extends StatelessWidget {
  const _PayComingSoonScreen({required this.surface});

  final AppSurface surface;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Pay',
      eyebrow:
          '${surface.id} · ${CatalogSurfaceScreen._priorityLabel(surface.priority)}',
      subtitle: 'Payment remains in the product map, but it is not part of this release.',
      children: <Widget>[
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'Product priority',
                value: CatalogSurfaceScreen._priorityLabel(surface.priority),
              ),
              const LoopKeyValueRow(
                label: 'Delivery status',
                value: 'Deferred',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Coming soon',
          message: 'Pay is not available yet. This route cannot scan a code, request camera access, collect payment details or submit a transaction.',
          icon: Icons.schedule_rounded,
          tone: LoopTone.neutral,
        ),
      ],
    );
  }
}

class _SurfacePreview extends StatelessWidget {
  const _SurfacePreview({required this.surface, required this.tone});

  final AppSurface surface;
  final LoopTone tone;

  @override
  Widget build(BuildContext context) {
    final color = loopToneColor(tone);
    return LoopCard(
      accent: true,
      tone: tone,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: LoopRadius.small,
                ),
                child: Icon(_iconFor(surface), color: color),
              ),
              const Spacer(),
              LoopStatusPill(label: surface.kind.name, tone: tone),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            _headlineFor(surface),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _bodyFor(surface),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(AppSurface surface) => switch (surface.module) {
    SurfaceModule.market => Icons.query_stats_rounded,
    SurfaceModule.perp => Icons.candlestick_chart_rounded,
    SurfaceModule.chat => Icons.forum_outlined,
    SurfaceModule.wallet => Icons.account_balance_wallet_outlined,
    SurfaceModule.launchpad => Icons.rocket_launch_outlined,
    SurfaceModule.profile => Icons.manage_accounts_outlined,
    SurfaceModule.system => Icons.layers_outlined,
    SurfaceModule.account => Icons.person_outline_rounded,
    SurfaceModule.home => Icons.space_dashboard_outlined,
  };

  static String _headlineFor(AppSurface surface) => switch (surface.kind) {
    SurfaceKind.sheet => 'A focused decision surface',
    SurfaceKind.component => 'Reusable in context',
    SurfaceKind.globalState => 'Clear recovery context',
    SurfaceKind.screen => 'A complete product route',
  };

  static String _bodyFor(AppSurface surface) => switch (surface.kind) {
    SurfaceKind.sheet => 'Critical facts stay compact, keyboard reachable and explicit before any action.',
    SurfaceKind.component => 'The component carries its source time and never silently becomes a live transaction.',
    SurfaceKind.globalState => 'The state explains what failed, what remains available and the next safe action.',
    SurfaceKind.screen => 'Loading, empty, partial and unavailable states share the same information hierarchy.',
  };
}

class UiInventoryScreen extends StatefulWidget {
  const UiInventoryScreen({super.key});

  @override
  State<UiInventoryScreen> createState() => _UiInventoryScreenState();
}

class _UiInventoryScreenState extends State<UiInventoryScreen> {
  SurfaceModule? selected;

  @override
  Widget build(BuildContext context) {
    final surfaces = selected == null
        ? SurfaceCatalog.all
        : SurfaceCatalog.forModule(selected!);
    return LoopPage(
      title: 'UI inventory',
      eyebrow: '${SurfaceCatalog.all.length} surfaces',
      subtitle: 'The implementation map for every screen, sheet, component and global state.',
      children: <Widget>[
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) => setState(() => selected = null),
                ),
              ),
              ...SurfaceModule.values.map((module) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(module.name),
                    selected: selected == module,
                    onSelected: (_) => setState(() => selected = module),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...surfaces.map((surface) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: LoopCard(
              onTap: surface.retainedHistory
                  ? null
                  : () => context.push(surface.path),
              semanticLabel: surface.retainedHistory
                  ? '${surface.title} is outside the current product'
                  : 'Open ${surface.title}',
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 35,
                    child: Text(
                      surface.id,
                      style: context.dataStyle.copyWith(color: LoopColors.mint),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          surface.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          surface.path,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  if (surface.retainedHistory)
                    const LoopStatusPill(
                      label: 'Out of scope',
                      tone: LoopTone.warning,
                    )
                  else if (surface.deferred)
                    const LoopStatusPill(label: 'Deferred')
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: LoopColors.vapor,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
