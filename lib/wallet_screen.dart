import 'package:flutter/material.dart';
import 'package:new_project/offline_auth_dialog.dart';
import 'package:new_project/offline_auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'id_card_selection_screen.dart';
import 'api_service.dart';

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

  // In your WalletScreen, when you get data from API
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

            // STORE COMPLETE DATA LOCALLY
            _storeUserDataLocally(result);
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

  // Store the complete API response
  Future<void> _storeUserDataLocally(Map<String, dynamic> apiResponse) async {
    try {
      // Store the entire API response
      await OfflineAuthService.storeUserDataLocally(apiResponse);
      print('[WalletScreen] Complete user data stored locally');
    } catch (e) {
      print('Error storing user data locally: $e');
    }
  }

  Widget _buildOfflineAuthButton() {
    return ElevatedButton.icon(
      onPressed: () {
        // Use the walletData that's already loaded (from local or API)
        if (walletData != null) {
          final userData =
              walletData!['data'] is List && walletData!['data'].isNotEmpty
              ? walletData!['data'][0]
              : walletData!['data'];

          showDialog(
            context: context,
            builder: (context) => OfflineAuthDialog(
              idNumber: widget.idNumber,
              userData: userData ?? {},
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('No user data available')));
        }
      },
      icon: Icon(Icons.qr_code_scanner),
      label: Text('Generate Verification QR'),
    );
  }

  // Helper method to get data from verifiable credentials or return null
  String? _getCredentialData(String fieldPath) {
    if (walletData == null) return null;

    // Collect possible credential lists
    final List<dynamic> credentials = [];

    // 1) Top-level verifiableCredentials (if ever used)
    if (walletData!['verifiableCredentials'] is List) {
      credentials.addAll(walletData!['verifiableCredentials'] as List);
    }

    // 2) Top-level walletVerifiableCredentials
    if (walletData!['walletVerifiableCredentials'] is List) {
      credentials.addAll(walletData!['walletVerifiableCredentials'] as List);
    }

    // 3) data.walletVerifiableCredentials  ✅ this matches your API JSON
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

        // Try on the credential itself
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

        // Try inside credentialSubject
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

  // Find a credential by its credentialType (e.g., "DRIVING_LICENSE")
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

  // Get a simple field from the DRIVING_LICENSE credentialSubject
  String? _getDrivingLicenseField(String key) {
    final cred = _getCredentialByType('DRIVING_LICENSE');
    if (cred == null) return null;

    print('license: $cred');

    final subject = cred['credentialSubject'];
    if (subject is! Map<String, dynamic>) return null;

    final value = subject[key];
    if (value == null || value.toString() == 'null') return null;

    return value.toString();
  }

  // Format a DRIVING_LICENSE date field (issueDate, expireDate)
  String? _getDrivingLicenseDate(String key) {
    final raw = _getDrivingLicenseField(key);
    if (raw == null) return null;

    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw; // fallback if parsing fails
    }
  }

  // Get categories like "A, DE, B, CE, BE"
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

    // Example: "A, DE, B, CE, BE"
    return categories.join(', ');
  }

  // Helper method to format date string (remove time part)
  String? _getFormattedDate(String fieldPath) {
    final dateString = _getCredentialData(fieldPath);
    if (dateString == null) return null;

    try {
      // Try to parse the date and return only the date part
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital ID Wallet'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF), // White
                  Color(0xFFD6E6F2), // Light blue
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (errorMessage.isNotEmpty)
                        Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error Loading Data',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadWalletData,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            // Digital ID Card Button
                            _buildCardButton(
                              context,
                              title: 'Digital ID',
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(
                                    label: 'Name:',
                                    value:
                                        _getCredentialData('fullName') ?? 'N/A',
                                  ),
                                  _InfoRow(
                                    label: 'Address:',
                                    value:
                                        _getCredentialData('address.street') ??
                                        'N/A',
                                  ),
                                  _InfoRow(
                                    label: 'Issue Date:',
                                    value:
                                        _getFormattedDate('issuanceDate') ??
                                        'N/A',
                                  ),
                                  _InfoRow(
                                    label: 'NIC Number:',
                                    value:
                                        _getCredentialData('nic') ??
                                        widget.idNumber,
                                  ),
                                  _InfoRow(
                                    label: 'Date of Birth:',
                                    value:
                                        _getFormattedDate('dateOfBirth') ??
                                        'N/A',
                                  ),
                                  _InfoRow(
                                    label: 'Gender:',
                                    value: _getCredentialData('gender') ?? 'N/A',
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showCardDetails(context, 'Digital ID');
                              },
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFE3F2FD),
                                  Color(0xFFBBDEFB),
                                  Color(0xFF90CAF9),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            if (_hasDrivingLicenseCredential) ...[
                              const SizedBox(height: 20),
                              _buildCardButton(
                                context,
                                title: 'Driving License',
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _InfoRow(
                                      label: 'Name:',
                                      value:
                                          _getCredentialData('fullName') ??
                                          'N/A',
                                    ),
                                    _InfoRow(
                                      label: 'License No:',
                                      value:
                                          _getDrivingLicenseField(
                                            'licenseNumber',
                                          ) ??
                                          'N/A',
                                    ),
                                    _InfoRow(
                                      label: 'Category:',
                                      value:
                                          _getDrivingLicenseCategories() ??
                                          'N/A',
                                    ),
                                    _InfoRow(
                                      label: 'Issue Date:',
                                      value:
                                          _getDrivingLicenseDate('issueDate') ??
                                          'N/A',
                                    ),
                                    _InfoRow(
                                      label: 'Expire Date:',
                                      value:
                                          _getDrivingLicenseDate(
                                            'expiryDate',
                                          ) ??
                                          'N/A',
                                    ),
                                    _InfoRow(
                                      label: 'Issuing Authority:',
                                      value:
                                          _getDrivingLicenseField(
                                            'issuingAuthority',
                                          ) ??
                                          'N/A',
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  _showCardDetails(context, 'Driving License');
                                },
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFE8F5E8),
                                    Color(0xFFC8E6C9),
                                    Color(0xFFA5D6A7),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardButton(
    BuildContext context, {
    required String title,
    required Widget content,
    required VoidCallback onTap,
    Gradient? gradient, // Changed from Color? to Gradient?
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: const Color(0xFF13A4B4),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 1),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCardDetails(BuildContext context, String cardType) {
    // Get data from API response or use defaults
    final cardData = {
      'Digital ID': {
        'Name': _getCredentialData('fullName') ?? 'N/A',
        'Address': _getCredentialData('address.street') ?? 'N/A',
        'Issue Date': _getFormattedDate('issuanceDate') ?? 'N/A',
        'NIC Number': _getCredentialData('nic') ?? widget.idNumber,
        'Date of Birth': _getFormattedDate('dateOfBirth') ?? 'N/A',
        'Gender': _getCredentialData('gender') ?? 'N/A',
      },

      'Driving License': {
        'Name': _getCredentialData('fullName') ?? 'N/A',
        'License Number': _getDrivingLicenseField('licenseNumber') ?? 'N/A',
        'Category': _getDrivingLicenseCategories() ?? 'N/A',
        'Issue Date': _getDrivingLicenseDate('issueDate') ?? 'N/A',
        'Expire Date': _getDrivingLicenseDate('expiryDate') ?? 'N/A',
        'Issuing Authority':
            _getDrivingLicenseField('issuingAuthority') ?? 'N/A',
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
    ).then((selectedData) {
      if (selectedData != null) {
        _shareSelectedData(context, selectedData);
      }
    });
  }

  void _shareSelectedData(
    BuildContext context,
    Map<String, String> selectedData,
  ) {
    final shareMessage = StringBuffer('My ID Information:\n');
    for (var entry in selectedData.entries) {
      shareMessage.writeln('${entry.key}: ${entry.value}');
    }

    Share.share(shareMessage.toString());
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}