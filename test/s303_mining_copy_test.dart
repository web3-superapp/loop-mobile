import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';

/// S303 · loop-api decisions 0182 / 0183 (需求方 2026-10-25): every sentence
/// that says a holding produces power names the three conditions, and every
/// bound-token field says a token belongs to one community.
void main() {
  test('the mining (i) carries the three conditions, one per line', () {
    final notes = miningInfoNotes(null);
    final conditions = notes.singleWhere((note) => note.title == '哪些持仓计入算力');
    final lines = conditions.body.split('\n');
    expect(lines, hasLength(4));
    expect(lines[0], contains('持有数量 × 资产权重'));
    expect(lines[0], contains('NFT'));
    expect(lines[1], miningConditionVerified);
    expect(lines[2], miningConditionMember);
    expect(lines[3], miningConditionEmbedded);
  });

  test('the conditions say verified community, membership and embedded '
      'wallet', () {
    expect(miningConditionVerified, contains('已通过审核'));
    expect(miningConditionMember, contains('加入该社区'));
    expect(miningConditionEmbedded, contains('内置钱包'));
    expect(miningConditionsShort, contains('内置钱包'));
    expect(miningConditionsShort, contains('加入'));
  });

  test('the baseline detail states quantity times weight and the '
      'conditions', () {
    expect(miningBaselineDetail, contains('持币算力 = 持有数量 × 资产权重'));
    expect(miningBaselineDetail, contains('NFT 算力 = 持有数量 × 所属社区系数'));
    expect(miningBaselineDetail, contains('已加入该社区'));
    expect(miningBaselineDetail, contains('内置钱包'));
    expect(miningBaselineDetail, isNot(contains('社区币权重')));
  });

  test('one token, one community', () {
    expect(communityBoundAssetUniqueHint, '每个代币只能被一个社区绑定。');
  });
}
