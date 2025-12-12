import 'package:flutter/material.dart';
import 'package:new_project/api_service.dart';
import 'id_card_selection_screen.dart';

class WalletScreen extends StatefulWidget {
  final String idNumber;
  final String password;

  const WalletScreen({required this.idNumber, required this.password});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? walletData;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await ApiService.getWalletStatus();

      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            walletData = result;
          } else {
            errorMessage = result['error'] ?? 'Failed to load wallet data';
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error loading wallet data: $e';
        });
      }
    }
  }

  String? _getCredentialData(String fieldPath) {
    if (walletData == null) return null;

    final List<dynamic> credentials = [];

    if (walletData!['verifiableCredentials'] is List) {
      credentials.addAll(walletData!['verifiableCredentials'] as List);
    }

    if (walletData!['walletVerifiableCredentials'] is List) {
      credentials.addAll(walletData!['walletVerifiableCredentials'] as List);
    }

    if (walletData!['data'] is Map &&
        (walletData!['data']['walletVerifiableCredentials'] is List)) {
      credentials.addAll(
        walletData!['data']['walletVerifiableCredentials'] as List,
      );
    }

    if (credentials.isEmpty) return null;

    final fieldParts = fieldPath.split('.');

    for (final credential in credentials) {
      if (credential is Map<String, dynamic>) {
        dynamic currentData = credential;

        for (final part in fieldParts) {
          if (currentData is Map<String, dynamic> &&
              currentData[part] != null) {
            currentData = currentData[part];
          } else {
            currentData = null;
            break;
          }
        }

        if (currentData != null) {
          return currentData.toString();
        }

        final subject = credential['credentialSubject'];
        if (subject is Map<String, dynamic>) {
          currentData = subject;

          for (final part in fieldParts) {
            if (currentData is Map<String, dynamic> &&
                currentData[part] != null) {
              currentData = currentData[part];
            } else {
              currentData = null;
              break;
            }
          }

          if (currentData != null) {
            return currentData.toString();
          }
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _getCredentialByType(String type) {
    if (walletData == null) return null;

    final List<dynamic> credentials = [];

    if (walletData!['walletVerifiableCredentials'] is List) {
      credentials.addAll(walletData!['walletVerifiableCredentials'] as List);
    }

    if (walletData!['verifiableCredentials'] is List) {
      credentials.addAll(walletData!['verifiableCredentials'] as List);
    }

    if (walletData!['data'] is Map &&
        (walletData!['data']['walletVerifiableCredentials'] is List)) {
      credentials.addAll(
        walletData!['data']['walletVerifiableCredentials'] as List,
      );
    }

    for (final c in credentials) {
      if (c is Map<String, dynamic> && c['credentialType'] == type) {
        return c;
      }
    }

    return null;
  }

  bool get _hasDrivingLicenseCredential {
    return _getCredentialByType('DRIVING_LICENSE') != null;
  }

  String? _getDrivingLicenseField(String key) {
    final cred = _getCredentialByType('DRIVING_LICENSE');
    if (cred == null) return null;

    final subject = cred['credentialSubject'];
    if (subject is! Map<String, dynamic>) return null;

    final value = subject[key];
    if (value == null || value.toString() == 'null') return null;

    return value.toString();
  }

  String? _getDrivingLicenseDate(String key) {
    final raw = _getDrivingLicenseField(key);
    if (raw == null) return null;

    try {
      final dt = DateTime.parse(raw);
      return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String? _getFormattedDate(String fieldPath) {
    final dateString = _getCredentialData(fieldPath);
    if (dateString == null) return null;

    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showCardDetails(BuildContext context, String cardType) {
    print('Navigating to $cardType details'); // Debug print

    final cardData = {
      'Digital ID': {
        'Name': _getCredentialData('fullName') ?? 'John Doe',
        'Address': _getCredentialData('address.street') ?? '123 Main St',
        'Issue Date': _getFormattedDate('issuanceDate') ?? '01/15/2020',
        'NIC Number': _getCredentialData('nic') ?? 'ID123456789',
        'Date of Birth': _getFormattedDate('dateOfBirth') ?? '01/01/1990',
        'Gender': _getCredentialData('gender') ?? 'Male',
      },
      'Driving License': {
        'Name': _getCredentialData('fullName') ?? 'John Doe',
        'License Number': _getDrivingLicenseField('licenseNumber') ?? 'DL987654321',
        'Category': _getDrivingLicenseCategories() ?? 'A, B',
        'Issue Date': _getDrivingLicenseDate('issueDate') ?? '06/10/2019',
        'Expire Date': _getDrivingLicenseDate('expiryDate') ?? '06/10/2027',
        'Issuing Authority': _getDrivingLicenseField('issuingAuthority') ?? 'DMV',
      },
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IDCardSelectionScreen(
          selectedCardType: cardType,
          allCardData: cardData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'My Digital Cards',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.05),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your cards...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : errorMessage.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: 40,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Unable to Load Cards',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadWalletData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // ID Card - Simple GestureDetector wrapper
                        GestureDetector(
                          onTap: () {
                            print('ID Card tapped'); // Debug print
                            _showCardDetails(context, 'Digital ID');
                          },
                          child: _buildIDCard(),
                        ),
                        const SizedBox(height: 20),

                        // Driver's License (if available)
                        if (_hasDrivingLicenseCredential)
                          GestureDetector(
                            onTap: () {
                              print('Driver License tapped'); // Debug print
                              _showCardDetails(context, 'Driving License');
                            },
                            child: _buildDriversLicenseCard(),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildIDCard() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF1D4ED8).withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 20,
                            color: Colors.white.withOpacity(0.95),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'ID Card',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Name
                  Text(
                    _getCredentialData('fullName')?.toUpperCase() ?? 'JOHN DOE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // ID Number
                  Text(
                    _getCredentialData('nic') ?? 'ID123456789',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Dates Row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ISSUED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getFormattedDate('issuanceDate') ?? '01/15/2020',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXPIRES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getFormattedDate('expiryDate') ?? '01/15/2030',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bottom indicator
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Visual feedback layer
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: null, // Handled by parent GestureDetector
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversLicenseCard() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF047857).withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            size: 20,
                            color: Colors.white.withOpacity(0.95),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Driver\'s License',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'VALID',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Name
                  Text(
                    _getCredentialData('fullName')?.toUpperCase() ?? 'JOHN DOE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // License Number
                  Text(
                    _getDrivingLicenseField('licenseNumber') ?? 'DL987654321',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Dates Row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ISSUED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getDrivingLicenseDate('issueDate') ?? '06/10/2019',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXPIRES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getDrivingLicenseDate('expiryDate') ?? '06/10/2027',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bottom indicator
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Visual feedback layer
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: null, // Handled by parent GestureDetector
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getDrivingLicenseCategories() {
    final cred = _getCredentialByType('DRIVING_LICENSE');
    if (cred == null) return null;

    final subject = cred['credentialSubject'];
    if (subject is! Map<String, dynamic>) return null;

    final vehicles = subject['authorizedVehicles'];
    if (vehicles is! List) return null;

    final categories = <String>{};

    for (final v in vehicles) {
      if (v is Map<String, dynamic> && v['category'] != null) {
        final cat = v['category'].toString().trim();
        if (cat.isNotEmpty && cat != 'null') {
          categories.add(cat);
        }
      }
    }

    if (categories.isEmpty) return null;

    return categories.join(', ');
  }
}