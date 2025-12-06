// lib/screens/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import 'api_service.dart';
import 'register_screen.dart';

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
                  Icon(Icons.check_circle, 
                    color: Colors.green[700], 
                    size: _isSmallScreen ? 22 : 24
                  ),
                  SizedBox(width: _isSmallScreen ? 8 : 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: _isSmallScreen ? _fontSizeBody : _fontSizeTitle - 2,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
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
                  color: Colors.black87,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13A4B4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: _isSmallScreen ? 12 : 14,
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
    final defaultPinTheme = PinTheme(
      width: _pinFieldSize,
      height: _pinFieldSize,
      textStyle: TextStyle(
        fontSize: _fontSizeBody,
        color: const Color.fromRGBO(30, 60, 87, 1),
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFF13A4B4)),
      borderRadius: BorderRadius.circular(12),
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFF13A4B4)),
      borderRadius: BorderRadius.circular(12),
      color: const Color.fromRGBO(234, 239, 243, 1),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'OTP Confirmation',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _fontSizeBody,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF13A4B4),
      ),
      body: SafeArea(
        child: Container(
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
          padding: EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: _verticalPadding,
          ),
          child: _buildContent(defaultPinTheme, focusedPinTheme, submittedPinTheme),
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
            Icon(
              Icons.verified_user_outlined,
              size: _iconSize,
              color: const Color(0xFF13A4B4).withOpacity(0.8),
            ),
            
            SizedBox(height: _isSmallScreen ? 16 : 20),
            
            // Title
            Text(
              "OTP Verification",
              style: TextStyle(
                fontSize: _fontSizeTitle,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF13A4B4),
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: _isSmallScreen ? 12 : 16),
            
            // Instruction message with dynamic email
            Text(
              "We've sent a 6-digit verification code to $_maskedEmail",
              style: TextStyle(
                fontSize: _fontSizeBody,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: _isSmallScreen ? 6 : 8),
            
            // Display ID number being verified
            Text(
              "Verifying ID: ${widget.idNumber}",
              style: TextStyle(
                fontSize: _fontSizeSmall,
                color: Colors.grey,
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
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[800], size: 20),
                    SizedBox(width: _isSmallScreen ? 8 : 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[800],
                          fontSize: _fontSizeSmall,
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
            
            // Resend Code Section - FIXED VERSION
            Container(
              padding: EdgeInsets.all(_isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildResendSection(),
            ),
            
            SizedBox(height: _isSmallScreen ? 30 : 40),
            
            // Verify Button
            SizedBox(
              width: double.infinity,
              height: _buttonHeight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13A4B4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: const Color(0xFF13A4B4).withOpacity(0.3),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified, size: _isSmallScreen ? 18 : 20),
                          SizedBox(width: _isSmallScreen ? 6 : 8),
                          Text(
                            'Verify OTP',
                            style: TextStyle(
                              fontSize: _fontSizeBody,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            SizedBox(height: _isSmallScreen ? 16 : 20),
            
            // Back button
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: Text(
                'Back to ID Entry',
                style: TextStyle(
                  fontSize: _fontSizeSmall,
                  color: const Color(0xFF13A4B4),
                ),
              ),
            ),
            
            // Footer note - only show on larger screens or if there's space
            if (_isMediumScreen || _isLargeScreen)
              Padding(
                padding: EdgeInsets.only(top: _isSmallScreen ? 16 : 20),
                child: Text(
                  'If you don\'t receive the code within 5 minutes, please check your spam folder',
                  style: TextStyle(
                    fontSize: _fontSizeSmall - 2,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
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
                color: _canResend ? const Color(0xFF13A4B4) : Colors.grey,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                _remainingTime > 0
                    ? 'Resend code in $_remainingTime seconds'
                    : 'Ready for new code?',
                style: TextStyle(
                  fontSize: _fontSizeSmall,
                  color: _canResend ? const Color(0xFF13A4B4) : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (_canResend) ...[
            SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : resendCode,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF13A4B4)),
                      ),
                    )
                  : Text(
                      'Resend Now',
                      style: TextStyle(
                        fontSize: _fontSizeSmall,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF13A4B4),
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
          color: _canResend ? const Color(0xFF13A4B4) : Colors.grey,
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
              color: _canResend ? const Color(0xFF13A4B4) : Colors.grey,
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
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF13A4B4)),
                      ),
                    )
                  : Text(
                      'Resend Now',
                      style: TextStyle(
                        fontSize: _fontSizeSmall,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF13A4B4),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}