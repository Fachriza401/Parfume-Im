import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/catalog_provider.dart' show LoadState;
import '../../widgets/common.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminProvider>().loadAuditLogs();
    });
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) {
      context.read<AdminProvider>().loadMoreAuditLogs();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() => context.read<AdminProvider>().loadAuditLogs();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final logs = provider.auditLogs;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: switch (provider.state) {
        LoadState.loading => const LoadingView(),
        LoadState.error => ErrorView(
          message: provider.error ?? 'Gagal memuat audit log',
          onRetry: _reload,
        ),
        _ =>
          logs.isEmpty
              ? const EmptyState(
                  title: 'Belum ada aktivitas',
                  message: 'Aktivitas admin akan tercatat di sini.',
                  icon: Icons.history,
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount:
                        logs.length + (provider.hasMoreAuditLogs ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= logs.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final log = logs[index];
                      return _logCard(log);
                    },
                  ),
                ),
      },
    );
  }

  Widget _logCard(AuditLogEntry log) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            log.description,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _tag(log.action.toUpperCase()),
              const SizedBox(width: 6),
              _tag(log.module),
              const Spacer(),
              Text(
                Formatters.dateTime(log.createdAt),
                style: TextStyle(fontSize: 10, color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 10, color: AppColors.charcoal),
    ),
  );
}
