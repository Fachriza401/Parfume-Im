import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/order_provider.dart';
import '../../widgets/error_toast.dart';

/// Bottom sheet used to submit or update a rating (the API upserts).
Future<void> showReviewFormSheet(BuildContext context, Product product) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ReviewForm(product: product),
    ),
  );
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.product});

  final Product product;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  int _rating = 5;
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      await context.read<OrderProvider>().submitReview(
        productId: widget.product.id,
        rating: _rating,
        review: _controller.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        showSuccess(context, 'Ulasan tersimpan');
      }
    } on Object catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Ulas ${widget.product.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: List<Widget>.generate(
              5,
              (index) => IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: AppColors.warning,
                  size: 30,
                ),
                onPressed: () => setState(() => _rating = index + 1),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Ceritakan pengalaman Anda (opsional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.charcoal,
                      ),
                    )
                  : const Text('Kirim ulasan'),
            ),
          ),
        ],
      ),
    );
  }
}
