import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_mint.dart';
import 'package:loop_mobile/features/launch2/launch2_trade_panel.dart';

// ---------------------------------------------------------------------------
// S224 · decision 0200 · the S221 walkthrough defects outside the creator
// pages (those are in s135_launch2_creator_pages_test.dart).
// ---------------------------------------------------------------------------

void main() {
  test('defect 5 · the curve explains 「最少获得」 with the server tolerance', () {
    expect(launch2CurveMinOutNote(100), '按当前曲线价计算，已含 1% 滑点保护，成交以链上为准');
    expect(launch2CurveMinOutNote(50), contains('0.5%'));
  });

  group('defect 6 · one set of words: 铸造', () {
    test('no stage label or caption says 发售 / 开售 / 认购', () {
      for (final stage in Launch2Stage.values) {
        for (final text in <String>[
          launch2StageLabel(stage),
          launch2StageCaption(stage),
        ]) {
          expect(text, isNot(matches(RegExp('发售|开售|认购'))), reason: stage.name);
        }
      }
      expect(launch2StageLabel(Launch2Stage.upcoming), '即将铸造');
      expect(launch2StageLabel(Launch2Stage.nftSale), '铸造中');
      expect(launch2ClosedNoHoldersText, '无人铸造，已关闭');
    });

    test('both mint entries name the action 铸造', () {
      for (final entry in Launch2NftMintEntry.values) {
        expect(entry.noun, '铸造');
      }
    });
  });

  group('defect 7 · 「测试网合约还在核对」', () {
    LoopCapabilityProjection pending(String? reason) =>
        LoopCapabilityProjection(
          decision: LoopCapabilityDecision.available,
          evidencePending: true,
          evidenceReasonCode: reason,
        );

    test('the module-wide testnet marker is not a fact about one instance', () {
      expect(
        launch2EvidenceNoticeShown(pending(launch2TestnetEvidencePendingCode)),
        isFalse,
      );
    });

    test('any other pending reason is still said', () {
      expect(
        launch2EvidenceNoticeShown(pending('LAUNCH2_RUNTIME_UNAVAILABLE')),
        isTrue,
      );
      expect(launch2EvidenceNoticeShown(pending(null)), isTrue);
    });

    test('no pending evidence, no line', () {
      expect(
        launch2EvidenceNoticeShown(
          const LoopCapabilityProjection(
            decision: LoopCapabilityDecision.available,
          ),
        ),
        isFalse,
      );
    });
  });
}
