import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/catalog_provider.dart' show LoadState;
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import 'category_form_sheet.dart';

class CategoriesAdminScreen extends StatefulWidget {
  const CategoriesAdminScreen({super.key});

  @override
  State<CategoriesAdminScreen> createState() => _CategoriesAdminScreenState();
}

class _CategoriesAdminScreenState extends State<CategoriesAdminScreen> {
  final _searchController = TextEditingController();

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Re-runs with the filters already stored on the provider, so the typed term
  /// survives a pull-to-refresh or a delete.
  Future<void> _reload() => context.read<AdminProvider>().loadCategories();

  void _onSearchChanged(String term) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<AdminProvider>().loadCategories(search: term);
    });
  }

  Future<void> _clearSearch() async {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    await context.read<AdminProvider>().loadCategories(search: '');
  }

  Future<void> _openForm([Category? category]) async {
    final created = await showCategoryFormSheet(context, category: category);
    if (!mounted) return;
    if (created != null) {
      showSuccess(
        context,
        category == null ? 'Kategori dibuat' : 'Kategori diperbarui',
      );
    }
  }

  Future<void> _delete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text(
          'Kategori "${category.name}" akan dihapus. '
          'Kategori yang masih memiliki produk tidak dapat dihapus.',
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
      await context.read<AdminProvider>().deleteCategory(category.id);
      if (mounted) showSuccess(context, 'Kategori dihapus');
    } on Object catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final palette = context.palette;
    final state = provider.categoriesState;
    final items = provider.categories;
    final filtering = provider.categoryFilters.search.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.gold,
        foregroundColor: palette.onGold,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                _debounce?.cancel();
                context.read<AdminProvider>().loadCategories(search: value);
              },
              decoration: InputDecoration(
                hintText: 'Cari kategori',
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
          Expanded(
            child: switch (state) {
              LoadState.loading => const LoadingView(),
              LoadState.error => ErrorView(
                message: provider.categoriesError ?? 'Gagal memuat kategori',
                onRetry: _reload,
              ),
              _ =>
                items.isEmpty
                    ? EmptyState(
                        title: filtering
                            ? 'Kategori tidak ditemukan'
                            : 'Belum ada kategori',
                        message: filtering
                            ? 'Coba kata kunci lain.'
                            : 'Tambahkan kategori pertama Anda.',
                        icon: Icons.category_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final category = items[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SectionCard(
                                onTap: () => _openForm(category),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child:
                                          category.imageUrl == null ||
                                              category.imageUrl!.isEmpty
                                          ? ColoredBox(
                                              color: AppColors.gold.withValues(
                                                alpha: 0.16,
                                              ),
                                              child: const Icon(
                                                Icons.category_outlined,
                                                size: 20,
                                                color: AppColors.gold,
                                              ),
                                            )
                                          : Image.network(
                                              AppConfig.resolveApiResource(
                                                category.imageUrl!,
                                              ).toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Icon(
                                                    Icons.broken_image_outlined,
                                                    size: 20,
                                                    color: AppColors.gold,
                                                  ),
                                            ),
                                    ),
                                  ),
                                  title: Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${category.productCount} produk',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      StatusChip(
                                        label: category.isActive
                                            ? 'Aktif'
                                            : 'Nonaktif',
                                        color: category.isActive
                                            ? palette.success
                                            : palette.textSecondary,
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _openForm(category);
                                          } else {
                                            _delete(category);
                                          }
                                        },
                                        itemBuilder: (_) =>
                                            const <PopupMenuEntry<String>>[
                                              PopupMenuItem<String>(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'delete',
                                                child: Text('Hapus'),
                                              ),
                                            ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            },
          ),
        ],
      ),
    );
  }
}
