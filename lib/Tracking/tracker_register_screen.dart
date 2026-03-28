import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../theme/app_theme.dart';

class TrackerRegisterScreen extends StatefulWidget {
  const TrackerRegisterScreen({super.key});

  @override
  State<TrackerRegisterScreen> createState() => _TrackerRegisterScreenState();
}

class _TrackerRegisterScreenState extends State<TrackerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isOTPMode = false;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);
        final authService = Provider.of<AuthService>(context, listen: false);

        if (!_isOTPMode) {
          await authService.sendRegistrationOTP(
            _emailController.text.trim(),
            _nameController.text.trim(),
          );
          setState(() {
            _isOTPMode = true;
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verification code sent to your email.'),
              ),
            );
          }
        } else {
          final isOtpValid = authService.verifyRegistrationOTP(
            _emailController.text.trim(),
            _otpController.text.trim(),
          );

          if (!isOtpValid) throw Exception('Invalid verification code.');

          final success = await authService.register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text.trim(),
            'TRACKER-001',
            role: 'tracker',
          );

          setState(() => _isLoading = false);

          if (success) {
            if (mounted) {
              _sendWelcomeEmail();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tracker registration successful!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pushReplacementNamed(context, '/tracker-home');
            }
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
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
      }
    }
  }

  Future<void> _sendWelcomeEmail() async {
    try {
      await EmailService().sendWelcomeEmail(
        _emailController.text.trim(),
        _nameController.text.trim(),
      );
    } catch (e) {
      debugPrint('Failed to send welcome email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Tracker Registration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _isOTPMode
              ? setState(() => _isOTPMode = false)
              : Navigator.pushReplacementNamed(context, '/tracker-login'),
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Join the Tracker Network',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (!_isOTPMode) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Colors.white70,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) =>
                          value!.isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
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
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.white70,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) =>
                          value!.length < 8 ? 'Min 8 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(
                          Icons.lock_clock_outlined,
                          color: Colors.white70,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords match fail'
                          : null,
                    ),
                  ] else ...[
                    const Text(
                      'Verification code sent to your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'OTP Code',
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
                      validator: (value) =>
                          value!.isEmpty ? 'OTP required' : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isOTPMode
                                ? 'VERIFY & REGISTER'
                                : 'REGISTER AS TRACKER',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
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
