// lib/services/storage_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _registeredDidKey = 'registered_did';
  static const String _deviceLockKey = 'device_did_lock';
  static const String _userDataKey = 'user_data';
  static const String _isFirstTimeKey = 'is_first_time';

  static Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  // Store the registered DID for this device
  static Future<void> setRegisteredDid(String did) async {
    final prefs = await _prefs;
    await prefs.setString(_registeredDidKey, did);
    await prefs.setBool(_deviceLockKey, true);
    print('[StorageService]   DID locked to device: $did');
  }

  // Get the registered DID for this device
  static Future<String?> getRegisteredDid() async {
    final prefs = await _prefs;
    return prefs.getString(_registeredDidKey);
  }

  // Check if device is locked to a specific DID
  static Future<bool> isDeviceLocked() async {
    final prefs = await _prefs;
    return prefs.getBool(_deviceLockKey) ?? false;
  }

  // Store user data after login
  static Future<void> storeUserData(Map<String, dynamic> userData) async {
    final prefs = await _prefs;
    await prefs.setString(_userDataKey, jsonEncode(userData));
    print('[StorageService]   User data stored: ${userData['fullName']}');
  }

  // Get stored user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await _prefs;
    final userDataString = prefs.getString(_userDataKey);
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
    final prefs = await _prefs;
    await prefs.remove(_userDataKey);
    print('[StorageService]   User data cleared');
  }

  // Clear device lock (for logout or account switching)
  static Future<void> clearDeviceLock() async {
    final prefs = await _prefs;
    await prefs.remove(_registeredDidKey);
    await prefs.remove(_deviceLockKey);
    await prefs.remove(_userDataKey);
    print('[StorageService]   Device lock and user data cleared');
  }

  // Check if user data exists
  static Future<bool> hasUserData() async {
    final prefs = await _prefs;
    return prefs.containsKey(_userDataKey);
  }
}