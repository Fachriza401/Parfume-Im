import 'package:flutter_test/flutter_test.dart';
import 'package:parfum_im/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppConfig.normalizeBaseUrl', () {
    test('adds the API path to a LAN host and trims whitespace', () {
      expect(
        AppConfig.normalizeBaseUrl(' http://192.168.100.119:8000/ '),
        'http://192.168.100.119:8000/api/v1',
      );
    });

    test('preserves a supplied API path', () {
      expect(
        AppConfig.normalizeBaseUrl('https://api.example.test/api/v1/'),
        'https://api.example.test/api/v1',
      );
    });

    test('rejects incomplete or unsafe server URLs', () {
      expect(AppConfig.normalizeBaseUrl('192.168.100.119:8000'), isNull);
      expect(AppConfig.normalizeBaseUrl('ftp://server.test'), isNull);
      expect(
          AppConfig.normalizeBaseUrl('http://user:pass@server.test'), isNull);
      expect(AppConfig.normalizeBaseUrl('http://server.test?x=1'), isNull);
    });

    test('resolves backend-relative images against the configured API host',
        () {
      final base = Uri.parse(AppConfig.apiBaseUrl);
      final image = AppConfig.resolveApiResource(
        '/images/products/oud-noir.png',
      );

      expect(image.host, base.host);
      expect(image.port, base.port);
      expect(image.path, '/images/products/oud-noir.png');
    });

    test('preserves absolute image URLs', () {
      expect(
        AppConfig.resolveApiResource('https://cdn.example.test/perfume.png'),
        Uri.parse('https://cdn.example.test/perfume.png'),
      );
    });

    test('persists and reloads a runtime server address', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await AppConfig.setApiBaseUrl('http://192.168.100.119:8000/api/v1');
      expect(AppConfig.apiBaseUrl, 'http://192.168.100.119:8000/api/v1');

      await AppConfig.initialize();
      expect(AppConfig.apiBaseUrl, 'http://192.168.100.119:8000/api/v1');
    });
  });
}
