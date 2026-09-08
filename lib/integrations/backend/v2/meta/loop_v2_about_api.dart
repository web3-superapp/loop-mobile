import 'package:dio/dio.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict V2 transport for the public `GET /v2/meta/about` (decision 0037).
///
/// It is the one authenticated-free resource this step consumes: no
/// Authorization header is sent, and the client build number is never
/// uploaded or compared.
abstract interface class LoopV2AboutApi {
  Future<LoopAbout> getAbout();
}

final class DioLoopV2AboutApi implements LoopV2AboutApi {
  DioLoopV2AboutApi(this._dio);

  static const aboutPath = '/v2/meta/about';
  static const maximumConfigVersions = 64;
  static const maximumOpenSourceEntries = 256;

  static const aboutErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{'REQUEST_TIMEOUT'},
  };

  static final RegExp _modulePattern = RegExp(r'^[a-z][A-Za-z0-9]{0,63}$');
  static final RegExp _configVersionPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$',
  );

  final Dio _dio;

  @override
  Future<LoopAbout> getAbout() async {
    try {
      final response = await _dio.get<Object?>(
        aboutPath,
        options: Options(
          headers: <String, String>{'accept': Headers.jsonContentType},
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'contractVersion',
        'configVersions',
        'termsGate',
        'openSource',
        'clientBuild',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final configVersions = <LoopAboutConfigVersion>[];
      final seenModules = <String>{};
      for (final raw in LoopV2ChainCodec.requireList(
        root['configVersions'],
        maximum: maximumConfigVersions,
      )) {
        final map = LoopV2Contract.strictMap(raw, const <String>{
          'module',
          'configVersion',
          'effectiveAt',
        });
        final module = LoopV2ChainCodec.requireString(
          map,
          'module',
          pattern: _modulePattern,
          maxLength: 64,
        );
        if (!seenModules.add(module)) LoopV2ChainCodec.invalid();
        configVersions.add(
          LoopAboutConfigVersion(
            module: module,
            configVersion: LoopV2ChainCodec.requireString(
              map,
              'configVersion',
              pattern: _configVersionPattern,
              maxLength: 128,
            ),
            effectiveAt: LoopV2ChainCodec.optionalTimestamp(map, 'effectiveAt'),
          ),
        );
      }
      if (configVersions.isEmpty) LoopV2ChainCodec.invalid();
      final clientBuild = LoopV2Contract.strictMap(
        root['clientBuild'],
        const <String>{'status', 'reasonCode'},
      );
      // The server never publishes a client build; it says so explicitly.
      if (clientBuild['status'] != 'local') LoopV2ChainCodec.invalid();
      return LoopAbout(
        contractVersion: LoopV2ChainCodec.contractVersion,
        configVersions: List<LoopAboutConfigVersion>.unmodifiable(
          configVersions,
        ),
        termsGate: _termsGate(root['termsGate']),
        openSource: _openSource(root['openSource']),
        clientBuildReasonCode: LoopV2ChainCodec.requireReasonCode(
          clientBuild,
          'reasonCode',
        ),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: aboutErrors);
    }
  }

  static LoopAboutTermsGate _termsGate(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'requiredVersion',
      'reasonCode',
    });
    final status = map['status'];
    if (status == 'unavailable') {
      if (map['requiredVersion'] != null) LoopV2ChainCodec.invalid();
      return LoopAboutTermsGate(
        requiredVersion: null,
        reasonCode: LoopV2ChainCodec.requireReasonCode(map, 'reasonCode'),
      );
    }
    if (status != 'available' || map['reasonCode'] != null) {
      LoopV2ChainCodec.invalid();
    }
    return LoopAboutTermsGate(
      requiredVersion: LoopV2ChainCodec.requireText(
        map,
        'requiredVersion',
        maxLength: 128,
      ),
      reasonCode: null,
    );
  }

  static LoopOpenSourceRegister _openSource(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'source',
      'summary',
      'entries',
    });
    final entries = <LoopOpenSourceEntry>[];
    final seen = <String>{};
    for (final rawEntry in LoopV2ChainCodec.requireList(
      map['entries'],
      maximum: maximumOpenSourceEntries,
    )) {
      // Only name, purpose and license exist on the wire: no version is
      // published, so none is rendered.
      final entry = LoopV2Contract.strictMap(rawEntry, const <String>{
        'name',
        'purpose',
        'license',
      });
      final name = LoopV2ChainCodec.requireText(entry, 'name', maxLength: 128);
      if (!seen.add(name)) LoopV2ChainCodec.invalid();
      entries.add(
        LoopOpenSourceEntry(
          name: name,
          purpose: LoopV2ChainCodec.requireText(
            entry,
            'purpose',
            maxLength: 256,
          ),
          license: LoopV2ChainCodec.requireText(
            entry,
            'license',
            maxLength: 64,
          ),
        ),
      );
    }
    if (entries.isEmpty) LoopV2ChainCodec.invalid();
    return LoopOpenSourceRegister(
      source: LoopV2ChainCodec.requireText(map, 'source', maxLength: 256),
      summary: LoopV2ChainCodec.requireText(map, 'summary', maxLength: 1024),
      entries: entries,
    );
  }
}
