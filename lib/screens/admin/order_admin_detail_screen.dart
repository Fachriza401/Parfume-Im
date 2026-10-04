import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_response.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import '../../widgets/order_view.dart';

class OrderAdminDetailScreen extends StatefulWidget {
  const OrderAdminDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderAdminDetailScreen> createState() => _OrderAdminDetailScreenState();
}

class _OrderAdminDetailScreenState extends State<OrderAdminDetailScreen>
    with WidgetsBindingObserver {
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _updating = false;
  Future<Uint8List>? _receiptFuture;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_refreshing && _shouldPoll) _load();
    });
  }

  bool get _shouldPoll =>
      _order?.statusPayment == PaymentStatus.unpaid ||
      (_order?.status != OrderStatus.completed &&
          _order?.status != OrderStatus.cancelled);

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final provider = context.read<AdminProvider>();
      final order = await provider.loadOrder(widget.orderId);
      final receiptFuture = order.payment?.receiptUploaded == true
          ? (_order?.payment?.receiptUploaded == true
                ? _receiptFuture
                : provider.loadPaymentReceipt(widget.orderId))
          : null;
      if (mounted) {
        setState(() {
          _order = order;
          _receiptFuture = receiptFuture;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
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

  Future<void> _updateOrderStatus(OrderStatus target) async {
    setState(() => _updating = true);
    try {
      await context.read<AdminProvider>().updateOrderStatus(
        widget.orderId,
        target,
      );
      if (mounted) showSuccess(context, 'Status pesanan diperbarui');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updatePayment({
    required PaymentStatus status,
    String? transactionId,
  }) async {
    setState(() => _updating = true);
    try {
      await context.read<AdminProvider>().updatePayment(
        widget.orderId,
        status: status,
        transactionId: transactionId,
      );
      if (mounted) showSuccess(context, 'Status pembayaran diperbarui');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      appBar: AppBar(
        title: Text(order == null ? 'Detail Pesanan' : '#${order.orderNumber}'),
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
    final statusOptions = order.status.allowedTransitions;
    final paymentOptions = order.statusPayment.allowedTransitions;

    return Stack(
      children: <Widget>[
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewPaddingOf(context).bottom + 40,
          ),
          children: <Widget>[
            OrderStatusCard(order: order),
            const SizedBox(height: 12),
            OrderCustomerCard(order: order),
            if (order.hasCustomer) const SizedBox(height: 12),
            OrderItemsCard(order: order),
            const SizedBox(height: 12),
            OrderShippingCard(order: order),
            const SizedBox(height: 12),
            OrderPaymentCard(
              order: order,
              receiptPreview: _receiptPreview(),
              action: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (statusOptions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: _updating
                            ? null
                            : () => _showStatusSheet(order, statusOptions),
                        icon: const Icon(Icons.sync),
                        label: const Text('Perbarui Status Pesanan'),
                      ),
                    ),
                  if (paymentOptions.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _updating
                          ? null
                          : () => _showPaymentSheet(order, paymentOptions),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Perbarui Pembayaran'),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_updating)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget? _receiptPreview() {
    final future = _receiptFuture;
    if (future == null) return null;

    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Bukti pembayaran gagal dimuat.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final imageBytes = snapshot.data!;

        return Tooltip(
          message: 'Ketuk untuk melihat bukti pembayaran',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showReceiptImage(imageBytes),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: Image.memory(
                    imageBytes,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'Format bukti pembayaran tidak dapat ditampilkan.',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReceiptImage(Uint8List imageBytes) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bukti Pembayaran'),
          leading: IconButton(
            tooltip: 'Tutup',
            onPressed: () => Navigator.of(dialogContext).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.memory(imageBytes, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );

  Future<void> _showStatusSheet(Order order, List<OrderStatus> options) async {
    final selected = await showModalBottomSheet<OrderStatus>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Perbarui status pesanan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: option.colorOf(Theme.of(context).brightness),
                ),
                title: Text(option.label, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  option.description,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await _updateOrderStatus(selected);
  }

  Future<void> _showPaymentSheet(
    Order order,
    List<PaymentStatus> options,
  ) async {
    final selectedStatus = await showModalBottomSheet<PaymentStatus>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Perbarui status pembayaran',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: option.colorOf(Theme.of(context).brightness),
                ),
                title: Text(option.label, style: const TextStyle(fontSize: 13)),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selectedStatus == null || !mounted) return;

    var transactionId = '';
    if (selectedStatus == PaymentStatus.paid) {
      final submitted = await _askTransactionId(order, selectedStatus);
      if (submitted == null || !mounted) return;
      transactionId = submitted;
    }

    await _updatePayment(status: selectedStatus, transactionId: transactionId);
  }

  Future<String?> _askTransactionId(Order order, PaymentStatus status) {
    final controller = TextEditingController(
      text: order.payment?.reference ?? '',
    );

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Konfirmasi pembayaran (${status.label})',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.text,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(100),
              ],
              decoration: const InputDecoration(
                labelText: 'Referensi pembayaran (opsional)',
                hintText: 'TRX-20260101-0001',
                prefixIcon: Icon(Icons.receipt_outlined),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
                child: const Text('Konfirmasi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
