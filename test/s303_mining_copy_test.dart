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
    final conditions = notes.singleWhere(
      (note) => note.title == 'Which holdings count toward power',
    );
    final lines = conditions.body.split('\n');
    expect(lines, hasLength(4));
    expect(lines[0], contains('amount held × asset weight'));
    expect(lines[0], contains('NFT'));
    expect(lines[1], miningConditionVerified);
    expect(lines[2], miningConditionMember);
    expect(lines[3], miningConditionEmbedded);
  });

  test('the conditions say verified community, membership and embedded '
      'wallet', () {
    expect(miningConditionVerified, contains('approved'));
    expect(miningConditionMember, contains('join the community'));
    // S304: the embedded-only rule is a server switch, off by default;
    // the copy names every wallet bound to the account.
    expect(
      miningConditionEmbedded,
      'Calculated from holdings in wallets linked to your LOOP account.',
    );
    expect(miningConditionEmbedded, isNot(contains('built-in')));
    expect(miningConditionsShort, contains('linked wallet'));
    expect(miningConditionsShort, isNot(contains('built-in')));
    expect(miningConditionsShort, contains('joining'));
  });

  test('the baseline detail states quantity times weight and the '
      'conditions', () {
    expect(
      miningBaselineDetail,
      contains('Token power = amount held × asset weight'),
    );
    expect(
      miningBaselineDetail,
      contains('NFT power = amount held × community factor'),
    );
    expect(miningBaselineDetail, contains("you've joined it"));
    expect(
      miningBaselineDetail,
      contains(
        'Calculated from holdings in wallets linked to your LOOP account',
      ),
    );
    expect(miningBaselineDetail, isNot(contains('built-in')));
    expect(miningBaselineDetail, isNot(contains('Community token weights')));
  });

  test('one token, one community', () {
    expect(
      communityBoundAssetUniqueHint,
      'Each token can be linked to only one community.',
    );
  });
}
