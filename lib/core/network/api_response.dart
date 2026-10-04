import 'dart:convert';

/// Error surfaced by the API layer, already localised for display.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.errors = const <String, dynamic>{},
  });

  final String message;
  final int? statusCode;

  /// Machine-readable code from the backend, e.g. `INSUFFICIENT_STOCK`.
  final String? code;

  /// Per-field validation messages keyed by field name.
  final Map<String, dynamic> errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// Validation message for a single field, when present.
  String? fieldError(String field) {
    final value = errors[field];
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value?.toString();
  }

  factory ApiException.fromJson(Map<String, dynamic> json, {int? statusCode}) {
    final rawErrors = json['errors'];
    final errors = rawErrors is Map<String, dynamic>
        ? rawErrors
        : const <String, dynamic>{};

    return ApiException(
      message: (json['message'] ?? 'Terjadi kesalahan.').toString(),
      statusCode: statusCode,
      // The backend nests the machine code inside `errors.code`, alongside the
      // per-field validation messages.
      code: errors['code']?.toString() ?? json['code']?.toString(),
      errors: errors,
    );
  }

  factory ApiException.network(String message) =>
      ApiException(message: message, code: 'NETWORK_ERROR');

  @override
  String toString() => message;
}

/// A paginated list response plus its paging metadata.
///
/// The backend always returns `data` as a plain array and puts `meta` at the
/// root level, so one parser covers products, orders, reviews, admin lists and
/// audit logs.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.from,
    this.to,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int? from;
  final int? to;

  bool get hasMorePages => currentPage < lastPage;

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final data = json['data'];
    final meta = json['meta'];

    final items = data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(parse)
              .toList(growable: false)
        : <T>[];

    final metaMap = meta is Map<String, dynamic>
        ? meta
        : const <String, dynamic>{};

    return Paginated<T>(
      items: items,
      currentPage: _asInt(metaMap['current_page'], 1),
      lastPage: _asInt(metaMap['last_page'], 1),
      perPage: _asInt(metaMap['per_page'], items.length),
      total: _asInt(metaMap['total'], items.length),
      from: _asNullableInt(metaMap['from']),
      to: _asNullableInt(metaMap['to']),
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/// Parses a plain (non-paginated) success envelope into its `data` payload.
Map<String, dynamic> parseDataEnvelope(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) return data;
  return const <String, dynamic>{};
}

/// Helper to read a decoded JSON map without throwing on a wrong type.
Map<String, dynamic> asMap(dynamic value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<dynamic> asList(dynamic value) => value is List ? value : const [];

/// Decodes a JSON body, tolerating an empty or non-object response.
Map<String, dynamic> decodeBody(String body) {
  if (body.trim().isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } on FormatException {
    return <String, dynamic>{};
  }
}
