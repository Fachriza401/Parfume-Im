import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_response.dart';
import '../core/storage/session_store.dart';
import '../models/models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Owns the session: token persistence, profile, login/register/logout.
///
/// The [ApiClient] is wired to [signOut] so any 401 anywhere in the app drops
/// the user back to the login screen automatically.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required ApiClient api, required SessionStore store})
    : _api = api,
      _store = store {
    _restore();
  }

  final ApiClient _api;
  final SessionStore _store;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _busy;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;

  void _restore() {
    final token = _store.readToken();
    _user = _store.readUser();

    if (token == null || token.isEmpty || _user == null) {
      _status = AuthStatus.unauthenticated;
      return;
    }

    _api.setToken(token);
    _status = AuthStatus.authenticated;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      '/auth/login',
      body: <String, dynamic>{'email': email, 'password': password},
    );

    return _persist(json);
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
  }) async {
    final json = await _api.post(
      '/auth/register',
      body: <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );

    return _persist(json);
  }

  Future<AuthSession> _persist(Map<String, dynamic> json) async {
    // The token and user live inside the `data` envelope, not at the root.
    final session = AuthSession.fromJson(parseDataEnvelope(json));

    if (session.token.isEmpty) {
      throw ApiException(message: 'Token tidak diterima dari server.');
    }

    _api.setToken(session.token);
    await _store.save(session);

    _user = session.user;
    _status = AuthStatus.authenticated;
    notifyListeners();

    return session;
  }

  Future<AppUser> refreshProfile() async {
    final json = await _api.get('/auth/me');
    final user = AppUser.fromJson(parseDataEnvelope(json));

    _user = user;
    await _store.saveUser(user);
    notifyListeners();

    return user;
  }

  Future<AppUser> updateProfile({
    String? name,
    String? phone,
    String? address,
    String? avatarUrl,
    String? password,
    String? currentPassword,
    String? passwordConfirmation,
  }) async {
    final json = await _api.patch(
      '/auth/profile',
      body: <String, dynamic>{
        if (name != null && name.isNotEmpty) 'name': name,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (password != null && password.isNotEmpty) 'password': password,
        if (currentPassword != null && currentPassword.isNotEmpty)
          'current_password': currentPassword,
        if (passwordConfirmation != null && passwordConfirmation.isNotEmpty)
          'password_confirmation': passwordConfirmation,
      },
    );

    final user = AppUser.fromJson(parseDataEnvelope(json));

    _user = user;
    await _store.saveUser(user);
    notifyListeners();

    return user;
  }

  Future<String> uploadProfileImage(String filePath) async {
    final json = await _api.uploadImage('/media/images', filePath);
    final imageUrl = parseDataEnvelope(json)['image_url']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw ApiException(message: 'Server tidak mengembalikan foto profil.');
    }
    return imageUrl;
  }

  /// Password change reuses the profile endpoint so the current password can be
  /// verified server-side before the token is reissued.
  Future<AppUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) => updateProfile(
    password: newPassword,
    currentPassword: currentPassword,
    passwordConfirmation: confirmPassword,
  );

  Future<void> forgotPassword(String email) async {
    await _api.post(
      '/auth/forgot-password',
      body: <String, dynamic>{'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.post(
      '/auth/reset-password',
      body: <String, dynamic>{
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<void> signOut() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // A revoked or expired token still means we must clear local state.
    }

    await clearSession();
  }

  /// Alias used by the profile screen UI.
  Future<void> logout() => signOut();

  Future<void> clearSession() async {
    _api.setToken(null);
    await _store.clear();

    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
