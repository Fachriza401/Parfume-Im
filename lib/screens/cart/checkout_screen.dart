import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import '../orders/order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalController = TextEditingController();
  final _noteController = TextEditingController();
  final _promoCodeController = TextEditingController();

  String _paymentMethod = 'bank_transfer';
  String? _paymentDestinationCode;
  List<PaymentDestination> _paymentDestinations = const <PaymentDestination>[];
  String? _paymentOptionsError;
  bool _loadingPaymentOptions = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentOptions();
    _promoCodeController.text =
        context.read<CartProvider>().summary.promotion?.code ?? '';
    final user = context.read<AuthProvider>().user;

    // Prefill from the account so repeat customers check out faster.
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _noteController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentOptions() async {
    try {
      final destinations = await context
          .read<OrderProvider>()
          .loadPaymentOptions();
      if (!mounted) return;
      final codes = _paymentMethod == 'bank_transfer'
          ? const <String>['bca', 'mandiri', 'bni', 'bri']
          : const <String>['gopay', 'ovo', 'dana', 'shopeepay'];
      final selectedDestinations = destinations
          .where((destination) => codes.contains(destination.code))
          .toList(growable: false);
      final configuredDestinations = selectedDestinations
          .where((destination) => destination.configured)
          .toList(growable: false);
      final availableDestinations = configuredDestinations.isNotEmpty
          ? configuredDestinations
          : selectedDestinations;
      setState(() {
        _paymentDestinations = destinations;
        _paymentDestinationCode = availableDestinations.isEmpty
            ? null
            : availableDestinations.first.code;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _paymentOptionsError = error.message);
    } finally {
      if (mounted) setState(() => _loadingPaymentOptions = false);
    }
  }

  List<PaymentDestination> get _selectedDestinations => _paymentDestinations
      .where(
        (destination) => _paymentMethod == 'bank_transfer'
            ? const <String>[
                'bca',
                'mandiri',
                'bni',
                'bri',
              ].contains(destination.code)
            : const <String>[
                'gopay',
                'ovo',
                'dana',
                'shopeepay',
              ].contains(destination.code),
      )
      .toList(growable: false);

  Future<void> _applyPromotion() async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;
    try {
      await context.read<CartProvider>().applyPromotion(code);
      if (mounted) showSuccess(context, 'Kode promo berhasil diterapkan');
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error, field: 'promotion_code');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final order = await context.read<OrderProvider>().checkout(
        shippingName: _nameController.text.trim(),
        shippingPhone: _phoneController.text.trim(),
        shippingAddress: _addressController.text.trim(),
        shippingCity: _cityController.text.trim(),
        shippingPostalCode: _postalController.text.trim(),
        paymentMethod: _paymentMethod,
        paymentDestinationCode: _paymentMethod == 'cod'
            ? null
            : _paymentDestinationCode,
        note: _noteController.text.trim(),
        promotionCode: context.read<CartProvider>().summary.promotion?.code,
      );

      if (!mounted) return;

      // The backend clears the cart as part of checkout, so re-sync it.
      await context.read<CartProvider>().load();

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              OrderDetailScreen(orderId: order.id, justCreated: true),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changeQuantity(int cartItemId, int quantity) async {
    try {
      await context.read<CartProvider>().updateQuantity(cartItemId, quantity);
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error, field: 'quantity');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final summary = cart.summary;
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: isAdmin
          ? const EmptyState(
              title: 'Checkout khusus pelanggan',
              message: 'Akun admin tidak dapat membuat pesanan.',
              icon: Icons.admin_panel_settings_outlined,
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    'Pesanan Anda',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final item in cart.items)
                    Card(
                      child: ListTile(
                        title: Text(
                          item.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${Formatters.rupiah(item.price)} × ${item.quantity}',
                        ),
                        trailing: SizedBox(
                          width: 116,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Kurangi jumlah',
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    cart.busyItemId == item.id ||
                                        item.quantity <= 1
                                    ? null
                                    : () => _changeQuantity(
                                        item.id,
                                        item.quantity - 1,
                                      ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                tooltip: 'Tambah jumlah',
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    cart.busyItemId == item.id ||
                                        item.quantity >= item.product.stock
                                    ? null
                                    : () => _changeQuantity(
                                        item.id,
                                        item.quantity + 1,
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Alamat pengiriman',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _nameController,
                    'Nama penerima',
                    Icons.person_outline,
                  ),
                  _field(
                    _phoneController,
                    'Nomor HP',
                    Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                  ),
                  _field(
                    _addressController,
                    'Alamat lengkap',
                    Icons.map_outlined,
                    maxLines: 3,
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _field(
                          _cityController,
                          'Kota',
                          Icons.location_city,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _postalController,
                          'Kode pos',
                          Icons.markunread_mailbox_outlined,
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  _field(
                    _noteController,
                    'Catatan (opsional)',
                    Icons.notes,
                    maxLines: 2,
                  ),
                  Text(
                    'Kode promo',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _promoCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Masukkan kode promo',
                            prefixIcon: Icon(Icons.local_offer_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Terapkan promo',
                        onPressed: _applyPromotion,
                        icon: const Icon(Icons.check),
                      ),
                    ],
                  ),
                  if (summary.promotion != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await context.read<CartProvider>().removePromotion();
                          _promoCodeController.clear();
                        },
                        icon: const Icon(Icons.close, size: 16),
                        label: Text('Hapus ${summary.promotion!.code}'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Metode pembayaran',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: _paymentMethod,
                    onChanged: (value) => setState(() {
                      _paymentMethod = value ?? 'bank_transfer';
                      final options = _selectedDestinations
                          .where((destination) => destination.configured)
                          .toList(growable: false);
                      _paymentDestinationCode = options.isEmpty
                          ? null
                          : options.first.code;
                    }),
                    child: Column(
                      children: const <Widget>[
                        RadioListTile<String>(
                          value: 'bank_transfer',
                          title: Text(
                            'Transfer bank',
                            style: TextStyle(fontSize: 13),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          value: 'cod',
                          title: Text(
                            'Bayar di tempat (COD)',
                            style: TextStyle(fontSize: 13),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          value: 'e_wallet',
                          title: Text(
                            'E-Wallet',
                            style: TextStyle(fontSize: 13),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  if (_paymentMethod != 'cod') ...<Widget>[
                    const SizedBox(height: 8),
                    if (_loadingPaymentOptions)
                      const LinearProgressIndicator()
                    else if (_paymentOptionsError != null)
                      Text(
                        _paymentOptionsError!,
                        style: TextStyle(color: context.palette.danger),
                      )
                    else ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: _paymentDestinationCode,
                        decoration: InputDecoration(
                          labelText: _paymentMethod == 'bank_transfer'
                              ? 'Pilih bank tujuan'
                              : 'Pilih E-Wallet',
                        ),
                        items: _selectedDestinations
                            .map(
                              (destination) => DropdownMenuItem<String>(
                                value: destination.code,
                                child: Text(
                                  destination.configured
                                      ? destination.name
                                      : '${destination.name} (belum dikonfigurasi)',
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) =>
                            setState(() => _paymentDestinationCode = value),
                      ),
                      if (!_selectedDestinations.any(
                        (destination) => destination.configured,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Tujuan pembayaran belum diatur. Isi nomor dan nama pemilik rekening/e-wallet di backend .env.',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.danger,
                            ),
                          ),
                        ),
                      if (_paymentDestinationCode != null)
                        Builder(
                          builder: (context) {
                            final destination = _paymentDestinations.firstWhere(
                              (item) => item.code == _paymentDestinationCode,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SectionCard(
                                child: Text(
                                  destination.configured
                                      ? '${destination.name}\n'
                                            'Nomor: ${destination.accountNumber}\n'
                                            'Atas nama: ${destination.accountName}'
                                      : 'Lengkapi rekening tujuan di backend .env sebelum menerima pembayaran.',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  SectionCard(
                    child: Column(
                      children: <Widget>[
                        _summaryRow(
                          'Subtotal',
                          Formatters.rupiah(summary.subtotal),
                        ),
                        if (summary.discountAmount > 0)
                          _summaryRow(
                            'Diskon',
                            '-${Formatters.rupiah(summary.discountAmount)}',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        const Divider(height: 16),
                        _summaryRow(
                          'Total',
                          Formatters.rupiah(summary.finalAmount),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed:
                        _submitting ||
                            cart.isEmpty ||
                            (_paymentMethod != 'cod' &&
                                (_paymentOptionsError != null ||
                                    _loadingPaymentOptions ||
                                    !_selectedDestinations.any(
                                      (destination) =>
                                          destination.code ==
                                              _paymentDestinationCode &&
                                          destination.configured,
                                    )))
                        ? null
                        : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.charcoal,
                            ),
                          )
                        : const Text('Buat Pesanan'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pesanan akan menunggu verifikasi pembayaran oleh admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) =>
          (value?.trim().isEmpty ?? true) ? '$label wajib diisi' : null,
    ),
  );

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
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
          color: color,
        ),
      ),
    ],
  );
}
