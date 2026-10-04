import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/models.dart';
import 'common.dart';

const double _chipSize = 10;

/// Status summary card shared by the customer and admin order details.
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      child: Row(
        children: <Widget>[
          Icon(
            Icons.circle,
            size: _chipSize,
            color: order.status.colorOf(palette.brightness),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.status.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  order.status.description,
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            Formatters.dateTime(order.createdAt),
            style: TextStyle(fontSize: 10, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Ordered items plus the price summary block.
class OrderItemsCard extends StatelessWidget {
  const OrderItemsCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Produk dipesan',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${item.quantity}x ',
                    style: const TextStyle(fontSize: 12, color: AppColors.gold),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.productName,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${Formatters.rupiah(item.unitPrice)} / item',
                          style: TextStyle(
                            fontSize: 10,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.rupiah(item.subtotal),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          _row('Subtotal', Formatters.rupiah(order.subtotal)),
          if (order.discountAmount > 0)
            _row(
              'Diskon',
              '-${Formatters.rupiah(order.discountAmount)}',
              color: palette.success,
            ),
          const SizedBox(height: 6),
          _row('Total', Formatters.rupiah(order.totalAmount), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w700 : null,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: bold ? 16 : 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      );
}

/// Shipping address block.
class OrderShippingCard extends StatelessWidget {
  const OrderShippingCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Alamat pengiriman',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(order.shippingName, style: const TextStyle(fontSize: 12)),
          Text(order.shippingPhone, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(order.shippingAddress, style: const TextStyle(fontSize: 12)),
          Text(
            '${order.shippingCity} ${order.shippingPostalCode}',
            style: const TextStyle(fontSize: 12),
          ),
          if (order.note != null && order.note!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Catatan: ${order.note}',
              style: TextStyle(fontSize: 11, color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Customer identity block, only rendered by the admin screens (BR-08).
class OrderCustomerCard extends StatelessWidget {
  const OrderCustomerCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (!order.hasCustomer) return const SizedBox.shrink();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Pelanggan',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (order.customerName != null && order.customerName!.isNotEmpty)
            Text(order.customerName!, style: const TextStyle(fontSize: 12)),
          if (order.customerEmail != null && order.customerEmail!.isNotEmpty)
            Text(order.customerEmail!, style: const TextStyle(fontSize: 12)),
          if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
            Text(order.customerPhone!, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Payment snapshot block, with an optional trailing action row for admins.
class OrderPaymentCard extends StatelessWidget {
  const OrderPaymentCard({
    super.key,
    required this.order,
    this.action,
    this.receiptPreview,
  });

  final Order order;
  final Widget? action;
  final Widget? receiptPreview;

  @override
  Widget build(BuildContext context) {
    final payment = order.payment;
    final palette = context.palette;
    final muted = TextStyle(fontSize: 11, color: palette.textSecondary);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Pembayaran',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (payment == null)
            Text(
              'Belum ada data pembayaran',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            )
          else ...<Widget>[
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.62,
                    ),
                    child: Text(
                      payment.methodLabel ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  StatusChip(
                    label: payment.statusLabel,
                    color: payment.status.colorOf(palette.brightness),
                  ),
                ],
              ),
            ),
            if (payment.amount != null && payment.amount! > 0) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Nominal: ${Formatters.rupiah(payment.amount!)}',
                style: muted,
              ),
            ],
            if (payment.destinationName != null) ...<Widget>[
              const SizedBox(height: 8),
              Text('Tujuan: ${payment.destinationName}', style: muted),
              if (payment.destinationAccount?.isNotEmpty ?? false)
                Text('Nomor: ${payment.destinationAccount}', style: muted),
              if (payment.destinationAccountName?.isNotEmpty ?? false)
                Text(
                  'Atas nama: ${payment.destinationAccountName}',
                  style: muted,
                ),
            ],
            if (payment.reference != null &&
                payment.reference!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text('Referensi: ${payment.reference}', style: muted),
              if (payment.status == PaymentStatus.unpaid &&
                  order.status != OrderStatus.cancelled &&
                  (payment.methodLabel == 'Transfer Bank' ||
                      payment.methodLabel == 'E-Wallet')) ...<Widget>[
                const SizedBox(height: 12),
                Center(
                  child: QrImageView(
                    data: payment.reference!,
                    size: 176,
                    backgroundColor: Colors.white,
                    semanticsLabel:
                        'QR referensi transaksi ${payment.reference}',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'QR ini hanya kode referensi pesanan, bukan bukti pembayaran resmi.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ],
            ],
            if (payment.receiptUploaded) ...<Widget>[
              const SizedBox(height: 8),
              Text('Bukti pembayaran sudah diunggah.', style: muted),
              if (receiptPreview != null) ...<Widget>[
                const SizedBox(height: 8),
                receiptPreview!,
              ],
            ],
            if (payment.paidAt != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Dibayar: ${Formatters.dateTime(payment.paidAt)}',
                style: muted,
              ),
            ],
          ],
          if (action != null) ...<Widget>[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
