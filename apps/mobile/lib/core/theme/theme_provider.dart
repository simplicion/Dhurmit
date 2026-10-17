import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_color_tokens.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.blue;
  AppColorTokens _tokens = const BlueColorTokens();

  AppThemeMode get mode => _mode;
  AppColorTokens get tokens => _tokens;
  ThemeData get currentTheme => buildAppTheme(_tokens);

  ThemeProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'red') {
        _mode = AppThemeMode.red;
        _tokens = const RedColorTokens();
        notifyListeners();
      } else {
        _mode = AppThemeMode.blue;
        _tokens = const BlueColorTokens();
        notifyListeners();
      }
    } catch (_) {
      // Fallback to blue theme
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    _tokens = (mode == AppThemeMode.red)
        ? const RedColorTokens()
        : const BlueColorTokens();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == AppThemeMode.red ? 'red' : 'blue');
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final next = (_mode == AppThemeMode.blue)
        ? AppThemeMode.red
        : AppThemeMode.blue;
    await setTheme(next);
  }
}
