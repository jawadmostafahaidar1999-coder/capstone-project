// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api;

  AuthService({required ApiClient apiClient}) : _api = apiClient;

  AppUser? _currentUser;
  String? _token;

  AppUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _currentUser != null;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);

    if (savedToken == null) return;

    _token = savedToken;
    _api.setAuthToken(savedToken);

    try {
      final json = await _api.get('/me', auth: true);
      final userJson = _extractUserJson(json);
      if (userJson != null) {
        _currentUser = AppUser.fromJson(userJson);
        await _persistSession();
      }
    } on ApiException {
      await logout();
    } catch (_) {
      final savedUserJson = prefs.getString(_userKey);
      if (savedUserJson != null) {
        final map = jsonDecode(savedUserJson) as Map<String, dynamic>;
        _currentUser = AppUser.fromJson(map);
      }
    }
  }

  Future<void> refreshCurrentUser() async {
    if (_token == null) return;

    try {
      final json = await _api.get('/me', auth: true);
      final userJson = _extractUserJson(json);
      if (userJson != null) {
        _currentUser = AppUser.fromJson(userJson);
        await _persistSession();
      }
    } on ApiException {
      // ignore
    }
  }

  Map<String, dynamic>? _extractUserJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      if (data['user'] is Map<String, dynamic>) {
        return data['user'] as Map<String, dynamic>;
      }
      return data;
    }
    if (json['user'] is Map<String, dynamic>) {
      return json['user'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<bool> uploadAndSetProfileImage({
    required List<int> bytes,
    required String filename,
  }) async {
    if (_token == null) return false;

    final json = await _api.uploadBytes(
      '/uploads',
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      auth: true,
      fields: {'folder': 'avatars'},
    );

    final data = json['data'];
    final path = (data is Map<String, dynamic>)
        ? data['path'] as String?
        : null;

    if (path == null || path.isEmpty) return false;

    return updateProfile(image: path);
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null && _currentUser != null) {
      await prefs.setString(_tokenKey, _token!);
      await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
    } else {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    final json = await _api.post(
      '/login',
      body: {'email': email, 'password': password},
    );

    final success =
        json['success'] as bool? ?? json['status'] as bool? ?? false;
    if (!success) return false;

    final data = json['data'] as Map<String, dynamic>?;

    _token = data?['token'] as String?;
    if (_token != null) _api.setAuthToken(_token);

    final userJson = data?['user'] as Map<String, dynamic>?;
    if (userJson != null) _currentUser = AppUser.fromJson(userJson);

    await _persistSession();
    await refreshCurrentUser();
    return true;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final json = await _api.post(
      '/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    final success =
        json['success'] as bool? ?? json['status'] as bool? ?? false;
    if (!success) return false;

    final data = json['data'] as Map<String, dynamic>?;

    _token = data?['token'] as String?;
    if (_token != null) _api.setAuthToken(_token);

    final userJson = data?['user'] as Map<String, dynamic>?;
    if (userJson != null) _currentUser = AppUser.fromJson(userJson);

    await _persistSession();
    return true;
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    _api.setAuthToken(null);
    await _persistSession();
  }

  Future<bool> updateProfile({String? name, String? image}) async {
    if (_token == null) return false;

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (image != null) body['image'] = image;

    if (body.isEmpty) return true;

    final json = await _api.put('/me', body: body, auth: true);

    final success = json['success'] == true;
    if (!success) return false;

    final userJson = _extractUserJson(json);
    if (userJson != null) {
      _currentUser = AppUser.fromJson(userJson);
      await _persistSession();
    }

    return true;
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    if (_token == null) return 'Not logged in';

    try {
      final json = await _api.post(
        '/me/change-password',
        auth: true,
        body: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPasswordConfirmation,
        },
      );

      final success = json['success'] == true;
      if (!success) {
        return json['message'] as String? ?? 'Failed to change password';
      }

      return null;
    } on ApiException catch (e) {
      return e.message.isNotEmpty ? e.message : 'Failed to change password';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }
}
