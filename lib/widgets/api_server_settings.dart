import 'package:flutter/material.dart';

import '../core/config/app_config.dart';

Future<void> showApiServerSettings(BuildContext context) async {
  final controller = TextEditingController(text: AppConfig.apiBaseUrl);
  final formKey = GlobalKey<FormState>();
  final messenger = ScaffoldMessenger.of(context);

  try {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Server API'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Alamat server',
              hintText: 'http://192.168.100.119:8000',
              helperText: 'Gunakan IP Wi-Fi komputer pada jaringan lokal.',
            ),
            validator: (value) =>
                AppConfig.normalizeBaseUrl(value ?? '') == null
                    ? 'Masukkan alamat server HTTP atau HTTPS yang valid.'
                    : null,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final normalized = AppConfig.normalizeBaseUrl(controller.text);
              if (normalized == null) return;
              await AppConfig.setApiBaseUrl(normalized);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Server API: ${AppConfig.apiBaseUrl}')),
      );
    }
  } finally {
    controller.dispose();
  }
}
