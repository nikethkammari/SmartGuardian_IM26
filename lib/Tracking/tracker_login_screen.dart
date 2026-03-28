import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class TrackerLoginScreen extends StatefulWidget {
  const TrackerLoginScreen({super.key});

  @override
  State<TrackerLoginScreen> createState() => _TrackerLoginScreenState();
}

class _TrackerLoginScreenState extends State<TrackerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  final bool _isOTPMode = false;
  bool _otpSent = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final authService = Provider.of<AuthService>(context, listen: false);

      try {
        if (_isOTPMode) {
          if (!_otpSent) {
            await authService.sendLoginOTP(_emailController.text.trim());
            setState(() {
              _otpSent = true;
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Verification code sent to your email.'),
                ),
              );
            }
            return;
          } else {
            await authService.verifyLoginOTP(
              _emailController.text.trim(),
              _otpController.text.trim(),
            );
          }
        } else {
          await authService.login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
        }

        if (mounted) {
          await authService.getProfile();

          if (!authService.isTracker) {
            await authService.logout();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This account is not registered as a tracker.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          Navigator.pushReplacementNamed(context, '/tracker-home');
        }
      } catch (e) {
        if (mounted) {
          String errorMsg = e.toString().contains(':')
              ? e.toString().split(':').last.trim()
              : e.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _backToDecision() {
    Navigator.pushNamedAndRemoveUntil(context, '/decision', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracker Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _backToDecision,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.track_changes,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TRACKER PORTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    readOnly: _otpSent,
                    decoration: InputDecoration(
                      labelText: 'Tracker Email',
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) =>
                        (value == null || !value.contains('@'))
                        ? 'Valid email required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (!_isOTPMode)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.white70,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white70,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Password required'
                          : null,
                    ),
                  if (_isOTPMode && _otpSent)
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        prefixIcon: const Icon(
                          Icons.security,
                          color: Colors.white70,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Code required'
                          : null,
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isOTPMode
                                  ? (_otpSent ? 'VERIFY' : 'SEND OTP')
                                  : 'LOGIN AS TRACKER',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/tracker-register'),
                    child: const Text(
                      'New Tracker? Register Here',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
}
