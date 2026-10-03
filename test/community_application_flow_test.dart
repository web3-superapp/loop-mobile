import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_application_flow.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/community_test_harness.dart';

void main() {
  Future<void> pumpApplication(
    WidgetTester tester,
    FakeCommunityGateway gateway,
  ) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityGatewayProvider.overrideWithValue(gateway),
        loopCapabilityProvider.overrideWith(
          (ref, id) => const LoopCapabilityProjection(
            decision: LoopCapabilityDecision.unavailable,
          ),
        ),
      ],
      child: MaterialApp(
        home: LoopToastHost(
          child: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    unawaited(openCommunityApplication(context, ref)),
                child: const Text('创建社区'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('closed production capability prevents form and write', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway();
    await pumpApplication(tester, gateway);
    await tester.tap(find.text('创建社区'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-apply-sheet')), findsNothing);
    expect(find.text('社区当前不可用'), findsOneWidget);
    expect(gateway.commands, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('explicit preview keeps the existing application form usable', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(mode: CommunityGatewayMode.preview);
    await pumpApplication(tester, gateway);
    await tester.tap(find.text('创建社区'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-apply-sheet')), findsOneWidget);
    expect(gateway.commands, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
