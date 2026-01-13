import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/main.dart';
import 'package:new_project/theme/app_theme.dart';
import 'package:new_project/providers/theme_provider.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import '../services/api_service.dart';
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
  String? _userName = 'User';

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

      final walletStatus = await ApiService.getWalletStatus();
      
      if (walletStatus['success'] == true) {
        final walletData = walletStatus['data'];
        if (walletData != null) {
          final credentials = walletData['walletVerifiableCredentials'] ?? [];
          if (credentials.isNotEmpty) {
            final credential = credentials[0];
            final credentialSubject = credential['credentialSubject'] ?? {};
            
            final fullName = credentialSubject['fullName'];
            if (fullName != null) {
              setState(() {
                _userName = fullName;
              });
            }
            
            final profilePhotoHash = credentialSubject['profilePhotoHash'];
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
      }
    } catch (e) {
      print('Error loading profile photo: $e');
    }
  }

  Widget _buildProfileImage(bool isDarkMode) {
    if (_isLoading) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      );
    }

    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      try {
        String imageData = _profileImageBase64!;
        if (imageData.contains(',')) {
          imageData = imageData.split(',').last;
        }

        return Container(
          width: 100,
          height: 100,
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
            image: DecorationImage(
              image: MemoryImage(base64Decode(imageData)),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (e) {
        return _buildDefaultAvatar();
      }
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.3),
            AppTheme.primaryColor.withOpacity(0.1),
          ],
        ),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        size: 50,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _signOut(BuildContext context, bool isDarkMode) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(isDarkMode),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: AppTheme.getTextPrimary(isDarkMode),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppTheme.getTextSecondary(isDarkMode)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(isDarkMode)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final textColor = AppTheme.getTextPrimary(isDarkMode);
        final secondaryTextColor = AppTheme.getTextSecondary(isDarkMode);
        
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: AppTheme.getGradient(isDarkMode),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Profile Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.getCardDecoration(isDarkMode),
                        child: Column(
                          children: [
                            // Profile Image
                            Stack(
                              children: [
                                _buildProfileImage(isDarkMode),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _loadProfileData,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.getSurfaceColor(isDarkMode),
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // User Name
                            Text(
                              _userName ?? 'User',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Verified badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 16, color: Colors.green),
                                  SizedBox(width: 6),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Profile Options
                      Container(
                        decoration: AppTheme.getCardDecoration(isDarkMode, borderRadius: 20),
                        child: Column(
                          children: [
                            _buildProfileOption(context, Icons.edit_rounded, 'Edit Profile', isDarkMode),
                            _buildDivider(isDarkMode),
                            _buildNotificationOption(context, isDarkMode),
                            _buildDivider(isDarkMode),
                            _buildThemeOption(context, themeProvider, isDarkMode),
                            _buildDivider(isDarkMode),
                            _buildProfileOption(context, Icons.description_rounded, 'Documents', isDarkMode),
                            _buildDivider(isDarkMode),
                            _buildProfileOption(context, Icons.lock_rounded, 'Change Password', isDarkMode),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Sign Out Button
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _signOut(context, isDarkMode),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign Out'),
                            style: isDarkMode 
                              ? AppTheme.outlineButtonStyle.copyWith(
                                  foregroundColor: const MaterialStatePropertyAll(Colors.red),
                                  side: MaterialStatePropertyAll(BorderSide(color: Colors.red.withOpacity(0.5), width: 2)),
                                )
                              : AppTheme.lightOutlineButtonStyle.copyWith(
                                  foregroundColor: const MaterialStatePropertyAll(Colors.red),
                                  side: MaterialStatePropertyAll(BorderSide(color: Colors.red.withOpacity(0.5), width: 2)),
                                ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // App version
                      Center(
                        child: Text(
                          'SLUDI v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor.withOpacity(0.4),
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
      },
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
      indent: 20,
      endIndent: 20,
    );
  }

  Widget _buildProfileOption(BuildContext context, IconData icon, String title, bool isDarkMode) {
    final textColor = AppTheme.getTextPrimary(isDarkMode);
    final iconColor = AppTheme.getTextSecondary(isDarkMode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          switch (title) {
            case 'Edit Profile':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditWalletScreen()),
              );
              break;
            case 'Documents':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Documents screen coming soon!'),
                  backgroundColor: AppTheme.getSurfaceColor(isDarkMode),
                  duration: const Duration(seconds: 1),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
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
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationOption(BuildContext context, bool isDarkMode) {
    final textColor = AppTheme.getTextPrimary(isDarkMode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_rounded, size: 22, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Switch(
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
            activeColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, ThemeProvider themeProvider, bool isDarkMode) {
    final textColor = AppTheme.getTextPrimary(isDarkMode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, 
              size: 22, 
              color: AppTheme.primaryColor
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Dark Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Switch(
            value: themeProvider.isDarkMode,
            onChanged: (bool value) {
              themeProvider.toggleTheme();
            },
            activeColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}