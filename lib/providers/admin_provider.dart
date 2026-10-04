import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/network/api_client.dart';
import '../core/network/api_response.dart';
import '../models/models.dart';
import 'catalog_provider.dart'
    show LoadState, describeError, normalizeSearchTerm;

/// Filters currently applied to the admin product list.
///
/// Kept as one object so a CRUD mutation can re-run the exact same query
/// instead of resetting the search box the admin just typed into.
class ProductFilters {
  const ProductFilters({this.search = '', this.categoryId, this.active});

  final String search;

  /// Null = all categories.
  final int? categoryId;

  /// Null = semua, true = aktif saja, false = nonaktif saja.
  final bool? active;

  bool get isDefault =>
      search.trim().isEmpty && categoryId == null && active == null;

  ProductFilters copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? active = _unset,
  }) => ProductFilters(
    search: search ?? this.search,
    categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
    active: active == _unset ? this.active : active as bool?,
  );

  static const Object _unset = Object();
}

/// Filters for the admin category list.
class CategoryFilters {
  const CategoryFilters({this.search = ''});

  final String search;

  CategoryFilters copyWith({String? search}) =>
      CategoryFilters(search: search ?? this.search);
}

/// Admin management state: dashboard stats, catalog CRUD, stock, orders,
/// promotions, sales reports and audit logs. Every mutation throws so the UI
/// can surface the backend message with [ApiException].
class AdminProvider extends ChangeNotifier {
  AdminProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  LoadState _state = LoadState.idle;
  String? _error;
  LoadState _dashboardState = LoadState.idle;
  String? _dashboardError;

  AdminStats? _stats;

  List<Category> _categories = const <Category>[];
  LoadState _categoriesState = LoadState.idle;
  String? _categoriesError;
  CategoryFilters _categoryFilters = const CategoryFilters();

  List<Product> _products = const <Product>[];
  ProductFilters _productFilters = const ProductFilters();
  int _productPage = 1;
  int _productLastPage = 1;
  int _productTotal = 0;
  bool _productsLoadingMore = false;
  String? _productsLoadMoreError;

  List<Promotion> _promotions = const <Promotion>[];
  LoadState _promotionsState = LoadState.idle;

  List<Order> _orders = const <Order>[];
  int _orderPage = 1;
  int _orderLastPage = 1;
  bool _ordersLoadingMore = false;
  bool _ordersLoading = false;
  bool _ordersRefreshQueued = false;
  String _orderSearch = '';
  OrderStatus? _orderStatusFilter;
  PaymentStatus? _paymentFilter;

  SalesReport? _report;
  bool _reportLoading = false;

  List<AuditLogEntry> _auditLogs = const <AuditLogEntry>[];
  int _auditPage = 1;
  int _auditLastPage = 1;
  bool _auditLoadingMore = false;

  LoadState get state => _state;
  String? get error => _error;
  LoadState get dashboardState => _dashboardState;
  String? get dashboardError => _dashboardError;
  AdminStats? get stats => _stats;

  List<Category> get categories => _categories;
  LoadState get categoriesState => _categoriesState;
  String? get categoriesError => _categoriesError;
  CategoryFilters get categoryFilters => _categoryFilters;

  List<Product> get products => _products;
  ProductFilters get productFilters => _productFilters;
  int get productTotal => _productTotal;
  bool get hasMoreProducts => _productPage < _productLastPage;
  bool get isLoadingMoreProducts => _productsLoadingMore;
  String? get productsLoadMoreError => _productsLoadMoreError;

  List<Promotion> get promotions => _promotions;
  LoadState get promotionsState => _promotionsState;

  List<Order> get orders => _orders;
  String get orderSearch => _orderSearch;
  OrderStatus? get orderStatusFilter => _orderStatusFilter;
  PaymentStatus? get paymentFilter => _paymentFilter;
  bool get hasMoreOrders => _orderPage < _orderLastPage;
  bool get isLoadingMoreOrders => _ordersLoadingMore;

  SalesReport? get report => _report;
  bool get isReportLoading => _reportLoading;

  List<AuditLogEntry> get auditLogs => _auditLogs;
  bool get hasMoreAuditLogs => _auditPage < _auditLastPage;
  bool get isLoadingMoreAuditLogs => _auditLoadingMore;

  /// ------------------------------------------------------------------ Dashboard

  Future<void> loadDashboard({DateTime? from, DateTime? to}) async {
    _dashboardState = LoadState.loading;
    _dashboardError = null;
    notifyListeners();

    try {
      final json = await _api.get(
        '/admin/dashboard-stats',
        query: <String, dynamic>{'from': from, 'to': to},
      );
      _stats = AdminStats.fromJson(parseDataEnvelope(json));
      _dashboardState = LoadState.ready;
    } on Object catch (error) {
      _dashboardError = describeError(error);
      _dashboardState = LoadState.error;
    } finally {
      notifyListeners();
    }
  }

  /// ------------------------------------------------------------ Categories

  Future<void> loadCategories({String? search}) async {
    if (search != null) {
      _categoryFilters = _categoryFilters.copyWith(search: search);
    }

    _categoriesState = LoadState.loading;
    _categoriesError = null;
    notifyListeners();

    try {
      final json = await _api.get(
        '/admin/categories',
        query: <String, dynamic>{
          if (_categoryFilters.search.trim().isNotEmpty)
            'search': _categoryFilters.search.trim(),
        },
      );
      _categories = _parseList(json, Category.fromJson);
      _categoriesState = LoadState.ready;
    } on Object catch (error) {
      _categoriesError = describeError(error);
      _categoriesState = LoadState.error;
    } finally {
      notifyListeners();
    }
  }

  /// Re-runs the category list with the current filters (used after a CRUD).
  Future<void> refreshCategories() => loadCategories();

  Future<Category> createCategory({
    required String name,
    String? slug,
    String? description,
    String? image,
    bool isActive = true,
  }) async {
    final json = await _api.post(
      '/admin/categories',
      body: <String, dynamic>{
        'name': name,
        if (slug != null && slug.isNotEmpty) 'slug': slug,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (image != null && image.isNotEmpty) 'image': image,
        'is_active': isActive,
      },
    );
    final category = Category.fromJson(parseDataEnvelope(json));
    await loadCategories();
    return category;
  }

  Future<Category> updateCategory(
    int id, {
    required String name,
    String? slug,
    String? description,
    String? image,
    bool isActive = true,
  }) async {
    final json = await _api.put(
      '/admin/categories/$id',
      body: <String, dynamic>{
        'name': name,
        if (slug != null && slug.isNotEmpty) 'slug': slug,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (image != null && image.isNotEmpty) 'image': image,
        'is_active': isActive,
      },
    );
    final category = Category.fromJson(parseDataEnvelope(json));
    await loadCategories();
    return category;
  }

  Future<void> deleteCategory(int id) async {
    await _api.delete('/admin/categories/$id');
    await loadCategories();
  }

  /// -------------------------------------------------------------- Products

  /// Loads the product list. Passing `null` keeps the currently applied
  /// filters, which is what the search box and the CRUD actions rely on.
  Future<void> loadProducts({
    String? search,
    Object? categoryId = _unset,
    Object? isActive = _unset,
    bool? trashed,
    bool reset = true,
  }) async {
    _productFilters = _productFilters.copyWith(
      search: search,
      categoryId: categoryId,
      active: isActive,
    );

    if (reset) {
      _state = LoadState.loading;
      _error = null;
      _productsLoadMoreError = null;
    } else {
      if (_productsLoadingMore || _productsLoadMoreError != null) return;
      _productsLoadingMore = true;
    }
    notifyListeners();

    try {
      final json = await _api.get(
        '/admin/products',
        query: <String, dynamic>{
          if (_productFilters.search.trim().isNotEmpty)
            'search': _productFilters.search.trim(),
          if (_productFilters.categoryId != null)
            'category_id': _productFilters.categoryId,
          if (_productFilters.active != null)
            'is_active': _productFilters.active,
          'trashed': trashed,
          'page': reset ? 1 : _productPage + 1,
          'per_page': 15,
        },
      );
      final page = Paginated<Product>.fromJson(json, Product.fromJson);

      _products = reset ? page.items : <Product>[..._products, ...page.items];
      _productPage = page.currentPage;
      _productLastPage = page.lastPage;
      _productTotal = page.total;
      _state = LoadState.ready;
    } on Object catch (error) {
      if (reset) {
        _error = describeError(error);
        _state = LoadState.error;
        _products = const <Product>[];
      } else {
        _productsLoadMoreError = describeError(error);
      }
    } finally {
      _productsLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreProducts() async {
    if (!hasMoreProducts ||
        _productsLoadingMore ||
        _productsLoadMoreError != null) {
      return;
    }
    await loadProducts(reset: false);
  }

  Future<void> retryLoadMoreProducts() async {
    if (_productsLoadingMore || _productsLoadMoreError == null) return;
    _productsLoadMoreError = null;
    await loadMoreProducts();
  }

  /// Applies (or clears) the product search term.
  Future<void> searchProducts(String term) =>
      loadProducts(search: normalizeSearchTerm(term) ?? '');

  Future<void> filterProductsByCategory(int? categoryId) =>
      loadProducts(categoryId: categoryId);

  Future<void> filterProductsByActive(bool? isActive) =>
      loadProducts(isActive: isActive);

  Future<Product> createProduct({
    required String name,
    required int categoryId,
    required double price,
    required int stock,
    String? slug,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final json = await _api.post(
      '/admin/products',
      body: <String, dynamic>{
        'name': name,
        'category_id': categoryId,
        'price': price,
        'stock': stock,
        if (slug != null && slug.isNotEmpty) 'slug': slug,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        'is_active': isActive,
      },
    );
    final product = Product.fromJson(parseDataEnvelope(json));
    await loadProducts();
    return product;
  }

  Future<String> uploadImage(String filePath) async {
    final json = await _api.uploadImage('/media/images', filePath);
    final imageUrl = parseDataEnvelope(json)['image_url']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw ApiException(message: 'Server tidak mengembalikan gambar.');
    }
    return imageUrl;
  }

  Future<Product> updateProduct(
    int id, {
    required String name,
    required int categoryId,
    required double price,
    required int stock,
    String? slug,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final json = await _api.put(
      '/admin/products/$id',
      body: <String, dynamic>{
        'name': name,
        'category_id': categoryId,
        'price': price,
        'stock': stock,
        if (slug != null && slug.isNotEmpty) 'slug': slug,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        'is_active': isActive,
      },
    );
    final product = Product.fromJson(parseDataEnvelope(json));
    await loadProducts();
    return product;
  }

  /// Soft-deletes the product so historical orders keep resolution (BR-11).
  Future<void> deleteProduct(int id) async {
    await _api.delete('/admin/products/$id');
    await loadProducts();
  }

  Future<Product> adjustStock(
    int id, {
    required String type,
    required int quantity,
    String? reason,
  }) async {
    final json = await _api.post(
      '/admin/products/$id/stock',
      body: <String, dynamic>{
        'type': type,
        'quantity': quantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    final product = Product.fromJson(parseDataEnvelope(json));

    _products = _products
        .map((candidate) => candidate.id == product.id ? product : candidate)
        .toList(growable: false);
    notifyListeners();

    return product;
  }

  /// ---------------------------------------------------------- Promotions

  Future<void> loadPromotions({String search = ''}) async {
    _promotionsState = LoadState.loading;
    notifyListeners();

    try {
      final json = await _api.get(
        '/admin/promotions',
        query: <String, dynamic>{
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      _promotions = _parseList(json, Promotion.fromJson);
      _promotionsState = LoadState.ready;
    } on Object catch (error) {
      _error = describeError(error);
      _promotionsState = LoadState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<Promotion> createPromotion({
    required String code,
    required String discountType,
    required double discountValue,
    String? name,
    String? description,
    double? maxDiscountAmount,
    double? minOrderAmount,
    int? usageLimit,
    DateTime? startsAt,
    DateTime? endsAt,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final json = await _api.post(
      '/admin/promotions',
      body: <String, dynamic>{
        'code': code,
        'discount_type': discountType,
        'discount_value': discountValue,
        if (name != null && name.isNotEmpty) 'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (maxDiscountAmount != null && maxDiscountAmount > 0)
          'max_discount_amount': maxDiscountAmount,
        if (minOrderAmount != null && minOrderAmount > 0)
          'min_order_amount': minOrderAmount,
        if (usageLimit != null) 'usage_limit': usageLimit,
        if (startsAt != null) 'starts_at': _date(startsAt),
        if (endsAt != null) 'ends_at': _date(endsAt),
        'is_active': isActive,
      },
    );
    final promotion = Promotion.fromJson(parseDataEnvelope(json));
    await loadPromotions();
    return promotion;
  }

  Future<Promotion> updatePromotion(
    int id, {
    required String code,
    required String discountType,
    required double discountValue,
    String? name,
    String? description,
    double? maxDiscountAmount,
    double? minOrderAmount,
    int? usageLimit,
    DateTime? startsAt,
    DateTime? endsAt,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final json = await _api.put(
      '/admin/promotions/$id',
      body: <String, dynamic>{
        'code': code,
        'discount_type': discountType,
        'discount_value': discountValue,
        if (name != null && name.isNotEmpty) 'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (maxDiscountAmount != null && maxDiscountAmount > 0)
          'max_discount_amount': maxDiscountAmount,
        if (minOrderAmount != null && minOrderAmount > 0)
          'min_order_amount': minOrderAmount,
        if (usageLimit != null) 'usage_limit': usageLimit,
        if (startsAt != null) 'starts_at': _date(startsAt),
        if (endsAt != null) 'ends_at': _date(endsAt),
        'is_active': isActive,
      },
    );
    final promotion = Promotion.fromJson(parseDataEnvelope(json));
    await loadPromotions();
    return promotion;
  }

  Future<void> deletePromotion(int id) async {
    await _api.delete('/admin/promotions/$id');
    await loadPromotions();
  }

  /// ---------------------------------------------------------------- Orders

  Future<void> loadOrders({bool reset = true}) async {
    if (_ordersLoading) {
      if (reset) _ordersRefreshQueued = true;
      return;
    }

    _ordersLoading = true;
    if (reset) {
      if (_orders.isEmpty) _state = LoadState.loading;
      _error = null;
    } else {
      if (_ordersLoadingMore) return;
      _ordersLoadingMore = true;
      _error = null;
    }
    notifyListeners();

    try {
      final json = await _api.get(
        '/admin/orders',
        query: <String, dynamic>{
          if (_orderSearch.trim().isNotEmpty) 'search': _orderSearch.trim(),
          if (_orderStatusFilter != null) 'status': _orderStatusFilter!.name,
          if (_paymentFilter != null) 'payment_status': _paymentFilter!.name,
          'page': reset ? 1 : _orderPage + 1,
          'per_page': 15,
        },
      );
      final page = Paginated<Order>.fromJson(json, Order.fromJson);

      _orders = reset ? page.items : <Order>[..._orders, ...page.items];
      _orderPage = page.currentPage;
      _orderLastPage = page.lastPage;
      _state = LoadState.ready;
    } on Object catch (error) {
      _error = describeError(error);
      if (reset && _orders.isEmpty) {
        _state = LoadState.error;
      }
    } finally {
      _ordersLoading = false;
      _ordersLoadingMore = false;
      notifyListeners();
      if (_ordersRefreshQueued) {
        _ordersRefreshQueued = false;
        unawaited(loadOrders());
      }
    }
  }

  Future<void> loadMoreOrders() async {
    if (!hasMoreOrders || _ordersLoadingMore) return;
    await loadOrders(reset: false);
  }

  Future<void> searchOrders(String term) async {
    _orderSearch = term;
    await loadOrders();
  }

  Future<void> filterOrdersByStatus(OrderStatus? status) async {
    _orderStatusFilter = status;
    await loadOrders();
  }

  Future<void> filterOrdersByPayment(PaymentStatus? status) async {
    _paymentFilter = status;
    await loadOrders();
  }

  Future<Order> loadOrder(int id) async {
    final json = await _api.get('/admin/orders/$id');
    final order = Order.fromJson(parseDataEnvelope(json));

    final index = _orders.indexWhere((candidate) => candidate.id == order.id);
    if (index >= 0) {
      _orders = <Order>[
        ..._orders.sublist(0, index),
        order,
        ..._orders.sublist(index + 1),
      ];
      notifyListeners();
    }

    return order;
  }

  Future<Uint8List> loadPaymentReceipt(int id) =>
      _api.getBytes('/admin/orders/$id/payment-receipt');

  Future<Order> updateOrderStatus(int id, OrderStatus status) async {
    final json = await _api.patch(
      '/admin/orders/$id/status',
      body: <String, dynamic>{'status_order': status.name},
    );
    final order = Order.fromJson(parseDataEnvelope(json));
    await loadOrders();
    return order;
  }

  Future<Order> updatePayment(
    int id, {
    required PaymentStatus status,
    String? transactionId,
  }) async {
    final json = await _api.patch(
      '/admin/orders/$id/payment',
      body: <String, dynamic>{
        'payment_status': status.name,
        if (transactionId != null && transactionId.isNotEmpty)
          'transaction_id': transactionId,
      },
    );
    final order = Order.fromJson(parseDataEnvelope(json));
    await loadOrders();
    return order;
  }

  /// --------------------------------------------------------------- Reports

  Future<void> loadReport({
    String? preset,
    DateTime? from,
    DateTime? to,
  }) async {
    _reportLoading = true;
    _error = null;
    notifyListeners();

    try {
      final json = await _api.get(
        '/admin/reports/sales',
        query: <String, dynamic>{
          if (preset != null) 'preset': preset,
          'from': from,
          'to': to,
        },
      );
      _report = SalesReport.fromJson(parseDataEnvelope(json));
    } on Object catch (error) {
      _error = describeError(error);
      _report = null;
    } finally {
      _reportLoading = false;
      notifyListeners();
    }
  }

  /// ------------------------------------------------------------ Audit logs

  Future<void> loadAuditLogs({bool reset = true}) async {
    if (reset) {
      _state = LoadState.loading;
      _error = null;
    } else {
      if (_auditLoadingMore) return;
      _auditLoadingMore = true;
    }
    notifyListeners();

    try {
      final json = await _api.get(
        '/admin/audit-logs',
        query: <String, dynamic>{
          'page': reset ? 1 : _auditPage + 1,
          'per_page': 20,
        },
      );
      final page = Paginated<AuditLogEntry>.fromJson(
        json,
        AuditLogEntry.fromJson,
      );

      _auditLogs = reset
          ? page.items
          : <AuditLogEntry>[..._auditLogs, ...page.items];
      _auditPage = page.currentPage;
      _auditLastPage = page.lastPage;
      _state = LoadState.ready;
    } on Object catch (error) {
      _error = describeError(error);
      if (reset) {
        _state = LoadState.error;
        _auditLogs = const <AuditLogEntry>[];
      }
    } finally {
      _auditLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreAuditLogs() async {
    if (!hasMoreAuditLogs || _auditLoadingMore) return;
    await loadAuditLogs(reset: false);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Non-paginated list payloads (categories, promotions) store the array
  /// directly under `data`.
  static List<T> _parseList<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) => (json['data'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .map(parse)
      .toList(growable: false);

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static const Object _unset = Object();
}
