import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';

import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import 'review_form_sheet.dart';

/// Product detail: gallery-less image, price, stock, description, reviews, and
/// the add-to-cart / buy actions.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  Future<List<Review>>? _reviewsFuture;
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _reviewsFuture = null;
    });

    try {
      final product = await context.read<CatalogProvider>().loadProduct(
        widget.productId,
      );
      if (mounted) {
        setState(() {
          _product = product;
          _reviewsFuture = context.read<OrderProvider>().loadReviews(
            product.id,
          );
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reloadReviews() {
    final product = _product;
    if (product == null) return;

    if (mounted) {
      setState(() {
        _reviewsFuture = context.read<OrderProvider>().loadReviews(product.id);
      });
    }
  }

  Future<void> _addToCart(int quantity) async {
    setState(() => _adding = true);

    try {
      await context.read<CartProvider>().addItem(widget.productId, quantity);
      if (mounted) showSuccess(context, 'Ditambahkan ke keranjang');
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error, field: 'quantity');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final product = _product;
    if (product == null) return;

    try {
      final updated = await context.read<CatalogProvider>().toggleFavorite(
        product,
      );
      if (mounted) setState(() => _product = updated);
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: <Widget>[
          if (product != null)
            IconButton(
              tooltip: product.isFavorite
                  ? 'Hapus dari favorit'
                  : 'Tambah favorit',
              icon: Icon(
                product.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: product.isFavorite ? AppColors.danger : null,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : product == null
          ? ErrorView(
              message: _error ?? 'Produk tidak ditemukan',
              onRetry: _load,
            )
          : _content(product),
      bottomNavigationBar: product == null ? null : _bottomBar(product),
    );
  }

  Widget _content(Product product) {
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: product.imageUrl == null || product.imageUrl!.isEmpty
                ? ColoredBox(
                    color: palette.surfaceAlt,
                    child: Center(
                      child: Icon(
                        Icons.local_florist,
                        size: 56,
                        color: palette.goldText,
                      ),
                    ),
                  )
                : Image.network(
                    AppConfig.resolveApiResource(product.imageUrl!).toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: palette.surfaceAlt,
                      child: Center(
                        child: Icon(
                          Icons.local_florist,
                          size: 56,
                          color: palette.goldText,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        if (product.categoryName != null)
          Text(
            product.categoryName!,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 4),
        Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Text(
              Formatters.rupiah(product.price),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            StatusChip(
              label: product.inStock ? 'Stok ${product.stock}' : 'Stok habis',
              color: product.inStock ? AppColors.success : AppColors.danger,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            const Icon(Icons.star, size: 18, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              product.ratingCount == 0
                  ? 'Belum ada ulasan'
                  : '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount} ulasan)',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (product.description != null &&
            product.description!.isNotEmpty) ...<Widget>[
          Text('Deskripsi', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            product.description!,
            style: const TextStyle(height: 1.5, fontSize: 13),
          ),
          const SizedBox(height: 24),
        ],
        _reviews(product),
      ],
    );
  }

  Widget _reviews(Product product) {
    final palette = context.palette;
    // The backend already decides eligibility and returns `can_rate`.
    final isLoggedIn = context.select<AuthProvider, bool>(
      (provider) => provider.user != null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Ulasan', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (isLoggedIn && product.canRate)
              TextButton(
                onPressed: () async {
                  await showReviewFormSheet(context, product);
                  if (mounted) _reloadReviews();
                },
                child: const Text('Tulis ulasan'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Review>>(
          future: _reviewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Gagal memuat ulasan produk.',
                  style: TextStyle(fontSize: 12),
                ),
              );
            }

            final reviews = snapshot.data ?? const <Review>[];
            if (reviews.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Belum ada ulasan untuk produk ini.',
                  style: TextStyle(fontSize: 12),
                ),
              );
            }

            return Column(
              children: reviews
                  .map(
                    (review) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    review.userName ?? 'Pengguna',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  Formatters.dateTime(review.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: List<Widget>.generate(
                                5,
                                (index) => Icon(
                                  index < review.rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 14,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                            if (review.review != null &&
                                review.review!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                review.review!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _bottomBar(Product product) {
    final inCart = context.select<CartProvider, int>(
      (provider) => provider.quantityOf(product.id),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            if (inCart > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('$inCart di keranjang'),
                ),
              ),
            if (inCart > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: (!product.inStock || _adding)
                    ? null
                    : () => _addToCart(1),
                child: _adding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.charcoal,
                        ),
                      )
                    : Text(
                        product.inStock ? 'Tambah ke keranjang' : 'Stok habis',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
