import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

/// System and component-state pages (manifest module 8 plus the two
/// module-0 gates `force-update` / `region-blocked`).
///
/// Principle kept from the previous implementation: a page renders a real
/// state only when its owner supplies a typed observation. Opening a route
/// proves nothing. Without an observation the page shows the prototype
/// layout with an explicit "来源未接入" notice and never a figure.
enum LoopConnectivityScope {
  fullyOffline,
  marketDataUnavailable,
  tradingServiceUnavailable,
}

/// Explicit connectivity evidence supplied by the owner of the request that
/// failed. The page never derives any of it from opening the route.
@immutable
final class LoopConnectivityObservation {
  const LoopConnectivityObservation({
    required this.scope,
    this.lastSyncAt,
    this.partialOutage,
  });

  final LoopConnectivityScope scope;

  /// When the cached data on the other pages was last synced. Null means the
  /// owner did not record one, and the kicker then states the device state.
  final DateTime? lastSyncAt;

  /// One named chain or service that is down while the rest of LOOP works
  /// (prototype `offline.html` 部分故障 block). Null keeps that block
  /// unavailable: per-chain availability has no connected source yet.
  final LoopPartialOutage? partialOutage;

  /// `LAST SYNC · HH:mm` in the device's own zone, or null.
  String? get lastSyncKicker {
    final value = lastSyncAt;
    if (value == null) return null;
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'LAST SYNC · $hour:$minute';
  }
}

/// A single chain or service outage reported by an approved source.
@immutable
final class LoopPartialOutage {
  const LoopPartialOutage({required this.networkLabel, this.detail});

  /// e.g. `BSC`; a display label chosen by the owner, never inferred.
  final String networkLabel;
  final String? detail;
}

enum LoopPermissionKind { camera, notifications, microphone }

enum LoopPermissionPromptMode { education, settingsRecovery }

enum LoopNoticeKind { success, warning, error }

enum LoopSkeletonKind { list, detail, chart }

typedef SystemAction = void Function();

/// Presentation-safe evidence of an error or unconfirmed request outcome.
/// [traceId] and [statusLabel] are display-ready strings chosen by the owner;
/// raw exceptions, payloads and retry semantics stay with the owner.
@immutable
final class LoopServiceErrorObservation {
  const LoopServiceErrorObservation({this.traceId, this.statusLabel});

  final String? traceId;
  final String? statusLabel;
}

/// Evidence that an approved version policy blocks this build.
///
/// Decision 0029 has two floors. [forceUpdateBelow] is the hard floor that
/// produced this block; [minimumSupportedVersion] is the softer
/// `minimumSupportedVersions[platform]` value and is shown only when the
/// policy stated one. They are never merged into a single "minimum".
@immutable
final class LoopForceUpdateRequirement {
  const LoopForceUpdateRequirement({
    this.forceUpdateBelow,
    this.minimumSupportedVersion,
    this.configVersion,
    this.storeUrl,
  });

  final String? forceUpdateBelow;
  final String? minimumSupportedVersion;
  final String? configVersion;
  final Uri? storeUrl;
}

/// Evidence that an approved maintenance notice is currently active.
@immutable
final class LoopMaintenanceNotice {
  const LoopMaintenanceNotice({this.windowLabel, this.detail});

  /// e.g. `03:00–05:00 UTC`; null when the source did not state a window.
  final String? windowLabel;

  /// Owner-supplied fact line (e.g. what stays read-only).
  final String? detail;
}

/// Evidence that an approved current decision restricts feature availability.
@immutable
final class LoopFeatureAvailabilityRestriction {
  const LoopFeatureAvailabilityRestriction({
    this.reasonCode,
    this.supportUrl,
    this.readOnlyAssetAccess,
  });

  final String? reasonCode;
  final Uri? supportUrl;
  final bool? readOnlyAssetAccess;
}

@immutable
final class LoopPermissionPrompt {
  const LoopPermissionPrompt({required this.kind, required this.mode});

  final LoopPermissionKind kind;
  final LoopPermissionPromptMode mode;
}

/// Presentation-safe feedback supplied by the exact feature that observed it.
@immutable
final class LoopGlobalFeedback {
  const LoopGlobalFeedback({
    required this.kind,
    required this.message,
    this.actionLabel,
  });

  final LoopNoticeKind kind;
  final String message;
  final String? actionLabel;

  String? get presentationMessage {
    final value = message.trim();
    return value.isEmpty ? null : value;
  }

  String? get presentationActionLabel {
    final value = actionLabel?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

/// A bounded skeleton selected by the exact feature that currently owns load.
@immutable
final class LoopLoadingPresentation {
  const LoopLoadingPresentation.list({this.placeholderCount = 4})
    : kind = LoopSkeletonKind.list;

  const LoopLoadingPresentation.detail()
    : kind = LoopSkeletonKind.detail,
      placeholderCount = 0;

  const LoopLoadingPresentation.chart()
    : kind = LoopSkeletonKind.chart,
      placeholderCount = 0;

  static const minListPlaceholders = 1;
  static const maxListPlaceholders = 8;

  final LoopSkeletonKind kind;
  final int placeholderCount;

  bool get isPresentable => switch (kind) {
    LoopSkeletonKind.list =>
      placeholderCount >= minListPlaceholders &&
          placeholderCount <= maxListPlaceholders,
    LoopSkeletonKind.detail || LoopSkeletonKind.chart => true,
  };
}

/// One Token Card example for the `token-card-states` showcase.
@immutable
final class LoopTokenCardShowcaseItem {
  const LoopTokenCardShowcaseItem({
    required this.label,
    required this.state,
    required this.model,
    this.actions = const <LoopTokenCardAction>[],
  });

  final String label;
  final LoopTokenCardState state;
  final LoopTokenCardModel model;
  final List<LoopTokenCardAction> actions;
}

/// One sign-sheet example for the `sign-sheet-states` showcase.
@immutable
final class LoopSignSheetShowcaseItem {
  const LoopSignSheetShowcaseItem({
    required this.label,
    required this.state,
    required this.facts,
    this.reason,
  });

  final String label;
  final LoopSignSheetState state;
  final List<LoopSignFact> facts;
  final String? reason;
}

/// Component showcase fixtures. They carry figures, so only the explicit
/// Development Preview root may supply them (labelled `演示数据`).
/// Production keeps [loopSystemShowcaseProvider] at `null`.
@immutable
final class LoopSystemShowcase {
  const LoopSystemShowcase({
    required this.sourceLabel,
    this.tokenCards = const <LoopTokenCardShowcaseItem>[],
    this.signSheets = const <LoopSignSheetShowcaseItem>[],
  });

  final String sourceLabel;
  final List<LoopTokenCardShowcaseItem> tokenCards;
  final List<LoopSignSheetShowcaseItem> signSheets;
}

final loopSystemShowcaseProvider = Provider<LoopSystemShowcase?>((ref) => null);

/// Single routing surface for the system and component-state pages.
class SystemSurfaceScreen extends StatelessWidget {
  const SystemSurfaceScreen.fromId(
    this.surfaceId, {
    super.key,
    this.onRetry,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.onServiceRetry,
    this.onServiceSupport,
    this.onForceUpdate,
    this.onMaintenanceRecheck,
    this.onMaintenanceStatus,
    this.onMaintenanceReadOnly,
    this.onRegionContinue,
    this.onRegionPolicy,
    this.onPermissionRequest,
    this.onPermissionOpenSettings,
    this.onPermissionNotNow,
    this.onFeedbackAction,
    this.onFeedbackDismiss,
    this.onBack,
    this.connectivityObservation,
    this.serviceErrorObservation,
    this.forceUpdateRequirement,
    this.maintenanceNotice,
    this.featureAvailabilityRestriction,
    this.permissionPrompt,
    this.globalFeedback,
    this.loadingPresentation,
    this.showcase,
  });

  static const supportedIds = <String>{
    'offline',
    'server-error',
    'force-update',
    'maintenance',
    'region-restricted',
    'permission',
    'toast',
    'loading',
    'token-card-states',
    'sign-sheet-states',
  };

  final String surfaceId;
  final SystemAction? onRetry;
  final SystemAction? onPrimaryAction;

  /// Generic "return to LOOP" used only by unavailable states.
  final SystemAction? onSecondaryAction;
  final SystemAction? onServiceRetry;
  final SystemAction? onServiceSupport;
  final SystemAction? onForceUpdate;
  final SystemAction? onMaintenanceRecheck;
  final SystemAction? onMaintenanceStatus;

  /// Dedicated "view read-only content" action for an active maintenance
  /// notice. The generic secondary action stays out of every explicit state.
  final SystemAction? onMaintenanceReadOnly;
  final SystemAction? onRegionContinue;
  final SystemAction? onRegionPolicy;
  final SystemAction? onPermissionRequest;
  final SystemAction? onPermissionOpenSettings;
  final SystemAction? onPermissionNotNow;
  final SystemAction? onFeedbackAction;
  final SystemAction? onFeedbackDismiss;

  /// Topbar back. Null hides the back button (blocking pages).
  final SystemAction? onBack;
  final LoopConnectivityObservation? connectivityObservation;
  final LoopServiceErrorObservation? serviceErrorObservation;
  final LoopForceUpdateRequirement? forceUpdateRequirement;
  final LoopMaintenanceNotice? maintenanceNotice;
  final LoopFeatureAvailabilityRestriction? featureAvailabilityRestriction;
  final LoopPermissionPrompt? permissionPrompt;
  final LoopGlobalFeedback? globalFeedback;
  final LoopLoadingPresentation? loadingPresentation;
  final LoopSystemShowcase? showcase;

  String get _id => surfaceId.replaceFirst('#', '').toLowerCase();

  @override
  Widget build(BuildContext context) {
    return switch (_id) {
      'offline' => _OfflinePage(
        observation: connectivityObservation,
        onRetry: onRetry,
        onContinue: onSecondaryAction,
        onBack: onBack,
      ),
      'server-error' => _ServerErrorPage(
        observation: serviceErrorObservation,
        onRetry: onServiceRetry,
        onSupport: onServiceSupport,
        onContinue: onSecondaryAction,
        onBack: onBack,
      ),
      'force-update' => _ForceUpdatePage(
        requirement: forceUpdateRequirement,
        onUpdate: onForceUpdate,
        onContinue: onSecondaryAction,
        onBack: onBack,
      ),
      'maintenance' => _MaintenancePage(
        notice: maintenanceNotice,
        onRecheck: onMaintenanceRecheck,
        onStatus: onMaintenanceStatus,
        onReadOnly: onMaintenanceReadOnly,
        onContinue: onSecondaryAction,
        onBack: onBack,
      ),
      'region-restricted' => _RegionPage(
        restriction: featureAvailabilityRestriction,
        onContinue: onRegionContinue,
        onPolicy: onRegionPolicy,
        onReturn: onSecondaryAction,
        onBack: onBack,
      ),
      'permission' => _PermissionPage(
        prompt: permissionPrompt,
        onRequest: onPermissionRequest,
        onOpenSettings: onPermissionOpenSettings,
        onNotNow: onPermissionNotNow,
        onContinue: onSecondaryAction,
        onBack: onBack,
      ),
      'toast' => _ToastStatesPage(
        feedback: globalFeedback,
        onAction: onFeedbackAction,
        onDismiss: onFeedbackDismiss,
        onBack: onBack,
      ),
      'loading' => _SkeletonStatesPage(
        presentation: loadingPresentation,
        onBack: onBack,
      ),
      'token-card-states' => _TokenCardStatesPage(
        showcase: showcase,
        onBack: onBack,
        onContinue: onSecondaryAction,
      ),
      'sign-sheet-states' => _SignSheetStatesPage(
        showcase: showcase,
        onBack: onBack,
        onContinue: onSecondaryAction,
      ),
      _ => _UnknownSystemPage(onBack: onBack),
    };
  }
}

// ---------------------------------------------------------------------------
// Reusable pieces kept for feature slices (Market uses the skeleton view).
// ---------------------------------------------------------------------------

/// Compact app-wide connectivity banner.
class LoopConnectivityBanner extends StatelessWidget {
  const LoopConnectivityBanner({required this.scope, super.key, this.onRetry});

  final LoopConnectivityScope scope;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final content = _connectivityCopy(scope);
    return Material(
      color: LoopColors.card2,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          label: '${content.title}。${content.body}',
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: LoopColors.line2)),
            ),
            child: Row(
              children: <Widget>[
                LoopIcon(content.icon, size: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      content.banner,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Success / warning / error notice. Its host owns placement and lifetime.
class LoopGlobalNotice extends StatelessWidget {
  const LoopGlobalNotice({
    required this.feedback,
    super.key,
    this.onAction,
    this.onDismiss,
  });

  final LoopGlobalFeedback feedback;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final message = feedback.presentationMessage;
    if (message == null) {
      return const SizedBox.shrink(
        key: ValueKey<String>('invalid-global-feedback'),
      );
    }
    final kind = switch (feedback.kind) {
      LoopNoticeKind.success => LoopToastKind.ok,
      LoopNoticeKind.warning => LoopToastKind.warn,
      LoopNoticeKind.error => LoopToastKind.err,
    };
    final actionLabel = feedback.presentationActionLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopToastView(
            entry: LoopToastEntry(message: message, kind: kind),
          ),
          if ((actionLabel != null && onAction != null) || onDismiss != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LoopButtonPair(
                padded: false,
                children: <Widget>[
                  if (onDismiss != null)
                    LoopButton(label: '关闭', onPressed: onDismiss),
                  if (actionLabel != null && onAction != null)
                    LoopButton(
                      label: actionLabel,
                      primary: true,
                      onPressed: onAction,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable skeleton for feature slices; fails closed on invalid density.
class LoopSkeletonView extends StatelessWidget {
  const LoopSkeletonView({required this.presentation, super.key});

  final LoopLoadingPresentation presentation;

  @override
  Widget build(BuildContext context) {
    if (!presentation.isPresentable) {
      return const SizedBox.shrink(
        key: ValueKey<String>('invalid-loading-presentation'),
      );
    }
    return switch (presentation.kind) {
      LoopSkeletonKind.list => LoopSkeleton(
        type: LoopSkeletonType.list,
        rows: presentation.placeholderCount,
      ),
      LoopSkeletonKind.detail => const LoopSkeleton(
        type: LoopSkeletonType.detail,
      ),
      LoopSkeletonKind.chart => const LoopSkeleton(
        type: LoopSkeletonType.chart,
      ),
    };
  }
}

Future<void> showLoopForceUpdateDialog(
  BuildContext context, {
  required LoopForceUpdateRequirement requirement,
  required VoidCallback onUpdate,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const LoopIcon('upgrade', size: 34, color: LoopColors.lime),
        title: const Text('请更新 LOOP 后继续'),
        content: Text(
          '已批准的版本策略要求受支持的版本${requirement.forceUpdateBelow == null ? '' : '（强制更新下限 ${requirement.forceUpdateBelow}）'}。安装受支持的版本后再回到 LOOP。',
        ),
        actions: <Widget>[
          LoopButton(label: '立即更新', primary: true, onPressed: onUpdate),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Page scaffold shared by the state pages
// ---------------------------------------------------------------------------

class _StatePage extends StatelessWidget {
  const _StatePage({
    required this.title,
    required this.folio,
    required this.body,
    this.onBack,
    this.primaryAction,
    this.blocking = false,
  });

  final String title;
  final LoopFolioPrimary folio;
  final List<Widget> body;
  final VoidCallback? onBack;
  final Widget? primaryAction;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      key: ValueKey<String>(
        blocking ? 'system-state-blocking' : 'system-state-dismissible',
      ),
      canPop: !blocking,
      child: LoopFocusPage(
        archetype: LoopPageArchetype.state,
        title: title,
        onBack: blocking ? null : onBack,
        folio: folio,
        body: body,
        primaryAction: primaryAction,
      ),
    );
  }
}

/// The "来源未接入" notice every unobserved page shows in place of a state.
class _SourceUnavailableNotice extends StatelessWidget {
  const _SourceUnavailableNotice({
    required this.keyName,
    required this.title,
    required this.body,
  });

  final String keyName;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return LoopNotice(
      key: ValueKey<String>(keyName),
      icon: 'question',
      tone: LoopNoticeTone.warn,
      title: title,
      body: body,
    );
  }
}

Widget? _returnAction(VoidCallback? onContinue) => onContinue == null
    ? null
    : LoopButton(
        key: const ValueKey<String>('system-return'),
        label: '返回 LOOP',
        block: true,
        onPressed: onContinue,
      );

// ---------------------------------------------------------------------------
// offline
// ---------------------------------------------------------------------------

({String title, String body, String banner, String icon, LoopNoticeTone tone})
_connectivityCopy(LoopConnectivityScope scope) => switch (scope) {
  LoopConnectivityScope.fullyOffline => (
    title: '完全离线',
    body: '检查 Wi-Fi 或蜂窝数据。资产数据为最后一次同步的缓存，可能已过期。',
    banner: '离线 · 实时信息已暂停',
    icon: 'offline',
    tone: LoopNoticeTone.danger,
  ),
  LoopConnectivityScope.marketDataUnavailable => (
    title: '行情暂时不可用',
    body: '其他功能正常。价格与图表可能不准，依赖当前价格的动作已暂停。',
    banner: '行情不可用 · 价格可能已过期',
    icon: 'warn',
    tone: LoopNoticeTone.warn,
  ),
  LoopConnectivityScope.tradingServiceUnavailable => (
    title: '交易服务暂时不可用',
    body: '订单与账户变更无法提交；行情浏览与聊天仍可使用。',
    banner: '交易服务中断 · 动作已暂停',
    icon: 'warn',
    tone: LoopNoticeTone.warn,
  ),
};

class _OfflinePage extends StatelessWidget {
  const _OfflinePage({
    required this.observation,
    required this.onRetry,
    required this.onContinue,
    required this.onBack,
  });

  final LoopConnectivityObservation? observation;
  final VoidCallback? onRetry;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final observation = this.observation;
    if (observation == null) {
      return _StatePage(
        title: '无网络',
        onBack: onBack,
        folio: const LoopFolioPrimary(
          kicker: 'CONNECTIVITY',
          heading: '连接状态还没有开放',
          caption: '打开这一页不代表设备离线或服务故障。',
          stamp: 'UNKNOWN',
          archetype: LoopFolioArchetype.state,
        ),
        body: const <Widget>[
          _SourceUnavailableNotice(
            keyName: 'connectivity-source-unavailable',
            title: '读不到连接状态',
            body: '暂时读不到设备网络与 LOOP 服务的状态，这一页不会替你判断是否离线。',
          ),
        ],
        primaryAction: _returnAction(onContinue),
      );
    }
    final scope = observation.scope;
    final copy = _connectivityCopy(scope);
    final fullyOffline = scope == LoopConnectivityScope.fullyOffline;
    final outage = observation.partialOutage;
    return _StatePage(
      title: '无网络',
      onBack: onBack,
      folio: LoopFolioPrimary(
        kicker:
            observation.lastSyncKicker ??
            (fullyOffline ? 'DEVICE OFFLINE' : 'SERVICE INTERRUPTED'),
        heading: fullyOffline ? '当前设备离线' : copy.title,
        caption: fullyOffline
            ? '缓存仍可查看；发送、兑换与跨链已经暂停。'
            : '其他部分仍可使用；受影响的动作在恢复前保持禁用。',
        stamp: fullyOffline ? 'OFFLINE' : 'PARTIAL',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        LoopNotice(
          icon: copy.icon,
          tone: copy.tone,
          title: copy.title,
          body: copy.body,
        ),
        if (fullyOffline)
          LoopEmpty(
            icon: 'offline',
            message: '无法连接到服务器',
            action: onRetry == null
                ? null
                : LoopButton(label: '重试', onPressed: onRetry),
          )
        else if (onRetry != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopButton(label: '重试', block: true, onPressed: onRetry),
          ),
        const LoopLabel('部分故障（另一种态）', followsLabel: true),
        if (outage == null)
          const _SourceUnavailableNotice(
            keyName: 'partial-outage-source-unavailable',
            title: '没有分链的故障信息',
            body: '暂时读不到单条链的状态，这一页不会替你判断某条链是否可用。',
          )
        else
          LoopNotice(
            key: const ValueKey<String>('partial-outage-notice'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '${outage.networkLabel} 网络暂时不可用',
            body: outage.detail ?? '其他链正常。该链上的资产余额可能不准，该链的交易已暂停。',
          ),
        const LoopNotice(
          title: '为什么区分这两种',
          body: '完全断网时所有操作都要拦；单链故障时其他链应该照常可用 —— 一刀切会让用户以为整个 App 坏了。',
        ),
      ],
      primaryAction: onContinue == null
          ? null
          : LoopButton(
              label: fullyOffline ? '查看缓存内容' : '继续使用可用功能',
              block: true,
              onPressed: onContinue,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// server-error
// ---------------------------------------------------------------------------

class _ServerErrorPage extends StatelessWidget {
  const _ServerErrorPage({
    required this.observation,
    required this.onRetry,
    required this.onSupport,
    required this.onContinue,
    required this.onBack,
  });

  final LoopServiceErrorObservation? observation;
  final VoidCallback? onRetry;
  final VoidCallback? onSupport;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final observation = this.observation;
    if (observation == null) {
      return _StatePage(
        title: '服务状态',
        onBack: onBack,
        folio: const LoopFolioPrimary(
          kicker: 'SERVICE STATUS',
          heading: '服务状态还没有开放',
          caption: '打开此页不代表某个请求返回了错误或未确认的结果。',
          stamp: 'UNKNOWN',
          archetype: LoopFolioArchetype.state,
        ),
        body: const <Widget>[
          _SourceUnavailableNotice(
            keyName: 'service-error-source-unavailable',
            title: '没有请求错误上下文',
            body: '只有在某个功能真的出错时，这一页才会显示服务不可用。',
          ),
        ],
        primaryAction: _returnAction(onContinue),
      );
    }
    final trace = observation.traceId;
    return _StatePage(
      title: '服务状态',
      onBack: onBack,
      folio: const LoopFolioPrimary(
        kicker: 'SERVICE STATUS',
        heading: '服务暂时不可用',
        caption: '钱包仍在你的设备上；稍后重试或联系支持。',
        stamp: 'RETRY',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        LoopNotice(
          icon: 'maintenance',
          tone: LoopNoticeTone.danger,
          title: observation.statusLabel == null
              ? '结果未确认'
              : '错误 ${observation.statusLabel}',
          body:
              '${trace == null ? '追踪号未提供' : '追踪号 $trace'} · 不要假定成功或失败；重试前先查看最新状态。Wallet 资产仍在链上，不受影响。',
        ),
        if (onRetry != null || onSupport != null)
          LoopButtonPair(
            children: <Widget>[
              if (onRetry != null)
                LoopButton(label: '重试', primary: true, onPressed: onRetry),
              if (onSupport != null)
                LoopButton(label: '联系客服', onPressed: onSupport),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// force-update
// ---------------------------------------------------------------------------

class _ForceUpdatePage extends StatelessWidget {
  const _ForceUpdatePage({
    required this.requirement,
    required this.onUpdate,
    required this.onContinue,
    required this.onBack,
  });

  final LoopForceUpdateRequirement? requirement;
  final VoidCallback? onUpdate;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final requirement = this.requirement;
    if (requirement == null) {
      return _StatePage(
        title: '强制更新',
        onBack: onBack,
        folio: const LoopFolioPrimary(
          kicker: 'VERSION POLICY',
          heading: '版本策略还没有开放',
          caption: '打开此页不代表当前版本不受支持或不安全。',
          stamp: 'UNKNOWN',
          archetype: LoopFolioArchetype.state,
        ),
        body: const <Widget>[
          _SourceUnavailableNotice(
            keyName: 'update-policy-unavailable',
            title: '没有已批准的最低版本策略',
            body: '只有当 client-policy 的 versionGate 为 available 且当前版本低于硬性下限时，LOOP 才会拦截。',
          ),
        ],
        primaryAction: _returnAction(onContinue),
      );
    }
    return _StatePage(
      title: '强制更新',
      blocking: true,
      folio: const LoopFolioPrimary(
        kicker: 'UPDATE REQUIRED',
        heading: '请更新 LOOP 后继续',
        caption: '已批准的版本策略要求受支持的版本，此要求不可跳过。',
        stamp: 'REQUIRED',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        LoopSurfaceCard(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              LoopKeyValue(
                label: '强制更新下限',
                value: requirement.forceUpdateBelow ?? '—',
              ),
              if (requirement.minimumSupportedVersion != null)
                LoopKeyValue(
                  label: '最低支持版本',
                  value: requirement.minimumSupportedVersion!,
                ),
              LoopKeyValue(
                label: '策略版本',
                value: requirement.configVersion ?? '—',
              ),
            ],
          ),
        ),
        if (onUpdate == null)
          const LoopNotice(
            key: ValueKey<String>('force-update-store-unavailable'),
            icon: 'info',
            title: '已确认需要更新',
            body: '暂时不能直接跳转商店，请手动前往应用商店更新。',
          ),
      ],
      primaryAction: onUpdate == null
          ? null
          : LoopButton(
              label: '立即更新',
              primary: true,
              block: true,
              onPressed: onUpdate,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// maintenance
// ---------------------------------------------------------------------------

class _MaintenancePage extends StatelessWidget {
  const _MaintenancePage({
    required this.notice,
    required this.onRecheck,
    required this.onStatus,
    required this.onReadOnly,
    required this.onContinue,
    required this.onBack,
  });

  final LoopMaintenanceNotice? notice;
  final VoidCallback? onRecheck;
  final VoidCallback? onStatus;

  /// Only the explicit-notice state exposes this; it is never the generic
  /// "return to LOOP" action of the source-unavailable state.
  final VoidCallback? onReadOnly;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final notice = this.notice;
    if (notice == null) {
      return _StatePage(
        title: '计划维护',
        onBack: onBack,
        folio: const LoopFolioPrimary(
          kicker: 'MAINTENANCE',
          heading: '维护状态还没有开放',
          caption: '打开此页不代表有计划中或进行中的维护。',
          stamp: 'UNKNOWN',
          archetype: LoopFolioArchetype.state,
        ),
        body: const <Widget>[
          _SourceUnavailableNotice(
            keyName: 'maintenance-source-unavailable',
            title: '没有已批准的维护通知',
            body: '必须提供一份当前生效的通知，此页才会报告维护窗口与受影响服务。',
          ),
        ],
        primaryAction: _returnAction(onContinue),
      );
    }
    return _StatePage(
      title: '计划维护',
      onBack: onBack,
      folio: LoopFolioPrimary(
        kicker: 'MAINTENANCE WINDOW',
        heading: notice.windowLabel ?? '维护通知已生效',
        caption: '期间暂停社区互动；钱包与 Mining 数据保持只读。',
        stamp: notice.windowLabel == null ? 'ACTIVE' : 'WINDOW',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        if (notice.detail != null)
          LoopNotice(icon: 'mine', title: '维护说明', body: notice.detail!),
        if (onRecheck != null || onStatus != null)
          LoopButtonPair(
            children: <Widget>[
              if (onRecheck != null)
                LoopButton(label: '再次检查', primary: true, onPressed: onRecheck),
              if (onStatus != null)
                LoopButton(label: '查看服务状态', onPressed: onStatus),
            ],
          ),
      ],
      primaryAction: onReadOnly == null
          ? null
          : LoopButton(label: '查看只读内容', block: true, onPressed: onReadOnly),
    );
  }
}

// ---------------------------------------------------------------------------
// region-blocked
// ---------------------------------------------------------------------------

class _RegionPage extends StatelessWidget {
  const _RegionPage({
    required this.restriction,
    required this.onContinue,
    required this.onPolicy,
    required this.onReturn,
    required this.onBack,
  });

  final LoopFeatureAvailabilityRestriction? restriction;
  final VoidCallback? onContinue;
  final VoidCallback? onPolicy;
  final VoidCallback? onReturn;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final restriction = this.restriction;
    if (restriction == null) {
      return _StatePage(
        title: '地区限制',
        onBack: onBack,
        folio: const LoopFolioPrimary(
          kicker: 'REGION POLICY',
          heading: '地区策略还没有开放',
          caption: '打开此页不代表你所在的地区或账号受限。',
          stamp: 'UNKNOWN',
          archetype: LoopFolioArchetype.state,
        ),
        body: const <Widget>[
          _SourceUnavailableNotice(
            keyName: 'region-policy-unavailable',
            title: '没有已批准的地区判定',
            body: 'LOOP 不会从设备语言、SIM 或 IP 推断地区；regionGate 为 unavailable 时视为“未知，未批准”。',
          ),
        ],
        primaryAction: _returnAction(onReturn),
      );
    }
    return _StatePage(
      title: '地区限制',
      onBack: onBack,
      folio: LoopFolioPrimary(
        kicker: 'REGION POLICY',
        heading: '部分功能在当前地区不可用',
        caption: restriction.readOnlyAssetAccess == true
            ? '资产保持只读可见；受限功能按各自页面的当前状态显示。'
            : '受限功能按各自页面的当前状态显示；此页不列出未确认的可用范围。',
        stamp: restriction.reasonCode ?? 'RESTRICTED',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        const LoopNotice(
          icon: 'globe',
          title: '这页不提供位置或原因细节',
          body: '不推断你所在的位置，也不确认其他功能一定可用。',
        ),
        if (onContinue != null || onPolicy != null)
          LoopButtonPair(
            children: <Widget>[
              if (onContinue != null)
                LoopButton(
                  label: '继续使用 LOOP',
                  primary: true,
                  onPressed: onContinue,
                ),
              if (onPolicy != null)
                LoopButton(label: '查看资格政策', onPressed: onPolicy),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// permission-notice
// ---------------------------------------------------------------------------

({String shortName, String icon, String purpose, String deniedBody})
_permissionCopy(LoopPermissionKind kind) => switch (kind) {
  LoopPermissionKind.notifications => (
    shortName: '通知',
    icon: 'bell',
    purpose: '用来推送挖矿结算、Launch 开始、@我的消息与安全事件。不会推送营销内容。',
    deniedBody: '你将收不到挖矿结算与 Launch 提醒。可在 系统设置 → LOOP → 通知 中重新开启。',
  ),
  LoopPermissionKind.camera => (
    shortName: '相机',
    icon: 'camera',
    purpose: '只在扫二维码时使用 —— 扫收款地址、扫 WalletConnect。不会在后台访问。',
    deniedBody: '扫码功能不可用；可在 系统设置 → LOOP → 相机 中重新开启。',
  ),
  LoopPermissionKind.microphone => (
    shortName: '麦克风',
    icon: 'mic',
    purpose: '只在你于语音房点击「发言」后使用；进入语音房时麦克风默认关闭。',
    deniedBody: '语音房只能收听；可在 系统设置 → LOOP → 麦克风 中重新开启。',
  ),
};

class _PermissionPage extends StatelessWidget {
  const _PermissionPage({
    required this.prompt,
    required this.onRequest,
    required this.onOpenSettings,
    required this.onNotNow,
    required this.onContinue,
    required this.onBack,
  });

  final LoopPermissionPrompt? prompt;
  final VoidCallback? onRequest;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onNotNow;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final prompt = this.prompt;
    final denied = prompt?.mode == LoopPermissionPromptMode.settingsRecovery;
    final copy = prompt == null ? null : _permissionCopy(prompt.kind);
    return _StatePage(
      title: '权限说明',
      onBack: onBack,
      folio: const LoopFolioPrimary(
        kicker: 'PERMISSION CONTROL',
        heading: '使用前再申请',
        caption: '相机、通知和生物识别只在对应动作发生时请求。',
        stamp: 'JUST IN TIME',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        const LoopLabel('申请前说明', tight: true),
        const LoopNotice(
          icon: 'bell',
          title: '通知权限',
          body: '用来推送挖矿结算、Launch 开始、@我的消息与安全事件。不会推送营销内容。',
        ),
        const LoopNotice(
          icon: 'camera',
          title: '相机权限',
          body: '只在扫二维码时使用 —— 扫收款地址、扫 WalletConnect。不会在后台访问。',
        ),
        const LoopNotice(
          icon: 'user',
          title: '生物识别',
          body: '用于应用锁与签名前验证。生物特征由系统保管，LOOP 拿不到。',
        ),
        if (copy == null) ...<Widget>[
          const LoopLabel('当前申请', followsLabel: true),
          const _SourceUnavailableNotice(
            keyName: 'permission-prompt-unavailable',
            title: '当前没有待处理的权限申请',
            body: '从你要使用的功能进入，LOOP 才能说明本次具体申请的用途与范围；此页不会代为请求或推断系统状态。',
          ),
        ] else ...<Widget>[
          LoopLabel(denied ? '被拒后的引导' : '本次申请', followsLabel: true),
          LoopPermissionState(
            key: ValueKey<String>(
              'permission-prompt-${prompt!.kind.name}-${prompt.mode.name}',
            ),
            icon: copy.icon,
            denied: denied,
            title: denied ? '${copy.shortName}权限已被系统关闭' : '${copy.shortName}权限',
            purpose: denied ? copy.deniedBody : copy.purpose,
            onRequest: onRequest,
            onOpenSettings: onOpenSettings,
            requestLabel: '继续',
            settingsLabel: '前往系统设置',
          ),
          if (onNotNow != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: LoopButton(label: '暂不', block: true, onPressed: onNotNow),
            ),
        ],
      ],
      primaryAction: copy == null ? _returnAction(onContinue) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// toast-states
// ---------------------------------------------------------------------------

class _ToastStatesPage extends StatelessWidget {
  const _ToastStatesPage({
    required this.feedback,
    required this.onAction,
    required this.onDismiss,
    required this.onBack,
  });

  final LoopGlobalFeedback? feedback;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final VoidCallback? onBack;

  static const samples = <(String, LoopToastKind, String)>[
    ('成功', LoopToastKind.ok, '示例 · 地址已复制'),
    ('警告', LoopToastKind.warn, '示例 · 价格已变动，请刷新报价'),
    ('错误', LoopToastKind.err, '示例 · 交易失败：gas 不足'),
  ];

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    final hasFeedback = feedback?.presentationMessage != null;
    final canToast = LoopToastHost.maybeOf(context) != null;
    return _StatePage(
      title: 'Toast 三态',
      onBack: onBack,
      folio: const LoopFolioPrimary(
        kicker: 'FEEDBACK SURFACE',
        heading: 'Toast 三态',
        caption: '成功、警告与错误共用同一位置和清晰语义。',
        stamp: '3 STATES',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        if (hasFeedback) ...<Widget>[
          const LoopLabel('当前反馈', tight: true),
          LoopGlobalNotice(
            feedback: feedback!,
            onAction: onAction,
            onDismiss: onDismiss,
          ),
        ] else
          const LoopNotice(
            key: ValueKey<String>('feedback-source-unavailable'),
            icon: 'info',
            body: '下面是组件示例。当前没有功能提供真实的成功、警告或错误结果；打开此页不代表任何动作发生过。',
          ),
        const LoopNotice(icon: 'info', body: '点按钮触发真实 Toast，2.6 秒后自动消失。'),
        for (final (label, kind, message) in samples) ...<Widget>[
          LoopLabel(label, followsLabel: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: LoopButton(
              key: ValueKey<String>('toast-trigger-${kind.name}'),
              label: '触发$label Toast',
              block: true,
              onPressed: canToast
                  ? () => LoopToast.show(context, message: message, kind: kind)
                  : null,
            ),
          ),
        ],
        const LoopLabel('静态样式对照', followsLabel: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: <Widget>[
              for (final (_, kind, message) in samples)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LoopToastView(
                    entry: LoopToastEntry(message: message, kind: kind),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// skeleton-states
// ---------------------------------------------------------------------------

class _SkeletonStatesPage extends StatelessWidget {
  const _SkeletonStatesPage({required this.presentation, required this.onBack});

  final LoopLoadingPresentation? presentation;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final presentation = this.presentation;
    final valid = presentation != null && presentation.isPresentable;
    return _StatePage(
      title: '骨架屏三类',
      onBack: onBack,
      folio: const LoopFolioPrimary(
        kicker: 'LOADING SYSTEM',
        heading: '骨架屏三类',
        caption: '列表、详情和图表分别保留稳定布局，避免内容跳动。',
        stamp: '3 TYPES',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        if (valid) ...<Widget>[
          const LoopLabel('当前加载', tight: true),
          LoopNotice(
            key: const ValueKey<String>('loading-presentation-active'),
            icon: 'clock',
            body:
                '拥有方选择了${switch (presentation.kind) {
                  LoopSkeletonKind.list => '列表',
                  LoopSkeletonKind.detail => '详情',
                  LoopSkeletonKind.chart => '图表',
                }}骨架；占位不代表结果数量、身份或成功。',
          ),
          LoopSkeletonView(presentation: presentation),
        ] else
          const LoopNotice(
            key: ValueKey<String>('loading-source-unavailable'),
            icon: 'info',
            body: '下面是三类骨架的示例布局。当前没有功能处于加载中；打开此页不代表有请求在进行。',
          ),
        const LoopChalkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LoopSkeletonBlock(height: 13, widthFactor: 0.42),
              SizedBox(height: 12),
              LoopSkeletonBlock(height: 30, widthFactor: 0.68),
              SizedBox(height: 9),
              LoopSkeletonBlock(height: 11, widthFactor: 0.54),
            ],
          ),
        ),
        const LoopLabel('列表骨架', followsLabel: true),
        const LoopSkeleton(type: LoopSkeletonType.list, rows: 3),
        const LoopLabel('详情骨架'),
        const LoopSkeleton(type: LoopSkeletonType.detail),
        const LoopLabel('图表骨架'),
        const LoopSkeleton(type: LoopSkeletonType.chart),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// token-card-states
// ---------------------------------------------------------------------------

class _TokenCardStatesPage extends StatelessWidget {
  const _TokenCardStatesPage({
    required this.showcase,
    required this.onBack,
    required this.onContinue,
  });

  final LoopSystemShowcase? showcase;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final items = showcase?.tokenCards ?? const <LoopTokenCardShowcaseItem>[];
    return _StatePage(
      title: 'Token Card 五态',
      onBack: onBack,
      folio: const LoopFolioPrimary(
        kicker: 'TOKEN CARD SYSTEM',
        heading: '5 种卡片状态',
        stamp: '5 STATES',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        if (items.isEmpty)
          const _SourceUnavailableNotice(
            keyName: 'token-card-showcase-unavailable',
            title: '组件示例还没有开放',
            body: '正式会话不注入演示资产；Token Card 出现在聊天流、社区主页、行情列表与搜索结果中，由各自的数据源驱动。',
          )
        else ...<Widget>[
          LoopNotice(
            key: const ValueKey<String>('token-card-showcase-label'),
            icon: 'info',
            tone: LoopNoticeTone.warn,
            title: showcase!.sourceLabel,
            body: '以下卡片的数值为固定演示，不来自任何 Provider。',
          ),
          for (final item in items) ...<Widget>[
            LoopLabel(item.label, followsLabel: true),
            LoopTokenCard(
              state: item.state,
              model: item.model,
              actions: item.actions,
            ),
          ],
          const LoopDisclosure(
            summary: '查看组件出现位置',
            child: LoopNotice(
              margin: EdgeInsets.fromLTRB(16, 10, 16, 14),
              body: '正常、识别中与 Launch 资产共享结构，不共享风险判断。此组件出现在聊天流、社区主页、行情列表、搜索结果四处，不占独立路由。',
            ),
          ),
          const LoopNotice(
            margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
            title: '风险态只列事实',
            body: '每条都标注出处和时间，不给「危险」「不安全」这类结论 —— 判断权留给你。',
          ),
        ],
        const SizedBox(height: 20),
      ],
      primaryAction: items.isEmpty ? _returnAction(onContinue) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// sign-sheet-states
// ---------------------------------------------------------------------------

class _SignSheetStatesPage extends StatelessWidget {
  const _SignSheetStatesPage({
    required this.showcase,
    required this.onBack,
    required this.onContinue,
  });

  final LoopSystemShowcase? showcase;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final items = showcase?.signSheets ?? const <LoopSignSheetShowcaseItem>[];
    return _StatePage(
      title: '签名弹层四态',
      onBack: onBack,
      folio: const LoopFolioPrimary(
        kicker: 'ONE SIGNING EXIT',
        heading: '4 种签名状态',
        caption: '发送、兑换、DApp 与跨链统一进入同一签名出口。',
        stamp: 'SECURE',
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        const LoopNotice(
          icon: 'lock',
          title: '全产品唯一签名出口',
          body: 'Send、Swap、Launch 买入、授权全部汇聚到这一个弹层；质押要等独立合约方案批准后才会加入。',
        ),
        if (items.isEmpty)
          const _SourceUnavailableNotice(
            keyName: 'sign-sheet-showcase-unavailable',
            title: '组件示例还没有开放',
            body: '正式会话不会注入演示交易；真实签名来自发送、兑换与授权流程。',
          )
        else ...<Widget>[
          LoopNotice(
            key: const ValueKey<String>('sign-sheet-showcase-label'),
            icon: 'info',
            tone: LoopNoticeTone.warn,
            title: showcase!.sourceLabel,
            body: '以下金额与策略均为固定演示，不会签名或广播。',
          ),
          for (final item in items) ...<Widget>[
            LoopLabel(item.label, followsLabel: true),
            if (item.state == LoopSignSheetState.pending)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: LoopButton(
                  key: const ValueKey<String>('sign-sheet-trigger-pending'),
                  label: '触发待确认弹层',
                  block: true,
                  onPressed: () => LoopSignSheet.show(
                    context,
                    sheet: LoopSignSheet(
                      state: item.state,
                      facts: item.facts,
                      reason: item.reason,
                      confirmLabel: '确认',
                      onConfirm: () => Navigator.of(context).pop(),
                      onCancel: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: LoopSignSheet(
                  state: item.state,
                  facts: item.facts,
                  reason: item.reason,
                  confirmLabel: '确认',
                  onConfirm: () {},
                  onCancel: () {},
                  onAdjustPolicy:
                      item.state == LoopSignSheetState.policyRejected
                      ? () {}
                      : null,
                ),
              ),
          ],
          const LoopNotice(
            margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
            title: '策略拒绝不是错误',
            body: '是钱包按你的规则挡住了 —— 所以文案要说清是哪条规则、怎么改，而不是只说「失败」。',
          ),
        ],
        const SizedBox(height: 20),
      ],
      primaryAction: items.isEmpty ? _returnAction(onContinue) : null,
    );
  }
}

class _UnknownSystemPage extends StatelessWidget {
  const _UnknownSystemPage({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return _StatePage(
      title: '系统',
      onBack: onBack,
      folio: const LoopFolioPrimary(
        kicker: 'SYSTEM',
        heading: '此页面不可用',
        caption: 'LOOP 无法识别请求的系统页面。',
        archetype: LoopFolioArchetype.state,
      ),
      body: const <Widget>[LoopNotice(body: '返回上一页后重试。')],
    );
  }
}
