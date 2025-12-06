// lib/id_verification_screen.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'otp_verification_screen.dart'; // Keep OTP screen import

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
        // Success - navigate to OTP screen
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
        // Show error message
        setState(() {
          _errorMessage = result['error'] ?? 'Verification failed';
        });
        
        // Show error dialog
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
        title: const Text('Verification Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),  // White
              Color(0xFFD6E6F2),  // Light blue
            ],
            stops: [0.1, 0.9],
          ),                  
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1-side',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            
            const Text(
              'ID Confirmation',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            
            // Welcome message
            const Center(
              child: Column(
                children: [
                  Text(
                    "Please enter your Digital ID Number",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "to confirm your identity",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red[800],
                    fontSize: 14,
                  ),
                ),
              ),
            
            if (_errorMessage != null) const SizedBox(height: 20),
            
            // ID Number Input
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _idNumberController,
                decoration: InputDecoration(
                  labelText: 'Enter Digital ID No',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
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
            ),
            const SizedBox(height: 30),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyID,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13A4B4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}