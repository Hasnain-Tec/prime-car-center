import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_client.dart';

class SessionController extends ChangeNotifier {
  final ApiClient api;
  AppUser? user;
  WorkshopInfo workshop = const WorkshopInfo();
  bool loading = true;

  SessionController(this.api);

  bool get signedIn => user != null;
  bool can(String code) => user?.can(code) ?? false;

  Future<void> initialize() async {
    await api.loadTokens();

    if (api.accessToken != null) {
      try {
        final data = await api.get('auth/me/');
        user = AppUser.fromJson(data as Map<String, dynamic>);
        await _cacheUser();
      } catch (_) {
        await api.clearTokens();
        user = null;
      }
    }

    await loadWorkshop();

    loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await api.post('auth/login/',
        body: {'email': email, 'password': password}) as Map<String, dynamic>;
    await api.saveTokens(data['access'].toString(), data['refresh'].toString());
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    await _cacheUser();
    await loadWorkshop();
    notifyListeners();
  }

  Future<String> register(
      {required String fullName,
      required String email,
      required String phone,
      required String password}) async {
    final data = await api.post('auth/register/', body: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirm': password,
    }) as Map<String, dynamic>;
    return data['message']?.toString() ?? 'Registration submitted.';
  }

  Future<void> refreshMe() async {
    final data = await api.get('auth/me/');
    user = AppUser.fromJson(data as Map<String, dynamic>);
    await _cacheUser();
    notifyListeners();
  }

  Future<void> loadWorkshop() async {
    try {
      final data = await api.get('workshop-settings/');
      workshop = WorkshopInfo.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      workshop = const WorkshopInfo();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await api.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pcc_user');
    user = null;
    notifyListeners();
  }

  Future<void> _cacheUser() async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pcc_user', jsonEncode(user!.toJson()));
  }
}
