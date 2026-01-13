// lib/services/offline_auth_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineAuthService {
  static const String _userDataKey = 'user_data';
  
  // Generate QR code data for age verification using LOCAL data
  static Future<Map<String, dynamic>> generateVerificationQR({
    required String idNumber,
    required String verificationType,
    required Map<String, dynamic> userData,
  }) async {
    try {
      print('[OfflineAuthService] Generating QR from LOCAL data for: $idNumber');
      print('[OfflineAuthService] Full user data structure: $userData');
      
      // EXTRACT AGE AND DOB FROM CREDENTIAL SUBJECT
      final extractedData = extractUserDataFromCredentials(userData);
      final age = extractedData['age'];
      final dateOfBirth = extractedData['dateOfBirth'];
      final fullName = extractedData['fullName'];
      
      print('[OfflineAuthService] Extracted - Age: $age, DOB: $dateOfBirth, Name: $fullName');
      
      // Validate that we have the required data
      if (age == null) {
        return {
          'success': false,
          'error': 'Age information not found in credentials. Available fields: ${extractedData.keys}',
        };
      }
      
      // Convert age to integer
      int ageValue;
      if (age is String) {
        ageValue = int.tryParse(age) ?? 0;
      } else if (age is int) {
        ageValue = age;
      } else {
        ageValue = 0;
      }
      
      final isAbove18 = ageValue >= 18;
      
      print('[OfflineAuthService] Final - Age: $ageValue, Above 18: $isAbove18');
      
      // Create QR content using extracted data
      String qrContent;
      
      switch (verificationType) {
        case 'age_verification':
          qrContent = _createAgeVerificationQR(
            idNumber: idNumber,
            fullName: fullName,
            age: ageValue,
            dateOfBirth: dateOfBirth,
            isAbove18: isAbove18,
          );
          break;
        
        default:
          qrContent = 'Verification Data';
      }
      
      return {
        'success': true,
        'qrData': qrContent,
        'qrString': qrContent,
        'calculatedAge': ageValue,
        'isAbove18': isAbove18,
        'dateOfBirth': dateOfBirth,
        'fullName': fullName,
        'source': 'local_storage',
      };
    } catch (e) {
      print('[OfflineAuthService] Error generating QR code: $e');
      return {
        'success': false,
        'error': 'Failed to generate QR code: $e',
      };
    }
  }

  // Generate QR code for data sharing
  static Future<Map<String, dynamic>> generateDataSharingQR({
    required String idNumber,
    required Map<String, bool> selectedFields,
    required Map<String, dynamic> userData,
  }) async {
    try {
      print('[OfflineAuthService] Generating data sharing QR for: $idNumber');
      
      // Extract all available data
      final extractedData = extractAllUserData(userData);
      final sharedData = <String, String>{};
      
      // Collect selected fields
      for (final field in selectedFields.entries) {
        if (field.value) {
          final value = _getFieldValue(extractedData, field.key);
          if (value != null && value.isNotEmpty) {
            final displayName = _getFieldDisplayName(field.key);
            sharedData[displayName] = value;
          }
        }
      }
      
      if (sharedData.isEmpty) {
        return {
          'success': false,
          'error': 'No valid data selected for sharing',
        };
      }
      
      // Create structured QR content
      final qrContent = _createStructuredQRContent(
        idNumber: idNumber,
        sharedData: sharedData,
        timestamp: DateTime.now(),
      );
      
      // Also create a simple text version for basic QR scanners
      final simpleQRContent = _createSimpleQRContent(sharedData);
      
      return {
        'success': true,
        'qrData': qrContent,
        'qrString': simpleQRContent,
        'structuredData': qrContent,
        'sharedData': sharedData,
        'fieldsCount': sharedData.length,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('[OfflineAuthService] Error generating data sharing QR: $e');
      return {
        'success': false,
        'error': 'Failed to generate QR code: $e',
      };
    }
  }
  
  // Create structured JSON content for advanced apps
  static String _createStructuredQRContent({
    required String idNumber,
    required Map<String, String> sharedData,
    required DateTime timestamp,
  }) {
    final structuredData = {
      'type': 'identity_sharing',
      'version': '1.0',
      'timestamp': timestamp.toIso8601String(),
      'digitalId': idNumber,
      'data': sharedData,
      'metadata': {
        'source': 'Digital ID Wallet',
        'verification': 'local_storage',
        'format': 'json_v1',
      },
    };
    
    return jsonEncode(structuredData);
  }
  
  // Create simple text content for basic QR scanners
  static String _createSimpleQRContent(Map<String, String> sharedData) {
    final buffer = StringBuffer();
    buffer.writeln('🏛️ DIGITAL IDENTITY CARD');
    buffer.writeln('══════════════════════════');
    buffer.writeln('');
    
    for (final entry in sharedData.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    
    buffer.writeln('');
    buffer.writeln('══════════════════════════');
    buffer.writeln('Generated: ${DateTime.now().toLocal()}');
    buffer.writeln('Source: SLUDI Digital Wallet');
    
    return buffer.toString();
  }
  
  // Parse shared data from QR content
  static Map<String, dynamic> parseSharedData(String qrContent) {
    try {
      // Try to parse as JSON first (structured data)
      try {
        final jsonData = jsonDecode(qrContent);
        if (jsonData is Map<String, dynamic>) {
          return {
            'type': 'structured',
            'data': jsonData['data'] ?? {},
            'digitalId': jsonData['digitalId'],
            'timestamp': jsonData['timestamp'],
            'source': jsonData['metadata']?['source'],
          };
        }
      } catch (e) {
        // Not JSON, try to parse as simple text
        return _parseSimpleQRContent(qrContent);
      }
    } catch (e) {
      print('[OfflineAuthService] Error parsing QR content: $e');
    }
    
    return {'type': 'unknown', 'data': {}};
  }
  
  static Map<String, dynamic> _parseSimpleQRContent(String content) {
    final data = <String, String>{};
    final lines = content.split('\n');
    
    for (final line in lines) {
      if (line.contains(':') && !line.startsWith('═') && !line.startsWith('🏛️')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            data[key] = value;
          }
        }
      }
    }
    
    return {'type': 'simple', 'data': data};
  }
  
  // EXTRACT DATA FROM CREDENTIAL SUBJECT - FIXED VERSION
  static Map<String, dynamic> extractUserDataFromCredentials(Map<String, dynamic> userData) {
    try {
      print('[OfflineAuthService] 🔍 Extracting data from credentials...');
      
      // Check ALL possible credential locations
      final credentialLocations = [
        'verifiableCredentials',
        'walletVerifiableCredentials',
        'credentials',
        'verifiable_credentials'
      ];
      
      for (final location in credentialLocations) {
        if (userData[location] is List && (userData[location] as List).isNotEmpty) {
          print('[OfflineAuthService]   Found credentials in: $location');
          final credentials = userData[location] as List;
          print('[OfflineAuthService] Number of credentials: ${credentials.length}');
          
          // Get the first credential
          final firstCredential = credentials[0];
          print('[OfflineAuthService] First credential type: ${firstCredential.runtimeType}');
          print('[OfflineAuthService] First credential keys: ${firstCredential is Map ? firstCredential.keys.toList() : 'NOT A MAP'}');
          
          if (firstCredential is Map) {
            // Check for credentialSubject
            if (firstCredential['credentialSubject'] is Map) {
              final credentialSubject = firstCredential['credentialSubject'] as Map<String, dynamic>;
              print('[OfflineAuthService]   Found credentialSubject');
              print('[OfflineAuthService] CredentialSubject keys: ${credentialSubject.keys.toList()}');
              
              // Extract the data we need
              final result = {
                'id': credentialSubject['id'],
                'age': credentialSubject['age'],
                'dateOfBirth': credentialSubject['dateOfBirth'],
                'fullName': credentialSubject['fullName'],
                'nic': credentialSubject['nic'],
                'gender': credentialSubject['gender'],
                'nationality': credentialSubject['nationality'],
                'citizenship': credentialSubject['citizenship'],
                'bloodGroup': credentialSubject['bloodGroup'],
                'email': credentialSubject['email'],
                'phone': credentialSubject['phone'],
                'profilePhotoHash': credentialSubject['profilePhotoHash'],
              };
              
              // Extract address data if available
              if (credentialSubject['address'] is Map) {
                final address = credentialSubject['address'] as Map<String, dynamic>;
                result['address.street'] = address['street'];
                result['address.city'] = address['city'];
                result['address.district'] = address['district'];
                result['address.postalCode'] = address['postalCode'];
                result['address.divisionalSecretariat'] = address['divisionalSecretariat'];
                result['address.gramaNiladhariDivision'] = address['gramaNiladhariDivision'];
                result['address.province'] = address['province'];
              }
              
              print('[OfflineAuthService] 🎯 Extracted data: $result');
              return result;
            } else {
              print('[OfflineAuthService]   credentialSubject not found or not a Map');
              print('[OfflineAuthService] Available keys in credential: ${firstCredential.keys.toList()}');
            }
          }
        } else {
          print('[OfflineAuthService]   No credentials found in: $location');
          if (userData.containsKey(location)) {
            print('[OfflineAuthService] $location exists but is: ${userData[location]} (type: ${userData[location].runtimeType})');
          }
        }
      }
      
      // If we get here, try direct extraction from root
      print('[OfflineAuthService] 🔍 Trying direct root extraction...');
      final rootData = {
        'age': userData['age'],
        'dateOfBirth': userData['dateOfBirth'],
        'fullName': userData['fullName'],
        'nic': userData['nic'],
        'gender': userData['gender'],
        'nationality': userData['nationality'],
      };
      
      print('[OfflineAuthService] Root data: $rootData');
      return rootData;
      
    } catch (e) {
      print('[OfflineAuthService]   Error extracting credentials: $e');
      print('[OfflineAuthService] Stack trace: ${e.toString()}');
      return {};
    }
  }
  
  // Create QR content for age verification
  static String _createAgeVerificationQR({
    required String idNumber,
    required String? fullName,
    required int age,
    required String? dateOfBirth,
    required bool isAbove18,
  }) {
    final status = isAbove18 ? 'OVER 18 - ELIGIBLE' : 'UNDER 18 - NOT ELIGIBLE';
    final emoji = isAbove18 ? ' ' : ' ';
    final title = isAbove18 ? 'AGE VERIFICATION PASSED' : 'AGE VERIFICATION FAILED';
    
    return '$emoji $title\n\n'
           'Digital ID: $idNumber\n'
           'Full Name: ${fullName ?? 'N/A'}\n'
           'Status: $status\n\n'
           'Source: Digital ID Wallet\n'
           'Verified: ${DateTime.now().toLocal()}';
  }
  
  // Helper method to get field value
  static String? _getFieldValue(Map<String, dynamic> data, String fieldPath) {
    try {
      if (fieldPath.contains('.')) {
        // Handle nested fields like address.street
        final parts = fieldPath.split('.');
        dynamic current = data;
        for (final part in parts) {
          if (current is Map && current.containsKey(part)) {
            current = current[part];
          } else {
            return null;
          }
        }
        return current?.toString();
      } else {
        return data[fieldPath]?.toString();
      }
    } catch (e) {
      return null;
    }
  }
  
  // Helper method to get field display name
  static String _getFieldDisplayName(String fieldKey) {
    const displayNames = {
      'fullName': 'Full Name',
      'nic': 'NIC Number',
      'age': 'Age',
      'dateOfBirth': 'Date of Birth',
      'gender': 'Gender',
      'nationality': 'Nationality',
      'citizenship': 'Citizenship',
      'bloodGroup': 'Blood Group',
      'email': 'Email Address',
      'phone': 'Phone Number',
      'address.street': 'Street Address',
      'address.city': 'City',
      'address.district': 'District',
      'address.postalCode': 'Postal Code',
      'address.divisionalSecretariat': 'Divisional Secretariat',
      'address.gramaNiladhariDivision': 'Grama Niladhari Division',
      'address.province': 'Province',
    };
    
    return displayNames[fieldKey] ?? fieldKey;
  }
  
  // Extract all user data from credentials
  static Map<String, dynamic> extractAllUserData(Map<String, dynamic> userData) {
    try {
      final Map<String, dynamic> result = {};
      
      // Extract from credentials first
      if (userData['verifiableCredentials'] is List && 
          userData['verifiableCredentials'].isNotEmpty) {
        final firstCredential = userData['verifiableCredentials'][0];
        if (firstCredential['credentialSubject'] is Map) {
          result.addAll(firstCredential['credentialSubject'] as Map<String, dynamic>);
        }
      }
      
      // Also include root level data
      result.addAll(userData);
      
      return result;
    } catch (e) {
      print('[OfflineAuthService] Error extracting all data: $e');
      return userData;
    }
  }
  
  // Format date for display
  static String _formatDateForDisplay(String? dateString) {
    if (dateString == null) return 'N/A';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
  
  // Store user data locally
  static Future<void> storeUserDataLocally(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userDataKey, jsonEncode(userData));
      print('[OfflineAuthService]   User data stored locally');
      
      // Debug: Verify what we stored
      final stored = await getLocalUserData();
      if (stored != null) {
        final extracted = extractUserDataFromCredentials(stored);
        print('[OfflineAuthService]   Verified stored data extraction: $extracted');
      }
    } catch (e) {
      print('[OfflineAuthService]   Error storing user data: $e');
    }
  }
  
  // Get user data from local storage
  static Future<Map<String, dynamic>?> getLocalUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_userDataKey);
      
      if (data != null) {
        final userData = jsonDecode(data) as Map<String, dynamic>;
        print('[OfflineAuthService]   Retrieved local user data');
        print('[OfflineAuthService] Stored data keys: ${userData.keys.toList()}');
        return userData;
      } else {
        print('[OfflineAuthService]   No local user data found');
        return null;
      }
    } catch (e) {
      print('[OfflineAuthService]   Error reading local user data: $e');
      return null;
    }
  }
  
  // Check if local user data exists
  static Future<bool> hasLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasData = prefs.containsKey(_userDataKey);
    print('[OfflineAuthService] Local data exists: $hasData');
    return hasData;
  }
  
  // Clear local user data
  static Future<void> clearLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
    print('[OfflineAuthService]   Local user data cleared');
  }
  
  // Get available fields for data sharing
  static Map<String, String> getAvailableFields() {
    return {
      'fullName': 'Full Name',
      'nic': 'NIC Number',
      'age': 'Age',
      'dateOfBirth': 'Date of Birth',
      'gender': 'Gender',
      'nationality': 'Nationality',
      'citizenship': 'Citizenship',
      'bloodGroup': 'Blood Group',
      'email': 'Email Address',
      'phone': 'Phone Number',
      'address.street': 'Street Address',
      'address.city': 'City',
      'address.district': 'District',
      'address.postalCode': 'Postal Code',
      'address.divisionalSecretariat': 'Divisional Secretariat',
      'address.gramaNiladhariDivision': 'Grama Niladhari Division',
      'address.province': 'Province',
    };
  }

  static Future getStoredWalletData(String walletId) async {}
}