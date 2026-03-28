import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/python_stream_widget.dart';
import '../widgets/shared_bottom_nav.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedVehicleType;
  String? _selectedBrand;
  String? _selectedFuel;
  final TextEditingController _licenseController = TextEditingController(
    text: 'IND ',
  );
  final TextEditingController _rcController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _emergencyNameController =
      TextEditingController();
  bool _isDrunk = false;
  bool _isLicenseValid = true;
  bool _isRcValid = true;
  bool _isLoading = false;
  bool _isScanning = false;
  bool _ignoreHelmet = false;
  int _detectionCount = 0;
  int _scanSeconds = 0;
  Timer? _scanTimer;
  final String _statusUrl = "http://127.0.0.1:5000/detection_status";

  final Map<String, List<String>> _brands = {
    'Two Wheeler': [
      'Hero',
      'Honda',
      'TVS',
      'Bajaj',
      'Royal Enfield',
      'Yamaha',
      'Suzuki',
      'KTM',
      'Ola Electric',
      'Ather',
    ],
    'Three Wheeler': ['Bajaj', 'Piaggio', 'Mahindra', 'Atul Auto', 'TVS'],
    'Four Wheeler': [
      'Maruti Suzuki',
      'Hyundai',
      'Tata Motors',
      'Mahindra',
      'Kia',
      'Toyota',
      'Honda',
      'MG',
      'Skoda',
      'Volkswagen',
    ],
    'Heavy Vehicle': [
      'Tata Motors',
      'Ashok Leyland',
      'BharatBenz',
      'Mahindra',
      'Eicher',
      'Volvo',
    ],
  };

  final List<String> _fuelTypes = ['Petrol', 'Diesel', 'CNG', 'EV', 'Hybrid'];


  int _tipIndex = 0;
  final List<String> _safetyTips = [
    'Check tire pressure daily.',
    'Always wear a quality helmet.',
    'Avoid blind spots of large vehicles.',
    'Keep a safe following distance.',
    'Signal early before turning.',
    'Check oil levels weekly.',
    'Clean your visor/windshield.',
    'Observe speed limits strictly.',
    'Stay hydrated on long rides.',
    'Wear reflective gear at night.',
    'Brake smoothly, avoid sudden stops.',
    'Check brake lights and indicators.',
    'Park in designated safe zones.',
  ];
  late Timer _tipRotationTimer;

  @override
  void initState() {
    super.initState();
    _loadFormState();
    _tipRotationTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        setState(() {
          _tipIndex = (_tipIndex + 3) % _safetyTips.length;
        });
      }
    });
  }

  Future<void> _saveFormState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_vehicle_type', _selectedVehicleType ?? '');
    await prefs.setString('home_brand', _selectedBrand ?? '');
    await prefs.setString('home_fuel', _selectedFuel ?? '');
    await prefs.setString('home_license', _licenseController.text);
    await prefs.setString('home_rc', _rcController.text);
    await prefs.setString('home_emergency_name', _emergencyNameController.text);
    await prefs.setString(
      'home_emergency_contact',
      _emergencyContactController.text,
    );
  }

  Future<void> _loadFormState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedVehicleType = prefs.getString('home_vehicle_type');
      if (_selectedVehicleType == '') _selectedVehicleType = null;

      _selectedBrand = prefs.getString('home_brand');
      if (_selectedBrand == '') _selectedBrand = null;

      _selectedFuel = prefs.getString('home_fuel');
      if (_selectedFuel == '') _selectedFuel = null;

      final license = prefs.getString('home_license') ?? 'IND ';
      _licenseController.text = license;

      _rcController.text = prefs.getString('home_rc') ?? '';
      _emergencyNameController.text =
          prefs.getString('home_emergency_name') ?? '';
      _emergencyContactController.text =
          prefs.getString('home_emergency_contact') ?? '';


      if (_licenseController.text.length > 4) {
        final actualInput = _licenseController.text.substring(4);
        if (actualInput.length >= 2) {
          _isLicenseValid = RegExp(
            r'^[A-Z]{2}',
          ).hasMatch(actualInput.substring(0, 2));
        }
      }

      if (_rcController.text.length >= 2) {
        _isRcValid = RegExp(
          r'^[A-Z]{2}',
        ).hasMatch(_rcController.text.substring(0, 2));
      }
    });
  }

  @override
  void dispose() {
    _tipRotationTimer.cancel();
    _scanTimer?.cancel();
    _licenseController.dispose();
    _rcController.dispose();
    _emergencyContactController.dispose();
    _emergencyNameController.dispose();
    super.dispose();
  }

  void _toggleScanning() {
    if (_isScanning) {
      _stopScanning();
    } else {
      _startScanning();
    }
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _detectionCount = 0;
      _scanSeconds = 0;
      _ignoreHelmet = false;
    });

    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() => _scanSeconds++);

      if (_scanSeconds >= 10) {
        _stopScanning();
        _showNoHelmetAlert();
        return;
      }

      try {
        final response = await http
            .get(Uri.parse(_statusUrl))
            .timeout(const Duration(milliseconds: 800));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['helmet_present'] == true) {
            setState(() {
              _detectionCount++;
            });

            if (_detectionCount >= 3) {
              _stopScanning();
              _onHelmetVerified();
            }
          }
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  void _showNoHelmetAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('No Helmet Detected', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'We couldn\'t detect a helmet. For your safety, we recommend wearing one. If you still want to proceed, you can check the "Proceed without helmet" box.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: AppTheme.accentYellow),
            ),
          ),
        ],
      ),
    );
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  void _onHelmetVerified() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.setHelmetVerified(true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppTheme.successGreen),
            SizedBox(width: 10),
            Text('HELMET FOUND', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Verification successful! You can now proceed to your ride.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: AppTheme.accentYellow),
            ),
          ),
        ],
      ),
    );
  }

  void _startJourney() async {
    if (_selectedVehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Vehicle Type')),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isHelmetVerified && !_ignoreHelmet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Safety Check: Please verify your helmet first or check "Proceed without helmet" to continue.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_isDrunk) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Warning'),
          content: const Text(
            'You cannot drive while drunk. Please arrange alternative transport.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);


    final eName = _emergencyNameController.text.trim();
    final eNumber = _emergencyContactController.text.trim();
    if (eName.isNotEmpty && eNumber.isNotEmpty) {
      final profile = await authService.getProfile();
      final existingContacts = profile?['emergency_contacts'] as List? ?? [];

      final List<Map<String, String>> finalContacts = [];
      bool found = false;

      for (var c in existingContacts) {
        if (c is Map) {
          final name = (c['name'] ?? '').toString();
          final num = (c['number'] ?? '').toString();

          if (name.toLowerCase() == eName.toLowerCase()) {
            finalContacts.add({'name': name, 'number': eNumber});
            found = true;
          } else {
            finalContacts.add({'name': name, 'number': num});
          }
        }
      }

      if (!found) {
        finalContacts.add({'name': eName, 'number': eNumber});
      }

      await authService.updateEmergencyContacts(finalContacts);
    }


    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    if (!mounted) return;

    final user = Provider.of<AuthService>(context, listen: false).userFullName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome $user, drive safely!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );


    Navigator.pushNamed(
      context,
      '/ride',
      arguments: {'vehicleType': _selectedVehicleType},
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.userFullName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Guardian'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: authService.getProfile(),
                  builder: (context, snapshot) {
                    final photoUrl = snapshot.data?['photo_url'];
                    return CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.accentYellow,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              user.isNotEmpty ? user[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildLeftDrawer(context),
      endDrawer: _buildRightDrawer(context, authService),
      extendBodyBehindAppBar: true,
      bottomNavigationBar: _buildBottomNavigation(context),
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [

                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          FutureBuilder<Map<String, dynamic>?>(
                            future: authService.getProfile(),
                            builder: (context, snapshot) {
                              final photoUrl = snapshot.data?['photo_url'];
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.accentYellow,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppTheme.primaryOrange,
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl == null
                                      ? Text(
                                          user.isNotEmpty
                                              ? user[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            fontSize: 20,
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Guardian Dashboard',
                              style: TextStyle(
                                color: AppTheme.accentYellow.withOpacity(0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _isDrunk
                              ? Colors.redAccent.withOpacity(0.2)
                              : const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isDrunk
                                ? Colors.redAccent
                                : const Color(0xFF10B981),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isDrunk
                                  ? Icons.warning_rounded
                                  : Icons.security_rounded,
                              color: _isDrunk
                                  ? Colors.redAccent
                                  : const Color(0xFF10B981),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isDrunk ? 'UNSAFE' : 'SECURE',
                              style: TextStyle(
                                color: _isDrunk
                                    ? Colors.redAccent
                                    : const Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Safety Tips',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),


                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: Column(
                      key: ValueKey<int>(_tipIndex),
                      children: [
                        _buildSafetyTip(
                          _safetyTips[_tipIndex % _safetyTips.length],
                          Icons.lightbulb_outline,
                        ),
                        const SizedBox(height: 8),
                        _buildSafetyTip(
                          _safetyTips[(_tipIndex + 1) % _safetyTips.length],
                          Icons.security,
                        ),
                        const SizedBox(height: 8),
                        _buildSafetyTip(
                          _safetyTips[(_tipIndex + 2) % _safetyTips.length],
                          Icons.info_outline,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SAFETY SCANNER',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.accentYellow,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'AI Vision Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentYellow.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: AppTheme.accentYellow,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 350,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentYellow.withOpacity(0.05),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(23),
                          child: const PythonStreamWidget(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _toggleScanning,
                          icon: Icon(
                            _isScanning
                                ? Icons.stop_rounded
                                : Icons.radar_rounded,
                            color: Colors.black,
                          ),
                          label: Text(
                            _isScanning ? 'SCANNING...' : 'SCAN HELMET',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isScanning
                                ? AppTheme.primaryOrange
                                : AppTheme.accentYellow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/helmet-detection'),
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.black,
                          ),
                          label: const Text(
                            'OPEN FULL SCANNER',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentYellow,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: CheckboxListTile(
                          title: const Text(
                            'Proceed without helmet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          value: _ignoreHelmet,
                          activeColor: AppTheme.accentYellow,
                          checkColor: Colors.black,
                          onChanged: (val) =>
                              setState(() => _ignoreHelmet = val ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),


                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildPreRideChecklist(),
                ),

                const SizedBox(height: 32),


                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Column(
                    children: [

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select Vehicle Type',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                          },
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          thickness: 4,
                          radius: const Radius.circular(10),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                ),
                                ...[
                                  'Two Wheeler',
                                  'Three Wheeler',
                                  'Four Wheeler',
                                  'Heavy Vehicle',
                                ].map((type) {
                                  final isSelected =
                                      _selectedVehicleType == type;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(() {
                                          _selectedVehicleType = type;
                                          _selectedBrand = null;
                                        });
                                        _saveFormState();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 15,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primaryOrange
                                              : Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.accentYellow
                                                : Colors.white.withOpacity(0.1),
                                            width: 2,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: AppTheme
                                                        .primaryOrange
                                                        .withOpacity(0.3),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getVehicleIconForType(type),
                                              color: isSelected
                                                  ? Colors.black
                                                  : AppTheme.accentYellow,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              type,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.black
                                                    : Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(
                                  width: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (_selectedVehicleType != null) ...[
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Select Brand',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _brands[_selectedVehicleType]!.map((brand) {
                            final isSelected = _selectedBrand == brand;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedBrand = brand);
                                _saveFormState();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accentYellow.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accentYellow
                                        : Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                child: Text(
                                  brand,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppTheme.accentYellow
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      if (_selectedBrand != null) ...[
                        const SizedBox(height: 24),

                        TextField(
                          controller: _licenseController,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (value) {
                            if (!value.startsWith('IND ')) {
                              _licenseController.text = 'IND ';
                              _licenseController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _licenseController.text.length,
                                    ),
                                  );
                            }

                            final actualInput = _licenseController.text
                                .substring(4);
                            if (actualInput.length >= 2) {
                              final firstTwo = actualInput.substring(0, 2);
                              setState(() {
                                _isLicenseValid = RegExp(
                                  r'^[A-Z]{2}',
                                ).hasMatch(firstTwo);
                              });
                            } else if (actualInput.isEmpty) {
                              setState(() => _isLicenseValid = true);
                            } else {
                              setState(() => _isLicenseValid = false);
                            }
                            _saveFormState();
                          },
                          decoration: InputDecoration(
                            labelText: 'License Number',
                            hintText: 'MH 12 AB 1234',
                            errorText: _isLicenseValid
                                ? null
                                : 'enter valid licence number',
                            prefixIcon: const Icon(
                              Icons.badge,
                              color: AppTheme.accentYellow,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],

                      if (_selectedBrand != null &&
                          _licenseController.text.trim().length > 4) ...[
                        const SizedBox(height: 16),

                        TextField(
                          controller: _rcController,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (_) {

                            final input = _rcController.text;
                            if (input.length >= 2) {
                              final firstTwo = input.substring(0, 2);
                              setState(() {
                                _isRcValid = RegExp(
                                  r'^[A-Z]{2}',
                                ).hasMatch(firstTwo);
                              });
                            } else if (input.isEmpty) {
                              setState(() => _isRcValid = true);
                            } else {
                              setState(() => _isRcValid = false);
                            }
                            _saveFormState();
                          },
                          decoration: InputDecoration(
                            labelText: 'Registration Number (RC)',
                            hintText: 'Enter RC Number',
                            errorText: _isRcValid
                                ? null
                                : 'enter valid  RC number ',
                            prefixIcon: const Icon(
                              Icons.assignment,
                              color: AppTheme.accentYellow,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],

                      if (_rcController.text.isNotEmpty && _isRcValid) ...[
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: _selectedFuel,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Fuel Type (Optional)',
                            prefixIcon: const Icon(
                              Icons.local_gas_station,
                              color: AppTheme.accentYellow,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _fuelTypes
                              .map(
                                (fuel) => DropdownMenuItem(
                                  value: fuel,
                                  child: Text(fuel),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedFuel = value);
                            _saveFormState();
                          },
                        ),
                        if (_selectedFuel != null) ...[
                          const SizedBox(height: 16),

                          TextField(
                            controller: _emergencyNameController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (_) {
                              setState(() {});
                              _saveFormState();
                            },
                            decoration: InputDecoration(
                              labelText: 'Emergency Contact Name',
                              hintText: 'e.g. Mom',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: AppTheme.accentYellow,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _emergencyContactController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (_) {
                              setState(() {});
                              _saveFormState();
                            },
                            decoration: InputDecoration(
                              labelText: 'Emergency Contact Number',
                              hintText: '+91 9876543210',
                              prefixIcon: const Icon(
                                Icons.contact_phone,
                                color: AppTheme.accentYellow,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 12),


                      if (_selectedVehicleType != null &&
                          _selectedBrand != null &&
                          _licenseController.text.length > 4 &&
                          _rcController.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: _isDrunk
                                ? Border.all(color: Colors.redAccent)
                                : null,
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              'Are you drunk?',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              _isDrunk ? 'You cannot drive!' : 'Drive safely.',
                              style: TextStyle(
                                color: _isDrunk
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                              ),
                            ),
                            value: _isDrunk,
                            activeThumbColor: Colors.redAccent,
                            onChanged: (value) =>
                                setState(() => _isDrunk = value),
                          ),
                        ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed:
                              (_isDrunk ||
                                  _selectedBrand == null ||
                                  _rcController.text.isEmpty ||
                                  _selectedFuel == null ||
                                  _emergencyNameController.text.isEmpty ||
                                  _emergencyContactController.text.isEmpty ||
                                  !_isLicenseValid ||
                                  !_isRcValid)
                              ? null
                              : _startJourney,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (_isDrunk ||
                                    _selectedBrand == null ||
                                    _rcController.text.isEmpty ||
                                    _selectedFuel == null ||
                                    _emergencyNameController.text.isEmpty ||
                                    _emergencyContactController.text.isEmpty)
                                ? Colors.grey
                                : AppTheme.primaryOrange,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'PROCEED TO RIDE',
                                  style: TextStyle(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      _buildSafeDrivingGuide(),

                      const SizedBox(height: 20),
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

  Widget _buildLeftDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.cardColor, theme.primaryColor],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield, color: Colors.black, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'SMART GUARDIAN',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            Icons.directions_bike,
            'Ride Analytics',
            '/ride',
          ),
          _buildDrawerItem(context, Icons.map, 'Live Map', '/map'),
          _buildDrawerItem(context, Icons.sos, 'Emergency SOS', '/sos'),
          _buildDrawerItem(context, Icons.settings, 'Settings', '/settings'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightDrawer(BuildContext context, AuthService auth) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: auth.getProfile(),
            builder: (context, snapshot) {
              final photoUrl = snapshot.data?['photo_url'];
              return UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: theme.cardColor),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: AppTheme.accentYellow,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          auth.userFullName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                accountName: Text(
                  auth.userFullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(auth.user?.email ?? ''),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.person_outline,
              color: AppTheme.accentYellow,
            ),
            title: Text(
              'Edit Profile',
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: AppTheme.accentYellow,
            ),
            title: Text(
              'App Settings',
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              await auth.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accentYellow),
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }

  Widget _buildSafetyTip(String tip, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accentYellow),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = AppTheme.accentYellow,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return const SharedBottomNav(currentRoute: '/home');
  }

  IconData _getVehicleIconForType(String? type) {
    switch (type) {
      case 'Two Wheeler':
        return Icons.directions_bike;
      case 'Three Wheeler':
        return Icons.electric_rickshaw;
      case 'Four Wheeler':
        return Icons.directions_car;
      case 'Heavy Vehicle':
        return Icons.local_shipping;
      default:
        return Icons.directions_car;
    }
  }

  Widget _buildSafeDrivingGuide() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book, color: AppTheme.accentYellow),
              SizedBox(width: 10),
              Text(
                'Safe Driving Instructions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstruction(
            'Keep a 2-second gap between you and the vehicle ahead.',
          ),
          _buildInstruction(
            'Always use signals before turning or changing lanes.',
          ),
          _buildInstruction('Obey all speed limits and traffic signals.'),
          _buildInstruction('Avoid using your phone while driving.'),
          _buildInstruction('Ensure your headlights are on in low visibility.'),
          _buildInstruction('Wear your seatbelt or helmet at all times.'),
        ],
      ),
    );
  }

  Widget _buildPreRideChecklist() {
    final authService = Provider.of<AuthService>(context);
    final bool helmetVerified = authService.isHelmetVerified;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRE-RIDE CHECKLIST',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          _buildCheckItem(
            'Helmet Verification',
            helmetVerified,
            Icons.headset_rounded,
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            'Vehicle Identification',
            _selectedBrand != null,
            Icons.directions_car_rounded,
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            'License Validation',
            _licenseController.text.length > 4,
            Icons.badge_rounded,
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            'Sobriety Check',
            !_isDrunk,
            Icons.health_and_safety_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isComplete, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isComplete
                ? const Color(0xFF10B981).withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isComplete
                ? Icons.check_circle_rounded
                : Icons.radio_button_off_rounded,
            color: isComplete ? const Color(0xFF10B981) : Colors.white24,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: isComplete ? Colors.white : Colors.white38,
            fontSize: 14,
            fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
