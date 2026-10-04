import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import '../../widgets/product_card.dart';
import '../../widgets/promo_ticker.dart';
import '../notifications/notifications_screen.dart';
import '../cart/cart_screen.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();

  Timer? _debounce;
  Timer? _promotionRefreshTimer;
  String _sort = 'latest';
  String? _category;
  bool _inStockOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
    _promotionRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<CatalogProvider>().loadPromotions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _promotionRefreshTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<CatalogProvider>().loadPromotions();
    }
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    final catalog = context.read<CatalogProvider>();

    if (catalog.state == LoadState.idle) {
      await catalog.loadProducts();
    }
    if (catalog.categories.isEmpty) await catalog.loadCategories();
    if (catalog.promotions.isEmpty) await catalog.loadPromotions();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<CatalogProvider>().loadMore();
    }
  }

  /// Builds the query from the current widget state so the search term, the
  /// category chip and the sort dropdown can never drift apart.
  ProductQuery _buildQuery() => ProductQuery(
    search: normalizeSearchTerm(_searchController.text),
    category: _category,
    inStock: _inStockOnly ? true : null,
    sort: _sort,
  );

  Future<void> _apply() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    return context.read<CatalogProvider>().applyQuery(_buildQuery());
  }

  /// Waits for a typing pause before hitting the API, so every keystroke does
  /// not spawn a request.
  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _apply();
    });
  }

  void _searchAllProducts(String value) {
    if (value.trim().isNotEmpty && _category != null) {
      setState(() => _category = null);
    }
    _scheduleSearch();
  }

  Future<void> _clearSearch() async {
    _debounce?.cancel();
    _searchController.clear();
    await _apply();
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    );
  }

  Future<void> _toggleFavorite(Product product) async {
    try {
      await context.read<CatalogProvider>().toggleFavorite(product);
    } on Object catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _resetFilters() async {
    _debounce?.cancel();
    setState(() {
      _category = null;
      _inStockOnly = false;
      _sort = 'latest';
    });
    _searchController.clear();
    await context.read<CatalogProvider>().clearFilters();
  }

  /// Tapping a promo copies its code so it can be pasted into the cart, which
  /// is where the customer applies a voucher.
  Future<void> _onPromoTap(Promotion? promotion) async {
    final code = promotion?.code;
    if (code == null || code.isEmpty) {
      _searchFocus.requestFocus();
      return;
    }

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Kode promo $code disalin')));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final cartCount = context.select<CartProvider, int>(
      (cart) => cart.summary.totalItems,
    );
    final unreadCount = context.select<NotificationProvider, int>(
      (notifications) => notifications.unreadCount,
    );
    final palette = context.palette;
    final hasFilters = _category != null || _inStockOnly || _sort != 'latest';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            'assets/images/parfum_im_logo.png',
            filterQuality: FilterQuality.high,
          ),
        ),
        title: const Text(
          'Parfum IM',
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          if (hasFilters)
            IconButton(
              tooltip: 'Atur ulang filter',
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton: cartCount == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CartScreen()),
              ),
              icon: Badge(
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              label: const Text('Keranjang'),
            ),
      body: Column(
        children: <Widget>[
          _searchBar(palette),
          PromoTicker(
            items: catalog.promotions.isNotEmpty
                ? catalog.promotions
                      .asMap()
                      .entries
                      .map(
                        (entry) => PromoTickerItem.fromPromotion(
                          code: entry.value.code,
                          name: entry.value.displayName,
                          description: entry.value.description,
                          discountLabel: entry.value.discountLabel,
                          minOrder: entry.value.minOrderAmount,
                          imageUrl:
                              entry.value.imageUrl ??
                              (catalog.products.isEmpty
                                  ? null
                                  : catalog
                                        .products[entry.key %
                                            catalog.products.length]
                                        .imageUrl),
                        ),
                      )
                      .toList(growable: false)
                : const <PromoTickerItem>[],
            onTap: (index) {
              final list = catalog.promotions;
              _onPromoTap(
                list.isEmpty ? null : list[index.clamp(0, list.length - 1)],
              );
            },
          ),
          _CategoryStrip(
            categories: catalog.categories,
            selected: _category,
            onSelected: (value) {
              setState(() => _category = value);
              _apply();
            },
          ),
          _sortBar(palette),
          Expanded(child: _body(catalog)),
        ],
      ),
    );
  }

  Widget _searchBar(AppPalette palette) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: TextField(
      controller: _searchController,
      focusNode: _searchFocus,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {});
        _searchAllProducts(value);
      },
      onSubmitted: (_) {
        _debounce?.cancel();
        _apply();
      },
      decoration: InputDecoration(
        hintText: 'Cari nama atau aroma parfum',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await _clearSearch();
                  if (mounted) _searchFocus.requestFocus();
                },
              ),
      ),
    ),
  );

  Widget _sortBar(AppPalette palette) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: <Widget>[
        Icon(Icons.swap_vert, size: 16, color: palette.textSecondary),
        const SizedBox(width: 6),
        Text(
          'Urutkan: ',
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
        Expanded(
          child: DropdownButton<String>(
            value: ProductSort.fromKey(_sort).key,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: TextStyle(fontSize: 12, color: palette.textPrimary),
            items: ProductSort.values
                .map(
                  (sort) => DropdownMenuItem<String>(
                    value: sort.key,
                    child: Text(sort.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _sort = value);
              _apply();
            },
          ),
        ),
        FilterChip(
          label: const Text('Stok', style: TextStyle(fontSize: 11)),
          selected: _inStockOnly,
          onSelected: (value) {
            setState(() => _inStockOnly = value);
            _apply();
          },
        ),
      ],
    ),
  );

  Widget _body(CatalogProvider catalog) {
    if (catalog.state == LoadState.loading) return const LoadingView();
    if (catalog.state == LoadState.error) {
      return ErrorView(
        message: catalog.error ?? 'Gagal memuat katalog',
        onRetry: _apply,
      );
    }
    if (catalog.isEmpty) {
      return EmptyState(
        title: 'Produk tidak ditemukan',
        message: 'Muat ulang katalog atau atur ulang filter.',
        icon: Icons.search_off,
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.refresh),
              label: const Text('Muat ulang'),
            ),
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Atur ulang filter'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _apply,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.50,
        ),
        itemCount: catalog.products.length + (catalog.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= catalog.products.length) {
            if (catalog.isLoadingMore) {
              return const Center(child: CircularProgressIndicator());
            }

            final loadMoreError = catalog.loadMoreError;
            if (loadMoreError != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.cloud_off_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loadMoreError,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      TextButton(
                        onPressed: catalog.retryLoadMore,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          }

          final product = catalog.products[index];

          return ProductCard(
            product: product,
            onTap: () => _openProduct(product),
            onFavorite: () => _toggleFavorite(product),
          );
        },
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;

    Category? activeCategory;
    for (final category in categories) {
      if (category.slug == selected) {
        activeCategory = category;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Semua'),
                  selected: selected == null,
                  onSelected: (_) => onSelected(null),
                ),
              ),
              for (final category in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: category.imageUrl == null
                        ? null
                        : CircleAvatar(
                            backgroundColor: Colors.transparent,
                            backgroundImage: NetworkImage(
                              AppConfig.resolveApiResource(
                                category.imageUrl!,
                              ).toString(),
                            ),
                          ),
                    label: Text(category.name),
                    selected: selected == category.slug,
                    onSelected: (_) => onSelected(category.slug),
                  ),
                ),
            ],
          ),
        ),
        if (activeCategory?.description?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: Text(
              activeCategory!.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: palette.textSecondary),
            ),
          ),
      ],
    );
  }
}
