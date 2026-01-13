// lib/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';

class StorageService {
  static const String _registeredDidKey = 'registered_did';
  static const String _deviceLockKey = 'device_did_lock';
  static const String _userDataKey = 'user_data';
  // static const String _isFirstTimeKey = 'is_first_time';

  // Use SharedPreferences for non-security critical flags
  static Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();
  
  // Use SecureStorage for sensitive data
  static final _secureStorage = SecureStorageService();

  // Store the registered DID for this device (SECURE)
  static Future<void> setRegisteredDid(String did) async {
    await _secureStorage.write(_registeredDidKey, did);
    
    // We can keep the boolean flag in SharedPreferences or SecureStorage.
    // Putting it in prefs is fine as it just triggers UI logic, but the actual DID is secure.
    final prefs = await _prefs;
    await prefs.setBool(_deviceLockKey, true);
    print('[StorageService] DID locked to device: $did (Encrypted)');
  }

  // Get the registered DID for this device (SECURE)
  static Future<String?> getRegisteredDid() async {
    return await _secureStorage.read(_registeredDidKey);
  }

  // Check if device is locked to a specific DID
  static Future<bool> isDeviceLocked() async {
    // We double check if the DID actually exists in secure storage
    final did = await getRegisteredDid();
    final prefs = await _prefs;
    final isLocked = prefs.getBool(_deviceLockKey) ?? false;
    
    return isLocked && did != null;
  }

  // Store user data after login (SECURE)
  static Future<void> storeUserData(Map<String, dynamic> userData) async {
    await _secureStorage.write(_userDataKey, jsonEncode(userData));
    print('[StorageService] User data stored encrypted: ${userData['fullName']}');
  }

  // Get stored user data (SECURE)
  static Future<Map<String, dynamic>?> getUserData() async {
    final userDataString = await _secureStorage.read(_userDataKey);
    if (userDataString != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(userDataString));
      } catch (e) {
        print('[StorageService] Error parsing user data: $e');
        return null;
      }
    }
    return null;
  }

  // Get specific user field
  static Future<String?> getUserField(String field) async {
    final userData = await getUserData();
    return userData?[field]?.toString();
  }

  // Clear all user data (for logout)
  static Future<void> clearUserData() async {
    await _secureStorage.delete(_userDataKey);
    print('[StorageService] User data cleared');
  }

  // Clear device lock (for logout or account switching)
  static Future<void> clearDeviceLock() async {
    await _secureStorage.delete(_registeredDidKey);
    await _secureStorage.delete(_userDataKey);
    
    final prefs = await _prefs;
    await prefs.remove(_deviceLockKey);
    
    print('[StorageService] Device lock and user data cleared');
  }

  // Check if user data exists
  static Future<bool> hasUserData() async {
    return await _secureStorage.containsKey(_userDataKey);
  }
}
