import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

/// Runtime configuration for the Parfum IM mobile app.
///
/// The base URL differs per platform because Android devices cannot reach the
/// host machine through `localhost`:
///
/// * Android device / emulator on the current Wi-Fi -> laptop LAN address
/// * iOS simulator / desktop -> `127.0.0.1`
///
/// Override at build time without editing code, or change it in the app's
/// server settings to connect to a device on the local network:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://api.parfumim.test/api/v1
/// ```
class AppConfig {
  const AppConfig._();

  static const String _buildOverride = String.fromEnvironment('API_BASE_URL');
  static const String _savedUrlKey = 'parfumim.apiBaseUrl';

  static const String _androidBaseUrl = 'http://192.168.100.119:8000/api/v1';
  static const String _localBaseUrl = 'http://127.0.0.1:8000/api/v1';
  static String? _runtimeOverride;

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _runtimeOverride = preferences.getString(_savedUrlKey);
  }

  static Future<void> setApiBaseUrl(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_savedUrlKey, value);
    _runtimeOverride = value;
  }

  /// Resolved at runtime so the server can be changed without rebuilding.
  static String get apiBaseUrl {
    if (_buildOverride.isNotEmpty) return _buildOverride;
    final override = _runtimeOverride;
    if (override != null && override.isNotEmpty) return override;
    return Platform.isAndroid ? _androidBaseUrl : _localBaseUrl;
  }

  static String? normalizeBaseUrl(String value) {
    final input = value.trim();
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }

    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    final apiPath = path.endsWith('/api/v1') ? path : '$path/api/v1';
    return uri
        .replace(path: apiPath)
        .toString()
        .replaceFirst(RegExp(r'/+$'), '');
  }

  static Uri resolveApiResource(String value) {
    final resource = Uri.parse(value);
    if (resource.hasScheme) return resource;

    final base = Uri.parse(apiBaseUrl);
    return base.resolve(value.startsWith('/') ? value : '/$value');
  }

  static const int requestTimeoutSeconds = 20;

  /// Shown on the login screen so testers know which backend they are hitting.
  static String get apiHost => Uri.parse(apiBaseUrl).host;
}
