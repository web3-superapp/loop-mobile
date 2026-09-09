import 'package:flutter/material.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

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
