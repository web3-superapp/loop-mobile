import 'dart:convert';

import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';

/// Decoders for the two DApp intent kinds (S342 · decision 0270, docs/55 §二).
///
/// Client first: the server half (S342-api) was written in parallel, so the
/// review is read by meaning, not key by key. Known keys are validated,
/// unknown keys are ignored, and the facts the signature depends on — the
/// ids, the chain, the digest, the signing permission, the unsigned
/// transaction and the message to sign — are required and strict. A review
/// the client cannot read is an invalid payload, never a partial sheet.
abstract final class LoopV2DappCodec {
  static Never _invalid() => LoopV2ChainCodec.invalid();

  static final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _address = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final RegExp _selector = RegExp(r'^0x[0-9a-fA-F]{8}$');
  static final RegExp _origin = RegExp(r'^https://[^/\s]{1,253}$');

  static const _intentKeys = <String>{
    'intentId',
    'kind',
    'state',
    'walletId',
    'chainId',
    'review',
    'reviewSha256',
    'expiresAt',
    'signing',
  };

  static const _optionalIntentKeys = <String>{
    'origin',
    'riskFlags',
    'factsObservedAt',
    'simulation',
    'policy',
    'unsignedTransaction',
    'authorizationPayload',
    'signatureRequest',
    'signPayload',
    'messagePayload',
    'result',
    'version',
    'createdAt',
    'updatedAt',
    'contractVersion',
  };

  /// True when [raw] names one of the two DApp kinds.
  static bool isDappKind(Object? raw) =>
      raw is Map && DappIntentKind.tryParse(raw['kind']) != null;

  static DappIntent intent(Object? raw) {
    final map = LoopV2Contract.knownKeysMap(
      raw,
      _intentKeys,
      _optionalIntentKeys,
    );
    if (map.containsKey('contractVersion')) {
      LoopV2ChainCodec.requireContractVersion(map);
    }
    final kind = DappIntentKind.tryParse(map['kind']);
    if (kind == null) _invalid();
    final rawState = map['state'];
    final state = rawState is String
        ? LoopIntentState.tryParse(rawState)
        : null;
    if (state == null) _invalid();
    final chainId = map['chainId'];
    if (chainId is! String || !loopKnownChainIds.contains(chainId)) _invalid();
    final review = _reviewView(map['review']);
    final origin = map['origin'] ?? review['origin'];
    if (origin is! String || !_origin.hasMatch(origin)) _invalid();
    final signing = LoopV2Contract.knownKeysMap(
      map['signing'],
      const <String>{'allowed'},
      const <String>{'mode', 'reasonCode'},
    );
    final allowed = signing['allowed'];
    if (allowed is! bool) _invalid();
    final reason = signing['reasonCode'];
    final digest = map['reviewSha256'];
    if (digest is! String || !_sha256.hasMatch(digest)) _invalid();

    DappTxReview? txReview;
    DappSignReview? signReview;
    LoopUnsignedTransaction? unsigned;
    String? signMethod;
    String? signPayload;
    switch (kind) {
      case DappIntentKind.transaction:
        txReview = _txReview(review);
        unsigned = LoopV2IntentCodec.unsignedTransactionFor(
          map['unsignedTransaction'],
          chainId,
        );
      case DappIntentKind.message:
        signReview = _signReview(review);
        final payload = _signPayload(map, review);
        signMethod = payload.$1;
        signPayload = payload.$2;
        if (signMethod != signReview.method) _invalid();
    }
    final flags = <DappRiskFlag>{
      ..._flags(review['riskFlags']),
      ..._flags(map['riskFlags']),
    };
    String? txHash;
    final result = map['result'];
    if (result is Map) {
      final hash = result['transactionHash'];
      if (hash is String && LoopV2ChainCodec.hashPattern.hasMatch(hash)) {
        txHash = hash;
      }
    }
    return DappIntent(
      intentId: LoopV2ChainCodec.requireString(
        map,
        'intentId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      kind: kind,
      state: state,
      walletId: LoopV2ChainCodec.requireString(
        map,
        'walletId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      chainId: chainId,
      origin: origin,
      reviewSha256: digest,
      expiresAt: LoopV2ChainCodec.requireTimestamp(map, 'expiresAt'),
      signingAllowed: allowed,
      signingReasonCode:
          reason is String &&
              LoopV2ChainCodec.reasonCodePattern.hasMatch(reason)
          ? reason
          : null,
      riskFlags: <DappRiskFlag>[
        for (final flag in DappRiskFlag.values)
          if (flags.contains(flag)) flag,
      ],
      txReview: txReview,
      signReview: signReview,
      unsignedTransaction: unsigned,
      signMethod: signMethod,
      signPayload: signPayload,
      transactionHash: txHash,
    );
  }

  static const _reviewKeys = <String>{
    'kind',
    'origin',
    'method',
    'to',
    'toIsContract',
    'toVerified',
    'value',
    'decodedCall',
    'counterparty',
    'riskFlags',
    'message',
    'text',
    'hex',
    'typedData',
    'payload',
    'dapp',
  };

  /// The review as one flat view: S342-api nests the DApp facts under
  /// `review.dapp` (origin, method, to, value, decodedCall, counterparty,
  /// message, typedData, riskFlags) beside the generic money-action keys;
  /// those nested keys win over a top-level key of the same name.
  static Map<String, Object?> _reviewView(Object? raw) {
    final review = LoopV2Contract.knownKeysMap(
      raw,
      const <String>{},
      _reviewKeys,
    );
    final nested = review['dapp'];
    if (nested == null) return review;
    final dapp = LoopV2Contract.knownKeysMap(
      nested,
      const <String>{},
      _reviewKeys,
    );
    return <String, Object?>{
      ...review,
      for (final entry in dapp.entries)
        if (entry.value != null || !review.containsKey(entry.key))
          entry.key: entry.value,
    };
  }

  static Iterable<DappRiskFlag> _flags(Object? raw) sync* {
    if (raw == null) return;
    if (raw is! List || raw.length > 16) _invalid();
    for (final item in raw) {
      // A flag this build does not know is a later rule: it is not drawn,
      // and it does not break the sheet.
      final flag = DappRiskFlag.tryParse(item);
      if (flag != null) yield flag;
    }
  }

  static BigInt _wei(Object? raw) {
    Object? value = raw;
    if (value is Map) value = value['raw'] ?? value['wei'];
    if (value == null) return BigInt.zero;
    if (value is int && value >= 0) return BigInt.from(value);
    if (value is String) {
      if (RegExp(r'^0x[0-9a-fA-F]{1,64}$').hasMatch(value)) {
        return BigInt.parse(value.substring(2), radix: 16);
      }
      if (LoopV2ChainCodec.rawAmountPattern.hasMatch(value)) {
        return BigInt.parse(value);
      }
    }
    _invalid();
  }

  static DappTxReview _txReview(Map<String, Object?> review) {
    final rawTo = review['to'];
    String? to;
    bool? isContract = _optionalBool(review['toIsContract']);
    bool? verified = _optionalBool(review['toVerified']);
    if (rawTo is String) {
      to = rawTo;
    } else if (rawTo is Map) {
      final address = rawTo['address'];
      if (address is String) to = address;
      isContract ??= _optionalBool(rawTo['isContract']);
      verified ??= _optionalBool(rawTo['verified'] ?? rawTo['isVerified']);
    }
    if (to == null || !_address.hasMatch(to)) _invalid();
    return DappTxReview(
      to: to.toLowerCase(),
      toIsContract: isContract,
      toVerified: verified,
      valueWei: _wei(review['value']),
      decodedCall: _decodedCall(review['decodedCall']),
    );
  }

  static bool? _optionalBool(Object? value) => value is bool ? value : null;

  static DappDecodedCall? _decodedCall(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.knownKeysMap(
      raw,
      const <String>{},
      const <String>{'functionName', 'selector', 'args', 'dataLength'},
    );
    final name = map['functionName'];
    if (name != null && (name is! String || name.isEmpty || name.length > 64)) {
      _invalid();
    }
    final selector = map['selector'];
    if (selector != null &&
        (selector is! String || !_selector.hasMatch(selector))) {
      _invalid();
    }
    final args = <String, String>{};
    final rawArgs = map['args'];
    if (rawArgs is Map) {
      for (final entry in rawArgs.entries.take(12)) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || key.length > 64) _invalid();
        if (value is String && value.length <= 256) {
          args[key] = value;
        } else if (value is num || value is bool) {
          args[key] = '$value';
        }
      }
    } else if (rawArgs != null && rawArgs is! List) {
      _invalid();
    }
    final length = map['dataLength'];
    return DappDecodedCall(
      functionName: name as String?,
      selector: (selector as String?)?.toLowerCase(),
      args: args,
      dataLength: length is int && length >= 0 ? length : null,
    );
  }

  static const _methods = <String>{'personal_sign', 'eth_signTypedData_v4'};

  static DappSignReview _signReview(Map<String, Object?> review) {
    final Object? source = review['message'];
    final merged = <String, Object?>{
      ...review,
      if (source is Map)
        for (final entry in source.entries)
          if (entry.key is String) entry.key as String: entry.value,
    };
    final method = merged['method'];
    if (method is! String || !_methods.contains(method)) _invalid();
    final text = merged['text'];
    final hex = merged['hex'];
    Object? typed = merged['typedData'];
    if (typed is String) {
      try {
        typed = jsonDecode(typed);
      } on FormatException {
        _invalid();
      }
    }
    if (method == 'eth_signTypedData_v4') {
      if (typed is! Map) _invalid();
      final fields = typed['fields'];
      if (fields is List) {
        // S342-api flattens the message tree into `{path, type, value}`
        // leaves; the sheet draws them back as one level under `message`.
        final domain = typed['domain'];
        return DappSignReview(
          method: method,
          text: null,
          hex: null,
          typedData: <String, Object?>{
            'primaryType': typed['primaryType'],
            if (domain is Map)
              'domain': <String, Object?>{
                for (final entry in domain.entries)
                  if (entry.value != null) '${entry.key}': entry.value,
              },
            'message': <String, Object?>{
              for (final field in fields.take(256))
                if (field is Map && field['path'] is String)
                  field['path'] as String: field['value'],
            },
          },
        );
      }
      return DappSignReview(
        method: method,
        text: null,
        hex: null,
        typedData: <String, Object?>{
          for (final key in const <String>['primaryType', 'domain', 'message'])
            if (typed.containsKey(key)) key: typed[key],
        },
      );
    }
    if (text is! String && hex is! String) {
      if (source is String) {
        return DappSignReview(
          method: method,
          text: source,
          hex: null,
          typedData: null,
        );
      }
      _invalid();
    }
    return DappSignReview(
      method: method,
      text: text is String ? text : null,
      hex: hex is String ? hex : null,
      typedData: null,
    );
  }

  /// The method and exact payload the device signs: `signPayload` or
  /// `messagePayload` (`{method, payload}`), else the review's own `payload`.
  static (String, String) _signPayload(
    Map<String, Object?> map,
    Map<String, Object?> review,
  ) {
    final request = map['signatureRequest'];
    final block = map['signPayload'] ?? map['messagePayload'];
    Object? method;
    Object? payload;
    if (request is Map) {
      // `{method, params}` exactly as the device hands it to the embedded
      // provider: personal_sign `[message, address]`, typed data
      // `[address, typedDataJson]`.
      method = request['method'];
      final params = request['params'];
      if (params is! List || params.length != 2) _invalid();
      payload = method == 'personal_sign' ? params[0] : params[1];
    } else if (block is Map) {
      method = block['method'];
      payload = block['payload'];
    } else {
      method =
          review['method'] ??
          (review['message'] is Map
              ? (review['message']! as Map)['method']
              : null);
      payload = review['payload'];
    }
    if (method is! String || !_methods.contains(method)) _invalid();
    if (payload is Map) payload = jsonEncode(payload);
    if (payload is! String || payload.isEmpty || payload.length > 65536) {
      _invalid();
    }
    return (method, payload);
  }
}
