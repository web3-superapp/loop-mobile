import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/wallet/wallet_readiness.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

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
