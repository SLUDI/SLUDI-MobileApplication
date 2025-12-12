import 'package:flutter/material.dart';
import 'package:new_project/main.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'main.dart'; // Make sure to import your WelcomeScreen
import 'api_service.dart';
import 'dart:convert';

class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen> {
  bool _notificationsEnabled = true;
  String? _profileImageBase64;
  bool _isLoading = false;
  String? _userName = 'Rowan Darmasana';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get wallet status to extract profile photo hash
      final walletStatus = await ApiService.getWalletStatus();
      
      if (walletStatus['success'] == true) {
        final walletData = walletStatus['data'];
        if (walletData != null) {
          // Extract credentials and find profile photo hash
          final credentials = walletData['walletVerifiableCredentials'] ?? [];
          if (credentials.isNotEmpty) {
            final credential = credentials[0]; // Get first credential
            final credentialSubject = credential['credentialSubject'] ?? {};
            
            // Update user name from credential data
            final fullName = credentialSubject['fullName'];
            if (fullName != null) {
              setState(() {
                _userName = fullName;
              });
            }
            
            // Get profile photo hash
            final profilePhotoHash = credentialSubject['profilePhotoHash'];
            print('📸 Profile Photo Hash: $profilePhotoHash');
            
            if (profilePhotoHash != null && profilePhotoHash is String) {
              await _loadProfilePhoto(profilePhotoHash);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading profile data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfilePhoto(String cid) async {
    try {
      final response = await ApiService.getProfilePhoto(cid);
      
      if (response.success && response.data != null) {
        setState(() {
          _profileImageBase64 = response.data;
        });
        print('✅ Profile photo loaded successfully');
      } else {
        print('❌ Failed to load profile photo: ${response.message}');
      }
    } catch (e) {
      print('Error loading profile photo: $e');
    }
  }

  Widget _buildProfileImage() {
    if (_isLoading) {
      return const CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      try {
        // Handle base64 image data (remove data:image/... prefix if present)
        String imageData = _profileImageBase64!;
        if (imageData.contains(',')) {
          imageData = imageData.split(',').last;
        }

        return CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: MemoryImage(
            base64Decode(imageData),
          ),
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return _buildDefaultAvatar();
      }
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.blue.shade100,
      child: const Icon(
        Icons.person,
        size: 30,
        color: Colors.blue,
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    // Show confirmation dialog
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      // Perform any cleanup here if needed
      // For example, clear tokens, clear local storage, etc.
      // await ApiService.signOut();
      // await clearLocalStorage();
      
      // Navigate to WelcomeScreen and remove all previous screens
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF), // White
              Color(0xFFD6E6F2), // Light blue
            ],
            stops: [0.1, 0.9],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image Section
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            _buildProfileImage(),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    // TODO: Implement photo upload
                                    _loadProfileData(); // Refresh for now
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // User Name
                        Text(
                          _userName!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        // Refresh button
                        // TextButton(
                        //   onPressed: _loadProfileData,
                        //   // child: const Text(
                        //   //   //'Refresh Profile',
                        //   //   //style: TextStyle(fontSize: 12),
                        //   // ),
                        // ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // Profile Options
                  _buildProfileOption(context, Icons.edit, 'Edit Profile'),
                  _buildNotificationOption(context),
                  _buildProfileOption(context, Icons.description, 'Documents'),
                  _buildProfileOption(context, Icons.lock, 'Change Password'),

                  const SizedBox(height: 40),

                  // Sign Out Button
                  Center(
                    child: TextButton(
                      onPressed: () {
                        _signOut(context);
                      },
                      child: const Text(
                        'Sign out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context, IconData icon, String title) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, size: 28, color: Colors.blue),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          switch (title) {
            case 'Edit Profile':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditWalletScreen()),
              );
              break;
            case 'Documents':
              // Navigate to documents screen
              // TODO: Implement documents screen navigation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Documents screen coming soon!'),
                  duration: Duration(seconds: 1),
                ),
              );
              break;
            case 'Change Password':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildNotificationOption(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.notifications, size: 28, color: Colors.blue),
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 18),
        ),
        trailing: Switch(
          value: _notificationsEnabled,
          onChanged: (bool value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
          activeColor: Colors.blue,
        ),
      ),
    );
  }
}