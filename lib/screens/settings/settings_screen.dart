import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/api_server_settings.dart';

/// Appearance + connectivity settings, reachable from both the customer
/// profile and the admin hub.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _SectionLabel('Tampilan'),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: <Widget>[
                for (final option in _modeOptions) ...<Widget>[
                  _ModeTile(
                    option: option,
                    selected: theme.mode == option.mode,
                    onTap: () => theme.setMode(option.mode),
                  ),
                  if (option != _modeOptions.last)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Teks, ikon dan kartu otomatis menyesuaikan kontras agar tetap '
            'nyaman dibaca pada mode terang maupun gelap.',
            style: TextStyle(fontSize: 11, color: palette.textMuted),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Koneksi'),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'Server API',
            subtitle: 'Alamat backend yang dipakai aplikasi',
            onTap: () => showApiServerSettings(context),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Parfum IM v1.0.0',
              style: TextStyle(fontSize: 10, color: palette.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  static const List<
    ({ThemeMode mode, String label, IconData icon, String hint})
  >
  _modeOptions = <({ThemeMode mode, String label, IconData icon, String hint})>[
    (
      mode: ThemeMode.light,
      label: 'Mode Terang',
      icon: Icons.light_mode_outlined,
      hint: 'Latar terang, teks gelap',
    ),
    (
      mode: ThemeMode.dark,
      label: 'Mode Gelap',
      icon: Icons.dark_mode_outlined,
      hint: 'Latar gelap, teks terang',
    ),
    (
      mode: ThemeMode.system,
      label: 'Ikuti Sistem',
      icon: Icons.brightness_auto_outlined,
      hint: 'Menyesuaikan pengaturan perangkat',
    ),
  ];
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: context.palette.goldText,
      ),
    ),
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ({ThemeMode mode, String label, IconData icon, String hint}) option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.18)
              : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          option.icon,
          size: 18,
          color: selected ? palette.goldText : palette.textSecondary,
        ),
      ),
      title: Text(
        option.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: palette.textPrimary,
        ),
      ),
      subtitle: Text(
        option.hint,
        style: TextStyle(fontSize: 11, color: palette.textMuted),
      ),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppColors.gold : palette.border,
        size: 20,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: palette.goldText),
        title: Text(
          title,
          style: TextStyle(fontSize: 13, color: palette.textPrimary),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: palette.textMuted),
              ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}

/// Quick light/dark switch for app bars; resolves `system` on first tap.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final affordance = theme.toggleAffordance;

    return IconButton(
      tooltip: affordance.tooltip,
      icon: Icon(affordance.icon),
      onPressed: () => theme.toggle(MediaQuery.platformBrightnessOf(context)),
    );
  }
}
