import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parfum_im/core/network/api_client.dart';
import 'package:parfum_im/providers/admin_provider.dart';
import 'package:parfum_im/providers/catalog_provider.dart';

void main() {
  test('a failed next page waits for an explicit retry', () async {
    final requestedPages = <String?>[];
    final api = ApiClient(
      httpClient: MockClient((request) async {
        final page = request.url.queryParameters['page'];
        requestedPages.add(page);
        if (page == '2' && requestedPages.length == 2) {
          return http.Response(
            '{"success":false,"message":"Server belum tersedia"}',
            503,
          );
        }

        final currentPage = page == '2' ? 2 : 1;
        return http.Response(
          '{"success":true,"data":[],"meta":{"current_page":$currentPage,'
          '"last_page":2,"per_page":15,"total":16}}',
          200,
        );
      }),
    );
    final provider = AdminProvider(api: api);

    try {
      await provider.loadProducts();
      await provider.loadMoreProducts();

      expect(provider.productsLoadMoreError, isNotNull);
      expect(provider.hasMoreProducts, isTrue);
      expect(requestedPages, <String?>['1', '2']);

      await provider.loadMoreProducts();
      expect(requestedPages, <String?>['1', '2']);

      await provider.retryLoadMoreProducts();
      expect(requestedPages, <String?>['1', '2', '2']);
      expect(provider.productsLoadMoreError, isNull);
      expect(provider.hasMoreProducts, isFalse);
    } finally {
      api.close();
    }
  });

  test('catalog pagination waits for an explicit retry after an error', () async {
    final requestedPages = <String?>[];
    final api = ApiClient(
      httpClient: MockClient((request) async {
        final page = request.url.queryParameters['page'];
        requestedPages.add(page);
        if (page == '2' && requestedPages.length == 2) {
          return http.Response(
            '{"success":false,"message":"Server belum tersedia"}',
            503,
          );
        }

        final currentPage = page == '2' ? 2 : 1;
        return http.Response(
          '{"success":true,"data":[],"meta":{"current_page":$currentPage,'
          '"last_page":2,"per_page":15,"total":16}}',
          200,
        );
      }),
    );
    final provider = CatalogProvider(api: api);

    try {
      await provider.loadProducts();
      await provider.loadMore();

      expect(provider.loadMoreError, isNotNull);
      expect(provider.hasMore, isTrue);
      expect(requestedPages, <String?>['1', '2']);

      await provider.loadMore();
      expect(requestedPages, <String?>['1', '2']);

      await provider.retryLoadMore();
      expect(requestedPages, <String?>['1', '2', '2']);
      expect(provider.loadMoreError, isNull);
      expect(provider.hasMore, isFalse);
    } finally {
      api.close();
    }
  });
}
