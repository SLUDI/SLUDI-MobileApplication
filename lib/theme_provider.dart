import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme Provider for managing light/dark theme preference
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  
  bool _isDarkMode = true;
  bool _isInitialized = false;
  
  bool get isDarkMode => _isDarkMode;
  bool get isLightMode => !_isDarkMode;
  bool get isInitialized => _isInitialized;
  
  ThemeProvider() {
    _loadThemePreference();
  }
  
  /// Load theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? true; // Default to dark mode
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error loading theme preference: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  /// Toggle between dark and light mode
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _saveThemePreference();
  }
  
  /// Set dark mode explicitly
  Future<void> setDarkMode() async {
    if (!_isDarkMode) {
      _isDarkMode = true;
      notifyListeners();
      await _saveThemePreference();
    }
  }
  
  /// Set light mode explicitly
  Future<void> setLightMode() async {
    if (_isDarkMode) {
      _isDarkMode = false;
      notifyListeners();
      await _saveThemePreference();
    }
  }
  
  /// Save theme preference to SharedPreferences
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }
}
