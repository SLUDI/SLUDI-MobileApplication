// lib/repositories/user_repository.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class UserRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Save complete user data from API response
  Future<void> saveUserData(Map<String, dynamic> apiResponse) async {
    final db = await _databaseHelper.database;
    
    await db.transaction((txn) async {
      // Extract user data
      final userData = apiResponse['data'] is List && apiResponse['data'].isNotEmpty
          ? apiResponse['data'][0]
          : apiResponse['data'];

      if (userData != null) {
        // Save user profile
        await _saveUserProfile(txn, userData);
        
        // Save address
        if (userData['address'] != null) {
          await _saveUserAddress(txn, userData['userId'], userData['address']);
        }
      }

      // Save verifiable credentials
      final credentials = apiResponse['verifiableCredentials'];
      if (credentials is List) {
        await _saveVerifiableCredentials(txn, userData?['userId'], credentials);
      }

      // Save auth tokens if available
      if (apiResponse['tokens'] != null) {
        await _saveAuthTokens(txn, userData?['userId'], apiResponse['tokens']);
      }
    });
  }

  Future<void> _saveUserProfile(Transaction txn, Map<String, dynamic> userData) async {
    await txn.insert(
      'user_profile',
      {
        'userId': userData['userId'],
        'citizenCode': userData['citizenCode'],
        'fullName': userData['fullName'],
        'nic': userData['nic'],
        'age': userData['age'],
        'email': userData['email'],
        'phone': userData['phone'],
        'dateOfBirth': userData['dateOfBirth'],
        'gender': userData['gender'],
        'nationality': userData['nationality'],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveUserAddress(Transaction txn, String? userId, Map<String, dynamic> address) async {
    if (userId == null) return;
    
    await txn.insert(
      'user_address',
      {
        'userId': userId,
        'street': address['street'],
        'city': address['city'],
        'district': address['district'],
        'postalCode': address['postalCode'],
        'divisionalSecretariat': address['divisionalSecretariat'],
        'gramaNiladhariDivision': address['gramaNiladhariDivision'],
        'province': address['province'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveVerifiableCredentials(Transaction txn, String? userId, List<dynamic> credentials) async {
    for (final credential in credentials) {
      if (credential is Map<String, dynamic>) {
        await txn.insert(
          'verifiable_credentials',
          {
            'userId': userId,
            'credentialId': credential['id'],
            'credentialType': credential['type'],
            'issuer': credential['issuer'],
            'issuanceDate': credential['issuanceDate'],
            'expirationDate': credential['expirationDate'],
            'credentialData': json.encode(credential),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<void> _saveAuthTokens(Transaction txn, String? userId, Map<String, dynamic> tokens) async {
    if (userId == null) return;
    
    await txn.insert(
      'auth_tokens',
      {
        'userId': userId,
        'accessToken': tokens['accessToken'],
        'refreshToken': tokens['refreshToken'],
        'tokenType': tokens['tokenType'],
        'expiresIn': tokens['expiresIn'],
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get user data for offline use
  Future<Map<String, dynamic>> getUserData() async {
    final db = await _databaseHelper.database;
    
    final userProfile = await db.query('user_profile');
    if (userProfile.isEmpty) {
      throw Exception('No user data found');
    }

    final user = userProfile.first;
    final userId = user['userId'];

    // Get address
    final addressData = await db.query(
      'user_address',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    // Get credentials
    final credentialsData = await db.query(
      'verifiable_credentials',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    // Convert credentials back to original format
    final credentials = credentialsData.map((cred) {
      try {
        return json.decode(cred['credentialData'] as String);
      } catch (e) {
        return null;
      }
    }).where((item) => item != null).toList();

    return {
      'success': true,
      'data': [user],
      'verifiableCredentials': credentials,
      'address': addressData.isNotEmpty ? addressData.first : {},
      'isOffline': true,
    };
  }

  // Check if user data exists
  Future<bool> hasUserData() async {
    final db = await _databaseHelper.database;
    final result = await db.query('user_profile');
    return result.isNotEmpty;
  }

  // Clear all user data (logout)
  Future<void> clearUserData() async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.delete('user_profile');
      await txn.delete('user_address');
      await txn.delete('verifiable_credentials');
      await txn.delete('auth_tokens');
    });
  }

  // Update specific user data
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    final db = await _databaseHelper.database;
    final userProfile = await db.query('user_profile');
    if (userProfile.isNotEmpty) {
      final userId = userProfile.first['userId'];
      await db.update(
        'user_profile',
        {
          ...updates,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'userId = ?',
        whereArgs: [userId],
      );
    }
  }
}