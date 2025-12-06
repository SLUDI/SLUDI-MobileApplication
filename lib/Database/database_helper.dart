// lib/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'user_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT UNIQUE,
        citizenCode TEXT,
        fullName TEXT,
        nic TEXT,
        age INTEGER,
        email TEXT,
        phone TEXT,
        dateOfBirth TEXT,
        gender TEXT,
        nationality TEXT,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_address(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        street TEXT,
        city TEXT,
        district TEXT,
        postalCode TEXT,
        divisionalSecretariat TEXT,
        gramaNiladhariDivision TEXT,
        province TEXT,
        FOREIGN KEY (userId) REFERENCES user_profile (userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE verifiable_credentials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        credentialId TEXT UNIQUE,
        credentialType TEXT,
        issuer TEXT,
        issuanceDate TEXT,
        expirationDate TEXT,
        credentialData TEXT,
        FOREIGN KEY (userId) REFERENCES user_profile (userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE auth_tokens(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        accessToken TEXT,
        refreshToken TEXT,
        tokenType TEXT,
        expiresIn INTEGER,
        createdAt TEXT,
        FOREIGN KEY (userId) REFERENCES user_profile (userId)
      )
    ''');
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}