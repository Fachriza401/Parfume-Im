import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/error_toast.dart';

/// Bottom-sheet category form shared by the create and edit flows. Returns the
/// created/updated category, or null when dismissed.
Future<Category?> showCategoryFormSheet(
  BuildContext context, {
  Category? category,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => CategoryFormSheet(category: category),
  );
}

class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({super.key, this.category});

  final Category? category;

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  XFile? _selectedImage;
  bool _isActive = true;
  bool _submitting = false;

  bool get _editing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _description = TextEditingController(
      text: widget.category?.description ?? '',
    );
    _image = TextEditingController(text: widget.category?.imageUrl ?? '');
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final provider = context.read<AdminProvider>();
      final category = widget.category;
      final image = _selectedImage == null
          ? _image.text.trim()
          : await provider.uploadImage(_selectedImage!.path);

      final result = category == null
          ? await provider.createCategory(
              name: _name.text.trim(),
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              image: image.isEmpty ? null : image,
              isActive: _isActive,
            )
          : await provider.updateCategory(
              category.id,
              name: _name.text.trim(),
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              image: image.isEmpty ? null : image,
              isActive: _isActive,
            );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
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
    return Padding(
      // Lift the sheet above the on-screen keyboard.
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
                _editing ? 'Edit Kategori' : 'Kategori Baru',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Nama kategori wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _image,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL gambar (opsional)',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_selectedImage!.path),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (widget.category?.imageUrl?.isNotEmpty ?? false)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    AppConfig.resolveApiResource(
                      widget.category!.imageUrl!,
                    ).toString(),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _selectedImage == null
                      ? 'Pilih foto kategori'
                      : 'Ganti foto kategori',
                ),
              ),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif', style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                  'Kategori aktif tampil di katalog.',
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
                      : Text(_editing ? 'Simpan Perubahan' : 'Buat Kategori'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
