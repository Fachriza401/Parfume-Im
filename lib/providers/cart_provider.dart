import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_response.dart';
import '../models/models.dart';

/// Cart state. All totals come from the backend so the mobile total can never
/// drift from the checkout total (BR-03).
class CartProvider extends ChangeNotifier {
  CartProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;

  List<CartItem> _items = const <CartItem>[];
  CartSummary _summary = const CartSummary(
    totalItems: 0,
    subtotal: 0,
    discountAmount: 0,
    finalAmount: 0,
  );

  bool _loading = false;
  String? _error;
  int? _busyItemId;
  String? _promotionCode;

  List<CartItem> get items => _items;
  CartSummary get summary => _summary;
  bool get isLoading => _loading;
  String? get error => _error;
  int? get busyItemId => _busyItemId;
  bool get isEmpty => _items.isEmpty;
  bool get hasPromotion => _summary.promotion != null;

  int quantityOf(int productId) {
    for (final item in _items) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _applyCartResponse(await _api.get('/cart'));
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addItem(int productId, int quantity) async {
    await _mutate(
      () => _api.post(
        '/cart',
        body: <String, dynamic>{'product_id': productId, 'quantity': quantity},
      ),
    );
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    _busyItemId = cartItemId;
    notifyListeners();

    try {
      await _mutate(
        () => _api.patch(
          '/cart/$cartItemId',
          body: <String, dynamic>{'quantity': quantity},
        ),
      );
    } finally {
      _busyItemId = null;
      notifyListeners();
    }
  }

  Future<void> removeItem(int cartItemId) async {
    _busyItemId = cartItemId;
    notifyListeners();

    try {
      await _mutate(() => _api.delete('/cart/$cartItemId'));
    } finally {
      _busyItemId = null;
      notifyListeners();
    }
  }

  Future<void> applyPromotion(String code) async {
    await _mutate(
      () => _api.post(
        '/cart/apply-promotion',
        body: <String, dynamic>{'promotion_code': code},
      ),
      reapplyPromotion: false,
    );
    _promotionCode = code.trim();
  }

  Future<void> removePromotion() async {
    _promotionCode = null;
    _error = null;

    // Re-price server-side so the local reset can never disagree with the API.
    await load();
  }

  Future<void> _mutate(
    Future<Map<String, dynamic>> Function() action, {
    bool reapplyPromotion = true,
  }) async {
    _error = null;
    notifyListeners();

    try {
      _applyCartResponse(await action());
      final promotionCode = _promotionCode;
      if (reapplyPromotion && promotionCode != null) {
        _applyCartResponse(
          await _api.post(
            '/cart/apply-promotion',
            body: <String, dynamic>{'promotion_code': promotionCode},
          ),
        );
      }
    } on ApiException catch (error) {
      _error = error.message;
      rethrow;
    }
  }

  void _applyCartResponse(Map<String, dynamic> json) {
    final data = parseDataEnvelope(json);

    _items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CartItem.fromJson)
        .toList(growable: false);

    if (_items.isEmpty) _promotionCode = null;
    _summary = CartSummary.fromJson(data);
    notifyListeners();
  }

  void clear() {
    _items = const <CartItem>[];
    _promotionCode = null;
    _summary = const CartSummary(
      totalItems: 0,
      subtotal: 0,
      discountAmount: 0,
      finalAmount: 0,
    );
    notifyListeners();
  }
}
