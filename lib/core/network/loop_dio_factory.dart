import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Creates Dio clients with one explicit network trust boundary.
///
/// Repositories still own request shapes, response parsing, authentication
/// refresh, idempotency, and domain failure mapping. This factory owns only
/// connection defaults and the invariants that must apply before dispatch.
abstract final class LoopDioFactory {
  static const connectTimeout = Duration(seconds: 10);
  static const sendTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 15);

  /// How long an idle keep-alive connection stays in the pool (decision 0101).
  ///
  /// `dart:io` closes idle sockets after 15 s by default. A reader who stays
  /// on one page longer than that paid a fresh TCP + TLS handshake — two more
  /// round trips, 0.5–2.3 s each from China — on the next page's first read.
  /// Sixty seconds stays below the LOOP API's own `keepAliveTimeout` (72 s),
  /// so the client lets go of a socket before the server does.
  static const idleConnectionTimeout = Duration(seconds: 60);

  /// Creates an identity-free client for one exact public HTTPS origin.
  ///
  /// Authorization, Cookie, Proxy-Authorization, and X-Api-Key are rejected
  /// before dispatch. A public client therefore cannot be reused later for
  /// Privy, Stream, or backend authentication.
  static Dio createCredentialFreePublic({required Uri origin}) {
    return _create(
      origin: _validatedOrigin(origin, allowLoopbackHttp: false),
      allowAuthorizationHeader: false,
    );
  }

  /// Creates a client for one exact LOOP backend origin.
  ///
  /// HTTPS is required except for an explicit loopback Development origin.
  /// Bearer credentials remain request-local and are never installed as Dio
  /// defaults or by an interceptor. Cookie, Proxy-Authorization, and X-Api-Key
  /// remain rejected.
  static Dio createLoopBackend({required Uri origin}) {
    return _create(
      origin: _validatedOrigin(origin, allowLoopbackHttp: true),
      allowAuthorizationHeader: true,
    );
  }

  static Dio _create({
    required Uri origin,
    required bool allowAuthorizationHeader,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: origin.toString(),
        connectTimeout: connectTimeout,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
        followRedirects: false,
        maxRedirects: 0,
        responseType: ResponseType.json,
      ),
    );
    dio.httpClientAdapter = _LoopOriginConnectionPool.lease(origin);
    dio.interceptors.add(
      _LoopTrustBoundaryInterceptor(
        origin: origin,
        allowAuthorizationHeader: allowAuthorizationHeader,
        defaultHeaders: () => dio.options.headers,
      ),
    );
    return dio;
  }

  static Uri _validatedOrigin(Uri origin, {required bool allowLoopbackHttp}) {
    final scheme = origin.scheme.toLowerCase();
    final host = origin.host.toLowerCase();
    final isRoot = origin.path.isEmpty || origin.path == '/';
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    final isAllowedScheme =
        scheme == 'https' ||
        (allowLoopbackHttp && scheme == 'http' && isLoopback);
    if (!origin.isAbsolute ||
        !origin.hasAuthority ||
        host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        !isRoot ||
        !isAllowedScheme) {
      throw ArgumentError(
        'Loop HTTP clients require one credential-free, root-only trusted origin.',
      );
    }
    return origin.replace(
      scheme: scheme,
      host: host,
      path: '/',
      query: null,
      fragment: null,
    );
  }
}

/// One keep-alive connection pool per exact origin (decision 0101).
///
/// The public D0 client and the authenticated backend client talk to the same
/// origin. With a pool each, a warm socket on one was useless to the other,
/// and every capability refresh opened its own TLS session. Connections carry
/// no credential state — `dart:io` keeps no cookies and every Authorization
/// header is request-local — so sharing the socket shares nothing else. The
/// trust-boundary interceptor still runs per client, before dispatch.
///
/// Each client holds a lease; the pool closes when the last lease closes.
final class _LoopOriginConnectionPool implements HttpClientAdapter {
  _LoopOriginConnectionPool._(this._key, this._entry);

  static final Map<String, _LoopPoolEntry> _entries =
      <String, _LoopPoolEntry>{};

  static _LoopOriginConnectionPool lease(Uri origin) {
    final key = '${origin.scheme}://${origin.host}:${origin.port}';
    final entry = _entries.putIfAbsent(
      key,
      () => _LoopPoolEntry(
        IOHttpClientAdapter(
          createHttpClient: () =>
              HttpClient()..idleTimeout = LoopDioFactory.idleConnectionTimeout,
        ),
      ),
    );
    entry.leases += 1;
    return _LoopOriginConnectionPool._(key, entry);
  }

  final String _key;
  final _LoopPoolEntry _entry;
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _entry.adapter.fetch(options, requestStream, cancelFuture);

  @override
  void close({bool force = false}) {
    if (_closed) return;
    _closed = true;
    _entry.leases -= 1;
    if (_entry.leases > 0) return;
    if (identical(_entries[_key], _entry)) _entries.remove(_key);
    _entry.adapter.close(force: force);
  }
}

final class _LoopPoolEntry {
  _LoopPoolEntry(this.adapter);

  final IOHttpClientAdapter adapter;
  int leases = 0;
}

/// Sanitized marker for requests rejected before network dispatch.
final class LoopHttpBoundaryViolation implements Exception {
  const LoopHttpBoundaryViolation();

  @override
  String toString() => 'HTTP request rejected by the Loop trust boundary.';
}

final class _LoopTrustBoundaryInterceptor extends Interceptor {
  _LoopTrustBoundaryInterceptor({
    required this._origin,
    required this._allowAuthorizationHeader,
    required this._defaultHeaders,
  });

  static const _alwaysForbiddenHeaders = <String>{
    'proxy-authorization',
    'cookie',
    'x-api-key',
  };

  final Uri _origin;
  final bool _allowAuthorizationHeader;
  final Map<String, dynamic> Function() _defaultHeaders;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestUri = options.uri;
    final exactOrigin =
        requestUri.scheme.toLowerCase() == _origin.scheme &&
        requestUri.host.toLowerCase() == _origin.host &&
        requestUri.port == _origin.port &&
        requestUri.userInfo.isEmpty;
    final hasForbiddenHeader = options.headers.keys.any((name) {
      final normalized = name.toLowerCase();
      return _alwaysForbiddenHeaders.contains(normalized) ||
          (normalized == 'authorization' && !_allowAuthorizationHeader);
    });
    final hasPersistentCredential = _defaultHeaders().keys.any((name) {
      final normalized = name.toLowerCase();
      return normalized == 'authorization' ||
          _alwaysForbiddenHeaders.contains(normalized);
    });
    if (!exactOrigin ||
        options.followRedirects ||
        hasForbiddenHeader ||
        hasPersistentCredential) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const LoopHttpBoundaryViolation(),
        ),
      );
      return;
    }
    handler.next(options);
  }
}
