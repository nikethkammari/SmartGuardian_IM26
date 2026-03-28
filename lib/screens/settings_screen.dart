import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import 'profile_screen.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final bool _darkMode = true;
  bool _notifications = true;
  bool _biometric = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSettingSection('Account'),
              _buildSettingTile(
                'Edit Profile',
                Icons.person_outline,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ),
              ),
              _buildSettingTile(
                'Logout',
                Icons.logout,
                onTap: () async {
                  await authService.logout();
                  if (mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 24),
              _buildSettingSection('Preferences'),
              _buildSettingTile(
                'Dark Mode',
                Icons.dark_mode_outlined,
                trailing: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) => Switch(
                    value: themeProvider.isDarkMode,
                    activeThumbColor: AppTheme.accentYellow,
                    onChanged: (v) => themeProvider.toggleTheme(),
                  ),
                ),
              ),
              _buildSettingTile(
                'Push Notifications',
                Icons.notifications_none,
                trailing: Switch(
                  value: _notifications,
                  activeThumbColor: AppTheme.accentYellow,
                  onChanged: (v) => setState(() => _notifications = v),
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingSection('Security'),
              _buildSettingTile(
                'Biometric Auth',
                Icons.fingerprint,
                trailing: Switch(
                  value: _biometric,
                  activeThumbColor: AppTheme.accentYellow,
                  onChanged: (v) => setState(() => _biometric = v),
                ),
              ),
              _buildSettingTile(
                'Change Password',
                Icons.lock_outline,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingSection('Support'),
              _buildSettingTile('Help Center', Icons.help_outline),
              _buildSettingTile('Privacy Policy', Icons.privacy_tip_outlined),
              _buildSettingTile(
                'About',
                Icons.info_outline,
                subtitle: 'v1.0.0',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64FFDA),
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    IconData icon, {
    Widget? trailing,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(color: Colors.white38))
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
