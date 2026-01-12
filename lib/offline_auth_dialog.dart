// lib/offline_auth_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'offline_auth_service.dart';

class OfflineAuthDialog extends StatefulWidget {
  final String idNumber;
  final Map<String, dynamic> userData;

  const OfflineAuthDialog({
    super.key,
    required this.idNumber,
    required this.userData,
  });

  @override
  State<OfflineAuthDialog> createState() => _OfflineAuthDialogState();
}

class _OfflineAuthDialogState extends State<OfflineAuthDialog> {
  String? _currentQRData;
  String _selectedMode = 'age_verification';
  bool _isLoading = false;
  Map<String, dynamic>? _verificationResult;

  final Map<String, bool> _selectedFields = {};
  final Map<String, String> _fieldDisplayNames = {
    'fullName': 'Full Name',
    'nic': 'NIC Number',
    'age': 'Age',
    'dateOfBirth': 'Date of Birth',
    'gender': 'Gender',
    'nationality': 'Nationality',
    'citizenship': 'Citizenship',
    'bloodGroup': 'Blood Group',
    'email': 'Email',
    'phone': 'Phone',
    'address.street': 'Street Address',
    'address.city': 'City',
    'address.district': 'District',
    'address.postalCode': 'Postal Code',
  };

  @override
  void initState() {
    super.initState();
    _initializeFieldSelections();
  }

  void _initializeFieldSelections() {
    final defaultSelected = ['fullName', 'nic', 'age', 'dateOfBirth'];
    for (final field in _fieldDisplayNames.keys) {
      _selectedFields[field] = defaultSelected.contains(field);
    }
  }

  void _generateQRCode(String type) async {
    setState(() {
      _isLoading = true;
      _verificationResult = null;
    });

    if (type == 'share_data') {
      await _generateDataSharingQR();
    } else {
      final result = await OfflineAuthService.generateVerificationQR(
        idNumber: widget.idNumber,
        verificationType: type,
        userData: widget.userData,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _currentQRData = result['qrString'];
          _selectedMode = type;
          _verificationResult = result;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _generateDataSharingQR() async {
    try {
      final result = await OfflineAuthService.generateDataSharingQR(
        idNumber: widget.idNumber,
        selectedFields: _selectedFields,
        userData: widget.userData,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _currentQRData = result['qrString'];
          _selectedMode = 'share_data';
          _verificationResult = result;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR code generated with ${result['fieldsCount']} fields'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating QR: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // FIXED: supports BOTH "address.street" direct key AND nested address.street path
  String? _getFieldValue(String fieldPath) {
    try {
      final extractedData = OfflineAuthService.extractAllUserData(widget.userData);

      // 1) Try direct key (supports flat map keys like "address.street")
      final direct = extractedData[fieldPath];
      if (direct != null) return direct.toString();

      // 2) Try nested traversal (supports {address:{street:...}})
      if (fieldPath.contains('.')) {
        final parts = fieldPath.split('.');
        dynamic current = extractedData;
        for (final part in parts) {
          if (current is Map && current.containsKey(part)) {
            current = current[part];
          } else {
            return null;
          }
        }
        return current?.toString();
      }

      return extractedData[fieldPath]?.toString();
    } catch (_) {
      return null;
    }
  }

  Widget _buildVerificationOption(
      String type, String title, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue, size: 20),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: _isLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code, size: 20),
        onTap: _isLoading ? null : () => _generateQRCode(type),
        dense: true,
      ),
    );
  }

  Widget _buildSegmentTabs() {
    final selectedCount = _selectedFields.values.where((v) => v).length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(10),
        labelPadding: EdgeInsets.zero,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black87,
        indicator: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(10),
        ),
        tabs: [
          const Tab(
            child: SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Age Verify',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Tab(
            child: SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    selectedCount > 0 ? 'Share Data ($selectedCount)' : 'Share Data',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSharingSection() {
    final selectedCount = _selectedFields.values.where((v) => v).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Select information to share:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        if (selectedCount > 0)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 14),
                const SizedBox(width: 6),
                Text(
                  '$selectedCount field${selectedCount > 1 ? 's' : ''} selected',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        Flexible(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _fieldDisplayNames.entries.length,
              itemBuilder: (context, index) {
                final entry = _fieldDisplayNames.entries.elementAt(index);
                final fieldKey = entry.key;
                final displayName = entry.value;
                final fieldValue = _getFieldValue(fieldKey);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Card(
                    elevation: 1,
                    child: CheckboxListTile(
                      title: Text(displayName, style: const TextStyle(fontSize: 12)),
                      subtitle: fieldValue != null
                          ? Text(
                              fieldValue.length > 30
                                  ? '${fieldValue.substring(0, 30)}...'
                                  : fieldValue,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            )
                          : const Text(
                              'Not available',
                              style: TextStyle(fontSize: 10, color: Colors.red),
                            ),
                      value: _selectedFields[fieldKey] ?? false,
                      onChanged: fieldValue != null
                          ? (value) {
                              setState(() {
                                _selectedFields[fieldKey] = value ?? false;
                              });
                            }
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.blue,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: selectedCount > 0 && !_isLoading
                ? () => _generateQRCode('share_data')
                : null,
            icon: _isLoading
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_2, size: 16),
            label: Text(
              _isLoading ? 'Generating...' : 'Generate QR ($selectedCount)',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedCount > 0 && !_isLoading ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgeVerificationSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Generate QR code for identity verification:',
          style: TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildVerificationOption(
          'age_verification',
          'Identity & Age Verification',
          'Verify your age and identity',
          Icons.verified_user,
        ),
      ],
    );
  }

  Color _getStatusColor(bool? isAbove18) {
    if (isAbove18 == null) return Colors.grey;
    return isAbove18 ? Colors.green : Colors.red;
  }

  String _getStatusText(bool? isAbove18) {
    if (isAbove18 == null) return 'Unknown';
    return isAbove18 ? 'ELIGIBLE' : 'NOT ELIGIBLE';
  }

  Widget _buildQRCodeView() {
    final isDataSharing = _selectedMode == 'share_data';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              children: [
                Icon(
                  isDataSharing ? Icons.share : Icons.verified_user,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  isDataSharing ? 'Shared Data QR Code' : 'Age Verification',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  isDataSharing
                      ? '${_verificationResult?['fieldsCount'] ?? 0} fields shared'
                      : 'Verify your age and identity',
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final qrSize = constraints.maxWidth * 0.6;
                        return QrImageView(
                          data: _currentQRData!,
                          version: QrVersions.auto,
                          size: qrSize.clamp(150.0, 250.0),
                          backgroundColor: Colors.white,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isDataSharing && _verificationResult != null) _buildSharedDataPreview(),
                  if (!isDataSharing && _verificationResult != null) _buildAgeVerificationPreview(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentQRData = null;
                      _verificationResult = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.done, size: 16),
                  label: const Text('Done', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSharedDataPreview() {
    final sharedData = _verificationResult?['sharedData'] as Map<String, String>?;

    if (sharedData == null) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 14),
              SizedBox(width: 6),
              Text(
                'Data Ready:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...sharedData.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${entry.key}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black),
                  ),
                  Expanded(
                    child: Text(
                      entry.value.length > 25 ? '${entry.value.substring(0, 25)}...' : entry.value,
                      style: const TextStyle(fontSize: 10, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeVerificationPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getStatusColor(_verificationResult!['isAbove18']).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _getStatusColor(_verificationResult!['isAbove18'])),
      ),
      child: Row(
        children: [
          Icon(
            _verificationResult!['isAbove18'] == true ? Icons.check_circle : Icons.cancel,
            color: _getStatusColor(_verificationResult!['isAbove18']),
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Age Verification: ${_getStatusText(_verificationResult!['isAbove18'])}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getStatusColor(_verificationResult!['isAbove18']),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screenHeight * 0.8,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Digital ID Sharing',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            if (_currentQRData == null) ...[
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSegmentTabs(),
                      const SizedBox(height: 12),
                      Flexible(
                        child: TabBarView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildAgeVerificationSection(),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildDataSharingSection(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Flexible(
                child: _buildQRCodeView(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
