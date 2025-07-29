import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:icons_plus/icons_plus.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the controller with the user's name when the screen loads
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser != null) {
      _nameController.text = userProvider.currentUser!.name;
    }
  }

    Future<void> _saveProfile() async {
    HapticFeedback.mediumImpact();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await userProvider.updateUserProfile(currentUser.uid, name: newName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (!mounted) return;
    setState(() {
      _isUploading = true;
    });

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (image == null) {
        setState(() => _isUploading = false);
        return;
      }

      final imageFile = File(image.path);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.currentUser!.id;

      // Save to GetStorage
      final box = GetStorage();
      await box.write('profile_image_path_$userId', imageFile.path);

      // Update Firestore
      await userProvider.updateUserProfile(userId, imageUrl: imageFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final userModel = userProvider.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              Semantics(
                label: _isEditing ? 'Save changes' : 'Edit profile',
                child: IconButton(
                  icon: _isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: colorScheme.onPrimary),
                          ),
                        )
                      : Icon(_isEditing ? EvaIcons.checkmark_circle_2_outline : EvaIcons.edit_2_outline),
                  onPressed: _isLoading
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (_isEditing) {
                              _saveProfile();
                            } else {
                              _isEditing = true;
                              if (userModel != null) {
                                _nameController.text = userModel.name;
                              }
                            }
                          });
                        },
                  tooltip: _isEditing ? 'Save' : 'Edit',
                ),
              ),
            ],
          ),
          body: userModel == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Semantics(
                          label: 'Change profile picture',
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 70,
                                backgroundColor: colorScheme.secondary.withOpacity(0.2),
                                backgroundImage: userModel.photoUrl.isNotEmpty
                                    ? FileImage(File(userModel.photoUrl))
                                    : null,
                                child: userModel.photoUrl.isEmpty
                                    ? Icon(EvaIcons.person_outline, size: 70, color: colorScheme.primary)
                                    : null,
                              ),
                              if (_isUploading)
                                CircularProgressIndicator(color: colorScheme.primary)
                              else
                                Positioned(
                                  bottom: 0,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                                    ),
                                    child: const Icon(EvaIcons.camera_outline, color: Colors.white, size: 20),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              _isEditing
                                  ? TextFormField(
                                      controller: _nameController,
                                      textAlign: TextAlign.center,
                                      style: textTheme.headlineSmall,
                                      decoration: const InputDecoration(
                                        hintText: 'Your Name',
                                        border: InputBorder.none,
                                        focusedBorder: UnderlineInputBorder(),
                                        semanticCounterText: 'Enter your name',
                                      ),
                                    )
                                  : Text(userModel.name, style: textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              Text(userModel.email, style: textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
