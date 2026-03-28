import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _vehicleController = TextEditingController();
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

          if (!isOtpValid) {
            throw Exception('Invalid verification code.');
          }

          final success = await authService.register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text.trim(),
            _vehicleController.text.trim(),
          );

          setState(() => _isLoading = false);

          if (success) {
            if (mounted) {
              _sendWelcomeEmail();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Registration successful! Welcome to Smart Guardian.',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          String errorMsg = e.toString().contains(':')
              ? e.toString().split(':').last.trim()
              : e.toString();

          if (errorMsg == 'null' || errorMsg.isEmpty) {
            errorMsg = 'Unexpected error occurred. Please try again.';
          }

          final isAlreadyRegistered =
              errorMsg.toLowerCase().contains('already registered') ||
              errorMsg.toLowerCase().contains('login instead');

          if (isAlreadyRegistered) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account already exists. Please login instead.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
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
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isOTPMode) {
              setState(() => _isOTPMode = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _buildRegisterForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Join Smart Guardian',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ride Safe, Ride Smart',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontStyle: FontStyle.italic,
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
              validator: (value) => value!.isEmpty ? 'Please enter name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleController,
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                prefixIcon: const Icon(
                  Icons.directions_bike,
                  color: Colors.white70,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter vehicle number' : null,
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
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter email';
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
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
                helperText: 'Min 8 chars, 1 uppercase, 1 special char',
                helperStyle: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
                if (value.length < 8) return 'Minimum 8 characters required';
                if (!value.contains(RegExp(r'[A-Z]'))) {
                  return 'Must contain an uppercase letter';
                }
                if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                  return 'Must contain a special character';
                }
                return null;
              },
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ] else ...[
            const Text(
              'Enter the verification code sent to your email',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Verification Code',
                prefixIcon: const Icon(Icons.security, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: const TextStyle(color: Colors.white, letterSpacing: 4),
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter the code'
                  : null,
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    _isOTPMode ? 'VERIFY & REGISTER' : 'REGISTER',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text(
              'Already have an account? Login',
              style: TextStyle(color: AppTheme.accentYellow),
            ),
          ),
        ],
      ),
    );
  }
}
