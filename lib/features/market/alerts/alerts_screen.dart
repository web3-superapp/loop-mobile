import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_controller.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `alerts` · price alerts plus the context notification feed.
///
/// The threshold is a decimal STRING end to end: it is validated against the
/// contract pattern here and sent verbatim, because a JSON number is rejected
/// by the server before type coercion. Distance to target is computed on the
/// client from the current market price and is never a server fact.
class PriceAlertsScreen extends ConsumerStatefulWidget {
  const PriceAlertsScreen({
    super.key,
    this.assetId,
    this.onBack,
    this.onNavigate,
  });

  /// Optional: pre-selects the asset when the page is opened from `token`.
  final String? assetId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends ConsumerState<PriceAlertsScreen> {
  /// Set once the owner asks to see every alert, after arriving from one
  /// asset's own bell.
  bool _showEveryAsset = false;

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.priceAlerts),
    );
    final mode = ref.watch(alertsGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(alertsControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(alertsControllerProvider.notifier).load());
        }
      });
    }
    final controller = ref.read(alertsControllerProvider.notifier);
    // The bell on a token page asks about that token. It used to open the
    // whole list — 25 alerts across every asset — with nothing saying why.
    // The page narrows to the asset it was opened for and offers the full
    // list as an explicit step.
    final focusAssetId = _showEveryAsset ? null : widget.assetId;
    final visible = focusAssetId == null
        ? state.items
        : state.items
              .where((alert) => alert.assetId == focusAssetId)
              .toList(growable: false);
    final focusLabel = focusAssetId == null
        ? null
        : _assetChoiceFor(focusAssetId, null)?.label ??
              loopTruncatedAssetId(focusAssetId);
    final armed = focusAssetId == null
        ? (state.page?.armed ?? const <LoopPriceAlert>[])
        : visible
              .where((alert) => alert.state == LoopAlertState.active)
              .toList(growable: false);
    // `entityRef` is `priceAlert:<alertId>`, so a feed entry points at exactly
    // one row. Highlighting is driven by that reference, never by matching a
    // symbol or a threshold the two objects happen to share.
    final triggered = _triggeredAlertIds(ref);

    return LoopDashboardPage(
      key: const ValueKey<String>('alerts-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.listing,
      title: '价格提醒',
      onBack: widget.onBack,
      actions: <Widget>[
        // `.topbar .seg`: the prototype's 新建 text pill. A bell glyph here
        // reads as「打开通知」, not「新建一条提醒」(audit 2026-09-21 §G.7).
        LoopSeg(
          key: const ValueKey<String>('alerts-create-action'),
          label: '新建',
          selected: false,
          onSelected: blocked || state.busy
              ? null
              : () => unawaited(
                  _openEditor(
                    controller,
                    presetAssetId: _showEveryAsset ? null : widget.assetId,
                  ),
                ),
        ),
      ],
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('alerts-folio'),
        variant: LoopFolioVariant.chalk,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: marketAlertsKicker,
        // The list answers one cursor page at a time and the response carries
        // no total, so the armed count describes this page only. It is stated
        // as a count of what is listening exactly when the last page is in;
        // before that the hero says how many rows it has loaded.
        heading: !state.isReady
            ? '价格提醒'
            : focusLabel != null
            ? '$focusLabel · ${armed.length} 个提醒正在监听'
            : state.page!.nextCursor != null
            ? '已载入 ${state.items.length} 条提醒'
            : '${armed.length} 个提醒正在监听',
        caption: focusLabel != null
            ? '只显示这个资产的提醒。触发一次后提醒会停下来，重新编辑才会再次生效。'
            : state.isReady && state.page!.nextCursor != null
            ? '这一页之后还有提醒没有载入。触发一次后提醒会停下来，重新编辑才会再次生效。'
            : '触发一次后提醒会停下来，重新编辑才会再次生效。',
        // No stamp: the prototype's `.folio-stamp` carries a settled reading,
        // never a state name, and 「9 ACTIVE」 restated the heading in English
        // over a figure that only counted one page.
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('alerts-capability-block'),
              title: '价格提醒当前不可用',
              capability: capability,
              fallbackReasonCode: 'ALERTS_RUNTIME_UNAVAILABLE',
            )
          : null,
      sections: <Widget>[
        if (!state.isReady)
          LoopChainStateBlock(
            keyPrefix: 'alerts',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '还没有价格提醒',
            emptyReason: '新建一个提醒后，评估器会在价格新鲜时检查它。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // A command that never reached the server created, changed and
          // deleted nothing. The list below is still the server's own answer.
          if (state.failureKind == LoopChainFailureKind.offline)
            LoopOfflineState(
              key: const ValueKey<String>('alerts-command-offline'),
              pausedActions: const <String>['新建提醒', '修改提醒', '删除提醒'],
              onRetry: () => unawaited(controller.reload()),
            )
          else if (LoopChainCommandPermission.covers(state.failureKind))
            LoopChainCommandPermission(
              blockKey: 'alerts-command-permission',
              failureKind: state.failureKind,
              title: '当前账号无权修改价格提醒',
              onOpenSecurity: () => _open('/profile/security'),
            )
          else if (state.failureKind != null)
            LoopErrorState(
              key: const ValueKey<String>('alerts-command-error'),
              title: '提醒没有更新',
              reason: loopChainFailureReason(state.failureKind),
              onRetry: () => unawaited(controller.reload()),
            ),
          const LoopLabel('已设提醒'),
          if (visible.isEmpty)
            LoopEmpty(
              key: const ValueKey<String>('alerts-empty'),
              message: focusLabel == null ? '还没有价格提醒' : '$focusLabel 还没有提醒',
              reason: '新建一个提醒后，评估器会在价格新鲜时检查它。',
              action: LoopButton(
                key: const ValueKey<String>('alerts-empty-create'),
                label: '新建提醒',
                onPressed: () => unawaited(
                  _openEditor(controller, presetAssetId: focusAssetId),
                ),
              ),
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final alert in visible)
                  _alertRow(
                    alert,
                    controller,
                    highlighted: triggered.contains(alert.alertId),
                  ),
              ],
            ),
          // The narrowed list says so, and says where the rest went. Without
          // this the page looks like the whole list with rows missing.
          if (focusAssetId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: LoopButton(
                key: const ValueKey<String>('alerts-show-every-asset'),
                label: '查看全部资产的提醒',
                block: true,
                onPressed: () => setState(() => _showEveryAsset = true),
              ),
            ),
          const LoopLabel('触发历史'),
          _AlertNotificationFeed(
            alertIds: focusAssetId == null
                ? null
                : <String>{for (final alert in visible) alert.alertId},
          ),
          const LoopNotice(
            key: ValueKey<String>('alerts-push-notice'),
            title: '推送尚不可用',
            body: '推送还没有开放，提醒只出现在应用内的通知列表里。只有最新价格会触发提醒。',
            tone: LoopNoticeTone.warn,
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('alerts-notification-settings'),
                title: '通知设置',
                subtitle: '关闭价格提醒类别后仍会记录事件，但不会生成通知',
                onTap: () => _open('/profile/notifications'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// The alert ids the feed says have fired, taken from each entry's
  /// `entityRef`. An entry with no parsable reference contributes nothing.
  Set<String> _triggeredAlertIds(WidgetRef ref) {
    final feed = ref.watch(notificationFeedControllerProvider).value;
    if (feed == null) return const <String>{};
    return <String>{for (final entry in feed.priceAlerts) ?entry.priceAlertId};
  }

  LoopRecordRow _alertRow(
    LoopPriceAlert alert,
    AlertsController controller, {
    bool highlighted = false,
  }) {
    final currentPrice = _currentPriceFor(alert.assetId);
    final distance = alert.distancePercent(currentPrice);
    return LoopRecordRow(
      // The key stays the alert's identity. A key that changed with the feed
      // would remount the row on every refresh; the highlight is carried by
      // the badge and the subtitle instead.
      key: ValueKey<String>('alert-${alert.alertId}'),
      // `.row-ico`: the prototype heads every alert with the asset's own
      // token mark, so a list of thresholds is read by its assets first. The
      // artwork comes from the same market read this row already watches for
      // the current price (decision 0072/0086); the alert resource publishes
      // none of its own.
      leading: LoopTokenLogo(
        assetSymbol: alert.displayName,
        logoUrl: _logoFor(alert.assetId),
        fallbackMonogram: alert.displayName,
      ),
      // The threshold keeps its exact characters; only the separators that
      // cannot change it are added, so 900000 stops being seven digits to
      // count.
      title:
          '${alert.displayName} ${alert.condition.label} '
          '${loopGroupedFigure(alert.thresholdText)}',
      subtitle: <String>[
        if (highlighted) '通知已记录这次触发',
        alert.state.label,
        if (distance != null) '距目标 ${loopFormatPercent(distance)}',
        if (alert.lastEvaluatedAt == null)
          '评估器还没有看过这条'
        else
          '评估于 ${loopRelativeTime(alert.lastEvaluatedAt!)}',
      ].join(' · '),
      // Four facts do not fit one line: 「距目标 -5....」 cut a number in the
      // middle of its decimals.
      subtitleMaxLines: 2,
      trailingBadge: LoopBadge(
        highlighted ? '本次触发' : alert.state.label,
        kind: switch (alert.state) {
          LoopAlertState.active => LoopBadgeKind.up,
          LoopAlertState.triggered => LoopBadgeKind.mining,
          LoopAlertState.expired => LoopBadgeKind.mute,
        },
      ),
      onTap: () => unawaited(_openEditor(controller, existing: alert)),
    );
  }

  Decimal? _currentPriceFor(String assetId) {
    final detail = ref.watch(marketAssetControllerProvider(assetId)).value;
    return detail?.price.value;
  }

  /// The asset's published artwork, from the same read as the current price.
  String? _logoFor(String assetId) =>
      ref.watch(marketAssetControllerProvider(assetId)).value?.logoUrl;

  /// The name, symbol and id of one asset, resolved from whatever this page
  /// already read.
  ///
  /// The editor used to print the raw `eip155:56:0x0e09…` into an editable
  /// field. A CAIP id is an opaque identifier: it is not a name, the person
  /// setting a threshold cannot check it, and typing into it could only ever
  /// produce a different asset or an invalid one.
  _AlertAssetChoice? _assetChoiceFor(String assetId, LoopPriceAlert? existing) {
    final detail = ref.watch(marketAssetControllerProvider(assetId)).value;
    final summary = existing?.asset;
    if (summary != null) {
      return _AlertAssetChoice(
        assetId: assetId,
        symbol: summary.symbol,
        name: summary.name,
        logoUrl: detail?.logoUrl,
      );
    }
    final settled = detail?.asset.settled;
    if (settled == null) return null;
    return _AlertAssetChoice(
      assetId: assetId,
      symbol: settled.symbol,
      name: settled.name,
      logoUrl: detail?.logoUrl,
    );
  }

  Future<void> _openEditor(
    AlertsController controller, {
    LoopPriceAlert? existing,
    String? presetAssetId,
  }) async {
    final assetId = existing?.assetId ?? presetAssetId;
    final result = await showModalBottomSheet<_AlertEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AlertEditorSheet(
        existing: existing,
        initialAssetId: assetId,
        initialChoice: assetId == null
            ? null
            : _assetChoiceFor(assetId, existing),
      ),
    );
    if (result == null || !mounted) return;
    final bool applied;
    if (result.delete && existing != null) {
      applied = await controller.delete(existing);
    } else if (existing != null) {
      applied = await controller.update(alert: existing, draft: result.draft!);
    } else {
      applied = await controller.create(result.draft!);
    }
    if (!mounted) return;
    if (applied) {
      LoopToast.show(
        context,
        message: result.delete ? '提醒已删除' : '提醒已保存',
        kind: LoopToastKind.ok,
      );
    }
  }
}

/// `.row-ico` with a check: one triggered record.
class _TriggeredAvatar extends StatelessWidget {
  const _TriggeredAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.limeSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const LoopIcon('check', size: 18, color: LoopColors.lime),
    );
  }
}

class _AlertEditorResult {
  const _AlertEditorResult({this.draft, this.delete = false});

  final LoopAlertDraft? draft;
  final bool delete;
}

/// One asset the editor can point at, with the two things a reader checks.
@immutable
final class _AlertAssetChoice {
  const _AlertAssetChoice({
    required this.assetId,
    required this.symbol,
    required this.name,
    this.logoUrl,
  });

  final String assetId;
  final String? symbol;
  final String? name;

  /// The registry's published artwork for this asset (decision 0072).
  final String? logoUrl;

  /// 「PEPE · Pepe」 — never the CAIP id, unless nothing named the asset, in
  /// which case the truncated id speaks for itself rather than a made-up
  /// ticker.
  String get label =>
      <String>[
        ?symbol,
        ?name,
      ].where((part) => part.isNotEmpty).toSet().join(' · ').isEmpty
      ? loopTruncatedAssetId(assetId)
      : <String>[
          ?symbol,
          ?name,
        ].where((part) => part.isNotEmpty).toSet().join(' · ');

  String get monogram => symbol ?? name ?? assetId;
}

/// zh-CN explanation of one condition, in the two words that separate them.
///
/// 涨破 / 涨到 / 跌破 / 跌到 differ by one character, and the four of them in a
/// column read as four buttons rather than one choice. They are one segmented
/// control now, and the sentence under it says which comparison the chosen
/// one makes — 到达 is `≥` / `≤`, 突破 is strict.
String alertConditionExplanation(LoopAlertCondition condition) =>
    switch (condition) {
      LoopAlertCondition.above => '突破：价格必须高于阈值（> 阈值）才触发，正好等于阈值不算。',
      LoopAlertCondition.atOrAbove => '到达：价格达到或高于阈值（≥ 阈值）就触发。',
      LoopAlertCondition.below => '突破：价格必须低于阈值（< 阈值）才触发，正好等于阈值不算。',
      LoopAlertCondition.atOrBelow => '到达：价格达到或低于阈值（≤ 阈值）就触发。',
    };

class _AlertEditorSheet extends ConsumerStatefulWidget {
  const _AlertEditorSheet({
    required this.existing,
    required this.initialAssetId,
    required this.initialChoice,
  });

  final LoopPriceAlert? existing;
  final String? initialAssetId;
  final _AlertAssetChoice? initialChoice;

  @override
  ConsumerState<_AlertEditorSheet> createState() => _AlertEditorSheetState();
}

class _AlertEditorSheetState extends ConsumerState<_AlertEditorSheet> {
  late final TextEditingController _thresholdController;
  late LoopAlertCondition _condition;
  late _AlertAssetChoice? _choice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _choice =
        widget.initialChoice ??
        (widget.initialAssetId == null
            ? null
            : _AlertAssetChoice(
                assetId: widget.initialAssetId!,
                symbol: null,
                name: null,
              ));
    _thresholdController = TextEditingController(
      text: widget.existing?.thresholdText ?? '',
    );
    _condition = widget.existing?.condition ?? LoopAlertCondition.atOrAbove;
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  void _submit() {
    final choice = _choice;
    if (choice == null) {
      setState(() => _error = '先选择要监听的资产。');
      return;
    }
    final draft = LoopAlertDraft(
      assetId: choice.assetId,
      condition: _condition,
      threshold: _thresholdController.text.trim(),
      expiresAt: widget.existing?.expiresAt,
    );
    final invalid = draft.invalidField;
    if (invalid != null) {
      setState(() {
        _error = switch (invalid) {
          'assetId' => '这个资产不能用于价格提醒，请换一个。',
          'threshold' => '阈值必须是正的十进制数字，最多 18 位小数。',
          _ => '过期时间必须在未来。',
        };
      });
      return;
    }
    Navigator.of(context).pop(_AlertEditorResult(draft: draft));
  }

  /// Picks the asset out of the owner's own watchlist.
  ///
  /// The watchlist is the only list of assets this account has already said
  /// it cares about, and every row in it carries a name. There is no free
  /// text: an id typed by hand is either an asset that is already reachable
  /// from the token page's bell, or a mistake.
  Future<void> _pickAsset() async {
    final picked = await showLoopSheet<_AlertAssetChoice>(
      context,
      builder: (sheetContext) => const _AlertAssetPickerSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _choice = picked;
      _error = null;
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showLoopSheet<bool>(
      context,
      builder: (sheetContext) => LoopSheet(
        key: const ValueKey<String>('alert-delete-confirm'),
        title: '删除这个提醒？',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const LoopNotice(
              key: ValueKey<String>('alert-delete-confirm-body'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '删除之后不会再监听这个价格',
              body: '已经触发过的记录留在触发历史里，不会被删掉。',
              margin: EdgeInsets.fromLTRB(0, 0, 0, 12),
            ),
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  label: '不删除',
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
                LoopButton(
                  key: const ValueKey<String>('alert-delete-confirm-yes'),
                  label: '删除',
                  primary: true,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(const _AlertEditorResult(delete: true));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final choice = _choice;
    return LoopSheet(
      title: existing == null ? '新建价格提醒' : '编辑价格提醒',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const LoopLabel('资产'),
          if (choice == null)
            LoopButton(
              key: const ValueKey<String>('alert-asset-pick'),
              label: '从自选里选择资产',
              block: true,
              onPressed: () => unawaited(_pickAsset()),
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('alert-asset-row'),
                  leading: LoopTokenLogo(
                    assetSymbol:
                        choice.symbol ?? loopTruncatedAssetId(choice.assetId),
                    logoUrl: choice.logoUrl,
                    fallbackMonogram: choice.monogram,
                  ),
                  title: choice.symbol ?? loopTruncatedAssetId(choice.assetId),
                  subtitle: choice.name ?? '这个资产的名称暂时读不到',
                  // An existing alert is bound to its asset: the contract has
                  // no way to move one, so this row is a fact, not a control.
                  onTap: existing == null
                      ? () => unawaited(_pickAsset())
                      : null,
                  trailingBadge: existing == null
                      ? const LoopBadge('可更换')
                      : const LoopBadge('不可更换', kind: LoopBadgeKind.mute),
                ),
              ],
            ),
          const SizedBox(height: 12),
          const LoopLabel('触发条件'),
          // `.segs`: one row, four segments — the same control the prototype
          // uses everywhere a choice is exclusive.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final (index, condition)
                    in LoopAlertCondition.values.indexed) ...<Widget>[
                  if (index > 0) const SizedBox(width: 8),
                  LoopSeg(
                    key: ValueKey<String>(
                      'alert-condition-${condition.wireName}',
                    ),
                    label: condition.label,
                    selected: condition == _condition,
                    onSelected: () => setState(() => _condition = condition),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            alertConditionExplanation(_condition),
            key: const ValueKey<String>('alert-condition-explanation'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('alert-threshold-field'),
            controller: _thresholdController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // The threshold never becomes a `double`: it stays the exact text
            // the user typed all the way to the wire.
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: '阈值（USD）',
              hintText: '例如 800.5',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const ValueKey<String>('alert-editor-error'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
          const SizedBox(height: 16),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                label: '取消',
                onPressed: () => Navigator.of(context).pop(),
              ),
              LoopButton(
                key: const ValueKey<String>('alert-editor-submit'),
                label: '保存',
                primary: true,
                onPressed: _submit,
              ),
            ],
          ),
          // 删除 is not a peer of 保存: it used to sit directly under it, full
          // width, one thumb-width from the primary action of the sheet. It
          // is a secondary text control now, and it asks first.
          if (existing != null) ...<Widget>[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                key: const ValueKey<String>('alert-editor-delete'),
                onPressed: () => unawaited(_confirmDelete()),
                child: const Text('删除这个提醒'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The watchlist, as a list of assets one alert can point at.
class _AlertAssetPickerSheet extends ConsumerStatefulWidget {
  const _AlertAssetPickerSheet();

  @override
  ConsumerState<_AlertAssetPickerSheet> createState() =>
      _AlertAssetPickerSheetState();
}

class _AlertAssetPickerSheetState
    extends ConsumerState<_AlertAssetPickerSheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchlistEditorControllerProvider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(watchlistEditorControllerProvider.notifier).load(),
          );
        }
      });
    }
    final items = <String, WatchlistItem>{};
    for (final group in state.groups) {
      for (final item in group.items) {
        items.putIfAbsent(item.assetId, () => item);
      }
    }
    return LoopSheet(
      key: const ValueKey<String>('alert-asset-picker'),
      title: '选择资产',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!state.isReady)
            LoopChainStateBlock(
              keyPrefix: 'alert-asset-picker',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '自选列表还没有读到',
              onRetry: () => unawaited(
                ref.read(watchlistEditorControllerProvider.notifier).reload(),
              ),
            )
          else if (items.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('alert-asset-picker-empty'),
              message: '自选里还没有资产',
              reason: '先在行情页把资产加入自选，或者直接在代币页用提醒入口新建。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final item in items.values)
                  LoopRecordRow(
                    key: ValueKey<String>('alert-asset-pick-${item.assetId}'),
                    leading: LoopTokenLogo(
                      assetSymbol:
                          item.asset?.symbol ??
                          loopTruncatedAssetId(item.assetId),
                      logoUrl: item.logoUrl,
                      fallbackMonogram:
                          item.asset?.symbol ??
                          loopTruncatedAssetId(item.assetId),
                    ),
                    title:
                        item.asset?.symbol ??
                        loopTruncatedAssetId(item.assetId),
                    subtitle: item.asset?.name ?? '这个资产的名称暂时读不到',
                    onTap: () => Navigator.of(context).pop(
                      _AlertAssetChoice(
                        assetId: item.assetId,
                        symbol: item.asset?.symbol,
                        name: item.asset?.name,
                        logoUrl: item.logoUrl,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The trigger history: the feed entries whose type is `trade.priceAlert`.
class _AlertNotificationFeed extends ConsumerStatefulWidget {
  const _AlertNotificationFeed({this.alertIds});

  /// When the page is narrowed to one asset, only that asset's own alert ids.
  /// `null` is the whole feed.
  final Set<String>? alertIds;

  @override
  ConsumerState<_AlertNotificationFeed> createState() =>
      _AlertNotificationFeedState();
}

class _AlertNotificationFeedState
    extends ConsumerState<_AlertNotificationFeed> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationFeedControllerProvider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(notificationFeedControllerProvider.notifier).load(),
          );
        }
      });
    }
    final feed = state.value;
    if (feed == null) {
      return LoopChainStateBlock(
        keyPrefix: 'alerts-feed',
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 2,
        emptyMessage: '还没有触发记录',
        onRetry: () => unawaited(
          ref.read(notificationFeedControllerProvider.notifier).reload(),
        ),
      );
    }
    final ids = widget.alertIds;
    final entries = ids == null
        ? feed.priceAlerts
        : feed.priceAlerts
              .where((entry) => ids.contains(entry.priceAlertId))
              .toList(growable: false);
    final more = feed.nextCursor != null;
    if (entries.isEmpty && !more) {
      return const LoopEmpty(
        key: ValueKey<String>('alerts-feed-empty'),
        message: '还没有触发记录',
        reason: '提醒触发后会在这里留下一条记录，标注出处和时间。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (entries.isEmpty)
          const LoopEmpty(
            key: ValueKey<String>('alerts-feed-empty-page'),
            message: '这一页没有价格提醒的记录',
            reason: '后面还有记录，载入下一页再看。',
          )
        else
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final entry in entries)
                LoopRecordRow(
                  key: ValueKey<String>('alerts-feed-${entry.notificationId}'),
                  // The prototype's 触发历史 rows carry a check mark, which
                  // is what tells them apart from the armed list above.
                  leading: const _TriggeredAvatar(),
                  title: _feedTitle(entry),
                  subtitle: _feedDetail(entry),
                  subtitleMaxLines: 2,
                  trailingBadge: entry.isUnread ? const LoopBadge('未读') : null,
                  onTap: entry.isUnread
                      ? () => unawaited(
                          ref
                              .read(notificationFeedControllerProvider.notifier)
                              .markRead(entry.notificationId),
                        )
                      : null,
                ),
            ],
          ),
        // The feed is a cursor page, not the whole history: without this the
        // page after the first one was unreachable and the list ended in
        // silence, which reads as "that is everything".
        if (more)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('alerts-feed-load-more'),
              label: state.busy ? '正在载入…' : '载入更多',
              block: true,
              onPressed: state.busy
                  ? null
                  : () => unawaited(
                      ref
                          .read(notificationFeedControllerProvider.notifier)
                          .loadMore(),
                    ),
            ),
          )
        else
          const LoopProvenanceFooter(
            key: ValueKey<String>('alerts-feed-end'),
            text: '没有更多触发记录',
          ),
        // The push reason is the notice below this block, printed once: the
        // footer used to carry the same sentence two lines above it.
        LoopProvenanceFooter(
          key: const ValueKey<String>('alerts-feed-unread'),
          text: '未读 ${feed.unreadCount} 条',
        ),
      ],
    );
  }
}

String _feedTitle(LoopNotificationEntry entry) {
  final symbol = entry.payload['symbol'];
  final threshold = entry.payload['threshold'];
  final observed = entry.payload['observedValue'];
  if (symbol == null || threshold == null || observed == null) {
    return '价格提醒已触发';
  }
  return '$symbol 触发 $threshold（观察值 $observed）';
}

String _feedDetail(LoopNotificationEntry entry) {
  final source = entry.source;
  final observedAt = entry.observedAt;
  // The alert id is an internal identifier: it addresses the row this entry
  // highlights and says nothing a reader can act on. Printed, it came out as
  // "提醒 a2b2c1ce-4ca9…" — half a UUID on a line that already names the
  // asset and the threshold.
  //
  // `source` is the same kind of thing until it names a provider. The
  // notification contract leaves it an open `[a-z][a-z0-9_]*` identifier, so
  // it can and does arrive as a pipeline name — every row on the review
  // device read 「来源 mock_seed」. A value that maps onto a provider LOOP
  // already names elsewhere prints as that provider; anything else is an
  // internal string and the segment is dropped, because a source a reader
  // cannot check is not provenance.
  final provenance = loopNotificationSourceLabel(source);
  return <String>[
    ?provenance,
    if (observedAt != null) '观察于 ${loopRelativeTime(observedAt)}',
  ].join(' · ');
}
