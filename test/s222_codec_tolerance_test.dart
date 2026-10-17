import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

import 'support/launch2_fixtures.dart';

// ---------------------------------------------------------------------------
// S222 · client decision 0198: what the strict codecs now admit
// ---------------------------------------------------------------------------
//
// The creator `hooks-config` cases live in s135_launch2_creator_codec_test,
// the dynamic-pool viewer / rounds cases in s168_launch2_dynamic_pool_test.

final Matcher _invalid = throwsA(isA<LoopBackendFailure>());

void main() {
  group('LoopV2Contract.knownKeysMap', () {
    test('known keys strict, unknown keys dropped', () {
      final map = LoopV2Contract.knownKeysMap(
        <String, Object?>{'a': 1, 'b': 2, 'future': 3},
        const <String>{'a'},
        const <String>{'b', 'c'},
      );
      expect(map, <String, Object?>{'a': 1, 'b': 2});
      expect(map.containsKey('future'), isFalse);
      expect(map.containsKey('c'), isFalse);
    });

    test(
      'a missing required key, a non-map or a non-string key is invalid',
      () {
        expect(
          () => LoopV2Contract.knownKeysMap(
            <String, Object?>{'b': 2},
            const <String>{'a'},
          ),
          _invalid,
        );
        expect(
          () => LoopV2Contract.knownKeysMap(<Object?>[], const <String>{'a'}),
          _invalid,
        );
        expect(
          () => LoopV2Contract.knownKeysMap(
            <Object?, Object?>{'a': 1, 2: 'x'},
            const <String>{'a'},
          ),
          _invalid,
        );
      },
    );
  });

  group('launch2 instance template', () {
    Map<String, Object?> template(Map<String, Object?> json) =>
        (json['instance']! as Map<String, Object?>)['template']!
            as Map<String, Object?>;

    test('a key a later generation adds is ignored', () {
      final json = l2DetailJson(perAddressCap: '3000000', perAddressCapBps: 30);
      template(json)['someFutureParameter'] = '1';
      final detail = LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null);
      expect(detail.template.perAddressCap, Decimal.fromInt(3000000));
    });

    test('a known key stays strict', () {
      final missing = l2DetailJson();
      template(missing).remove('perAddressCap');
      expect(
        () => LoopV2Launch2Codec.detail(missing, mediaUrl: (_) => null),
        _invalid,
      );
      final version = l2DetailJson();
      template(version)['templateVersion'] = 'hooks_launch_v2';
      expect(
        () => LoopV2Launch2Codec.detail(version, mediaUrl: (_) => null),
        _invalid,
      );
    });
  });

  group('community directory row', () {
    Map<String, Object?> row() => <String, Object?>{
      'communityId': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
      'name': 'Frog Holders',
      'slug': 'frog-holders',
      'description': null,
      'logoRef': null,
      'verificationStatus': 'pending',
      'boundAssetKey': 'eip155:56:0x55d398326f99059ff775485246999027b3197955',
      'memberCount': 1,
      'createdAt': '2026-06-01T00:00:00.000Z',
      'configVersion': 'communityV1',
      'viewerMembership': <String, Object?>{
        'role': 'owner',
        'status': 'active',
        'pending': true,
      },
      'boundAsset': null,
    };

    test("an owned page's application is accepted and ignored", () {
      final read = LoopV2ProjectionCodec.communityRow(
        row()
          ..['application'] = <String, Object?>{
            'status': 'pending',
            'submittedAt': '2026-06-01T00:00:00.000Z',
            'reviewedAt': null,
            'rejectedReason': null,
          },
        sort: CommunityDirectorySort.members,
      );
      expect(read.name, 'Frog Holders');
      expect(
        () => LoopV2ProjectionCodec.communityRow(
          row()..['somethingElse'] = 1,
          sort: CommunityDirectorySort.members,
        ),
        _invalid,
      );
    });
  });
}
