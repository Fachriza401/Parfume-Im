import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/catalog_provider.dart' show LoadState;
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import 'promotion_form_sheet.dart';

class PromotionsAdminScreen extends StatefulWidget {
  const PromotionsAdminScreen({super.key});

  @override
  State<PromotionsAdminScreen> createState() => _PromotionsAdminScreenState();
}

class _PromotionsAdminScreenState extends State<PromotionsAdminScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminProvider>().loadPromotions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() => context.read<AdminProvider>().loadPromotions();

  Future<void> _openForm([Promotion? promotion]) async {
    final created = await showPromotionFormSheet(context, promotion: promotion);
    if (!mounted) return;
    if (created != null) {
      showSuccess(
        context,
        promotion == null ? 'Promo dibuat' : 'Promo diperbarui',
      );
    }
  }

  Future<void> _delete(Promotion promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus promo?'),
        content: Text(
          'Promo ${promotion.code} akan dihapus dan tidak bisa dipakai lagi.',
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
      await context.read<AdminProvider>().deletePromotion(promotion.id);
      if (mounted) showSuccess(context, 'Promo dihapus');
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final items = provider.promotions;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Promo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.charcoal,
        icon: const Icon(Icons.add),
        label: const Text('Promo'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              controller: _searchController,
              onSubmitted: (value) {
                context.read<AdminProvider>().loadPromotions(
                  search: value.trim(),
                );
              },
              decoration: InputDecoration(
                hintText: 'Cari kode promo',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<AdminProvider>().loadPromotions();
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (provider.promotionsState) {
              LoadState.loading => const LoadingView(),
              LoadState.error => ErrorView(
                message: provider.error ?? 'Gagal memuat promo',
                onRetry: _reload,
              ),
              _ =>
                items.isEmpty
                    ? const EmptyState(
                        title: 'Belum ada promo',
                        message: 'Buat kode promo pertama Anda.',
                        icon: Icons.local_offer_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              _promotionTile(provider, items[index]),
                        ),
                      ),
            },
          ),
        ],
      ),
    );
  }

  Widget _promotionTile(AdminProvider provider, Promotion promotion) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        onTap: () => _openForm(promotion),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      promotion.code,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  StatusChip(
                    label: promotion.isActive ? 'Aktif' : 'Nonaktif',
                    color: promotion.isActive
                        ? palette.success
                        : palette.textSecondary,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openForm(promotion);
                      } else {
                        _delete(promotion);
                      }
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Hapus'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (promotion.description?.isNotEmpty ?? false)
                Text(
                  promotion.description!,
                  style: const TextStyle(fontSize: 11),
                ),
              const SizedBox(height: 6),
              Text(
                'Diskon ${promotion.discountLabel}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (promotion.minOrderAmount > 0)
                Text(
                  'Min. belanja ${Formatters.rupiah(promotion.minOrderAmount)}',
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
              if (promotion.usageLimit != null)
                Text(
                  'Terpakai ${promotion.usedCount}/${promotion.usageLimit}',
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
              if (promotion.startsAt != null || promotion.endsAt != null)
                Text(
                  _validityLabel(promotion),
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _validityLabel(Promotion promotion) {
    final start = promotion.startsAt == null
        ? null
        : Formatters.date(promotion.startsAt);
    final end = promotion.endsAt == null
        ? null
        : Formatters.date(promotion.endsAt);

    if (start != null && end != null) return 'Berlaku $start s.d. $end';
    if (start != null) return 'Mulai $start';
    if (end != null) return 'Berlaku sampai $end';
    return 'Berlaku selamanya';
  }
}
