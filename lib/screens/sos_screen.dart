import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/auth_service.dart';
import '../services/journey_service.dart';
import '../services/email_service.dart';
import '../widgets/shared_bottom_nav.dart';
import '../theme/app_theme.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  bool _isSending = false;
  Future<void> _sendSOS() async {
    setState(() => _isSending = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final emailService = EmailService();

    try {
      final journeyService = Provider.of<JourneyService>(
        context,
        listen: false,
      );
      final iconPos = journeyService.currentIconPosition;
      late double lat, lng;
      String locationName = "Current User Location";

      if (iconPos != null) {

        lat = iconPos.latitude;
        lng = iconPos.longitude;


        locationName = await journeyService.getAddressFromLatLng(
          LatLng(lat, lng),
        );
      } else {

        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled.');
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Location permissions are denied.');
          }
        }

        final position = await Geolocator.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;


        locationName = await journeyService.getAddressFromLatLng(
          LatLng(lat, lng),
        );
      }

      final emergencyEmail = authService.emergencyEmail;
      final fullName = authService.userFullName;

      if (emergencyEmail == null || emergencyEmail.isEmpty) {
        throw Exception('No emergency email set in profile.');
      }

      final now = DateTime.now();
      final formattedTime =
          "${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}";


      final mapsLink = 'https://www.google.com/maps?q=$lat,$lng';


      final success = await emailService.sendSOSPremiumAlert(
        emergencyEmail: emergencyEmail,
        fullName: fullName,
        locationName: locationName,
        latitude: lat.toString(),
        longitude: lng.toString(),
        dateTime: formattedTime,
        link: mapsLink,
      );

      if (success) {

        await journeyService.saveSOS(
          userId: authService.user?.id ?? '',
          userName: fullName,
          position: LatLng(lat, lng),
          address: locationName,
        );
      }

      setState(() => _isSending = false);

      if (mounted) {
        if (success) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text(
                'SOS SENT',
                style: TextStyle(color: Colors.red),
              ),
              content: const Text(
                'Emergency alert with your location has been sent to your Primary emergency contacts.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          throw Exception('Failed to send SOS email alert.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBar: const SharedBottomNav(currentRoute: '/sos'),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'NEED ASSISTANCE?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: Text(
                  'Pressing the SOS button will alert your emergency contacts and nearby medical services with your live location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const Spacer(),
              _buildSOSButton(),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildContactTile('Police', '100'),
              _buildContactTile('Ambulance', '108'),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: _isSending ? null : _sendSOS,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(0.1),
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Center(
          child: Container(
            width: 160,
            height: 160,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent,
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactTile(String name, String number) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(number, style: const TextStyle(color: AppTheme.accentYellow)),
        ],
      ),
    );
  }
}
