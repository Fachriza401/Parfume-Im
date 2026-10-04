import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_response.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/error_toast.dart';
import '../settings/settings_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final palette = context.palette;
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: user == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                SectionCard(
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                        backgroundImage: user.avatarUrl == null
                            ? null
                            : NetworkImage(
                                AppConfig.resolveApiResource(
                                  user.avatarUrl!,
                                ).toString(),
                              ),
                        child: user.avatarUrl != null
                            ? null
                            : Text(
                                user.name.isEmpty
                                    ? '?'
                                    : user.name.characters.first.toUpperCase(),
                                style: TextStyle(
                                  color: palette.goldText,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            StatusChip(
                              label: user.isAdmin
                                  ? 'Administrator'
                                  : 'Pelanggan',
                              color: user.isAdmin
                                  ? palette.warning
                                  : palette.goldText,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (user.phone != null && user.phone!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.phone_outlined,
                          size: 18,
                          color: palette.goldText,
                        ),
                        const SizedBox(width: 12),
                        Text(user.phone!, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _tile(
                  context,
                  icon: Icons.favorite_border,
                  title: 'Favorit Saya',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FavoritesScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'Edit Profil',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Ubah Password',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Tampilan: ${_themeLabel(theme.mode)}',
                  onTap: () => _openThemeMenu(context, theme),
                ),
                _tile(
                  context,
                  icon: Icons.cloud_outlined,
                  title: 'Server API',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Bahasa aplikasi',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Indonesia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await _confirmLogout(context);
                    if (confirmed == true && context.mounted) {
                      await context.read<AuthProvider>().logout();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.danger,
                    side: BorderSide(color: palette.danger),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar'),
                ),
                const SizedBox(height: 12),
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

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Mode Terang',
    ThemeMode.dark => 'Mode Gelap',
    ThemeMode.system => 'Ikuti Sistem',
  };

  /// Bottom sheet with the three brightness options, available straight from
  /// the profile so the user does not have to hunt for the settings screen.
  Future<void> _openThemeMenu(BuildContext context, ThemeProvider theme) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          final palette = sheetContext.palette;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Mode tampilan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                RadioGroup<ThemeMode>(
                  groupValue: theme.mode,
                  onChanged: (value) {
                    if (value == null) return;
                    theme.setMode(value);
                    Navigator.of(sheetContext).pop();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final option in ThemeMode.values)
                        RadioListTile<ThemeMode>(
                          value: option,
                          title: Text(
                            _themeLabel(option),
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            switch (option) {
                              ThemeMode.light => 'Latar terang, teks gelap',
                              ThemeMode.dark => 'Latar gelap, teks terang',
                              ThemeMode.system =>
                                'Mengikuti pengaturan perangkat',
                            },
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.textMuted,
                            ),
                          ),
                          activeColor: AppColors.gold,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: context.palette.goldText),
        title: Text(title, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    ),
  );

  Future<bool?> _confirmLogout(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Keluar dari akun?'),
      content: const Text(
        'Anda perlu login kembali untuk melanjutkan pesanan.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
}

/// Password change form; validation mirrors the backend minimum rules.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await context.read<AuthProvider>().changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
        confirmPassword: _confirmController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccess(context, 'Password berhasil diperbarui');
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _currentController,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Password saat ini',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) => (value?.isEmpty ?? true)
                    ? 'Password saat ini wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newController,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Password baru',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password baru wajib diisi';
                  }
                  if (value.length < 8) return 'Minimal 8 karakter';
                  if (value == _currentController.text) {
                    return 'Password baru harus berbeda';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi password baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (value) => value == _newController.text
                    ? null
                    : 'Konfirmasi tidak cocok',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.palette.onGold,
                          ),
                        )
                      : const Text('Simpan Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
