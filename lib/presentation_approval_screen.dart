import 'package:flutter/material.dart';
import 'package:new_project/main_screen.dart';
import 'package:new_project/offline_auth_service.dart';
import 'package:new_project/storage_service.dart';
import '../models/presentation_request.dart';
import '../models/verifiable_presentation.dart';
import '../models/credential.dart';
import 'api_service.dart';

class PresentationApprovalScreen extends StatefulWidget {
  final String sessionId;
  final String requestUrl;

  const PresentationApprovalScreen({
    super.key,
    required this.sessionId,
    required this.requestUrl,
  });

  @override
  State<PresentationApprovalScreen> createState() =>
      _PresentationApprovalScreenState();
}

class _PresentationApprovalScreenState
    extends State<PresentationApprovalScreen> {
  PresentationRequestDto? _presentationRequest;
  IdentityCredential? _userCredential;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, bool> _selectedAttributes = {};

  @override
  void initState() {
    super.initState();
    _loadPresentationRequest();
  }

  Future<void> _loadPresentationRequest() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Fetch presentation request using ApiService
      final requestResponse = await ApiService.getPresentationRequest(
        widget.sessionId,
      );

      if (!requestResponse.success || requestResponse.data == null) {
        setState(() {
          _errorMessage = requestResponse.message ?? 'Failed to load request';
          _isLoading = false;
        });
        return;
      }

      _presentationRequest = requestResponse.data!;

      final data = await OfflineAuthService.getLocalUserData();
      final userData = OfflineAuthService.extractUserDataFromCredentials(data!);

      _userCredential = _createIdentityCredential(userData);

      if (_userCredential == null) {
        setState(() {
          _errorMessage = 'Identity credential not found';
          _isLoading = false;
        });
        return;
      }

      // Initialize all requested attributes as selected by default
      for (String attr in _presentationRequest!.requestedAttributes) {
        _selectedAttributes[attr] = true;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load request: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPresentation() async {
    if (_userCredential == null || _presentationRequest == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Get only selected attributes
      final selectedAttrs = _selectedAttributes.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (selectedAttrs.isEmpty) {
        setState(() {
          _errorMessage = 'Please select at least one attribute to share';
          _isSubmitting = false;
        });
        return;
      }

      // Show password dialog
      final password = await _showPasswordDialog();

      if (password == null) {
        setState(() {
          _isSubmitting = false;
        });
        return; // User cancelled
      }

      if (password.isEmpty) {
        setState(() {
          _errorMessage = 'Password cannot be empty';
          _isSubmitting = false;
        });
        return;
      }

      // Build attributes map from credential subject
      final attributes = _userCredential!.credentialSubject.toAttributesMap(
        selectedAttrs,
      );

      // Generate proof using ApiService
      final proof = await ApiService.generatePresentationProof(
        _userCredential!.did,
        password,
        widget.sessionId,
        attributes,
      );

      // Create verifiable presentation
      final vpDto = VerifiablePresentationDto(
        holder: _userCredential!.did,
        credentialId: _userCredential!.id,
        attributes: attributes,
        proof: proof,
      );

      // Submit to backend using ApiService
      final response = await ApiService.submitVerifiablePresentation(
        widget.sessionId,
        vpDto,
      );

      if (response.success) {
        _showSuccessDialog();
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Submission failed';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit: ${e.toString()}';
        _isSubmitting = false;
      });
    }
  }

  // Create IdentityCredential from stored user data
  IdentityCredential? _createIdentityCredential(Map<String, dynamic> userData) {
    try {
      print('[createIdentityCredential] Creating credential from user data');

      final did = userData['id']?.toString() ?? '';
      if (did.isEmpty) {
        print('[createIdentityCredential] ❌ No DID found in user data');
        return null;
      }

      // Parse address from user data if available
      final address = AddressDto(
        street:
            userData['address.street']?.toString() ??
            userData['addressStreet']?.toString() ??
            'Unknown Street',
        city:
            userData['address.city']?.toString() ??
            userData['addressCity']?.toString() ??
            'Unknown City',
        district:
            userData['address.district']?.toString() ??
            userData['addressDistrict']?.toString() ??
            'Unknown District',
        postalCode:
            userData['address.postalCode']?.toString() ??
            userData['addressPostalCode']?.toString() ??
            '00000',
        divisionalSecretariat:
            userData['address.divisionalSecretariat']?.toString() ??
            userData['addressDivisionalSecretariat']?.toString() ??
            'Unknown Divisional Secretariat',
        gramaNiladhariDivision:
            userData['address.gramaNiladhariDivision']?.toString() ??
            userData['addressGramaNiladhariDivision']?.toString() ??
            'Unknown Grama Niladhari Division',
        province:
            userData['address.province']?.toString() ??
            userData['addressProvince']?.toString() ??
            'Unknown Province',
      );

      // Create credential subject from user data
      final credentialSubject = CredentialSubject(
        id: did,
        fullName: userData['fullName']?.toString() ?? 'Unknown User',
        nic: userData['nic']?.toString() ?? did,
        age: _calculateAge(userData['dateOfBirth']?.toString()),
        dateOfBirth: userData['dateOfBirth']?.toString() ?? '1990-01-01',
        profilePhotoHash:
            userData['photoUrl']?.toString() ??
            userData['profilePhotoHash']?.toString(),
        citizenship: userData['citizenship']?.toString() ?? 'Sri Lankan',
        gender: userData['gender']?.toString() ?? 'Not specified',
        nationality: userData['nationality']?.toString() ?? 'Sri Lankan',
        bloodGroup: userData['bloodGroup']?.toString() ?? 'O+',
        address: address,
      );

      final idNumber = did.split(':').last;

      // Create the identity credential
      final identityCredential = IdentityCredential(
        id: 'credential:identity:$idNumber',
        credentialType: 'IdentityCredential',
        did: did,
        credentialSubject: credentialSubject,
      );

      print(
        '[createIdentityCredential] ✅ Identity credential created for DID: $did',
      );
      print(
        '[createIdentityCredential] Credential subject: $credentialSubject',
      );

      return identityCredential;
    } catch (e, st) {
      print(
        '[createIdentityCredential] ❌ Error creating identity credential: $e',
      );
      print(st);
      return null;
    }
  }

  /// Helper function to calculate age from date of birth
  int _calculateAge(String? dateOfBirth) {
    try {
      if (dateOfBirth == null || dateOfBirth.isEmpty) return 0;

      final birthDate = DateTime.parse(dateOfBirth);
      final currentDate = DateTime.now();

      int age = currentDate.year - birthDate.year;

      // Adjust age if birthday hasn't occurred this year
      if (currentDate.month < birthDate.month ||
          (currentDate.month == birthDate.month &&
              currentDate.day < birthDate.day)) {
        age--;
      }

      return age;
    } catch (e) {
      print('[calculateAge] Error calculating age: $e');
      return 0;
    }
  }

  Future<String?> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Your Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your password to sign the presentation.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.isNotEmpty) {
                  Navigator.pop(context, passwordController.text);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          title: const Text('Success'),
          content: const Text(
            'Your information has been shared successfully. The officer can now proceed with issuing your driving license.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog

                _navigateToMainScreen();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToMainScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  String _getAttributeDisplayName(String attribute) {
    final displayNames = {
      'fullName': 'Full Name',
      'full_name': 'Full Name',
      'dateOfBirth': 'Date of Birth',
      'dob': 'Date of Birth',
      'age': 'Age',
      'address': 'Address',
      'bloodGroup': 'Blood Group',
      'blood_group': 'Blood Group',
      'id': 'Digital Identity',
      'nic': 'NIC Number',
      'profilePhoto': 'Profile Photo',
      'profile_photo': 'Profile Photo',
    };
    return displayNames[attribute] ?? attribute;
  }

  String _getAttributeValue(String attribute) {
    if (_userCredential == null) return '';

    final subject = _userCredential!.credentialSubject;

    switch (attribute) {
      case 'fullName':
      case 'full_name':
        return subject.fullName;
      case 'dateOfBirth':
      case 'dob':
        return subject.dateOfBirth;
      case 'age':
        return subject.age.toString();
      case 'address':
        return subject.address.toString();
      case 'bloodGroup':
      case 'blood_group':
        return subject.bloodGroup;
      case 'id':
        return subject.id;
      case 'nic':
        return subject.nic;
      case 'profilePhoto':
      case 'profile_photo':
        return subject.profilePhotoHash ?? 'Not available';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Your Information'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : _buildApprovalView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _presentationRequest!.requesterName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Purpose: ${_presentationRequest!.purpose}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expires: ${_formatDateTime(_presentationRequest!.expiresAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Information section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select information to share:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The organization is requesting the following information. You can choose what to share.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attribute list
                      ..._presentationRequest!.requestedAttributes
                          .map((attribute) => _buildAttributeCard(attribute))
                          .toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPresentation,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Share Information'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttributeCard(String attribute) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: CheckboxListTile(
        value: _selectedAttributes[attribute] ?? false,
        onChanged: (bool? value) {
          setState(() {
            _selectedAttributes[attribute] = value ?? false;
          });
        },
        title: Text(
          _getAttributeDisplayName(attribute),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _getAttributeValue(attribute),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
