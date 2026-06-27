import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';

class TokenStorage {
  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _slugKey = 'auth.slug';
  static const _userKey = 'auth.user';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_accessTokenKey, accessToken);

    if (refreshToken == null || refreshToken.isEmpty) {
      await prefs.remove(_refreshTokenKey);
      return;
    }

    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> get accessToken async {
    final prefs = await _prefs;
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> get refreshToken async {
    final prefs = await _prefs;
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_slugKey);
    await prefs.remove(_userKey);
  }

  Future<void> saveSlug(String slug) async {
    final prefs = await _prefs;
    await prefs.setString(_slugKey, slug);
  }

  Future<String?> getSlug() async {
    final prefs = await _prefs;
    return prefs.getString(_slugKey);
  }

  Future<void> saveUser(User user) async {
    final prefs = await _prefs;
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await _prefs;
    final rawUser = prefs.getString(_userKey);

    if (rawUser == null || rawUser.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return User.fromJson(decoded);
      }

      if (decoded is Map) {
        return User.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      await prefs.remove(_userKey);
    }

    return null;
  }
}
