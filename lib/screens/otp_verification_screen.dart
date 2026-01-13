// lib/screens/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'register_screen.dart';
import '../theme/app_theme.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String idNumber;
  final Map<String, dynamic>? verificationData;
  
  const OTPVerificationScreen({
    super.key,
    required this.idNumber,
    this.verificationData,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  final int _resendTimeout = 30; // seconds
  int _remainingTime = 30;
  late Timer _timer;
  bool _isLoading = false;
  String? _errorMessage;
  String? _maskedEmail;
  bool _canResend = false;

  // Responsive helper methods
  bool get _isSmallScreen => MediaQuery.of(context).size.width < 600;
  bool get _isMediumScreen => 
      MediaQuery.of(context).size.width >= 600 && 
      MediaQuery.of(context).size.width < 1200;
  bool get _isLargeScreen => MediaQuery.of(context).size.width >= 1200;

  double get _horizontalPadding {
    if (_isSmallScreen) return 24.0;
    if (_isMediumScreen) return 32.0;
    return 48.0;
  }

  double get _verticalPadding {
    if (_isSmallScreen) return 16.0;
    if (_isMediumScreen) return 20.0;
    return 24.0;
  }

  double get _iconSize {
    if (_isSmallScreen) return 70.0;
    if (_isMediumScreen) return 80.0;
    return 90.0;
  }

  double get _fontSizeTitle {
    if (_isSmallScreen) return 22.0;
    if (_isMediumScreen) return 24.0;
    return 26.0;
  }

  double get _fontSizeBody {
    if (_isSmallScreen) return 14.0;
    if (_isMediumScreen) return 16.0;
    return 17.0;
  }

  double get _fontSizeSmall {
    if (_isSmallScreen) return 12.0;
    if (_isMediumScreen) return 14.0;
    return 15.0;
  }

  double get _pinFieldSize {
    if (_isSmallScreen) return 50.0;
    if (_isMediumScreen) return 56.0;
    return 60.0;
  }

  double get _buttonHeight {
    if (_isSmallScreen) return 48.0;
    if (_isMediumScreen) return 52.0;
    return 56.0;
  }

  // Dialog responsive methods
  double get _dialogWidth {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 400) return screenWidth * 0.85;
    if (screenWidth < 600) return screenWidth * 0.75;
    return 400.0; // Max width for larger screens
  }

  double get _dialogPadding {
    if (_isSmallScreen) return 16.0;
    if (_isMediumScreen) return 20.0;
    return 24.0;
  }

  @override
  void initState() {
    super.initState();
    _remainingTime = _resendTimeout;
    startTimer();
    _extractEmailFromVerificationData();
  }

  void _extractEmailFromVerificationData() {
    try {
      // Safely extract email from verification data
      if (widget.verificationData != null) {
        String? email;
        
        // Check if data exists and is a Map
        if (widget.verificationData!['data'] != null && 
            widget.verificationData!['data'] is Map) {
          final data = widget.verificationData!['data'] as Map;
          email = data['email'] ?? data['userEmail'];
        }
        
        // If not found in data, check in the root
        if (email == null) {
          email = widget.verificationData!['email'] ?? widget.verificationData!['userEmail'];
        }
        
        _maskedEmail = _maskEmail(email?.toString() ?? 'your email');
      } else {
        _maskedEmail = 'your email';
      }
    } catch (e) {
      print('Error extracting email: $e');
      _maskedEmail = 'your email';
    }
  }

  String _maskEmail(String email) {
    try {
      if (email.contains('@')) {
        final parts = email.split('@');
        final username = parts[0];
        final domain = parts[1];
        
        if (username.length <= 2) {
          return '${'*' * username.length}@$domain';
        } else {
          final visiblePart = username.substring(0, 2);
          final maskedPart = '*' * (username.length - 2);
          return '$visiblePart$maskedPart@$domain';
        }
      }
      return email;
    } catch (e) {
      return 'your email';
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
          _canResend = false;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void resendCode() {
    if (!_canResend) return;
    
    setState(() {
      _remainingTime = _resendTimeout;
      _canResend = false;
      _errorMessage = null;
    });
    
    startTimer();
    _resendOTP();
  }

  Future<void> _resendOTP() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final result = await ApiService.resendOTP(widget.idNumber);

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP has been resent successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Clear previous OTP
        _otpController.clear();
        
        // Show success dialog
        _showSuccessDialog(
          'New OTP Sent', 
          'A new OTP has been sent to $_maskedEmail. Please check your inbox.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend OTP: ${result['error']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend OTP: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    
    if (otp.isEmpty || otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit OTP';
      });
      return;
    }

    // Validate that OTP contains only digits
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _errorMessage = 'OTP should contain only numbers';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.verifyOTP(widget.idNumber, otp);

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        // OTP verification successful - navigate to Registration screen
        _showSuccessDialog(
          'Verification Successful!', 
          'Your identity has been verified successfully.',
          () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RegisterScreen(
                  idNumber: widget.idNumber, // Pass the verified ID number
                ),
              ),
            );
          },
        );
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'OTP verification failed';
        });
        
        // Clear OTP field on failure
        _otpController.clear();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      print('OTP Verification Error: $e');
    }
  }

  void _showSuccessDialog(String title, String message, [VoidCallback? onOk]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.darkBg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: _dialogWidth,
          padding: EdgeInsets.all(_dialogPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.check_circle, 
                      color: Colors.green, 
                      size: _isSmallScreen ? 22 : 24
                    ),
                  ),
                  SizedBox(width: _isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: _isSmallScreen ? _fontSizeBody : _fontSizeTitle - 2,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: _isSmallScreen ? 16 : 20),
              
              // Message
              Text(
                message,
                style: TextStyle(
                  fontSize: _isSmallScreen ? _fontSizeSmall : _fontSizeBody,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.left,
              ),
              
              SizedBox(height: _isSmallScreen ? 20 : 24),
              
              // OK Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onOk ?? () => Navigator.pop(context),
                  style: AppTheme.primaryButtonStyle.copyWith(
                    padding: WidgetStateProperty.all(
                      EdgeInsets.symmetric(vertical: _isSmallScreen ? 12 : 14),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: _isSmallScreen ? _fontSizeBody : _fontSizeBody + 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dark theme pin styles
    final defaultPinTheme = PinTheme(
      width: _pinFieldSize,
      height: _pinFieldSize,
      textStyle: TextStyle(
        fontSize: _fontSizeBody,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppTheme.primaryColor, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppTheme.primaryColor),
      borderRadius: BorderRadius.circular(12),
      color: AppTheme.primaryColor.withOpacity(0.2),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: _verticalPadding,
            ),
            child: Column(
              children: [
                // Custom header matching other screens
                Row(
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
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Step 2 of 3',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
                const SizedBox(height: 24),
                // Main content
                Expanded(
                  child: _buildContent(defaultPinTheme, focusedPinTheme, submittedPinTheme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(PinTheme defaultPinTheme, PinTheme focusedPinTheme, PinTheme submittedPinTheme) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.vertical -
                    AppBar().preferredSize.height,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Icon(
                Icons.verified_user_outlined,
                size: _iconSize,
                color: AppTheme.primaryColor,
              ),
            ),
            
            SizedBox(height: _isSmallScreen ? 24 : 32),
            
            // Title
            Text(
              "OTP Verification",
              style: AppTheme.headingStyle.copyWith(
                fontSize: _fontSizeTitle,
              ),
            ),
            
            SizedBox(height: _isSmallScreen ? 12 : 16),
            
            // Instruction message with dynamic email
            Text(
              "We've sent a 6-digit verification code to $_maskedEmail",
              style: AppTheme.subtitleStyle.copyWith(
                fontSize: _fontSizeBody,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: _isSmallScreen ? 6 : 8),
            
            // Display ID number being verified
            Text(
              "Verifying ID: ${widget.idNumber}",
              style: TextStyle(
                fontSize: _fontSizeSmall,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: _isSmallScreen ? 24 : 30),
            
            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(_isSmallScreen ? 12 : 16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    SizedBox(width: _isSmallScreen ? 8 : 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // OTP Input Field
            Pinput(
              length: 6,
              controller: _otpController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              keyboardType: TextInputType.number,
              onCompleted: (pin) => _verifyOTP(),
              onChanged: (value) {
                // Clear error when user starts typing
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),
            
            SizedBox(height: _isSmallScreen ? 24 : 30),
            
            // Resend Code Section
            Container(
              padding: EdgeInsets.all(_isSmallScreen ? 12 : 16),
              decoration: AppTheme.glassDecoration(opacity: 0.1, borderRadius: 12),
              child: _buildResendSection(),
            ),
            
            SizedBox(height: _isSmallScreen ? 30 : 40),
            
            // Verify Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
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
                            'Verify OTP',
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
            
            SizedBox(height: _isSmallScreen ? 24 : 32),
            
            // Security note
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
    );
  }

  Widget _buildResendSection() {
    // For very small screens, use a column layout
    if (MediaQuery.of(context).size.width < 350) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                color: _canResend ? AppTheme.primaryColor : Colors.white.withOpacity(0.5),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _remainingTime > 0
                    ? 'Resend code in $_remainingTime seconds'
                    : 'Ready for new code?',
                style: TextStyle(
                  fontSize: _fontSizeSmall,
                  color: _canResend ? AppTheme.primaryColor : Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (_canResend) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : resendCode,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    )
                  : Text(
                      'Resend Now',
                      style: TextStyle(
                        fontSize: _fontSizeSmall,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
            ),
          ],
        ],
      );
    }

    // For normal screens, use row layout with proper constraints
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.access_time,
          color: _canResend ? AppTheme.primaryColor : Colors.white.withOpacity(0.5),
          size: 18,
        ),
        SizedBox(width: _isSmallScreen ? 6 : 8),
        Expanded(
          child: Text(
            _remainingTime > 0
                ? 'Resend code in $_remainingTime seconds'
                : 'Ready for new code?',
            style: TextStyle(
              fontSize: _fontSizeSmall,
              color: _canResend ? AppTheme.primaryColor : Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_canResend) ...[
          SizedBox(width: _isSmallScreen ? 6 : 8),
          Flexible(
            child: TextButton(
              onPressed: _isLoading ? null : resendCode,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: _isSmallScreen ? 12 : 16,
                  vertical: _isSmallScreen ? 6 : 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    )
                  : Text(
                      'Resend Now',
                      style: TextStyle(
                        fontSize: _fontSizeSmall,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}