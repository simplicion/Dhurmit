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
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
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

  String get userType => _user?['userType']?.toString() ?? 'ORGANIZER';
  bool get isOrganizer => userType == 'ORGANIZER';
  bool get isMember => userType == 'MEMBER';

  Future<void> setUserType(String type) async {
    if (_user != null) {
      _user!['userType'] = type;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_user));
    }
  }

  /// Enables 100% offline usage immediately without requiring any internet connection.
  Future<void> enterOfflineMode() async {
    _user = {
      'id': 'offline_organizer',
      'displayName': 'Organizer (Offline)',
      'email': 'organizer@offline.dhurmit',
      'userType': 'ORGANIZER',
    };
    _activeWorkspace = {
      'id': 'offline_workspace',
      'name': 'Local Committee Ledger',
      'role': 'OWNER',
    };
    apiClient.authToken = 'offline_session_active';
    apiClient.workspaceId = 'offline_workspace';
    _isAuthenticated = true;
    _isLoading = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', 'offline_session_active');
      await prefs.setString('user_data', jsonEncode(_user));
      await prefs.setString('workspace_data', jsonEncode(_activeWorkspace));
    } catch (_) {}
  }

  Future<void> register(String displayName, String email, String password, {String? phone, String userType = 'ORGANIZER'}) async {
    final res = await apiClient.post('/auth/register', body: {
      'displayName': displayName,
      'email': email,
      'password': password,
      'userType': userType,
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

  Future<void> loginWith180(
    String code, {
    String? token,
    Map<String, dynamic>? user,
    String? redirectUri,
    String userType = 'ORGANIZER',
  }) async {
    final res = await apiClient.post('/auth/180/exchange', body: {
      'code': code,
      'userType': userType,
      if (token != null) 'token': token,
      if (user != null) 'user': user,
      if (redirectUri != null) 'redirectUri': redirectUri,
    });

    await _persistSession(res);
  }

  Future<void> loginWithMemberCredentials({
    required String committeeCode,
    required String phone,
    required String password,
  }) async {
    final res = await apiClient.post('/auth/member-login', body: {
      'committeeCode': committeeCode.trim().toUpperCase(),
      'phone': phone.trim(),
      'password': password.trim(),
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
