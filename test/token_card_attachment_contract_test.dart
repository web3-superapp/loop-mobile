import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/attachments/token_card_attachment.dart';

void main() {
  const valid = <String, Object?>{
    'loop_schema': LoopTokenCardAttachment.schema,
    'asset_id': 'GLYPH',
    'chain_id': 'base',
    'contract_id': '0x71e4000000000000000000000000000000009a2c',
    'snapshot_at': '2026-08-23T14:07:00.000Z',
  };

  test('token_card.v1 accepts only the permanent identifier payload', () {
    final reference = LoopTokenCardAttachment.tryParse(
      type: LoopTokenCardAttachment.attachmentType,
      extraData: valid,
    );

    expect(reference, isNotNull);
    expect(reference!.assetId, 'GLYPH');
    expect(reference.chainId, 'base');
    expect(reference.compactContract, '0x71e40…09a2c');
    expect(reference.snapshotAt, DateTime.utc(2026, 8, 23, 14, 7));
    expect(reference.toExtraData(), valid);

    expect(
      LoopTokenCardAttachment.tryParse(
        type: LoopTokenCardAttachment.attachmentType,
        extraData: <String, Object?>{
          ...valid,
          'asset_id': 'glyph.v2',
          'contract_id': 'Base contract reference 1',
        },
      ),
      isNotNull,
      reason: 'v1 preserves the legacy bounded-text producer contract',
    );
  });

  test('mutable facts and executable data are rejected from the message', () {
    for (final forbidden in <String, Object?>{
      'price': '0.0842',
      'liquidity': '1000000',
      'risk_score': 'low',
      'buy_url': 'https://example.com/buy',
    }.entries) {
      expect(
        LoopTokenCardAttachment.tryParse(
          type: LoopTokenCardAttachment.attachmentType,
          extraData: <String, Object?>{
            ...valid,
            forbidden.key: forbidden.value,
          },
        ),
        isNull,
        reason: forbidden.key,
      );
    }
  });

  test('schema drift and malformed identifiers fail closed', () {
    final cases = <Map<String, Object?>>[
      <String, Object?>{...valid}..remove('asset_id'),
      <String, Object?>{...valid, 'loop_schema': 'token_card.v2'},
      <String, Object?>{
        ...valid,
        'asset_id': List<String>.filled(33, 'A').join(),
      },
      <String, Object?>{...valid, 'asset_id': ' padded'},
      <String, Object?>{...valid, 'asset_id': 'bad\u0001asset'},
      <String, Object?>{...valid, 'asset_id': 'bad\nasset'},
      <String, Object?>{...valid, 'asset_id': 'bad\u202easset'},
      <String, Object?>{...valid, 'chain_id': 'Base'},
      <String, Object?>{...valid, 'chain_id': 'eip155:8453'},
      <String, Object?>{...valid, 'chain_id': 'base/mainnet'},
      <String, Object?>{...valid, 'contract_id': ' trailing '},
      <String, Object?>{...valid, 'contract_id': 'bad\u007fcontract'},
      <String, Object?>{...valid, 'contract_id': 'bad\u200bcontract'},
      <String, Object?>{...valid, 'snapshot_at': '2026-02-30T14:07:00.000Z'},
      <String, Object?>{...valid, 'snapshot_at': '2026-08-23T14:07:00Z'},
    ];

    for (final extraData in cases) {
      expect(
        LoopTokenCardAttachment.tryParse(
          type: LoopTokenCardAttachment.attachmentType,
          extraData: extraData,
        ),
        isNull,
        reason: extraData.toString(),
      );
    }
    expect(
      LoopTokenCardAttachment.tryParse(type: 'image', extraData: valid),
      isNull,
    );
  });
}
