import 'package:flutter/foundation.dart' hide Category;

import '../core/network/api_client.dart';
import '../core/network/api_response.dart';
import '../models/models.dart';

enum LoadState { idle, loading, ready, error }

/// Sort keys accepted by `GET /products`.
///
/// These strings are sent verbatim to the backend, so they must stay in sync
/// with `ProductRepository::SORT_OPTIONS`. Sending an unknown value makes the
/// API answer 422, which used to break the sort dropdown on the catalog.
enum ProductSort {
  latest('latest', 'Terbaru'),
  popular('popular', 'Terlaris'),
  rating('rating', 'Rating tertinggi'),
  priceAsc('price_asc', 'Harga termurah'),
  priceDesc('price_desc', 'Harga termahal'),
  name('name', 'Nama A-Z');

  const ProductSort(this.key, this.label);

  final String key;
  final String label;

  static ProductSort fromKey(String? key) => ProductSort.values.firstWhere(
    (sort) => sort.key == key,
    orElse: () => ProductSort.latest,
  );
}

/// Query parameters accepted by `GET /products`.
class ProductQuery {
  const ProductQuery({
    this.search,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.inStock,
    this.sort = 'latest',
    this.page = 1,
    this.perPage = 15,
  });

  final String? search;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final bool? inStock;
  final String sort;
  final int page;
  final int perPage;

  Map<String, dynamic> toParams() => <String, dynamic>{
    'search': search,
    'category': category,
    'min_price': minPrice,
    'max_price': maxPrice,
    'in_stock': inStock,
    'sort': sort,
    'page': page,
    'per_page': perPage,
  };

  ProductQuery copyWith({
    String? search,
    Object? category = _unset,
    double? minPrice,
    double? maxPrice,
    Object? inStock = _unset,
    String? sort,
    int? page,
    int? perPage,
  }) => ProductQuery(
    search: search ?? this.search,
    category: category == _unset ? this.category : category as String?,
    minPrice: minPrice ?? this.minPrice,
    maxPrice: maxPrice ?? this.maxPrice,
    inStock: inStock == _unset ? this.inStock : inStock as bool?,
    sort: sort ?? this.sort,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
  );

  static const Object _unset = Object();
}

/// Catalog browsing state: product list, categories, product detail and the
/// promotions shown in the ticker.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<Category> _categories = const <Category>[];
  LoadState _categoriesState = LoadState.idle;
  String? _categoriesError;

  List<Product> _products = const <Product>[];
  ProductQuery _query = const ProductQuery();

  LoadState _state = LoadState.idle;
  String? _error;

  List<Promotion> _promotions = const <Promotion>[];
  bool _promotionsLoading = false;

  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loadingMore = false;
  String? _loadMoreError;

  List<Category> get categories => _categories;
  LoadState get categoriesState => _categoriesState;
  String? get categoriesError => _categoriesError;
  List<Product> get products => _products;
  ProductQuery get query => _query;
  LoadState get state => _state;
  String? get error => _error;
  List<Promotion> get promotions => _promotions;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _currentPage < _lastPage;
  String? get loadMoreError => _loadMoreError;
  bool get isEmpty => _state == LoadState.ready && _products.isEmpty;

  /// ------------------------------------------------------------------ Categories

  Future<void> loadCategories() async {
    _categoriesState = LoadState.loading;
    _categoriesError = null;
    notifyListeners();

    try {
      final json = await _api.get(
        '/categories',
        query: <String, dynamic>{'per_page': 50},
      );
      _categories = Paginated<Category>.fromJson(json, Category.fromJson).items;
      _categoriesState = LoadState.ready;
    } on Object catch (error) {
      // Anything (transport or parsing) must clear the spinner, otherwise the
      // category strip stays blank forever.
      _categoriesError = describeError(error);
      _categoriesState = LoadState.error;
    } finally {
      notifyListeners();
    }
  }

  /// ------------------------------------------------------------------- Products

  Future<void> loadProducts({bool reset = true}) async {
    if (reset) {
      _state = LoadState.loading;
      _error = null;
      _loadMoreError = null;
      _query = _query.copyWith(page: 1);
    } else {
      if (_loadingMore || _loadMoreError != null) return;
      _loadingMore = true;
    }

    notifyListeners();

    try {
      final json = await _api.get('/products', query: _query.toParams());
      final page = Paginated<Product>.fromJson(json, Product.fromJson);

      if (page.items.isEmpty && reset) {
        _products = const <Product>[];
      } else if (reset) {
        _products = page.items;
      } else {
        final seen = <int>{for (final product in _products) product.id};
        final append = page.items
            .where((product) => seen.add(product.id))
            .toList();
        _products = <Product>[..._products, ...append];
      }

      _currentPage = page.currentPage;
      _lastPage = page.lastPage;
      _total = page.total;
      _state = LoadState.ready;
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Product catalog request failed (${error.runtimeType}): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (reset) {
        _error = describeError(error);
        _state = LoadState.error;
        _products = const <Product>[];
      } else {
        _loadMoreError = describeError(error);
      }
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore ||
        _loadingMore ||
        _loadMoreError != null ||
        _state != LoadState.ready) {
      return;
    }

    _query = _query.copyWith(page: _currentPage + 1);
    await loadProducts(reset: false);
  }

  Future<void> retryLoadMore() async {
    if (_loadingMore || _loadMoreError == null) return;
    _loadMoreError = null;
    await loadMore();
  }

  Future<void> applyQuery(ProductQuery query) async {
    _query = query;
    await loadProducts();
  }

  /// An empty term clears the search filter.
  Future<void> search(String term) =>
      applyQuery(_query.copyWith(search: normalizeSearchTerm(term)));

  Future<void> clearFilters() => applyQuery(const ProductQuery());

  Future<Product> loadProduct(int id) async {
    final json = await _api.get('/products/$id');
    return Product.fromJson(parseDataEnvelope(json));
  }

  /// ----------------------------------------------------------------- Promotions

  /// Promotions for the scrolling ticker under the catalog search bar.
  ///
  /// A failure here must never break the catalog. Keep the last successful list
  /// visible and log the failure for diagnostics.
  Future<void> loadPromotions() async {
    if (_promotionsLoading) return;
    _promotionsLoading = true;
    try {
      final json = await _api.get('/promotions');
      _promotions = (json['data'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Promotion.fromJson)
          .toList(growable: false);
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Promotion catalog request failed (${error.runtimeType}): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _promotionsLoading = false;
      notifyListeners();
    }
  }

  /// ----------------------------------------------------------------- Favorites

  /// Favorites are only returned to the authenticated owner.
  Future<List<Product>> favorites() async {
    final json = await _api.get('/favorites');
    return Paginated<Product>.fromJson(json, Product.fromJson).items;
  }

  /// Flips the favorite flag and mirrors the change locally for instant feedback.
  Future<Product> toggleFavorite(Product product) async {
    final isRemoving = product.isFavorite;

    if (isRemoving) {
      await _api.delete('/favorites/${product.id}');
    } else {
      await _api.post(
        '/favorites',
        body: <String, dynamic>{'product_id': product.id},
      );
    }

    _replaceProduct(product.copyWith(isFavorite: !isRemoving));
    return _productById(product.id) ??
        product.copyWith(isFavorite: !isRemoving);
  }

  void _replaceProduct(Product updated) {
    _products = _products
        .map((product) => product.id == updated.id ? updated : product)
        .toList(growable: false);
    notifyListeners();
  }

  Product? _productById(int id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }
}

/// Trims a search term and maps an empty result to `null`, so the backend does
/// not receive an empty `search` parameter.
String? normalizeSearchTerm(String term) {
  final trimmed = term.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Human readable message for any thrown object, so a screen can always leave
/// its loading state and show something actionable.
String describeError(Object error) {
  if (error is ApiException) return error.message;
  return 'Gagal memuat data. Periksa koneksi Anda.';
}
