import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/order_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import '../../widgets/order_view.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.justCreated = false,
  });

  final int orderId;
  final bool justCreated;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _uploadingReceipt = false;
  bool _refreshing = false;
  Timer? _refreshTimer;

  bool get _shouldPoll =>
      _order?.statusPayment == PaymentStatus.unpaid ||
      (_order?.status != OrderStatus.completed &&
          _order?.status != OrderStatus.cancelled);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_refreshing && _shouldPoll) _load();
    });
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final order = await context.read<OrderProvider>().loadOrder(
        widget.orderId,
      );
      if (mounted) setState(() => _order = order);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
      _refreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _shouldPoll) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _uploadReceipt() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    setState(() => _uploadingReceipt = true);
    try {
      final order = await context.read<OrderProvider>().uploadPaymentReceipt(
        widget.orderId,
        image.path,
      );
      if (mounted) setState(() => _order = order);
      if (mounted) showSuccess(context, 'Bukti pembayaran berhasil diunggah');
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      appBar: AppBar(
        title: Text(order == null ? 'Detail Pesanan' : '#${order.orderNumber}'),
        actions: <Widget>[
          if (order != null && order.status.canCancel)
            IconButton(
              tooltip: 'Batalkan pesanan',
              icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
              onPressed: () async {
                await confirmCancelOrder(context, order);
                await _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : order == null
          ? ErrorView(
              message: _error ?? 'Pesanan tidak ditemukan',
              onRetry: _load,
            )
          : _content(order),
    );
  }

  Widget _content(Order order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (widget.justCreated) ...<Widget>[
          const SectionCard(
            child: Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline, color: AppColors.success),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pesanan dibuat. Tunggu verifikasi pembayaran oleh admin.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        OrderStatusCard(order: order),
        const SizedBox(height: 12),
        OrderItemsCard(order: order),
        const SizedBox(height: 12),
        OrderShippingCard(order: order),
        const SizedBox(height: 12),
        OrderPaymentCard(
          order: order,
          action:
              order.statusPayment == PaymentStatus.unpaid &&
                  (order.payment?.methodLabel == 'Transfer Bank' ||
                      order.payment?.methodLabel == 'E-Wallet')
              ? OutlinedButton.icon(
                  onPressed: _uploadingReceipt ? null : _uploadReceipt,
                  icon: _uploadingReceipt
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(
                    order.payment?.receiptUploaded == true
                        ? 'Ganti bukti pembayaran'
                        : 'Unggah bukti pembayaran',
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// Shared cancellation confirmation used by both the customer and admin flows.
Future<void> confirmCancelOrder(BuildContext context, Order order) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Batalkan pesanan?'),
      content: Text(
        'Pesanan #${order.orderNumber} akan dibatalkan dan stok '
        'dikembalikan. Tindakan ini tidak dapat dibatalkan.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Batalkan'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await context.read<OrderProvider>().cancelOrder(order.id);
    if (context.mounted) showSuccess(context, 'Pesanan dibatalkan');
  } on ApiException catch (error) {
    if (context.mounted) showApiError(context, error);
  }
}
