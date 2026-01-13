import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart'; // To navigate to WelcomeScreen
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Navigate to WelcomeScreen after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        
        // We always use a dark/gradient background for splash screen for "wow" factor
        // but can adapt slightly based on theme if needed. 
        // For consistency with WelcomeScreen, we keep it premium dark/gradient.
        
        return Scaffold(
          body: Stack(
            children: [
               // Background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode 
                      ? [
                          const Color(0xFF0F2027),
                          const Color(0xFF203A43),
                          const Color(0xFF2C5364),
                        ]
                      : [
                          const Color(0xFF13A4B4),
                          const Color(0xFF0D8A99),
                          const Color(0xFF086E7D),
                        ],
                  ),
                ),
              ),
              
              // Animated Logo & Text
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1), // Subtle glass effect
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF13A4B4).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 12.0,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 3),
                                  blurRadius: 10,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                            children: [
                              TextSpan(
                                text: 'SL',
                                style: TextStyle(color: Color(0xFF13A4B4)), // Cyan
                              ),
                              TextSpan(
                                text: 'U',
                                style: TextStyle(color: Color(0xFFFFD700)), // Gold
                              ),
                              TextSpan(
                                text: 'DI',
                                style: TextStyle(color: Color(0xFF13A4B4)), // Cyan
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // 'SLUDI' text removed from here as it's now in the logo above
                          const SizedBox(height: 8),
                          Text(
                            'Sri Lanka\'s Digital Identity',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Loading Indicator at bottom
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
