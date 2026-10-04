import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _preset = 'month';

  static const List<(String, String, IconData)> _presets =
      <(String, String, IconData)>[
        ('Hari Ini', 'today', Icons.today_outlined),
        ('Minggu Ini', 'week', Icons.date_range_outlined),
        ('Bulan Ini', 'month', Icons.calendar_month_outlined),
        ('30 Hari', 'custom', Icons.insights_outlined),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminProvider>().loadReport(preset: _preset);
    });
  }

  Future<void> _load([String? preset]) async {
    if (preset != null) setState(() => _preset = preset);
    await context.read<AdminProvider>().loadReport(preset: _preset);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final report = provider.report;

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Penjualan')),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: <Widget>[
                for (final (label, value, icon) in _presets) ...<Widget>[
                  _presetChip(
                    label,
                    _preset == value,
                    icon,
                    () => _load(value),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: provider.isReportLoading && report == null
                ? const LoadingView()
                : report == null
                ? ErrorView(
                    message: provider.error ?? 'Gagal memuat laporan',
                    onRetry: _load,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: <Widget>[
                        _summaryCard(report),
                        const SizedBox(height: 12),
                        _lineCard(report),
                        const SizedBox(height: 12),
                        _barCard(report),
                        const SizedBox(height: 12),
                        _categoryPieCard(report),
                        const SizedBox(height: 12),
                        _statusPieCard(report),
                        const SizedBox(height: 12),
                        _bestSellingCard(report),
                        const SizedBox(height: 12),
                        _dailyListCard(report),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(
    String label,
    bool selected,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  /// Garis: pendapatan harian selama periode terpilih.
  Widget _lineCard(SalesReport report) {
    final palette = context.palette;
    final series = dailySalesSeries(report.salesByDate, palette);

    return LineChartCard(
      title: 'Grafik Garis — Pendapatan',
      subtitle: 'Tren penjualan harian pada periode terpilih',
      labels: series.labels,
      series: <LineSeries>[series.revenue],
      emptyMessage: 'Belum ada penjualan pada periode ini.',
    );
  }

  /// Batang: jumlah pesanan per hari.
  Widget _barCard(SalesReport report) {
    final palette = context.palette;
    final colors = defaultSeriesColors(palette);
    final ordered = report.salesByDate.reversed.toList(growable: false);

    return BarChartCard(
      title: 'Grafik Batang — Pesanan per Hari',
      subtitle: 'Jumlah pesanan yang masuk setiap hari',
      slices: <ChartSlice>[
        for (var i = 0; i < ordered.length; i++)
          ChartSlice(
            label: Formatters.date(ordered[i].date),
            value: ordered[i].orders.toDouble(),
            color: colors[i % colors.length],
          ),
      ],
      valueFormatter: (value) => value.toStringAsFixed(0),
      emptyMessage: 'Belum ada pesanan pada periode ini.',
    );
  }

  /// Lingkaran: pangsa pendapatan per kategori.
  Widget _categoryPieCard(SalesReport report) {
    final palette = context.palette;

    return PieChartCard(
      title: 'Grafik Lingkaran — Kategori Terlaris',
      subtitle: 'Pangsa pendapatan tiap kategori',
      slices: ChartSlice.fromCategories(report.topCategories, palette),
      centerLabel: 'Kategori',
      centerValue: '${report.topCategories.length}',
      emptyMessage: 'Belum ada penjualan per kategori.',
    );
  }

  /// Lingkaran: sebaran status pesanan pada periode ini.
  Widget _statusPieCard(SalesReport report) {
    final palette = context.palette;

    return PieChartCard(
      title: 'Grafik Lingkaran — Status Pesanan',
      subtitle: 'Distribusi pesanan pada periode terpilih',
      slices: <ChartSlice>[
        for (final status in OrderStatus.values)
          ChartSlice(
            label: status.label,
            value: (report.ordersByStatus[status] ?? 0).toDouble(),
            color: status.colorOf(palette.brightness),
          ),
      ],
      centerLabel: 'Pesanan',
      centerValue: '${report.totalOrders}',
      emptyMessage: 'Belum ada pesanan pada periode ini.',
    );
  }

  Widget _summaryCard(SalesReport report) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Periode ${Formatters.date(DateTime.tryParse(report.periodFrom))} '
          's.d. ${Formatters.date(DateTime.tryParse(report.periodTo))}',
          style: TextStyle(fontSize: 11, color: context.palette.textSecondary),
        ),
        const SizedBox(height: 12),
        _row(
          'Total penjualan',
          Formatters.rupiah(report.totalSales),
          bold: true,
        ),
        _row('Total pesanan', '${report.totalOrders}'),
        _row('Pesanan lunas', '${report.totalPaidOrders}'),
        _row('Nilai rata-rata', Formatters.rupiah(report.averageOrderValue)),
      ],
    ),
  );

  Widget _bestSellingCard(SalesReport report) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Produk terlaris',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        if (report.bestSelling.isEmpty)
          Text(
            'Belum ada penjualan.',
            style: TextStyle(
              fontSize: 12,
              color: context.palette.textSecondary,
            ),
          )
        else
          for (final (index, item) in report.bestSelling.indexed) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _rankBadge(index + 1),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${item.sold} terjual • ${Formatters.rupiah(item.revenue)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
      ],
    ),
  );

  Widget _rankBadge(int rank) {
    final palette = context.palette;

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: rank == 1
            ? AppColors.gold.withValues(alpha: 0.25)
            : palette.surfaceAlt,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: rank == 1 ? palette.goldText : palette.textSecondary,
        ),
      ),
    );
  }

  Widget _dailyListCard(SalesReport report) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Rincian penjualan per hari',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        if (report.salesByDate.isEmpty)
          Text(
            'Belum ada data.',
            style: TextStyle(
              fontSize: 12,
              color: context.palette.textSecondary,
            ),
          )
        else
          for (final day in report.salesByDate.reversed) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _row(
                Formatters.date(day.date),
                '${day.orders} pesanan • ${Formatters.rupiah(day.revenue)}',
              ),
            ),
          ],
      ],
    ),
  );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? null : context.palette.textSecondary,
          ),
        ),
      ],
    ),
  );
}
