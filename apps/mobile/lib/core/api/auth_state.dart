import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthState extends ChangeNotifier {
  final ApiClient apiClient;

  bool _isLoading = true;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _activeWorkspace;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get activeWorkspace => _activeWorkspace;

  AuthState({required this.apiClient}) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userStr = prefs.getString('user_data');
      final wsStr = prefs.getString('workspace_data');

      if (token != null && token.isNotEmpty) {
        apiClient.authToken = token;
        if (wsStr != null) {
          final ws = jsonDecode(wsStr) as Map<String, dynamic>;
          _activeWorkspace = ws;
          apiClient.workspaceId = ws['id'] as String?;
        }
        if (userStr != null) {
          _user = jsonDecode(userStr) as Map<String, dynamic>;
        }
        _isAuthenticated = true;
      }
    } catch (_) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String displayName, String email, String password, {String? phone}) async {
    final res = await apiClient.post('/auth/register', body: {
      'displayName': displayName,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });

    await _persistSession(res);
  }

  Future<void> login(String email, String password) async {
    final res = await apiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    await _persistSession(res);
  }

  Future<void> loginWith180(String code, {String? token, Map<String, dynamic>? user, String? redirectUri}) async {
    final res = await apiClient.post('/auth/180/exchange', body: {
      'code': code,
      if (token != null) 'token': token,
      if (user != null) 'user': user,
      if (redirectUri != null) 'redirectUri': redirectUri,
    });

    await _persistSession(res);
  }

  Future<void> _persistSession(dynamic res) async {
    if (res is Map<String, dynamic>) {
      final tokens = res['tokens'] as Map<String, dynamic>;
      final token = tokens['accessToken'] as String;
      apiClient.authToken = token;

      _user = res['user'] as Map<String, dynamic>?;
      _activeWorkspace = res['workspace'] as Map<String, dynamic>?;

      if (_activeWorkspace != null) {
        apiClient.workspaceId = _activeWorkspace!['id'] as String?;
      }

      _isAuthenticated = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      if (_user != null) {
        await prefs.setString('user_data', jsonEncode(_user));
      }
      if (_activeWorkspace != null) {
        await prefs.setString('workspace_data', jsonEncode(_activeWorkspace));
      }
    }
  }

  Future<void> logout() async {
    try {
      await apiClient.post('/auth/logout');
    } catch (_) {}

    apiClient.authToken = null;
    apiClient.workspaceId = null;
    _isAuthenticated = false;
    _user = null;
    _activeWorkspace = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('workspace_data');
  }
}
