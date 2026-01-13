// lib/login_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:new_project/face_detection_screen.dart';
import 'package:new_project/id_verification_screen.dart';
import 'package:new_project/offline_auth_dialog.dart';
import 'package:new_project/offline_auth_service.dart';
import 'package:new_project/storage_service.dart';
import 'package:new_project/app_theme.dart';
import 'package:pointycastle/api.dart' hide Padding;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/prime256v1.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'recover_wallet_screen.dart';
import 'main_screen.dart';
import 'api_service.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class LoginScreen extends StatefulWidget {
  final String? preFilledDid;
  final bool? isDeviceLocked;

  const LoginScreen({
    super.key,
    this.preFilledDid,
    this.isDeviceLocked = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _didController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final LocalAuthentication auth;
  bool _supportState = false;
  bool _isLoading = false;
  bool _isDidLocked = false;
  String? _deviceLockedDid;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    auth = LocalAuthentication();
    auth.isDeviceSupported().then(
      (bool isSuported) => setState(() {
        _supportState = isSuported;
      }),
    );

    _initializeDidLock();
  }

  Future<void> _initializeDidLock() async {
    final bool isDeviceLocked = await StorageService.isDeviceLocked();
    final String? registeredDid = await StorageService.getRegisteredDid();

    print('[LoginScreen] Device lock status: $isDeviceLocked');
    print('[LoginScreen] Registered DID: $registeredDid');

    if (isDeviceLocked && registeredDid != null) {
      setState(() {
        _deviceLockedDid = registeredDid;
        _didController.text = registeredDid;
        _isDidLocked = true;
      });
      print('[LoginScreen] 🔒 Device locked to DID: $registeredDid');
    } else if (widget.preFilledDid != null && widget.preFilledDid!.isNotEmpty) {
      setState(() {
        _didController.text = widget.preFilledDid!;
        _isDidLocked = widget.isDeviceLocked ?? false;
        if (widget.isDeviceLocked == true) {
          _deviceLockedDid = widget.preFilledDid;
        }
      });
      print('[LoginScreen] 📝 Pre-filled DID: ${widget.preFilledDid}');
    }
  }

  @override
  void dispose() {
    _didController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToMainScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  /// Fetch user data from API and store locally for offline use (QR scanning, etc.)
  Future<void> _fetchAndStoreUserData() async {
    try {
      print('[Login] 📥 Fetching user data for local storage...');
      
      final walletData = await ApiService.getWalletStatus();
      
      if (walletData['success'] == true && walletData['data'] != null) {
        // Store the complete wallet data for offline use
        await OfflineAuthService.storeUserDataLocally(walletData['data']);
        print('[Login]   User data stored locally for offline use');
      } else {
        print('[Login] ⚠️ Could not fetch user data: ${walletData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('[Login] ⚠️ Error storing user data locally: $e');
      // Don't fail the login if this fails - it's optional for offline features
    }
  }

  Future<void> _handleEmailPasswordLogin() async {
    // Basic validation
    if (_didController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both DID and password')),
      );
      return;
    }

    final String enteredDid = _didController.text.trim();
    final String password = _passwordController.text;

    // Check if device is locked to a different DID
    if (_deviceLockedDid != null && enteredDid != _deviceLockedDid) {
      _showDeviceLockedError();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('[Login] Starting authentication for DID: $enteredDid');

      // Step 1: Retrieve and decrypt private key
      print('[Login]   Retrieving stored keys...');
      final keys = await ApiService.getStoredKeys(enteredDid, password);

      if (keys == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid credentials or no wallet found'),
          ),
        );
        return;
      }

      final String privateKeyPem = keys['privateKey']!;
      print('[Login]   Private key decrypted successfully');

      // Step 2: Get challenge from backend
      print('[Login]   Requesting challenge from backend...');
      final challengeResult = await _getChallenge(enteredDid);

      if (!challengeResult['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${challengeResult['error']}'),
          ),
        );
        return;
      }

      final String challenge = challengeResult['challenge']!;
      print('[Login]   Received challenge: $challenge');

      // Step 3: Sign the challenge with private key
      print('[Login] ✍️ Signing challenge...');
      final String signature = await _signChallenge(challenge, privateKeyPem);
      print('[Login]   Challenge signed successfully');

      // Step 4: Verify signature with backend and get JWT token
      print('[Login]   Verifying signature with backend...');
      final verifyResult = await _verifyChallenge(enteredDid, signature);

      print('[Login] Verify result success: ${verifyResult['success']}');

      if (verifyResult['success'] == true) {
        final String? jwtToken = verifyResult['token'];

        if (jwtToken != null && jwtToken.isNotEmpty) {
          // Store the token in ApiService
          ApiService.setAuthToken(jwtToken);
          print('[Login]   JWT token stored in ApiService');

          //   Lock device to this DID
          if (!_isDidLocked && _deviceLockedDid == null) {
            await StorageService.setRegisteredDid(enteredDid);
            setState(() {
              _isDidLocked = true;
              _deviceLockedDid = enteredDid;
            });
            print('[Login] 🔒 Device now locked to DID: $enteredDid');
          }

          //   Fetch and store user data for offline features (QR scanning, etc.)
          await _fetchAndStoreUserData();

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Login successful!')));
          _navigateToMainScreen();
        } else {
          print('[Login]   Empty or null token received from verifyChallenge');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Login failed: No valid token received from server',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${verifyResult['error']}'),
          ),
        );
      }
    } catch (e, st) {
      print('[Login]   Authentication error: $e');
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed. Please try again.'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show offline authentication dialog with stored user data
  void _showOfflineAuthDialog() async {
    final enteredIdNumber = _didController.text.trim();
    if (enteredIdNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your ID number first')),
      );
      return;
    }

    print('[LoginScreen] Loading stored user data for offline auth...');

    // Get stored user data
    final userData = await StorageService.getUserData();

    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to access offline authentication'),
        ),
      );
      return;
    }

    print('[LoginScreen]   User data loaded: ${userData['fullName']}');
    print('[LoginScreen] User DOB: ${userData['dateOfBirth']}');

    showDialog(
      context: context,
      builder: (context) => OfflineAuthDialog(
        idNumber: enteredIdNumber,
        userData: userData, // Use stored user data
      ),
    );
  }

  void _showDeviceLockedError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.device_unknown, color: Colors.orange),
            SizedBox(width: 8),
            Text('Device Locked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This device is registered to Digital ID:',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _deviceLockedDid!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'For security reasons, you can only log in with the registered Digital ID on this device.',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: _clearDeviceLock,
            child: const Text(
              'Clear Device Lock',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDeviceLock() async {
    await StorageService.clearDeviceLock();
    setState(() {
      _isDidLocked = false;
      _deviceLockedDid = null;
      _didController.clear();
    });
    Navigator.pop(context); // Close the dialog

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device lock cleared. You can now enter any DID.'),
      ),
    );
  }

  Future<Map<String, dynamic>> _getChallenge(String did) async {
    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/api/wallet/generate-challenge',
      );
      print('[getChallenge] -> POST $uri');

      final body = jsonEncode({'did': did});
      print('[getChallenge] Request body: $body');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      print('[getChallenge] <-- ${response.statusCode}');
      print('[getChallenge] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final nonce = responseData['data']?['nonce'] ?? responseData['nonce'];
          if (nonce != null) {
            print('[getChallenge]   Extracted nonce: $nonce');
            return {'success': true, 'challenge': nonce.toString()};
          } else {
            print('[getChallenge]   No nonce found in response');
          }
        } else {
          print('[getChallenge]   API returned success: false');
        }
        return {'success': false, 'error': 'No challenge/nonce received'};
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['message'] ?? 'Failed to get challenge';
        print('[getChallenge]   HTTP Error: $errorMsg');
        return {'success': false, 'error': errorMsg};
      }
    } on TimeoutException catch (e) {
      print('[getChallenge] Timeout: $e');
      return {'success': false, 'error': 'Request timeout'};
    } on SocketException catch (e) {
      print('[getChallenge] Network error: $e');
      return {'success': false, 'error': 'Network error'};
    } catch (e, st) {
      print('[getChallenge] Error: $e');
      print(st);
      return {'success': false, 'error': 'Failed to get challenge'};
    }
  }

  // Sign a nonce/message
  Future<String> _signChallenge(String challenge, String privateKeyPem) async {
    final privateKey = _parsePrivateKeyFromPem(privateKeyPem);

    // Hash the message (SHA-256)
    final messageBytes = utf8.encode(challenge);
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(messageBytes));

    // Create and properly seed the secure random
    final secureRandom = FortunaRandom();
    final seedSource = Uint8List.fromList(
      List<int>.generate(
        32,
        (i) => (DateTime.now().microsecondsSinceEpoch + i) % 256,
      ),
    );
    secureRandom.seed(KeyParameter(seedSource));

    // Sign using ECDSA
    final signer = ECDSASigner(SHA256Digest());
    final params = ParametersWithRandom(
      PrivateKeyParameter<ECPrivateKey>(privateKey),
      secureRandom,
    );

    signer.init(true, params);
    final signature = signer.generateSignature(hash) as ECSignature;

    // Encode signature as DER format
    final signatureBytes = _encodeDERSignature(signature);
    return base64Encode(signatureBytes);
  }

  Future<Map<String, dynamic>> _verifyChallenge(
    String did,
    String signature,
  ) async {
    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/api/wallet/verify-challenge',
      );
      print('[verifyChallenge] -> POST $uri');

      final body = jsonEncode({'did': did, 'signature': signature});
      print('[verifyChallenge] Request body: ${body.length} chars');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      print('[verifyChallenge] <-- ${response.statusCode}');
      print('[verifyChallenge] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          // Extract JWT token from response
          final String? token =
              responseData['data']?['token'] ??
              responseData['token'] ??
              responseData['data']?['accessToken'] ??
              responseData['accessToken'] ??
              responseData['data']?['jwt'] ??
              responseData['jwt'];

          print('[verifyChallenge] Token extraction result: $token');

          if (token != null && token.isNotEmpty) {
            print(
              '[verifyChallenge]   JWT token extracted: ${token.substring(0, 30)}...',
            );
            return {
              'success': true,
              'message': responseData['message'] ?? 'Authentication successful',
              'token': token,
            };
          } else {
            print('[verifyChallenge]   No token found in response');
            return {
              'success': false,
              'error': 'No authentication token received from server',
            };
          }
        } else {
          return {
            'success': false,
            'error': responseData['message'] ?? 'Verification failed',
          };
        }
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error':
              errorData['message'] ??
              'Verification failed. Status: ${response.statusCode}',
        };
      }
    } on TimeoutException catch (e) {
      print('[verifyChallenge] Timeout: $e');
      return {'success': false, 'error': 'Request timeout'};
    } on SocketException catch (e) {
      print('[verifyChallenge] Network error: $e');
      return {'success': false, 'error': 'Network error'};
    } catch (e, st) {
      print('[verifyChallenge] Error: $e');
      print(st);
      return {'success': false, 'error': 'Verification failed'};
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Authenticate to access your wallet',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        print("Biometric authentication successful");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication successful!')),
        );
        // You can implement biometric-specific login flow here
      } else {
        print("Biometric authentication failed");
      }
    } on PlatformException catch (e) {
      print("Biometric auth error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric authentication failed: ${e.message}'),
        ),
      );
    }
  }

  // Replace the existing _authenticateWithFaceId method with this:
  Future<void> _authenticateWithFaceId() async {
    if (_deviceLockedDid == null || _deviceLockedDid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first to set up Face ID')),
      );
      return;
    }

    try {
      // First check if biometrics are available
      final canAuthenticate = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();

      if (!canAuthenticate || !isDeviceSupported) {
        _navigateToFaceDetectionDirectly();
        return;
      }

      // Get available biometrics
      final availableBiometrics = await auth.getAvailableBiometrics();

      if (!availableBiometrics.contains(BiometricType.face) &&
          !availableBiometrics.contains(BiometricType.fingerprint)) {
        _navigateToFaceDetectionDirectly();
        return;
      }

      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan your face to access your wallet',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        print("Biometric authentication successful");

        // Navigate to Face Detection Screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FaceDetectionScreen(idNumber: _deviceLockedDid!),
          ),
        );

        // Handle the result from face detection
        if (result != null && result['success'] == true) {
          final String? jwtToken = result['token'];

          if (jwtToken != null && jwtToken.isNotEmpty) {
            // Store the token in ApiService (same as password login)
            ApiService.setAuthToken(jwtToken);
            print('[FaceLogin]   JWT token stored in ApiService');

            //   Lock device to this DID (if not already locked)
            if (!_isDidLocked) {
              await StorageService.setRegisteredDid(_deviceLockedDid!);
              setState(() {
                _isDidLocked = true;
              });
              print(
                '[FaceLogin] 🔒 Device now locked to DID: $_deviceLockedDid',
              );
            }

            //   Fetch and store user data for offline features (QR scanning, etc.)
            await _fetchAndStoreUserData();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Face verification successful!')),
            );
            _navigateToMainScreen();
          } else {
            print(
              '[FaceLogin]   Empty or null token received from face verification',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Face verification failed: No valid token received',
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Face verification failed. Please try again.'),
            ),
          );
        }
      } else {
        print("Biometric authentication failed or cancelled");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication cancelled')),
        );
      }
    } on PlatformException catch (e) {
      print("Face ID auth error: $e");

      if (e.code == 'NotAvailable') {
        _navigateToFaceDetectionDirectly();
      } else if (e.code == 'PasscodeNotSet') {
        _showPasscodeNotSetDialog();
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        _showBiometricLockedOutDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication failed: ${e.message}'),
          ),
        );
      }
    } catch (e) {
      print("Unexpected error during biometric auth: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed. Please try again.'),
        ),
      );
    }
  }



  void _showPasscodeNotSetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Passcode Required'),
          ],
        ),
        content: const Text(
          'Please set up a device passcode to use biometric authentication.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBiometricLockedOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 8),
            Text('Biometric Locked'),
          ],
        ),
        content: const Text(
          'Too many failed attempts. Biometric authentication is temporarily locked. '
          'Please use your device passcode or try again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToFaceDetectionDirectly();
            },
            child: const Text('Use Face Detection'),
          ),
        ],
      ),
    );
  }

  void _navigateToFaceDetectionDirectly() async {
    if (_deviceLockedDid == null || _deviceLockedDid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to use face detection'),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceDetectionScreen(idNumber: _deviceLockedDid!),
      ),
    );

    if (result != null && result['success'] == true) {
      final String? jwtToken = result['token'];

      if (jwtToken != null && jwtToken.isNotEmpty) {
        ApiService.setAuthToken(jwtToken);
        print('[FaceLogin]   JWT token stored in ApiService');

        if (!_isDidLocked) {
          await StorageService.setRegisteredDid(_deviceLockedDid!);
          setState(() {
            _isDidLocked = true;
          });
        }

        //   Fetch and store user data for offline features (QR scanning, etc.)
        await _fetchAndStoreUserData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face verification successful!')),
        );
        _navigateToMainScreen();
      }
    }
  }

  // Parse private key from PEM
  ECPrivateKey _parsePrivateKeyFromPem(String pem) {
    final base64Key = pem
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll('\n', '')
        .trim();

    final keyBytes = base64Decode(base64Key);
    final d = _decodeBigInt(keyBytes);

    final params = ECCurve_prime256v1();
    return ECPrivateKey(d, params);
  }

  // Encode signature in DER format
  Uint8List _encodeDERSignature(ECSignature signature) {
    final rBytes = _encodeBigInt(signature.r);
    final sBytes = _encodeBigInt(signature.s);

    final rLength = rBytes.length;
    final sLength = sBytes.length;
    final totalLength = 2 + rLength + 2 + sLength;

    final result = Uint8List(2 + totalLength);
    result[0] = 0x30; // SEQUENCE
    result[1] = totalLength;
    result[2] = 0x02; // INTEGER
    result[3] = rLength;
    result.setRange(4, 4 + rLength, rBytes);
    result[4 + rLength] = 0x02; // INTEGER
    result[5 + rLength] = sLength;
    result.setRange(6 + rLength, 6 + rLength + sLength, sBytes);

    return result;
  }

  // Helper: Encode BigInt to bytes (32 bytes for P-256)
  Uint8List _encodeBigInt(BigInt number) {
    final bytes = number.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(
      List.generate(
        32,
        (i) => int.parse(bytes.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  // Helper: Decode bytes to BigInt
  BigInt _decodeBigInt(Uint8List bytes) {
    return BigInt.parse(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final textColor = AppTheme.getTextPrimary(isDarkMode);
        final secondaryTextColor = AppTheme.getTextSecondary(isDarkMode);
        
        return Scaffold(
          body: Container(
            constraints: const BoxConstraints.expand(),
            decoration: BoxDecoration(
              gradient: AppTheme.getGradient(isDarkMode),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Welcome Back',
                        style: AppTheme.getHeadingStyle(isDarkMode),
                      ),

                      const SizedBox(height: 12),

                      // Welcome message
                      Text(
                        "Sign in to access your digital wallet",
                        style: AppTheme.getSubtitleStyle(isDarkMode),
                      ),

                      const SizedBox(height: 40),

                      // DID field header with device lock indicator
                      Row(
                        children: [
                          Text(
                            '12 Digit Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor.withOpacity(0.9),
                            ),
                          ),
                          if (_isDidLocked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Registered',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Conditional DID field - locked or editable
                      if (_isDidLocked)
                        // Locked DID display
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: AppTheme.getCardDecoration(isDarkMode, borderRadius: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                color: secondaryTextColor,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _didController.text,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.lock_outline,
                                color: secondaryTextColor,
                                size: 20,
                              ),
                            ],
                          ),
                        )
                      else
                        // Editable DID field
                        TextFormField(
                          controller: _didController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          style: TextStyle(color: textColor, fontSize: 18),
                          decoration: AppTheme.getInputDecoration(
                            hintText: 'Enter your 12 Digit DID',
                            prefixIcon: Icons.badge_outlined,
                            isDarkMode: isDarkMode,
                          ).copyWith(counterText: ''),
                        ),

                      // Helper text for locked DID
                      if (_isDidLocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0, left: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.security, size: 14, color: Colors.green.withOpacity(0.8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This device is secured to this Digital ID',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Password field
                      Text(
                        'Password',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: textColor, fontSize: 18),
                        decoration: AppTheme.getInputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: Icons.lock_outline,
                          isDarkMode: isDarkMode,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: secondaryTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Forgot password and Clear lock
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Forgot password feature coming soon'),
                                ),
                              );
                            },
                            child: const Text('Forgot your Password'),
                          ),
                          if (_isDidLocked)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              onPressed: _clearDeviceLock,
                              child: const Text('Clear Device Lock'),
                            ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Sign in button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleEmailPasswordLogin,
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
                                    Icon(Icons.login_rounded, size: 22),
                                    SizedBox(width: 10),
                                    Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),

                      // Offline Authentication Button
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showOfflineAuthDialog,
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('Offline Authentication'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // Register button for new users
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => IDVerificationScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            'Don\'t have an account? Register',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      // Recover wallet
                      Center(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RecoverWalletScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            'Lost your phone? Recover Wallet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Biometric authentication
                      if (_supportState)
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Or login with',
                                style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.6)),
                              ),
                              const SizedBox(height: 16),

                              // Row with Face ID
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Face ID Button
                                  ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _authenticateWithFaceId,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      elevation: 0,
                                      minimumSize: const Size(80, 80),
                                    ),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.face,
                                          size: 32,
                                          color: AppTheme.primaryColor,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Face ID',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 20),
                                ],
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
      },
    );
  }
}
