import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/order_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrderProvider>().loadOrders();
      _startRefreshTimer();
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 300) {
      context.read<OrderProvider>().loadOrders(reset: false);
    }
  }

  Future<void> _openOrder(int orderId) async {
    _refreshTimer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(orderId: orderId),
      ),
    );
    if (!mounted) return;
    final provider = context.read<OrderProvider>();
    await provider.loadOrders(status: provider.statusFilter);
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        final provider = context.read<OrderProvider>();
        provider.loadOrders(status: provider.statusFilter);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final provider = context.read<OrderProvider>();
    provider.loadOrders(status: provider.statusFilter);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: <Widget>[
                _filterChip(provider, null, 'Semua'),
                for (final status in OrderStatus.values)
                  _filterChip(provider, status, status.label),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadOrders(status: provider.statusFilter),
        child: _body(provider),
      ),
    );
  }

  Widget _filterChip(
    OrderProvider provider,
    OrderStatus? status,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: status == provider.statusFilter,
        onSelected: (_) => provider.filterBy(status),
      ),
    );
  }

  Widget _body(OrderProvider provider) {
    if (provider.isLoading && provider.orders.isEmpty) {
      return const LoadingView();
    }
    if (provider.error != null && provider.orders.isEmpty) {
      return ErrorView(
        message: provider.error!,
        onRetry: () => provider.loadOrders(),
      );
    }
    if (provider.orders.isEmpty) {
      return const EmptyState(
        title: 'Belum ada pesanan',
        message: 'Pesanan yang Anda buat akan muncul di sini.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount:
          provider.orders.length +
          (provider.hasMore || provider.isLoadingMore || provider.error != null
              ? 1
              : 0),
      itemBuilder: (context, index) {
        if (index >= provider.orders.length) {
          if (provider.error != null && !provider.isLoadingMore) {
            return TextButton.icon(
              onPressed: () => provider.loadOrders(reset: false),
              icon: const Icon(Icons.refresh),
              label: const Text('Gagal memuat. Coba lagi.'),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final order = provider.orders[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            onTap: () => _openOrder(order.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      '#${order.orderNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    StatusChip(
                      label: order.status.label,
                      color: order.status.colorOf(Theme.of(context).brightness),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(
                      'Pembayaran',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: order.statusPayment.label,
                      color: order.statusPayment.colorOf(
                        Theme.of(context).brightness,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.dateTime(order.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in order.items.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.productName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          Formatters.rupiah(item.subtotal),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if ((order.detailsCount ?? order.items.length) >
                    order.items.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '+${(order.detailsCount ?? order.items.length) - order.items.length} produk lainnya',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                const Divider(height: 20),
                Row(
                  children: <Widget>[
                    const Text('Total', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text(
                      Formatters.rupiah(order.totalAmount),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lets the customer cancel while the order is still pending (BR-08).
Future<void> confirmCancelOrder(BuildContext context, Order order) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Batalkan pesanan?'),
      content: const Text(
        'Stok produk akan dikembalikan. Tindakan ini tidak dapat dibatalkan.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Tidak'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.danger,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Ya, batalkan'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await context.read<OrderProvider>().cancelOrder(order.id);
    if (context.mounted) showSuccess(context, 'Pesanan dibatalkan');
  } on Object catch (error) {
    if (context.mounted) showApiError(context, error);
  }
}
