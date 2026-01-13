// lib/services/offline_auth_service.dart
import 'dart:convert';
import 'package:new_project/services/storage_service.dart';
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
      final extractedData = extractUserDataFromCredentials(userData);
      final age = extractedData['age'];
      final dateOfBirth = extractedData['dateOfBirth'];
      final fullName = extractedData['fullName'];

      if (age == null) {
        return {
          'success': false,
          'error': 'Age information not found in credentials. Available fields: ${extractedData.keys}',
        };
      }

      int ageValue;
      if (age is String) {
        ageValue = int.tryParse(age) ?? 0;
      } else if (age is int) {
        ageValue = age;
      } else {
        ageValue = 0;
      }

      final isAbove18 = ageValue >= 18;

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
      final extractedData = extractAllUserData(userData);
      final sharedData = <String, String>{};

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

      final qrContent = _createStructuredQRContent(
        idNumber: idNumber,
        sharedData: sharedData,
        timestamp: DateTime.now(),
      );

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
      return {
        'success': false,
        'error': 'Failed to generate QR code: $e',
      };
    }
  }

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

  static String _createSimpleQRContent(Map<String, String> sharedData) {
    final buffer = StringBuffer();
    buffer.writeln(' DIGITAL IDENTITY CARD');
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

  static Map<String, dynamic> parseSharedData(String qrContent) {
    try {
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
      } catch (_) {
        return _parseSimpleQRContent(qrContent);
      }
    } catch (_) {}

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

  // This extractor keeps some flattened keys (fine for age verification)
  static Map<String, dynamic> extractUserDataFromCredentials(Map<String, dynamic> userData) {
    try {
      final credentialLocations = [
        'verifiableCredentials',
        'walletVerifiableCredentials',
        'credentials',
        'verifiable_credentials',
      ];

      for (final location in credentialLocations) {
        final creds = userData[location];
        if (creds is List && creds.isNotEmpty) {
          final first = creds.first;
          if (first is Map && first['credentialSubject'] is Map) {
            final subject = Map<String, dynamic>.from(first['credentialSubject']);

            return {
              'id': subject['id'],
              'age': subject['age'],
              'dateOfBirth': subject['dateOfBirth'],
              'fullName': subject['fullName'],
              'nic': subject['nic'],
              'gender': subject['gender'],
              'nationality': subject['nationality'],
              'citizenship': subject['citizenship'],
              'bloodGroup': subject['bloodGroup'],
              'email': subject['email'],
              'phone': subject['phone'],
              'profilePhotoHash': subject['profilePhotoHash'],
            };
          }
        }
      }

      return {
        'age': userData['age'],
        'dateOfBirth': userData['dateOfBirth'],
        'fullName': userData['fullName'],
        'nic': userData['nic'],
        'gender': userData['gender'],
        'nationality': userData['nationality'],
      };
    } catch (_) {
      return {};
    }
  }

  static String _createAgeVerificationQR({
    required String idNumber,
    required String? fullName,
    required int age,
    required String? dateOfBirth,
    required bool isAbove18,
  }) {
    final status = isAbove18 ? 'OVER 18 - ELIGIBLE' : 'UNDER 18 - NOT ELIGIBLE';
    final emoji = isAbove18 ? '' : '';
    final title = isAbove18 ? 'AGE VERIFICATION PASSED' : 'AGE VERIFICATION FAILED';

    return '$emoji $title\n\n'
        'Digital ID: $idNumber\n'
        'Full Name: ${fullName ?? 'N/A'}\n'
        'Status: $status\n\n'
        'Source: Digital ID Wallet\n'
        'Verified: ${DateTime.now().toLocal()}';
  }

  static String? _getFieldValue(Map<String, dynamic> data, String fieldPath) {
    try {
      // direct key (supports flat keys too)
      final direct = data[fieldPath];
      if (direct != null) return direct.toString();

      if (fieldPath.contains('.')) {
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
    } catch (_) {
      return null;
    }
  }

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
    };

    return displayNames[fieldKey] ?? fieldKey;
  }

  //  FIXED: extracts credentialSubject from ALL possible locations and keeps NESTED address map
  static Map<String, dynamic> extractAllUserData(Map<String, dynamic> userData) {
    try {
      Map<String, dynamic> subject = {};

      final credentialLocations = [
        'verifiableCredentials',
        'walletVerifiableCredentials',
        'credentials',
        'verifiable_credentials',
      ];

      for (final loc in credentialLocations) {
        final creds = userData[loc];
        if (creds is List && creds.isNotEmpty) {
          final first = creds.first;
          if (first is Map && first['credentialSubject'] is Map) {
            subject = Map<String, dynamic>.from(first['credentialSubject']);
            break;
          }
        }
      }

      final result = <String, dynamic>{};

      // Prefer credentialSubject
      result.addAll(subject);

      // Add root as fallback
      result.addAll(userData);

      // Ensure nested address map (so address.street works)
      if (result['address'] is Map) {
        result['address'] = Map<String, dynamic>.from(result['address']);
      }

      return result;
    } catch (_) {
      return userData;
    }
  }

  static Future<void> storeUserDataLocally(Map<String, dynamic> userData) async {
    try {
      // Use the StorageService which now uses SecureStorage
      await StorageService.storeUserData(userData);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getLocalUserData() async {
    try {
      return await StorageService.getUserData();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasLocalUserData() async {
    return await StorageService.hasUserData();
  }

  static Future<void> clearLocalUserData() async {
    await StorageService.clearUserData();
  }

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
    };
  }

  static Future getStoredWalletData(String walletId) async {}
}
