import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_response.dart';
import '../../models/models.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import '../../widgets/product_card.dart';
import '../catalog/product_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Product> _favorites = const <Product>[];
  bool _loading = true;
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
    });

    try {
      final products = await context.read<CatalogProvider>().favorites();
      if (mounted) setState(() => _favorites = products);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(Product product) async {
    try {
      await context.read<CatalogProvider>().toggleFavorite(product);
      if (mounted) {
        setState(() {
          _favorites = _favorites
              .where((candidate) => candidate.id != product.id)
              .toList(growable: false);
        });
        showSuccess(context, 'Dihapus dari favorit');
      }
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorit Saya')),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _favorites.isEmpty
          ? const EmptyState(
              title: 'Belum ada favorit',
              message:
                  'Tekan ikon hati pada produk untuk menyimpannya di sini.',
              icon: Icons.favorite_border,
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.63,
              ),
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final product = _favorites[index];

                return ProductCard(
                  product: product,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProductDetailScreen(productId: product.id),
                      ),
                    );
                    await _load();
                  },
                  onFavorite: () => _remove(product),
                );
              },
            ),
    );
  }
}
