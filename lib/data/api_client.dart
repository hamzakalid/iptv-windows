import 'package:dio/dio.dart';

import '../core/json.dart';

/// Thrown for any failed request. `code` mirrors the backend's
/// `{ error: { code, message } }` envelope when available.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.status});
  final String message;
  final String? code;
  final int? status;

  bool get isUnauthorized => status == 401 && code != 'invalid_credentials';

  @override
  String toString() => message;
}

/// Thin Dio wrapper that injects the bearer token and normalises errors.
class ApiClient {
  ApiClient({required String baseUrl, required String? Function() token, required void Function() onUnauthorized})
      : _dio = Dio(BaseOptions(
          baseUrl: normalizeBaseUrl(baseUrl),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          contentType: Headers.jsonContentType,
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = token();
        if (t != null) options.headers['Authorization'] = 'Bearer $t';
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401 && !e.requestOptions.path.startsWith('/auth/')) {
          onUnauthorized();
        }
        handler.next(e);
      },
    ));
  }

  final Dio _dio;

  /// Accepts `host:4000`, `http://host:4000` or `http://host:4000/api`.
  static String normalizeBaseUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith(RegExp(r'https?://'))) url = 'http://$url';
    url = url.replaceAll(RegExp(r'/+$'), '');
    if (!url.endsWith('/api')) url = '$url/api';
    return url;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, [Object? body]) => _send(() => _dio.post(path, data: body));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      return res.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) =>
      q == null ? null : (Map.of(q)..removeWhere((_, v) => v == null || v == ''));

  static ApiException _toApiException(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(
        switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout =>
            'The server took too long to respond.',
          _ => 'Could not reach the server. Check the server address and your connection.',
        },
        code: 'network_error',
      );
    }
    final err = jMap(jMap(res.data)?['error']);
    return ApiException(
      jStr(err?['message']) ?? 'Request failed (${res.statusCode}).',
      code: jStr(err?['code']),
      status: res.statusCode,
    );
  }
}
