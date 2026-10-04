import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parfum_im/core/network/api_client.dart';

void main() {
  test('sends the stored session token as a bearer token', () async {
    final client = ApiClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer registration-token');
        return http.Response('{"success":true,"data":{}}', 200);
      }),
    );
    client.setToken('registration-token');

    try {
      await client.get('/auth/me');
    } finally {
      client.close();
    }
  });

  test(
    'serializes scalar and list query parameters for HTTP requests',
    () async {
      final client = ApiClient(
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters, <String, String>{
            'page': '2',
            'in_stock': 'true',
            'sort': 'latest',
            'category': 'fresh',
          });
          expect(request.url.queryParametersAll['category'], <String>[
            'floral',
            'fresh',
          ]);
          return http.Response('{"success":true,"data":[]}', 200);
        }),
      );

      try {
        await client.get(
          '/products',
          query: <String, dynamic>{
            'page': 2,
            'in_stock': true,
            'sort': 'latest',
            'category': <String>['floral', 'fresh'],
          },
        );
      } finally {
        client.close();
      }
    },
  );
}
