import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/system/system_specimens.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
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

  /// `上次同步 HH:mm` in the device's own zone, or null.
  String? get lastSyncKicker {
    final value = lastSyncAt;
    if (value == null) return null;
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return LoopL10n.current.system_surfacesLastSyncKicker(hour, minute);
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
    this.chalk = false,
  });

  final String label;
  final LoopTokenCardState state;
  final LoopTokenCardModel model;
  final List<LoopTokenCardAction> actions;

  /// `.tcard.tcard-signature.chalk-card`: the prototype draws only the
  /// normal state on the Chalk ground.
  final bool chalk;
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
    this.onRegionViewAssets,
    this.onRegionExportKey,
    this.onRegionSupport,
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

  /// The three `#scr-region-blocked` exits. Each is null when its page is not
  /// reachable from here; the gate then shows it as off with a reason rather
  /// than dropping it.
  final SystemAction? onRegionViewAssets;
  final SystemAction? onRegionExportKey;
  final SystemAction? onRegionSupport;
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
        onBack: onBack,
      ),
      'region-restricted' => _RegionPage(
        restriction: featureAvailabilityRestriction,
        onViewAssets: onRegionViewAssets,
        onExportKey: onRegionExportKey,
        onSupport: onRegionSupport,
        onPolicy: onRegionPolicy,
        onReturn: onSecondaryAction,
        onBack: onBack,
      ),
      'permission' => _PermissionPage(
        prompt: permissionPrompt,
        onRequest: onPermissionRequest,
        onOpenSettings: onPermissionOpenSettings,
        onNotNow: onPermissionNotNow,
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
      ),
      'sign-sheet-states' => _SignSheetStatesPage(
        showcase: showcase,
        onBack: onBack,
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
          label: context.l10n.system_surfacesTitleBody(
            content.body,
            content.title,
          ),
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
                  TextButton(
                    onPressed: onRetry,
                    child: Text(context.l10n.common_retry),
                  ),
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
                    LoopButton(
                      label: context.l10n.common_close,
                      onPressed: onDismiss,
                    ),
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
        icon: const LoopIcon('upgrade', size: 34, color: LoopColors.yellow),
        title: Text(context.l10n.system_surfacesShowLoopForceUpdateDialog),
        content: Text(
          context.l10n.system_surfacesShowLoopForceUpdateDialog2(
            requirement.forceUpdateBelow == null
                ? ''
                : context.l10n.system_surfacesForceUpdateFloorSuffix(
                    requirement.forceUpdateBelow,
                  ),
          ),
        ),
        actions: <Widget>[
          LoopButton(
            label: context.l10n.system_surfacesLabel,
            primary: true,
            onPressed: onUpdate,
          ),
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
    this.kicker,
    this.actionFollowsBody = false,
  });

  final String title;

  /// The mono eyebrow above the title.
  ///
  /// It carries one thing on these pages: that what is drawn below is a
  /// specimen and not a reading ([loopComponentSpecimenLabel] /
  /// [loopStateSpecimenLabel]). It is a bar line rather than a notice card on
  /// purpose — the audit's finding was that the explanatory card had *become*
  /// the page, so the label may not take a block of the body.
  final String? kicker;
  final LoopFolioPrimary folio;
  final List<Widget> body;
  final VoidCallback? onBack;
  final Widget? primaryAction;

  /// The action flows under the last row instead of being pinned.
  ///
  /// The prototype writes `<div class="pad"><button class="btn-block">` in
  /// normal flow, and on a page whose body is two cards a pinned bar puts
  /// 500px of empty screen between the last line and the button — the same
  /// finding as audit §D item 9.
  final bool actionFollowsBody;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      key: const ValueKey<String>('system-state-dismissible'),
      child: LoopFocusPage(
        archetype: LoopPageArchetype.state,
        title: title,
        kicker: kicker,
        onBack: onBack,
        folio: folio,
        body: body,
        primaryAction: primaryAction,
        actionsFollowBody: actionFollowsBody,
      ),
    );
  }
}

/// The prototype's `.empty` block: a centred glyph, one line and one way out,
/// inside a hairline frame (`.refined-page .folio-body>.empty`).
///
/// `LoopInlineUnavailable` is the line used *inside* a loaded page; the offline
/// page's 无法连接到服务器 card is the other shape — it is the page's middle and
/// it owns the retry.
class _CenteredStateBlock extends StatelessWidget {
  const _CenteredStateBlock({
    required this.icon,
    required this.message,
    this.action,
    super.key,
  });

  final String icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: LoopColors.card,
            borderRadius: LoopRadius.card,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LoopIcon(icon, size: 32, color: LoopColors.text3),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: LoopType.captionSm,
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: 18),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A whole-page policy gate: one Chalk card, centred, with its exits under it.
///
/// `#scr-force-update` and `#scr-region-blocked` are the two pages in the
/// frozen prototype that carry no topbar at all: a `chalk-card` folio sits in
/// the middle of the screen and the ways out are stacked beneath it. Rendered
/// as an ordinary top-aligned state page they lost both the Chalk ground and,
/// worse, every exit — a blocked owner saw an explanation with nothing to do
/// (audit 2026-09-20 §C.9, §C.10).
class _PolicyGatePage extends StatelessWidget {
  const _PolicyGatePage({
    required this.folio,
    required this.exits,
    this.facts = const <Widget>[],
    this.footnote,
    this.blocking = true,
  });

  final LoopFolioPrimary folio;

  /// Read-only evidence shown between the card and the exits.
  final List<Widget> facts;

  /// One exit per row, in the prototype's order, each already stating why it
  /// is off when it is off.
  final List<Widget> exits;
  final String? footnote;
  final bool blocking;

  /// `.btn` column width in `#scr-region-blocked`.
  static const double exitWidth = 250;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      key: ValueKey<String>(
        blocking ? 'system-state-blocking' : 'system-state-dismissible',
      ),
      canPop: !blocking,
      child: Semantics(
        container: true,
        identifier: loopPageIdentifier(
          LoopPageArchetype.state,
          LoopLayoutMode.focus,
        ),
        explicitChildNodes: true,
        child: Scaffold(
          key: const ValueKey<String>('loop-page-policy-gate'),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    folio,
                    ...facts,
                    if (exits.isNotEmpty)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: exitWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: exits,
                          ),
                        ),
                      ),
                    if (footnote case final String line)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                        child: Text(
                          line,
                          textAlign: TextAlign.center,
                          style: LoopType.captionSm,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One exit on a policy gate. An exit with no reviewed destination stays on
/// the page as a disabled control with the reason under it, because removing
/// it is what left the blocked page with nothing on it.
class _PolicyExit extends StatelessWidget {
  const _PolicyExit({
    required this.id,
    required this.label,
    required this.onPressed,
    required this.unavailableReason,
    this.primary = false,
  });

  /// Stable id for the key; the key never spells copy.
  final String id;
  final String label;
  final VoidCallback? onPressed;
  final String unavailableReason;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopButton(
            key: ValueKey<String>('policy-exit-$id'),
            label: label,
            primary: primary,
            block: true,
            onPressed: onPressed,
          ),
          if (onPressed == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                unavailableReason,
                textAlign: TextAlign.center,
                style: LoopType.captionSm,
              ),
            ),
        ],
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
        label: LoopL10n.current.system_surfacesSystemReturnLabel,
        block: true,
        onPressed: onContinue,
      );

// ---------------------------------------------------------------------------
// offline
// ---------------------------------------------------------------------------

({String title, String body, String banner, String icon, LoopNoticeTone tone})
_connectivityCopy(LoopConnectivityScope scope) => switch (scope) {
  LoopConnectivityScope.fullyOffline => (
    title: LoopL10n.current.system_surfacesTitle,
    body: LoopL10n.current.system_surfacesBody,
    banner: LoopL10n.current.system_surfacesBanner,
    icon: 'offline',
    tone: LoopNoticeTone.danger,
  ),
  LoopConnectivityScope.marketDataUnavailable => (
    title: LoopL10n.current.system_surfacesTitle2,
    body: LoopL10n.current.system_surfacesBody2,
    banner: LoopL10n.current.system_surfacesBanner2,
    icon: 'warn',
    tone: LoopNoticeTone.warn,
  ),
  LoopConnectivityScope.tradingServiceUnavailable => (
    title: LoopL10n.current.system_surfacesTitle3,
    body: LoopL10n.current.system_surfacesBody3,
    banner: LoopL10n.current.system_surfacesBanner3,
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
      // No observation means no one has reported a network state, so the
      // page draws its two specimens instead — 全断 and 单链断 on one screen,
      // which is what `offline.html` exists to show (audit §K.2). The bar
      // says 组件样例 · 不是当前状态 above every line of it.
      return _StatePage(
        title: context.l10n.system_surfacesConnectivitySpecimenTitle,
        kicker: loopStateSpecimenLabel,
        onBack: onBack,
        folio: LoopFolioPrimary(
          headingMaxLines: 2,
          captionMaxLines: 3,
          ring: false,
          key: ValueKey<String>('connectivity-specimen'),
          kicker: context.l10n.system_surfacesConnectivitySpecimenKicker,
          heading: context.l10n.system_surfacesConnectivitySpecimenHeading,
          caption: context.l10n.system_surfacesConnectivitySpecimenCaption,
          stamp: context.l10n.system_surfacesConnectivitySpecimenStamp,
          archetype: LoopFolioArchetype.state,
        ),
        body: <Widget>[
          LoopNotice(
            icon: 'offline',
            tone: LoopNoticeTone.danger,
            title: context.l10n.system_surfacesTitle,
            body: context.l10n.system_surfacesBody,
          ),
          _CenteredStateBlock(
            key: const ValueKey<String>('connectivity-specimen-retry'),
            icon: 'offline',
            message:
                context.l10n.system_surfacesConnectivitySpecimenRetryMessage,
            // 重试 has no request of its own to repeat here: it returns to
            // the page that opened this one, which reads again as it builds.
            action: LoopButton(
              label: context.l10n.common_retry,
              onPressed: onRetry,
            ),
          ),
          LoopLabel(context.l10n.system_surfacesLoopLabel, followsLabel: true),
          LoopNotice(
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: context.l10n.system_surfacesTitle4,
            body: context.l10n.system_surfacesBody4,
          ),
          LoopNotice(
            title: context.l10n.system_surfacesTitle5,
            body: context.l10n.system_surfacesBody5,
          ),
          const SizedBox(height: 20),
        ],
      );
    }
    final scope = observation.scope;
    final copy = _connectivityCopy(scope);
    final fullyOffline = scope == LoopConnectivityScope.fullyOffline;
    final outage = observation.partialOutage;
    return _StatePage(
      title: context.l10n.system_surfacesConnectivitySpecimenTitle,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker:
            observation.lastSyncKicker ??
            (fullyOffline
                ? context.l10n.system_surfacesKicker
                : context.l10n.system_surfacesKicker2),
        heading: fullyOffline
            ? context.l10n.system_surfacesConnectivitySpecimenHeading
            : copy.title,
        caption: fullyOffline
            ? context.l10n.system_surfacesConnectivitySpecimenCaption
            : context.l10n.system_surfacesCaption,
        stamp: fullyOffline
            ? context.l10n.system_surfacesConnectivitySpecimenStamp
            : context.l10n.system_surfacesStamp,
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
          LoopInlineUnavailable(
            icon: 'offline',
            message:
                context.l10n.system_surfacesConnectivitySpecimenRetryMessage,
            maxLines: 2,
            onRetry: onRetry,
          )
        else if (onRetry != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopButton(
              label: context.l10n.common_retry,
              block: true,
              onPressed: onRetry,
            ),
          ),
        LoopLabel(context.l10n.system_surfacesLoopLabel, followsLabel: true),
        if (outage == null)
          _SourceUnavailableNotice(
            keyName: 'partial-outage-source-unavailable',
            title: context.l10n.system_surfacesTitle6,
            body: context.l10n.system_surfacesBody6,
          )
        else
          LoopNotice(
            key: const ValueKey<String>('partial-outage-notice'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: context.l10n.system_surfacesPartialOutageNoticeTitle(
              outage.networkLabel,
            ),
            body:
                outage.detail ??
                context.l10n.system_surfacesPartialOutageNoticeBody,
          ),
        LoopNotice(
          title: context.l10n.system_surfacesTitle5,
          body: context.l10n.system_surfacesBody5,
        ),
      ],
      primaryAction: onContinue == null
          ? null
          : LoopButton(
              label: fullyOffline
                  ? context.l10n.system_surfacesLabel2
                  : context.l10n.system_surfacesLabel3,
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
    required this.onBack,
  });

  final LoopServiceErrorObservation? observation;
  final VoidCallback? onRetry;
  final VoidCallback? onSupport;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final observation = this.observation;
    if (observation == null) {
      // The specimen of `server-error.html`: the shape a failed request
      // takes, with the prototype's own 502 and trace id (audit §K.3).
      return _StatePage(
        title: context.l10n.system_surfacesServiceErrorSpecimenTitle,
        kicker: loopStateSpecimenLabel,
        onBack: onBack,
        folio: LoopFolioPrimary(
          headingMaxLines: 2,
          captionMaxLines: 3,
          ring: false,
          key: ValueKey<String>('service-error-specimen'),
          kicker: context.l10n.system_surfacesServiceErrorSpecimenTitle,
          heading: context.l10n.system_surfacesServiceErrorSpecimenHeading,
          caption: context.l10n.system_surfacesServiceErrorSpecimenCaption,
          stamp: context.l10n.system_surfacesServiceErrorSpecimenStamp,
          archetype: LoopFolioArchetype.state,
        ),
        body: <Widget>[
          LoopNotice(
            icon: 'maintenance',
            tone: LoopNoticeTone.danger,
            title: context.l10n.system_surfacesTitle7,
            body: context.l10n.system_surfacesBody7,
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                label: context.l10n.common_retry,
                primary: true,
                onPressed: onRetry,
              ),
              LoopButton(
                label: context.l10n.system_surfacesLabel4,
                onPressed: onSupport,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      );
    }
    final trace = observation.traceId;
    return _StatePage(
      title: context.l10n.system_surfacesServiceErrorSpecimenTitle,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesServiceErrorSpecimenTitle,
        heading: context.l10n.system_surfacesServiceErrorSpecimenHeading,
        caption: context.l10n.system_surfacesServiceErrorSpecimenCaption,
        stamp: context.l10n.system_surfacesServiceErrorSpecimenStamp,
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        LoopNotice(
          icon: 'maintenance',
          tone: LoopNoticeTone.danger,
          title: observation.statusLabel == null
              ? context.l10n.system_surfacesTitle8
              : context.l10n.system_surfacesTitle9(observation.statusLabel),
          body: context.l10n.system_surfacesBody8(
            trace == null
                ? context.l10n.system_surfacesTraceMissing
                : context.l10n.system_surfacesTraceId(trace),
          ),
        ),
        if (onRetry != null || onSupport != null)
          LoopButtonPair(
            children: <Widget>[
              if (onRetry != null)
                LoopButton(
                  label: context.l10n.common_retry,
                  primary: true,
                  onPressed: onRetry,
                ),
              if (onSupport != null)
                LoopButton(
                  label: context.l10n.system_surfacesLabel4,
                  onPressed: onSupport,
                ),
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
        title: context.l10n.system_surfacesTitle10,
        onBack: onBack,
        folio: LoopFolioPrimary(
          headingMaxLines: 2,
          captionMaxLines: 3,
          ring: false,
          kicker: context.l10n.system_surfacesKicker3,
          heading: context.l10n.system_surfacesHeading,
          caption: context.l10n.system_surfacesCaption2,
          stamp: context.l10n.common_unknown,
          // S241b: flat dark card, Chalk heading (no light slab on Ink).
          variant: LoopFolioVariant.quiet,
          headingTone: LoopFolioHeadingTone.neutral,
          archetype: LoopFolioArchetype.state,
        ),
        body: <Widget>[
          _SourceUnavailableNotice(
            keyName: 'update-policy-unavailable',
            title: context.l10n.system_surfacesTitle11,
            body: context.l10n.system_surfacesBody9,
          ),
        ],
        primaryAction: _returnAction(onContinue),
      );
    }
    return _PolicyGatePage(
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesKicker4,
        heading: context.l10n.system_surfacesShowLoopForceUpdateDialog,
        caption: context.l10n.system_surfacesCaption3,
        stamp: context.l10n.system_surfacesStamp2,
        // S241b: flat dark card, Chalk heading (no light slab on Ink).
        variant: LoopFolioVariant.quiet,
        headingTone: LoopFolioHeadingTone.neutral,
        archetype: LoopFolioArchetype.state,
      ),
      facts: <Widget>[
        LoopSurfaceCard(
          margin: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            14,
          ),
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              LoopKeyValue(
                label: context.l10n.system_surfacesLabel5,
                value: requirement.forceUpdateBelow ?? '—',
              ),
              if (requirement.minimumSupportedVersion != null)
                LoopKeyValue(
                  label: context.l10n.system_surfacesLabel6,
                  value: requirement.minimumSupportedVersion!,
                ),
            ],
          ),
        ),
        if (onUpdate == null)
          LoopNotice(
            key: ValueKey<String>('force-update-store-unavailable'),
            icon: 'info',
            title: context.l10n.system_surfacesForceUpdateStoreUnavailableTitle,
            body: context.l10n.system_surfacesForceUpdateStoreUnavailableBody,
          ),
      ],
      exits: <Widget>[
        _PolicyExit(
          id: 'update',
          label: context.l10n.system_surfacesLabel7,
          primary: true,
          onPressed: onUpdate,
          unavailableReason: context.l10n.system_surfacesUnavailableReason,
        ),
      ],
      footnote: context.l10n.system_surfacesForceUpdateStoreUnavailableFootnote,
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
    required this.onBack,
  });

  final LoopMaintenanceNotice? notice;
  final VoidCallback? onRecheck;
  final VoidCallback? onStatus;

  /// Only the explicit-notice state exposes this; it is never the generic
  /// "return to LOOP" action of the source-unavailable state.
  final VoidCallback? onReadOnly;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final notice = this.notice;
    if (notice == null) {
      // The specimen of `maintenance.html`. Its one promise — Mining Power
      // keeps accruing — is the reason the page exists (audit §K.4).
      return _StatePage(
        title: context.l10n.system_surfacesMaintenanceSpecimenTitle,
        kicker: loopStateSpecimenLabel,
        onBack: onBack,
        folio: LoopFolioPrimary(
          headingMaxLines: 2,
          captionMaxLines: 3,
          ring: false,
          key: ValueKey<String>('maintenance-specimen'),
          kicker: context.l10n.system_surfacesMaintenanceSpecimenKicker,
          heading: '03:00–05:00 UTC',
          caption: context.l10n.system_surfacesMaintenanceSpecimenCaption,
          stamp: context.l10n.system_surfacesMaintenanceSpecimenStamp,
          archetype: LoopFolioArchetype.state,
        ),
        body: <Widget>[
          LoopNotice(
            icon: 'mine',
            title: context.l10n.system_surfacesTitle12,
            body: context.l10n.system_surfacesBody10,
          ),
        ],
        actionFollowsBody: true,
        primaryAction: LoopButton(
          key: const ValueKey<String>('maintenance-specimen-read-only'),
          label: context.l10n.system_surfacesMaintenanceSpecimenReadOnlyLabel,
          block: true,
          onPressed: onReadOnly,
        ),
      );
    }
    return _StatePage(
      title: context.l10n.system_surfacesMaintenanceSpecimenTitle,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesMaintenanceSpecimenKicker,
        heading: notice.windowLabel ?? context.l10n.system_surfacesHeading2,
        caption: context.l10n.system_surfacesMaintenanceSpecimenCaption,
        stamp: notice.windowLabel == null
            ? context.l10n.system_surfacesStamp3
            : context.l10n.system_surfacesStamp4,
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        if (notice.detail != null)
          LoopNotice(
            icon: 'mine',
            title: context.l10n.system_surfacesTitle13,
            body: notice.detail!,
          ),
        if (onRecheck != null || onStatus != null)
          LoopButtonPair(
            children: <Widget>[
              if (onRecheck != null)
                LoopButton(
                  label: context.l10n.system_surfacesLabel8,
                  primary: true,
                  onPressed: onRecheck,
                ),
              if (onStatus != null)
                LoopButton(
                  label: context.l10n.system_surfacesLabel9,
                  onPressed: onStatus,
                ),
            ],
          ),
      ],
      primaryAction: onReadOnly == null
          ? null
          : LoopButton(
              label:
                  context.l10n.system_surfacesMaintenanceSpecimenReadOnlyLabel,
              block: true,
              onPressed: onReadOnly,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// region-blocked
// ---------------------------------------------------------------------------

class _RegionPage extends StatelessWidget {
  const _RegionPage({
    required this.restriction,
    required this.onViewAssets,
    required this.onExportKey,
    required this.onSupport,
    required this.onPolicy,
    required this.onReturn,
    required this.onBack,
  });

  final LoopFeatureAvailabilityRestriction? restriction;

  /// `#scr-region-blocked` exits, in the prototype's order. A restricted owner
  /// keeps control of their assets, so the page keeps the three ways to act on
  /// them even while the product is closed.
  final VoidCallback? onViewAssets;
  final VoidCallback? onExportKey;
  final VoidCallback? onSupport;
  final VoidCallback? onPolicy;
  final VoidCallback? onReturn;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final restriction = this.restriction;
    if (restriction == null) {
      return _StatePage(
        title: context.l10n.system_surfacesTitle14,
        onBack: onBack,
        folio: LoopFolioPrimary(
          headingMaxLines: 2,
          captionMaxLines: 3,
          ring: false,
          kicker: context.l10n.system_surfacesKicker5,
          heading: context.l10n.system_surfacesHeading3,
          caption: context.l10n.system_surfacesCaption4,
          stamp: context.l10n.common_unknown,
          // S241b: flat dark card, Chalk heading (no light slab on Ink).
          variant: LoopFolioVariant.quiet,
          headingTone: LoopFolioHeadingTone.neutral,
          archetype: LoopFolioArchetype.state,
        ),
        body: <Widget>[
          _SourceUnavailableNotice(
            keyName: 'region-policy-unavailable',
            title: context.l10n.system_surfacesTitle15,
            body: context.l10n.system_surfacesBody11,
          ),
        ],
        primaryAction: _returnAction(onReturn),
      );
    }
    return _PolicyGatePage(
      // A restriction is not a whole-app block: the three exits are the way
      // off this page, so it does not trap the back gesture.
      blocking: false,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesKicker5,
        heading: context.l10n.system_surfacesHeading4,
        caption: restriction.readOnlyAssetAccess == true
            ? context.l10n.system_surfacesCaption5
            : context.l10n.system_surfacesCaption6,
        stamp: context.l10n.system_surfacesStamp5,
        // S241b: flat dark card, Chalk heading (no light slab on Ink).
        variant: LoopFolioVariant.quiet,
        headingTone: LoopFolioHeadingTone.neutral,
        archetype: LoopFolioArchetype.state,
      ),
      facts: <Widget>[
        LoopNotice(
          icon: 'globe',
          title: context.l10n.system_surfacesTitle16,
          body: context.l10n.system_surfacesBody12,
        ),
      ],
      exits: <Widget>[
        _PolicyExit(
          id: 'view-assets',
          label: context.l10n.system_surfacesLabel10,
          primary: true,
          onPressed: onViewAssets,
          unavailableReason: context.l10n.system_surfacesUnavailableReason2,
        ),
        _PolicyExit(
          id: 'export-key',
          label: context.l10n.system_surfacesLabel11,
          onPressed: onExportKey,
          unavailableReason: context.l10n.system_surfacesUnavailableReason3,
        ),
        _PolicyExit(
          id: 'support',
          label: context.l10n.system_surfacesLabel4,
          onPressed: onSupport,
          unavailableReason: context.l10n.system_surfacesUnavailableReason4,
        ),
        if (onPolicy != null)
          _PolicyExit(
            id: 'policy',
            label: context.l10n.system_surfacesLabel12,
            onPressed: onPolicy,
            unavailableReason: context.l10n.system_surfacesUnavailableReason5,
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
    shortName: LoopL10n.current.common_notifications,
    icon: 'bell',
    purpose: LoopL10n.current.system_surfacesPurpose,
    deniedBody: LoopL10n.current.system_surfacesDeniedBody,
  ),
  LoopPermissionKind.camera => (
    shortName: LoopL10n.current.system_surfacesShortName,
    icon: 'camera',
    purpose: LoopL10n.current.system_surfacesPurpose2,
    deniedBody: LoopL10n.current.system_surfacesDeniedBody2,
  ),
  LoopPermissionKind.microphone => (
    shortName: LoopL10n.current.system_surfacesShortName2,
    icon: 'mic',
    purpose: LoopL10n.current.system_surfacesPurpose3,
    deniedBody: LoopL10n.current.system_surfacesDeniedBody3,
  ),
};

class _PermissionPage extends StatelessWidget {
  const _PermissionPage({
    required this.prompt,
    required this.onRequest,
    required this.onOpenSettings,
    required this.onNotNow,
    required this.onBack,
  });

  final LoopPermissionPrompt? prompt;
  final VoidCallback? onRequest;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onNotNow;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final prompt = this.prompt;
    final denied = prompt?.mode == LoopPermissionPromptMode.settingsRecovery;
    final copy = prompt == null ? null : _permissionCopy(prompt.kind);
    return _StatePage(
      title: context.l10n.system_surfacesPermissionDeniedSpecimenTitle,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesKicker6,
        heading: context.l10n.system_surfacesHeading5,
        caption: context.l10n.system_surfacesCaption7,
        stamp: context.l10n.system_surfacesStamp6,
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        LoopLabel(context.l10n.system_surfacesLoopLabel2, tight: true),
        LoopNotice(
          icon: 'bell',
          title: context.l10n.system_surfacesTitle17,
          body: context.l10n.system_surfacesPurpose,
        ),
        LoopNotice(
          icon: 'camera',
          title: context.l10n.system_surfacesTitle18,
          body: context.l10n.system_surfacesPurpose2,
        ),
        LoopNotice(
          icon: 'user',
          title: context.l10n.system_surfacesTitle19,
          body: context.l10n.system_surfacesBody13,
        ),
        if (copy == null) ...<Widget>[
          // No live prompt: the page shows the prototype's 被拒后的引导 as a
          // specimen instead of a card saying there is nothing to show
          // (audit §K.5). It is the same LoopPermissionState the real
          // request uses, so this group is the component's own baseline.
          LoopLabel(context.l10n.system_surfacesLoopLabel3, followsLabel: true),
          LoopPermissionState(
            key: const ValueKey<String>('permission-denied-specimen'),
            icon: 'bell',
            denied: true,
            title: context.l10n.system_surfacesPermissionDeniedSpecimenTitle2,
            purpose: context.l10n.system_surfacesDeniedBody,
            onOpenSettings:
                onOpenSettings ??
                (LoopToastHost.maybeOf(context) == null
                    ? null
                    : () => LoopToast.show(
                        context,
                        message: context.l10n.system_surfacesMessage,
                        kind: LoopToastKind.warn,
                      )),
          ),
          const SizedBox(height: 20),
        ] else ...<Widget>[
          LoopLabel(
            denied
                ? context.l10n.system_surfacesLoopLabel4
                : context.l10n.system_surfacesS,
            followsLabel: true,
          ),
          LoopPermissionState(
            key: ValueKey<String>(
              'permission-prompt-${prompt!.kind.name}-${prompt.mode.name}',
            ),
            icon: copy.icon,
            denied: denied,
            title: denied
                ? context.l10n.system_surfacesTitle20(copy.shortName)
                : context.l10n.system_surfacesTitle21(copy.shortName),
            purpose: denied ? copy.deniedBody : copy.purpose,
            onRequest: onRequest,
            onOpenSettings: onOpenSettings,
            requestLabel: context.l10n.common_continueAction,
            settingsLabel: context.l10n.system_surfacesSettingsLabel,
          ),
          if (onNotNow != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: LoopButton(
                label: context.l10n.system_surfacesLabel13,
                block: true,
                onPressed: onNotNow,
              ),
            ),
        ],
      ],
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

  static List<(String, LoopToastKind, String)> get samples =>
      <(String, LoopToastKind, String)>[
        (
          LoopL10n.current.common_success,
          LoopToastKind.ok,
          LoopL10n.current.system_surfacesText,
        ),
        (
          LoopL10n.current.system_surfacesText2,
          LoopToastKind.warn,
          LoopL10n.current.system_surfacesText3,
        ),
        (
          LoopL10n.current.system_surfacesText4,
          LoopToastKind.err,
          LoopL10n.current.system_surfacesText5,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    final hasFeedback = feedback?.presentationMessage != null;
    final canToast = LoopToastHost.maybeOf(context) != null;
    return _StatePage(
      title: context.l10n.system_surfacesTitle22,
      kicker: hasFeedback ? null : loopComponentSpecimenLabel,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesKicker7,
        heading: context.l10n.system_surfacesTitle22,
        caption: context.l10n.system_surfacesCaption8,
        stamp: context.l10n.system_surfacesStamp7,
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        if (hasFeedback) ...<Widget>[
          LoopLabel(context.l10n.system_surfacesLoopLabel5, tight: true),
          LoopGlobalNotice(
            feedback: feedback!,
            onAction: onAction,
            onDismiss: onDismiss,
          ),
        ],
        LoopNotice(icon: 'info', body: context.l10n.system_surfacesBody14),
        for (final (label, kind, message) in samples) ...<Widget>[
          LoopLabel(label, followsLabel: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: LoopButton(
              key: ValueKey<String>('toast-trigger-${kind.name}'),
              label: context.l10n.system_surfacesLabel14(label),
              block: true,
              onPressed: canToast
                  ? () => LoopToast.show(context, message: message, kind: kind)
                  : null,
            ),
          ),
        ],
        LoopLabel(context.l10n.system_surfacesLoopLabel6, followsLabel: true),
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
      title: context.l10n.system_surfacesLoadingPresentationActiveTitle,
      kicker: valid ? null : loopComponentSpecimenLabel,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesKicker8,
        heading: context.l10n.system_surfacesLoadingPresentationActiveTitle,
        caption: context.l10n.system_surfacesCaption9,
        stamp: context.l10n.system_surfacesStamp8,
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        if (valid) ...<Widget>[
          LoopLabel(context.l10n.system_surfacesLoopLabel7, tight: true),
          LoopNotice(
            key: const ValueKey<String>('loading-presentation-active'),
            icon: 'clock',
            body: context.l10n.system_surfacesLoadingPresentationActiveBody(
              switch (presentation.kind) {
                LoopSkeletonKind.list =>
                  context.l10n.system_surfacesSkeletonList,
                LoopSkeletonKind.detail =>
                  context.l10n.system_surfacesSkeletonDetail,
                LoopSkeletonKind.chart =>
                  context.l10n.system_surfacesSkeletonChart,
              },
            ),
          ),
          LoopSkeletonView(presentation: presentation),
        ],
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
        LoopLabel(context.l10n.system_surfacesLoopLabel8, followsLabel: true),
        const LoopSkeleton(type: LoopSkeletonType.list, rows: 3),
        LoopLabel(context.l10n.system_surfacesLoopLabel9),
        const LoopSkeleton(type: LoopSkeletonType.detail),
        LoopLabel(context.l10n.system_surfacesLoopLabel10),
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
  const _TokenCardStatesPage({required this.showcase, required this.onBack});

  final LoopSystemShowcase? showcase;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // This page *is* the Token Card's specification, so it renders the five
    // states itself. Nothing here comes from a Provider and nothing here is
    // a reading — the bar above the folio says so, and the Development
    // Preview root replaces the label with its own.
    final showcase = this.showcase ?? buildLoopSystemSpecimens();
    final items = showcase.tokenCards;
    return _StatePage(
      title: context.l10n.system_surfacesTitle23,
      kicker: showcase.sourceLabel,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesKicker9,
        heading: context.l10n.system_surfacesHeading6,
        stamp: context.l10n.system_surfacesStamp9,
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        for (final (index, item) in items.indexed) ...<Widget>[
          LoopLabel(item.label, followsLabel: index > 0, tight: index == 0),
          LoopTokenCard(
            state: item.state,
            model: item.model,
            actions: item.actions,
            chalk: item.chalk,
          ),
          // The prototype folds this note under the first card, where it
          // answers the question the first card raises.
          if (index == 0)
            LoopDisclosure(
              summary: context.l10n.system_surfacesSummary,
              child: LoopNotice(
                margin: EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  10,
                  LoopSpacing.page,
                  14,
                ),
                body: context.l10n.system_surfacesBody15,
              ),
            ),
        ],
        LoopNotice(
          margin: EdgeInsets.fromLTRB(
            LoopSpacing.page,
            14,
            LoopSpacing.page,
            14,
          ),
          title: context.l10n.system_surfacesTitle24,
          body: context.l10n.system_surfacesBody16,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// sign-sheet-states
// ---------------------------------------------------------------------------

class _SignSheetStatesPage extends StatelessWidget {
  const _SignSheetStatesPage({required this.showcase, required this.onBack});

  final LoopSystemShowcase? showcase;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final showcase = this.showcase ?? buildLoopSystemSpecimens();
    final items = showcase.signSheets;
    return _StatePage(
      title: context.l10n.system_surfacesSignSheetTriggerPendingTitle,
      kicker: showcase.sourceLabel,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesKicker10,
        heading: context.l10n.system_surfacesHeading7,
        caption: context.l10n.system_surfacesCaption10,
        stamp: context.l10n.common_security,
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[
        LoopNotice(
          icon: 'lock',
          title: context.l10n.system_surfacesTitle25,
          body: context.l10n.system_surfacesBody17,
        ),
        for (final item in items) ...<Widget>[
          LoopLabel(item.label, followsLabel: true),
          if (item.state == LoopSignSheetState.pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: LoopButton(
                key: const ValueKey<String>('sign-sheet-trigger-pending'),
                label: context.l10n.system_surfacesSignSheetTriggerPendingLabel,
                block: true,
                onPressed: () => LoopSignSheet.show(
                  context,
                  sheet: LoopSignSheet(
                    state: item.state,
                    facts: item.facts,
                    reason: item.reason,
                    confirmLabel: context.l10n.common_confirm,
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
                confirmLabel: context.l10n.common_confirm,
                onConfirm: () {},
                onCancel: () {},
                onAdjustPolicy: item.state == LoopSignSheetState.policyRejected
                    ? () {}
                    : null,
              ),
            ),
        ],
        LoopNotice(
          margin: EdgeInsets.fromLTRB(
            LoopSpacing.page,
            14,
            LoopSpacing.page,
            14,
          ),
          title: context.l10n.system_surfacesTitle26,
          body: context.l10n.system_surfacesBody18,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _UnknownSystemPage extends StatelessWidget {
  const _UnknownSystemPage({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return _StatePage(
      title: context.l10n.system_surfacesTitle27,
      onBack: onBack,
      folio: LoopFolioPrimary(
        headingMaxLines: 2,
        captionMaxLines: 3,
        ring: false,
        kicker: context.l10n.system_surfacesTitle27,
        heading: context.l10n.system_surfacesHeading8,
        caption: context.l10n.system_surfacesCaption11,
        archetype: LoopFolioArchetype.state,
      ),
      body: <Widget>[LoopNotice(body: context.l10n.system_surfacesBody19)],
    );
  }
}
