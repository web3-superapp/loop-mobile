import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict codecs for the MEME v2 project side (S135, client decision 0138).
///
/// Sources: loop-api `docs/frontend-v2-hooks-launch-api.md` (§2–§6, §9) and
/// OpenAPI `getV2HooksLaunchProjectConfig`, `saveV2HooksLaunchProjectConfig`,
/// `getV2HooksLaunchSigningRequest`, `submitV2HooksLaunchDeployment`,
/// `getV2HooksLaunchDeployment` and `listV2Launch2Instances`. Every object is
/// read with its exact key set; an unknown or missing key is an invalid
/// payload, never a default.
abstract final class LoopV2Launch2CreatorCodec {
  static Never invalid() => LoopV2ChainCodec.invalid();

  static final RegExp _uuid = LoopV2Contract.uuidPattern;
  static final RegExp _address = RegExp(r'^0x[0-9a-f]{40}$');
  static final RegExp _addressAnyCase = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final RegExp _bytes32 = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp _bytes32AnyCase = RegExp(r'^0x[0-9a-fA-F]{64}$');
  static final RegExp _uint64 = RegExp(r'^(0|[1-9][0-9]{0,19})$');
  static final RegExp _uint = RegExp(r'^(0|[1-9][0-9]{0,77})$');
  static final RegExp _ticker = RegExp(r'^[A-Z0-9]{2,12}$');
  static final RegExp _code = RegExp(r'^[A-Z0-9_]{1,64}$');
  static final RegExp _kind = RegExp(r'^[a-z_]{1,40}$');
  static final RegExp _decimal = RegExp(
    r'^(0|[1-9][0-9]{0,40})(\.[0-9]{1,18})?$',
  );
  static final RegExp _anything = RegExp(r'^[\s\S]*$');

  static const String templateVersion = 'hooks_launch_v1';

  // -- hooks-config ---------------------------------------------------------

  static const Set<String> draftKeys = <String>{
    'projectId',
    'version',
    'templateVersion',
    'config',
    'updatedAt',
  };

  static const Set<String> configKeys = <String>{
    'templateVersion',
    'templateHash',
    'name',
    'ticker',
    'logoAssetUrl',
    'description',
    'links',
    'nftSaleStartAt',
    'buybackRecipient',
    'fixedEconomics',
    'configHash',
  };

  static const Set<String> economicsKeys = <String>{
    'chainId',
    'memeTotalSupplyRaw',
    'curveSaleSupplyRaw',
    'initialLiquiditySupplyRaw',
    'graduationReserveUsd1Raw',
    'nftPriceUsd1Raw',
    'nftSaleDurationSeconds',
    'earlyRoundDurationSeconds',
    'perAddressLifetimeBuyCapRaw',
    'curveBuyTaxBps',
    'curveSellTaxBps',
    'officialPoolBuyTaxBps',
    'officialPoolSellTaxBps',
    'lpFee',
    'tickSpacing',
    'buybackOrderUsd1Raw',
    'buybackMinIntervalSeconds',
  };

  /// `GET …/hooks-config` (loop-api decision 0120): `draft`, `approval`,
  /// `latestDeployment` and `minSaleLeadSeconds` are all required keys;
  /// `approval` and `latestDeployment` may be `null`. Without a draft there is
  /// no approval; an approval always names the draft's own version.
  static Launch2HooksConfig configEnvelope(
    Object? raw, {
    required String projectId,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'draft',
      'approval',
      'latestDeployment',
      'minSaleLeadSeconds',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final draftRaw = root['draft'];
    final parsed = draftRaw == null
        ? null
        : draft(draftRaw, projectId: projectId);
    final approvalRaw = root['approval'];
    Launch2HooksApproval? approval;
    if (approvalRaw != null) {
      if (parsed == null) invalid();
      final map = LoopV2Contract.strictMap(approvalRaw, const <String>{
        'configVersion',
        'status',
        'approvedAt',
      });
      final version = LoopV2ChainCodec.requireInt(
        map,
        'configVersion',
        minimum: 1,
        maximum: 2147483647,
      );
      if (version != parsed.version) invalid();
      final status = Launch2ApprovalStatus.tryParse(map['status']);
      if (status == null) invalid();
      final approvedAt = LoopV2ChainCodec.optionalTimestamp(map, 'approvedAt');
      // Approved and its time arrive together.
      if ((status == Launch2ApprovalStatus.approved) != (approvedAt != null)) {
        invalid();
      }
      approval = Launch2HooksApproval(
        configVersion: version,
        status: status,
        approvedAt: approvedAt,
      );
    } else if (parsed != null) {
      // A draft always has an approval state, even if only awaiting.
      invalid();
    }
    final jobRaw = root['latestDeployment'];
    final lead = LoopV2ChainCodec.requireInt(
      root,
      'minSaleLeadSeconds',
      minimum: 4200,
      maximum: 2592000,
    );
    return Launch2HooksConfig(
      draft: parsed,
      approval: approval,
      latestDeployment: jobRaw == null
          ? null
          : job(jobRaw, projectId: projectId),
      minSaleLead: Duration(seconds: lead),
    );
  }

  /// One draft (`PUT` answers it bare).
  static Launch2HooksDraft draft(Object? raw, {required String projectId}) {
    final map = LoopV2Contract.strictMap(raw, draftKeys);
    final id = LoopV2ChainCodec.requireString(map, 'projectId', pattern: _uuid);
    if (id != projectId) invalid();
    final version = LoopV2ChainCodec.requireInt(map, 'version', minimum: 1);
    if (map['templateVersion'] != templateVersion) invalid();
    final config = LoopV2Contract.strictMap(map['config'], configKeys);
    if (config['templateVersion'] != templateVersion) invalid();
    final linksRaw = LoopV2ChainCodec.requireList(config['links'], maximum: 8);
    final links = <String>[for (final link in linksRaw) _httpsUrl(link)];
    final description = config['description'];
    if (description is! String || description.length > 2000) invalid();
    return Launch2HooksDraft(
      projectId: id,
      version: version,
      templateVersion: templateVersion,
      templateHash: LoopV2ChainCodec.requireString(
        config,
        'templateHash',
        pattern: _bytes32,
      ),
      name: LoopV2ChainCodec.requireString(
        config,
        'name',
        pattern: _anything,
        maxLength: 64,
      ),
      ticker: LoopV2ChainCodec.requireString(
        config,
        'ticker',
        pattern: _ticker,
      ),
      logoAssetUrl: _httpsUrl(config['logoAssetUrl']),
      description: description,
      links: List<String>.unmodifiable(links),
      nftSaleStartAt: BigInt.parse(
        LoopV2ChainCodec.requireString(
          config,
          'nftSaleStartAt',
          pattern: _uint64,
        ),
      ),
      buybackRecipient: LoopV2ChainCodec.requireString(
        config,
        'buybackRecipient',
        pattern: _address,
      ),
      economics: economics(config['fixedEconomics']),
      configHash: LoopV2ChainCodec.requireString(
        config,
        'configHash',
        pattern: _bytes32,
      ),
      updatedAt: LoopV2ChainCodec.requireTimestamp(map, 'updatedAt'),
    );
  }

  static Launch2FixedEconomics economics(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, economicsKeys);
    BigInt amount(String key) =>
        BigInt.parse(LoopV2ChainCodec.requireString(map, key, pattern: _uint));
    int bps(String key) =>
        LoopV2ChainCodec.requireInt(map, key, maximum: 10000);
    return Launch2FixedEconomics(
      templateChainId: LoopV2ChainCodec.requireString(
        map,
        'chainId',
        pattern: RegExp(r'^[1-9][0-9]{0,9}$'),
      ),
      memeTotalSupplyRaw: amount('memeTotalSupplyRaw'),
      curveSaleSupplyRaw: amount('curveSaleSupplyRaw'),
      initialLiquiditySupplyRaw: amount('initialLiquiditySupplyRaw'),
      graduationReserveUsd1Raw: amount('graduationReserveUsd1Raw'),
      nftPriceUsd1Raw: amount('nftPriceUsd1Raw'),
      nftSaleDurationSeconds: LoopV2ChainCodec.requireInt(
        map,
        'nftSaleDurationSeconds',
      ),
      earlyRoundDurationSeconds: LoopV2ChainCodec.requireInt(
        map,
        'earlyRoundDurationSeconds',
      ),
      perAddressLifetimeBuyCapRaw: amount('perAddressLifetimeBuyCapRaw'),
      curveBuyTaxBps: bps('curveBuyTaxBps'),
      curveSellTaxBps: bps('curveSellTaxBps'),
      officialPoolBuyTaxBps: bps('officialPoolBuyTaxBps'),
      officialPoolSellTaxBps: bps('officialPoolSellTaxBps'),
      lpFee: LoopV2ChainCodec.requireInt(map, 'lpFee', maximum: 1000000),
      tickSpacing: LoopV2ChainCodec.requireInt(
        map,
        'tickSpacing',
        minimum: 1,
        maximum: 32767,
      ),
      buybackOrderUsd1Raw: amount('buybackOrderUsd1Raw'),
      buybackMinIntervalSeconds: LoopV2ChainCodec.requireInt(
        map,
        'buybackMinIntervalSeconds',
      ),
    );
  }

  static String _httpsUrl(Object? value) {
    if (value is! String || value.length > 2048) invalid();
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) invalid();
    return value;
  }

  /// The `PUT` body. Only the seven owner fields: the server rejects any
  /// economic key (§3).
  static Map<String, Object?> configBody({
    required int expectedVersion,
    required Launch2ConfigInput input,
  }) => <String, Object?>{
    'expectedVersion': expectedVersion,
    'config': <String, Object?>{
      'name': input.name,
      'ticker': input.ticker,
      'logoAssetUrl': input.logoAssetUrl,
      'description': input.description,
      'links': input.links,
      'nftSaleStartAt': input.nftSaleStartAt,
      'buybackRecipient': input.buybackRecipient,
    },
  };

  // -- signing-request ------------------------------------------------------

  static const Set<String> signingKeys = <String>{
    'request',
    'typedData',
    'hookDeployer',
    'hookInitCodeHash',
    'hookSalt',
    'hookAddress',
    'memeDeployer',
    'memeInitCodeHash',
    'memeAddress',
  };

  static const Set<String> requestKeys = <String>{
    'projectOwner',
    'configVersion',
    'configHash',
    'name',
    'ticker',
    'nftSaleStart',
    'buybackRecipient',
    'deadline',
    'memeSalt',
    'nonce',
  };

  /// The eleven `LaunchRequest` fields the Factory verifies.
  static const List<String> launchRequestFields = <String>[
    'configHash',
    'projectOwner',
    'configVersion',
    'name',
    'ticker',
    'nftSaleStart',
    'buybackRecipient',
    'deadline',
    'memeSalt',
    'nonce',
    'templateHash',
  ];

  /// `types.EIP712Domain`, field by field (loop-api decision 0120).
  static const List<(String, String)> eip712Domain = <(String, String)>[
    ('name', 'string'),
    ('version', 'string'),
    ('chainId', 'uint256'),
    ('verifyingContract', 'address'),
  ];

  static Launch2SigningRequest signingRequest(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, signingKeys);
    final requestRaw = LoopV2Contract.strictMap(root['request'], requestKeys);
    final request = Map<String, Object?>.unmodifiable(requestRaw);
    final projectOwner = LoopV2ChainCodec.requireString(
      request,
      'projectOwner',
      pattern: _address,
    );
    final configVersion = LoopV2ChainCodec.requireInt(
      request,
      'configVersion',
      minimum: 1,
      maximum: 4294967295,
    );
    final configHash = LoopV2ChainCodec.requireString(
      request,
      'configHash',
      pattern: _bytes32,
    );
    final name = LoopV2ChainCodec.requireString(
      request,
      'name',
      pattern: _anything,
      maxLength: 64,
    );
    final ticker = LoopV2ChainCodec.requireString(
      request,
      'ticker',
      pattern: _ticker,
    );
    final nftSaleStart = LoopV2ChainCodec.requireString(
      request,
      'nftSaleStart',
      pattern: _uint64,
    );
    final buybackRecipient = LoopV2ChainCodec.requireString(
      request,
      'buybackRecipient',
      pattern: _address,
    );
    final deadline = LoopV2ChainCodec.requireString(
      request,
      'deadline',
      pattern: _uint64,
    );
    LoopV2ChainCodec.requireString(request, 'memeSalt', pattern: _bytes32);
    final nonce = LoopV2ChainCodec.requireString(
      request,
      'nonce',
      pattern: _uint,
    );

    for (final key in const <String>[
      'hookDeployer',
      'hookAddress',
      'memeDeployer',
      'memeAddress',
    ]) {
      LoopV2ChainCodec.requireString(root, key, pattern: _address);
    }
    for (final key in const <String>[
      'hookInitCodeHash',
      'hookSalt',
      'memeInitCodeHash',
    ]) {
      LoopV2ChainCodec.requireString(root, key, pattern: _bytes32);
    }
    final memeAddress = root['memeAddress']! as String;
    // The vanity tail is part of what the Factory verifies (§5); a request
    // without it would be refused after signing.
    if (!memeAddress.endsWith('6666')) invalid();

    final typed = root['typedData'];
    if (typed is! Map) invalid();
    final typedData = <String, Object?>{};
    for (final entry in typed.entries) {
      final key = entry.key;
      if (key is! String) invalid();
      typedData[key] = entry.value;
    }
    final domain = LoopV2Contract.strictMap(typedData['domain'], const <String>{
      'name',
      'version',
      'chainId',
      'verifyingContract',
    });
    final domainChainId = domain['chainId'];
    if (domain['name'] is! String ||
        domain['version'] is! String ||
        domainChainId is! int ||
        domainChainId <= 0) {
      invalid();
    }
    final verifyingContract = domain['verifyingContract'];
    if (verifyingContract is! String ||
        !_addressAnyCase.hasMatch(verifyingContract)) {
      invalid();
    }
    if (typedData['primaryType'] != 'LaunchRequest') invalid();
    final types = typedData['types'];
    if (types is! Map) invalid();
    // Decision 0120: the standard domain type is listed explicitly so the
    // object can go to `eth_signTypedData_v4` as is. It must be exactly the
    // four fields of the domain, in EIP-712's order; anything else would
    // hash a different domain separator than the Factory's.
    if (types.length != 2 ||
        !types.containsKey('EIP712Domain') ||
        !types.containsKey('LaunchRequest')) {
      invalid();
    }
    final domainType = types['EIP712Domain'];
    if (domainType is! List || domainType.length != eip712Domain.length) {
      invalid();
    }
    for (var i = 0; i < eip712Domain.length; i += 1) {
      final field = domainType[i];
      if (field is! Map ||
          field.length != 2 ||
          field['name'] != eip712Domain[i].$1 ||
          field['type'] != eip712Domain[i].$2) {
        invalid();
      }
    }
    final fields = types['LaunchRequest'];
    if (fields is! List) invalid();
    final names = <String>[
      for (final field in fields)
        if (field is Map && field['name'] is String)
          field['name'] as String
        else
          '',
    ];
    if (names.length != launchRequestFields.length ||
        !launchRequestFields.every(names.contains)) {
      invalid();
    }
    final message = typedData['message'];
    if (message is! Map) invalid();
    if (message.length != launchRequestFields.length) invalid();
    // What the sheet shows is what the wallet signs: every request field the
    // message repeats must be the same value.
    for (final key in requestKeys) {
      if (!_sameValue(message[key], request[key])) invalid();
    }
    final templateHash = message['templateHash'];
    if (templateHash is! String || !_bytes32AnyCase.hasMatch(templateHash)) {
      invalid();
    }

    return Launch2SigningRequest(
      request: request,
      typedData: Map<String, Object?>.unmodifiable(typedData),
      projectOwner: projectOwner,
      configVersion: configVersion,
      configHash: configHash,
      name: name,
      ticker: ticker,
      nftSaleStart: BigInt.parse(nftSaleStart),
      buybackRecipient: buybackRecipient,
      deadline: BigInt.parse(deadline),
      nonce: nonce,
      domainChainId: domainChainId,
      verifyingContract: verifyingContract.toLowerCase(),
      hookSalt: root['hookSalt']! as String,
      hookAddress: root['hookAddress']! as String,
      memeAddress: memeAddress,
    );
  }

  static bool _sameValue(Object? message, Object? request) {
    if (message is String && request is String) {
      if (message.startsWith('0x') && request.startsWith('0x')) {
        return message.toLowerCase() == request.toLowerCase();
      }
      return message == request;
    }
    if (request is int) {
      return message == request || (message is String && message == '$request');
    }
    return false;
  }

  /// The `POST …/hooks-deployments` body: the request returned unchanged.
  static Map<String, Object?> deploymentBody({
    required String walletId,
    required Launch2SigningRequest request,
    required String signature,
  }) => <String, Object?>{
    'walletId': walletId,
    'request': request.request,
    'hookSalt': request.hookSalt,
    'signature': signature,
  };

  // -- hooks-deployments ----------------------------------------------------

  static const Set<String> jobKeys = <String>{
    'jobId',
    'projectId',
    'configVersion',
    'chainId',
    'factoryAddress',
    'status',
    'memeAddress',
    'hookAddress',
    'txHash',
    'confirmations',
    'activationTxHash',
    'addresses',
    'failure',
    'attemptCount',
    'events',
    'createdAt',
    'updatedAt',
  };

  static const Set<String> eventKeys = <String>{
    'sequence',
    'fromStatus',
    'toStatus',
    'kind',
    'txHash',
    'blockNumber',
    'blockHash',
    'confirmations',
    'errorCode',
    'createdAt',
  };

  static const Set<String> deployedKeys = <String>{
    'launchId',
    'meme',
    'hook',
    'nft',
    'curve',
    'gate',
    'escrow',
    'snapshots',
    'graduationAdapter',
    'buybackAdapter',
    'priceRecorder',
    'buybackExecutor',
  };

  static Launch2DeploymentJob job(
    Object? raw, {
    required String projectId,
    String? jobId,
  }) {
    final map = LoopV2Contract.strictMap(raw, jobKeys);
    final id = LoopV2ChainCodec.requireString(map, 'jobId', pattern: _uuid);
    if (jobId != null && id != jobId) invalid();
    final project = LoopV2ChainCodec.requireString(
      map,
      'projectId',
      pattern: _uuid,
    );
    if (project != projectId) invalid();
    final status = Launch2JobStatus.tryParse(map['status']);
    if (status == null) invalid();
    final addresses = LoopV2Contract.strictMap(map['addresses'], const <String>{
      'predicted',
      'deployed',
    });
    final predicted = LoopV2Contract.strictMap(
      addresses['predicted'],
      const <String>{'meme', 'hook'},
    );
    final meme = LoopV2ChainCodec.requireString(
      map,
      'memeAddress',
      pattern: _address,
    );
    final hook = LoopV2ChainCodec.requireString(
      map,
      'hookAddress',
      pattern: _address,
    );
    if (predicted['meme'] != meme || predicted['hook'] != hook) invalid();
    String? deployedLaunchId;
    String? deployedMeme;
    final deployedRaw = addresses['deployed'];
    if (deployedRaw != null) {
      final deployed = LoopV2Contract.strictMap(deployedRaw, deployedKeys);
      deployedLaunchId = LoopV2ChainCodec.requireString(
        deployed,
        'launchId',
        pattern: _bytes32,
      );
      for (final key in deployedKeys) {
        if (key == 'launchId') continue;
        LoopV2ChainCodec.requireString(deployed, key, pattern: _address);
      }
      deployedMeme = deployed['meme']! as String;
    }
    Launch2JobFailure? failure;
    final failureRaw = map['failure'];
    if (failureRaw != null) {
      final f = LoopV2Contract.strictMap(failureRaw, const <String>{
        'code',
        'retryable',
      });
      failure = Launch2JobFailure(
        code: LoopV2ChainCodec.requireString(f, 'code', pattern: _code),
        retryable: LoopV2ChainCodec.requireBool(f, 'retryable'),
      );
    }
    final eventsRaw = LoopV2ChainCodec.requireList(map['events'], maximum: 100);
    final events = <Launch2JobEvent>[for (final e in eventsRaw) event(e)];
    for (var i = 1; i < events.length; i += 1) {
      if (events[i].sequence <= events[i - 1].sequence) invalid();
    }
    final chainId = LoopV2ChainCodec.requireInt(map, 'chainId', minimum: 1);
    return Launch2DeploymentJob(
      jobId: id,
      projectId: project,
      configVersion: LoopV2ChainCodec.requireInt(
        map,
        'configVersion',
        minimum: 1,
      ),
      chainId: chainId,
      factoryAddress: LoopV2ChainCodec.requireString(
        map,
        'factoryAddress',
        pattern: _address,
      ),
      status: status,
      memeAddress: meme,
      hookAddress: hook,
      txHash: LoopV2ChainCodec.optionalString(map, 'txHash', pattern: _bytes32),
      confirmations: LoopV2ChainCodec.optionalInt(
        map,
        'confirmations',
        minimum: 0,
      ),
      activationTxHash: LoopV2ChainCodec.optionalString(
        map,
        'activationTxHash',
        pattern: _bytes32,
      ),
      deployedLaunchId: deployedLaunchId,
      deployedMeme: deployedMeme,
      failure: failure,
      attemptCount: LoopV2ChainCodec.requireInt(map, 'attemptCount'),
      events: List<Launch2JobEvent>.unmodifiable(events),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
      updatedAt: LoopV2ChainCodec.requireTimestamp(map, 'updatedAt'),
    );
  }

  static Launch2JobEvent event(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, eventKeys);
    final from = map['fromStatus'];
    final fromStatus = from == null ? null : Launch2JobStatus.tryParse(from);
    if (from != null && fromStatus == null) invalid();
    final to = Launch2JobStatus.tryParse(map['toStatus']);
    if (to == null) invalid();
    LoopV2ChainCodec.optionalString(map, 'blockHash', pattern: _bytes32);
    return Launch2JobEvent(
      sequence: LoopV2ChainCodec.requireInt(map, 'sequence', minimum: 1),
      fromStatus: fromStatus,
      toStatus: to,
      kind: LoopV2ChainCodec.requireString(map, 'kind', pattern: _kind),
      txHash: LoopV2ChainCodec.optionalString(map, 'txHash', pattern: _bytes32),
      blockNumber: LoopV2ChainCodec.optionalString(
        map,
        'blockNumber',
        pattern: _uint64,
      ),
      confirmations: LoopV2ChainCodec.optionalInt(
        map,
        'confirmations',
        minimum: 0,
      ),
      errorCode: LoopV2ChainCodec.optionalString(
        map,
        'errorCode',
        pattern: _code,
      ),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
    );
  }

  // -- launch2 instances (the one read the project side needs) --------------

  static const Set<String> instanceRowKeys = <String>{
    'instanceId',
    'projectId',
    'launchId',
    'chainId',
    'name',
    'ticker',
    'logoUrl',
    'memeAddress',
    'stage',
    'nextChangeAt',
    'holdReason',
    'activatedAt',
    'nftSale',
    'curve',
    'graduatedAt',
  };

  static const Set<String> instanceStages = <String>{
    'upcoming',
    'nft_sale',
    'snapshot_pending',
    'closed_no_holders',
    'priority',
    'public',
    'graduated',
    'paused',
  };

  /// One page of `GET /v2/launch2/instances`, reduced to the three facts the
  /// project side uses. The row is still read with its full key set.
  static ({List<Launch2InstanceRef> rows, String? nextCursor}) instancePage(
    Object? raw,
  ) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'instances',
      'nextCursor',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final list = LoopV2ChainCodec.requireList(root['instances'], maximum: 50);
    final rows = <Launch2InstanceRef>[];
    for (final item in list) {
      final row = LoopV2Contract.strictMap(item, instanceRowKeys);
      LoopV2Contract.strictMap(row['nftSale'], const <String>{
        'priceUsd1',
        'soldCount',
        'startAt',
        'endAt',
      });
      final curve = LoopV2Contract.strictMap(row['curve'], const <String>{
        'saleSupply',
        'soldSupply',
        'soldBps',
        'reserveUsd1',
        'graduationReserveUsd1',
        'reserveBps',
        'priceUsd1',
      });
      LoopV2ChainCodec.requireString(curve, 'priceUsd1', pattern: _decimal);
      final stage = row['stage'];
      if (stage is! String || !instanceStages.contains(stage)) invalid();
      rows.add(
        Launch2InstanceRef(
          instanceId: LoopV2ChainCodec.requireString(
            row,
            'instanceId',
            pattern: _uuid,
          ),
          projectId: LoopV2ChainCodec.requireString(
            row,
            'projectId',
            pattern: _uuid,
          ),
          stage: stage,
        ),
      );
    }
    return (
      rows: List<Launch2InstanceRef>.unmodifiable(rows),
      nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
    );
  }
}
