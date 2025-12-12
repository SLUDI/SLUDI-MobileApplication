import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_project/app_theme.dart';
import 'dart:io';

class EditWalletScreen extends StatefulWidget {
  const EditWalletScreen({super.key});

  @override
  State<EditWalletScreen> createState() => _EditWalletScreenState();
}

class _EditWalletScreenState extends State<EditWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController(text: 'Rowan Darmasena');
  final TextEditingController _emailController = TextEditingController(text: 'rowan@example.com');
  final TextEditingController _phoneController = TextEditingController(text: '+94771234567');
  final TextEditingController _addressController = TextEditingController(text: '163, Colombo Road, Galle');
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
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
                  
                  // Title
                  const Center(
                    child: Text('Edit Profile', style: AppTheme.headingStyle),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Profile Picture
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
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
                              image: _profileImage != null
                                  ? DecorationImage(
                                      image: FileImage(_profileImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              gradient: _profileImage == null
                                  ? LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor.withOpacity(0.3),
                                        AppTheme.primaryColor.withOpacity(0.1),
                                      ],
                                    )
                                  : null,
                            ),
                            child: _profileImage == null
                                ? const Icon(Icons.person, size: 60, color: AppTheme.primaryColor)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.darkBg2, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Center(
                    child: Text(
                      'Tap to change photo',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Form Fields
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.glassDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildField('Full Name', _nameController, Icons.person_outline, 'Enter your name'),
                        const SizedBox(height: 20),
                        _buildField('Email', _emailController, Icons.email_outlined, 'Enter your email', isEmail: true),
                        const SizedBox(height: 20),
                        _buildField('Phone Number', _phoneController, Icons.phone_outlined, 'Enter phone number'),
                        const SizedBox(height: 20),
                        _buildField('Address', _addressController, Icons.location_on_outlined, 'Enter your address', maxLines: 2),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _isLoading = true);
                          await Future.delayed(const Duration(seconds: 1));
                          setState(() => _isLoading = false);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Profile updated successfully'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                      style: AppTheme.primaryButtonStyle,
                      child: _isLoading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded, size: 22),
                                SizedBox(width: 10),
                                Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
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

  Widget _buildField(String label, TextEditingController controller, IconData icon, String hint, {bool isEmail = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: maxLines,
          decoration: AppTheme.inputDecoration(hintText: hint, prefixIcon: icon),
          validator: (value) {
            if (value == null || value.isEmpty) return 'This field is required';
            if (isEmail && !value.contains('@')) return 'Please enter a valid email';
            return null;
          },
        ),
      ],
    );
  }
}