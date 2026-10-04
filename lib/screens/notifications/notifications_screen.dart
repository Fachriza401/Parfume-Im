import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().load(showLoading: true);
      }
    });
  }

  Future<void> _openNotification(AppNotification item) async {
    try {
      await context.read<NotificationProvider>().markRead(item);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: <Widget>[
          if (notifications.unreadCount > 0)
            TextButton(
              onPressed: () async {
                try {
                  await notifications.markAllRead();
                } on Object catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
              child: const Text('Baca semua'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifications.load(),
        child: notifications.isLoading && notifications.items.isEmpty
            ? const LoadingView()
            : notifications.error != null && notifications.items.isEmpty
            ? ListView(
                children: <Widget>[
                  SizedBox(
                    height: 360,
                    child: ErrorView(
                      message: notifications.error!,
                      onRetry: () => notifications.load(showLoading: true),
                    ),
                  ),
                ],
              )
            : notifications.items.isEmpty
            ? ListView(
                children: const <Widget>[
                  SizedBox(
                    height: 360,
                    child: EmptyState(
                      title: 'Belum ada notifikasi',
                      message:
                          'Info promo dan status pesanan akan muncul di sini.',
                      icon: Icons.notifications_none,
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = notifications.items[index];
                  return SectionCard(
                    onTap: () => _openNotification(item),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          item.type.contains('promotion') ||
                                  item.type.contains('promo')
                              ? Icons.local_offer_outlined
                              : Icons.notifications_active_outlined,
                          color: item.isRead
                              ? palette.textMuted
                              : palette.goldText,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                              if (item.body.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  item.body,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                              if (item.createdAt != null) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  Formatters.dateTime(item.createdAt!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!item.isRead)
                          Icon(Icons.circle, size: 8, color: palette.goldText),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
