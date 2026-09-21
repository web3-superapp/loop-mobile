import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/wallet_creation_facts.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_gate.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
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
    this.appLock,
    this.onToggleAppLock,
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

  /// The device-local lock, for `security-setup`. Absent in a tree that
  /// composed none.
  final LoopAppLockState? appLock;
  final VoidCallback? onToggleAppLock;

  String get _id => surfaceId.replaceFirst('#', '').toLowerCase();

  void _navigate(BuildContext context, String destination) {
    onNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_id) {
      'splash' => SplashScreen(
        phase: splashPhase,
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
        onBack: onBack,
        onDecision: onRecoveryDecision,
        onContinue: () => _navigate(context, 'security-setup'),
      ),
      'security-setup' => SecuritySetupScreen(
        capabilities: capabilities,
        appLock: appLock,
        onToggleAppLock: onToggleAppLock,
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
    final fraction = (step / total).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: '流程第 $step 步，共 $total 步：$label',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          2,
          LoopSpacing.page,
          14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: step.toString().padLeft(2, '0'),
                          style: LoopTypography.figure(
                            13,
                            color: LoopColors.lime,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${total.toString().padLeft(2, '0')}',
                          style: LoopTypography.figure(
                            12,
                            weight: FontWeight.w500,
                            height: 1.5,
                            color: LoopColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    label,
                    style: LoopTypography.figure(
                      11,
                      weight: FontWeight.w500,
                      color: LoopColors.text2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                key: const ValueKey<String>('identity-progress-track'),
                value: fraction,
                minHeight: 4,
                backgroundColor: LoopColors.line2,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  LoopColors.lime,
                ),
              ),
            ),
          ],
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
          style: LoopTypography.body(14, color: LoopColors.text2),
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
class IdentityOptionIcon extends StatelessWidget {
  const IdentityOptionIcon(this.icon, {this.chosen = false, super.key});

  final String icon;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.card2,
        borderRadius: BorderRadius.circular(15),
      ),
      child: LoopIcon(
        icon,
        size: 21,
        color: chosen ? LoopColors.lime : LoopColors.text2,
      ),
    );
  }
}

/// One recovery / security option whose availability comes from a capability.
/// It is never a switch: nothing here can enrol, configure or store anything.
class CapabilityChoiceRow extends StatelessWidget {
  const CapabilityChoiceRow({
    required this.title,
    required this.detail,
    required this.available,
    required this.unavailableReason,
    super.key,
    this.position = LoopRowPosition.single,
  });

  final String title;
  final String detail;
  final bool available;
  final String unavailableReason;
  final LoopRowPosition position;

  @override
  Widget build(BuildContext context) {
    return LoopRecordRow(
      key: ValueKey<String>('capability-$title'),
      title: title,
      subtitle: available ? detail : '$detail · $unavailableReason',
      trailing: available ? '可用' : '不可用',
      position: position,
      semanticLabel: available
          ? '$title，可用但未开启'
          : '$title，不可用：$unavailableReason',
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
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    required this.onContinue,
    super.key,
    this.phase = LoopSplashPhase.entry,
  });

  final VoidCallback onContinue;
  final LoopSplashPhase phase;

  @override
  Widget build(BuildContext context) {
    final preparing = phase == LoopSplashPhase.preparingAccount;
    return Scaffold(
      key: const ValueKey<String>('loop-splash-screen'),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Spacer(),
            const LoopBrandMark(
              key: ValueKey<String>('loop-splash-wordmark'),
              kind: LoopBrandMarkKind.wordmark,
              height: 96,
              semanticLabel: 'LOOP',
            ),
            const SizedBox(height: 20),
            const LoopBrandLoader(key: ValueKey<String>('loop-splash-loader')),
            if (preparing) ...<Widget>[
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: Text(
                  '正在准备你的账号…',
                  key: const ValueKey<String>('loop-splash-preparing'),
                  textAlign: TextAlign.center,
                  style: LoopTypography.caption(12, color: LoopColors.text3),
                ),
              ),
            ],
            const Spacer(),
            // Waiting is not a choice, so it is offered none. The entry frame
            // keeps the prototype's single full-width action.
            if (!preparing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LoopButton(
                  key: const ValueKey<String>('loop-splash-enter'),
                  label: '进入 LOOP',
                  primary: true,
                  block: true,
                  onPressed: onContinue,
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// `.loop-brand-loader`: the rail, the Lime line and the dot at its end.
///
/// The prototype's line animates once and stops; under `reduceMotion` it is
/// drawn already complete. This is the static reading of the same mark: a
/// 244-wide rail with the Lime line over it and the dot at the right end, so
/// the launch frame is the prototype's and not a Material progress bar
/// (audit 2026-09-20 §C.1).
class LoopBrandLoader extends StatelessWidget {
  const LoopBrandLoader({super.key, this.width = 244});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LOOP 正在加载',
      liveRegion: true,
      child: SizedBox(
        width: width,
        height: 12,
        child: Center(
          child: Stack(
            alignment: Alignment.centerRight,
            children: <Widget>[
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: LoopColors.lime,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: LoopColors.lime,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '连接钱包',
      onBack: onBack,
      actionsFollowBody: true,
      primaryAction: LoopButton(
        key: const ValueKey<String>('external-wallet-connect'),
        label: '选择钱包并签名',
        primary: true,
        block: true,
        onPressed: capabilityAvailable ? onConnect : null,
      ),
      disclosure: const LoopDisclosure(
        summary: '扫码连接与失败说明',
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopNotice(
                icon: 'info',
                title: '外部钱包只是登录凭证',
                body: '它不是 LOOP 交易钱包，也不能授权任何交易。',
                margin: EdgeInsets.only(bottom: 10),
              ),
              LoopNotice(
                icon: 'mine',
                title: '连接已有钱包就能挖矿',
                body: '你钱包里的社区币不用搬家 —— 绑定后持仓自动计入算力。这也是外部钱包入口保留的原因。',
                margin: EdgeInsets.only(bottom: 10),
              ),
              LoopNotice(
                icon: 'close',
                tone: LoopNoticeTone.danger,
                title: '签名被拒绝',
                body: '连接钱包需要一次签名以验证所有权，不会转移任何资产。取消签名不会改变任何状态。',
                margin: EdgeInsets.only(bottom: 10),
              ),
              LoopNotice(
                icon: 'clock',
                tone: LoopNoticeTone.warn,
                title: '连接超时',
                body: '会话已过期，请回到这一页重新发起连接。',
                margin: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      body: <Widget>[
        const IdentityProgress(step: 1, total: 2, label: '选择钱包'),
        const IdentityStepCopy('连接只验证所有权，不会转移资产。'),
        if (!capabilityAvailable)
          const LoopNotice(
            key: ValueKey<String>('external-wallet-unavailable'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '外部钱包连接暂不可用',
            body: '缺少有效的 Reown Project ID 或 Privy Client ID。没有可用的连接通道，这里不会列出任何已安装的钱包。',
          ),
        const LoopLabel('可连接的钱包'),
        const LoopEmpty(
          key: ValueKey<String>('external-wallet-list-unavailable'),
          message: '已安装钱包清单暂不可读',
          reason: '连接钱包后才会显示可用的钱包名称。',
        ),
      ],
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
        '钱包已创建',
        '这个账号下已经能看到内置钱包。LOOP 不使用助记词。',
      ),
      LoopWalletCreationPhase.working => (
        '正在创建你的钱包',
        '密钥在本地生成，不会离开这台设备。LOOP 不使用助记词。',
      ),
      LoopWalletCreationPhase.timedOut => (
        '钱包还在创建中，可以先继续',
        '等了 60 秒仍然没有看到钱包，这不代表失败。LOOP 不使用助记词。',
      ),
      LoopWalletCreationPhase.unavailable => (
        '还没有开始创建',
        'Privy 尚未确认内置钱包能力，这一页不会伪造进度。LOOP 不使用助记词。',
      ),
    };
    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '创建 LOOP 钱包',
      onBack: onBack,
      // `.wallet-create-action{margin-top:auto}`: this is the one step page
      // whose button the prototype does push to the bottom, because the ring
      // above it owns the rest of the screen.
      primaryAction: LoopButton(
        key: const ValueKey<String>('wallet-create-continue'),
        label: '设置恢复方式',
        primary: true,
        block: true,
        onPressed: facts.canContinue ? onContinue : null,
      ),
      body: <Widget>[
        const IdentityProgress(step: 2, total: 5, label: '创建钱包'),
        const IdentityStepCopy('安全钱包正在本地初始化。'),
        if (phase == LoopWalletCreationPhase.unavailable)
          const LoopNotice(
            key: ValueKey<String>('wallet-create-unavailable'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '钱包创建暂不可用',
            body: 'Privy 尚未确认内置钱包能力。这一页不会伪造进度，也没有创建任何钱包。',
          ),
        if (facts.providerMessage case final String message)
          LoopNotice(
            key: const ValueKey<String>('wallet-create-provider-message'),
            icon: 'warn',
            tone: LoopNoticeTone.danger,
            title: '这次创建没有完成',
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
                  LoopWalletCreationPhase.unavailable => const ValueKey<String>(
                    'wallet-create-idle',
                  ),
                },
                headline,
                textAlign: TextAlign.center,
                style: LoopTypography.display(21),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: LoopTypography.body(12.5, color: LoopColors.text2),
                ),
              ),
              const SizedBox(height: 22),
              _step(
                id: 'keypair',
                title: '生成密钥对',
                done: facts.walletObserved,
                pendingDetail: '钱包出现后才算完成',
              ),
              _step(
                id: 'secure-element',
                title: '写入安全区',
                done: facts.walletObserved,
                pendingDetail: '钱包出现后才算完成',
              ),
              _step(
                id: 'recovery',
                title: '设置恢复方式',
                done: facts.recoveryEnrolled,
                pendingDetail: '第 3 步选择后才算完成',
              ),
              _step(
                id: 'loop-id',
                title: '绑定 LOOP ID',
                done: facts.loopIdActivated,
                pendingDetail: '第 5 步完成后才算完成',
              ),
            ],
          ),
        ),
      ],
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
      label: done ? '$title，已完成' : '$title，未完成：$pendingDetail',
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
                    ? const LoopIcon('check', size: 15, color: LoopColors.lime)
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
                      style: LoopTypography.body(
                        13,
                        color: done ? LoopColors.text2 : LoopColors.chalk,
                      ),
                    ),
                    if (!done)
                      Text(
                        pendingDetail,
                        textAlign: TextAlign.start,
                        style: LoopTypography.caption(
                          11,
                          color: LoopColors.text3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                done ? '已完成' : '未完成',
                style: LoopTypography.figure(
                  11,
                  weight: FontWeight.w500,
                  color: done ? LoopColors.lime : LoopColors.text3,
                ),
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
        ..color = LoopColors.lime,
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
/// [cloud] is not like the other two. It is how a Privy embedded wallet is
/// recovered by default — the provider keeps the wallet reachable through the
/// login method itself — so it is already in force for every account that has
/// one. The other two are enrolments LOOP would have to perform, and the SDK
/// in this build exposes no call that performs them.
enum WalletRecoveryMethod {
  passkey('Passkey（推荐）', '用设备生物识别，跟随系统钥匙串同步', 'key'),
  password('恢复密码', '自己设一个密码，忘了就找不回', 'lock'),
  cloud('自动恢复', '凭登录方式恢复，换设备后用同一邮箱登录即可', 'cloud');

  const WalletRecoveryMethod(this.title, this.detail, this.icon);

  final String title;
  final String detail;
  final String icon;
}

/// The one sentence that makes 自动恢复 an enabled method rather than a claim.
///
/// A page may say 已启用 only where it can also say why it is true and who
/// says so. This is that evidence: Privy's own documented behaviour for the
/// embedded wallets LOOP creates, named as Privy's and not as LOOP's.
const walletAutomaticRecoveryEvidence =
    'Privy 内置钱包默认由登录方式恢复；换设备后用同一邮箱登录即可（来源：Privy）';

/// What the product can say today about a method it does not offer.
///
/// The old sentences named the integration («设备或 Privy 尚未确认 Passkey
/// 能力»). An owner cannot do anything with that, and it reads as a fault.
/// This says the same thing in the owner's terms: the service has not opened
/// it in this version.
const walletRecoveryProviderPending = '当前版本的登录服务还没有开放这一项';

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
  });

  final PrivyWalletCapabilities capabilities;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

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

/// What one row on step 03 is: already in force, offered, or neither.
enum _RecoveryRowState { enabled, selectable, unavailable }

class _WalletRecoveryScreenState extends State<WalletRecoveryScreen> {
  WalletRecoveryMethod? _chosen;

  _RecoveryRowState _stateOf(WalletRecoveryMethod method) => switch (method) {
    // 自动恢复 is the Privy embedded wallet's own default. It is not a switch
    // LOOP owns, so it is never offered as a choice — it is reported, with
    // the sentence that makes it true.
    WalletRecoveryMethod.cloud => _RecoveryRowState.enabled,
    WalletRecoveryMethod.passkey =>
      widget.capabilities.canUsePasskey
          ? _RecoveryRowState.selectable
          : _RecoveryRowState.unavailable,
    WalletRecoveryMethod.password =>
      widget.capabilities.canUseRecoveryPassword
          ? _RecoveryRowState.selectable
          : _RecoveryRowState.unavailable,
  };

  String _reason(WalletRecoveryMethod method) => switch (method) {
    WalletRecoveryMethod.cloud => walletAutomaticRecoveryEvidence,
    WalletRecoveryMethod.passkey ||
    WalletRecoveryMethod.password => walletRecoveryProviderPending,
  };

  bool get _anySelectable => WalletRecoveryMethod.values.any(
    (method) => _stateOf(method) == _RecoveryRowState.selectable,
  );

  @override
  Widget build(BuildContext context) {
    final blocked = widget.loading || widget.failureReason != null;
    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '恢复方式',
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
            label: '确认',
            primary: true,
            block: true,
            onPressed: blocked ? null : () => _decide(_chosen),
          ),
          const SizedBox(height: 10),
          LoopButton(
            key: const ValueKey<String>('wallet-recovery-later'),
            label: '稍后设置',
            block: true,
            onPressed: () => _decide(null),
          ),
        ],
      ),
      disclosure: LoopDisclosure(
        summary: '其他恢复方式与跳过风险',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const LoopLabel('另外', tight: true),
              LoopRecordGroup(
                rows: <LoopRecordRow>[
                  _capabilityRow(
                    title: '社交恢复 2-of-3',
                    detail: '指定 3 个守护人，2 个同意即可恢复',
                    available: widget.capabilities.canUseSocialRecovery,
                    reason: walletRecoveryProviderPending,
                    position: LoopRowPosition.first,
                  ),
                  _capabilityRow(
                    title: '导出私钥',
                    detail: '随时可导出，这是你的逃生舱',
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
              const LoopNotice(
                icon: 'warn',
                tone: LoopNoticeTone.warn,
                title: '自动恢复依赖你的登录方式',
                body: '邮箱或登录方式丢了，钱包也会一起丢。再加一种方式会更稳妥，等这些方式开放后可以随时补上。',
                margin: EdgeInsets.only(top: 12),
              ),
            ],
          ),
        ),
      ),
      body: <Widget>[
        const IdentityProgress(step: 3, total: 5, label: '设置恢复方式'),
        const IdentityStepCopy('你的钱包已经有一种恢复方式，其余的等开放后再补。'),
        const LoopNotice(
          key: ValueKey<String>('wallet-recovery-default'),
          icon: 'check',
          title: '换手机后你已经能拿回资产',
          body: '$walletAutomaticRecoveryEvidence。LOOP 没有助记词，这条路就是默认的那条。',
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
            source: '能力清单',
            onRetry: widget.onRetry,
          )
        else ...<Widget>[
          if (!_anySelectable)
            const LoopNotice(
              key: ValueKey<String>('wallet-recovery-unavailable'),
              icon: 'info',
              title: '现在还不能再加一种',
              body: '$walletRecoveryProviderPending。下面的选项不会在本地模拟，也不会预先勾选。',
            ),
          const LoopLabel('恢复方式'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final method in WalletRecoveryMethod.values)
                _methodRow(method),
            ],
          ),
        ],
      ],
    );
  }

  void _decide(WalletRecoveryMethod? method) {
    widget.onDecision?.call(method);
    widget.onContinue();
  }

  LoopRecordRow _methodRow(WalletRecoveryMethod method) {
    final state = _stateOf(method);
    final enabled = state == _RecoveryRowState.enabled;
    final selectable = state == _RecoveryRowState.selectable;
    final chosen = _chosen == method;
    final index = WalletRecoveryMethod.values.indexOf(method);
    final reason = _reason(method);
    return LoopRecordRow(
      key: ValueKey<String>('recovery-${method.name}'),
      leading: IdentityOptionIcon(method.icon, chosen: chosen || enabled),
      title: method.title,
      // An enabled row carries its evidence; an unavailable row carries the
      // reason. Neither is ever a bare state word.
      subtitle: selectable ? method.detail : '${method.detail} · $reason',
      // `.row-choice .row-s{white-space:normal}`: the sentence that decides
      // whether an owner can get back in may not end in an ellipsis.
      subtitleMaxLines: 3,
      selected: chosen,
      trailing: enabled
          ? '已启用'
          : chosen
          ? '已选'
          : selectable
          ? '可用'
          : '不可用',
      onTap: selectable ? () => setState(() => _chosen = method) : null,
      position: index == 0
          ? LoopRowPosition.first
          : index == WalletRecoveryMethod.values.length - 1
          ? LoopRowPosition.last
          : LoopRowPosition.middle,
      semanticLabel: enabled
          ? '${method.title}，已启用：$reason'
          : selectable
          ? '${method.title}，${chosen ? '已选' : '可选'}'
          : '${method.title}，不可用：$reason',
    );
  }

  LoopRecordRow _capabilityRow({
    required String title,
    required String detail,
    required bool available,
    required String reason,
    required LoopRowPosition position,
  }) {
    return LoopRecordRow(
      key: ValueKey<String>('recovery-$title'),
      title: title,
      subtitle: available ? detail : '$detail · $reason',
      subtitleMaxLines: 2,
      trailing: available ? '可用' : '不可用',
      position: position,
      semanticLabel: available ? '$title，能力可用' : '$title，不可用：$reason',
    );
  }
}

// ---------------------------------------------------------------------------
// security-setup · intro / focus
// ---------------------------------------------------------------------------

class SecuritySetupScreen extends StatelessWidget {
  const SecuritySetupScreen({
    required this.capabilities,
    required this.onContinue,
    super.key,
    this.onBack,
    this.appLock,
    this.onToggleAppLock,
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

  @override
  Widget build(BuildContext context) {
    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '安全设置',
      onBack: onBack,
      actionsFollowBody: true,
      primaryAction: LoopButton(
        key: const ValueKey<String>('security-setup-continue'),
        label: '下一步',
        primary: true,
        block: true,
        onPressed: onContinue,
      ),
      body: <Widget>[
        const IdentityProgress(step: 4, total: 5, label: '安全设置'),
        const IdentityStepCopy('应用锁由这台设备把关，交易验证由登录服务决定。'),
        const LoopNotice(
          key: ValueKey<String>('protection-setup-unavailable'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '交易验证还开不了',
          body: '下面写的是每一项开不了的原因。LOOP 不会保存 PIN，也不会把「能开」说成「已经开了」。',
        ),
        const LoopLabel('应用锁'),
        LoopRecordGroup(rows: <LoopRecordRow>[_appLockRow()]),
        const LoopLabel('交易验证'),
        // Prototype order: the amount rule first, the second factor after it.
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            _row(
              title: '大额交易二次验证',
              detail: '超过阈值时重新验证身份',
              available: capabilities.canUseTransactionMfa,
              reason: '多大金额要再验一次还没有定下来',
              position: LoopRowPosition.first,
            ),
            _row(
              title: 'MFA',
              detail: 'SMS / TOTP / Passkey',
              available: capabilities.canUseTransactionMfa,
              reason: walletRecoveryProviderPending,
              position: LoopRowPosition.last,
            ),
          ],
        ),
        const LoopNotice(
          icon: 'info',
          title: '设备不支持生物识别时',
          body: '会退回到系统层面的锁屏验证，不会因此阻断使用；App 不会自行存储 PIN。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
      ],
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
        ? '还没有读到这台设备的锁屏能力'
        : loopAppLockFactorText(lock!.capability!);
    final subtitle = enabled && lock != null && !lock.persisted
        ? '$detail · 这次有效，重开 App 后不会记得'
        : detail;
    return LoopRecordRow(
      key: const ValueKey<String>('security-app-lock'),
      leading: const IdentityOptionIcon('lock'),
      title: '应用锁',
      subtitle: subtitle,
      subtitleMaxLines: 2,
      selected: enabled,
      trailing: busy
          ? '验证中…'
          : !available
          ? '不可用'
          : enabled
          ? '已开启'
          : '未开启',
      onTap: available && !busy ? onToggleAppLock : null,
      semanticLabel: !available
          ? '应用锁，不可用：$detail'
          : enabled
          ? '应用锁，已开启，点按后验证身份可关闭'
          : '应用锁，未开启，点按后验证身份可开启',
    );
  }

  LoopRecordRow _row({
    required String title,
    required String detail,
    required bool available,
    required String reason,
    required LoopRowPosition position,
    String? icon,
  }) {
    return LoopRecordRow(
      key: ValueKey<String>('security-$title'),
      leading: icon == null ? null : IdentityOptionIcon(icon),
      title: title,
      subtitle: available ? detail : '$detail · $reason',
      // The reason a protection is off is the whole point of the row; one
      // line ellipsed it away (audit 2026-09-20 §C.7).
      subtitleMaxLines: 2,
      trailing: available ? '可用' : '不可用',
      position: position,
      semanticLabel: available ? '$title，可用但未开启' : '$title，不可用：$reason',
    );
  }
}

class UnknownAccountScreen extends StatelessWidget {
  const UnknownAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoopFocusPage(
      archetype: LoopPageArchetype.state,
      title: '页面不存在',
      body: <Widget>[
        LoopEmpty(
          key: ValueKey<String>('unknown-account-surface'),
          message: '这个账户页面不在 93 页产品清单里',
          reason: '请返回社区。请求已被记录。',
        ),
      ],
    );
  }
}
