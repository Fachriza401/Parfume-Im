import 'package:flutter_test/flutter_test.dart';
import 'package:parfum_im/models/models.dart';

void main() {
  group('Product', () {
    test('parses a nested category and coerces numeric strings', () {
      final product = Product.fromJson(<String, dynamic>{
        'id': 3,
        'name': 'Baccarat Rouge 540',
        'slug': 'baccarat-rouge-540',
        'price': '1250000.50',
        'stock': 7,
        'category': <String, dynamic>{
          'id': 1,
          'name': 'Eau de Parfum',
          'slug': 'edp',
        },
        'rating_avg': '4.75',
        'rating_count': '12',
        'sold_count': 30,
        'is_active': 1,
        'is_favorite': 0,
        'can_rate': true,
      });

      expect(product.price, 1250000.5);
      expect(product.categoryName, 'Eau de Parfum');
      expect(product.categorySlug, 'edp');
      expect(product.ratingAvg, 4.75);
      expect(product.isActive, isTrue);
      expect(product.isFavorite, isFalse);
      expect(product.canRate, isTrue);
      expect(product.inStock, isTrue);
      expect(product.isLowStock, isFalse);
    });

    test('reports low and out-of-stock states', () {
      final low = Product.fromJson(<String, dynamic>{'id': 1, 'stock': 3});
      final none = Product.fromJson(<String, dynamic>{'id': 2, 'stock': 0});

      expect(low.isLowStock, isTrue);
      expect(low.inStock, isTrue);
      expect(none.inStock, isFalse);
      expect(none.isLowStock, isFalse);
    });

    test('copyWith only overrides the favorite flag', () {
      final product = Product.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Test',
        'price': 1000,
        'stock': 5,
        'is_favorite': false,
      });

      final favorited = product.copyWith(isFavorite: true);

      expect(favorited.isFavorite, isTrue);
      expect(favorited.name, 'Test');
      expect(favorited.price, 1000);
      // The original instance is untouched, so optimistic UI cannot corrupt state.
      expect(product.isFavorite, isFalse);
    });
  });

  group('CartSummary', () {
    test('prefers the nested summary block and keeps the promotion', () {
      final summary = CartSummary.fromJson(<String, dynamic>{
        'items': <dynamic>[],
        'summary': <String, dynamic>{
          'total_items': 3,
          'subtotal': 500000.0,
          'discount_amount': 50000.0,
          'final_amount': 450000.0,
        },
        'promotion': <String, dynamic>{
          'id': 2,
          'code': 'WELCOME10',
          'name': 'Diskon Pembeli Baru',
          'discount_type': 'percentage',
          'discount_value': 10,
        },
      });

      expect(summary.totalItems, 3);
      expect(summary.subtotal, 500000);
      expect(summary.discountAmount, 50000);
      expect(summary.finalAmount, 450000);
      expect(summary.promotion?.code, 'WELCOME10');
      expect(summary.promotion?.isPercentage, isTrue);
      expect(summary.promotion?.label, '10.0%');
    });

    test('clearPromotion drops the promotion', () {
      const summary = CartSummary(
        totalItems: 1,
        subtotal: 100,
        discountAmount: 10,
        finalAmount: 90,
        promotion: PromotionInfo(
          id: 1,
          code: 'X',
          name: 'X',
          discountType: 'fixed',
          discountValue: 10,
        ),
      );

      final cleared = summary.copyWith(clearPromotion: true);

      expect(cleared.promotion, isNull);
      expect(cleared.subtotal, 100);
    });
  });

  group('CartItem', () {
    test('exposes the unit price from the embedded product', () {
      final item = CartItem.fromJson(<String, dynamic>{
        'id': 4,
        'quantity': 2,
        'subtotal': 550000.0,
        'product': <String, dynamic>{
          'id': 9,
          'name': 'Aroma',
          'price': 275000.0,
          'stock': 10,
        },
      });

      expect(item.productId, 9);
      expect(item.price, 275000);
      expect(item.subtotal, 550000);
      expect(item.quantity, 2);
    });
  });

  group('Order', () {
    test('parses nested shipping and payment resources', () {
      final order = Order.fromJson(<String, dynamic>{
        'id': 12,
        'order_code': 'PRF-20260101-0001',
        'status_order': 'completed',
        'status_payment': 'paid',
        'subtotal': 300000.0,
        'discount_amount': 30000.0,
        'final_amount': 270000.0,
        'shipping': <String, dynamic>{
          'name': 'Budi Santoso',
          'phone': '08123456789',
          'address': 'Jl. Melati No. 10',
          'city': 'Bandung',
          'postal_code': '40115',
        },
        'note': 'Titip di pos satpam',
        'created_at': '2026-01-01T10:00:00.000000Z',
        'details': <dynamic>[
          <String, dynamic>{
            'id': 1,
            'product_id': 9,
            'product_name_snapshot': 'Aroma',
            'price_snapshot': 150000.0,
            'quantity': 2,
            'subtotal': 300000.0,
          },
        ],
        'payment': <String, dynamic>{
          'status': 'paid',
          'method': 'transfer',
          'reference': 'TRX-123',
          'paid_at': '2026-01-01T11:00:00.000000Z',
        },
      });

      expect(order.orderNumber, 'PRF-20260101-0001');
      expect(order.status, OrderStatus.completed);
      expect(order.totalAmount, 270000);
      expect(order.shippingName, 'Budi Santoso');
      expect(order.shippingCity, 'Bandung');
      expect(order.shippingPostalCode, '40115');
      expect(order.note, 'Titip di pos satpam');
      expect(order.items, hasLength(1));
      expect(order.items.first.productName, 'Aroma');
      expect(order.items.first.unitPrice, 150000);
      expect(order.totalQuantity, 2);
      expect(order.payment?.status, PaymentStatus.paid);
      expect(order.payment?.reference, 'TRX-123');
      expect(order.payment?.statusLabel, 'Lunas');
    });

    test('only a pending order can be cancelled', () {
      expect(OrderStatus.pending.canCancel, isTrue);
      expect(OrderStatus.processing.canCancel, isFalse);
      expect(OrderStatus.completed.canCancel, isFalse);
      expect(OrderStatus.cancelled.canCancel, isFalse);
    });

    test('unknown status values degrade to pending', () {
      expect(OrderStatus.from('nonsense'), OrderStatus.pending);
      expect(PaymentStatus.from('nonsense'), PaymentStatus.unpaid);
    });
  });

  group('AppUser and AuthSession', () {
    test('round-trips through toJson for local storage', () {
      const user = AppUser(
        id: 1,
        name: 'Sari',
        email: 'sari@example.test',
        role: 'customer',
        phone: '0812000000',
        address: 'Jl. Kenari 3',
      );

      final restored = AppUser.fromJson(user.toJson());

      expect(restored.name, 'Sari');
      expect(restored.phone, '0812000000');
      expect(restored.address, 'Jl. Kenari 3');
      expect(restored.isAdmin, isFalse);
    });

    test('reads the token and user from the auth payload', () {
      final session = AuthSession.fromJson(<String, dynamic>{
        'token': '1|abcdef',
        'user': <String, dynamic>{
          'id': 2,
          'name': 'Admin',
          'email': 'admin@parfumim.test',
          'role': 'admin',
        },
      });

      expect(session.token, '1|abcdef');
      expect(session.user.isAdmin, isTrue);
    });
  });

  group('Review', () {
    test('reads the author name from the nested user', () {
      final review = Review.fromJson(<String, dynamic>{
        'id': 5,
        'rating': 5,
        'review': 'Wangi banget',
        'user': <String, dynamic>{'id': 3, 'name': 'Dewi'},
      });

      expect(review.rating, 5);
      expect(review.userName, 'Dewi');
      expect(review.review, 'Wangi banget');
    });
  });
}
