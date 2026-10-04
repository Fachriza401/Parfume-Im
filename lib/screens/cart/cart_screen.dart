import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';

import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import '../catalog/product_detail_screen.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _updateQuantity(
    BuildContext context,
    CartItem item,
    int quantity,
  ) async {
    if (quantity <= 0) {
      await _remove(context, item);
      return;
    }

    try {
      await context.read<CartProvider>().updateQuantity(item.id, quantity);
    } on ApiException catch (error) {
      if (context.mounted) showApiError(context, error, field: 'quantity');
    }
  }

  Future<void> _remove(BuildContext context, CartItem item) async {
    try {
      await context.read<CartProvider>().removeItem(item.id);
      if (context.mounted) {
        showSuccess(context, 'Produk dihapus dari keranjang');
      }
    } on ApiException catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }

  Future<void> _applyPromotion(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _PromotionDialog(),
    );

    if (code == null || code.trim().isEmpty || !context.mounted) return;

    try {
      await context.read<CartProvider>().applyPromotion(code.trim());
      if (context.mounted) showSuccess(context, 'Promo diterapkan');
    } on ApiException catch (error) {
      if (context.mounted) {
        showApiError(context, error, field: 'promotion_code');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      body: cart.isLoading
          ? const LoadingView()
          : cart.isEmpty
          ? EmptyState(
              title: 'Keranjang masih kosong',
              message: 'Tambahkan produk pilihan Anda untuk memulai pesanan.',
              icon: Icons.shopping_bag_outlined,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: <Widget>[
                for (final item in cart.items)
                  _CartTile(
                    item: item,
                    busy: cart.busyItemId == item.id,
                    onIncrease: () =>
                        _updateQuantity(context, item, item.quantity + 1),
                    onDecrease: () =>
                        _updateQuantity(context, item, item.quantity - 1),
                    onRemove: () => _remove(context, item),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProductDetailScreen(productId: item.product.id),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _PromotionTile(
                  summary: cart.summary,
                  onApply: () => _applyPromotion(context),
                  onRemove: () async {
                    try {
                      await context.read<CartProvider>().removePromotion();
                    } on ApiException catch (error) {
                      if (context.mounted) {
                        showApiError(context, error, field: 'promotion_code');
                      }
                    }
                  },
                ),
              ],
            ),
      bottomNavigationBar:
          cart.isEmpty || (context.watch<AuthProvider>().user?.isAdmin ?? false)
          ? null
          : _SummaryBar(cart: cart),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.item,
    required this.busy,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onTap,
  });

  final CartItem item;
  final bool busy;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: product.imageUrl == null || product.imageUrl!.isEmpty
                    ? ColoredBox(
                        color: palette.surfaceAlt,
                        child: Icon(
                          Icons.local_florist,
                          color: palette.goldText,
                        ),
                      )
                    : Image.network(
                        AppConfig.resolveApiResource(
                          product.imageUrl!,
                        ).toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => ColoredBox(
                          color: palette.surfaceAlt,
                          child: Icon(
                            Icons.local_florist,
                            color: palette.goldText,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.rupiah(item.price),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: busy ? null : onDecrease,
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: busy || item.quantity >= product.stock
                            ? null
                            : onIncrease,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: busy ? null : onRemove,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  if (item.quantity >= product.stock)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'Maksimal stok tersedia',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionTile extends StatelessWidget {
  const _PromotionTile({
    required this.summary,
    required this.onApply,
    required this.onRemove,
  });

  final CartSummary summary;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final promotion = summary.promotion;
    final palette = context.palette;

    return SectionCard(
      child: Row(
        children: <Widget>[
          Icon(Icons.local_offer_outlined, color: palette.goldText),
          const SizedBox(width: 12),
          Expanded(
            child: promotion == null
                ? const Text(
                    'Punya kode promo? Terapkan di sini',
                    style: TextStyle(fontSize: 13),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        promotion.code,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.success,
                        ),
                      ),
                      Text(
                        'Hemat ${Formatters.rupiah(summary.discountAmount)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
          TextButton(
            onPressed: promotion == null ? onApply : onRemove,
            child: Text(promotion == null ? 'Terapkan' : 'Hapus'),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    final summary = cart.summary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _row('Subtotal', Formatters.rupiah(summary.subtotal)),
            if (summary.discountAmount > 0)
              _row(
                'Diskon',
                '-${Formatters.rupiah(summary.discountAmount)}',
                valueColor: AppColors.success,
              ),
            const Divider(height: 16),
            _row('Total', Formatters.rupiah(summary.finalAmount), bold: true),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CheckoutScreen(),
                  ),
                ),
                child: const Text('Lanjut ke Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : null,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: bold ? 16 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: valueColor,
        ),
      ),
    ],
  );
}

class _PromotionDialog extends StatefulWidget {
  const _PromotionDialog();

  @override
  State<_PromotionDialog> createState() => _PromotionDialogState();
}

class _PromotionDialogState extends State<_PromotionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kode promo'),
      content: TextField(
        controller: _controller,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          hintText: 'Contoh: WELCOME10',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final code = _controller.text.trim();
            if (code.isEmpty) return;
            Navigator.of(context).pop(code);
          },
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}
