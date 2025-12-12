import 'package:flutter/material.dart';

/// SLUDI App Theme Constants
/// Centralized styling for consistent professional look
/// Supports both Dark and Light themes
class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF13A4B4);
  static const Color accentColor = Color(0xFFFFD700);
  
  // ========== DARK THEME COLORS ==========
  static const Color darkBg1 = Color(0xFF0F0F1A);
  static const Color darkBg2 = Color(0xFF1A1A2E);
  static const Color darkBg3 = Color(0xFF16213E);
  static const Color darkTextPrimary = Colors.white;
  static Color darkTextSecondary = Colors.white.withOpacity(0.7);
  static Color darkTextMuted = Colors.white.withOpacity(0.5);
  
  // ========== LIGHT THEME COLORS ==========
  static const Color lightBg1 = Color(0xFFFFFFFF);
  static const Color lightBg2 = Color(0xFFF5F7FA);
  static const Color lightBg3 = Color(0xFFE8EEF4);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static Color lightTextSecondary = const Color(0xFF64748B);
  static Color lightTextMuted = const Color(0xFF94A3B8);
  
  // Legacy compatible accessors (defaults to dark)
  static const Color textPrimary = darkTextPrimary;
  static Color textSecondary = darkTextSecondary;
  static Color textMuted = darkTextMuted;
  
  // ========== GRADIENTS ==========
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBg1, darkBg2, darkBg3],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBg1, lightBg2, lightBg3],
    stops: [0.0, 0.5, 1.0],
  );
  
  static LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryColor.withOpacity(0.8)],
  );
  
  // ========== THEME-AWARE GETTERS ==========
  
  /// Get background gradient based on theme
  static LinearGradient getGradient(bool isDarkMode) {
    return isDarkMode ? darkGradient : lightGradient;
  }
  
  /// Get background color based on theme
  static Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode ? darkBg1 : lightBg1;
  }
  
  /// Get card/surface color based on theme
  static Color getSurfaceColor(bool isDarkMode) {
    return isDarkMode ? darkBg2 : lightBg2;
  }
  
  /// Get primary text color based on theme
  static Color getTextPrimary(bool isDarkMode) {
    return isDarkMode ? darkTextPrimary : lightTextPrimary;
  }
  
  /// Get secondary text color based on theme
  static Color getTextSecondary(bool isDarkMode) {
    return isDarkMode ? darkTextSecondary : lightTextSecondary;
  }
  
  /// Get muted text color based on theme
  static Color getTextMuted(bool isDarkMode) {
    return isDarkMode ? darkTextMuted : lightTextMuted;
  }
  
  // ========== GLASSMORPHISM / CARD DECORATION ==========
  
  /// Glassmorphism decoration for dark theme
  static BoxDecoration glassDecoration({
    double opacity = 0.15,
    double borderRadius = 24,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: Colors.white.withOpacity(opacity),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 20,
          spreadRadius: 5,
        ),
      ],
    );
  }
  
  /// Card decoration for light theme
  static BoxDecoration lightCardDecoration({
    double borderRadius = 24,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: lightBg1,
      border: Border.all(
        color: const Color(0xFFE2E8F0),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
  
  /// Theme-aware card decoration
  static BoxDecoration getCardDecoration(bool isDarkMode, {double borderRadius = 24}) {
    return isDarkMode 
        ? glassDecoration(borderRadius: borderRadius) 
        : lightCardDecoration(borderRadius: borderRadius);
  }
  
  // ========== INPUT DECORATION ==========
  
  /// Input decoration for dark theme
  static InputDecoration inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      prefixIcon: Icon(prefixIcon, color: Colors.white.withOpacity(0.7)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
  
  /// Input decoration for light theme
  static InputDecoration lightInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: lightTextMuted),
      prefixIcon: Icon(prefixIcon, color: lightTextSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: lightBg2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
  
  /// Theme-aware input decoration
  static InputDecoration getInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    required bool isDarkMode,
  }) {
    return isDarkMode 
        ? inputDecoration(hintText: hintText, prefixIcon: prefixIcon, suffixIcon: suffixIcon)
        : lightInputDecoration(hintText: hintText, prefixIcon: prefixIcon, suffixIcon: suffixIcon);
  }
  
  // ========== BUTTON STYLES ==========
  
  /// Primary button style (works for both themes)
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 18),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 8,
    shadowColor: primaryColor.withOpacity(0.5),
  );
  
  /// Outline button style for dark theme
  static ButtonStyle outlineButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 18),
    side: const BorderSide(color: Colors.white, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );
  
  /// Outline button style for light theme
  static ButtonStyle lightOutlineButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    padding: const EdgeInsets.symmetric(vertical: 18),
    side: const BorderSide(color: primaryColor, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );
  
  /// Theme-aware outline button style
  static ButtonStyle getOutlineButtonStyle(bool isDarkMode) {
    return isDarkMode ? outlineButtonStyle : lightOutlineButtonStyle;
  }
  
  // ========== TEXT STYLES ==========
  
  /// Heading style for dark theme
  static const TextStyle headingStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: darkTextPrimary,
    letterSpacing: 0.5,
  );
  
  /// Heading style for light theme
  static const TextStyle lightHeadingStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: lightTextPrimary,
    letterSpacing: 0.5,
  );
  
  /// Theme-aware heading style
  static TextStyle getHeadingStyle(bool isDarkMode) {
    return isDarkMode ? headingStyle : lightHeadingStyle;
  }
  
  static TextStyle subtitleStyle = TextStyle(
    fontSize: 16,
    color: darkTextSecondary,
    height: 1.5,
  );
  
  static TextStyle lightSubtitleStyle = TextStyle(
    fontSize: 16,
    color: lightTextSecondary,
    height: 1.5,
  );
  
  /// Theme-aware subtitle style
  static TextStyle getSubtitleStyle(bool isDarkMode) {
    return isDarkMode ? subtitleStyle : lightSubtitleStyle;
  }
}
