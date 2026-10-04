import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's light / dark preference.
///
/// The stored value is a plain [ThemeMode] name, so the choice survives app
/// restarts and can be switched from either the customer or the admin side.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._preferences) : _mode = _read(_preferences);

  final SharedPreferences _preferences;

  static const String _storageKey = 'parfumim.themeMode';

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  /// True when the app is currently painting dark surfaces.
  bool get isDark => _mode == ThemeMode.dark;

  bool get isLight => _mode == ThemeMode.light;

  /// `system` follows the device brightness.
  bool get followsSystem => _mode == ThemeMode.system;

  static Future<ThemeProvider> create() async =>
      ThemeProvider(await SharedPreferences.getInstance());

  static ThemeMode _read(SharedPreferences preferences) {
    final stored = preferences.getString(_storageKey);
    if (stored == null) return ThemeMode.dark;
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _preferences.setString(_storageKey, mode.name);
  }

  /// Flips between light and dark. Pass the platform brightness so `system`
  /// resolves to a concrete opposite instead of toggling to itself.
  Future<void> toggle(Brightness platformBrightness) => setMode(switch (_mode) {
    ThemeMode.system =>
      platformBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.light,
  });

  /// Icon + label pair used by the quick toggle in the catalog app bar.
  ({IconData icon, String tooltip}) get toggleAffordance => switch (_mode) {
    ThemeMode.light => (icon: Icons.dark_mode_outlined, tooltip: 'Mode gelap'),
    ThemeMode.dark || ThemeMode.system => (
      icon: Icons.light_mode_outlined,
      tooltip: 'Mode terang',
    ),
  };
}
