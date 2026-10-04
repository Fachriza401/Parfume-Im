import 'package:flutter/material.dart';

import '../core/network/api_response.dart';

/// Shows a snackbar for an error, surfacing the backend's field message when a
/// [field] is supplied so the user sees "Email sudah digunakan" rather than the
/// generic envelope message.
void showApiError(BuildContext context, Object error, {String? field}) {
  final message = switch (error) {
    ApiException api =>
      field == null ? api.message : (api.fieldError(field) ?? api.message),
    _ => error.toString(),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Success confirmation used after cart and checkout mutations.
void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
