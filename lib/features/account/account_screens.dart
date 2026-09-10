import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
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
    this.onNavigate,
    this.onBack,
    this.onPrimaryAction,
    this.versionLabel = 'Version 0.1.0',
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
  final AccountNavigation? onNavigate;
  final VoidCallback? onBack;
  final VoidCallback? onPrimaryAction;
  final String versionLabel;

  String get _id => surfaceId.replaceFirst('#', '').toLowerCase();

  void _navigate(BuildContext context, String destination) {
    onNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_id) {
      'splash' => SplashScreen(
        versionLabel: versionLabel,
        onContinue: () => _navigate(context, 'auth'),
      ),
      'auth-wallet' => ExternalWalletScreen(
        capabilityAvailable: capabilities.canConnectExternalWallet,
        onBack: onBack,
        onConnect: onPrimaryAction,
      ),
      'wallet-create' => WalletCreateScreen(
        capabilityAvailable: capabilities.canCreateEmbeddedWallet,
        onBack: onBack,
        onContinue: () => _navigate(context, 'wallet-recovery'),
      ),
      'wallet-recovery' => WalletRecoveryScreen(
        capabilities: capabilities,
        onBack: onBack,
        onContinue: () => _navigate(context, 'security-setup'),
      ),
      'security-setup' => SecuritySetupScreen(
        capabilities: capabilities,
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
          textAlign: TextAlign.center,
          style: LoopTypography.body(14, color: LoopColors.text2),
        ),
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

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    required this.versionLabel,
    required this.onContinue,
    super.key,
  });

  final String versionLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('loop-splash-screen'),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Spacer(),
            const LoopBrandMark(
              key: ValueKey<String>('loop-splash-wordmark'),
              kind: LoopBrandMarkKind.wordmark,
              height: 64,
              semanticLabel: 'LOOP',
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                key: ValueKey<String>('loop-splash-loader'),
                minHeight: 3,
                backgroundColor: LoopColors.line2,
                valueColor: AlwaysStoppedAnimation<Color>(LoopColors.lime),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
              child: LoopButton(
                key: const ValueKey<String>('loop-splash-enter'),
                label: '进入 LOOP',
                primary: true,
                block: true,
                onPressed: onContinue,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              versionLabel,
              style: LoopTypography.figure(
                11,
                weight: FontWeight.w500,
                color: LoopColors.text3,
              ),
            ),
            const SizedBox(height: 18),
          ],
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
        const LoopNotice(
          icon: 'info',
          title: '外部钱包只是登录凭证',
          body: '它不是 LOOP 交易钱包，也不能授权任何交易。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
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
    required this.capabilityAvailable,
    required this.onContinue,
    super.key,
    this.onBack,
  });

  final bool capabilityAvailable;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '创建 LOOP 钱包',
      onBack: onBack,
      primaryAction: LoopButton(
        key: const ValueKey<String>('wallet-create-continue'),
        label: '设置恢复方式',
        primary: true,
        block: true,
        onPressed: capabilityAvailable ? onContinue : null,
      ),
      body: <Widget>[
        const IdentityProgress(step: 2, total: 5, label: '创建钱包'),
        const IdentityStepCopy('内置钱包由 Privy 在设备上创建，密钥不会经过 LOOP。'),
        if (capabilityAvailable)
          const LoopNotice(
            key: ValueKey<String>('wallet-create-progress'),
            icon: 'wallet',
            title: '正在创建你的钱包',
            body: '密钥在本地生成并写入安全区。完成前请不要关闭 App。',
          )
        else
          const LoopNotice(
            key: ValueKey<String>('wallet-create-unavailable'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '钱包创建暂不可用',
            body: 'Privy 尚未确认内置钱包能力。这一页不会伪造进度，也没有创建任何钱包。',
          ),
        const LoopLabel('这一步会做什么'),
        const LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              title: '生成密钥对',
              subtitle: '在设备本地生成，不上传',
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              title: '写入安全区',
              subtitle: '由系统钥匙串 / Keystore 保管',
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              title: '绑定 LOOP ID',
              subtitle: '钱包地址随时可换，LOOP ID 不变',
              position: LoopRowPosition.last,
            ),
          ],
        ),
        const LoopNotice(
          icon: 'info',
          title: 'LOOP 不使用助记词',
          body: '恢复通过 Passkey、恢复密码或自动恢复完成；下一步会让你选择。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// wallet-recovery · intro / focus
// ---------------------------------------------------------------------------

/// One selectable recovery method. Selecting it records a local intent only;
/// nothing is enrolled, stored or proven until the capability exists.
enum WalletRecoveryMethod {
  passkey('Passkey（推荐）', '用设备生物识别，跟随系统钥匙串同步', 'key'),
  password('恢复密码', '自己设一个密码，忘了就找不回', 'lock'),
  cloud('自动恢复', '凭登录方式恢复，最省事但依赖供应商', 'cloud');

  const WalletRecoveryMethod(this.title, this.detail, this.icon);

  final String title;
  final String detail;
  final String icon;
}

class WalletRecoveryScreen extends StatefulWidget {
  const WalletRecoveryScreen({
    required this.capabilities,
    required this.onContinue,
    super.key,
    this.onBack,
    this.loading = false,
    this.failureReason,
    this.onRetry,
  });

  final PrivyWalletCapabilities capabilities;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  /// The capability document has not been observed yet.
  final bool loading;

  /// The capability document could not be read. Options stay unavailable.
  final String? failureReason;
  final VoidCallback? onRetry;

  @override
  State<WalletRecoveryScreen> createState() => _WalletRecoveryScreenState();
}

class _WalletRecoveryScreenState extends State<WalletRecoveryScreen> {
  WalletRecoveryMethod? _chosen;

  bool _available(WalletRecoveryMethod method) => switch (method) {
    WalletRecoveryMethod.passkey => widget.capabilities.canUsePasskey,
    WalletRecoveryMethod.password => widget.capabilities.canUseRecoveryPassword,
    WalletRecoveryMethod.cloud => widget.capabilities.canUseCloudRecovery,
  };

  String _reason(WalletRecoveryMethod method) => switch (method) {
    WalletRecoveryMethod.passkey => '设备或 Privy 尚未确认 Passkey 能力',
    WalletRecoveryMethod.password => '恢复密码还没有开放',
    WalletRecoveryMethod.cloud => '账号恢复还没有开放',
  };

  bool get _anyAvailable => WalletRecoveryMethod.values.any(_available);

  @override
  Widget build(BuildContext context) {
    final blocked = widget.loading || widget.failureReason != null;
    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '恢复方式',
      onBack: widget.onBack,
      // The skip risk lives in the disclosure, so the primary pair stays
      // reachable on the first screen.
      primaryAction: LoopButtonPair(
        children: <Widget>[
          LoopButton(
            key: const ValueKey<String>('wallet-recovery-confirm'),
            label: '确认',
            primary: true,
            onPressed: _chosen != null && !blocked ? widget.onContinue : null,
          ),
          LoopButton(
            key: const ValueKey<String>('wallet-recovery-later'),
            label: '稍后设置',
            onPressed: widget.onContinue,
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
                    reason: '守护人还没有开放',
                    position: LoopRowPosition.first,
                  ),
                  _capabilityRow(
                    title: '导出私钥',
                    detail: '随时可导出，这是你的逃生舱',
                    available: widget.capabilities.canExportPrivateKey,
                    reason: '私钥导出还没有开放',
                    position: LoopRowPosition.last,
                  ),
                ],
              ),
              const LoopNotice(
                icon: 'warn',
                tone: LoopNoticeTone.danger,
                title: '跳过的后果',
                body: '换设备或清除数据后可能永久失去资产访问权。恢复方式可用后请尽快设置。',
                margin: EdgeInsets.only(top: 12),
              ),
            ],
          ),
        ),
      ),
      body: <Widget>[
        const IdentityProgress(step: 3, total: 5, label: '设置恢复方式'),
        const IdentityStepCopy('建议至少设置一种长期可用的恢复凭证。'),
        const LoopNotice(
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '这一步决定你换手机后能不能拿回资产',
          body: 'LOOP 没有助记词兜底，恢复方式是唯一的路。',
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
          if (!_anyAvailable)
            const LoopNotice(
              key: ValueKey<String>('wallet-recovery-unavailable'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '暂时没有可用的恢复方式',
              body: 'Privy 尚未确认任何恢复能力。下面的选项都不能在本地模拟或预先勾选。',
            ),
          const LoopLabel('选择方式'),
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

  LoopRecordRow _methodRow(WalletRecoveryMethod method) {
    final available = _available(method);
    final chosen = _chosen == method;
    final index = WalletRecoveryMethod.values.indexOf(method);
    return LoopRecordRow(
      key: ValueKey<String>('recovery-${method.name}'),
      leading: LoopIcon(
        method.icon,
        size: 19,
        color: available ? LoopColors.lime : LoopColors.text3,
      ),
      title: method.title,
      subtitle: available
          ? method.detail
          : '${method.detail} · ${_reason(method)}',
      trailing: chosen
          ? '已选'
          : available
          ? '可用'
          : '不可用',
      onTap: available ? () => setState(() => _chosen = method) : null,
      position: index == 0
          ? LoopRowPosition.first
          : index == WalletRecoveryMethod.values.length - 1
          ? LoopRowPosition.last
          : LoopRowPosition.middle,
      semanticLabel: available
          ? '${method.title}，${chosen ? '已选' : '可选'}'
          : '${method.title}，不可用：${_reason(method)}',
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
  });

  final PrivyWalletCapabilities capabilities;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '安全设置',
      onBack: onBack,
      primaryAction: LoopButton(
        key: const ValueKey<String>('security-setup-continue'),
        label: '下一步',
        primary: true,
        block: true,
        onPressed: onContinue,
      ),
      body: <Widget>[
        const IdentityProgress(step: 4, total: 5, label: '安全设置'),
        const IdentityStepCopy('应用锁与交易验证由 Privy 与设备共同决定。'),
        const LoopNotice(
          key: ValueKey<String>('protection-setup-unavailable'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '保护设置还没有开放',
          body: '这里不会保存 PIN，也不会声称已经开启任何保护。可用性只说明能力，不代表已启用。',
        ),
        const LoopLabel('应用锁'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            _row(
              title: '生物识别',
              detail: '打开 App 与签名前验证',
              available: capabilities.canUseBiometrics,
              reason: '设备生物识别能力尚未确认',
              position: LoopRowPosition.first,
            ),
            _row(
              title: '6 位 PIN',
              detail: '生物识别不可用时的备用',
              available: capabilities.canUseApplicationPin,
              reason: '应用 PIN 需要账号绑定的凭证生命周期决策',
              position: LoopRowPosition.last,
            ),
          ],
        ),
        const LoopLabel('交易验证'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            _row(
              title: 'MFA',
              detail: 'SMS / TOTP / Passkey',
              available: capabilities.canUseTransactionMfa,
              reason: '钱包 MFA 的设置回调尚不存在',
              position: LoopRowPosition.first,
            ),
            _row(
              title: '大额交易二次验证',
              detail: '超过阈值时重新验证身份',
              available: capabilities.canUseTransactionMfa,
              reason: '阈值与验证通道均未确定',
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

  LoopRecordRow _row({
    required String title,
    required String detail,
    required bool available,
    required String reason,
    required LoopRowPosition position,
  }) {
    return LoopRecordRow(
      key: ValueKey<String>('security-$title'),
      title: title,
      subtitle: available ? detail : '$detail · $reason',
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
