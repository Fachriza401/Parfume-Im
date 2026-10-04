import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';

/// Full-page product form for create and edit. The provider refreshes the admin
/// product list after a successful save, so the previous screen updates on pop.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _description;
  XFile? _selectedImage;
  int? _categoryId;
  bool _isActive = true;
  bool _submitting = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _price = TextEditingController(
      text: product == null ? '' : _formatPrice(product.price),
    );
    _stock = TextEditingController(
      text: product == null ? '' : '${product.stock}',
    );
    _description = TextEditingController(text: product?.description ?? '');
    _categoryId = product?.categoryId;
    _isActive = product?.isActive ?? true;
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(
      _price.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    final stock = int.parse(_stock.text.trim());

    setState(() => _submitting = true);

    try {
      final provider = context.read<AdminProvider>();
      final product = widget.product;
      final imageUrl = _selectedImage == null
          ? product?.imageUrl
          : await provider.uploadImage(_selectedImage!.path);

      if (product == null) {
        await provider.createProduct(
          name: _name.text.trim(),
          categoryId: _categoryId!,
          price: price,
          stock: stock,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          imageUrl: imageUrl,
          isActive: _isActive,
        );
      } else {
        await provider.updateProduct(
          product.id,
          name: _name.text.trim(),
          categoryId: _categoryId!,
          price: price,
          stock: stock,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          imageUrl: imageUrl,
          isActive: _isActive,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccess(
        context,
        product == null ? 'Produk dibuat' : 'Produk diperbarui',
      );
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error, field: 'name');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image != null && mounted) setState(() => _selectedImage = image);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Produk' : 'Produk Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama produk',
                  prefixIcon: Icon(Icons.spa_outlined),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Nama produk wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: provider.categories
                    .map(
                      (category) => DropdownMenuItem<int>(
                        value: category.id,
                        child: Text(
                          category.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) =>
                    value == null ? 'Kategori wajib dipilih' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Harga (Rp)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        final normalized = (value ?? '')
                            .trim()
                            .replaceAll('.', '')
                            .replaceAll(',', '.');
                        final number = double.tryParse(normalized);
                        if (!(number != null && number >= 0)) {
                          return 'Harga tidak valid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Stok',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        final intNumber = int.tryParse((value ?? '').trim());
                        if (!(intNumber != null && intNumber >= 0)) {
                          return 'Stok tidak valid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 14),
              _imagePicker(
                currentUrl: widget.product?.imageUrl,
                selectedImage: _selectedImage,
                onPick: _pickImage,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Produk aktif',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Produk nonaktif tidak tampil di katalog.',
                  style: TextStyle(fontSize: 11),
                ),
                activeTrackColor: AppColors.gold,
              ),
              const SizedBox(height: 16),
              if (widget.product != null)
                SectionCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Harga saat ini ${Formatters.rupiah(widget.product!.price)} '
                          'dengan stok ${widget.product!.stock}.',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
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
                      : Text(_editing ? 'Simpan Perubahan' : 'Buat Produk'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePicker({
    required String? currentUrl,
    required XFile? selectedImage,
    required VoidCallback onPick,
  }) {
    final image = selectedImage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(image.path), height: 180, fit: BoxFit.cover),
          )
        else if (currentUrl != null && currentUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              AppConfig.resolveApiResource(currentUrl).toString(),
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _submitting ? null : onPick,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            image == null ? 'Pilih foto produk' : 'Ganti foto produk',
          ),
        ),
      ],
    );
  }
}
