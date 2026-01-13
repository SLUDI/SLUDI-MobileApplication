// lib/services/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  // Singleton pattern
  static final SecureStorageService _instance = SecureStorageService._internal();

  factory SecureStorageService() {
    return _instance;
  }

  SecureStorageService._internal();

  // Create storage instance with options
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Read value
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      print('[SecureStorage] Error reading key $key: $e');
      return null;
    }
  }

  // Write value
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      print('[SecureStorage] Error writing key $key: $e');
    }
  }

  // Delete value
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      print('[SecureStorage] Error deleting key $key: $e');
    }
  }

  // Delete all values
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('[SecureStorage] Error deleting all: $e');
    }
  }
  
  // Check if key exists
  Future<bool> containsKey(String key) async {
     try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      print('[SecureStorage] Error checking key $key: $e');
      return false;
    }
  }
}
