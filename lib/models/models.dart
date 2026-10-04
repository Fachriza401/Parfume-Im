/// Data transfer objects mirroring the Laravel API resources.
library;

import 'package:flutter/material.dart' show Brightness, Color;

import '../core/network/api_response.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

/// Reads an int from a JSON value that may be an int, double or string.
int readInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Reads a double from a JSON value that may be a num or a decimal string.
double readDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool readBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

String readString(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;

DateTime? readDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.productCount = 0,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final int productCount;
  final bool isActive;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: readInt(json['id']),
    name: readString(json['name']),
    slug: readString(json['slug']),
    description: json['description'] as String?,
    imageUrl: (json['image'] ?? json['image_url']) as String?,
    productCount: readInt(json['product_count']),
    isActive: readBool(json['is_active'], true),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'slug': slug,
    'description': description,
    'image': imageUrl,
    'product_count': productCount,
    'is_active': isActive,
  };
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    required this.stock,
    this.description,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.categorySlug,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.soldCount = 0,
    this.isActive = true,
    this.isFavorite = false,
    this.canRate = false,
  });

  final int id;
  final String name;
  final String slug;
  final double price;
  final int stock;
  final String? description;
  final String? imageUrl;
  final int? categoryId;
  final String? categoryName;
  final String? categorySlug;
  final double ratingAvg;
  final int ratingCount;
  final int soldCount;
  final bool isActive;
  final bool isFavorite;
  final bool canRate;

  bool get inStock => stock > 0;
  bool get isLowStock => stock > 0 && stock <= 5;

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final categoryId = category is Map<String, dynamic>
        ? readInt(category['id'])
        : readInt(json['category_id']);
    final categoryName = category is Map<String, dynamic>
        ? readString(category['name'])
        : readString(json['category_name']);
    final categorySlug = category is Map<String, dynamic>
        ? readString(category['slug'])
        : readString(json['category_slug']);

    return Product(
      id: readInt(json['id']),
      name: readString(json['name']),
      slug: readString(json['slug']),
      price: readDouble(json['price']),
      stock: readInt(json['stock']),
      description: json['description'] as String?,
      imageUrl: readString(json['image_url']) != ''
          ? readString(json['image_url'])
          : readString(json['image']) != ''
          ? readString(json['image'])
          : readString(json['image_path']),
      categoryId: categoryId == 0 ? null : categoryId,
      categoryName: categoryName.isEmpty ? null : categoryName,
      categorySlug: categorySlug.isEmpty ? null : categorySlug,
      ratingAvg: readDouble(json['rating_avg']),
      ratingCount: readInt(json['rating_count']),
      soldCount: readInt(json['sold_count']),
      isActive: readBool(json['is_active'], true),
      isFavorite: readBool(json['is_favorite']),
      canRate: readBool(json['can_rate']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'slug': slug,
    'price': price,
    'stock': stock,
    'description': description,
    'image_url': imageUrl,
    'category': categoryId == null
        ? null
        : <String, dynamic>{
            'id': categoryId,
            'name': categoryName,
            'slug': categorySlug,
          },
    'rating_avg': ratingAvg,
    'rating_count': ratingCount,
    'sold_count': soldCount,
    'is_active': isActive,
    'is_favorite': isFavorite,
    'can_rate': canRate,
  };

  Product copyWith({bool? isFavorite, bool? canRate}) => Product(
    id: id,
    name: name,
    slug: slug,
    price: price,
    stock: stock,
    description: description,
    imageUrl: imageUrl,
    categoryId: categoryId,
    categoryName: categoryName,
    categorySlug: categorySlug,
    ratingAvg: ratingAvg,
    ratingCount: ratingCount,
    soldCount: soldCount,
    isActive: isActive,
    isFavorite: isFavorite ?? this.isFavorite,
    canRate: canRate ?? this.canRate,
  );
}

class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.subtotal,
  });

  final int id;
  final Product product;
  final int quantity;
  final double subtotal;

  int get productId => product.id;

  /// Unit price snapshot taken when the item entered the cart.
  double get price => product.price;

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: readInt(json['id']),
    product: Product.fromJson(
      (json['product'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    quantity: readInt(json['quantity']),
    subtotal: readDouble(json['subtotal']),
  );
}

class PromotionInfo {
  const PromotionInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.discountType,
    required this.discountValue,
  });

  final int id;
  final String code;
  final String name;
  final String discountType;
  final double discountValue;

  bool get isPercentage => discountType == 'percentage';

  String get label => isPercentage
      ? '$discountValue%'
      : 'Rp${discountValue.toStringAsFixed(0)}';

  factory PromotionInfo.fromJson(Map<String, dynamic> json) => PromotionInfo(
    id: readInt(json['id']),
    code: readString(json['code']),
    name: readString(json['name']),
    discountType: readString(json['discount_type']),
    discountValue: readDouble(json['discount_value']),
  );
}

class CartSummary {
  const CartSummary({
    required this.totalItems,
    required this.subtotal,
    required this.discountAmount,
    required this.finalAmount,
    this.promotion,
  });

  final int totalItems;
  final double subtotal;
  final double discountAmount;
  final double finalAmount;
  final PromotionInfo? promotion;

  factory CartSummary.fromJson(Map<String, dynamic> json) {
    // The cart endpoint nests totals under `summary`; the promotion preview
    // endpoint returns them at the top level.
    final summary = json['summary'] is Map<String, dynamic>
        ? json['summary'] as Map<String, dynamic>
        : json;

    return CartSummary(
      totalItems: readInt(summary['total_items']),
      subtotal: readDouble(summary['subtotal']),
      discountAmount: readDouble(summary['discount_amount']),
      finalAmount: readDouble(summary['final_amount']),
      promotion: json['promotion'] == null
          ? null
          : PromotionInfo.fromJson(json['promotion'] as Map<String, dynamic>),
    );
  }

  CartSummary copyWith({
    int? totalItems,
    double? subtotal,
    double? discountAmount,
    double? finalAmount,
    PromotionInfo? promotion,
    bool clearPromotion = false,
  }) => CartSummary(
    totalItems: totalItems ?? this.totalItems,
    subtotal: subtotal ?? this.subtotal,
    discountAmount: discountAmount ?? this.discountAmount,
    finalAmount: finalAmount ?? this.finalAmount,
    promotion: clearPromotion ? null : (promotion ?? this.promotion),
  );
}

enum OrderStatus {
  pending,
  processing,
  completed,
  cancelled;

  static OrderStatus from(String? value) => OrderStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => OrderStatus.pending,
  );

  String get label => switch (this) {
    OrderStatus.pending => 'Menunggu Pembayaran',
    OrderStatus.processing => 'Diproses',
    OrderStatus.completed => 'Selesai',
    OrderStatus.cancelled => 'Dibatalkan',
  };

  bool get isFinal =>
      this == OrderStatus.completed || this == OrderStatus.cancelled;

  /// Only a pending order can be cancelled (BR-03).
  bool get canCancel => this == OrderStatus.pending;

  /// Legal transitions mirrored from the backend enum (BR-10).
  List<OrderStatus> get allowedTransitions => switch (this) {
    OrderStatus.pending => const <OrderStatus>[
      OrderStatus.processing,
      OrderStatus.cancelled,
    ],
    OrderStatus.processing => const <OrderStatus>[OrderStatus.completed],
    OrderStatus.completed || OrderStatus.cancelled => const <OrderStatus>[],
  };

  Color colorOf(Brightness brightness) => switch (this) {
    OrderStatus.pending => AppPalette.of(brightness).warning,
    OrderStatus.processing => AppPalette.of(brightness).info,
    OrderStatus.completed => AppPalette.of(brightness).success,
    OrderStatus.cancelled => AppPalette.of(brightness).danger,
  };

  String get description => switch (this) {
    OrderStatus.pending => 'Menunggu verifikasi pembayaran oleh admin.',
    OrderStatus.processing => 'Pembayaran terverifikasi, pesanan diproses.',
    OrderStatus.completed => 'Pesanan selesai. Jangan lupa beri ulasan.',
    OrderStatus.cancelled => 'Pesanan dibatalkan dan stok dikembalikan.',
  };
}

enum PaymentStatus {
  unpaid,
  paid,
  refunded;

  static PaymentStatus from(String? value) => PaymentStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => PaymentStatus.unpaid,
  );

  String get label => switch (this) {
    PaymentStatus.unpaid => 'Belum Dibayar',
    PaymentStatus.paid => 'Lunas',
    PaymentStatus.refunded => 'Dikembalikan',
  };

  Color colorOf(Brightness brightness) => switch (this) {
    PaymentStatus.unpaid => AppPalette.of(brightness).warning,
    PaymentStatus.paid => AppPalette.of(brightness).success,
    PaymentStatus.refunded => AppPalette.of(brightness).info,
  };

  /// Legal transitions mirrored from the backend enum.
  List<PaymentStatus> get allowedTransitions => switch (this) {
    PaymentStatus.unpaid => const <PaymentStatus>[PaymentStatus.paid],
    PaymentStatus.paid => const <PaymentStatus>[PaymentStatus.refunded],
    PaymentStatus.refunded => const <PaymentStatus>[],
  };
}

/// Payment snapshot embedded in the order detail resource.
///
/// Accepts both key sets: the shorthand used by cached fixtures
/// (`method`/`reference`) and the canonical [PaymentResource]
/// (`payment_method_label`/`transaction_id`).
class PaymentInfo {
  const PaymentInfo({
    required this.status,
    this.methodLabel,
    this.reference,
    this.paidAt,
    this.amount,
    this.destinationName,
    this.destinationAccount,
    this.destinationAccountName,
    this.receiptUploaded = false,
    this.receiptUploadedAt,
  });

  final PaymentStatus status;
  final String? methodLabel;
  final String? reference;
  final DateTime? paidAt;
  final double? amount;
  final String? destinationName;
  final String? destinationAccount;
  final String? destinationAccountName;
  final bool receiptUploaded;
  final DateTime? receiptUploadedAt;

  String get statusLabel => status.label;

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
    status: PaymentStatus.from(
      json['status'] as String? ?? json['payment_status'] as String?,
    ),
    methodLabel:
        json['method'] as String? ?? json['payment_method_label'] as String?,
    reference:
        json['reference'] as String? ?? json['transaction_id'] as String?,
    paidAt: readDate(json['paid_at']),
    amount: json['amount'] == null ? null : readDouble(json['amount']),
    destinationName: json['destination_name'] as String?,
    destinationAccount: json['destination_account'] as String?,
    destinationAccountName: json['destination_account_name'] as String?,
    receiptUploaded: json['receipt_uploaded'] as bool? ?? false,
    receiptUploadedAt: readDate(json['receipt_uploaded_at']),
  );
}

class PaymentDestination {
  const PaymentDestination({
    required this.code,
    required this.name,
    required this.accountNumber,
    required this.accountName,
    required this.configured,
  });

  final String code;
  final String name;
  final String accountNumber;
  final String accountName;
  final bool configured;

  factory PaymentDestination.fromJson(Map<String, dynamic> json) =>
      PaymentDestination(
        code: readString(json['code']),
        name: readString(json['name']),
        accountNumber: readString(json['account_number']),
        accountName: readString(json['account_name']),
        configured: json['configured'] as bool? ?? false,
      );
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.productId,
    required this.productNameSnapshot,
    required this.priceSnapshot,
    required this.quantity,
    required this.subtotal,
    this.categoryNameSnapshot,
    this.imageUrl,
  });

  final int id;
  final int? productId;
  final String productNameSnapshot;
  final String? categoryNameSnapshot;
  final double priceSnapshot;
  final int quantity;
  final double subtotal;
  final String? imageUrl;

  String get productName => productNameSnapshot;
  double get unitPrice => priceSnapshot;

  factory OrderDetail.fromJson(Map<String, dynamic> json) => OrderDetail(
    id: readInt(json['id']),
    productId: json['product_id'] == null ? null : readInt(json['product_id']),
    productNameSnapshot: readString(json['product_name_snapshot']),
    categoryNameSnapshot: json['category_name_snapshot'] as String?,
    priceSnapshot: readDouble(json['price_snapshot']),
    quantity: readInt(json['quantity']),
    subtotal: readDouble(json['subtotal']),
    imageUrl: json['image_url'] as String?,
  );
}

class Order {
  const Order({
    required this.id,
    required this.orderCode,
    required this.statusOrder,
    required this.statusPayment,
    required this.subtotal,
    required this.discountAmount,
    required this.finalAmount,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    required this.shippingCity,
    required this.shippingPostalCode,
    required this.createdAt,
    this.details = const <OrderDetail>[],
    this.detailsCount,
    this.payment,
    this.note,
    this.completedAt,
    this.cancelledAt,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
  });

  final int id;
  final String orderCode;
  final OrderStatus statusOrder;
  final PaymentStatus statusPayment;
  final double subtotal;
  final double discountAmount;
  final double finalAmount;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final String shippingCity;
  final String shippingPostalCode;
  final String? note;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final List<OrderDetail> details;
  final int? detailsCount;
  final PaymentInfo? payment;

  /// Customer identity, only present on admin responses (BR-08).
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;

  bool get hasCustomer =>
      customerName != null || customerEmail != null || customerPhone != null;

  String get orderNumber => orderCode;
  OrderStatus get status => statusOrder;
  List<OrderDetail> get items => details;
  double get totalAmount => finalAmount;

  int get totalQuantity =>
      details.fold(0, (sum, detail) => sum + detail.quantity);

  factory Order.fromJson(Map<String, dynamic> json) {
    // OrderResource nests the address under `shipping` and the payment under
    // `payment`, while the flat columns are not exposed.
    final shipping = json['shipping'] is Map<String, dynamic>
        ? json['shipping'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return Order(
      id: readInt(json['id']),
      orderCode: readString(json['order_code']),
      statusOrder: OrderStatus.from(json['status_order'] as String?),
      statusPayment: PaymentStatus.from(json['status_payment'] as String?),
      subtotal: readDouble(json['subtotal']),
      discountAmount: readDouble(json['discount_amount']),
      finalAmount: readDouble(json['final_amount']),
      shippingName: readString(shipping['name']),
      shippingPhone: readString(shipping['phone']),
      shippingAddress: readString(shipping['address']),
      shippingCity: readString(shipping['city']),
      shippingPostalCode: readString(shipping['postal_code']),
      note: json['note'] as String?,
      completedAt: readDate(json['completed_at']),
      cancelledAt: readDate(json['cancelled_at']),
      createdAt: readDate(json['created_at']),
      details: (json['details'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(OrderDetail.fromJson)
          .toList(growable: false),
      detailsCount: json['details_count'] == null
          ? null
          : readInt(json['details_count']),
      payment: json['payment'] is Map<String, dynamic>
          ? PaymentInfo.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
      customerName: readString(
        (json['customer'] as Map<String, dynamic>?)?['name'],
      ),
      customerEmail: readString(
        (json['customer'] as Map<String, dynamic>?)?['email'],
      ),
      customerPhone:
          (json['customer'] as Map<String, dynamic>?)?['phone'] as String?,
    );
  }
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    this.review,
    this.userName,
    this.createdAt,
  });

  final int id;
  final int rating;
  final String? review;
  final String? userName;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    final user = json['user'];

    return Review(
      id: readInt(json['id']),
      rating: readInt(json['rating']),
      review: json['review'] as String?,
      userName: user is Map<String, dynamic> ? user['name'] as String? : null,
      createdAt: readDate(json['created_at']),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.data = const <String, dynamic>{},
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  String get message => body;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: readInt(json['id']),
        type: readString(json['type']),
        title: readString(json['title']),
        body: readString(json['body'] ?? json['message']),
        isRead: readBool(json['is_read']),
        createdAt: readDate(json['created_at']),
        data: json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : const <String, dynamic>{},
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    data: data,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.address,
    this.avatarUrl,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? address;
  final String? avatarUrl;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: readInt(json['id']),
    name: readString(json['name']),
    email: readString(json['email']),
    role: readString(json['role'], 'customer'),
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
    'address': address,
    'avatar_url': avatarUrl,
  };
}

/// Session token returned by the auth endpoints.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: readString(json['token']),
    user: AppUser.fromJson(
      (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'user': user.toJson(),
  };
}

/// Full promotion record used by the admin manager; cart totals only use the
/// lighter [PromotionInfo] summary.
class Promotion {
  const Promotion({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.isActive,
    this.name,
    this.description,
    this.maxDiscountAmount,
    this.minOrderAmount = 0,
    this.usageLimit,
    this.usedCount = 0,
    this.startsAt,
    this.endsAt,
    this.imageUrl,
  });

  final int id;
  final String code;
  final String? name;
  final String? description;
  final String discountType;
  final double discountValue;
  final double? maxDiscountAmount;
  final double minOrderAmount;
  final int? usageLimit;
  final int usedCount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? imageUrl;
  final bool isActive;

  String get displayName => (name?.isNotEmpty ?? false) ? name! : code;
  bool get isPercentage => discountType == 'percentage';

  String get discountLabel {
    if (!isPercentage) return Formatters.rupiah(discountValue);
    final cap = maxDiscountAmount;
    return cap == null || cap <= 0
        ? '${discountValue.toStringAsFixed(discountValue % 1 == 0 ? 0 : 1)}%'
        : 's.d. ${Formatters.rupiah(cap)}';
  }

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
    id: readInt(json['id']),
    code: readString(json['code']),
    name: json['name'] as String?,
    description: json['description'] as String?,
    discountType: readString(json['discount_type']),
    discountValue: readDouble(json['discount_value']),
    maxDiscountAmount: json['max_discount_amount'] == null
        ? null
        : readDouble(json['max_discount_amount']),
    minOrderAmount: readDouble(json['min_order_amount']),
    usageLimit: json['usage_limit'] == null
        ? null
        : readInt(json['usage_limit']),
    usedCount: readInt(json['used_count']),
    startsAt: readDate(json['starts_at']),
    endsAt: readDate(json['ends_at']),
    imageUrl: json['image_url'] as String?,
    isActive: readBool(json['is_active'], true),
  );
}

/// One point of the sales-by-date series.
class DailySales {
  const DailySales({
    required this.date,
    required this.orders,
    required this.revenue,
  });

  final DateTime date;
  final int orders;
  final double revenue;

  factory DailySales.fromJson(Map<String, dynamic> json) => DailySales(
    date: DateTime.tryParse(readString(json['date'])) ?? DateTime(0),
    orders: readInt(json['orders']),
    revenue: readDouble(json['revenue']),
  );
}

/// Best-selling product from a period report.
class BestSeller {
  const BestSeller({
    required this.productId,
    required this.name,
    required this.sold,
    required this.revenue,
  });

  final int productId;
  final String name;
  final int sold;
  final double revenue;

  factory BestSeller.fromJson(Map<String, dynamic> json) => BestSeller(
    productId: readInt(json['product_id']),
    name: readString(json['name']),
    sold: readInt(json['sold']),
    revenue: readDouble(json['revenue']),
  );
}

/// Top category from a period report; nullable when the product was deleted.
class TopCategory {
  const TopCategory({
    required this.name,
    required this.sold,
    required this.revenue,
    this.categoryId,
  });

  final int? categoryId;
  final String name;
  final int sold;
  final double revenue;

  factory TopCategory.fromJson(Map<String, dynamic> json) => TopCategory(
    categoryId: json['category_id'] == null
        ? null
        : readInt(json['category_id']),
    name: json['name'] as String? ?? 'Tanpa kategori',
    sold: readInt(json['sold']),
    revenue: readDouble(json['revenue']),
  );
}

/// Latest order row on the admin dashboard.
class RecentOrder {
  const RecentOrder({
    required this.orderCode,
    required this.finalAmount,
    required this.statusOrder,
    required this.statusPayment,
    this.customer,
    this.createdAt,
  });

  final String orderCode;
  final String? customer;
  final double finalAmount;
  final OrderStatus statusOrder;
  final PaymentStatus statusPayment;
  final DateTime? createdAt;

  factory RecentOrder.fromJson(Map<String, dynamic> json) => RecentOrder(
    orderCode: readString(json['order_code']),
    customer: json['customer'] as String?,
    finalAmount: readDouble(json['final_amount']),
    statusOrder: OrderStatus.from(json['status_order'] as String?),
    statusPayment: PaymentStatus.from(json['status_payment'] as String?),
    createdAt: readDate(json['created_at']),
  );
}

/// Payload of `GET /admin/dashboard-stats`.
class AdminStats {
  const AdminStats({
    required this.revenueTotal,
    required this.revenueToday,
    required this.revenueThisMonth,
    required this.ordersTotal,
    required this.ordersPending,
    required this.ordersProcessing,
    required this.ordersCompleted,
    required this.ordersCancelled,
    required this.paymentsUnpaid,
    required this.paymentsPaid,
    required this.paymentsRefunded,
    required this.productsTotal,
    required this.productsActive,
    required this.productsOutOfStock,
    required this.customersTotal,
    required this.customersNewThisMonth,
    required this.averageOrderValue,
    required this.bestSelling,
    required this.topCategories,
    required this.salesByDate,
    required this.recentOrders,
  });

  final double revenueTotal;
  final double revenueToday;
  final double revenueThisMonth;
  final int ordersTotal;
  final int ordersPending;
  final int ordersProcessing;
  final int ordersCompleted;
  final int ordersCancelled;
  final int paymentsUnpaid;
  final int paymentsPaid;
  final int paymentsRefunded;
  final int productsTotal;
  final int productsActive;
  final int productsOutOfStock;
  final int customersTotal;
  final int customersNewThisMonth;
  final double averageOrderValue;
  final List<BestSeller> bestSelling;
  final List<TopCategory> topCategories;
  final List<DailySales> salesByDate;
  final List<RecentOrder> recentOrders;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final revenue = asMap(json['revenue']);
    final orders = asMap(json['orders']);
    final payments = asMap(json['payments']);
    final products = asMap(json['products']);
    final customers = asMap(json['customers']);

    return AdminStats(
      revenueTotal: readDouble(revenue['total']),
      revenueToday: readDouble(revenue['today']),
      revenueThisMonth: readDouble(revenue['this_month']),
      ordersTotal: readInt(orders['total']),
      ordersPending: readInt(orders['pending']),
      ordersProcessing: readInt(orders['processing']),
      ordersCompleted: readInt(orders['completed']),
      ordersCancelled: readInt(orders['cancelled']),
      paymentsUnpaid: readInt(payments['unpaid']),
      paymentsPaid: readInt(payments['paid']),
      paymentsRefunded: readInt(payments['refunded']),
      productsTotal: readInt(products['total']),
      productsActive: readInt(products['active']),
      productsOutOfStock: readInt(products['out_of_stock']),
      customersTotal: readInt(customers['total']),
      customersNewThisMonth: readInt(customers['new_this_month']),
      averageOrderValue: readDouble(json['average_order_value']),
      bestSelling: asList(json['best_selling'])
          .whereType<Map<String, dynamic>>()
          .map(BestSeller.fromJson)
          .toList(growable: false),
      topCategories: asList(json['top_categories'])
          .whereType<Map<String, dynamic>>()
          .map(TopCategory.fromJson)
          .toList(growable: false),
      salesByDate: asList(json['sales_by_date'])
          .whereType<Map<String, dynamic>>()
          .map(DailySales.fromJson)
          .toList(growable: false),
      recentOrders: asList(json['recent_orders'])
          .whereType<Map<String, dynamic>>()
          .map(RecentOrder.fromJson)
          .toList(growable: false),
    );
  }
}

/// Payload of `GET /admin/reports/sales`.
class SalesReport {
  const SalesReport({
    required this.periodFrom,
    required this.periodTo,
    required this.totalSales,
    required this.totalPaidOrders,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.salesByDate,
    required this.bestSelling,
    this.topCategories = const <TopCategory>[],
    this.ordersByStatus = const <OrderStatus, int>{},
  });

  final String periodFrom;
  final String periodTo;
  final double totalSales;
  final int totalPaidOrders;
  final int totalOrders;
  final double averageOrderValue;
  final List<DailySales> salesByDate;
  final List<BestSeller> bestSelling;

  /// Revenue share per category, rendered as a pie chart.
  final List<TopCategory> topCategories;

  /// Order counts per workflow status, rendered as a donut chart.
  final Map<OrderStatus, int> ordersByStatus;

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    final period = asMap(json['period']);

    return SalesReport(
      periodFrom: readString(period['from']),
      periodTo: readString(period['to']),
      totalSales: readDouble(json['total_sales']),
      totalPaidOrders: readInt(json['total_paid_orders']),
      totalOrders: readInt(json['total_orders']),
      averageOrderValue: readDouble(json['average_order_value']),
      salesByDate: asList(json['sales_by_date'])
          .whereType<Map<String, dynamic>>()
          .map(DailySales.fromJson)
          .toList(growable: false),
      bestSelling: asList(json['best_selling'])
          .whereType<Map<String, dynamic>>()
          .map(BestSeller.fromJson)
          .toList(growable: false),
      topCategories: asList(json['top_categories'])
          .whereType<Map<String, dynamic>>()
          .map(TopCategory.fromJson)
          .toList(growable: false),
      ordersByStatus: <OrderStatus, int>{
        for (final entry in asMap(json['orders_by_status']).entries)
          if (OrderStatus.values.any((status) => status.name == entry.key))
            OrderStatus.from(entry.key): readInt(entry.value),
      },
    );
  }
}

/// Row of `GET /admin/audit-logs`.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.module,
    required this.description,
    required this.properties,
    this.userId,
    this.entityType,
    this.entityId,
    this.ipAddress,
    this.userAgent,
    this.createdAt,
  });

  final int id;
  final int? userId;
  final String action;
  final String module;
  final String? entityType;
  final int? entityId;
  final String description;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> properties;
  final DateTime? createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id: readInt(json['id']),
    userId: json['user_id'] == null ? null : readInt(json['user_id']),
    action: readString(json['action']),
    module: readString(json['module']),
    entityType: json['entity_type'] as String?,
    entityId: json['entity_id'] == null ? null : readInt(json['entity_id']),
    description: readString(json['description']),
    ipAddress: json['ip_address'] as String?,
    userAgent: json['user_agent'] as String?,
    properties: asMap(json['properties']),
    createdAt: readDate(json['created_at']),
  );
}
