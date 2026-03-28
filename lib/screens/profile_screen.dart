import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/journey_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/shared_bottom_nav.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<TextEditingController> _contactControllers = [];
  final List<TextEditingController> _contactNameControllers =
      [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _primaryEmergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyEmailController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _notificationsEnabled = true;
  bool _locationSharing = true;


  int _refreshKey = 0;

  void _refreshProfile() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final profile = await authService.getProfile();

    if (profile != null) {

      _contactControllers.clear();
      _contactNameControllers.clear();

      _nameController.text = profile['full_name'] ?? '';
      _vehicleController.text = profile['vehicle_number'] ?? '';
      _emailController.text = profile['email'] ?? authService.currentUser ?? '';
      _bloodGroupController.text = profile['blood_group'] ?? '';
      _licenseController.text = profile['license_number'] ?? '';
      _primaryEmergencyNameController.text =
          profile['primary_emergency_name'] ?? '';
      _emergencyEmailController.text = profile['emergency_email'] ?? '';

      if (profile['emergency_contacts'] != null) {
        final contactsData = profile['emergency_contacts'];

        if (contactsData is List && contactsData.isNotEmpty) {
          for (var contact in contactsData) {
            String name = '';
            String number = '';

            if (contact is String) {
              number = contact;
              if (number.trim().startsWith('{') &&
                  number.trim().endsWith('}')) {
                try {
                  final jsonString = number.replaceAll("'", '"');
                  final Map<String, dynamic> parsed = jsonDecode(jsonString);
                  name = parsed['name'] ?? '';
                  number = parsed['number'] ?? parsed['phone'] ?? '';
                } catch (e) {}
              }
            } else if (contact is Map) {
              name = contact['name'] ?? '';
              number = contact['number'] ?? '';
            }

            if (name.isNotEmpty) {
              _contactNameControllers.add(TextEditingController(text: name));
              _contactControllers.add(TextEditingController(text: number));
            }
          }
        }
      }
    }


    try {
      final prefs = await SharedPreferences.getInstance();
      final homeName = prefs.getString('home_emergency_name') ?? '';
      final homeContact = prefs.getString('home_emergency_contact') ?? '';

      if (homeName.isNotEmpty && homeContact.isNotEmpty) {
        bool alreadyExists = false;
        for (int i = 0; i < _contactNameControllers.length; i++) {
          if (_contactNameControllers[i].text.trim().toLowerCase() ==
                  homeName.trim().toLowerCase() &&
              _contactControllers[i].text.trim() == homeContact.trim()) {
            alreadyExists = true;
            break;
          }
        }

        if (!alreadyExists) {
          _contactNameControllers.add(TextEditingController(text: homeName));
          _contactControllers.add(TextEditingController(text: homeContact));
        }
      }
    } catch (e) {
      debugPrint('Error syncing initial home contact: $e');
    }

    setState(() => _isLoading = false);
  }

  void _addContactField() {
    setState(() {
      _contactControllers.add(TextEditingController());
      _contactNameControllers.add(TextEditingController());
    });
  }

  void _removeContactField(int index) async {
    final nameToRemove = _contactNameControllers[index].text.trim();
    final numberToRemove = _contactControllers[index].text.trim();

    setState(() {
      _contactControllers[index].dispose();
      _contactNameControllers[index].dispose();
      _contactControllers.removeAt(index);
      _contactNameControllers.removeAt(index);
    });


    try {
      final prefs = await SharedPreferences.getInstance();
      final hName = prefs.getString('home_emergency_name') ?? '';
      final hNum = prefs.getString('home_emergency_contact') ?? '';

      if (hName.isNotEmpty &&
          hName.toLowerCase() == nameToRemove.toLowerCase() &&
          hNum == numberToRemove) {
        await prefs.remove('home_emergency_name');
        await prefs.remove('home_emergency_contact');
      }
    } catch (e) {
      debugPrint('Error clearing home contact on delete: $e');
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final authService = Provider.of<AuthService>(context, listen: false);


    if (_isEditMode) {
      final profileSuccess = await authService.updateProfileExtended(
        fullName: _nameController.text.trim(),
        vehicleNumber: _vehicleController.text.trim(),
        bloodGroup: _bloodGroupController.text.trim(),
        licenseNumber: _licenseController.text.trim(),
        primaryEmergencyName: _primaryEmergencyNameController.text.trim(),
        emergencyEmail: _emergencyEmailController.text.trim(),
      );

      if (!profileSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile details'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
    }


    final List<Map<String, String>> contacts = [];

    for (int i = 0; i < _contactControllers.length; i++) {
      final number = _contactControllers[i].text.trim();
      final name = _contactNameControllers[i].text.trim();

      if (number.isNotEmpty) {
        contacts.add({
          'name': name.isNotEmpty ? name : 'Contact ${i + 1}',
          'number': number,
        });
      }
    }

    final contactsSuccess = await authService.updateEmergencyContacts(contacts);

    setState(() {
      _isSaving = false;
      _isEditMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            contactsSuccess ? 'Profile updated successfully' : 'Update failed',
          ),
          backgroundColor: contactsSuccess ? Colors.green : Colors.redAccent,
        ),
      );

      _refreshProfile();
    }
  }

  Future<void> _pickAndUploadImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Choose Photo Source',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: Text(
                'Camera',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: Text(
                'Gallery',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 100);

    if (image != null) {
      setState(() => _isSaving = true);
      final bytes = await image.readAsBytes();
      final authService = Provider.of<AuthService>(context, listen: false);
      final url = await authService.uploadProfilePicture(
        bytes,
        'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      setState(() => _isSaving = false);
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: Colors.green,
          ),
        );

        _refreshProfile();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Photo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove your profile photo?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.deleteProfilePicture();
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Photo removed' : 'Failed to remove photo'),
            backgroundColor: success ? Colors.green : Colors.redAccent,
          ),
        );
        if (success) {

          _refreshProfile();
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _contactControllers) {
      controller.dispose();
    }
    for (var controller in _contactNameControllers) {
      controller.dispose();
    }
    _nameController.dispose();
    _vehicleController.dispose();
    _emailController.dispose();
    _bloodGroupController.dispose();
    _licenseController.dispose();
    _primaryEmergencyNameController.dispose();
    _emergencyEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                setState(() => _isLoading = true);
                await _fetchProfile();
                setState(() {
                  _isEditMode = true;
                  _isLoading = false;
                });
              },
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      bottomNavigationBar: const SharedBottomNav(currentRoute: '/profile'),
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : FutureBuilder<Map<String, dynamic>?>(
                  key: ValueKey(_refreshKey),
                  future: authService.getProfile(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final photoUrl = profile?['photo_url'];

                    return RefreshIndicator(
                      onRefresh: () async {
                        _refreshProfile();
                      },
                      backgroundColor: const Color(0xFF1E293B),
                      color: AppTheme.accentYellow,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.accentYellow.withOpacity(
                                            0.3,
                                          ),
                                          AppTheme.primaryOrange.withOpacity(
                                            0.3,
                                          ),
                                        ],
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: const Color(0xFF1E293B),
                                      backgroundImage: photoUrl != null
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: photoUrl == null
                                          ? const Icon(
                                              Icons.person,
                                              size: 70,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: _pickAndUploadImage,
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.primaryOrange,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 20,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (photoUrl != null) ...[
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: _removeProfilePhoto,
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: const BoxDecoration(
                                                color: Colors.redAccent,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    profile?['full_name'] ?? 'Not filled',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile?['email'] ??
                                        authService.currentUser ??
                                        '',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),


                            _buildSafetyScoreCard(profile),

                            const SizedBox(height: 24),


                            _buildSOSReportsCard(
                              authService,
                              Provider.of<JourneyService>(context),
                            ),

                            const SizedBox(height: 24),


                            _buildTrackingRequestsCard(authService),

                            const SizedBox(height: 24),


                            _buildProfileDetailsCard(authService, profile),

                            const SizedBox(height: 24),


                            _buildAccountStatsCard(authService),

                            const SizedBox(height: 24),


                            Text(
                              'EMERGENCY CONTACTS',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _contactControllers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  _contactNameControllers[index],
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge?.color,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Contact Name',
                                                hintText: 'e.g. Mom',
                                                filled: true,
                                                fillColor: Theme.of(context)
                                                    .inputDecorationTheme
                                                    .fillColor,
                                                prefixIcon: Icon(
                                                  Icons.person_outline,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_isEditMode)
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                              onPressed: () =>
                                                  _removeContactField(index),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller:
                                            _contactControllers[index],
                                        keyboardType: TextInputType.phone,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Phone Number',
                                          hintText: '+91 9876543210',
                                          filled: true,
                                          fillColor: Theme.of(
                                            context,
                                          ).inputDecorationTheme.fillColor,
                                          prefixIcon: Icon(
                                            Icons.phone,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _addContactField,
                              icon: Icon(
                                Icons.add_circle,
                                color: Theme.of(context).primaryColor,
                              ),
                              label: Text(
                                'Add Emergency Contact',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),


                            _buildSettingsCard(),

                            const SizedBox(height: 24),


                            _buildSecurityCard(),

                            const SizedBox(height: 32),


                            Center(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      title: const Text(
                                        'Logout',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        'Are you sure you want to logout?',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text(
                                            'CANCEL',
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'LOGOUT',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await authService.logout();
                                    if (mounted) {
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        '/login',
                                        (route) => false,
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(
                                  Icons.logout,
                                  color: Colors.redAccent,
                                ),
                                label: const Text(
                                  'LOGOUT',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 48),


                            if (_isEditMode) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () {
                                              setState(() {
                                                _isEditMode = false;
                                                _fetchProfile();
                                              });
                                            },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.white54,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: const Text(
                                        'CANCEL',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryOrange,
                                        foregroundColor:
                                            Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.black,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'SAVE',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryOrange,
                                    foregroundColor:
                                        Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Text(
                                          'SAVE CHANGES',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailsCard(
    AuthService authService,
    Map<String, dynamic>? profile,
  ) {
    final fullName = profile?['full_name'] ?? 'Not filled';
    final email = profile?['email'] ?? authService.currentUser ?? 'Not filled';
    final vehicleNumber = profile?['vehicle_number'] ?? 'Not filled';
    final faceVerified = profile?['face_verified'] ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROFILE DETAILS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: faceVerified
                      ? AppTheme.successGreen.withOpacity(0.2)
                      : Colors.orangeAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      faceVerified ? Icons.verified_user : Icons.pending,
                      size: 16,
                      color: faceVerified
                          ? AppTheme.successGreen
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      faceVerified ? 'VERIFIED' : 'PENDING',
                      style: TextStyle(
                        color: faceVerified
                            ? AppTheme.successGreen
                            : Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isEditMode) ...[
            _buildEditableField(Icons.person, 'Full Name', _nameController),
            const SizedBox(height: 12),
            _buildEditableField(
              Icons.email,
              'Email',
              _emailController,
              enabled: false,
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              Icons.directions_bike,
              'Vehicle Number',
              _vehicleController,
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              Icons.bloodtype,
              'Blood Group',
              _bloodGroupController,
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              Icons.badge,
              'License Number',
              _licenseController,
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              Icons.contact_emergency,
              'Emergency Contact Person',
              _primaryEmergencyNameController,
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              Icons.contact_mail,
              'Emergency Email',
              _emergencyEmailController,
            ),
          ] else ...[
            _buildDetailRow(Icons.person, 'Full Name', fullName),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.email, 'Email', email),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.directions_bike,
              'Vehicle Number',
              vehicleNumber,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.bloodtype,
              'Blood Group',
              profile?['blood_group'] ?? 'Not filled',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.badge,
              'License Number',
              profile?['license_number'] ?? 'Not filled',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.contact_emergency,
              'Primary Emergency Number',
              profile?['primary_emergency_name'] ?? 'Not filled',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.contact_mail,
              'Emergency Email',
              profile?['emergency_email'] ?? 'Not filled',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountStatsCard(AuthService authService) {
    return FutureBuilder<Map<String, dynamic>>(
      future: authService.getAccountStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final createdAt = stats['created_at'];
        final faceVerified = stats['face_verified'] ?? false;
        final emailVerified = stats['email_verified'] ?? false;
        final lastSignIn = stats['last_sign_in'];

        String formatDate(dynamic date) {
          if (date == null) return 'N/A';
          try {
            final parsedDate = date is DateTime
                ? date
                : DateTime.parse(date.toString());
            return DateFormat('MMM dd, yyyy').format(parsedDate);
          } catch (e) {
            return 'N/A';
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACCOUNT STATISTICS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                Icons.calendar_today,
                'Member Since',
                formatDate(createdAt),
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                Icons.login,
                'Last Sign In',
                formatDate(lastSignIn),
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                Icons.email_outlined,
                'Email Status',
                emailVerified ? 'Verified' : 'Not Verified',
                valueColor: emailVerified
                    ? AppTheme.successGreen
                    : Colors.orangeAccent,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                Icons.face,
                'Face Verification',
                faceVerified ? 'Completed' : 'Pending',
                valueColor: faceVerified
                    ? AppTheme.successGreen
                    : Colors.orangeAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SETTINGS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingToggle(
            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            'Dark Mode',
            'Switch between light and dark theme',
            themeProvider.isDarkMode,
            (value) => themeProvider.toggleTheme(),
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildSettingToggle(
            Icons.notifications_active,
            'Push Notifications',
            'Receive alerts for emergencies',
            _notificationsEnabled,
            (value) => setState(() => _notificationsEnabled = value),
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildSettingToggle(
            Icons.location_on,
            'Location Sharing',
            'Share location during journeys',
            _locationSharing,
            (value) => setState(() => _locationSharing = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyScoreCard(Map<String, dynamic>? profile) {
    final rides = profile?['total_rides'] ?? 0;
    final points = profile?['total_points'] ?? 0;
    final rank = profile?['rank'] ?? 'Rookie';
    final score = (profile?['safety_score'] ?? 0.0).toDouble();
    final scorePercent = (score / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withOpacity(0.2),
            AppTheme.accentYellow.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SAFETY SCORE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(Icons.stars, color: AppTheme.accentYellow),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSafetyStat('Rides', '$rides', Icons.directions_bike),
              _buildSafetyStat(
                'Points',
                NumberFormat('#,###').format(points),
                Icons.emoji_events,
              ),
              _buildSafetyStat('Rank', rank, Icons.trending_up),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: scorePercent,
              backgroundColor: Colors.white10,
              color: score >= 80
                  ? AppTheme.successGreen
                  : score >= 50
                  ? AppTheme.accentYellow
                  : Colors.redAccent,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${score.toStringAsFixed(0)}% Safe Riding Streak',
            style: TextStyle(
              color: score >= 80
                  ? AppTheme.successGreen
                  : score >= 50
                  ? AppTheme.accentYellow
                  : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSReportsCard(
    AuthService authService,
    JourneyService journeyService,
  ) {
    final userId = authService.user?.id;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: journeyService.fetchMySOS(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final reports = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MY SOS REPORTS',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reports.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 24),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final reportId = report['id'].toString();
                  final address = report['address'] ?? 'Unknown Location';
                  final createdAt = report['created_at'].toString();

                  String timeStr = 'Time Unknown';
                  try {
                    final dt = DateTime.parse(createdAt).toLocal();
                    timeStr = DateFormat('MMM dd, HH:mm').format(dt);
                  } catch (e) {}

                  return Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            if (report['incident_type'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "Reported: ${report['incident_type']}",
                                  style: const TextStyle(
                                    color: AppTheme.accentYellow,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.open_in_new_rounded,
                            color: AppTheme.primaryOrange,
                            size: 18,
                          ),
                        ),
                        onPressed: () => _showIncidentReportDialog(
                          journeyService,
                          reportId,
                          initialType: report['incident_type'],
                          initialDesc: report['incident_description'],
                        ),
                        tooltip: 'View/Report Details',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.white38,
                          size: 20,
                        ),
                        onPressed: () =>
                            _handleDeleteSOS(journeyService, reportId),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showIncidentReportDialog(
    JourneyService journeyService,
    String sosId, {
    String? initialType,
    String? initialDesc,
  }) async {
    final typeController = TextEditingController(text: initialType);
    final descController = TextEditingController(text: initialDesc);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Incident Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Help others by describing what happened.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildEditableField(
                Icons.help_outline,
                'What happened?',
                typeController,
              ),
              const SizedBox(height: 12),
              _buildEditableField(
                Icons.description_outlined,
                'How did it happen?',
                descController,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await journeyService.updateSOSDetails(
                sosId,
                typeController.text.trim(),
                descController.text.trim(),
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Details updated' : 'Update failed',
                    ),
                    backgroundColor: success ? Colors.green : Colors.redAccent,
                  ),
                );
                _refreshProfile();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.black,
            ),
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteSOS(
    JourneyService journeyService,
    String sosId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Remove Report?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove the SOS marker from everyone\'s map. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'REMOVE',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await journeyService.deleteSOS(sosId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS Report removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove report'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Widget _buildSafetyStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final bool isNotFilled = value.toLowerCase() == 'not filled';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accentYellow),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(
                  color: isNotFilled ? Colors.white38 : Colors.white,
                  fontSize: 16,
                  fontWeight: isNotFilled ? FontWeight.normal : FontWeight.w500,
                  fontStyle: isNotFilled ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.accentYellow),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          labelStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accentYellow),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingToggle(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppTheme.accentYellow),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      value: value,
      activeThumbColor: AppTheme.accentYellow,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SECURITY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            Icons.lock_reset,
            'Change Password',
            _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentYellow, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Change Password',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  oldPasswordController,
                  'Old Password',
                  true,
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  newPasswordController,
                  'New Password',
                  true,
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  confirmPasswordController,
                  'Confirm New Password',
                  true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.black,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newPasswordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        final authService = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        await authService.updateUserPassword(
                          newPasswordController.text,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('UPDATE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    bool obscure,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildTrackingRequestsCard(AuthService authService) {
    if (authService.currentProfile?['role'] == 'tracker') {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: authService.getIncomingTrackingRequests(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.accentYellow.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentYellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: AppTheme.accentYellow,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'TRACKING REQUESTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 24),
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final trackerName = req['tracker_name'] ??
                      req['trackers']?['full_name'] ??
                      'Unknown Tracker';
                  final requestId = req['id'];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$trackerName wants to track your safety status.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _showApproveTrackingDialog(
                                authService,
                                requestId,
                                trackerName,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentYellow,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('APPROVE'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {

                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white54,
                                side: const BorderSide(color: Colors.white10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('IGNORE'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showApproveTrackingDialog(
    AuthService authService,
    String requestId,
    String trackerName,
  ) {
    final codeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Approve $trackerName',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the 6-digit code sent to your email to approve this tracking request.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  prefixIcon: const Icon(Icons.security, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 8,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (codeController.text.length != 6) return;
                      setState(() => isLoading = true);
                      final success = await authService.approveTrackingRequest(
                        requestId,
                        codeController.text,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tracking approved successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _refreshProfile();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid code. Please try again.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentYellow,
                foregroundColor: Colors.black,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('APPROVE'),
            ),
          ],
        ),
      ),
    );
  }
}
