import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import 'services/auth_service.dart';
import 'providers/theme_provider.dart';
import 'services/journey_service.dart';


import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/ride_screen.dart';
import 'screens/map_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/helmet_detection_screen.dart';
import 'Tracking/decision_page.dart';
import 'Tracking/tracker_login_screen.dart';
import 'Tracking/tracker_register_screen.dart';
import 'Tracking/tracker_home_page.dart';
import 'Tracking/tracker_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zchouatsvczvusicsqtc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjaG91YXRzdmN6dnVzaWNzcXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1NTk3NDQsImV4cCI6MjA4NjEzNTc0NH0._cZlVKEbwN_WLt-vw_fFJoiR9IVfsJTcBMyyTjw9zOo',
  );

  runApp(const SmartGuardianApp());
}

class SmartGuardianApp extends StatelessWidget {
  const SmartGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<JourneyService>(create: (_) => JourneyService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
            title: 'Smart Guardian',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            initialRoute: '/onboarding',
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/decision': (context) => const DecisionPage(),
              '/login': (context) => const LoginScreen(),
              '/tracker-login': (context) => const TrackerLoginScreen(),
              '/tracker-register': (context) => const TrackerRegisterScreen(),
              '/tracker-home': (context) => const TrackerHomePage(),
              '/register': (context) => const RegisterScreen(),
              '/home': (context) => const HomeScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/ride': (context) => const RideScreen(),
              '/map': (context) => const MapScreen(),
              '/sos': (context) => const SOSScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/helmet-detection': (context) => const HelmetDetectionScreen(),
              '/tracker-map': (context) {
                final args =
                    ModalRoute.of(context)!.settings.arguments
                        as Map<String, dynamic>;
                return TrackerMapScreen(userProfile: args);
              },
            },
          );
        },
      ),
    );
  }
}
