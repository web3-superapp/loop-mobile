import 'package:decimal/decimal.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the S6 money-action modules (`sendApprovals`, `swap`).
///
/// Every object goes through [LoopV2Contract.strictMap]: an unknown or missing
/// field is an invalid payload, never a partially trusted intent. Amounts stay
/// exact — the raw minor-unit string is kept verbatim because it is what the
/// call data encodes, and `double` never appears.
abstract final class LoopV2IntentCodec {
  static final RegExp checksumAddressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final RegExp callDataPattern = RegExp(r'^0x([0-9a-f]{2})*$');
  static final RegExp quantityPattern = RegExp(r'^0x(0|[1-9a-f][0-9a-f]*)$');
  static final RegExp selectorPattern = RegExp(r'^0x[0-9a-f]{8}$');
  static final RegExp sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp versionPattern = RegExp(r'^[1-9][0-9]{0,18}$');
  static final RegExp expiryPattern = RegExp(r'^[1-9][0-9]{0,15}$');
  static final RegExp warningPattern = RegExp(r'^[a-z][A-Za-z0-9.]{0,63}$');
  static final RegExp providerActionIdPattern = RegExp(r'^[\x21-\x7e]{1,128}$');
  static final RegExp httpsUrlPattern = RegExp(r'^https://[\x21-\x7e]{1,504}$');
  static final RegExp privyAppIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  static Never _invalid() => LoopV2ChainCodec.invalid();

  static String _address(Map<String, Object?> source, String key) =>
      LoopV2ChainCodec.requireString(
        source,
        key,
        pattern: LoopV2ChainCodec.addressPattern,
        maxLength: 42,
      );

  static String _checksumAddress(Map<String, Object?> source, String key) =>
      LoopV2ChainCodec.requireString(
        source,
        key,
        pattern: checksumAddressPattern,
        maxLength: 42,
      );

  static String _hash(Map<String, Object?> source, String key) =>
      LoopV2ChainCodec.requireString(
        source,
        key,
        pattern: LoopV2ChainCodec.hashPattern,
        maxLength: 66,
      );

  static String? _optionalQuantity(Map<String, Object?> source, String key) =>
      LoopV2ChainCodec.optionalString(
        source,
        key,
        pattern: quantityPattern,
        maxLength: 80,
      );

  static String _quantity(Map<String, Object?> source, String key) =>
      LoopV2ChainCodec.requireString(
        source,
        key,
        pattern: quantityPattern,
        maxLength: 80,
      );

  /// A raw minor-unit string that is optional on the wire.
  static String? _optionalRawAmount(Map<String, Object?> source, String key) =>
      LoopV2ChainCodec.optionalString(
        source,
        key,
        pattern: LoopV2ChainCodec.rawAmountPattern,
        maxLength: 80,
      );

  static LoopIntentKind _kind(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String) _invalid();
    return LoopIntentKind.tryParse(value) ?? _invalid();
  }

  static LoopIntentAsset asset(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'assetId',
      'address',
      'symbol',
      'decimals',
    });
    return LoopIntentAsset(
      assetId: LoopV2ChainCodec.requireAssetId(map, 'assetId'),
      address: LoopV2ChainCodec.optionalString(
        map,
        'address',
        pattern: LoopV2ChainCodec.addressPattern,
        maxLength: 42,
      ),
      symbol: LoopV2ChainCodec.requireText(map, 'symbol', maxLength: 32),
      decimals: LoopV2ChainCodec.requireInt(map, 'decimals', maximum: 36),
    );
  }

  /// `{raw, display}`. `display` may be the literal `unlimited`, which is a
  /// meaning rather than a number and is therefore never parsed as one.
  static LoopIntentAmount amount(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{'raw', 'display'});
    final rawValue = LoopV2ChainCodec.requireRawAmount(map, 'raw');
    final display = map['display'];
    if (display is! String || display.isEmpty || display.length > 160) {
      _invalid();
    }
    if (display == LoopIntentAmount.unlimitedDisplay) {
      return LoopIntentAmount(raw: rawValue, display: display, value: null);
    }
    if (!LoopV2ChainCodec.unsignedDecimalPattern.hasMatch(display)) _invalid();
    final parsed = Decimal.tryParse(display);
    if (parsed == null) _invalid();
    return LoopIntentAmount(raw: rawValue, display: display, value: parsed);
  }

  static LoopUnavailable _unavailableBlock(Object? raw) =>
      LoopV2ChainCodec.unavailable(raw);

  static LoopIntentRecipient recipient(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'address',
      'checksumAddress',
      'isContract',
      'isFirstRecipient',
      'basis',
      'screening',
    });
    final basis = map['basis'];
    if (basis != 'indexed_erc20_transfers') _invalid();
    return LoopIntentRecipient(
      address: _address(map, 'address'),
      checksumAddress: _checksumAddress(map, 'checksumAddress'),
      isContract: LoopV2ChainCodec.requireBool(map, 'isContract'),
      isFirstRecipient: LoopV2ChainCodec.requireBool(map, 'isFirstRecipient'),
      basis: basis! as String,
      screening: _unavailableBlock(map['screening']),
    );
  }

  static LoopIntentSpender? _spender(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'address',
      'checksumAddress',
      'isContract',
      'isUnlimited',
    });
    return LoopIntentSpender(
      address: _address(map, 'address'),
      checksumAddress: _checksumAddress(map, 'checksumAddress'),
      isContract: LoopV2ChainCodec.requireBool(map, 'isContract'),
      isUnlimited: LoopV2ChainCodec.requireBool(map, 'isUnlimited'),
    );
  }

  static LoopDecodedCall? _decodedCall(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'functionName',
      'selector',
      'args',
    });
    final functionName = map['functionName'];
    if (functionName is! String) _invalid();
    final parsed = LoopDecodedFunction.tryParse(functionName);
    if (parsed == null) _invalid();
    final rawArgs = map['args'];
    if (rawArgs is! Map || rawArgs.length > 4) _invalid();
    final args = <String, String>{};
    for (final entry in rawArgs.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String ||
          key.isEmpty ||
          key.length > 64 ||
          value is! String ||
          value.length > 128 ||
          args.containsKey(key)) {
        _invalid();
      }
      args[key] = value;
    }
    return LoopDecodedCall(
      functionName: parsed,
      selector: LoopV2ChainCodec.requireString(
        map,
        'selector',
        pattern: selectorPattern,
        maxLength: 10,
      ),
      args: args,
    );
  }

  static LoopIntentFee? _fee(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'gasLimit',
      'type',
      'maxFeePerGas',
      'maxPriorityFeePerGas',
      'gasPrice',
      'maximumFeeRaw',
      'maximumFee',
      'observedAt',
    });
    final type = map['type'];
    if (type != 'eip1559' && type != 'legacy') _invalid();
    return LoopIntentFee(
      gasLimit: LoopV2ChainCodec.requireRawAmount(map, 'gasLimit'),
      type: type! as String,
      maxFeePerGas: _optionalRawAmount(map, 'maxFeePerGas'),
      maxPriorityFeePerGas: _optionalRawAmount(map, 'maxPriorityFeePerGas'),
      gasPrice: _optionalRawAmount(map, 'gasPrice'),
      maximumFeeRaw: LoopV2ChainCodec.requireRawAmount(map, 'maximumFeeRaw'),
      maximumFee: LoopV2ChainCodec.requireDecimal(map, 'maximumFee'),
      observedAt: LoopV2ChainCodec.requireTimestamp(map, 'observedAt'),
    );
  }

  static LoopIntentBalance _balance(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'blockNumber',
      'blockHash',
      'observedAt',
      'rawBalance',
      'displayBalance',
      'rawNativeBalance',
      'gasReserveRaw',
    });
    return LoopIntentBalance(
      blockNumber: LoopV2ChainCodec.requireBlockNumber(map, 'blockNumber'),
      blockHash: _hash(map, 'blockHash'),
      observedAt: LoopV2ChainCodec.requireTimestamp(map, 'observedAt'),
      rawBalance: LoopV2ChainCodec.requireRawAmount(map, 'rawBalance'),
      displayBalance: LoopV2ChainCodec.requireDecimal(map, 'displayBalance'),
      rawNativeBalance: LoopV2ChainCodec.requireRawAmount(
        map,
        'rawNativeBalance',
      ),
      gasReserveRaw: LoopV2ChainCodec.requireRawAmount(map, 'gasReserveRaw'),
    );
  }

  static LoopSwapPriceImpact _priceImpact(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'value',
      'decision',
      'reasonCode',
      'marketValueUsd',
      'estimatedOutputValueUsd',
      'priceSource',
    });
    final status = map['status'];
    if (status != 'available' && status != 'unavailable') _invalid();
    final decision = map['decision'];
    if (decision is! String) _invalid();
    final parsedDecision = LoopPriceImpactDecision.tryParse(decision);
    if (parsedDecision == null) _invalid();
    final available = status == 'available';
    final value = LoopV2ChainCodec.optionalDecimal(map, 'value', signed: true);
    // An available impact must carry a figure; an unavailable one must not.
    if (available != (value != null)) _invalid();
    return LoopSwapPriceImpact(
      available: available,
      value: value,
      decision: parsedDecision,
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
      marketValueUsd: LoopV2ChainCodec.optionalDecimal(map, 'marketValueUsd'),
      estimatedOutputValueUsd: LoopV2ChainCodec.optionalDecimal(
        map,
        'estimatedOutputValueUsd',
      ),
      priceSource: LoopV2ChainCodec.optionalString(
        map,
        'priceSource',
        pattern: LoopV2ChainCodec.displayTextPattern,
        maxLength: 64,
      ),
    );
  }

  static LoopSwapPolicy swapPolicy(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'configVersion',
      'status',
      'defaultSlippageBps',
      'maximumSlippageBps',
      'hardBlockPriceImpact',
      'confirmPriceImpact',
      'quoteTtlSeconds',
    });
    return LoopSwapPolicy(
      configVersion: LoopV2ChainCodec.requireText(
        map,
        'configVersion',
        maxLength: 64,
      ),
      status: LoopV2ChainCodec.requireText(map, 'status', maxLength: 64),
      defaultSlippageBps: LoopV2ChainCodec.requireInt(
        map,
        'defaultSlippageBps',
        minimum: 1,
        maximum: 10000,
      ),
      maximumSlippageBps: LoopV2ChainCodec.requireInt(
        map,
        'maximumSlippageBps',
        minimum: 1,
        maximum: 10000,
      ),
      hardBlockPriceImpact: LoopV2ChainCodec.requireDecimal(
        map,
        'hardBlockPriceImpact',
      ),
      confirmPriceImpact: LoopV2ChainCodec.requireDecimal(
        map,
        'confirmPriceImpact',
      ),
      quoteTtlSeconds: LoopV2ChainCodec.requireInt(
        map,
        'quoteTtlSeconds',
        minimum: 1,
        maximum: 600,
      ),
    );
  }

  static LoopSwapQuote quote(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'quoteId',
      'provider',
      'amountType',
      'inputAmount',
      'estimatedOutputAmount',
      'minimumOutputAmount',
      'slippageBps',
      'gasEstimateRaw',
      'quotedAt',
      'expiresAt',
      'priceImpact',
      'platformFeeBps',
    });
    if (map['provider'] != 'privy') _invalid();
    if (map['amountType'] != 'exact_input') _invalid();
    return LoopSwapQuote(
      quoteId: LoopV2ChainCodec.requireString(
        map,
        'quoteId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      provider: 'privy',
      amountType: 'exact_input',
      inputAmount: amount(map['inputAmount']),
      estimatedOutputAmount: amount(map['estimatedOutputAmount']),
      minimumOutputAmount: amount(map['minimumOutputAmount']),
      slippageBps: LoopV2ChainCodec.requireInt(
        map,
        'slippageBps',
        minimum: 1,
        maximum: 300,
      ),
      gasEstimateRaw: LoopV2ChainCodec.requireRawAmount(map, 'gasEstimateRaw'),
      quotedAt: LoopV2ChainCodec.requireTimestamp(map, 'quotedAt'),
      expiresAt: LoopV2ChainCodec.requireTimestamp(map, 'expiresAt'),
      priceImpact: _priceImpact(map['priceImpact']),
      platformFeeBps: LoopV2ChainCodec.optionalInt(
        map,
        'platformFeeBps',
        minimum: 1,
      ),
    );
  }

  static LoopIntentSwap? _swap(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'destinationAsset',
      'quote',
      'policy',
    });
    return LoopIntentSwap(
      destinationAsset: asset(map['destinationAsset']),
      quote: quote(map['quote']),
      policy: swapPolicy(map['policy']),
    );
  }

  static LoopIntentReview _review(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'kind',
      'asset',
      'amount',
      'recipient',
      'spender',
      'decodedCall',
      'fee',
      'balance',
      'swap',
    });
    return LoopIntentReview(
      kind: _kind(map, 'kind'),
      asset: asset(map['asset']),
      amount: amount(map['amount']),
      recipient: map['recipient'] == null ? null : recipient(map['recipient']),
      spender: _spender(map['spender']),
      decodedCall: _decodedCall(map['decodedCall']),
      fee: _fee(map['fee']),
      balance: _balance(map['balance']),
      swap: _swap(map['swap']),
    );
  }

  static LoopIntentSimulation _simulation(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'source',
      'observedAt',
      'reasonCode',
    });
    final status = map['status'];
    final source = map['source'];
    if (status is! String || source is! String) _invalid();
    final parsedStatus = LoopSimulationStatus.tryParse(status);
    final parsedSource = LoopSimulationSource.tryParse(source);
    if (parsedStatus == null || parsedSource == null) _invalid();
    return LoopIntentSimulation(
      status: parsedStatus,
      source: parsedSource,
      observedAt: LoopV2ChainCodec.requireTimestamp(map, 'observedAt'),
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
    );
  }

  static LoopIntentPolicy _policy(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'configVersion',
      'canaryMaxUsd',
      'exposureBasis',
      'exposureRaw',
      'exposureBlockNumber',
      'valueUsd',
      'priceSource',
      'priceFetchedAt',
    });
    final basis = map['exposureBasis'];
    if (basis is! String) _invalid();
    final parsedBasis = LoopExposureBasis.tryParse(basis);
    if (parsedBasis == null) _invalid();
    return LoopIntentPolicy(
      configVersion: LoopV2ChainCodec.requireText(
        map,
        'configVersion',
        maxLength: 64,
      ),
      canaryMaxUsd: LoopV2ChainCodec.requireDecimal(map, 'canaryMaxUsd'),
      exposureBasis: parsedBasis,
      exposureRaw: _optionalRawAmount(map, 'exposureRaw'),
      exposureBlockNumber: LoopV2ChainCodec.optionalBlockNumber(
        map,
        'exposureBlockNumber',
      ),
      valueUsd: LoopV2ChainCodec.optionalDecimal(map, 'valueUsd'),
      priceSource: LoopV2ChainCodec.optionalString(
        map,
        'priceSource',
        pattern: LoopV2ChainCodec.displayTextPattern,
        maxLength: 64,
      ),
      priceFetchedAt: LoopV2ChainCodec.optionalTimestamp(map, 'priceFetchedAt'),
    );
  }

  static LoopIntentSigning _signing(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'mode',
      'allowed',
      'reasonCode',
    });
    final mode = map['mode'];
    if (mode is! String) _invalid();
    final parsed = LoopSigningMode.tryParse(mode);
    if (parsed == null) _invalid();
    return LoopIntentSigning(
      mode: parsed,
      allowed: LoopV2ChainCodec.requireBool(map, 'allowed'),
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
    );
  }

  /// The primary chain id, and nothing else (decision 0038).
  static String _primaryChainId(Map<String, Object?> source, String key) {
    if (source[key] != loopPrimaryChainId) _invalid();
    return loopPrimaryChainId;
  }

  /// The primary chain's numeric EIP-155 reference, and nothing else.
  static int _primaryChainReference(Map<String, Object?> source, String key) {
    final reference = loopChainReference(loopPrimaryChainId);
    if (source[key] != reference) _invalid();
    return reference;
  }

  static LoopUnsignedTransaction? _unsignedTransaction(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'chainId',
      'from',
      'to',
      'data',
      'value',
      'gas',
      'nonce',
      'type',
      'maxFeePerGas',
      'maxPriorityFeePerGas',
      'gasPrice',
    });
    final type = map['type'];
    if (type != 'eip1559' && type != 'legacy') _invalid();
    return LoopUnsignedTransaction(
      // The signable payload's own chain must be the primary chain too: the
      // owner reviewed a BNB Smart Chain transaction, not a testnet one.
      chainId: _primaryChainReference(map, 'chainId'),
      from: _address(map, 'from'),
      to: _address(map, 'to'),
      data: LoopV2ChainCodec.requireString(
        map,
        'data',
        pattern: callDataPattern,
        minLength: 2,
        maxLength: 8192,
      ),
      value: _quantity(map, 'value'),
      gas: _quantity(map, 'gas'),
      nonce: _quantity(map, 'nonce'),
      type: type! as String,
      maxFeePerGas: _optionalQuantity(map, 'maxFeePerGas'),
      maxPriorityFeePerGas: _optionalQuantity(map, 'maxPriorityFeePerGas'),
      gasPrice: _optionalQuantity(map, 'gasPrice'),
    );
  }

  /// The Privy authorization payload. The optional `fee_configuration` is the
  /// only key that may be absent, so the body is validated against both shapes
  /// and then rebuilt verbatim — the device signs exactly what the server sent.
  static LoopAuthorizationPayload? _authorizationPayload(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'version',
      'method',
      'url',
      'body',
      'headers',
    });
    if (map['version'] != 1) _invalid();
    if (map['method'] != 'POST') _invalid();
    final rawBody = map['body'];
    if (rawBody is! Map) _invalid();
    final hasFee = rawBody.containsKey('fee_configuration');
    final body = LoopV2Contract.strictMap(rawBody, <String>{
      'base_amount',
      'source',
      'destination',
      'amount_type',
      'slippage_bps',
      if (hasFee) 'fee_configuration',
    });
    if (body['amount_type'] != 'exact_input') _invalid();
    final baseAmount = LoopV2ChainCodec.requireRawAmount(body, 'base_amount');
    final slippageBps = LoopV2ChainCodec.requireInt(
      body,
      'slippage_bps',
      minimum: 1,
      maximum: 300,
    );
    final source = _swapEndpoint(body['source']);
    final destination = _swapEndpoint(body['destination']);
    Map<String, Object?>? feeConfiguration;
    if (hasFee) {
      final fee = LoopV2Contract.strictMap(
        body['fee_configuration'],
        const <String>{'type', 'value'},
      );
      if (fee['type'] != 'total_fee_bps') _invalid();
      feeConfiguration = <String, Object?>{
        'type': 'total_fee_bps',
        'value': LoopV2ChainCodec.requireInt(
          fee,
          'value',
          minimum: 1,
          maximum: 1000,
        ),
      };
    }
    final headers = LoopV2Contract.strictMap(map['headers'], const <String>{
      'privy-app-id',
      'privy-idempotency-key',
      'privy-request-expiry',
    });
    return LoopAuthorizationPayload(
      version: 1,
      method: 'POST',
      url: LoopV2ChainCodec.requireString(
        map,
        'url',
        pattern: httpsUrlPattern,
        maxLength: 512,
      ),
      body: <String, Object?>{
        'base_amount': baseAmount,
        'source': source,
        'destination': destination,
        'amount_type': 'exact_input',
        'slippage_bps': slippageBps,
        'fee_configuration': ?feeConfiguration,
      },
      headers: <String, String>{
        'privy-app-id': LoopV2ChainCodec.requireString(
          headers,
          'privy-app-id',
          pattern: privyAppIdPattern,
          maxLength: 64,
        ),
        'privy-idempotency-key': LoopV2ChainCodec.requireString(
          headers,
          'privy-idempotency-key',
          pattern: LoopV2Contract.uuidV4Pattern,
          maxLength: 36,
        ),
        'privy-request-expiry': LoopV2ChainCodec.requireString(
          headers,
          'privy-request-expiry',
          pattern: expiryPattern,
          maxLength: 16,
        ),
      },
    );
  }

  static Map<String, Object?> _swapEndpoint(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'asset_address',
      'caip2',
    });
    final address = map['asset_address'];
    if (address != 'native' &&
        (address is! String ||
            !LoopV2ChainCodec.addressPattern.hasMatch(address))) {
      _invalid();
    }
    return <String, Object?>{
      'asset_address': address,
      'caip2': LoopV2ChainCodec.requireString(
        map,
        'caip2',
        pattern: LoopV2ChainCodec.chainIdPattern,
        maxLength: 32,
      ),
    };
  }

  static LoopIntentReceipt? _receipt(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'blockNumber',
      'blockHash',
      'gasUsed',
      'effectiveGasPrice',
      'confirmations',
      'observedAt',
    });
    final status = map['status'];
    if (status is! String) _invalid();
    final parsed = LoopReceiptStatus.tryParse(status);
    if (parsed == null) _invalid();
    return LoopIntentReceipt(
      status: parsed,
      blockNumber: LoopV2ChainCodec.requireBlockNumber(map, 'blockNumber'),
      blockHash: _hash(map, 'blockHash'),
      gasUsed: LoopV2ChainCodec.requireRawAmount(map, 'gasUsed'),
      effectiveGasPrice: LoopV2ChainCodec.requireRawAmount(
        map,
        'effectiveGasPrice',
      ),
      confirmations: LoopV2ChainCodec.optionalInt(
        map,
        'confirmations',
        minimum: 0,
      ),
      observedAt: LoopV2ChainCodec.requireTimestamp(map, 'observedAt'),
    );
  }

  static LoopIntentResult _result(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'transactionHash',
      'providerActionId',
      'reasonCode',
      'receipt',
    });
    return LoopIntentResult(
      transactionHash: LoopV2ChainCodec.optionalString(
        map,
        'transactionHash',
        pattern: LoopV2ChainCodec.hashPattern,
        maxLength: 66,
      ),
      providerActionId: LoopV2ChainCodec.optionalString(
        map,
        'providerActionId',
        pattern: providerActionIdPattern,
        maxLength: 128,
      ),
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
      receipt: _receipt(map['receipt']),
    );
  }

  /// One intent resource. Every prepare, report, execute, cancel and read
  /// answers with exactly this object.
  static LoopWalletIntent intent(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'intentId',
      'kind',
      'state',
      'walletId',
      'chainId',
      'review',
      'reviewSha256',
      'factsObservedAt',
      'expiresAt',
      'simulation',
      'policy',
      'signing',
      'unsignedTransaction',
      'authorizationPayload',
      'result',
      'version',
      'createdAt',
      'updatedAt',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(map);
    final state = map['state'];
    if (state is! String) _invalid();
    final parsedState = LoopIntentState.tryParse(state);
    if (parsedState == null) _invalid();
    final kind = _kind(map, 'kind');
    final review = _review(map['review']);
    // The review's own kind is part of the canonical payload: a mismatch means
    // the two halves do not describe the same operation.
    if (review.kind != kind) _invalid();
    return LoopWalletIntent(
      intentId: LoopV2ChainCodec.requireString(
        map,
        'intentId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      kind: kind,
      state: parsedState,
      walletId: LoopV2ChainCodec.requireString(
        map,
        'walletId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      // Decision 0038: send, approve, revoke and swap are locked to the
      // primary chain. Only a Launch intent may ever carry another slot, and
      // this module never produces one, so anything else is an invalid
      // payload rather than a wallet action on an unreviewed chain.
      chainId: _primaryChainId(map, 'chainId'),
      review: review,
      reviewSha256: LoopV2ChainCodec.requireString(
        map,
        'reviewSha256',
        pattern: sha256Pattern,
        maxLength: 64,
      ),
      factsObservedAt: LoopV2ChainCodec.requireTimestamp(
        map,
        'factsObservedAt',
      ),
      expiresAt: LoopV2ChainCodec.requireTimestamp(map, 'expiresAt'),
      simulation: _simulation(map['simulation']),
      policy: _policy(map['policy']),
      signing: _signing(map['signing']),
      unsignedTransaction: _unsignedTransaction(map['unsignedTransaction']),
      authorizationPayload: _authorizationPayload(map['authorizationPayload']),
      result: _result(map['result']),
      version: LoopV2ChainCodec.requireString(
        map,
        'version',
        pattern: versionPattern,
        maxLength: 19,
      ),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
      updatedAt: LoopV2ChainCodec.requireTimestamp(map, 'updatedAt'),
    );
  }

  static LoopWalletIntentPage intentPage(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'items',
      'nextCursor',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(map);
    return LoopWalletIntentPage(
      items: <LoopWalletIntent>[
        for (final item in LoopV2ChainCodec.requireList(
          map['items'],
          maximum: 50,
        ))
          intent(item),
      ],
      nextCursor: LoopV2ChainCodec.cursor(map, 'nextCursor'),
    );
  }

  static LoopSendPreflight preflight(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'walletId',
      'chainId',
      'recipient',
      'basis',
      'warnings',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(map);
    if (map['basis'] != 'indexed_erc20_transfers') _invalid();
    final warnings = <String>[];
    for (final value in LoopV2ChainCodec.requireList(
      map['warnings'],
      maximum: 8,
    )) {
      if (value is! String ||
          value.length > 64 ||
          !warningPattern.hasMatch(value) ||
          warnings.contains(value)) {
        _invalid();
      }
      warnings.add(value);
    }
    return LoopSendPreflight(
      walletId: LoopV2ChainCodec.requireString(
        map,
        'walletId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      chainId: LoopV2ChainCodec.requireString(
        map,
        'chainId',
        pattern: LoopV2ChainCodec.chainIdPattern,
        maxLength: 32,
      ),
      recipient: recipient(map['recipient']),
      basis: 'indexed_erc20_transfers',
      warnings: warnings,
    );
  }

  static LoopSwapQuoteView quoteView(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'walletId',
      'sourceAsset',
      'destinationAsset',
      'quote',
      'policy',
      'canary',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(map);
    final canary = LoopV2Contract.strictMap(map['canary'], const <String>{
      'configVersion',
      'canaryMaxUsd',
      'inputValueUsd',
    });
    return LoopSwapQuoteView(
      walletId: LoopV2ChainCodec.requireString(
        map,
        'walletId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      sourceAsset: asset(map['sourceAsset']),
      destinationAsset: asset(map['destinationAsset']),
      quote: quote(map['quote']),
      policy: swapPolicy(map['policy']),
      canary: LoopSwapCanary(
        configVersion: LoopV2ChainCodec.requireText(
          canary,
          'configVersion',
          maxLength: 64,
        ),
        canaryMaxUsd: LoopV2ChainCodec.requireDecimal(canary, 'canaryMaxUsd'),
        inputValueUsd: LoopV2ChainCodec.requireDecimal(canary, 'inputValueUsd'),
      ),
    );
  }

  static LoopAllowance _allowance(Object? raw) {
    if (raw is! Map) _invalid();
    if (raw['status'] == 'unavailable') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'reasonCode',
      });
      return LoopAllowanceUnavailable(
        LoopV2ChainCodec.requireReasonCode(map, 'reasonCode'),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'rawValue',
      'displayValue',
      'isUnlimited',
      'blockNumber',
      'blockHash',
      'observedAt',
    });
    if (map['status'] != 'available') _invalid();
    final display = map['displayValue'];
    if (display is! String || display.isEmpty || display.length > 160) {
      _invalid();
    }
    final unlimited = LoopV2ChainCodec.requireBool(map, 'isUnlimited');
    Decimal? value;
    if (display == LoopIntentAmount.unlimitedDisplay) {
      if (!unlimited) _invalid();
    } else {
      if (unlimited) _invalid();
      if (!LoopV2ChainCodec.unsignedDecimalPattern.hasMatch(display)) {
        _invalid();
      }
      value = Decimal.tryParse(display);
      if (value == null) _invalid();
    }
    return LoopAllowanceAvailable(
      rawValue: LoopV2ChainCodec.requireRawAmount(map, 'rawValue'),
      displayValue: display,
      value: value,
      isUnlimited: unlimited,
      blockNumber: LoopV2ChainCodec.requireBlockNumber(map, 'blockNumber'),
      blockHash: _hash(map, 'blockHash'),
      observedAt: LoopV2ChainCodec.requireTimestamp(map, 'observedAt'),
    );
  }

  static LoopApprovalRow approvalRow(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'assetId',
      'symbol',
      'decimals',
      'spender',
      'allowance',
      'lastApproval',
      'riskFacts',
    });
    final spender = LoopV2Contract.strictMap(map['spender'], const <String>{
      'address',
      'checksumAddress',
    });
    final lastApprovalRaw = map['lastApproval'];
    LoopApprovalEvent? lastApproval;
    if (lastApprovalRaw != null) {
      final event = LoopV2Contract.strictMap(lastApprovalRaw, const <String>{
        'transactionHash',
        'blockNumber',
        'rawValue',
        'observedAt',
      });
      lastApproval = LoopApprovalEvent(
        transactionHash: _hash(event, 'transactionHash'),
        blockNumber: LoopV2ChainCodec.requireBlockNumber(event, 'blockNumber'),
        rawValue: LoopV2ChainCodec.requireRawAmount(event, 'rawValue'),
        observedAt: LoopV2ChainCodec.requireTimestamp(event, 'observedAt'),
      );
    }
    return LoopApprovalRow(
      assetId: LoopV2ChainCodec.requireAssetId(map, 'assetId'),
      symbol: LoopV2ChainCodec.requireText(map, 'symbol', maxLength: 32),
      decimals: LoopV2ChainCodec.requireInt(map, 'decimals', maximum: 36),
      spender: LoopApprovalSpender(
        address: _address(spender, 'address'),
        checksumAddress: _checksumAddress(spender, 'checksumAddress'),
      ),
      allowance: _allowance(map['allowance']),
      lastApproval: lastApproval,
      riskFacts: _unavailableBlock(map['riskFacts']),
    );
  }

  static LoopApprovalInventory approvals(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'walletId',
      'items',
      'summary',
      'freshness',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(map);
    final summary = LoopV2Contract.strictMap(map['summary'], const <String>{
      'activeCount',
      'unlimitedCount',
    });
    final freshness = LoopV2Contract.strictMap(map['freshness'], const <String>{
      'indexerBlockNumber',
      'approvalCoverageFromBlockNumber',
      'headBlockNumber',
      'observedAt',
    });
    return LoopApprovalInventory(
      walletId: LoopV2ChainCodec.requireString(
        map,
        'walletId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      items: <LoopApprovalRow>[
        for (final item in LoopV2ChainCodec.requireList(
          map['items'],
          maximum: 500,
        ))
          approvalRow(item),
      ],
      summary: LoopApprovalSummary(
        activeCount: LoopV2ChainCodec.requireInt(summary, 'activeCount'),
        unlimitedCount: LoopV2ChainCodec.requireInt(summary, 'unlimitedCount'),
      ),
      freshness: LoopApprovalFreshness(
        indexerBlockNumber: LoopV2ChainCodec.requireBlockNumber(
          freshness,
          'indexerBlockNumber',
        ),
        approvalCoverageFromBlockNumber: LoopV2ChainCodec.requireBlockNumber(
          freshness,
          'approvalCoverageFromBlockNumber',
        ),
        headBlockNumber: LoopV2ChainCodec.requireBlockNumber(
          freshness,
          'headBlockNumber',
        ),
        observedAt: LoopV2ChainCodec.requireTimestamp(freshness, 'observedAt'),
      ),
    );
  }

  static LoopApprovalRow approvalDetail(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'walletId',
      'item',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(map);
    return approvalRow(map['item']);
  }
}
