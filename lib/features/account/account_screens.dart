import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/wallet_creation_facts.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_gate.dart';
import 'package:loop_mobile/features/security/mfa/mfa_controller.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_sheet.dart';
import 'package:loop_mobile/features/security/step_up/step_up_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Capabilities confirmed by the Privy integration at runtime.
///
/// The default is deliberately fail-closed. Recovery methods, MFA, private-key
/// export and embedded-wallet creation must never become available because a
/// screen was merely routed to. LOOP has no recovery phrase at all: seed
/// reveal, verify and import were removed with the mnemonic pages.
///
/// These stay local constants rather than a `loopCapabilityProvider` read
/// because the frozen V2 contract has no capability ID for passkey, recovery
/// password, cloud or social recovery, application PIN, transaction MFA or
/// private-key export. When the contract adds them, replace each field with
/// the matching projection instead of widening this struct.
@immutable
class PrivyWalletCapabilities {
  const PrivyWalletCapabilities({
    this.canCreateEmbeddedWallet = false,
    this.canConnectExternalWallet = false,
    this.canUsePasskey = false,
    this.canUseBiometrics = false,
    this.canUseRecoveryPassword = false,
    this.canUseCloudRecovery = false,
    this.canUseSocialRecovery = false,
    this.canExportPrivateKey = false,
    this.canUseApplicationPin = false,
    this.canUseTransactionMfa = false,
    this.secureScreenProtectionActive = false,
  });

  const PrivyWalletCapabilities.unavailable() : this();

  final bool canCreateEmbeddedWallet;
  final bool canConnectExternalWallet;
  final bool canUsePasskey;
  final bool canUseBiometrics;
  final bool canUseRecoveryPassword;
  final bool canUseCloudRecovery;
  final bool canUseSocialRecovery;
  final bool canExportPrivateKey;
  final bool canUseApplicationPin;
  final bool canUseTransactionMfa;
  final bool secureScreenProtectionActive;
}

typedef AccountNavigation = void Function(String destination);

/// Routing surface for the account pages that are not a Privy credential flow.
///
/// `auth` and `auth-otp` live in `privy_login_screen.dart` / `privy_otp_screen
/// .dart`; `loop-id-setup` lives in `loop_id_setup_screen.dart`.
class AccountSurfaceScreen extends StatelessWidget {
  const AccountSurfaceScreen.fromId(
    this.surfaceId, {
    super.key,
    this.capabilities = const PrivyWalletCapabilities.unavailable(),
    this.walletCreation,
    this.onNavigate,
    this.onBack,
    this.onPrimaryAction,
    this.onRecoveryDecision,
    this.splashPhase = LoopSplashPhase.entry,
    this.splashUnavailableReason,
    this.appLock,
    this.onToggleAppLock,
    this.mfa,
    this.onOpenMfa,
    this.onOpenPasskey,
  });

  static const supportedIds = <String>{
    'splash',
    'auth-wallet',
    'wallet-create',
    'wallet-recovery',
    'security-setup',
  };

  final String surfaceId;
  final PrivyWalletCapabilities capabilities;

  /// The wallet observations the 02 page renders. Absent outside the opening
  /// sequence, where nothing has been observed and the page says so.
  final LoopWalletCreationFacts? walletCreation;

  final AccountNavigation? onNavigate;
  final VoidCallback? onBack;
  final VoidCallback? onPrimaryAction;

  /// What step 03 decided, reported with the method the owner chose or
  /// `null` for 稍后设置. It records a decision, never an enrolment.
  final ValueChanged<WalletRecoveryMethod?>? onRecoveryDecision;

  /// What the launch page is waiting for, if anything. Only `splash` reads it.
  final LoopSplashPhase splashPhase;

  /// Why that wait ended with nothing. See [SplashScreen.unavailableReason].
  final String? splashUnavailableReason;

  /// The device-local lock, for `security-setup`. Absent in a tree that
  /// composed none.
  final LoopAppLockState? appLock;
  final VoidCallback? onToggleAppLock;

  /// What the login service says it holds as a second factor, for
  /// `security-setup`. Absent in a tree with no provider behind it.
  final LoopMfaState? mfa;
  final VoidCallback? onOpenMfa;

  /// Opens the passkey binding sheet, for `wallet-recovery`. Absent in a
  /// tree with no provider behind it.
  final VoidCallback? onOpenPasskey;

  String get _id => surfaceId.replaceFirst('#', '').toLowerCase();

  void _navigate(BuildContext context, String destination) {
    onNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_id) {
      'splash' => SplashScreen(
        phase: splashPhase,
        unavailableReason: splashUnavailableReason,
        onContinue: () => _navigate(context, 'auth'),
      ),
      'auth-wallet' => ExternalWalletScreen(
        capabilityAvailable: capabilities.canConnectExternalWallet,
        onBack: onBack,
        onConnect: onPrimaryAction,
      ),
      'wallet-create' => WalletCreateScreen(
        facts:
            walletCreation ??
            (capabilities.canCreateEmbeddedWallet
                ? const LoopWalletCreationFacts(
                    phase: LoopWalletCreationPhase.working,
                  )
                : const LoopWalletCreationFacts.capabilityUnconfirmed()),
        onBack: onBack,
        onContinue: () => _navigate(context, 'wallet-recovery'),
      ),
      'wallet-recovery' => WalletRecoveryScreen(
        capabilities: capabilities,
        mfa: mfa,
        onOpenPasskey: onOpenPasskey,
        onBack: onBack,
        onDecision: onRecoveryDecision,
        onContinue: () => _navigate(context, 'security-setup'),
      ),
      'security-setup' => SecuritySetupScreen(
        capabilities: capabilities,
        appLock: appLock,
        onToggleAppLock: onToggleAppLock,
        mfa: mfa,
        onOpenMfa: onOpenMfa,
        onBack: onBack,
        onContinue: () => _navigate(context, 'loop-id-setup'),
      ),
      _ => const UnknownAccountScreen(),
    };
  }
}

/// `.identity-progress`: step counter, label and a filled track.
class IdentityProgress extends StatelessWidget {
  const IdentityProgress({
    required this.step,
    required this.total,
    required this.label,
    super.key,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Decision 0126: one dot per step and the step's name, instead of the
    // `04 / 05` counter over a filled track.
    return Semantics(
      container: true,
      label: context.l10n.account_screensIdentityProgressTrackLabel(
        label,
        step,
        total,
      ),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: LoopStepDots(
            key: const ValueKey<String>('identity-progress-track'),
            step: step,
            total: total,
            label: label,
          ),
        ),
      ),
    );
  }
}

/// `.identity-step-copy`: one line of primary narrative for a step page.
///
/// It is left-aligned, as `.identity-step-copy` is: the line sits directly
/// under a left-aligned progress track and a left-aligned title, and centring
/// it broke that column on every step page (audit 2026-09-20 §D#9).
class IdentityStepCopy extends StatelessWidget {
  const IdentityStepCopy(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        LoopSpacing.group,
      ),
      child: Semantics(
        container: true,
        child: Text(
          key: const ValueKey<String>('identity-step-copy'),
          text,
          textAlign: TextAlign.start,
          style: LoopType.body.copyWith(color: LoopColors.text2),
        ),
      ),
    );
  }
}

/// `.row-ico`: the 44 square that carries an option row's glyph.
///
/// A recovery method and an app lock are chosen by shape first; the prototype
/// gives each row a filled square so the three read as three things rather
/// than three paragraphs. The glyph turns Lime only on the chosen row
/// (`.row-choice.is-chosen .row-ico`), so the colour is a selection mark and
/// never a claim that the method is available or enrolled.
///
/// Decision 0172: it is the shared [LoopRowIcon] in its `.row-choice` form.
class IdentityOptionIcon extends StatelessWidget {
  const IdentityOptionIcon(this.icon, {this.chosen = false, super.key});

  final String icon;
  final bool chosen;

  @override
  Widget build(BuildContext context) =>
      LoopRowIcon(icon: icon, choice: true, chosen: chosen);
}

/// One recovery / security option whose availability comes from a capability.
/// It is never a switch: nothing here can enrol, configure or store anything.
class CapabilityChoiceRow extends StatelessWidget {
  const CapabilityChoiceRow({
    required this.id,
    required this.title,
    required this.detail,
    required this.available,
    required this.unavailableReason,
    super.key,
    this.position = LoopRowPosition.single,
  });

  /// Stable id for the row's key; the key never spells copy.
  final String id;
  final String title;
  final String detail;
  final bool available;
  final String unavailableReason;
  final LoopRowPosition position;

  @override
  Widget build(BuildContext context) {
    return LoopRecordRow(
      key: ValueKey<String>('capability-$id'),
      title: title,
      subtitle: available ? detail : '$detail · $unavailableReason',
      trailing: available
          ? context.l10n.account_screensTrailing
          : context.l10n.common_unavailable,
      position: position,
      semanticLabel: available
          ? context.l10n.account_screensSemanticLabel(title)
          : context.l10n.account_screensSemanticLabel2(
              title,
              unavailableReason,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// splash · intro / focus
// ---------------------------------------------------------------------------

/// What the launch page is doing while it is on screen.
enum LoopSplashPhase {
  /// The brand frame with the way in. Nothing is being waited on.
  entry,

  /// A credential was accepted and `GET /v2/profile` has not answered yet.
  ///
  /// The page offers no action here on purpose: there is nowhere to go until
  /// the answer says whether this account is already active or still opening,
  /// and any page drawn before it is one the owner would be taken away from
  /// (device report 2026-09-21 · F1).
  preparingAccount,

  /// The wait ended without an answer: the read failed, or it ran past the
  /// ceiling it is given.
  ///
  /// The mark stops here. A rail that keeps sweeping after LOOP has given up
  /// says the account is still being prepared, which is the one thing that is
  /// no longer true, so the movement ends and the reason takes its place.
  accountUnavailable,
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    required this.onContinue,
    super.key,
    this.phase = LoopSplashPhase.entry,
    this.unavailableReason,
  });

  final VoidCallback onContinue;
  final LoopSplashPhase phase;

  /// Why the wait ended with nothing, for [LoopSplashPhase.accountUnavailable].
  ///
  /// It is the reason the rest of the application already shows for the same
  /// failure; the launch page never writes one of its own, and shows no line
  /// at all when it was handed none.
  final String? unavailableReason;

  /// The one line the launch frame says while the account is prepared. The
  /// frames before it (restoring, the hand-over) already say it, so the move
  /// onto this page changes nothing on screen (UX-001).
  static String get preparingText =>
      LoopL10n.current.account_screensPreparingText;

  @override
  Widget build(BuildContext context) {
    final unavailable = phase == LoopSplashPhase.accountUnavailable;
    return LoopLaunchFrame(
      key: const ValueKey<String>('loop-splash-screen'),
      markKey: const ValueKey<String>('loop-splash-wordmark'),
      loaderKey: const ValueKey<String>('loop-splash-loader'),
      // The mark sweeps while something is still being waited on, and
      // settles the moment nothing is: a wait that ended badly gets the still
      // rail and the reason under it.
      waiting: !unavailable,
      status: switch (phase) {
        LoopSplashPhase.preparingAccount => preparingText,
        LoopSplashPhase.accountUnavailable => unavailableReason,
        LoopSplashPhase.entry => null,
      },
      statusKey: switch (phase) {
        LoopSplashPhase.preparingAccount => const ValueKey<String>(
          'loop-splash-preparing',
        ),
        LoopSplashPhase.accountUnavailable => const ValueKey<String>(
          'loop-splash-unavailable',
        ),
        LoopSplashPhase.entry => null,
      },
      // Waiting is not a choice, so it is offered none. The entry frame keeps
      // the prototype's single full-width action.
      bottomAction: phase == LoopSplashPhase.entry
          ? LoopButton(
              key: const ValueKey<String>('loop-splash-enter'),
              label: context.l10n.account_screensLoopSplashEnterLabel,
              primary: true,
              block: true,
              onPressed: onContinue,
            )
          : null,
    );
  }
}

/// UX-001 (decision 0254): the one launch frame.
///
/// A cold start used to walk through three different frames — 「正在恢复登录状态」
/// with a 88 mark set above the middle, a bare 88 mark in the middle for the
/// frame or two before the router moved, and the launch page's 96 mark set
/// higher still, which also slid in as a pushed page. Each looked like the
/// App starting again. Every wait before the first product page now draws
/// this frame: the wordmark exactly where the native launch screen puts it
/// (centred on the whole screen at the launch image's 103 pt), the rail and
/// one status line under it. Moving from one wait to the next only changes
/// that line.
class LoopLaunchFrame extends StatelessWidget {
  const LoopLaunchFrame({
    super.key,
    this.status,
    this.statusKey,
    this.detail,
    this.detailKey,
    this.waiting = true,
    this.showRail = true,
    this.action,
    this.bottomAction,
    this.markKey,
    this.loaderKey,
    this.semanticLabel,
    this.statusStyle,
  });

  /// `LaunchImage` is 160 × 103 pt, centred on the whole screen.
  static const double markHeight = 103;

  /// The gap between the mark's foot and the rail.
  static const double railGap = 28;

  /// The one line under the rail. It is the only thing that changes while
  /// the App waits.
  final String? status;
  final Key? statusKey;

  /// A second line for a wait that ended: the reason, never an explanation.
  final String? detail;
  final Key? detailKey;

  /// Whether the rail sweeps.
  final bool waiting;

  /// A frame that ended its wait with a block of its own may drop the rail.
  final bool showRail;

  /// One next step under the status lines.
  final Widget? action;

  /// The entry frame's full-width action at the foot of the page.
  final Widget? bottomAction;

  final Key? markKey;
  final Key? loaderKey;
  final String? semanticLabel;

  /// The status line's style; the caption step unless a frame says more
  /// than a wait (the App lock's 「LOOP 已锁定」).
  final TextStyle? statusStyle;

  @override
  Widget build(BuildContext context) {
    final line = status;
    final second = detail;
    final next = action;
    final foot = bottomAction;
    return Scaffold(
      backgroundColor: LoopColors.ink,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final middle = constraints.maxHeight / 2;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: middle - markHeight / 2,
                height: markHeight,
                child: Center(
                  child: LoopBrandMark(
                    key: markKey,
                    kind: LoopBrandMarkKind.wordmark,
                    height: markHeight,
                    semanticLabel: 'LOOP',
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: middle + markHeight / 2 + railGap,
                child: Semantics(
                  label: semanticLabel,
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (showRail) ...<Widget>[
                        Center(
                          child: LoopBrandLoader(
                            key: loaderKey,
                            animating: waiting,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      // Only the words change: no fade, no second frame.
                      if (line != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            line,
                            key: statusKey,
                            textAlign: TextAlign.center,
                            style: statusStyle ?? LoopType.caption,
                          ),
                        ),
                      if (second != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            second,
                            key: detailKey,
                            textAlign: TextAlign.center,
                            style: LoopType.caption.copyWith(
                              color: LoopColors.text2,
                            ),
                          ),
                        ),
                      ],
                      if (next != null) ...<Widget>[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LoopSpacing.page,
                          ),
                          child: next,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (foot != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                  child: foot,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// `.loop-brand-loader`: the rail, the Lime line and the dot at its end.
///
/// The prototype's line draws itself once in 1.18s and stops, because in the
/// prototype there is nothing behind it. In the App there is: the launch page
/// holds a verified session until `GET /v2/profile` answers, and on a slow
/// path that answer took more than ten seconds on a real device. A line that
/// filled the rail in a second and then sat still said the work had finished
/// when it had not, and the page read as frozen (device report 2026-09-22).
///
/// So the mark is indeterminate while [animating]: a Lime band sweeps the
/// rail and comes back, with the prototype's dot riding its leading edge. It
/// claims no fraction, because LOOP knows none — it only says the wait is
/// still running.
///
/// [animating] false is the settled reading: the full Lime line with the dot
/// at the right end, which is also what `reduceMotion` is given while the
/// wait is on, so movement is never the only thing carrying the message.
class LoopBrandLoader extends StatefulWidget {
  const LoopBrandLoader({super.key, this.width = 244, this.animating = true});

  /// `.loop-brand-loader{width:min(244px,64vw)}`.
  final double width;

  /// Whether something is still being waited on.
  final bool animating;

  /// One end-to-end pass of the band. `reverse` makes the return trip, so a
  /// full cycle is twice this.
  static const Duration sweep = Duration(milliseconds: 1150);

  /// `.loop-brand-loader-track{height:12px}`.
  static const double trackHeight = 12;

  /// How much of the rail the travelling band covers.
  static const double bandWidth = 84;

  /// `.loop-brand-loader-rail,.loop-brand-loader-line{stroke-width:2}`.
  static const double railThickness = 2;

  /// `.loop-brand-loader-point` — the 8px dot the prototype lands with.
  static const double pointSize = 8;

  @override
  State<LoopBrandLoader> createState() => LoopBrandLoaderState();
}

class LoopBrandLoaderState extends State<LoopBrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LoopBrandLoader.sweep,
  );

  /// Whether the band is moving right now.
  ///
  /// Exposed so a test can hold the two facts apart: the rail sweeps while the
  /// account is being prepared, and stops the moment the wait ends — which is
  /// the whole of this widget's behaviour and cannot be read off one frame.
  @visibleForTesting
  bool get isSweeping => _controller.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant LoopBrandLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (_settled) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      // UX-001 (decision 0254): every rail on the way in reads one clock, so
      // a rail that replaces another (restoring → hand-over → the launch page)
      // picks the band up where the last one left it instead of restarting
      // it from the left edge.
      final sweep = LoopBrandLoader.sweep.inMicroseconds;
      final phase = (_launchClock.elapsedMicroseconds % (2 * sweep)) / sweep;
      if (phase < 1) {
        _controller.value = phase;
        _controller.repeat(reverse: true);
      } else {
        _controller.value = 2 - phase;
        unawaited(
          _controller.reverse().then((_) {
            if (mounted && !_settled) _controller.repeat(reverse: true);
          }, onError: (Object _) {}),
        );
      }
    }
  }

  /// One clock for every rail in the run.
  static final Stopwatch _launchClock = Stopwatch()..start();

  /// The still reading: the wait is over, or the device asked for less motion.
  bool get _settled =>
      !widget.animating || MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Spoken from the wait itself, never from whether the band happens to
      // move: a reduced-motion device is still waiting and still says so.
      label: widget.animating ? context.l10n.account_screensLabel : 'LOOP',
      liveRegion: widget.animating,
      child: SizedBox(
        width: widget.width,
        height: LoopBrandLoader.trackHeight,
        child: _settled ? _settledRail() : _sweepingRail(),
      ),
    );
  }

  /// `.loop-brand-loader-line` at `stroke-dashoffset:0` with the point shown —
  /// the frame the prototype's own reduced-motion rule draws.
  Widget _settledRail() {
    return Center(
      child: Stack(
        alignment: Alignment.centerRight,
        children: <Widget>[
          Container(
            height: LoopBrandLoader.railThickness,
            decoration: BoxDecoration(
              color: LoopColors.yellow,
              borderRadius: BorderRadius.circular(
                LoopBrandLoader.railThickness / 2,
              ),
            ),
          ),
          Container(
            width: LoopBrandLoader.pointSize,
            height: LoopBrandLoader.pointSize,
            decoration: const BoxDecoration(
              color: LoopColors.yellow,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sweepingRail() {
    final travel = math.max(0.0, widget.width - LoopBrandLoader.bandWidth);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        // The dot rides whichever end of the band is leading, so the mark
        // reads as one object turning around rather than two crossing.
        final forward = _controller.status != AnimationStatus.reverse;
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            // `.loop-brand-loader-rail{stroke:rgba(243,245,239,.16)}`.
            Container(
              height: LoopBrandLoader.railThickness,
              decoration: BoxDecoration(
                color: LoopColors.line,
                borderRadius: BorderRadius.circular(
                  LoopBrandLoader.railThickness / 2,
                ),
              ),
            ),
            Positioned(
              key: const ValueKey<String>('loop-brand-loader-band'),
              left: travel * t,
              child: SizedBox(
                width: LoopBrandLoader.bandWidth,
                height: LoopBrandLoader.trackHeight,
                child: Center(
                  child: Stack(
                    alignment: forward
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    children: <Widget>[
                      Container(
                        height: LoopBrandLoader.railThickness,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: forward
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            end: forward
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            colors: const <Color>[
                              LoopColors.yellowSoft,
                              LoopColors.yellow,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            LoopBrandLoader.railThickness / 2,
                          ),
                        ),
                      ),
                      Container(
                        width: LoopBrandLoader.pointSize,
                        height: LoopBrandLoader.pointSize,
                        decoration: const BoxDecoration(
                          color: LoopColors.yellow,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// auth-wallet · intro / focus
// ---------------------------------------------------------------------------

class ExternalWalletScreen extends StatelessWidget {
  const ExternalWalletScreen({
    required this.capabilityAvailable,
    super.key,
    this.onBack,
    this.onConnect,
  });

  final bool capabilityAvailable;
  final VoidCallback? onBack;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return LoopFlat(
      step: true,
      child: LoopFocusPage(
        archetype: LoopPageArchetype.intro,
        title: context.l10n.account_screensExternalWalletConnectTitle,
        onBack: onBack,
        actionsFollowBody: true,
        primaryAction: LoopButton(
          key: const ValueKey<String>('external-wallet-connect'),
          label: context.l10n.account_screensExternalWalletConnectLabel,
          primary: true,
          block: true,
          onPressed: capabilityAvailable ? onConnect : null,
        ),
        disclosure: LoopDisclosure(
          summary: context.l10n.account_screensSummary,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopNotice(
                  icon: 'info',
                  title: context.l10n.account_screensTitle,
                  body: context.l10n.account_screensBody,
                  margin: EdgeInsets.only(bottom: 10),
                ),
                LoopNotice(
                  icon: 'mine',
                  title: context.l10n.account_screensTitle2,
                  body: context.l10n.account_screensBody2,
                  margin: EdgeInsets.only(bottom: 10),
                ),
                LoopNotice(
                  icon: 'close',
                  tone: LoopNoticeTone.danger,
                  title: context.l10n.account_screensTitle3,
                  body: context.l10n.account_screensBody3,
                  margin: EdgeInsets.only(bottom: 10),
                ),
                LoopNotice(
                  icon: 'clock',
                  tone: LoopNoticeTone.warn,
                  title: context.l10n.account_screensTitle4,
                  body: context.l10n.account_screensBody4,
                  margin: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        body: <Widget>[
          IdentityProgress(
            step: 1,
            total: 2,
            label: context.l10n.account_screensLabel2,
          ),
          IdentityStepCopy(context.l10n.account_screensIdentityStepCopy),
          if (!capabilityAvailable)
            LoopNotice(
              key: ValueKey<String>('external-wallet-unavailable'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: context.l10n.account_screensExternalWalletUnavailableTitle,
              body: context.l10n.account_screensExternalWalletUnavailableBody,
            ),
          LoopLabel(context.l10n.account_screensLoopLabel),
          LoopInlineUnavailable(
            key: ValueKey<String>('external-wallet-list-unavailable'),
            message: context
                .l10n
                .account_screensExternalWalletListUnavailableMessage,
            detail:
                context.l10n.account_screensExternalWalletListUnavailableDetail,
            maxLines: 2,
            detailMaxLines: 4,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// wallet-create · intro / focus
// ---------------------------------------------------------------------------

class WalletCreateScreen extends StatelessWidget {
  const WalletCreateScreen({
    required this.facts,
    required this.onContinue,
    super.key,
    this.onBack,
  });

  final LoopWalletCreationFacts facts;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final phase = facts.phase;
    final (String headline, String detail) = switch (phase) {
      LoopWalletCreationPhase.observed => (
        context.l10n.account_screensSwitch,
        context.l10n.account_screensSwitch2,
      ),
      LoopWalletCreationPhase.working => (
        context.l10n.account_screensSwitch3,
        context.l10n.account_screensSwitch4,
      ),
      LoopWalletCreationPhase.timedOut => (
        context.l10n.account_screensSwitch5,
        context.l10n.account_screensSwitch6,
      ),
      LoopWalletCreationPhase.unavailable => (
        context.l10n.account_screensSwitch7,
        context.l10n.account_screensSwitch8,
      ),
    };
    return LoopFlat(
      step: true,
      child: LoopFocusPage(
        archetype: LoopPageArchetype.intro,
        title: context.l10n.account_screensWalletCreateContinueTitle,
        onBack: onBack,
        // `.wallet-create-action{margin-top:auto}`: this is the one step page
        // whose button the prototype does push to the bottom, because the ring
        // above it owns the rest of the screen.
        primaryAction: LoopButton(
          key: const ValueKey<String>('wallet-create-continue'),
          label: context.l10n.account_screensWalletCreateContinueLabel,
          primary: true,
          block: true,
          onPressed: facts.canContinue ? onContinue : null,
        ),
        body: <Widget>[
          IdentityProgress(
            step: 2,
            total: 5,
            label: context.l10n.account_screensLabel3,
          ),
          IdentityStepCopy(context.l10n.account_screensIdentityStepCopy2),
          if (phase == LoopWalletCreationPhase.unavailable)
            LoopNotice(
              key: ValueKey<String>('wallet-create-unavailable'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: context.l10n.account_screensWalletCreateUnavailableTitle,
              body: context.l10n.account_screensWalletCreateUnavailableBody,
            ),
          if (facts.providerMessage case final String message)
            LoopNotice(
              key: const ValueKey<String>('wallet-create-provider-message'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title:
                  context.l10n.account_screensWalletCreateProviderMessageTitle,
              body: message,
            ),
          // `.wallet-create-progress`: the ring, the headline, one line of copy
          // and the plain checklist. The prototype's ring spins; a static arc
          // says the same thing and says it the same way under reduceMotion.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              26,
              LoopSpacing.page,
              0,
            ),
            child: Column(
              children: <Widget>[
                WalletCreationRing(
                  key: ValueKey<String>('wallet-create-ring-${phase.name}'),
                  complete: facts.walletObserved,
                ),
                const SizedBox(height: 26),
                Text(
                  key: switch (phase) {
                    LoopWalletCreationPhase.observed => const ValueKey<String>(
                      'wallet-create-observed',
                    ),
                    LoopWalletCreationPhase.working => const ValueKey<String>(
                      'wallet-create-progress',
                    ),
                    LoopWalletCreationPhase.timedOut => const ValueKey<String>(
                      'wallet-create-timeout',
                    ),
                    LoopWalletCreationPhase.unavailable =>
                      const ValueKey<String>('wallet-create-idle'),
                  },
                  headline,
                  textAlign: TextAlign.center,
                  style: LoopType.heading,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ),
                const SizedBox(height: 22),
                _step(
                  id: 'keypair',
                  title: context.l10n.account_screensTitle5,
                  done: facts.walletObserved,
                  pendingDetail: context.l10n.account_screensPendingDetail,
                ),
                _step(
                  id: 'secure-element',
                  title: context.l10n.account_screensTitle6,
                  done: facts.walletObserved,
                  pendingDetail: context.l10n.account_screensPendingDetail,
                ),
                _step(
                  id: 'recovery',
                  title: context.l10n.account_screensWalletCreateContinueLabel,
                  done: facts.recoveryEnrolled,
                  pendingDetail: context.l10n.account_screensPendingDetail2,
                ),
                _step(
                  id: 'loop-id',
                  title: context.l10n.account_screensTitle7,
                  done: facts.loopIdActivated,
                  pendingDetail: context.l10n.account_screensPendingDetail3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One creation step. It reads 已完成 only from an observation this run
  /// actually made; everything else states which step will produce it.
  Widget _step({
    required String id,
    required String title,
    required bool done,
    required String pendingDetail,
  }) {
    return Semantics(
      key: ValueKey<String>('wallet-create-step-$id'),
      container: true,
      label: done
          ? LoopL10n.current.account_screensLabel4(title)
          : LoopL10n.current.account_screensLabel5(pendingDetail, title),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, minHeight: 30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: done
                    ? const LoopIcon(
                        'check',
                        size: 15,
                        color: LoopColors.yellow,
                      )
                    : Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: LoopColors.text3,
                            width: 1.5,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      textAlign: TextAlign.start,
                      style: LoopType.bodySm.copyWith(
                        color: done ? LoopColors.text2 : LoopColors.chalk,
                      ),
                    ),
                    if (!done)
                      Text(
                        pendingDetail,
                        textAlign: TextAlign.start,
                        style: LoopType.captionSm,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                done
                    ? LoopL10n.current.account_screensStep
                    : LoopL10n.current.account_screensS,
                style: LoopTypography.withWeight(
                  LoopType.figureXs,
                  FontWeight.w500,
                ).copyWith(color: done ? LoopColors.yellow : LoopColors.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.wallet-create-ring`: the 120 ring with the app mark inside it.
class WalletCreationRing extends StatelessWidget {
  const WalletCreationRing({required this.complete, super.key});

  /// The wallet was actually seen: the arc closes instead of standing open.
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _WalletCreationRingPainter(complete: complete),
        child: const Center(
          child: LoopBrandMark(
            kind: LoopBrandMarkKind.appIcon,
            height: 54,
            semanticLabel: 'LOOP',
          ),
        ),
      ),
    );
  }
}

class _WalletCreationRingPainter extends CustomPainter {
  const _WalletCreationRingPainter({required this.complete});

  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    const radius = 46.0;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = LoopColors.chalk.withValues(alpha: 0.1),
    );
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      complete ? math.pi * 2 : math.pi / 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = LoopColors.yellow,
    );
  }

  @override
  bool shouldRepaint(_WalletCreationRingPainter oldDelegate) =>
      oldDelegate.complete != complete;
}

// ---------------------------------------------------------------------------
// wallet-recovery · intro / focus
// ---------------------------------------------------------------------------

/// One recovery method the page lists.
///
/// Decision 0151 (owner ruling 2026-10-12): 恢复密码 is no longer one of
/// them; the capability flag [PrivyWalletCapabilities.canUseRecoveryPassword]
/// is still read, nothing on this page shows it.
///
/// [cloud] is not like the other one. It is how a Privy embedded wallet is
/// recovered by default — the provider keeps the wallet reachable through the
/// login method itself — so it is already in force for every account that has
/// one. Passkey is an enrolment LOOP would have to perform, and the SDK
/// in this build exposes no call that performs it.
enum WalletRecoveryMethod {
  passkey('key'),
  cloud('cloud');

  const WalletRecoveryMethod(this.icon);

  String get title => switch (this) {
    WalletRecoveryMethod.passkey => LoopL10n.current.account_screensPasskey,

    WalletRecoveryMethod.cloud => LoopL10n.current.account_screensCloud,
  };
  String get detail => switch (this) {
    WalletRecoveryMethod.passkey => LoopL10n.current.account_screensPasskey2,
    WalletRecoveryMethod.cloud => LoopL10n.current.account_screensCloud2,
  };
  final String icon;
}

/// The one sentence that makes 自动恢复 an enabled method rather than a claim.
///
/// A page may say 已启用 only where it can also say why it is true and who
/// says so. This is that evidence: Privy's own documented behaviour for the
/// embedded wallets LOOP creates, named as Privy's and not as LOOP's.
String get walletAutomaticRecoveryEvidence =>
    LoopL10n.current.account_screensWalletAutomaticRecoveryEvidence;

/// What the product can say today about a method it does not offer.
///
/// The old sentences named the integration («设备或 Privy 尚未确认 Passkey
/// 能力»). An owner cannot do anything with that, and it reads as a fault.
/// This says the same thing in the owner's terms: the service has not opened
/// it in this version.
String get walletRecoveryProviderPending =>
    LoopL10n.current.account_screensWalletRecoveryProviderPending;

/// Why Passkey is not offered, which is a different thing from the rest.
///
/// It is the same sentence the second-factor sheets print, read off the one
/// constant so the two pages can never drift apart: a passkey belongs to a
/// domain, and a build with no domain credential cannot make one.
String get walletRecoveryPasskeyPending => loopPasskeyDomainPending;

class WalletRecoveryScreen extends StatefulWidget {
  const WalletRecoveryScreen({
    required this.capabilities,
    required this.onContinue,
    super.key,
    this.onBack,
    this.onDecision,
    this.loading = false,
    this.failureReason,
    this.onRetry,
    this.mfa,
    this.onOpenPasskey,
  });

  final PrivyWalletCapabilities capabilities;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  /// What the login service says this account already holds, or `null` in a
  /// tree with no provider. `null` is not "no passkey": it is "not asked".
  final LoopMfaState? mfa;

  /// Opens the provider's own binding sheet. This page binds nothing.
  final VoidCallback? onOpenPasskey;

  /// Reports the method the owner chose, or `null` when the step is skipped.
  /// Nothing is enrolled, so the report is a choice and never a credential.
  final ValueChanged<WalletRecoveryMethod?>? onDecision;

  /// The capability document has not been observed yet.
  final bool loading;

  /// The capability document could not be read. Options stay unavailable.
  final String? failureReason;
  final VoidCallback? onRetry;

  @override
  State<WalletRecoveryScreen> createState() => _WalletRecoveryScreenState();
}

/// What one row on step 03 is: already in force, already set up by the
/// owner, offered, or none of those.
///
/// [enabled] and [bound] are different facts and are named differently.
/// 自动恢复 is in force because of how Privy's embedded wallets work; a
/// passkey is set up because the owner created one and the provider says it
/// holds it.
enum _RecoveryRowState { enabled, bound, selectable, unavailable }

class _WalletRecoveryScreenState extends State<WalletRecoveryScreen> {
  WalletRecoveryMethod? _chosen;

  /// Whether the provider said this account already has a passkey.
  ///
  /// Only an answered read counts. An unread or unavailable provider leaves
  /// the row offering the binding, never claiming one.
  bool get _passkeyBound =>
      widget.mfa?.phase == LoopMfaPhase.known &&
      (widget.mfa?.hasPasskey ?? false);

  _RecoveryRowState _stateOf(WalletRecoveryMethod method) => switch (method) {
    // 自动恢复 is the Privy embedded wallet's own default. It is not a switch
    // LOOP owns, so it is never offered as a choice — it is reported, with
    // the sentence that makes it true.
    WalletRecoveryMethod.cloud => _RecoveryRowState.enabled,
    WalletRecoveryMethod.passkey =>
      !widget.capabilities.canUsePasskey
          ? _RecoveryRowState.unavailable
          : _passkeyBound
          ? _RecoveryRowState.bound
          : _RecoveryRowState.selectable,
  };

  String _reason(WalletRecoveryMethod method) => switch (method) {
    WalletRecoveryMethod.cloud => walletAutomaticRecoveryEvidence,
    WalletRecoveryMethod.passkey => walletRecoveryPasskeyPending,
  };

  /// What a bound passkey row says about itself, in the provider's terms.
  String get _passkeyBoundDetail {
    final passkeys = widget.mfa?.passkeys ?? const <LoopPasskeyCredential>[];
    final named = passkeys
        .map((one) => one.label)
        .whereType<String>()
        .where((label) => label.trim().isNotEmpty)
        .toList(growable: false);
    return named.isEmpty
        ? LoopL10n.current.account_screensPasskeyBoundDetail
        : LoopL10n.current.account_screensS2(named.join(' · '));
  }

  /// Any method on this page the owner could still act on.
  ///
  /// A passkey the account already has counts: the page must not tell an
  /// owner who just bound one that nothing more can be added.
  bool get _anySelectable => WalletRecoveryMethod.values.any((method) {
    final state = _stateOf(method);
    return state == _RecoveryRowState.selectable ||
        state == _RecoveryRowState.bound;
  });

  @override
  Widget build(BuildContext context) {
    final blocked = widget.loading || widget.failureReason != null;
    return LoopFlat(
      step: true,
      child: LoopFocusPage(
        archetype: LoopPageArchetype.intro,
        title: context.l10n.account_screensWalletRecoveryConfirmTitle,
        onBack: widget.onBack,
        // The prototype stacks the two full-width buttons under the options and
        // puts the skip risk above them, so the risk is read before the choice
        // is made. Both flow with the body rather than sitting on a pinned bar.
        actionsFollowBody: true,
        primaryActionBeforeDisclosure: false,
        primaryAction: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The step is never a dead end. An account already has a working
            // recovery method the moment its wallet exists, so 确认 continues
            // with whatever is true — the chosen method if one was chosen, the
            // default otherwise. Disabling it left owners on a page they could
            // not leave when nothing was enrollable (device report 2026-09-21
            // · F2).
            LoopButton(
              key: const ValueKey<String>('wallet-recovery-confirm'),
              label: context.l10n.common_confirm,
              primary: true,
              block: true,
              onPressed: blocked ? null : () => _decide(_chosen),
            ),
            const SizedBox(height: 10),
            LoopButton(
              key: const ValueKey<String>('wallet-recovery-later'),
              label: context.l10n.account_screensWalletRecoveryLaterLabel,
              block: true,
              onPressed: () => _decide(null),
            ),
          ],
        ),
        disclosure: LoopDisclosure(
          summary: context.l10n.account_screensSummary2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopLabel(context.l10n.account_screensLoopLabel2, tight: true),
                LoopRecordGroup(
                  rows: <LoopRecordRow>[
                    _capabilityRow(
                      id: 'social-recovery',
                      title: context.l10n.account_screensTitle8,
                      detail: context.l10n.account_screensDetail,
                      available: widget.capabilities.canUseSocialRecovery,
                      reason: walletRecoveryProviderPending,
                      position: LoopRowPosition.first,
                    ),
                    _capabilityRow(
                      id: 'key-export',
                      title: context.l10n.account_screensTitle9,
                      detail: context.l10n.account_screensDetail2,
                      available: widget.capabilities.canExportPrivateKey,
                      reason: walletRecoveryProviderPending,
                      position: LoopRowPosition.last,
                    ),
                  ],
                ),
                // The honest residual risk. It is no longer "you may lose
                // everything": the account has a recovery method. What it
                // depends on is the login method, and that is the thing to
                // keep.
                LoopNotice(
                  icon: 'warn',
                  tone: LoopNoticeTone.warn,
                  title: context.l10n.account_screensTitle10,
                  body: context.l10n.account_screensBody5,
                  margin: EdgeInsets.only(top: 12),
                ),
              ],
            ),
          ),
        ),
        body: <Widget>[
          IdentityProgress(
            step: 3,
            total: 5,
            label: context.l10n.account_screensWalletCreateContinueLabel,
          ),
          IdentityStepCopy(context.l10n.account_screensIdentityStepCopy3),
          LoopNotice(
            key: ValueKey<String>('wallet-recovery-default'),
            icon: 'check',
            title: context.l10n.account_screensWalletRecoveryDefaultTitle,
            body: context.l10n.account_screensWalletRecoveryDefaultBody(
              walletAutomaticRecoveryEvidence,
            ),
          ),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LoopSkeleton(
                key: ValueKey<String>('wallet-recovery-loading'),
                type: LoopSkeletonType.list,
                rows: 3,
              ),
            )
          else if (widget.failureReason != null)
            LoopErrorState(
              key: const ValueKey<String>('wallet-recovery-error'),
              reason: widget.failureReason!,
              source: context.l10n.account_screensWalletRecoveryErrorSource,
              onRetry: widget.onRetry,
            )
          else ...<Widget>[
            if (!_anySelectable)
              LoopNotice(
                key: ValueKey<String>('wallet-recovery-unavailable'),
                icon: 'info',
                title:
                    context.l10n.account_screensWalletRecoveryUnavailableTitle,
                body: context.l10n.account_screensWalletRecoveryUnavailableBody(
                  walletRecoveryProviderPending,
                ),
              ),
            LoopLabel(context.l10n.account_screensWalletRecoveryConfirmTitle),
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final method in WalletRecoveryMethod.values)
                  _methodRow(method),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _decide(WalletRecoveryMethod? method) {
    widget.onDecision?.call(method);
    widget.onContinue();
  }

  LoopRecordRow _methodRow(WalletRecoveryMethod method) {
    final state = _stateOf(method);
    final enabled = state == _RecoveryRowState.enabled;
    final bound = state == _RecoveryRowState.bound;
    final selectable = state == _RecoveryRowState.selectable;
    final chosen = _chosen == method;
    final index = WalletRecoveryMethod.values.indexOf(method);
    final reason = _reason(method);
    // The passkey row is the one row whose tap reaches the provider: it
    // opens the sheet that creates or removes the credential. Choosing it
    // still only records a choice — the binding is the sheet's, and the row
    // says 已设置 only after the provider answered that it holds one.
    final detail = bound ? _passkeyBoundDetail : method.detail;
    return LoopRecordRow(
      key: ValueKey<String>('recovery-${method.name}'),
      leading: IdentityOptionIcon(
        method.icon,
        chosen: chosen || enabled || bound,
      ),
      title: method.title,
      // An enabled row carries its evidence; an unavailable row carries the
      // reason. Neither is ever a bare state word.
      subtitle: selectable || bound ? detail : '$detail · $reason',
      // `.row-choice .row-s{white-space:normal}`: the sentence that decides
      // whether an owner can get back in may not end in an ellipsis.
      subtitleMaxLines: 3,
      selected: chosen,
      trailing: enabled
          ? LoopL10n.current.account_screensTrailing2
          : bound
          ? LoopL10n.current.account_screensTrailing3
          : chosen
          ? LoopL10n.current.account_screensTrailing4
          : selectable
          ? LoopL10n.current.account_screensTrailing
          : LoopL10n.current.common_unavailable,
      onTap: selectable
          ? () => _choose(method)
          : bound
          ? widget.onOpenPasskey
          : null,
      position: index == 0
          ? LoopRowPosition.first
          : index == WalletRecoveryMethod.values.length - 1
          ? LoopRowPosition.last
          : LoopRowPosition.middle,
      semanticLabel: enabled
          ? LoopL10n.current.account_screensSemanticLabel3(reason, method.title)
          : bound
          ? LoopL10n.current.account_screensSemanticLabel4(detail, method.title)
          : selectable
          ? (chosen
                ? LoopL10n.current.account_screensMethodSelectedSemanticLabel(
                    method.title,
                  )
                : LoopL10n.current.account_screensMethodSelectableSemanticLabel(
                    method.title,
                  ))
          : LoopL10n.current.account_screensSemanticLabel2(
              method.title,
              reason,
            ),
    );
  }

  /// Records the choice, and for Passkey opens the sheet that can act on it.
  ///
  /// Choosing is not enrolling: the decision is reported on 确认 as it always
  /// was. What the sheet adds is a way to actually create the credential
  /// while the owner is on the step that asked for it.
  void _choose(WalletRecoveryMethod method) {
    setState(() => _chosen = method);
    if (method == WalletRecoveryMethod.passkey) {
      widget.onOpenPasskey?.call();
    }
  }

  LoopRecordRow _capabilityRow({
    required String id,
    required String title,
    required String detail,
    required bool available,
    required String reason,
    required LoopRowPosition position,
  }) {
    return LoopRecordRow(
      key: ValueKey<String>('recovery-$id'),
      title: title,
      subtitle: available ? detail : '$detail · $reason',
      subtitleMaxLines: 2,
      trailing: available
          ? LoopL10n.current.account_screensTrailing
          : LoopL10n.current.common_unavailable,
      position: position,
      semanticLabel: available
          ? LoopL10n.current.account_screensSemanticLabel6(title)
          : LoopL10n.current.account_screensSemanticLabel2(title, reason),
    );
  }
}

// ---------------------------------------------------------------------------
// security-setup · intro / focus
// ---------------------------------------------------------------------------

/// The one 11px line under `security-setup`'s rows (decision 0121).
String get securityBiometricFallbackLine =>
    LoopL10n.current.account_screensSecurityBiometricFallbackLine;

class SecuritySetupScreen extends StatelessWidget {
  const SecuritySetupScreen({
    required this.capabilities,
    required this.onContinue,
    super.key,
    this.onBack,
    this.appLock,
    this.onToggleAppLock,
    this.mfa,
    this.onOpenMfa,
  });

  final PrivyWalletCapabilities capabilities;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  /// The device-local lock, as the composition reads it, or `null` in a tree
  /// that composed none. `null` is not "off": it is a page with no lock to
  /// report, and it says so rather than offering a control that does nothing.
  final LoopAppLockState? appLock;

  /// Turns the lock on or off. The system's own prompt runs first, in the
  /// controller; this page never decides that anybody was authenticated.
  final VoidCallback? onToggleAppLock;

  /// The account's second factor as the login service last reported it, or
  /// `null` in a tree with no provider. `null` is not "off".
  final LoopMfaState? mfa;

  /// Opens the provider's enrolment sheet. The page performs no enrolment.
  final VoidCallback? onOpenMfa;

  @override
  Widget build(BuildContext context) {
    return LoopFlat(
      step: true,
      child: LoopFocusPage(
        archetype: LoopPageArchetype.intro,
        title: context.l10n.account_screensSecuritySetupContinueTitle,
        onBack: onBack,
        actionsFollowBody: true,
        primaryAction: LoopButton(
          key: const ValueKey<String>('security-setup-continue'),
          label: context.l10n.common_next,
          primary: true,
          block: true,
          onPressed: onContinue,
        ),
        body: <Widget>[
          IdentityProgress(
            step: 4,
            total: 5,
            label: context.l10n.account_screensSecuritySetupContinueTitle,
          ),
          IdentityStepCopy(context.l10n.account_screensIdentityStepCopy4),
          // Decision 0121 (device report 2026-10-09 · 4): the warning banner
          // that opened this page spoke to engineers. Each row below states its
          // own state; the page saves no PIN and claims no protection is on.
          LoopLabel(context.l10n.account_screensLoopLabel3),
          // Decision 0172: both groups are the shared `.record-card` rows.
          LoopRecordGroup(rows: <LoopRecordRow>[_appLockRow()]),
          LoopLabel(context.l10n.account_screensLoopLabel4),
          // Prototype order: the amount rule first, the second factor after it.
          // The step-up row reads its own state, so it is not a plain
          // [LoopRecordRow] a [LoopRecordGroup] could re-position; the two
          // rows carry `first` / `last` themselves, as the group would. S288:
          // they still stand on the group's block, like 应用锁 above.
          LoopRecordGroup.children(
            key: const ValueKey<String>('security-verification-group'),
            children: <Widget>[
              // Decision 0152: a real switch now. A signature worth at least
              // the threshold in USD1 asks the device first; the row reads
              // and writes its own per-account choice.
              const LoopStepUpSettingRow(position: LoopRowPosition.first),
              _mfaRow(),
            ],
          ),
          Padding(
            key: const ValueKey<String>('security-biometric-fallback'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              securityBiometricFallbackLine,
              style: LoopType.captionSm,
            ),
          ),
        ],
      ),
    );
  }

  /// The one protection on this page LOOP can actually turn on.
  ///
  /// It is the device's lock: the system asks for a face, a fingerprint or
  /// the passcode behind them, and answers yes or no. LOOP stores one boolean
  /// and nothing that could be compared against a PIN, because it never sees
  /// one. Both directions go through the same prompt — a lock anybody could
  /// switch off would not be a lock.
  LoopRecordRow _appLockRow() {
    final lock = appLock;
    final available = lock?.isAvailable ?? false;
    final enabled = lock?.enabled ?? false;
    final busy = lock?.busy ?? false;
    final detail = lock?.capability == null
        ? LoopL10n.current.account_screensAppLockRow
        : loopAppLockFactorText(lock!.capability!);
    final subtitle = enabled && lock != null && !lock.persisted
        ? LoopL10n.current.account_screensAppLockRow2(detail)
        : detail;
    return LoopRecordRow(
      key: const ValueKey<String>('security-app-lock'),
      leading: const IdentityOptionIcon('lock'),
      title: LoopL10n.current.account_screensLoopLabel3,
      subtitle: subtitle,
      subtitleMaxLines: 2,
      selected: enabled,
      trailing: busy
          ? LoopL10n.current.common_verifying
          : !available
          ? LoopL10n.current.common_unavailable
          : enabled
          ? LoopL10n.current.common_on
          : LoopL10n.current.account_screensSecurityAppLockTrailing,
      onTap: available && !busy ? onToggleAppLock : null,
      semanticLabel: !available
          ? LoopL10n.current.account_screensSecurityAppLockSemanticLabel(detail)
          : enabled
          ? LoopL10n.current.account_screensSecurityAppLockSemanticLabel2
          : LoopL10n.current.account_screensSecurityAppLockSemanticLabel3,
    );
  }

  /// The account's second factor at the login service.
  ///
  /// Every word in this row came back from the provider: 已开启 means Privy
  /// answered that the account holds a method and named it. An unread or
  /// unavailable provider is 不可用, never 未开启 — "we could not ask" and
  /// "you have none" are different facts.
  LoopRecordRow _mfaRow() {
    final mfa = this.mfa;
    final enrolled = mfa?.enrollments ?? const <LoopMfaEnrollment>[];
    final known = mfa?.phase == LoopMfaPhase.known;
    final reading = mfa?.phase == LoopMfaPhase.reading;
    final trailing = reading
        ? LoopL10n.current.account_screensMfaRow
        : !known
        ? LoopL10n.current.common_unavailable
        : enrolled.isEmpty
        ? LoopL10n.current.account_screensSecurityAppLockTrailing
        : LoopL10n.current.common_on;
    final detail = enrolled.isEmpty
        ? 'SMS / TOTP / Passkey'
        : enrolled.map((one) => one.kind.label).join(' · ');
    final reason = mfa == null
        ? LoopL10n.current.account_screensMfaRow2
        : mfa.failure == null
        ? LoopL10n.current.account_screensMfaRow3
        : loopMfaFailureText(mfa.failure!);
    return LoopRecordRow(
      key: const ValueKey<String>('security-mfa'),
      title: 'MFA',
      subtitle: known ? detail : '$detail · $reason',
      subtitleMaxLines: 2,
      selected: enrolled.isNotEmpty,
      trailing: trailing,
      onTap: known && !(mfa?.isBusy ?? false) ? onOpenMfa : null,
      position: LoopRowPosition.last,
      semanticLabel: known
          ? enrolled.isEmpty
                ? LoopL10n.current.account_screensSecurityMfaSemanticLabel
                : LoopL10n.current.account_screensSecurityMfaSemanticLabel2(
                    detail,
                  )
          : LoopL10n.current.account_screensSecurityMfaSemanticLabel3(reason),
    );
  }
}

class UnknownAccountScreen extends StatelessWidget {
  const UnknownAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoopFocusPage(
      archetype: LoopPageArchetype.state,
      title: context.l10n.account_screensUnknownAccountSurfaceTitle,
      body: <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('unknown-account-surface'),
          illustration: LoopIllustration.profile,
          title: context.l10n.account_screensUnknownAccountSurfaceTitle2,
          message: context.l10n.account_screensUnknownAccountSurfaceMessage,
          compact: true,
        ),
      ],
    );
  }
}
