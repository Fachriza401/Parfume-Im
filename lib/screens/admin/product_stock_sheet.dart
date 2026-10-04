import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/error_toast.dart';

/// Bottom sheet for stock adjustments: add (`in`), remove (`out`) or set an
/// exact value. Sends the reason through to the audit log.
Future<void> showProductStockSheet(
  BuildContext context, {
  required Product product,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => ProductStockSheet(product: product),
  );
}

class ProductStockSheet extends StatefulWidget {
  const ProductStockSheet({super.key, required this.product});

  final Product product;

  @override
  State<ProductStockSheet> createState() => _ProductStockSheetState();
}

class _ProductStockSheetState extends State<ProductStockSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  String _type = 'in';
  bool _submitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int? get _resultStock {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null) return null;

    return switch (_type) {
      'in' => widget.product.stock + quantity,
      'out' => widget.product.stock - quantity,
      _ => quantity,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.parse(_quantityController.text.trim());

    setState(() => _submitting = true);

    try {
      await context.read<AdminProvider>().adjustStock(
        widget.product.id,
        type: _type,
        quantity: quantity,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccess(context, 'Stok diperbarui');
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error, field: 'stock');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _resultStock;
    final outOfRange = result != null && result < 0;
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Stok: ${widget.product.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Stok saat ini: ${widget.product.stock}',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'in',
                    label: Text('Tambah'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment<String>(
                    value: 'out',
                    label: Text('Kurangi'),
                    icon: Icon(Icons.remove),
                  ),
                  ButtonSegment<String>(
                    value: 'set',
                    label: Text('Tetapkan'),
                    icon: Icon(Icons.tune),
                  ),
                ],
                selected: <String>{_type},
                onSelectionChanged: (selection) {
                  setState(() => _type = selection.first);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) {
                  final quantity = int.tryParse((value ?? '').trim());
                  if (quantity == null || quantity <= 0) {
                    return 'Jumlah harus lebih dari 0';
                  }
                  if (_type != 'in' &&
                      widget.product.stock - quantity < 0 &&
                      _type == 'out') {
                    return 'Stok tidak boleh negatif';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Alasan (opsional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      result == null
                          ? 'Masukkan jumlah.'
                          : outOfRange
                          ? 'Stok tidak boleh negatif.'
                          : 'Stok menjadi: $result',
                      style: TextStyle(
                        fontSize: 12,
                        color: outOfRange
                            ? palette.danger
                            : palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.charcoal,
                          ),
                        )
                      : const Text('Simpan Stok'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
