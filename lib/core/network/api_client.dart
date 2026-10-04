import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_response.dart';

/// Callback invoked when the backend rejects the stored token (401), so the app
/// can sign the user out and route back to the login screen.
typedef UnauthorizedHandler = Future<void> Function();

/// Thin HTTP layer over the Laravel REST API.
///
/// Responsibilities: attach the bearer token, encode/decode the standard
/// envelope, map every failure to [ApiException], and refresh the session on
/// 401.
///
/// Every transport error is normalised here on purpose. A caller that only
/// handles [ApiException] would otherwise leak a raw [SocketException],
/// [HandshakeException] or [FormatException] and leave its screen stuck on a
/// loading spinner, which is what users reported as "loading terus".
class ApiClient {
  ApiClient({http.Client? httpClient, this.onUnauthorized})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  final UnauthorizedHandler? onUnauthorized;

  String? _token;

  /// Device name recorded on the Sanctum token (shown in the profile screen).
  String _deviceName = 'flutter-android';

  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void setToken(String? token) {
    _token = token;
  }

  void setDeviceName(String name) {
    if (name.isNotEmpty) _deviceName = name;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalised = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$normalised');

    final effectiveQuery = <String, dynamic>{};
    query?.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      if (value is DateTime) {
        effectiveQuery[key] =
            '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
        return;
      }
      effectiveQuery[key] = value is Iterable
          ? value.map((item) => item.toString()).toList(growable: false)
          : value.toString();
    });

    return effectiveQuery.isEmpty
        ? uri
        : uri.replace(queryParameters: effectiveQuery);
  }

  Map<String, String> _headers({bool json = true}) => <String, String>{
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
    'X-Device-Name': _deviceName,
    if (isAuthenticated) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _guard(
    () => _send(() => _http.get(_uri(path, query), headers: _headers())),
  );

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _guard(
    () => _send(
      () => _http.post(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    ),
  );

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _guard(
        () => _send(
          () => _http.put(
            _uri(path),
            headers: _headers(),
            body: body == null ? null : jsonEncode(body),
          ),
        ),
      );

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => _guard(
    () => _send(
      () => _http.patch(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    ),
  );

  Future<Map<String, dynamic>> delete(String path) =>
      _guard(() => _send(() => _http.delete(_uri(path), headers: _headers())));

  Future<Map<String, dynamic>> uploadImage(String path, String filePath) =>
      uploadFile(path, filePath, fieldName: 'image');

  Future<Map<String, dynamic>> uploadFile(
    String path,
    String filePath, {
    required String fieldName,
  }) =>
      _guard(() async {
        final request = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_headers(json: false))
          ..files.add(await http.MultipartFile.fromPath(fieldName, filePath));
        final streamed = await _http
            .send(request)
            .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
        final response = await http.Response.fromStream(streamed);
        return _handleResponse(response);
      });

  Future<Uint8List> getBytes(String path) => _guard(() async {
    final response = await _http
        .get(_uri(path), headers: _headers(json: false))
        .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await _handleResponse(response);
    throw ApiException(message: 'Gagal memuat bukti pembayaran.');
  });

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async => _handleResponse(
    await request().timeout(
      const Duration(seconds: AppConfig.requestTimeoutSeconds),
    ),
  );

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final decoded = decodeBody(response.body);
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      return decoded;
    }

    if (status == 401 && onUnauthorized != null) {
      await onUnauthorized!();
    }

    throw ApiException.fromJson(decoded, statusCode: status);
  }

  /// Turns any transport / decoding failure into an [ApiException] carrying a
  /// message that is safe to show to the user.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException.network(
        'Server tidak merespons. Periksa koneksi Anda.',
      );
    } on HandshakeException {
      throw ApiException.network(
        'Koneksi aman (HTTPS) ke server gagal. Periksa alamat server.',
      );
    } on SocketException {
      throw ApiException.network(
        'Tidak dapat terhubung ke server di ${AppConfig.apiHost}. '
        'Pastikan backend berjalan dan alamat server benar.',
      );
    } on http.ClientException {
      throw ApiException.network('Koneksi ke server gagal.');
    } on FormatException {
      throw ApiException(message: 'Respons server tidak dapat dibaca.');
    } on IOException catch (error) {
      final detail = error.toString().replaceFirst('IOException: ', '').trim();
      throw ApiException.network(
        detail.isEmpty
            ? 'Jaringan bermasalah, server tidak dapat dijangkau.'
            : 'Jaringan bermasalah: $detail',
      );
    } on Object catch (error, stackTrace) {
      // Preserve actionable diagnostics instead of masking unexpected runtime
      // failures as a generic server or connectivity error.
      debugPrint('Unexpected API client error (${error.runtimeType}): $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ApiException(
        message:
            'Terjadi kesalahan aplikasi (${error.runtimeType}). Coba lagi.',
      );
    }
  }

  void close() => _http.close();
}
