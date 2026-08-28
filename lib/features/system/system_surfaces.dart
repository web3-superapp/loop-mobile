import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

enum LoopConnectivityScope {
  fullyOffline,
  marketDataUnavailable,
  tradingServiceUnavailable,
}

enum LoopPermissionKind { camera, notifications, microphone }

enum LoopPermissionPromptMode { education, settingsRecovery }

enum LoopNoticeKind { success, warning, error }

enum LoopSkeletonKind { list, detail, chart }

typedef SystemAction = void Function();

/// Presentation-safe evidence of an error or unconfirmed request outcome.
///
/// The owning feature keeps the raw exception, response, retry semantics, and
/// every provider/support identifier. This marker intentionally carries none.
@immutable
final class LoopServiceErrorObservation {
  const LoopServiceErrorObservation();
}

/// Evidence that an approved minimum-version policy blocks this build.
///
/// Version, platform, policy freshness, and store-destination facts remain at
/// the future app-level policy boundary. This marker carries none of them.
@immutable
final class LoopForceUpdateRequirement {
  const LoopForceUpdateRequirement();
}

/// Evidence that an approved maintenance notice is currently active.
///
/// The future app-level source owns notice identity, freshness, timing, and
/// affected services. This presentation marker intentionally carries none.
@immutable
final class LoopMaintenanceNotice {
  const LoopMaintenanceNotice();
}

/// Evidence that an approved current decision restricts feature availability.
///
/// The future app-level source owns decision identity, freshness, location,
/// reason, and affected capabilities. This presentation marker carries none.
@immutable
final class LoopFeatureAvailabilityRestriction {
  const LoopFeatureAvailabilityRestriction();
}

/// Presentation-safe permission context selected by the exact owning feature.
///
/// The future platform adapter owns OS status reads and native requests. This
/// value carries only the reviewed permission kind and next presentation mode.
@immutable
final class LoopPermissionPrompt {
  const LoopPermissionPrompt({required this.kind, required this.mode});

  final LoopPermissionKind kind;
  final LoopPermissionPromptMode mode;
}

/// Presentation-safe feedback supplied by the exact feature that observed it.
///
/// The owning feature keeps raw exceptions, request identifiers, provider
/// payloads, retry semantics, and any sensitive values. This projection carries
/// only reviewed display copy and an optional exact action label.
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
///
/// List placeholder count controls visual density only. It never predicts a
/// provider result count or proves that a request was sent.
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

/// Single routing surface for global system UI I1-I8.
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
    this.onRegionContinue,
    this.onRegionPolicy,
    this.onPermissionRequest,
    this.onPermissionOpenSettings,
    this.onPermissionNotNow,
    this.onFeedbackAction,
    this.onFeedbackDismiss,
    this.connectivityScope,
    this.serviceErrorObservation,
    this.forceUpdateRequirement,
    this.maintenanceNotice,
    this.featureAvailabilityRestriction,
    this.permissionPrompt,
    this.globalFeedback,
    this.loadingPresentation,
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
  };

  final String surfaceId;
  final SystemAction? onRetry;
  final SystemAction? onPrimaryAction;
  final SystemAction? onSecondaryAction;
  final SystemAction? onServiceRetry;
  final SystemAction? onServiceSupport;
  final SystemAction? onForceUpdate;
  final SystemAction? onMaintenanceRecheck;
  final SystemAction? onMaintenanceStatus;
  final SystemAction? onRegionContinue;
  final SystemAction? onRegionPolicy;
  final SystemAction? onPermissionRequest;
  final SystemAction? onPermissionOpenSettings;
  final SystemAction? onPermissionNotNow;
  final SystemAction? onFeedbackAction;
  final SystemAction? onFeedbackDismiss;
  final LoopConnectivityScope? connectivityScope;
  final LoopServiceErrorObservation? serviceErrorObservation;
  final LoopForceUpdateRequirement? forceUpdateRequirement;
  final LoopMaintenanceNotice? maintenanceNotice;
  final LoopFeatureAvailabilityRestriction? featureAvailabilityRestriction;
  final LoopPermissionPrompt? permissionPrompt;
  final LoopGlobalFeedback? globalFeedback;
  final LoopLoadingPresentation? loadingPresentation;

  String get _id => surfaceId.replaceFirst('#', '').toLowerCase();

  @override
  Widget build(BuildContext context) {
    return switch (_id) {
      'offline' =>
        connectivityScope == null
            ? _ConnectivityUnavailableScreen(onContinue: onSecondaryAction)
            : _ConnectivityScreen(
                scope: connectivityScope!,
                onRetry: onRetry,
                onContinue: onSecondaryAction,
              ),
      'server-error' =>
        serviceErrorObservation == null
            ? _ServiceErrorUnavailableScreen(onContinue: onSecondaryAction)
            : _ServerErrorScreen(
                onRetry: onServiceRetry,
                onSupport: onServiceSupport,
              ),
      'force-update' =>
        forceUpdateRequirement == null
            ? _UpdateStatusUnavailableScreen(onContinue: onSecondaryAction)
            : _ForceUpdateScreen(onUpdate: onForceUpdate),
      'maintenance' =>
        maintenanceNotice == null
            ? _MaintenanceStatusUnavailableScreen(onContinue: onSecondaryAction)
            : _MaintenanceScreen(
                onRecheck: onMaintenanceRecheck,
                onStatus: onMaintenanceStatus,
              ),
      'region-restricted' =>
        featureAvailabilityRestriction == null
            ? _FeatureAvailabilityStatusUnavailableScreen(
                onContinue: onSecondaryAction,
              )
            : _FeatureAvailabilityRestrictedScreen(
                onContinue: onRegionContinue,
                onPolicy: onRegionPolicy,
              ),
      'permission' =>
        permissionPrompt == null
            ? _PermissionStatusUnavailableScreen(onContinue: onSecondaryAction)
            : _PermissionScreen(
                prompt: permissionPrompt!,
                onRequest: onPermissionRequest,
                onOpenSettings: onPermissionOpenSettings,
                onNotNow: onPermissionNotNow,
              ),
      'toast' =>
        globalFeedback?.presentationMessage == null
            ? _FeedbackStatusUnavailableScreen(onContinue: onSecondaryAction)
            : _GlobalFeedbackScreen(
                feedback: globalFeedback!,
                onAction: onFeedbackAction,
                onDismiss: onFeedbackDismiss,
              ),
      'loading' =>
        loadingPresentation == null || !loadingPresentation!.isPresentable
            ? _LoadingContextUnavailableScreen(onContinue: onSecondaryAction)
            : _LoadingScreen(presentation: loadingPresentation!),
      _ => const _UnknownSystemScreen(),
    };
  }
}

/// Compact app-wide connectivity banner for I1.
class LoopConnectivityBanner extends StatelessWidget {
  const LoopConnectivityBanner({required this.scope, super.key, this.onRetry});

  final LoopConnectivityScope scope;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final content = _connectivityContent(scope);
    final useStackedLayout = MediaQuery.textScalerOf(context).scale(10) > 15;
    return Material(
      color: content.color.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          label: '${content.title}. ${content.message}',
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: content.color.withValues(alpha: 0.32),
                ),
              ),
            ),
            child: useStackedLayout
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(content.icon, color: content.color, size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              content.banner,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: content.color),
                            ),
                          ),
                        ],
                      ),
                      if (onRetry != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Icon(content.icon, color: content.color, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          content.banner,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: content.color),
                        ),
                      ),
                      if (onRetry != null)
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// I7 success/warning/error notice. Its host owns placement and lifetime.
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
    final (color, icon, label) = switch (feedback.kind) {
      LoopNoticeKind.success => (
        LoopColors.mint,
        Icons.check_circle_outline_rounded,
        'Success',
      ),
      LoopNoticeKind.warning => (
        LoopColors.warning,
        Icons.warning_amber_rounded,
        'Warning',
      ),
      LoopNoticeKind.error => (
        LoopColors.danger,
        Icons.error_outline_rounded,
        'Error',
      ),
    };
    final useStackedLayout = MediaQuery.textScalerOf(context).scale(10) > 15;
    final actionLabel = feedback.presentationActionLabel;
    final actions = <Widget>[
      if (actionLabel != null && onAction != null)
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      if (onDismiss != null)
        Semantics(
          button: true,
          label: 'Dismiss',
          onTap: onDismiss,
          child: ExcludeSemantics(
            child: IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
          ),
        ),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: '$label. $message',
      child: Material(
        color: LoopColors.basalt,
        borderRadius: LoopRadius.medium,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: LoopRadius.medium,
            border: Border.all(color: color.withValues(alpha: 0.38)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: LoopColors.abyss.withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: useStackedLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ExcludeSemantics(
                          child: Icon(icon, color: color, size: 21),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: ExcludeSemantics(
                            child: Text(
                              message,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (actions.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: actions,
                        ),
                      ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    ExcludeSemantics(child: Icon(icon, color: color, size: 21)),
                    const SizedBox(width: 11),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
        ),
      ),
    );
  }
}

/// I8 reusable skeleton. It intentionally does not shimmer, so reduced-motion
/// users and ordinary users receive the same calm loading state.
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
    final semanticLabel = switch (presentation.kind) {
      LoopSkeletonKind.list => 'Loading list content',
      LoopSkeletonKind.detail => 'Loading detail content',
      LoopSkeletonKind.chart => 'Loading chart content',
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: switch (presentation.kind) {
          LoopSkeletonKind.list => _ListSkeleton(
            itemCount: presentation.placeholderCount,
          ),
          LoopSkeletonKind.detail => const _DetailSkeleton(),
          LoopSkeletonKind.chart => const _ChartSkeleton(),
        },
      ),
    );
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
        icon: const Icon(
          Icons.system_update_alt_rounded,
          color: LoopColors.mint,
          size: 34,
        ),
        title: const Text('Update LOOP to continue'),
        content: const Text(
          'An approved version policy requires a supported build before you can continue. Install a supported version before returning to LOOP.',
        ),
        actions: <Widget>[
          FilledButton(onPressed: onUpdate, child: const Text('Update now')),
        ],
      ),
    ),
  );
}

class _ConnectivityUnavailableScreen extends StatelessWidget {
  const _ConnectivityUnavailableScreen({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: 'CONNECTIVITY',
      title: 'Connectivity status unavailable',
      subtitle: 'LOOP did not receive a verified device or service connectivity signal for this page.',
      bottom: onContinue == null
          ? null
          : LoopActionDock(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  child: const Text('Return to LOOP'),
                ),
              ),
            ),
      children: const <Widget>[
        LoopStateCard(
          key: ValueKey<String>('connectivity-source-unavailable'),
          title: 'No connectivity source connected',
          message: 'Opening this route does not mean the device is offline or that a LOOP service failed. Live status remains unknown until an approved source reports it.',
          icon: Icons.help_outline_rounded,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _ConnectivityScreen extends StatelessWidget {
  const _ConnectivityScreen({
    required this.scope,
    required this.onRetry,
    required this.onContinue,
  });

  final LoopConnectivityScope scope;
  final VoidCallback? onRetry;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final content = _connectivityContent(scope);
    final fullyOffline = scope == LoopConnectivityScope.fullyOffline;
    return _SystemStateScaffold(
      eyebrow: fullyOffline ? 'NO CONNECTION' : 'SERVICE INTERRUPTED',
      title: content.title,
      message: content.message,
      icon: content.icon,
      tone: content.color,
      primaryLabel: 'Try again',
      onPrimary: onRetry,
      secondaryLabel: fullyOffline
          ? 'Use downloaded content'
          : 'Continue with available features',
      onSecondary: onContinue,
      detail: fullyOffline
          ? 'Live prices, messages, balances, and orders may be out of date while you’re offline.'
          : 'Other parts of LOOP remain available. Affected actions stay disabled until the service recovers.',
    );
  }
}

class _ServerErrorScreen extends StatelessWidget {
  const _ServerErrorScreen({required this.onRetry, required this.onSupport});

  final VoidCallback? onRetry;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'SERVICE ERROR',
      title: 'LOOP couldn’t confirm the result',
      message: 'The request did not return a confirmed outcome. Do not assume success or failure; check the latest state before trying again.',
      icon: Icons.cloud_off_outlined,
      tone: LoopColors.danger,
      primaryLabel: onRetry == null ? null : 'Try again',
      onPrimary: onRetry,
      secondaryLabel: onSupport == null ? null : 'Contact support',
      onSecondary: onSupport,
      detail: 'Support references remain hidden until their exact source and format are reviewed.',
    );
  }
}

class _ServiceErrorUnavailableScreen extends StatelessWidget {
  const _ServiceErrorUnavailableScreen({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'SERVICE STATUS',
      title: 'Service error status unavailable',
      message: 'Opening this route does not mean that a LOOP request or provider returned an error or an unconfirmed outcome. A feature must supply one exact observation before this page can report it.',
      icon: Icons.help_outline_rounded,
      tone: LoopColors.warning,
      secondaryLabel: onContinue == null ? null : 'Return to LOOP',
      onSecondary: onContinue,
      detail: 'No request-error context is connected to this surface.',
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({required this.onUpdate});

  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'UPDATE REQUIRED',
      title: 'Update LOOP to continue',
      message: 'An approved version policy requires a supported build before you can continue.',
      icon: Icons.system_update_alt_rounded,
      tone: LoopColors.mint,
      primaryLabel: onUpdate == null ? null : 'Update now',
      onPrimary: onUpdate,
      detail: onUpdate == null
          ? 'A verified update requirement is present, but no reviewed store action is connected.'
          : 'Install a supported version before returning to LOOP. This requirement cannot be skipped.',
      blocking: true,
    );
  }
}

class _UpdateStatusUnavailableScreen extends StatelessWidget {
  const _UpdateStatusUnavailableScreen({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'VERSION STATUS',
      title: 'Update status unavailable',
      message: 'Opening this route does not mean that this build is unsupported or unsafe. An approved minimum-version policy must explicitly require an update before LOOP can block access.',
      icon: Icons.help_outline_rounded,
      tone: LoopColors.warning,
      secondaryLabel: onContinue == null ? null : 'Return to LOOP',
      onSecondary: onContinue,
      detail: 'No minimum-version policy is connected to this surface.',
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.onRecheck, required this.onStatus});

  final VoidCallback? onRecheck;
  final VoidCallback? onStatus;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'MAINTENANCE NOTICE',
      title: 'Maintenance notice is active',
      message: 'An approved maintenance notice is active. Feature availability still comes from each feature’s own current state.',
      icon: Icons.construction_rounded,
      tone: LoopColors.warning,
      primaryLabel: onRecheck == null ? null : 'Check again',
      onPrimary: onRecheck,
      secondaryLabel: onStatus == null ? null : 'View service status',
      onSecondary: onStatus,
      detail: 'This notice does not include a maintenance window or affected services.',
    );
  }
}

class _MaintenanceStatusUnavailableScreen extends StatelessWidget {
  const _MaintenanceStatusUnavailableScreen({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'MAINTENANCE STATUS',
      title: 'Maintenance status unavailable',
      message: 'Opening this route does not mean that maintenance is planned, active, or affecting a LOOP service. An approved current notice must be supplied before this page can report maintenance.',
      icon: Icons.help_outline_rounded,
      tone: LoopColors.warning,
      secondaryLabel: onContinue == null ? null : 'Return to LOOP',
      onSecondary: onContinue,
      detail: 'No maintenance notice is connected to this surface.',
    );
  }
}

class _FeatureAvailabilityRestrictedScreen extends StatelessWidget {
  const _FeatureAvailabilityRestrictedScreen({
    required this.onContinue,
    required this.onPolicy,
  });

  final VoidCallback? onContinue;
  final VoidCallback? onPolicy;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'FEATURE AVAILABILITY',
      title: 'Some features are unavailable',
      message: 'Feature access is currently limited. Check each feature for its current availability.',
      icon: Icons.public_off_outlined,
      tone: LoopColors.warning,
      primaryLabel: onContinue == null ? null : 'Continue to LOOP',
      onPrimary: onContinue,
      secondaryLabel: onPolicy == null ? null : 'View eligibility policy',
      onSecondary: onPolicy,
      detail: 'This page does not provide a location, reason, or affected features. It does not confirm that any other feature is available.',
    );
  }
}

class _FeatureAvailabilityStatusUnavailableScreen extends StatelessWidget {
  const _FeatureAvailabilityStatusUnavailableScreen({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'FEATURE AVAILABILITY',
      title: 'Availability status unavailable',
      message: 'LOOP cannot confirm feature availability from this page. Opening it does not mean that this account or location is restricted.',
      icon: Icons.help_outline_rounded,
      tone: LoopColors.warning,
      secondaryLabel: onContinue == null ? null : 'Return to LOOP',
      onSecondary: onContinue,
      detail: 'No current availability details are available here.',
    );
  }
}

class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({
    required this.prompt,
    required this.onRequest,
    required this.onOpenSettings,
    required this.onNotNow,
  });

  final LoopPermissionPrompt prompt;
  final VoidCallback? onRequest;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onNotNow;

  @override
  Widget build(BuildContext context) {
    final content = _permissionContent(prompt.kind);
    final settings = prompt.mode == LoopPermissionPromptMode.settingsRecovery;
    final primaryAction = settings ? onOpenSettings : onRequest;
    return _SystemStateScaffold(
      eyebrow: settings ? 'PERMISSION SETTINGS' : 'BEFORE YOU CONTINUE',
      title: settings
          ? 'Review ${content.shortName.toLowerCase()} access in settings'
          : content.title,
      message: settings
          ? 'To change ${content.shortName.toLowerCase()} access, review LOOP in device settings.'
          : content.message,
      icon: content.icon,
      tone: content.color,
      primaryLabel: primaryAction == null
          ? null
          : settings
          ? 'Open settings'
          : 'Continue',
      onPrimary: primaryAction,
      secondaryLabel: onNotNow == null ? null : 'Not now',
      onSecondary: onNotNow,
      detail: settings
          ? 'Returning to LOOP does not prove that this permission changed.'
          : content.detail,
    );
  }
}

class _PermissionStatusUnavailableScreen extends StatelessWidget {
  const _PermissionStatusUnavailableScreen({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'PERMISSION STATUS',
      title: 'Permission status unavailable',
      message: 'LOOP has not received a permission request or device status for this page. Opening it does not mean that a permission is needed or denied.',
      icon: Icons.help_outline_rounded,
      tone: LoopColors.warning,
      secondaryLabel: onContinue == null ? null : 'Return to LOOP',
      onSecondary: onContinue,
      detail: 'Start from the feature you want to use so LOOP can explain the exact request.',
    );
  }
}

class _GlobalFeedbackScreen extends StatelessWidget {
  const _GlobalFeedbackScreen({
    required this.feedback,
    required this.onAction,
    required this.onDismiss,
  });

  final LoopGlobalFeedback feedback;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'GLOBAL FEEDBACK',
      title: 'Feature feedback',
      message: 'This notice was supplied by the feature that observed the current outcome.',
      icon: Icons.campaign_outlined,
      tone: LoopColors.vapor,
      content: LoopGlobalNotice(
        feedback: feedback,
        onAction: onAction,
        onDismiss: onDismiss,
      ),
      detail: 'The owning feature keeps raw errors, identifiers, sensitive values, and retry semantics out of this feedback.',
    );
  }
}

class _FeedbackStatusUnavailableScreen extends StatelessWidget {
  const _FeedbackStatusUnavailableScreen({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'GLOBAL FEEDBACK',
      title: 'Feedback context unavailable',
      message: 'No feature supplied a current success, warning, or error outcome for this page.',
      icon: Icons.help_outline_rounded,
      tone: LoopColors.warning,
      secondaryLabel: onContinue == null ? null : 'Return to LOOP',
      onSecondary: onContinue,
      detail: 'Opening this route does not mean that an action succeeded, a warning was observed, or an error occurred.',
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.presentation});

  final LoopLoadingPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final (name, detail) = switch (presentation.kind) {
      LoopSkeletonKind.list => (
        'list',
        'Placeholder rows set visual density only. They do not predict a result count, identity, freshness, or success.',
      ),
      LoopSkeletonKind.detail => (
        'detail',
        'This placeholder does not prove that an object exists, is accessible, or will load successfully.',
      ),
      LoopSkeletonKind.chart => (
        'chart',
        'This placeholder does not prove that prices, candles, provider history, freshness, continuity, or success exist.',
      ),
    };
    return _SystemStateScaffold(
      eyebrow: 'LOADING',
      title: 'Loading in progress',
      message:
          'The owning feature selected a $name placeholder for its current pending state.',
      icon: Icons.hourglass_top_rounded,
      tone: LoopColors.vapor,
      content: LoopSkeletonView(presentation: presentation),
      detail: detail,
    );
  }
}

class _LoadingContextUnavailableScreen extends StatelessWidget {
  const _LoadingContextUnavailableScreen({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _SystemStateScaffold(
      eyebrow: 'LOADING',
      title: 'Loading context unavailable',
      message: 'No feature supplied an active loading state for this page.',
      icon: Icons.help_outline_rounded,
      tone: LoopColors.warning,
      secondaryLabel: onContinue == null ? null : 'Return to LOOP',
      onSecondary: onContinue,
      detail: 'Opening this route does not mean that content is being requested, exists, or will arrive.',
    );
  }
}

class _UnknownSystemScreen extends StatelessWidget {
  const _UnknownSystemScreen();

  @override
  Widget build(BuildContext context) {
    return const _SystemStateScaffold(
      eyebrow: 'SYSTEM',
      title: 'This page is unavailable',
      message: 'LOOP could not identify the requested system page.',
      icon: Icons.route_outlined,
      tone: LoopColors.vapor,
      detail: 'Return to the previous screen and try again.',
    );
  }
}

class _SystemStateScaffold extends StatelessWidget {
  const _SystemStateScaffold({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
    required this.detail,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.content,
    this.blocking = false,
  });

  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;
  final Color tone;
  final String detail;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? content;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      key: ValueKey<String>(
        blocking ? 'system-state-blocking' : 'system-state-dismissible',
      ),
      canPop: !blocking,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: LoopBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const verticalPadding = 46.0;
                  final minContentHeight =
                      constraints.maxHeight > verticalPadding
                      ? constraints.maxHeight - verticalPadding
                      : 0.0;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minContentHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              eyebrow,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: tone, letterSpacing: 1.4),
                            ),
                            const Spacer(),
                            Center(
                              child: _SystemGlyph(icon: icon, color: tone),
                            ),
                            const SizedBox(height: 38),
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              message,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: LoopColors.vapor),
                            ),
                            if (content != null) ...<Widget>[
                              const SizedBox(height: 20),
                              content!,
                            ],
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: LoopColors.basalt,
                                borderRadius: LoopRadius.medium,
                                border: Border.fromBorderSide(
                                  BorderSide(color: LoopColors.line),
                                ),
                              ),
                              child: Text(
                                detail,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const Spacer(),
                            if (primaryLabel != null)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: onPrimary,
                                  child: Text(primaryLabel!),
                                ),
                              ),
                            if (secondaryLabel != null) ...<Widget>[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: onSecondary,
                                  child: Text(secondaryLabel!),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemGlyph extends StatelessWidget {
  const _SystemGlyph({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      child: SizedBox.square(
        dimension: 168,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.16)),
              ),
            ),
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08),
                border: Border.all(color: color.withValues(alpha: 0.38)),
              ),
            ),
            Icon(icon, size: 46, color: color),
            Positioned(top: 9, child: _GlyphNode(color: color)),
            Positioned(
              left: 17,
              bottom: 28,
              child: _GlyphNode(color: color.withValues(alpha: 0.7)),
            ),
            Positioned(
              right: 17,
              bottom: 28,
              child: _GlyphNode(color: color.withValues(alpha: 0.42)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlyphNode extends StatelessWidget {
  const _GlyphNode({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: LoopColors.abyss,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 10),
          child: const LoopCard(
            child: Row(
              children: <Widget>[
                _SkeletonBlock(width: 42, height: 42, circular: true),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SkeletonBlock(width: 132, height: 12),
                      SizedBox(height: 9),
                      _SkeletonBlock(width: 204, height: 9),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const LoopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _SkeletonBlock(width: 54, height: 54, circular: true),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SkeletonBlock(width: 146, height: 15),
                    SizedBox(height: 10),
                    _SkeletonBlock(width: 92, height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _SkeletonBlock(width: double.infinity, height: 12),
          SizedBox(height: 10),
          _SkeletonBlock(width: 244, height: 12),
          SizedBox(height: 10),
          _SkeletonBlock(width: 184, height: 12),
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const LoopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SkeletonBlock(width: 118, height: 12),
          SizedBox(height: 12),
          _SkeletonBlock(width: 176, height: 26),
          SizedBox(height: 22),
          SizedBox(
            height: 112,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: _SkeletonGrid()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: _SkeletonBlock(width: double.infinity, height: 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.circular = false,
  });

  final double width;
  final double height;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: LoopColors.elevated,
        borderRadius: circular ? LoopRadius.pill : LoopRadius.small,
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(
        4,
        (_) =>
            Container(height: 1, color: LoopColors.line.withValues(alpha: 0.7)),
      ),
    );
  }
}

({String title, String message, String banner, IconData icon, Color color})
_connectivityContent(LoopConnectivityScope scope) {
  return switch (scope) {
    LoopConnectivityScope.fullyOffline => (
      title: 'You’re offline',
      message:
          'Reconnect to refresh account, market, chat, and wallet information.',
      banner: 'Offline · live information is paused',
      icon: Icons.wifi_off_rounded,
      color: LoopColors.warning,
    ),
    LoopConnectivityScope.marketDataUnavailable => (
      title: 'Market data is unavailable',
      message: 'Live prices and charts cannot refresh. Trading actions that depend on current prices remain disabled.',
      banner: 'Market data unavailable · prices may be stale',
      icon: Icons.query_stats_rounded,
      color: LoopColors.market,
    ),
    LoopConnectivityScope.tradingServiceUnavailable => (
      title: 'Trading is temporarily unavailable',
      message: 'Orders and account changes cannot be submitted. Market browsing and chat may still work.',
      banner: 'Trading service interrupted · actions paused',
      icon: Icons.sync_problem_rounded,
      color: LoopColors.danger,
    ),
  };
}

({
  String shortName,
  String title,
  String message,
  String detail,
  IconData icon,
  Color color,
})
_permissionContent(LoopPermissionKind kind) {
  return switch (kind) {
    LoopPermissionKind.camera => (
      shortName: 'Camera',
      title: 'Allow camera access to scan',
      message: 'This permission request is for QR scanning.',
      detail: 'The device controls the final permission choice. This page does not start a scanner.',
      icon: Icons.qr_code_scanner_rounded,
      color: LoopColors.market,
    ),
    LoopPermissionKind.notifications => (
      shortName: 'Notification',
      title: 'Choose whether LOOP can notify you',
      message: 'This permission controls whether the operating system may show LOOP notifications.',
      detail: 'Notification preferences and operating-system permission are separate. Allowing access does not enable a category or prove delivery.',
      icon: Icons.notifications_active_outlined,
      color: LoopColors.chat,
    ),
    LoopPermissionKind.microphone => (
      shortName: 'Microphone',
      title: 'Allow microphone access?',
      message:
          'LOOP uses the microphone only after you tap Speak in an audio room.',
      detail: 'Joining an audio room starts with the microphone off. The device controls the final permission choice.',
      icon: Icons.mic_none_rounded,
      color: LoopColors.mint,
    ),
  };
}
