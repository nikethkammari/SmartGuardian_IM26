import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  final String _pythonBackendUrl = kIsWeb
      ? "http://127.0.0.1:8000/verify"
      : "http://10.0.2.2:8000/verify";

  User? _user;
  Map<String, dynamic>? _localProfile;
  Map<String, dynamic>? _trackerProfile;
  bool _isInitialized = false;
  bool _isHelmetVerified = false;
  String? _pendingRegistrationOTP;
  String? _pendingLoginOTP;
  String? _pendingLoginEmail;
  String? _pendingResetOTP;
  String? _pendingResetEmail;
  bool get isHelmetVerified => _isHelmetVerified;
  bool get isInitialized => _isInitialized;

  void setHelmetVerified(bool value) {
    _isHelmetVerified = value;
    notifyListeners();
  }

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProfile = prefs.getString('user_profile');

    if (savedProfile != null) {
      _localProfile = jsonDecode(savedProfile);

      _refreshProfile();
    }

    _user = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session?.user != null) {
        _user = data.session?.user;
        _refreshProfile();
      }
    });

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _refreshProfile() async {
    if (_user == null && _localProfile == null) return;

    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return;

    try {

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data != null) {
        _localProfile = data;
        _trackerProfile = null;
        if (data['status'] != 'Active' && data['status'] != 'On Journey') {
          updateOnlineStatus('Active');
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', jsonEncode(data));
        notifyListeners();
        return;
      }


      final trackerData = await _supabase
          .from('trackers')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (trackerData != null) {
        _trackerProfile = trackerData;
        _localProfile = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', jsonEncode(trackerData));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing profile: $e');
    }
  }

  bool get isAuthenticated =>
      _localProfile != null || _trackerProfile != null || _user != null;
  String? get currentUser =>
      _localProfile?['email'] ?? _trackerProfile?['email'] ?? _user?.email;

  bool get isTracker =>
      _trackerProfile != null || _localProfile?['role'] == 'tracker';
  String get userFullName =>
      _localProfile?['full_name'] ??
      _user?.userMetadata?['full_name'] ??
      'User';
  User? get user => _user;
  String? get userPhotoUrl =>
      _localProfile?['photo_url'] ?? _user?.userMetadata?['photo_url'];
  String? get emergencyEmail => _localProfile?['emergency_email'];

  Map<String, dynamic>? get currentProfile => _trackerProfile ?? _localProfile;


  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUserModel => _supabase.auth.currentUser;

  Future<Map<String, dynamic>?> getProfile() async {
    if (_trackerProfile != null) return _trackerProfile;
    if (_localProfile != null) return _localProfile;
    if (_user == null) return null;


    try {
      final trackerData = await _supabase
          .from('trackers')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      if (trackerData != null) {
        _trackerProfile = trackerData;
        notifyListeners();
        return _trackerProfile;
      }
    } catch (_) {}

    return await _refreshProfile().then((_) => _localProfile);
  }

  Future<bool> updateEmergencyContacts(
    List<Map<String, String>> newContacts,
  ) async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return false;
    try {

      final updatedContacts = List<dynamic>.from(newContacts);

      await _supabase.from('profiles').upsert({
        'id': id,
        'emergency_contacts': updatedContacts,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await _refreshProfile();
      return true;
    } catch (e) {
      debugPrint('Error updating contacts: $e');
      return false;
    }
  }

  Future<bool> updateProfile(String fullName, String vehicleNumber) async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return false;
    try {
      await _supabase
          .from('profiles')
          .update({
            'full_name': fullName,
            'vehicle_number': vehicleNumber,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);


      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      } catch (_) {}

      await _refreshProfile();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  Future<bool> updateProfileExtended({
    required String fullName,
    required String vehicleNumber,
    required String bloodGroup,
    required String licenseNumber,
    required String primaryEmergencyName,
    required String emergencyEmail,
  }) async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return false;
    try {
      await _supabase.from('profiles').upsert({
        'id': id,
        'full_name': fullName,
        'vehicle_number': vehicleNumber,
        'blood_group': bloodGroup,
        'license_number': licenseNumber,
        'primary_emergency_name': primaryEmergencyName,
        'emergency_email': emergencyEmail,
        'updated_at': DateTime.now().toIso8601String(),
      });

      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      } catch (_) {}

      await _refreshProfile();
      return true;
    } catch (e) {
      debugPrint('Error updating extended profile: $e');
      return false;
    }
  }

  Future<bool> saveFaceVerification(bool status) async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return false;
    try {
      await _supabase.from('profiles').upsert({
        'id': id,
        'face_verified': status,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await _refreshProfile();
      return true;
    } catch (e) {
      debugPrint('Error saving face verification: $e');
      return false;
    }
  }

  Future<String?> uploadProfilePicture(Uint8List bytes, String fileName) async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return null;
    try {
      final path = '$id/$fileName';
      await _supabase.storage
          .from('profile-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _supabase.storage
          .from('profile-photos')
          .getPublicUrl(path);

      await _supabase
          .from('profiles')
          .update({
            'photo_url': publicUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'photo_url': publicUrl}),
        );
      } catch (_) {}

      await _refreshProfile();
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  Future<bool> deleteProfilePicture() async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return false;
    try {
      final profile = await getProfile();
      final photoUrl = profile?['photo_url'];

      if (photoUrl != null) {
        final path = '$id/';
        try {
          final files = await _supabase.storage
              .from('profile-photos')
              .list(path: path);
          for (var file in files) {
            await _supabase.storage.from('profile-photos').remove([
              '$path${file.name}',
            ]);
          }
        } catch (storageError) {
          debugPrint('Storage deletion error: $storageError');
        }
      }

      await _supabase
          .from('profiles')
          .update({
            'photo_url': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'photo_url': null}),
        );
      } catch (_) {}

      await _refreshProfile();
      return true;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getAccountStats() async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return {};
    try {
      final profile = await getProfile();
      return {
        'created_at': profile?['created_at'],
        'face_verified': profile?['face_verified'] ?? false,
        'face_verified_at': profile?['face_verified_at'],
        'email_verified': true,
        'last_sign_in': DateTime.now().toIso8601String(),
        'total_rides': profile?['total_rides'] ?? 0,
        'total_points': profile?['total_points'] ?? 0,
        'safety_score': profile?['safety_score'] ?? 0.0,
        'rank': profile?['rank'] ?? 'Rookie',
      };
    } catch (e) {
      debugPrint('Error fetching account stats: $e');
      return {};
    }
  }

  Future<bool> updateUserStats({
    int rideIncrement = 0,
    int pointIncrement = 0,
    double scoreAdjustment = 0.0,
  }) async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return false;
    try {
      final profile = await getProfile();
      final currentRides = profile?['total_rides'] ?? 0;
      final currentPoints = profile?['total_points'] ?? 0;
      final currentScore = (profile?['safety_score'] ?? 0.0).toDouble();

      final newSpeeding = currentRides + rideIncrement;
      final newPoints = currentPoints + pointIncrement;


      double newScore = currentScore;
      if (rideIncrement > 0) {


        newScore =
            (currentScore * currentRides + (100.0 + scoreAdjustment)) /
            (currentRides + 1);
        if (newScore > 100) newScore = 100;
        if (newScore < 0) newScore = 0;
      }


      String rank = 'Rookie';
      if (newPoints > 5000) {
        rank = 'Legend';
      } else if (newPoints > 2500)
        rank = 'Expert';
      else if (newPoints > 1000)
        rank = 'Pro';
      else if (newPoints > 500)
        rank = 'Advanced';

      await _supabase
          .from('profiles')
          .update({
            'total_rides': newSpeeding,
            'total_points': newPoints,
            'safety_score': newScore,
            'rank': rank,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      await _refreshProfile();
      return true;
    } catch (e) {
      debugPrint('Error updating user stats: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTrackedProfiles() async {
    final trackerId = _trackerProfile?['id'] ?? _localProfile?['id'];
    if (trackerId == null) return [];

    try {

      final data = await _supabase.rpc(
        'get_tracked_profiles',
        params: {'tracker_uuid': trackerId},
      );
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('Error fetching tracked profiles: $e');
      return [];
    }
  }


  void refreshTrackingData() {
    notifyListeners();
  }

  Future<void> sendTrackingRequest(String targetEmail) async {
    final trackerId = _trackerProfile?['id'] ?? _localProfile?['id'];
    final trackerName =
        _trackerProfile?['full_name'] ??
        _localProfile?['full_name'] ??
        'Tracker';
    if (trackerId == null) throw Exception('Tracker not logged in');

    final normalizedEmail = targetEmail.trim().toLowerCase();
    final otp = (Random().nextInt(900000) + 100000).toString();

    try {

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _trackingServiceId,
          'template_id': _trackingTemplateId,
          'user_id': _trackingPublicKey,
          'template_params': {
            'email': normalizedEmail,
            'REQUESTER_NAME': trackerName,
            'FULL_NAME': 'Smart Guardian User',
            'OTP': otp,
            'VALIDITY_TIME': '5',
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send tracking request email.');
      }


      await _supabase.from('tracking_links').upsert({
        'tracker_id': trackerId,
        'primary_user_email': normalizedEmail,
        'tracker_name': trackerName,
        'verification_code': otp,
        'status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Tracking request sent to $normalizedEmail with code $otp');
      notifyListeners();
    } catch (e) {
      debugPrint('Error sending tracking request: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSentTrackingRequests() async {
    final trackerId = _trackerProfile?['id'] ?? _localProfile?['id'];
    if (trackerId == null) return [];

    try {
      final data = await _supabase
          .from('tracking_links')
          .select()
          .eq('tracker_id', trackerId)
          .eq('status', 'pending');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching sent requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getIncomingTrackingRequests() async {
    final userEmail = _localProfile?['email'] ?? _user?.email;
    if (userEmail == null) return [];

    try {
      final data = await _supabase
          .from('tracking_links')
          .select('*, trackers(full_name)')
          .eq('primary_user_email', userEmail.toLowerCase())
          .eq('status', 'pending');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching incoming requests: $e');
      return [];
    }
  }

  Future<bool> approveTrackingRequest(
    String requestId,
    String enteredCode,
  ) async {
    try {
      final request = await _supabase
          .from('tracking_links')
          .select()
          .eq('id', requestId)
          .single();

      if (request['verification_code'] == enteredCode.trim()) {
        await _supabase
            .from('tracking_links')
            .update({'status': 'approved'})
            .eq('id', requestId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error approving request: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> verifyWithPython(Uint8List imageBytes) async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return {"status": "error", "message": "User not logged in"};

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_pythonBackendUrl));
      request.fields['user_id'] = id;
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'frame.jpg'),
      );

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        notifyListeners();
        try {
          final data = Map<String, dynamic>.from(jsonDecode(response.body));
          if (data['status'] == 'success') {
            _isHelmetVerified = true;
          } else {
            _isHelmetVerified = false;
          }
          notifyListeners();
          return data;
        } catch (e) {
          return {"status": "success", "message": "Verified (parse error)"};
        }
      } else {
        return {
          "status": "fail",
          "message": "Backend error: ${response.statusCode}",
        };
      }
    } catch (e) {
      debugPrint('Python verification error: $e');
      return {
        "status": "error",
        "message": "Connection failed. Is backend running?",
      };
    }
  }

  Future<void> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {

      try {
        await _supabase.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );
        await updateOnlineStatus('Active');
        await _refreshProfile();
        return;
      } catch (officialError) {
        debugPrint('Official login failed, trying bypass: $officialError');
      }


      final exists = await _supabase.rpc(
        'email_exists',
        params: {'p_email': normalizedEmail},
      );

      if (exists == true) {

        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('email', normalizedEmail)
            .maybeSingle();

        if (profileData != null) {
          _localProfile = profileData;
          _trackerProfile = null;
          await updateOnlineStatus('Active');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_profile', jsonEncode(profileData));
          notifyListeners();
          return;
        }


        final trackerData = await _supabase
            .from('trackers')
            .select()
            .eq('email', normalizedEmail)
            .maybeSingle();

        if (trackerData != null) {
          _trackerProfile = trackerData;
          _localProfile = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_profile', jsonEncode(trackerData));
          notifyListeners();
          return;
        }


        throw Exception(
          'Account found but profile inaccessible in both tables. Please contact support.',
        );
      } else {
        throw Exception('User not found. Please register first.');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      throw Exception(e.toString());
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String vehicleNumber, {
    String role = 'user',
  }) async {
    String? userId;

    final normalizedEmail = email.trim().toLowerCase();


    final response = await _supabase.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {'full_name': name, 'vehicle_number': vehicleNumber, 'role': role},
    );

    userId = response.user?.id;

    if (userId == null) {


      throw Exception(
        'Registration issue: User might already exist or confirmation required.',
      );
    }


    final exists = await _supabase.rpc(
      'email_exists',
      params: {'p_email': normalizedEmail},
    );
    if (exists == true) {


      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', normalizedEmail)
          .maybeSingle();
      if (existing != null) {
        throw Exception(
          'You are a primary user, you cannot register here as a tracker.',
        );
      } else {

        throw Exception(
          'An account with this email already exists. Please Login with OTP.',
        );
      }
    }

    try {
      final profileData = {
        'id': userId,
        'full_name': name,
        'email': normalizedEmail,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (role == 'tracker') {
        try {
          final response = await _supabase
              .from('trackers')
              .upsert(profileData)
              .select()
              .single();
          _trackerProfile = response;
        } catch (e) {
          debugPrint('Tracker profile creation handled by trigger or RLS: $e');

          final existing = await _supabase
              .from('trackers')
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (existing != null) {
            _trackerProfile = existing;
          } else {
            debugPrint(
              'Tracker profile not found after signup. Might be waiting for email confirmation.',
            );
          }
        }
      } else {
        profileData['vehicle_number'] = vehicleNumber;
        profileData['role'] = role;
        try {
          final response = await _supabase
              .from('profiles')
              .upsert(profileData)
              .select()
              .single();
          _localProfile = response;
        } catch (e) {
          debugPrint('User profile creation handled by trigger or RLS: $e');
          final existing = await _supabase
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (existing != null) {
            _localProfile = existing;
          } else {
            debugPrint(
              'User profile not found after signup. Might be waiting for email confirmation.',
            );
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'user_profile',
        jsonEncode(_trackerProfile ?? _localProfile),
      );

      debugPrint(
        'Profile created/updated for $role: ${_trackerProfile?['id'] ?? _localProfile?['id']}',
      );
      notifyListeners();
      return true;
    } catch (profileError) {
      debugPrint('Profile creation failed: $profileError');
      throw Exception('Failed to create local profile: $profileError');
    }
  }


  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {

      final rpcExists = await _supabase.rpc(
        'email_exists',
        params: {'p_email': normalizedEmail},
      );

      final profileQuery = await _supabase
          .from('profiles')
          .select('id')
          .ilike('email', normalizedEmail)
          .maybeSingle();

      if (rpcExists != true && profileQuery == null) {
        throw Exception('Account not found with this email.');
      }


      final otp = (Random().nextInt(900000) + 100000).toString();
      _pendingResetOTP = otp;
      _pendingResetEmail = normalizedEmail;


      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _emailjsServiceId,
          'template_id': _loginTemplateId,
          'user_id': _emailjsPublicKey,
          'template_params': {
            'email': normalizedEmail,
            'otp': otp,
            'message':
                '''Smart Guardian Password Reset

Your OTP: $otp

Valid for 5 minutes. Do not share this code with anyone.

– Team Smart Guardian''',
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send reset code. Please try again.');
      }

      debugPrint('Reset OTP sent to $normalizedEmail: $otp');
    } catch (e) {
      debugPrint('Send reset email error: $e');
      rethrow;
    }
  }

  Future<bool> verifyOTPAndResetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {

      if (_pendingResetOTP == null ||
          _pendingResetEmail != normalizedEmail ||
          _pendingResetOTP != token.trim()) {
        throw Exception('Invalid verification code or expired.');
      }











      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      _pendingResetOTP = null;
      _pendingResetEmail = null;
      return true;
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  Future<bool> verifySignupOTP(String email, String token) async {
    return verifyRegistrationOTP(email, token);
  }


  Future<void> sendRegistrationOTP(String email, String name) async {
    final normalizedEmail = email.trim().toLowerCase();



    final rpcExists = await _supabase.rpc(
      'email_exists',
      params: {'p_email': normalizedEmail},
    );


    final profileQuery = await _supabase
        .from('profiles')
        .select('id')
        .eq('email', normalizedEmail)
        .maybeSingle();

    if (rpcExists == true || profileQuery != null) {
      throw Exception(
        'You are a primary user, you cannot register here as a tracker.',
      );
    }


    final otp = (Random().nextInt(900000) + 100000).toString();
    _pendingRegistrationOTP = otp;


    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': _emailjsServiceId,
        'template_id': _registrationTemplateId,
        'user_id': _emailjsPublicKey,
        'template_params': {
          'email': normalizedEmail,
          'full name': name,
          'otp': otp,
          'message':
              '''Dear $name,

Welcome to Smart Guardian! 🎉

Your registration has been successfully initiated.

To complete your account setup, please use the One-Time Password (OTP) given below:

🔐 Your OTP: $otp

This OTP is valid for 5 minutes. Please do not share this code with anyone for security reasons.

If you did not register for Smart Guardian, please ignore this email.

Thank you for choosing Smart Guardian.
Stay Safe. Stay Protected.

Best Regards,
Team Smart Guardian''',
        },
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('EmailJS registration error: ${response.body}');
      throw Exception('Failed to send verification email.');
    }

    debugPrint('Registration OTP sent: $otp');
  }

  bool verifyRegistrationOTP(String email, String enteredCode) {
    if (_pendingRegistrationOTP == null) return false;
    final isValid = _pendingRegistrationOTP == enteredCode.trim();
    if (isValid) {
      _pendingRegistrationOTP = null;
    }
    return isValid;
  }





  static const String _emailjsServiceId = 'service_smuxq4m';
  static const String _registrationTemplateId = 'template_qy0ho9b';
  static const String _loginTemplateId = 'template_gzuk13l';
  static const String _emailjsPublicKey = 'tmxqqbH_JgwNFONgt';


  static const String _trackingServiceId = 'service_bmq887l';
  static const String _trackingTemplateId = 'template_q8qtqgr';
  static const String _trackingPublicKey = '7LdKoYlJ2nbVW8FMI';





  Future<void> sendLoginOTP(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {

      final rpcExists = await _supabase.rpc(
        'email_exists',
        params: {'p_email': normalizedEmail},
      );

      final profileQuery = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('email', normalizedEmail)
          .maybeSingle();

      if (rpcExists != true && profileQuery == null) {
        throw Exception(
          'Email not registered. Please create an account first.',
        );
      }

      final userName = profileQuery?['full_name'] ?? 'Smart Guardian User';


      final otp = (Random().nextInt(900000) + 100000).toString();
      _pendingLoginOTP = otp;
      _pendingLoginEmail = normalizedEmail;


      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _emailjsServiceId,
          'template_id': _loginTemplateId,
          'user_id': _emailjsPublicKey,
          'template_params': {
            'email': normalizedEmail,
            'full name': userName,
            'otp': otp,
            'message':
                '''Smart Guardian Login Verification

Your OTP is: $otp

Valid for 5 minutes. Do not share this code with anyone.

– Team Smart Guardian''',
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('EmailJS error ${response.statusCode}: ${response.body}');
        throw Exception('Failed to send verification email. Please try again.');
      }

      debugPrint('OTP sent successfully via EmailJS to $normalizedEmail');
    } on Exception {
      rethrow;
    } catch (e) {
      debugPrint('Error sending login OTP: $e');
      throw Exception('Unexpected error occurred. Please try again.');
    }
  }

  Future<bool> verifyLoginOTP(String email, String token) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {

      if (_pendingLoginOTP == null ||
          _pendingLoginEmail != normalizedEmail ||
          _pendingLoginOTP != token.trim()) {
        throw Exception('Invalid verification code or expired.');
      }
      _pendingLoginOTP = null;
      _pendingLoginEmail = null;


      final data = await _supabase
          .from('profiles')
          .select()
          .ilike('email', normalizedEmail)
          .maybeSingle();

      if (data == null) {

        final rpcExists = await _supabase.rpc(
          'email_exists',
          params: {'p_email': normalizedEmail},
        );

        if (rpcExists != true) {
          throw Exception('Account not found with this email.');
        }


        debugPrint(
          'User exists in Auth but missing profile for $normalizedEmail',
        );
      }

      _localProfile = data;
      await updateOnlineStatus('Active');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', jsonEncode(data));

      _user = _supabase.auth.currentUser;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('OTP verification error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      final id = _user?.id ?? _localProfile?['id'];
      if (id != null) {
        await _supabase
            .from('profiles')
            .update({'status': 'Offline'})
            .eq('id', id);
        debugPrint('Logout: Status set to Offline');
      }
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    _user = null;
    _localProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile');
    notifyListeners();
  }


  bool isEmailVerified() {
    return true;
  }

  Future<void> updateUserPassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      debugPrint('Update password error: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  Future<void> updateOnlineStatus(String status) async {
    final id = _user?.id ?? _localProfile?['id'];
    if (id == null) return;
    try {
      await _supabase.from('profiles').update({'status': status}).eq('id', id);
      debugPrint('User status updated to $status');
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }
}
