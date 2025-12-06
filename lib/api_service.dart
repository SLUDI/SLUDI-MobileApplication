// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:encrypt/encrypt.dart' as encrypt;

import 'models/presentation_request.dart';
import 'models/verifiable_presentation.dart';
import 'models/credential.dart';
import 'models/api_response.dart';

class ApiService {
  static const String baseUrl = 'https://api.sludi.dpdns.org';
  static const Duration httpTimeout = Duration(seconds: 30);
  static const bool logFullPublicKey = true;
  static const bool logEncryptionDetails = true;
  static const String huggingFaceToken = 'your-huggingface-token';

  // Store JWT token after successful login
  static String? authToken;

  // Helper method to set token
  static void setAuthToken(String token) {
    authToken = token;
    print('[ApiService] JWT token set: ${token.substring(0, 30)}...');
  }

  // Helper method to clear token
  static void clearAuthToken() {
    authToken = null;
    print('[ApiService] JWT token cleared');
  }

  // Helper method to get headers with authorization
  static Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };

    if (authToken != null) {
      print('[AuthToken] : $authToken');
      headers['Authorization'] = 'Bearer $authToken';
      print('[ApiService] Adding Authorization header with token');
    } else {
      print('[ApiService] No auth token available for headers');
    }

    return headers;
  }

  // Add this method to your ApiService class
static Future<ApiResponse<String>> getProfilePhoto(String cid) async {
  try {
    final uri = Uri.parse('$baseUrl/api/wallet/photo/$cid');
    print('[getProfilePhoto] -> GET $uri');
    print('[getProfilePhoto] CID: $cid');

    final response = await http
        .get(uri, headers: _getHeaders())
        .timeout(httpTimeout);

    print('[getProfilePhoto] <-- ${response.statusCode}');
    print('[getProfilePhoto] Response body length: ${response.body.length}');

    final jsonResponse = _safeJsonDecode(response.body);

    if (response.statusCode == 200) {
      return ApiResponse<String>(
        success: true,
        message: jsonResponse['message'] ?? 'Profile photo retrieved successfully',
        data: jsonResponse['data'], // This is the base64 image string
      );
    } else {
      return ApiResponse<String>(
        success: false,
        message: jsonResponse['message'] ?? 'Failed to fetch profile photo',
        errorCode: jsonResponse['errorCode'],
      );
    }
  } on TimeoutException catch (e) {
    print('[getProfilePhoto] TimeoutException: $e');
    return ApiResponse<String>(
      success: false,
      message: 'Request timed out. Check your internet connection.',
    );
  } on SocketException catch (e) {
    print('[getProfilePhoto] SocketException: $e');
    return ApiResponse<String>(
      success: false,
      message: 'Network error. Please check your connection.',
    );
  } catch (e, st) {
    print('[getProfilePhoto] Unexpected error: $e');
    print(st);
    return ApiResponse<String>(
      success: false,
      message: 'Unexpected error: $e',
    );
  }
}
  

  static Future<Map<String, dynamic>> createWallet(
    String idNumber,
    String password,
  ) async {
    final uri = Uri.parse('$baseUrl/api/wallet/create');
    try {
      print('[createWallet] -> POST $uri');
      print('[createWallet] did=$idNumber');

      print('[createWallet] Generating key pair...');
      Map<String, String> keyPair;
      late String publicKeyPem;
      late String privateKeyPem;
      try {
        keyPair = await _generateKeyPair();
        publicKeyPem = keyPair['publicKey']!;
        privateKeyPem = keyPair['privateKey']!;
      } catch (e, st) {
        print('[createWallet] Key generation error: $e');
        print(st);
        print('[createWallet] Public key not generated');
        return _err(
          'createWallet',
          'Failed to generate keys. Please try again.',
        );
      }

      print('[createWallet] Public Key length: ${publicKeyPem.length}');
      print('[createWallet] Private Key length: ${privateKeyPem.length}');
      if (logFullPublicKey) {
        print('[createWallet] Public Key (PEM):\n$publicKeyPem');
      }

      // Only send did and publicKey to backend
      final body = jsonEncode({'did': idNumber, 'publicKey': publicKeyPem});
      print(
        '[createWallet] Request headers: {Content-Type: application/json, Accept: application/json}',
      );
      print('[createWallet] Request body: $body');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(httpTimeout);

      print('[createWallet] <-- ${response.statusCode}');
      print('[createWallet] Response headers: ${response.headers}');
      print('[createWallet] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = _safeJsonDecode(response.body);
        // Pass password for encryption
        await _storeKeysLocally(
          idNumber,
          publicKeyPem,
          privateKeyPem,
          password,
        );
        return {
          'success': true,
          'message': responseData['message'] ?? 'Registration successful!',
          'data': responseData,
        };
      }

      if (response.statusCode == 400) {
        final errorData = _safeJsonDecode(response.body);
        return _err(
          'createWallet',
          errorData['message'] ?? 'Invalid request data',
        );
      }
      if (response.statusCode == 409)
        return _err('createWallet', 'Wallet already exists for this ID number');
      if (response.statusCode == 500)
        return _err('createWallet', 'Server error. Please try again later.');

      final errorData = _safeJsonDecode(response.body);
      return _err(
        'createWallet',
        errorData['message'] ?? 'Registration failed. Please try again.',
      );
    } on TimeoutException catch (e) {
      print('[createWallet] TimeoutException: $e');
      return _err(
        'createWallet',
        'Request timed out. Check your internet/ngrok tunnel.',
      );
    } on HandshakeException catch (e) {
      print('[createWallet] HandshakeException (TLS): $e');
      return _err(
        'createWallet',
        'TLS handshake failed. If using emulator, check date/time & trust store; verify ngrok HTTPS cert.',
      );
    } on SocketException catch (e) {
      print('[createWallet] SocketException: $e');
      return _err(
        'createWallet',
        'Network error. Check connectivity, INTERNET permission, server URL, or ngrok tunnel.',
      );
    } on HttpException catch (e) {
      print('[createWallet] HttpException: $e');
      return _err('createWallet', 'HTTP error. ${e.message}');
    } on FormatException catch (e) {
      print('[createWallet] FormatException: $e');
      return _err(
        'createWallet',
        'Invalid/HTML response received (not JSON). Is the endpoint correct?',
      );
    } catch (e, st) {
      print('[createWallet] Unexpected Exception: $e');
      print(st);
      return _err('createWallet', 'Unexpected error: $e');
    }
  }

  static Future<Map<String, dynamic>> verifyDID(String idNumber) async {
    final uri = Uri.parse('$baseUrl/api/wallet/verify-did');
    try {
      print('[verifyDID] -> POST $uri');
      final body = jsonEncode({'did': idNumber});
      print('[verifyDID] Request body: $body');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(httpTimeout);

      print('[verifyDID] <-- ${response.statusCode}');
      print('[verifyDID] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = _safeJsonDecode(response.body);
        return {'success': true, 'data': responseData};
      }
      if (response.statusCode == 400)
        return _err('verifyDID', 'Invalid ID number format');
      if (response.statusCode == 404)
        return _err('verifyDID', 'ID number not found');
      if (response.statusCode == 500)
        return _err('verifyDID', 'Server error. Please try again later.');

      final errorData = _safeJsonDecode(response.body);
      return _err(
        'verifyDID',
        'Verification failed: ${errorData['message'] ?? 'Status: ${response.statusCode}'}',
      );
    } on TimeoutException catch (e) {
      print('[verifyDID] TimeoutException: $e');
      return _err(
        'verifyDID',
        'Request timed out. Check your internet/ngrok tunnel.',
      );
    } on SocketException catch (e) {
      print('[verifyDID] SocketException: $e');
      return _err(
        'verifyDID',
        'Network error. Ensure the server is running and reachable.',
      );
    } catch (e, st) {
      print('[verifyDID] Unexpected: $e');
      print(st);
      return _err('verifyDID', 'Unexpected error: $e');
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(
    String idNumber,
    String otp,
  ) async {
    final uri = Uri.parse('$baseUrl/api/wallet/verify-otp');
    try {
      print('[verifyOTP] -> POST $uri');
      final body = jsonEncode({'did': idNumber, 'otp': otp});
      print('[verifyOTP] Request body: $body');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(httpTimeout);

      print('[verifyOTP] <-- ${response.statusCode}');
      print('[verifyOTP] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = _safeJsonDecode(response.body);
        return {'success': true, 'data': responseData};
      }
      final errorData = _safeJsonDecode(response.body);
      return _err(
        'verifyOTP',
        'OTP verification failed: ${errorData['message'] ?? 'Invalid OTP'}',
        extra: errorData,
      );
    } on TimeoutException catch (e) {
      print('[verifyOTP] TimeoutException: $e');
      return _err(
        'verifyOTP',
        'Request timed out. Check your internet/ngrok tunnel.',
      );
    } on SocketException catch (e) {
      print('[verifyOTP] SocketException: $e');
      return _err(
        'verifyOTP',
        'Network error. Ensure the server is running and reachable.',
      );
    } catch (e, st) {
      print('[verifyOTP] Unexpected: $e');
      print(st);
      return _err('verifyOTP', 'Unexpected error: $e');
    }
  }

  static Future<Map<String, dynamic>> resendOTP(String idNumber) async {
    final uri = Uri.parse('$baseUrl/api/wallet/resend-otp');
    try {
      print('[resendOTP] -> POST $uri');
      final body = jsonEncode({'did': idNumber});
      print('[resendOTP] Request body: $body');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(httpTimeout);

      print('[resendOTP] <-- ${response.statusCode}');
      print('[resendOTP] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = _safeJsonDecode(response.body);
        return {'success': true, 'data': responseData};
      }
      final errorData = _safeJsonDecode(response.body);
      return _err(
        'resendOTP',
        'Failed to resend OTP: ${errorData['message'] ?? 'Please try again.'}',
      );
    } on TimeoutException catch (e) {
      print('[resendOTP] TimeoutException: $e');
      return _err(
        'resendOTP',
        'Request timed out. Check your internet/ngrok tunnel.',
      );
    } on SocketException catch (e) {
      print('[resendOTP] SocketException: $e');
      return _err('resendOTP', 'Network error. Please check your connection.');
    } catch (e, st) {
      print('[resendOTP] Unexpected: $e');
      print(st);
      return _err('resendOTP', 'Unexpected error: $e');
    }
  }

  // Challenge-Response APIs
  static Future<Map<String, dynamic>> generateChallenge(String did) async {
    final uri = Uri.parse('$baseUrl/api/wallet/generate-challenge');
    try {
      print('[generateChallenge] -> POST $uri');
      final body = jsonEncode({'did': did});

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(httpTimeout);

      print('[generateChallenge] <-- ${response.statusCode}');
      print('[generateChallenge] Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = _safeJsonDecode(response.body);
        if (responseData['success'] == true) {
          // FIX: Extract nonce from response
          final nonce = responseData['data']?['nonce'] ?? responseData['nonce'];
          if (nonce != null) {
            return {
              'success': true,
              'data': responseData,
              'challenge': nonce.toString(),
            };
          }
        }
      }

      final errorData = _safeJsonDecode(response.body);
      return _err(
        'generateChallenge',
        errorData['message'] ?? 'Failed to generate challenge',
      );
    } on TimeoutException catch (e) {
      print('[generateChallenge] Timeout: $e');
      return _err('generateChallenge', 'Request timeout');
    } catch (e, st) {
      print('[generateChallenge] Error: $e');
      print(st);
      return _err('generateChallenge', 'Failed to generate challenge');
    }
  }

  /// Fetch presentation request details from scanned QR code URL
  static Future<ApiResponse<PresentationRequestDto>> getPresentationRequest(
    String sessionId,
  ) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/wallet/driving-license/request/$sessionId',
      );
      print('[getPresentationRequest] -> GET $uri');

      final response = await http
          .get(uri, headers: _getHeaders())
          .timeout(httpTimeout);

      print('[getPresentationRequest] <-- ${response.statusCode}');
      print('[getPresentationRequest] Response body: ${response.body}');

      final jsonResponse = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.fromJson(
          jsonResponse,
          (data) => PresentationRequestDto.fromJson(data),
        );
      } else {
        return ApiResponse<PresentationRequestDto>(
          success: false,
          message: jsonResponse['message'] ?? 'Failed to fetch request',
          errorCode: jsonResponse['errorCode'],
        );
      }
    } on TimeoutException catch (e) {
      print('[getPresentationRequest] TimeoutException: $e');
      return ApiResponse<PresentationRequestDto>(
        success: false,
        message: 'Request timed out. Check your internet connection.',
      );
    } on SocketException catch (e) {
      print('[getPresentationRequest] SocketException: $e');
      return ApiResponse<PresentationRequestDto>(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    } catch (e, st) {
      print('[getPresentationRequest] Unexpected error: $e');
      print(st);
      return ApiResponse<PresentationRequestDto>(
        success: false,
        message: 'Unexpected error: $e',
      );
    }
  }

  //Submit verifiable presentation with citizen data
  static Future<ApiResponse<Map<String, dynamic>>> submitVerifiablePresentation(
    String sessionId,
    VerifiablePresentationDto vpDto,
  ) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/wallet/driving-license/presentation/$sessionId',
      );
      print('[submitVerifiablePresentation] -> POST $uri');

      print('[submitVerifiablePresentation] Request body: ${vpDto.toJson()}');

      final body = jsonEncode(vpDto.toJson());
      print(
        '[submitVerifiablePresentation] Request body length: ${body.length} chars',
      );

      final response = await http
          .post(uri, headers: _getHeaders(), body: body)
          .timeout(httpTimeout);

      print('[submitVerifiablePresentation] <-- ${response.statusCode}');
      print('[submitVerifiablePresentation] Response body: ${response.body}');

      final jsonResponse = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.fromJson(
          jsonResponse,
          (data) => data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: jsonResponse['message'] ?? 'Failed to submit presentation',
          errorCode: jsonResponse['errorCode'],
        );
      }
    } on TimeoutException catch (e) {
      print('[submitVerifiablePresentation] TimeoutException: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Request timed out. Check your internet connection.',
      );
    } on SocketException catch (e) {
      print('[submitVerifiablePresentation] SocketException: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    } catch (e, st) {
      print('[submitVerifiablePresentation] Unexpected error: $e');
      print(st);
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Unexpected error: $e',
      );
    }
  }

  // Generate digital signature for the presentation
  static Future<ProofDto> generatePresentationProof(
    String holder,
    String password,
    String sessionId,
    Map<String, dynamic> attributes,
  ) async {
    try {
      print('[generatePresentationProof] 🔐 Generating presentation proof...');
      print('[generatePresentationProof]   Holder: $holder');
      print('[generatePresentationProof]   Session ID: $sessionId');
      print(
        '[generatePresentationProof]   Attributes count: ${attributes.length}',
      );

      // Get current timestamp
      final now = DateTime.now().toUtc().toIso8601String();

      // Retrieve stored keys
      final did = holder.split(':').last;
      final keys = await getStoredKeys(did, password);
      if (keys == null) {
        throw Exception('Could not retrieve keys for holder: $holder');
      }

      final String privateKeyPem = keys['privateKey']!;

      // Generate signature using the stored private key and canonical VP format
      final signature = await _generateSignature(
        holder,
        sessionId,
        attributes,
        privateKeyPem,
      );

      final proof = ProofDto(
        type: 'Ed25519Signature2020',
        created: now,
        verificationMethod: '$holder#keys-1',
        proofPurpose: 'authentication',
        proofValue: signature,
      );

      print('[generatePresentationProof] ✅ Proof generated successfully');
      return proof;
    } catch (e, st) {
      print('[generatePresentationProof] ❌ Error generating proof: $e');
      print(st);
      rethrow;
    }
  }

  /// Generate signature using canonical VP format matching backend
  static Future<String> _generateSignature(
    String holder,
    String sessionId,
    Map<String, dynamic> attributes,
    String privateKeyPem,
  ) async {
    try {
      print('[generateSignature] 🔐 Starting signature generation...');

      // Build canonical VP string matching backend format
      final canonicalVP = _buildCanonicalVP(sessionId, holder, attributes);
      print('[generateSignature] Canonical VP: $canonicalVP');
      print(
        '[generateSignature] Canonical VP length: ${canonicalVP.length} chars',
      );

      // Parse private key from PEM
      final privateKey = _parsePrivateKeyFromPem(privateKeyPem);
      print('[generateSignature] ✅ Private key parsed successfully');

      // Hash the canonical VP message (SHA-256)
      final messageBytes = utf8.encode(canonicalVP);
      final digest = SHA256Digest();
      final hash = digest.process(Uint8List.fromList(messageBytes));
      print('[generateSignature] ✅ Message hashed with SHA-256');

      // Create and properly seed the secure random
      final secureRandom = FortunaRandom();
      final seedSource = Uint8List.fromList(
        List<int>.generate(
          32,
          (i) => (DateTime.now().microsecondsSinceEpoch + i) % 256,
        ),
      );
      secureRandom.seed(KeyParameter(seedSource));
      print('[generateSignature] ✅ Secure random seeded');

      // Sign using ECDSA
      final signer = ECDSASigner(SHA256Digest());
      final params = ParametersWithRandom(
        PrivateKeyParameter<ECPrivateKey>(privateKey),
        secureRandom,
      );

      signer.init(true, params);
      final signature = signer.generateSignature(hash) as ECSignature;
      print('[generateSignature] ✅ Signature generated with ECDSA');

      // Encode signature as DER format
      final signatureBytes = _encodeDERSignature(signature);
      final base64Signature = base64Encode(signatureBytes);

      print(
        '[generateSignature] ✅ Signature encoded (Base64): ${base64Signature.length} chars',
      );
      return base64Signature;
    } catch (e, st) {
      print('[generateSignature] ❌ Error in signature generation: $e');
      print(st);
      rethrow;
    }
  }

  /// Build canonical VP string matching backend format
  /// Format: "&sessionId=...&holder=...&credentialAttributes=..."
  static String _buildCanonicalVP(
    String sessionId,
    String holder,
    Map<String, dynamic> attributes,
  ) {
    final canonical = StringBuffer();

    canonical.write('&sessionId=');
    canonical.write(sessionId); // <-- NO encoding

    canonical.write('&holder=');
    canonical.write(holder); // <-- NO encoding

    canonical.write('&credentialAttributes=');

    // sort JSON keys exactly same as backend (good)
    final sortedKeys = attributes.keys.toList()..sort();
    final canonicalAttributes = {for (var k in sortedKeys) k: attributes[k]};

    final attributesJson = jsonEncode(canonicalAttributes);

    canonical.write(attributesJson); // <-- NO encoding

    final result = canonical.toString();
    print('[buildCanonicalVP] Built canonical VP: $result');
    return result;
  }

  // Parse private key from PEM
  static ECPrivateKey _parsePrivateKeyFromPem(String pem) {
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

  static BigInt _decodeBigInt(Uint8List bytes) {
    return BigInt.parse(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );
  }

  // Encode signature in DER format
  static Uint8List _encodeDERSignature(ECSignature signature) {
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

  // ----------------------------- WALLET STATUS ----------------------------
  static Future<Map<String, dynamic>> getWalletStatus() async {
    final uri = Uri.parse('$baseUrl/api/wallet/retrieve');

    try {
      print('[getWalletStatus] -> GET $uri');

      // Check if we have a token
      if (authToken == null) {
        print('[getWalletStatus] ❌ No JWT token available');
        return _err(
          'getWalletStatus',
          'Not authenticated. Please login first.',
        );
      }

      print(
        '[getWalletStatus] Using JWT token: Bearer ${authToken!.substring(0, 30)}...',
      );

      final response = await http
          .get(uri, headers: _getHeaders())
          .timeout(httpTimeout);

      print('[getWalletStatus] <-- ${response.statusCode}');
      print(
        '[getWalletStatus] Response body: ${_safeJsonDecode(response.body)}',
      );

      if (response.statusCode == 200) {
        final responseData = _safeJsonDecode(response.body);

        if (responseData['success'] == true) {
          return {
            'success': true,
            'message':
                responseData['message'] ??
                'Wallet status retrieved successfully',
            'walletId': responseData['data']?['id'],
            'did': responseData['data']?['did'],
            'verifiableCredentials':
                responseData['data']?['walletVerifiableCredentials'] ?? [],
            'createdAt': responseData['data']?['createdAt'],
            'updatedAt': responseData['data']?['updatedAt'],
            'data': responseData['data'],
          };
        } else {
          return _err(
            'getWalletStatus',
            responseData['message'] ?? 'Failed to get wallet status',
          );
        }
      }

      // Handle unauthorized (token expired)
      if (response.statusCode == 401) {
        authToken = null; // Clear expired token
        return _err('getWalletStatus', 'Session expired. Please login again.');
      }

      final errorData = _safeJsonDecode(response.body);
      return _err(
        'getWalletStatus',
        errorData['message'] ??
            'Failed to fetch wallet status. Status: ${response.statusCode}',
      );
    } on TimeoutException catch (e) {
      print('[getWalletStatus] TimeoutException: $e');
      return _err(
        'getWalletStatus',
        'Request timed out. Check your internet connection.',
      );
    } on SocketException catch (e) {
      print('[getWalletStatus] SocketException: $e');
      return _err(
        'getWalletStatus',
        'Network error. Please check your connection.',
      );
    } catch (e, st) {
      print('[getWalletStatus] Unexpected error: $e');
      print(st);
      return _err('getWalletStatus', 'Unexpected error: $e');
    }
  }

  // ----------------------------- ENCRYPTED STORAGE HELPERS ----------------------------
  static Future<void> _storeKeysLocally(
    String idNumber,
    String publicKey,
    String privateKey,
    String password,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      print('[storeKeys] 🗃️ Starting local storage for ID: $idNumber');

      // Store public key in plain text (it's public anyway)
      await prefs.setString('${idNumber}_publicKey', publicKey);
      print('[storeKeys] ✅ Public key stored (plain text)');

      // ENCRYPT the private key with user's password
      print('[storeKeys] 🔐 Encrypting private key...');
      print(
        '[storeKeys]   Original private key length: ${privateKey.length} chars',
      );

      final encryptedPrivateKey = _encryptWithPassword(privateKey, password);

      print('[storeKeys] ✅ Private key encrypted successfully');
      print(
        '[storeKeys]   Encrypted private key length: ${encryptedPrivateKey.length} chars',
      );
      if (logEncryptionDetails) {
        print('[storeKeys]   Encrypted data format: IV:encrypted_data');
        final parts = encryptedPrivateKey.split(':');
        if (parts.length == 2) {
          print('[storeKeys]   IV length: ${parts[0].length} chars (base64)');
          print(
            '[storeKeys]   Encrypted data length: ${parts[1].length} chars (base64)',
          );
        }
      }

      await prefs.setString('${idNumber}_privateKey', encryptedPrivateKey);
      await prefs.setString('currentWalletId', idNumber);

      print('[storeKeys] 💾 All keys stored in SharedPreferences');
      print('[storeKeys] 📊 Storage Summary:');
      print(
        '[storeKeys]   - Public Key: ${publicKey.length} chars (plain text)',
      );
      print(
        '[storeKeys]   - Private Key: ${encryptedPrivateKey.length} chars (encrypted)',
      );
      print('[storeKeys]   - Current Wallet ID: $idNumber');

      // Verify storage
      final storedPublicKey = prefs.getString('${idNumber}_publicKey');
      final storedPrivateKey = prefs.getString('${idNumber}_privateKey');

      if (storedPublicKey != null && storedPrivateKey != null) {
        print('[storeKeys] ✅ Verification: Keys found in SharedPreferences');
        print(
          '[storeKeys]   Public key present: ${storedPublicKey.isNotEmpty}',
        );
        print(
          '[storeKeys]   Private key present: ${storedPrivateKey.isNotEmpty}',
        );
        print(
          '[storeKeys]   Private key is encrypted: ${storedPrivateKey.contains(':')}',
        );
      } else {
        print('[storeKeys] ❌ WARNING: Keys may not have been stored properly');
      }
    } catch (e, st) {
      print('[storeKeys] ❌ Storage Error: $e');
      print(st);
      throw Exception('Failed to store keys locally');
    }
  }

  // ----------------------------- ENCRYPTION/DECRYPTION METHODS ----------------------------
  static String _encryptWithPassword(String data, String password) {
    try {
      print('[encryptWithPassword] 🔑 Starting encryption process...');

      // Derive encryption key from password
      final key = _deriveEncryptionKey(password);
      print('[encryptWithPassword] ✅ Encryption key derived from password');

      // Generate random IV
      final iv = encrypt.IV.fromSecureRandom(16);
      print(
        '[encryptWithPassword] ✅ IV generated: ${iv.base64.substring(0, 16)}...',
      );

      // Create encryptor
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      print('[encryptWithPassword] 🔄 Encrypting data...');

      // Encrypt the private key
      final encrypted = encrypter.encrypt(data, iv: iv);
      print('[encryptWithPassword] ✅ Data encrypted successfully');

      // Store IV + encrypted data together (IV:encrypted_data)
      final result = '${iv.base64}:${encrypted.base64}';

      print('[encryptWithPassword] 📦 Final encrypted package created');
      print('[encryptWithPassword]   Format: IV:encrypted_data');
      print('[encryptWithPassword]   Total length: ${result.length} chars');

      return result;
    } catch (e, st) {
      print('[encryptWithPassword] ❌ Encryption failed: $e');
      print(st);
      rethrow;
    }
  }

  static String? _decryptWithPassword(String encryptedData, String password) {
    try {
      print('[decryptWithPassword] 🔓 Starting decryption process...');

      // Split IV and encrypted data
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        print('[decryptWithPassword] ❌ Invalid encrypted data format');
        return null;
      }

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      print('[decryptWithPassword] ✅ Extracted IV and encrypted data');
      print('[decryptWithPassword]   IV: ${parts[0].substring(0, 16)}...');
      print(
        '[decryptWithPassword]   Encrypted data length: ${parts[1].length} chars',
      );

      // Derive key from password
      final key = _deriveEncryptionKey(password);
      print('[decryptWithPassword] ✅ Encryption key derived from password');

      // Create decryptor
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      print('[decryptWithPassword] 🔄 Decrypting data...');

      // Decrypt
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      print('[decryptWithPassword] ✅ Data decrypted successfully');
      print(
        '[decryptWithPassword]   Decrypted length: ${decrypted.length} chars',
      );

      return decrypted;
    } catch (e, st) {
      print('[decryptWithPassword] ❌ Decryption failed: $e');
      print(st);
      return null;
    }
  }

  static encrypt.Key _deriveEncryptionKey(String password) {
    try {
      print(
        '[deriveEncryptionKey] 🔧 Deriving encryption key from password...',
      );
      print(
        '[deriveEncryptionKey]   Password length: ${password.length} chars',
      );

      // Simple key derivation - pad/truncate to 32 bytes for AES-256
      var keyMaterial = password;
      if (keyMaterial.length < 32) {
        // Pad with repeating pattern
        keyMaterial = keyMaterial.padRight(32, '0');
      } else if (keyMaterial.length > 32) {
        // Truncate to 32 chars
        keyMaterial = keyMaterial.substring(0, 32);
      }

      final key = encrypt.Key.fromUtf8(keyMaterial);
      print('[deriveEncryptionKey] ✅ Encryption key derived');
      print('[deriveEncryptionKey]   Key length: 32 bytes (AES-256)');

      return key;
    } catch (e, st) {
      print('[deriveEncryptionKey] ❌ Key derivation failed: $e');
      print(st);
      rethrow;
    }
  }

  // ----------------------------- MODIFIED RETRIEVAL METHODS ----------------------------
  static Future<Map<String, String>?> getStoredKeys(
    String idNumber,
    String password,
  ) async {
    try {
      print('[getStoredKeys] 🔍 Retrieving stored keys for ID: $idNumber');

      final prefs = await SharedPreferences.getInstance();
      final publicKey = prefs.getString('${idNumber}_publicKey');
      final encryptedPrivateKey = prefs.getString('${idNumber}_privateKey');

      if (publicKey != null && encryptedPrivateKey != null) {
        print('[getStoredKeys] ✅ Found stored keys');
        print('[getStoredKeys]   Public key present: ${publicKey.isNotEmpty}');
        print(
          '[getStoredKeys]   Private key present (encrypted): ${encryptedPrivateKey.isNotEmpty}',
        );

        // Decrypt the private key
        print('[getStoredKeys] 🔓 Decrypting private key...');
        final privateKey = _decryptWithPassword(encryptedPrivateKey, password);

        if (privateKey != null) {
          print('[getStoredKeys] ✅ Private key decrypted successfully');
          if (logFullPublicKey) {
            print('[getStoredKeys] 🔑 Public Key (PEM):\n$publicKey');
          }
          return {'publicKey': publicKey, 'privateKey': privateKey};
        } else {
          print(
            '[getStoredKeys] ❌ Failed to decrypt private key - wrong password?',
          );
          return null;
        }
      }

      print('[getStoredKeys] ❌ No keys found for ID: $idNumber');
      return null;
    } catch (e, st) {
      print('[getStoredKeys] ❌ Error: $e');
      print(st);
      return null;
    }
  }

  static Future<String?> getCurrentWalletId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('currentWalletId');
    } catch (e, st) {
      print('[getCurrentWalletId] Error: $e');
      print(st);
      return null;
    }
  }

  // ----------------------------- VERIFICATION METHOD ----------------------------
  static Future<bool> verifyStoredKeys(String idNumber, String password) async {
    try {
      print('[verifyStoredKeys] 🔍 Verifying stored keys for ID: $idNumber');

      final keys = await getStoredKeys(idNumber, password);
      if (keys != null) {
        print('[verifyStoredKeys] ✅ Keys verified and accessible');
        return true;
      } else {
        print('[verifyStoredKeys] ❌ Keys verification failed');
        return false;
      }
    } catch (e, st) {
      print('[verifyStoredKeys] ❌ Verification error: $e');
      print(st);
      return false;
    }
  }

  static Future<void> clearStoredKeys(String idNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check what we're clearing
      final publicKey = prefs.getString('${idNumber}_publicKey');
      final privateKey = prefs.getString('${idNumber}_privateKey');

      print('[clearStoredKeys] 🗑️ Clearing stored keys for ID: $idNumber');
      print('[clearStoredKeys]   Public key present: ${publicKey != null}');
      print('[clearStoredKeys]   Private key present: ${privateKey != null}');
      if (privateKey != null) {
        print(
          '[clearStoredKeys]   Private key is encrypted: ${privateKey.contains(':')}',
        );
      }

      await prefs.remove('${idNumber}_publicKey');
      await prefs.remove('${idNumber}_privateKey');
      await prefs.remove('currentWalletId');

      print('[clearStoredKeys] ✅ Keys cleared for ID=$idNumber');
    } catch (e, st) {
      print('[clearStoredKeys] ❌ Error: $e');
      print(st);
    }
  }

  // ----------------------------- CRYPTO HELPERS -----------------------------

  static Future<Map<String, String>> _generateKeyPair() async {
    final keyGen = ECKeyGenerator();
    final secureRandom = FortunaRandom();

    // Seed the random number generator
    final seedSource = Uint8List.fromList(
      List<int>.generate(
        32,
        (i) => DateTime.now().millisecondsSinceEpoch % 256,
      ),
    );
    secureRandom.seed(KeyParameter(seedSource));

    // Use secp256r1 (P-256) curve - compatible with Hyperledger Fabric
    final params = ECKeyGeneratorParameters(ECCurve_prime256v1());

    final paramsWithRandom = ParametersWithRandom(params, secureRandom);
    keyGen.init(paramsWithRandom);

    final keyPair = keyGen.generateKeyPair();
    final publicKey = keyPair.publicKey as ECPublicKey;
    final privateKey = keyPair.privateKey as ECPrivateKey;

    // Encode keys
    final publicKeyPem = _encodePublicKeyToPem(publicKey);
    final privateKeyPem = _encodePrivateKeyToPem(privateKey);

    return {'publicKey': publicKeyPem, 'privateKey': privateKeyPem};
  }

  // Encode public key to PEM format
  static String _encodePublicKeyToPem(ECPublicKey publicKey) {
    final q = publicKey.Q!;
    final x = q.x!.toBigInteger()!;
    final y = q.y!.toBigInteger()!;

    // Uncompressed point format: 0x04 || X || Y
    final xBytes = _encodeBigInt(x);
    final yBytes = _encodeBigInt(y);

    final publicKeyBytes = Uint8List(1 + xBytes.length + yBytes.length);
    publicKeyBytes[0] = 0x04; // Uncompressed
    publicKeyBytes.setRange(1, 1 + xBytes.length, xBytes);
    publicKeyBytes.setRange(1 + xBytes.length, publicKeyBytes.length, yBytes);

    final base64Key = base64Encode(publicKeyBytes);
    return '-----BEGIN PUBLIC KEY-----\n$base64Key\n-----END PUBLIC KEY-----';
  }

  // Encode private key to PEM format
  static String _encodePrivateKeyToPem(ECPrivateKey privateKey) {
    final dBytes = _encodeBigInt(privateKey.d!);
    final base64Key = base64Encode(dBytes);
    return '-----BEGIN PRIVATE KEY-----\n$base64Key\n-----END PRIVATE KEY-----';
  }

  // Encode BigInt to bytes (32 bytes for P-256)
  static Uint8List _encodeBigInt(BigInt number) {
    final bytes = number.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(
      List.generate(
        32,
        (i) => int.parse(bytes.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  // ----------------------------- UTILITIES ---------------------------------
  static Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'raw': decoded};
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic> _err(
    String where,
    String message, {
    Map<String, dynamic>? extra,
  }) {
    final map = <String, dynamic>{
      'success': false,
      'where': where,
      'error': message,
    };
    if (extra != null) map['data'] = extra;
    return map;
  }

  static Future<Map<String, dynamic>> verifyVideoWithEmbedding({
    required File videoFile,
    required String idNumber,
  }) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/wallet/verify-identity'),
      );

      // Add headers with authorization
      request.headers.addAll(_getHeaders());

      // Add video file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          videoFile.path,
          filename:
              'face_verification_${DateTime.now().millisecondsSinceEpoch}.mp4',
        ),
      );

      // Add form data - use citizenId instead of did
      request.fields['citizenId'] = "did:sludi:$idNumber";

      print(
        '[verifyVideoWithEmbedding] Sending verification request for citizenId: $idNumber',
      );
      print('[verifyVideoWithEmbedding] Video file: ${videoFile.path}');

      // Send request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print(
        '[verifyVideoWithEmbedding] Response status: ${response.statusCode}',
      );
      print('[verifyVideoWithEmbedding] Response data: $responseData');

      if (response.statusCode == 200) {
        final result = jsonDecode(responseData);

        if (result['success'] == true) {
          final data = result['data'] ?? {};
          final verification = data['verification'] ?? {};

          // Extract values from the verification object
          final isMatch = verification['match'] ?? false;
          final isDeepfakeDetected = verification['deepfakeDetected'] ?? false;
          final similarity =
              verification['similarity'] ?? verification['confidence'] ?? 0.0;
          final message =
              verification['message'] ??
              data['message'] ??
              result['message'] ??
              'Verification completed';

          // Extract tokens and status
          final accessToken = data['accessToken'];
          final refreshToken = data['refreshToken'];
          final status = data['status'] ?? 'UNKNOWN';

          print(
            '[verifyVideoWithEmbedding] ✅ Verification completed - Match: $isMatch, Deepfake: $isDeepfakeDetected',
          );
          print(
            '[verifyVideoWithEmbedding] Similarity: ${(similarity * 100).toStringAsFixed(2)}%',
          );
          print('[verifyVideoWithEmbedding] Status: $status');

          // Check if authentication was successful
          final bool isVerified = isMatch && !isDeepfakeDetected;

          if (isVerified && accessToken != null) {
            print(
              '[verifyVideoWithEmbedding] ✅ Access token received: ${accessToken.substring(0, 30)}...',
            );
            if (refreshToken != null) {
              print(
                '[verifyVideoWithEmbedding] ✅ Refresh token received: ${refreshToken.substring(0, 30)}...',
              );
            }
          }

          return {
            'success': true,
            'is_verified': isVerified,
            'is_match': isMatch,
            'deepfake_detected': isDeepfakeDetected,
            'similarity': similarity,
            'message': message,
            'status': status,
            'token': accessToken, // Return access token for login
            'refresh_token': refreshToken,
            'verification_data': verification,
          };
        } else {
          return {
            'success': false,
            'error': result['message'] ?? 'Verification failed',
            'is_verified': false,
            'similarity': 0.0,
          };
        }
      } else {
        final errorData = jsonDecode(responseData);
        return {
          'success': false,
          'error':
              errorData['message'] ??
              'Verification failed with status: ${response.statusCode}',
          'is_verified': false,
          'similarity': 0.0,
        };
      }
    } catch (e) {
      print('[verifyVideoWithEmbedding] ❌ Error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
        'is_verified': false,
        'similarity': 0.0,
      };
    }
  }
}
