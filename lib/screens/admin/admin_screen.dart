import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart' show LoadState;
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import 'categories_admin_screen.dart';
import 'promotions_admin_screen.dart';
import 'products_admin_screen.dart';

/// Admin dashboard, rendered only for sessions with the admin role.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.onOpenOrders});

  final VoidCallback? onOpenOrders;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminProvider>().loadDashboard();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _reload(),
      );
    });
  }

  Future<void> _reload() => context.read<AdminProvider>().loadDashboard();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final stats = provider.stats;

    if (stats == null && provider.dashboardState == LoadState.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard Admin')),
        body: const LoadingView(),
      );
    }

    if (stats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard Admin')),
        body: ErrorView(
          message: provider.dashboardError ?? 'Gagal memuat data',
          onRetry: _reload,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Admin')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _greeting(context),
            const SizedBox(height: 12),
            _revenueCard(stats),
            const SizedBox(height: 12),
            _activityLineChart(stats),
            const SizedBox(height: 12),
            _activityBarChart(stats),
            const SizedBox(height: 12),
            _categoryPieChart(stats),
            const SizedBox(height: 12),
            _orderStatusPieChart(stats),
            const SizedBox(height: 12),
            _ordersCard(stats),
            const SizedBox(height: 12),
            _recentOrdersCard(stats),
            const SizedBox(height: 12),
            _storeCard(stats),
            const SizedBox(height: 12),
            _managementCard(context),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await _confirmLogout(context);
                if (confirmed == true && context.mounted) {
                  await context.read<AuthProvider>().logout();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.palette.danger,
                side: BorderSide(color: context.palette.danger),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Keluar Admin'),
            ),
          ],
        ),
      ),
    );
  }

  /// Grafik garis: tren pendapatan harian.
  Widget _activityLineChart(AdminStats stats) {
    final palette = context.palette;
    final series = dailySalesSeries(stats.salesByDate, palette);

    return LineChartCard(
      title: 'Aktivitas Pembelian — Grafik Garis',
      subtitle: 'Pendapatan harian (30 hari terakhir)',
      labels: series.labels,
      series: <LineSeries>[series.revenue],
      emptyMessage: 'Belum ada penjualan pada 30 hari terakhir.',
    );
  }

  /// Grafik batang: jumlah pesanan per hari.
  Widget _activityBarChart(AdminStats stats) {
    final colors = defaultSeriesColors(context.palette);
    final ordered = stats.salesByDate.reversed.toList(growable: false);

    return BarChartCard(
      title: 'Aktivitas Pembelian — Grafik Batang',
      subtitle: 'Jumlah pesanan per hari',
      slices: <ChartSlice>[
        for (var i = 0; i < ordered.length; i++)
          ChartSlice(
            label: Formatters.date(ordered[i].date),
            value: ordered[i].orders.toDouble(),
            color: colors[i % colors.length],
          ),
      ],
      valueFormatter: (value) => value.toStringAsFixed(0),
      emptyMessage: 'Belum ada pesanan pada 30 hari terakhir.',
    );
  }

  /// Grafik lingkaran: pangsa pendapatan per kategori produk.
  Widget _categoryPieChart(AdminStats stats) {
    final palette = context.palette;

    return PieChartCard(
      title: 'Aktivitas Pembelian — Grafik Lingkaran',
      subtitle: 'Porsi pendapatan berdasarkan kategori produk',
      slices: ChartSlice.fromCategories(stats.topCategories, palette),
      centerLabel: 'Kategori',
      centerValue: '${stats.topCategories.length}',
      emptyMessage: 'Belum ada penjualan per kategori.',
    );
  }

  /// Grafik lingkaran: sebaran status pesanan.
  Widget _orderStatusPieChart(AdminStats stats) {
    final palette = context.palette;

    return PieChartCard(
      title: 'Status Pesanan',
      subtitle: 'Distribusi seluruh pesanan',
      slices: <ChartSlice>[
        for (final status in OrderStatus.values)
          ChartSlice(
            label: status.label,
            value: _statusCount(stats, status).toDouble(),
            color: status.colorOf(palette.brightness),
          ),
      ],
      centerLabel: 'Pesanan',
      centerValue: '${stats.ordersTotal}',
    );
  }

  static int _statusCount(AdminStats stats, OrderStatus status) =>
      switch (status) {
        OrderStatus.pending => stats.ordersPending,
        OrderStatus.processing => stats.ordersProcessing,
        OrderStatus.completed => stats.ordersCompleted,
        OrderStatus.cancelled => stats.ordersCancelled,
      };

  Widget _greeting(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final palette = context.palette;

    return SectionCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.gold.withValues(alpha: 0.2),
            child: Text(
              user?.name.isEmpty ?? true
                  ? '?'
                  : user!.name.characters.first.toUpperCase(),
              style: TextStyle(
                color: palette.goldText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user?.name ?? 'Administrator',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                StatusChip(label: 'Administrator', color: palette.warning),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueCard(AdminStats stats) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Pendapatan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _statRow(
          label: '30 hari terakhir',
          value: Formatters.rupiah(stats.revenueTotal),
          icon: Icons.account_balance_wallet_outlined,
        ),
        _statRow(
          label: 'Hari ini',
          value: Formatters.rupiah(stats.revenueToday),
          icon: Icons.today_outlined,
        ),
        _statRow(
          label: 'Bulan ini',
          value: Formatters.rupiah(stats.revenueThisMonth),
          icon: Icons.calendar_month_outlined,
        ),
      ],
    ),
  );

  Widget _statRow({
    required String label,
    required String value,
    required IconData icon,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 16, color: context.palette.goldText),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _ordersCard(AdminStats stats) {
    final palette = context.palette;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Pesanan',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _countChip('Total', stats.ordersTotal, palette.textPrimary),
              _countChip('Menunggu', stats.ordersPending, palette.warning),
              _countChip('Diproses', stats.ordersProcessing, palette.info),
              _countChip('Selesai', stats.ordersCompleted, palette.success),
              _countChip('Dibatalkan', stats.ordersCancelled, palette.danger),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Konfirmasi Pembayaran',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _countChip(
                'Belum dibayar',
                stats.paymentsUnpaid,
                palette.warning,
              ),
              _countChip('Terkonfirmasi', stats.paymentsPaid, palette.success),
              _countChip('Dikembalikan', stats.paymentsRefunded, palette.info),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recentOrdersCard(AdminStats stats) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Checkout Terbaru',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            if (widget.onOpenOrders != null)
              TextButton(
                onPressed: widget.onOpenOrders,
                child: const Text('Semua pesanan'),
              ),
          ],
        ),
        if (stats.recentOrders.isEmpty)
          Text(
            'Belum ada checkout dari pelanggan.',
            style: TextStyle(
              fontSize: 12,
              color: context.palette.textSecondary,
            ),
          )
        else
          for (final order in stats.recentOrders)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: widget.onOpenOrders,
              title: Text(
                '${order.orderCode} · ${order.customer ?? 'Pelanggan'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  StatusChip(
                    label: order.statusOrder.label,
                    color: order.statusOrder.colorOf(
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
              trailing: Text(
                Formatters.rupiah(order.finalAmount),
                style: const TextStyle(fontSize: 11),
              ),
            ),
      ],
    ),
  );

  Widget _managementCard(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Kelola Katalog',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.local_offer_outlined,
            color: context.palette.goldText,
          ),
          title: const Text('Kode Promo', style: TextStyle(fontSize: 13)),
          subtitle: const Text(
            'Kelola kode, diskon, masa berlaku, dan promo customer',
            style: TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PromotionsAdminScreen(),
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.sell_outlined, color: context.palette.goldText),
          title: const Text('Produk', style: TextStyle(fontSize: 13)),
          subtitle: const Text(
            'Tambah/edit produk, kategori, dan foto',
            style: TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ProductsAdminScreen(),
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.category_outlined,
            color: context.palette.goldText,
          ),
          title: const Text('Kategori', style: TextStyle(fontSize: 13)),
          subtitle: const Text(
            'Tambah, ubah, atau nonaktifkan kategori',
            style: TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CategoriesAdminScreen(),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _countChip(String label, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      '$label: $count',
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  Widget _storeCard(AdminStats stats) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Toko',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _statRow(
          label: 'Produk tersedia',
          value: '${stats.productsTotal}',
          icon: Icons.inventory_2_outlined,
        ),
        _statRow(
          label: 'Stok habis',
          value: '${stats.productsOutOfStock}',
          icon: Icons.emergency_outlined,
        ),
        _statRow(
          label: 'Pelanggan',
          value: '${stats.customersTotal}',
          icon: Icons.people_outline,
        ),
        _statRow(
          label: 'Rata-rata nilai pesanan',
          value: Formatters.rupiah(stats.averageOrderValue),
          icon: Icons.percent_outlined,
        ),
      ],
    ),
  );

  Future<bool?> _confirmLogout(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Keluar dari akun?'),
      content: const Text('Anda akan kembali ke layar masuk.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
}
