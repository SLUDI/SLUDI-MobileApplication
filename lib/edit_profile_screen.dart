import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:new_project/app_theme.dart';
import 'api_service.dart';

class EditWalletScreen extends StatefulWidget {
  const EditWalletScreen({super.key});

  @override
  State<EditWalletScreen> createState() => _WalletProfileViewScreenState();
}

class _WalletProfileViewScreenState extends State<EditWalletScreen> {
  // Display-only values (as per your requirement)
  String _fullName = 'N/A';
  String _nic = 'N/A';
  String _dateOfBirth = 'N/A';
  //String _sex = 'N/A';
  String _gender = 'N/A';
  String _address = 'N/A';

  Uint8List? _profileImageBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() => _isLoading = true);

      final walletStatus = await ApiService.getWalletStatus();
      if (walletStatus['success'] != true) return;

      final walletData = walletStatus['data'];
      final credentials = walletData?['walletVerifiableCredentials'];

      if (credentials is! List || credentials.isEmpty) return;

      // Find IDENTITY VC (matches your response)
      Map<String, dynamic>? identityCredential;
      for (final c in credentials) {
        if (c is Map) {
          final type = c['credentialType'];
          if (type == 'IDENTITY') {
            identityCredential = Map<String, dynamic>.from(c as Map);
            break;
          }
        }
      }
      identityCredential ??= (credentials.first is Map)
          ? Map<String, dynamic>.from(credentials.first as Map)
          : null;

      if (identityCredential == null) return;

      final subjectRaw = identityCredential['credentialSubject'];
      if (subjectRaw is! Map) return;

      final subject = Map<String, dynamic>.from(subjectRaw as Map);

      // Extract fields exactly as in your response
      final fullName = _asNonEmptyString(subject['fullName']);
      final nic = _asNonEmptyString(subject['nic']);
      final dob = _asNonEmptyString(subject['dateOfBirth']);

      // Backend has "gender: male" -> use it for both "Sex" and "Gender" for now
      final gender = _asNonEmptyString(subject['gender']);
      //final sex = gender; // (if later backend adds "sex", you can use that)

      final addressStr = _formatAddress(subject['address']);

      final photoCid = _asNonEmptyString(subject['profilePhotoHash']);
      if (photoCid != null) {
        await _loadProfilePhoto(photoCid);
      }

      if (!mounted) return;
      setState(() {
        if (fullName != null) _fullName = fullName;
        if (nic != null) _nic = nic;
        if (dob != null) _dateOfBirth = dob;
       // if (sex != null) _sex = _capitalizeFirst(sex);
        if (gender != null) _gender = _capitalizeFirst(gender);
        if (addressStr != null) _address = addressStr;
      });
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _asNonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // address is an object in your response:
  // address: {street:..., city:..., district:..., postalCode:..., province:...}
  String? _formatAddress(dynamic addressValue) {
    if (addressValue == null) return null;

    if (addressValue is String) {
      final t = addressValue.trim();
      return t.isEmpty ? null : t;
    }

    if (addressValue is Map) {
      final address = Map<String, dynamic>.from(addressValue);

      String pick(String key) {
        final v = address[key];
        if (v == null) return '';
        return v.toString().trim();
      }

      final parts = <String>[
        pick('street'),
        pick('city'),
        pick('district'),
        pick('postalCode'),
        pick('province'),
      ].where((e) => e.isNotEmpty).toList();

      return parts.isEmpty ? null : parts.join(', ');
    }

    return addressValue.toString().trim();
  }

  Future<void> _loadProfilePhoto(String cid) async {
    try {
      final response = await ApiService.getProfilePhoto(cid);

      if (response.success && response.data != null) {
        String imageData = response.data as String;

        // Remove "data:image/...;base64," if present
        if (imageData.contains(',')) {
          imageData = imageData.split(',').last;
        }

        final bytes = base64Decode(imageData);

        if (mounted) {
          setState(() => _profileImageBytes = bytes);
        }
      }
    } catch (e) {
      debugPrint('Error loading profile photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg1,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(child: Text('Profile', style: AppTheme.headingStyle)),
                const SizedBox(height: 16),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                  ),

                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                      image: _profileImageBytes != null
                          ? DecorationImage(image: MemoryImage(_profileImageBytes!), fit: BoxFit.cover)
                          : null,
                      gradient: _profileImageBytes == null
                          ? LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.3),
                                AppTheme.primaryColor.withOpacity(0.1),
                              ],
                            )
                          : null,
                    ),
                    child: _profileImageBytes == null
                        ? const Icon(Icons.person, size: 60, color: AppTheme.primaryColor)
                        : null,
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.glassDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Full Name', _fullName, Icons.person_outline),
                      const SizedBox(height: 18),
                      _buildInfoRow('NIC Number', _nic, Icons.badge_outlined),
                      const SizedBox(height: 18),
                      _buildInfoRow('Date of Birth', _dateOfBirth, Icons.cake_outlined),
                      const SizedBox(height: 18),
                     // _buildInfoRow('Sex', _sex, Icons.wc_outlined),
                      const SizedBox(height: 18),
                      _buildInfoRow('Gender', _gender, Icons.transgender_outlined),
                      const SizedBox(height: 18),
                      _buildInfoRow('Address', _address, Icons.location_on_outlined, maxLines: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {int maxLines = 2}) {
    final shown = value.trim().isEmpty ? 'N/A' : value.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                shown,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
