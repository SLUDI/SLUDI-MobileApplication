import 'package:flutter/material.dart';
import 'package:new_project/api_service.dart';
import 'package:new_project/app_theme.dart';
import 'package:new_project/login_screen.dart';

class RecoverWalletScreen extends StatefulWidget {
  const RecoverWalletScreen({super.key});

  @override
  State<RecoverWalletScreen> createState() => _RecoverWalletScreenState();
}

class _RecoverWalletScreenState extends State<RecoverWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _didController = TextEditingController();
  final _mnemonicController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _recover() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.recoverWallet(
        _didController.text.trim(),
        _passwordController.text,
        _mnemonicController.text.trim(),
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet recovered successfully! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Recovery failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const Text(
                    'Recover Wallet',
                    style: AppTheme.headingStyle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your details to restore access to your wallet.',
                    style: AppTheme.subtitleStyle,
                  ),
                  const SizedBox(height: 32),
                  
                  // DID Input
                  Text(
                    'Digital ID Number (NIC)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _didController,
                    style: const TextStyle(color: Colors.white),
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Enter your ID number',
                      prefixIcon: Icons.badge_outlined,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Mnemonic Input
                  Text(
                    'Seed Phrase (12 Words)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _mnemonicController,
                    style: const TextStyle(color: Colors.white),
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Enter your 12-word recovery phrase',
                      prefixIcon: Icons.lock_open_rounded,
                    ),
                    maxLines: 3,
                    validator: (v) {
                       if (v == null || v.isEmpty) return 'Required';
                       if (v.trim().split(' ').length != 12) {
                         return 'Phrase must be exactly 12 words';
                       }
                       return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // New Password Input
                  Text(
                    'New Password (for this device)',
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
                    style: const TextStyle(color: Colors.white),
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Create a password to secure keys locally',
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
                    validator: (v) => (v != null && v.length < 6) 
                        ? 'Password must be at least 6 characters' 
                        : null,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _recover,
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
                          : const Text(
                              'Recover Wallet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
