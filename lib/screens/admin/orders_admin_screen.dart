import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/catalog_provider.dart' show LoadState;
import '../../widgets/common.dart';
import 'order_admin_detail_screen.dart';

class OrdersAdminScreen extends StatefulWidget {
  const OrdersAdminScreen({super.key});

  @override
  State<OrdersAdminScreen> createState() => _OrdersAdminScreenState();
}

class _OrdersAdminScreenState extends State<OrdersAdminScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminProvider>().loadOrders();
      _startRefreshTimer();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 300) {
      context.read<AdminProvider>().loadMoreOrders();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() => context.read<AdminProvider>().loadOrders();

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _reload();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _reload();
  }

  Future<void> _openDetail(int orderId) async {
    _refreshTimer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderAdminDetailScreen(orderId: orderId),
      ),
    );
    if (mounted) {
      await _reload();
      _startRefreshTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final items = provider.orders;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pesanan')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onSubmitted: (value) {
                context.read<AdminProvider>().searchOrders(value.trim());
              },
              decoration: InputDecoration(
                hintText: 'Cari kode pesanan atau email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<AdminProvider>().searchOrders('');
                  },
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            key: const PageStorageKey<String>('order-status-filter'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                _statusChip(
                  'Semua',
                  provider.orderStatusFilter == null,
                  () =>
                      context.read<AdminProvider>().filterOrdersByStatus(null),
                ),
                for (final status in OrderStatus.values) ...<Widget>[
                  const SizedBox(width: 8),
                  _statusChip(
                    status.label,
                    provider.orderStatusFilter == status,
                    () => context.read<AdminProvider>().filterOrdersByStatus(
                      status,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  'Pembayaran:',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<PaymentStatus?>(
                  value: provider.paymentFilter,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Semua', style: TextStyle(fontSize: 12)),
                  items: <DropdownMenuItem<PaymentStatus?>>[
                    const DropdownMenuItem<PaymentStatus?>(
                      value: null,
                      child: Text('Semua', style: TextStyle(fontSize: 12)),
                    ),
                    for (final status in PaymentStatus.values)
                      DropdownMenuItem<PaymentStatus?>(
                        value: status,
                        child: Text(
                          status.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    context.read<AdminProvider>().filterOrdersByPayment(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: switch (provider.state) {
              LoadState.loading => const LoadingView(),
              LoadState.error => ErrorView(
                message: provider.error ?? 'Gagal memuat pesanan',
                onRetry: _reload,
              ),
              _ =>
                items.isEmpty
                    ? const EmptyState(
                        title: 'Belum ada pesanan',
                        message: 'Pesanan pelanggan akan tampil di sini.',
                        icon: Icons.receipt_long_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount:
                              items.length +
                              (provider.hasMoreOrders || provider.error != null
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            if (index >= items.length) {
                              if (provider.error != null &&
                                  !provider.isLoadingMoreOrders) {
                                return TextButton.icon(
                                  onPressed: _reload,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Gagal memuat. Coba lagi.'),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final order = items[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SectionCard(
                                onTap: () => _openDetail(order.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              '#${order.orderNumber}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            Formatters.dateTime(
                                              order.createdAt,
                                            ),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  context.palette.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        order.customerEmail ??
                                            order.customerName ??
                                            '-',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: <Widget>[
                                          StatusChip(
                                            label: order.status.label,
                                            color: order.status.colorOf(
                                              Theme.of(context).brightness,
                                            ),
                                          ),
                                          StatusChip(
                                            label: order.statusPayment.label,
                                            color: order.statusPayment.colorOf(
                                              Theme.of(context).brightness,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          Formatters.rupiah(order.totalAmount),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
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

  Widget _statusChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
