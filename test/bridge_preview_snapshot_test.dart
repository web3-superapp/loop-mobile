import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/bridge_preview_snapshot.dart';

void main() {
  test('Bridge progress variants preserve one immutable route snapshot', () {
    const pending = BridgePreviewSnapshot.demo;
    final claim = pending.withNeedsClaim(true);

    expect(pending.needsClaim, isFalse);
    expect(pending.destinationStepTitle, 'Destination pending');
    expect(claim.needsClaim, isTrue);
    expect(claim.destinationStepTitle, 'Manual claim required');
    expect(claim.destinationStepDetail, contains('unavailable'));

    expect(claim.sourceLabel, pending.sourceLabel);
    expect(claim.destinationLabel, pending.destinationLabel);
    expect(claim.estimatedTimeLabel, pending.estimatedTimeLabel);
    expect(claim.estimatedFeesLabel, pending.estimatedFeesLabel);
    expect(claim.sourceConfirmationLabel, pending.sourceConfirmationLabel);
    expect(claim.relayLabel, pending.relayLabel);

    final pendingSteps = pending.progressSteps;
    final claimSteps = claim.progressSteps;
    expect(pendingSteps, hasLength(3));
    expect(pendingSteps.first.title, 'Source confirmed');
    expect(pendingSteps.first.complete, isTrue);
    expect(pendingSteps.first.warning, isFalse);
    expect(pendingSteps[1].title, 'Relay processing');
    expect(pendingSteps[1].complete, isTrue);
    expect(pendingSteps.last.complete, isFalse);
    expect(pendingSteps.last.warning, isFalse);
    expect(claimSteps.last.title, 'Manual claim required');
    expect(claimSteps.last.complete, isFalse);
    expect(claimSteps.last.warning, isTrue);
  });
}
