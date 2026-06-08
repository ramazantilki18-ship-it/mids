import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../data/mock_data.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isAuthenticated = false;

  UserModel? get user => _user;
  UserModel? get currentUser => _user; // Ekranlarla uyumluluk için alias
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final savedUsername = prefs.getString('saved_username');
    final savedPassword = prefs.getString('saved_password');

    if (rememberMe && savedUsername != null) {
      try {
        // Önce SharedPreferences'te saklanan kullanıcılar arasında ara
        final usersJson = prefs.getString('users_json');
        if (usersJson != null) {
          final List<dynamic> decoded = jsonDecode(usersJson);
          final users = decoded.map((e) => UserModel.fromJson(Map<String, dynamic>.from(e))).toList();
          try {
            _user = users.firstWhere((u) => u.username.toLowerCase() == savedUsername.toLowerCase().trim());
            // Şifre kontrolü
            final correctPassword = _user!.password ?? '12345';
            if (savedPassword == correctPassword) {
              _isAuthenticated = true;
            } else {
              _user = null;
            }
          } catch (_) {
            _user = null;
          }
        } else {
          // MockData'dan kontrol et
          try {
            _user = MockData.users.firstWhere((u) => u.username.toLowerCase() == savedUsername.toLowerCase().trim());
            if (savedPassword == '12345') {
              _isAuthenticated = true;
            } else {
              _user = null;
            }
          } catch (_) {
            _user = null;
          }
        }
      } catch (e) {
        // Hata durumunda sessizce devam et
        _user = null;
      }
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password, {bool rememberMe = false}) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();
      final prefs = await SharedPreferences.getInstance();
      
      // Önce SharedPreferences'te saklanan kullanıcılar arasında ara
      UserModel? found;
      final usersJson = prefs.getString('users_json');
      if (usersJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(usersJson);
          final users = decoded.map((e) => UserModel.fromJson(Map<String, dynamic>.from(e))).toList();
          found = users.firstWhere((u) => u.username.toLowerCase() == normalizedUsername);
        } catch (_) {
          found = null;
        }
      }

      // Fallback to MockData
      if (found == null) {
        try {
          found = MockData.users.firstWhere((u) => u.username.toLowerCase() == normalizedUsername);
        } catch (_) {
          found = null;
        }
      }

      if (found == null) {
        throw Exception('Kullanıcı bulunamadı. Lütfen kullanıcı adınızı kontrol edin.');
      }

      // Şifre kontrolü
      final correctPassword = found.password ?? '12345';
      if (password.trim() != correctPassword.trim()) {
        if (found.password == null) {
          throw Exception('Şifre belirlenmemiş. Lütfen sistem yöneticisine başvurun.');
        } else {
          throw Exception('Şifre yanlış. Lütfen tekrar deneyin.');
        }
      }

      _user = found;
      _isAuthenticated = true;

      if (rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_username', _user!.username);
        await prefs.setString('saved_password', password);
      } else {
        await prefs.setBool('remember_me', false);
        await prefs.remove('saved_username');
        await prefs.remove('saved_password');
      }

      notifyListeners();
      return true;
    } catch (e) {
      print('Login error: $e'); // Debug için
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_me');
    await prefs.remove('saved_username');
    await prefs.remove('saved_password');
    notifyListeners();
  }
}
