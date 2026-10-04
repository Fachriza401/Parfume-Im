import 'package:flutter_test/flutter_test.dart';
import 'package:parfum_im/core/network/api_response.dart';
import 'package:parfum_im/models/models.dart';

void main() {
  group('ApiException', () {
    test('reads the machine code from the nested errors object', () {
      final exception = ApiException.fromJson(<String, dynamic>{
        'success': false,
        'message': 'Stok produk tidak mencukupi.',
        'errors': <String, dynamic>{
          'code': 'INSUFFICIENT_STOCK',
          'quantity': <String>['Stok hanya tersisa 2'],
        },
      }, statusCode: 422);

      expect(exception.code, 'INSUFFICIENT_STOCK');
      expect(exception.message, 'Stok produk tidak mencukupi.');
      expect(exception.statusCode, 422);
      expect(exception.fieldError('quantity'), 'Stok hanya tersisa 2');
    });

    test('falls back to a generic message when the body is unusable', () {
      final exception = ApiException.fromJson(<String, dynamic>{});

      expect(exception.message, 'Terjadi kesalahan.');
      expect(exception.code, isNull);
      expect(exception.errors, isEmpty);
    });

    test('classifies status codes', () {
      expect(
        ApiException(message: 'x', statusCode: 401).isUnauthorized,
        isTrue,
      );
      expect(ApiException(message: 'x', statusCode: 403).isForbidden, isTrue);
      expect(ApiException(message: 'x', statusCode: 404).isNotFound, isTrue);
    });
  });

  group('Paginated', () {
    test('parses the array plus root meta envelope', () {
      final page = Paginated<Category>.fromJson(<String, dynamic>{
        'success': true,
        'data': <dynamic>[
          <String, dynamic>{'id': 1, 'name': 'Eau de Parfum', 'slug': 'edp'},
          <String, dynamic>{'id': 2, 'name': 'Body Mist', 'slug': 'body-mist'},
        ],
        'meta': <String, dynamic>{
          'current_page': 2,
          'last_page': 5,
          'per_page': 2,
          'total': 9,
        },
      }, Category.fromJson);

      expect(page.items, hasLength(2));
      expect(page.items.first.name, 'Eau de Parfum');
      expect(page.currentPage, 2);
      expect(page.lastPage, 5);
      expect(page.total, 9);
      expect(page.hasMorePages, isTrue);
    });

    test('tolerates a missing meta block', () {
      final page = Paginated<Product>.fromJson(<String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{'id': 7, 'name': 'Chanel No.5', 'price': 950000},
        ],
      }, Product.fromJson);

      expect(page.items, hasLength(1));
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.hasMorePages, isFalse);
    });
  });

  group('parseDataEnvelope', () {
    test('unwraps the success payload', () {
      final data = parseDataEnvelope(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'token': 'abc',
          'user': <String, dynamic>{'id': 1},
        },
      });

      expect(data['token'], 'abc');
    });

    test('returns an empty map when data is absent', () {
      expect(parseDataEnvelope(<String, dynamic>{'success': true}), isEmpty);
    });
  });
}
