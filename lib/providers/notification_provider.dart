import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_response.dart';
import '../models/models.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({required ApiClient api}) : _api = api;

  final ApiClient _api;
  List<AppNotification> _items = const <AppNotification>[];
  bool _loading = false;
  String? _error;

  List<AppNotification> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;
  int get unreadCount => _items.where((item) => !item.isRead).length;

  Future<void> load({bool showLoading = false}) async {
    if (_loading) return;
    _loading = true;
    if (showLoading) notifyListeners();

    try {
      final response = await _api.get('/notifications');
      final data = response['data'];
      if (data is! List) {
        throw const FormatException(
          'Format notifikasi dari server tidak valid.',
        );
      }
      _items = data
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(growable: false);
      _error = null;
    } on Object catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Notifikasi belum dapat dimuat. Coba lagi.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final index = _items.indexWhere((item) => item.id == notification.id);
    if (index < 0) return;

    final previous = _items[index];
    _items = <AppNotification>[
      ..._items.take(index),
      previous.copyWith(isRead: true),
      ..._items.skip(index + 1),
    ];
    notifyListeners();

    try {
      await _api.patch('/notifications/${notification.id}/read');
    } on Object {
      _items = <AppNotification>[
        ..._items.take(index),
        previous,
        ..._items.skip(index + 1),
      ];
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    final previous = _items;
    _items = _items
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: false);
    notifyListeners();

    try {
      await _api.patch('/notifications/read-all');
    } on Object {
      _items = previous;
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _items = const <AppNotification>[];
    _error = null;
    notifyListeners();
  }
}
