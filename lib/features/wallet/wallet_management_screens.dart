import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/wallet/wallet_readiness.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:uuid/uuid.dart';

class DappBrowserScreen extends ConsumerStatefulWidget {
  const DappBrowserScreen({super.key});

  @override
  ConsumerState<DappBrowserScreen> createState() => _DappBrowserScreenState();
}

class _DappBrowserScreenState extends ConsumerState<DappBrowserScreen> {
  final controller = TextEditingController(text: 'app.uniswap.org');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readiness = WalletReadiness.fromSession(
      ref.watch(loopSessionProvider),
    );
    final typedDomain = controller.text.trim();
    return LoopPage(
      title: 'DApp browser',
      eyebrow: '开发预览',
      subtitle: 'Local domain layout only. Embedded browsing and wallet injection remain disabled.',
      children: <Widget>[
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.lock_outline_rounded),
            suffixIcon: Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 14),
        const LoopStateCard(
          title: 'Browser and injection unavailable',
          message: 'The typed domain is not trusted, opened, resolved, or connected to a wallet.',
          icon: Icons.language_rounded,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('Before connecting'),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'Typed preview domain',
                value: typedDomain.isEmpty ? 'Unavailable' : typedDomain,
              ),
              LoopKeyValueRow(
                label: 'Current wallet identity',
                value: readiness.canCopy
                    ? readiness.ethereumAddress!
                    : 'Unavailable',
              ),
              const LoopKeyValueRow(
                label: 'Wallet injection',
                value: 'Unavailable',
              ),
              const LoopKeyValueRow(
                label: 'Granted permissions',
                value: 'None',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ApprovalInterceptScreen extends StatefulWidget {
  const ApprovalInterceptScreen({super.key});

  @override
  State<ApprovalInterceptScreen> createState() =>
      _ApprovalInterceptScreenState();
}

class _ApprovalInterceptScreenState extends State<ApprovalInterceptScreen> {
  bool unlimited = false;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Approval request',
      eyebrow: '开发预览 · Wallet protection',
      subtitle: 'This is a local layout draft. No DApp request or wallet fact was received.',
      bottom: LoopActionDock(
        child: FilledButton(
          onPressed: unlimited
              ? null
              : () {
                  final now = DateTime.now().toUtc();
                  context.push(
                    '/preview/signing-review',
                    extra: SigningIntent.approval(
                      revision: const Uuid().v4(),
                      app: 'app.uniswap.org',
                      asset: 'USDC',
                      allowance: '250.00 USDC',
                      network: 'Ethereum',
                      observedAt: now,
                      expiresAt: now.add(const Duration(seconds: 30)),
                    ),
                  );
                },
          child: Text(
            unlimited
                ? 'Choose a limited allowance'
                : 'Review limited approval',
          ),
        ),
      ),
      children: <Widget>[
        const LoopStateCard(
          title: '演示数据 · approval request',
          message: 'An approval is permission, not a payment. It remains active until you revoke it.',
          icon: Icons.policy_outlined,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('Allowance'),
        LoopCard(
          child: RadioGroup<bool>(
            groupValue: unlimited,
            onChanged: (value) => setState(() => unlimited = value ?? false),
            child: const Column(
              children: <Widget>[
                RadioListTile<bool>(
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Limited'),
                  subtitle: Text('Up to 250.00 USDC'),
                ),
                RadioListTile<bool>(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Unlimited'),
                  subtitle: Text(
                    'Not recommended · action disabled in preview',
                  ),
                ),
              ],
            ),
          ),
        ),
        const LoopSectionLabel('Request facts'),
        const LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(label: 'App', value: 'app.uniswap.org'),
              LoopKeyValueRow(label: 'Asset', value: 'USDC'),
              LoopKeyValueRow(label: 'Network', value: 'Ethereum'),
              LoopKeyValueRow(
                label: 'Current allowance',
                value: '0 USDC',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'App permissions',
      eyebrow: '开发预览',
      subtitle: 'Allowances below are 演示数据; no supported network was queried.',
      children: <Widget>[
        const LoopStateCard(
          title: '演示数据 · permission warning',
          message: 'This is a warning-layout example. No allowance or wallet balance was read.',
          icon: Icons.warning_amber_rounded,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('Ethereum'),
        LoopCard(
          accent: true,
          tone: LoopTone.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const LoopAssetMark(symbol: 'USDC'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Uniswap Router',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Unlimited USDC · last used Aug 20',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: const Text('Revocation unavailable'),
                ),
              ),
            ],
          ),
        ),
        const LoopSectionLabel('Arbitrum'),
        const LoopStateCard(
          title: '演示数据 · empty allowance state',
          message: 'This preview is not evidence that the connected account has no allowances.',
          icon: Icons.visibility_outlined,
          tone: LoopTone.neutral,
        ),
      ],
    );
  }
}

class DappListScreen extends StatelessWidget {
  const DappListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoopPage(
      title: 'DApps',
      eyebrow: 'Later phase',
      subtitle: 'Bookmarks and recent apps will appear after browser isolation and permission controls are production-ready.',
      children: <Widget>[
        LoopStateCard(
          title: 'Deliberately deferred',
          message: 'The wallet can be completed without an embedded DApp directory. Direct domain connections remain the safer first release.',
          icon: Icons.apps_outlined,
        ),
      ],
    );
  }
}

class ProtectionScreen extends StatelessWidget {
  const ProtectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoopPage(
      title: 'Transaction protection',
      eyebrow: 'Later phase',
      subtitle: 'Protection will explain concrete simulation findings without inventing a risk score.',
      children: <Widget>[
        LoopStateCard(
          title: 'No third-party protection configured',
          message: 'Privy policy and MFA protection require verified provider configuration. Contract simulation and malicious-domain detection require a separate trusted data source.',
          icon: Icons.shield_outlined,
          tone: LoopTone.warning,
        ),
        LoopSectionLabel('What remains protected'),
        LoopCard(
          child: Column(
            children: <Widget>[
              LoopKeyValueRow(
                label: 'High-value actions',
                value: 'Provider policy not verified',
              ),
              LoopKeyValueRow(
                label: 'Exact transaction facts',
                value: 'Backend canonical review required',
              ),
              LoopKeyValueRow(
                label: 'Provider result',
                value: 'Not connected',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
