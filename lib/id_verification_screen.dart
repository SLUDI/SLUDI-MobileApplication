// lib/id_verification_screen.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'otp_verification_screen.dart';
import 'app_theme.dart';

class IDVerificationScreen extends StatefulWidget {
  const IDVerificationScreen({super.key});

  @override
  State<IDVerificationScreen> createState() => _IDVerificationScreenState();
}

class _IDVerificationScreenState extends State<IDVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idNumberController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyID() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.verifyDID(_idNumberController.text.trim());
      
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              idNumber: _idNumberController.text.trim(),
              verificationData: result['data'],
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Verification failed';
        });
        _showErrorDialog(result['error'] ?? 'Verification failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred';
      });
      _showErrorDialog('An unexpected error occurred');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Verification Failed', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
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
                  
                  const SizedBox(height: 40),
                  
                  // Step indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Step 1 of 3',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'ID Verification',
                    style: AppTheme.headingStyle,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    'Enter your Digital ID Number to verify your identity and get started.',
                    style: AppTheme.subtitleStyle,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // ID Card Icon
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.3),
                            AppTheme.primaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        size: 60,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Input Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.glassDecoration(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Digital ID Number',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _idNumberController,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            keyboardType: TextInputType.number,
                            decoration: AppTheme.inputDecoration(
                              hintText: 'Enter your 12-digit ID',
                              prefixIcon: Icons.badge_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your Digital ID number';
                              }
                              if (value.length < 8) {
                                return 'ID number must be at least 8 digits';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyID,
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
                                        Text(
                                          'Verify ID',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Info text
                  Center(
                    child: Text(
                      'Your data is encrypted and secure',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: Colors.white.withOpacity(0.4)),
                        const SizedBox(width: 6),
                        Text(
                          'Protected by SLUDI Security',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
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
    );
  }
}