import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/catalog_provider.dart' show LoadState;
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import 'product_form_screen.dart';
import 'product_stock_sheet.dart';

class ProductsAdminScreen extends StatefulWidget {
  const ProductsAdminScreen({super.key});

  @override
  State<ProductsAdminScreen> createState() => _ProductsAdminScreenState();
}

class _ProductsAdminScreenState extends State<ProductsAdminScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _debounce;

  /// Null = semua, true = aktif saja, false = nonaktif saja.
  bool? _activeFilter;

  /// Null = semua kategori.
  int? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final admin = context.read<AdminProvider>();
      admin.loadProducts();
      admin.loadCategories();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 300) {
      context.read<AdminProvider>().loadMoreProducts();
    }
  }

  /// Pull-to-refresh keeps whatever the admin typed instead of wiping it.
  Future<void> _reload() => context.read<AdminProvider>().loadProducts();

  Future<void> _applySearch(String term) =>
      context.read<AdminProvider>().searchProducts(term);

  /// Debounced so a fast typist does not fire a request per keystroke.
  void _onSearchChanged(String term) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _applySearch(term);
    });
  }

  Future<void> _clearSearch() async {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    await _applySearch('');
  }

  Future<void> _setActiveFilter(bool? value) async {
    setState(() => _activeFilter = value);
    await context.read<AdminProvider>().filterProductsByActive(value);
  }

  Future<void> _setCategoryFilter(int? value) async {
    setState(() => _categoryFilter = value);
    await context.read<AdminProvider>().filterProductsByCategory(value);
  }

  Future<void> _openForm([Product? product]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
  }

  Future<void> _openStock(Product product) async {
    await showProductStockSheet(context, product: product);
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text(
          '"${product.name}" akan dihapus dari katalog. '
          'Riwayat pesanan tetap tersimpan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AdminProvider>().deleteProduct(product.id);
      if (mounted) showSuccess(context, 'Produk dihapus');
    } on Object catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final palette = context.palette;
    final items = provider.products;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Produk')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Produk'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                _debounce?.cancel();
                _applySearch(value);
              },
              decoration: InputDecoration(
                hintText: 'Cari nama produk, deskripsi atau kategori',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close),
                        onPressed: _clearSearch,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                _filterChip(
                  'Semua',
                  _activeFilter == null,
                  () => _setActiveFilter(null),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Aktif',
                  _activeFilter == true,
                  () => _setActiveFilter(true),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Nonaktif',
                  _activeFilter == false,
                  () => _setActiveFilter(false),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.category_outlined,
                  size: 16,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int?>(
                    value: _categoryFilter,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    hint: Text(
                      'Semua kategori',
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                    style: TextStyle(fontSize: 12, color: palette.textPrimary),
                    items: <DropdownMenuItem<int?>>[
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Semua kategori',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      for (final category in provider.categories)
                        DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                    ],
                    onChanged: _setCategoryFilter,
                  ),
                ),
                Text(
                  '${provider.productTotal} produk',
                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: switch (provider.state) {
              LoadState.loading => const LoadingView(),
              LoadState.error => ErrorView(
                message: provider.error ?? 'Gagal memuat produk',
                onRetry: _reload,
              ),
              _ =>
                items.isEmpty
                    ? EmptyState(
                        title: provider.productFilters.isDefault
                            ? 'Belum ada produk'
                            : 'Produk tidak ditemukan',
                        message: provider.productFilters.isDefault
                            ? 'Tambahkan produk pertama Anda.'
                            : 'Coba kata kunci atau filter lain.',
                        icon: Icons.sell_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount:
                              items.length + (provider.hasMoreProducts ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= items.length) {
                              if (provider.isLoadingMoreProducts) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final loadMoreError =
                                  provider.productsLoadMoreError;
                              if (loadMoreError != null) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          loadMoreError,
                                          style: TextStyle(
                                            color: palette.danger,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            provider.retryLoadMoreProducts,
                                        child: const Text('Coba lagi'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return const SizedBox.shrink();
                            }
                            return _productTile(provider, items[index]);
                          },
                        ),
                      ),
            },
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _productTile(AdminProvider provider, Product product) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        onTap: () => _openForm(product),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: product.imageUrl == null || product.imageUrl!.isEmpty
                  ? ColoredBox(
                      color: AppColors.gold.withValues(alpha: 0.14),
                      child: const Icon(
                        Icons.spa_outlined,
                        size: 22,
                        color: AppColors.gold,
                      ),
                    )
                  : Image.network(
                      AppConfig.resolveApiResource(
                        product.imageUrl!,
                      ).toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: AppColors.gold.withValues(alpha: 0.14),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 22,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
            ),
          ),
          title: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${Formatters.rupiah(product.price)} • ${product.categoryName ?? 'Tanpa kategori'}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  _stockBadge(product),
                  const SizedBox(width: 8),
                  if (!product.isActive)
                    StatusChip(label: 'Nonaktif', color: palette.textSecondary),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openForm(product);
                case 'stock':
                  _openStock(product);
                case 'delete':
                  _delete(product);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
              PopupMenuItem<String>(value: 'stock', child: Text('Stok')),
              PopupMenuItem<String>(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockBadge(Product product) {
    final palette = context.palette;
    final low = product.stock > 0 && product.stock <= 5;
    final none = product.stock == 0;

    final color = none
        ? palette.danger
        : low
        ? palette.warning
        : palette.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Stok ${product.stock}',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
