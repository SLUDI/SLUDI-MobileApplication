// lib/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_project/login_screen.dart';
import 'package:new_project/api_service.dart';
import 'package:new_project/app_theme.dart';
import 'package:new_project/backup_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String idNumber;

  const RegisterScreen({
    super.key,
    required this.idNumber,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.createWallet(
        widget.idNumber,
        _passwordController.text,
      );

      setState(() => _isLoading = false);

      if (response['success'] == true) {
        _showSuccessSnackBar(response['message'] ?? 'Registration successful!');
        
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted) {
          final mnemonic = response['mnemonic'];
          if (mnemonic != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BackupScreen(mnemonic: mnemonic)),
            );
          } else {
            // Fallback if no mnemonic (shouldn't happen with new logic)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      } else {
        final err = response['error'] ?? 'Registration failed';
        final where = response['where'];
        final msg = where != null ? '[$where] $err' : err;
        _showErrorSnackBar(msg);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Network error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Step indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Step 3 of 3',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    const Text(
                      'Create Account',
                      style: AppTheme.headingStyle,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Set up your secure password to protect your digital identity",
                      style: AppTheme.subtitleStyle,
                    ),

                    const SizedBox(height: 40),

                    // Form card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.glassDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Digital ID display
                          Text(
                            'Digital ID Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  color: AppTheme.primaryColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    widget.idNumber,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.verified,
                                  color: Colors.green.withOpacity(0.8),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Colors.green.withOpacity(0.8)),
                              const SizedBox(width: 6),
                              Text(
                                'Verified and ready to register',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Password field
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: AppTheme.inputDecoration(
                              hintText: 'Create a strong password',
                              prefixIcon: Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: _validatePassword,
                          ),

                          const SizedBox(height: 20),

                          // Confirm Password field
                          Text(
                            'Confirm Password',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: AppTheme.inputDecoration(
                              hintText: 'Confirm your password',
                              prefixIcon: Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 32),

                          // Register button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: AppTheme.primaryButtonStyle,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_add_rounded, size: 22),
                                        SizedBox(width: 10),
                                        Text(
                                          'Create Account',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                        child: const Text(
                          'Already have an account? Sign in',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Security note
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Colors.white.withOpacity(0.4)),
                          const SizedBox(width: 8),
                          Text(
                            'Your data is protected with encryption',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}