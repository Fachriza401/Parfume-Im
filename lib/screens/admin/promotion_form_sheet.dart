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
import '../../widgets/error_toast.dart';

/// Bottom-sheet promotion form for create and edit.
Future<Promotion?> showPromotionFormSheet(
  BuildContext context, {
  Promotion? promotion,
}) {
  return showModalBottomSheet<Promotion>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => PromotionFormSheet(promotion: promotion),
  );
}

class PromotionFormSheet extends StatefulWidget {
  const PromotionFormSheet({super.key, this.promotion});

  final Promotion? promotion;

  @override
  State<PromotionFormSheet> createState() => _PromotionFormSheetState();
}

class _PromotionFormSheetState extends State<PromotionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _discountValue;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _minOrder;
  late final TextEditingController _usageLimit;
  String _discountType = 'percentage';
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _isActive = true;
  bool _submitting = false;
  XFile? _selectedImage;

  bool get _editing => widget.promotion != null;

  @override
  void initState() {
    super.initState();
    final promotion = widget.promotion;
    _code = TextEditingController(text: promotion?.code ?? '');
    _name = TextEditingController(text: promotion?.name ?? '');
    _description = TextEditingController(text: promotion?.description ?? '');
    _discountValue = TextEditingController(
      text: promotion == null ? '' : _formatNumber(promotion.discountValue),
    );
    _maxDiscount = TextEditingController(
      text: _formatOptional(promotion?.maxDiscountAmount),
    );
    _minOrder = TextEditingController(
      text: promotion == null || promotion.minOrderAmount <= 0
          ? ''
          : _formatNumber(promotion.minOrderAmount),
    );
    _usageLimit = TextEditingController(
      text: promotion?.usageLimit?.toString() ?? '',
    );
    _discountType = promotion?.discountType ?? 'percentage';
    _startsAt = promotion?.startsAt;
    _endsAt = promotion?.endsAt;
    _isActive = promotion?.isActive ?? true;
  }

  String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  String _formatOptional(double? value) =>
      value == null || value <= 0 ? '' : _formatNumber(value);

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    _discountValue.dispose();
    _maxDiscount.dispose();
    _minOrder.dispose();
    _usageLimit.dispose();
    super.dispose();
  }

  double? _parseNumber(String text) {
    final normalized = text.trim().replaceAll('.', '').replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;
    return value;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? _startsAt : _endsAt;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startsAt = picked;
        if (_endsAt != null && _endsAt!.isBefore(picked)) {
          _endsAt = null;
        }
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final discountValue = _parseNumber(_discountValue.text)!;

    setState(() => _submitting = true);

    try {
      final provider = context.read<AdminProvider>();
      final promotion = widget.promotion;
      final imageUrl = _selectedImage == null
          ? promotion?.imageUrl
          : await provider.uploadImage(_selectedImage!.path);

      final result = promotion == null
          ? await provider.createPromotion(
              code: _code.text.trim().toUpperCase(),
              name: _name.text.trim().isEmpty ? null : _name.text.trim(),
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              discountType: _discountType,
              discountValue: discountValue,
              maxDiscountAmount: _parseNumber(_maxDiscount.text),
              minOrderAmount: _parseNumber(_minOrder.text),
              usageLimit: _parseOptionalInt(_usageLimit.text),
              startsAt: _startsAt,
              endsAt: _endsAt,
              imageUrl: imageUrl,
              isActive: _isActive,
            )
          : await provider.updatePromotion(
              promotion.id,
              code: _code.text.trim().toUpperCase(),
              name: _name.text.trim().isEmpty ? null : _name.text.trim(),
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              discountType: _discountType,
              discountValue: discountValue,
              maxDiscountAmount: _parseNumber(_maxDiscount.text),
              minOrderAmount: _parseNumber(_minOrder.text),
              usageLimit: _parseOptionalInt(_usageLimit.text),
              startsAt: _startsAt,
              endsAt: _endsAt,
              imageUrl: imageUrl,
              isActive: _isActive,
            );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error, field: 'code');
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

  int? _parseOptionalInt(String text) {
    final value = int.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  String? _validateNumber(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = _parseNumber(text);
    if (parsed == null) return '$label tidak valid';
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                _editing ? 'Edit Promo' : 'Promo Baru',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Kode promo',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Kode promo wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nama promo (opsional)',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 14),
              _imagePicker(),
              DropdownButtonFormField<String>(
                initialValue: _discountType,
                decoration: const InputDecoration(
                  labelText: 'Tipe diskon',
                  prefixIcon: Icon(Icons.percent),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'percentage',
                    child: Text('Persen (%)', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem<String>(
                    value: 'fixed',
                    child: Text('Nominal (Rp)', style: TextStyle(fontSize: 13)),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _discountType = value);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _discountValue,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: _discountType == 'percentage'
                      ? 'Nilai diskon (%)'
                      : 'Nilai diskon (Rp)',
                  prefixIcon: Icon(
                    _discountType == 'percentage'
                        ? Icons.percent
                        : Icons.attach_money,
                  ),
                ),
                validator: (value) {
                  final parsed = _parseNumber(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Nilai diskon wajib diisi';
                  }
                  if (_discountType == 'percentage' && parsed > 100) {
                    return 'Diskon persen maksimal 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _maxDiscount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Maksimal diskon (Rp, opsional)',
                  prefixIcon: Icon(Icons.offline_pin_outlined),
                ),
                validator: (value) => _validateNumber(value, 'Batas diskon'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _minOrder,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Min. belanja (Rp, opsional)',
                  prefixIcon: Icon(Icons.shopping_cart_outlined),
                ),
                validator: (value) => _validateNumber(value, 'Minimal belanja'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usageLimit,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Batas pemakaian (opsional)',
                  prefixIcon: Icon(Icons.people_outline),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _dateField(
                      label: 'Mulai',
                      icon: Icons.event_outlined,
                      value: _startsAt,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField(
                      label: 'Selesai',
                      icon: Icons.event_available_outlined,
                      value: _endsAt,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Promo aktif',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Kode aktif dapat dipakai saat checkout.',
                  style: TextStyle(fontSize: 11),
                ),
                activeTrackColor: AppColors.gold,
              ),
              const SizedBox(height: 8),
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
                      : Text(_editing ? 'Simpan Perubahan' : 'Buat Promo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required IconData icon,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(
          value == null ? 'Tentukan tanggal' : Formatters.date(value),
          style: TextStyle(
            fontSize: 13,
            color: value == null ? palette.textSecondary : palette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _imagePicker() {
    final image = _selectedImage;
    final currentUrl = widget.promotion?.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(image.path), height: 160, fit: BoxFit.cover),
          )
        else if (currentUrl != null && currentUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              AppConfig.resolveApiResource(currentUrl).toString(),
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _submitting ? null : _pickImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(image == null ? 'Pilih foto promo' : 'Ganti foto promo'),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
