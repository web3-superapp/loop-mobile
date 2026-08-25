import 'package:flutter/foundation.dart' show immutable;

/// The identifier-only payload accepted from a Stream Chat message.
///
/// Prices, liquidity, ownership, risk labels, provider URLs, and executable
/// actions are deliberately absent. Those facts can change after the message
/// is stored and must come from a separately verified, fresh projection.
@immutable
final class LoopTokenCardAttachment {
  const LoopTokenCardAttachment._({
    required this.assetId,
    required this.chainId,
    required this.contractId,
    required this.snapshotAt,
  });

  static const String attachmentType = 'token_card';
  static const String schema = 'token_card.v1';
  static const Set<String> extraDataKeys = <String>{
    'loop_schema',
    'asset_id',
    'chain_id',
    'contract_id',
    'snapshot_at',
  };

  static final RegExp _chainPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');
  static final RegExp _forbiddenTextControlPattern = RegExp(
    r'[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff]',
  );
  static final RegExp _timestampPattern = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
  );

  final String assetId;
  final String chainId;
  final String contractId;
  final DateTime snapshotAt;

  static LoopTokenCardAttachment? tryParse({
    required String? type,
    required Map<String, Object?> extraData,
  }) {
    if (type != attachmentType ||
        extraData.length != extraDataKeys.length ||
        !extraData.keys.every(extraDataKeys.contains)) {
      return null;
    }

    final rawSchema = extraData['loop_schema'];
    final assetId = extraData['asset_id'];
    final chainId = extraData['chain_id'];
    final contractId = extraData['contract_id'];
    final snapshotAt = extraData['snapshot_at'];
    if (rawSchema != schema ||
        assetId is! String ||
        chainId is! String ||
        contractId is! String ||
        snapshotAt is! String ||
        !_isBoundedLegacyText(assetId, maxLength: 32) ||
        !_chainPattern.hasMatch(chainId) ||
        !_isBoundedLegacyText(contractId, maxLength: 128) ||
        !_timestampPattern.hasMatch(snapshotAt)) {
      return null;
    }

    final parsedTime = DateTime.tryParse(snapshotAt);
    if (parsedTime == null ||
        !parsedTime.isUtc ||
        parsedTime.toIso8601String() != snapshotAt) {
      return null;
    }

    return LoopTokenCardAttachment._(
      assetId: assetId,
      chainId: chainId,
      contractId: contractId,
      snapshotAt: parsedTime,
    );
  }

  Map<String, Object?> toExtraData() => <String, Object?>{
    'loop_schema': schema,
    'asset_id': assetId,
    'chain_id': chainId,
    'contract_id': contractId,
    'snapshot_at': snapshotAt.toIso8601String(),
  };

  static bool _isBoundedLegacyText(String value, {required int maxLength}) {
    return value.isNotEmpty &&
        value.length <= maxLength &&
        value.trim() == value &&
        !_forbiddenTextControlPattern.hasMatch(value);
  }

  String get compactContract {
    if (contractId.length <= 14) return contractId;
    return '${contractId.substring(0, 7)}…${contractId.substring(contractId.length - 5)}';
  }

  @override
  bool operator ==(Object other) {
    return other is LoopTokenCardAttachment &&
        other.assetId == assetId &&
        other.chainId == chainId &&
        other.contractId == contractId &&
        other.snapshotAt == snapshotAt;
  }

  @override
  int get hashCode => Object.hash(assetId, chainId, contractId, snapshotAt);
}
