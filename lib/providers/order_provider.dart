 import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_response.dart';
import '../models/models.dart';

/// Checkout, order history, order detail and review submission.
class OrderProvider extends ChangeNotifier {
  OrderProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<Order> _orders = const <Order>[];
  Order? _lastCreatedOrder;
  bool _loading = false;
  bool _loadingMore = false;
  bool _submitting = false;
  String? _error;

  OrderStatus? _statusFilter;
  int _currentPage = 1;
  int _lastPage = 1;

  List<Order> get orders => _orders;
  Order? get lastCreatedOrder => _lastCreatedOrder;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get isSubmitting => _submitting;
  String? get error => _error;
  OrderStatus? get statusFilter => _statusFilter;
  bool get hasMore => _currentPage < _lastPage;

  Future<List<PaymentDestination>> loadPaymentOptions() async {
    final json = await _api.get('/payment-options');
    final data = parseDataEnvelope(json);
    final banks = data['banks'] as List<dynamic>? ?? const <dynamic>[];
    final wallets = data['e_wallets'] as List<dynamic>? ?? const <dynamic>[];

    return <PaymentDestination>[
      ...banks
          .whereType<Map<String, dynamic>>()
          .map(PaymentDestination.fromJson),
      ...wallets
          .whereType<Map<String, dynamic>>()
          .map(PaymentDestination.fromJson),
    ];
  }

  Future<Order> uploadPaymentReceipt(int orderId, String filePath) async {
    await _api.uploadFile(
      '/orders/$orderId/payment-receipt',
      filePath,
      fieldName: 'receipt',
    );
    return loadOrder(orderId);
  }

  Future<void> loadOrders({OrderStatus? status, bool reset = true}) async {
    if (reset) {
      if (_loading) return;
      if (status != null) _statusFilter = status;
      _loading = true;
    } else {
      if (_loadingMore) return;
      _loadingMore = true;
    }
    _error = null;
    notifyListeners();

    try {
      final json = await _api.get(
        '/orders',
        query: <String, dynamic>{
          if (_statusFilter != null) 'status': _statusFilter!.name,
          'page': reset ? 1 : _currentPage + 1,
          'per_page': 15,
        },
      );

      final page = Paginated<Order>.fromJson(json, Order.fromJson);

      _orders = reset ? page.items : <Order>[..._orders, ...page.items];
      _currentPage = page.currentPage;
      _lastPage = page.lastPage;
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> filterBy(OrderStatus? status) {
    _statusFilter = status;
    return loadOrders();
  }

  Future<Order> loadOrder(int id) async {
    final json = await _api.get('/orders/$id');
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

  /// Creates the order; the backend re-prices everything and locks stock.
  Future<Order> checkout({
    required String shippingName,
    required String shippingPhone,
    required String shippingAddress,
    required String shippingCity,
    required String shippingPostalCode,
    required String paymentMethod,
    String? paymentDestinationCode,
    String? note,
    String? promotionCode,
  }) async {
    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      final json = await _api.post(
        '/checkout',
        body: <String, dynamic>{
          'shipping_name': shippingName,
          'shipping_phone': shippingPhone,
          'shipping_address': shippingAddress,
          'shipping_city': shippingCity,
          'shipping_postal_code': shippingPostalCode,
          'payment_method': paymentMethod,
          if (paymentDestinationCode != null)
            'payment_destination_code': paymentDestinationCode,
          if (note != null && note.isNotEmpty) 'note': note,
          if (promotionCode != null && promotionCode.isNotEmpty)
            'promotion_code': promotionCode,
        },
      );

      final order = Order.fromJson(parseDataEnvelope(json));
      _lastCreatedOrder = order;
      return order;
    } on ApiException catch (error) {
      _error = error.message;
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> submitReview({
    required int productId,
    required int rating,
    String? review,
  }) async {
    await _api.post(
      '/products/$productId/rating',
      body: <String, dynamic>{
        'rating': rating,
        if (review != null && review.isNotEmpty) 'review': review,
      },
    );
  }

  /// Cancellation is only valid while the order is pending; the backend
  /// restores stock inside the same transaction.
  Future<void> cancelOrder(int id) async {
    await _api.post('/orders/$id/cancel');
    await loadOrder(id);
    await loadOrders(status: _statusFilter);
  }

  Future<List<Review>> loadReviews(int productId, {int page = 1}) async {
    final json = await _api.get(
      '/products/$productId/reviews',
      query: <String, dynamic>{'page': page, 'per_page': 20},
    );

    return Paginated<Review>.fromJson(json, Review.fromJson).items;
  }

  void clearLastCreatedOrder() {
    _lastCreatedOrder = null;
  }
}
