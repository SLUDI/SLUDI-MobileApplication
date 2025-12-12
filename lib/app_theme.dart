import 'package:flutter/material.dart';

/// SLUDI App Theme Constants
/// Centralized styling for consistent professional look
class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF13A4B4);
  static const Color accentColor = Color(0xFFFFD700);
  
  // Dark Theme Colors
  static const Color darkBg1 = Color(0xFF0F0F1A);
  static const Color darkBg2 = Color(0xFF1A1A2E);
  static const Color darkBg3 = Color(0xFF16213E);
  
  // Text Colors
  static const Color textPrimary = Colors.white;
  static Color textSecondary = Colors.white.withOpacity(0.7);
  static Color textMuted = Colors.white.withOpacity(0.5);
  
  // Gradients
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBg1, darkBg2, darkBg3],
    stops: [0.0, 0.5, 1.0],
  );
  
  static LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryColor.withOpacity(0.8)],
  );
  
  // Glassmorphism decoration
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
  
  // Input decoration for text fields
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
  
  // Primary button style
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
  
  // Outline button style
  static ButtonStyle outlineButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 18),
    side: const BorderSide(color: Colors.white, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );
  
  // Card text style
  static const TextStyle headingStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: 0.5,
  );
  
  static TextStyle subtitleStyle = TextStyle(
    fontSize: 16,
    color: textSecondary,
    height: 1.5,
  );
}
