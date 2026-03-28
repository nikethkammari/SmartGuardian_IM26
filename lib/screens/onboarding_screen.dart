import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _agreedToTerms = false;

  void _getStarted() {
    if (_agreedToTerms) {
      Navigator.pushReplacementNamed(context, '/decision');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Conditions to proceed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              const Icon(Icons.two_wheeler, size: 120, color: Colors.white)
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(
                    duration: 2000.ms,
                    color: Theme.of(context).primaryColor,
                  )
                  .moveY(
                    begin: 0,
                    end: -10,
                    curve: Curves.easeInOut,
                    duration: 1000.ms,
                  )
                  .then()
                  .moveY(begin: -10, end: 0, curve: Curves.easeInOut),

              const SizedBox(height: 30),

              const Text(
                'SMART GUARDIAN',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.5, end: 0),

              const SizedBox(height: 10),

              const Text(
                'Guardian of Your Journey',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.2,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 800.ms),

              const Spacer(),


              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Safety Commitment',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'By proceeding, you commit to wearing a helmet and adhering to all safety protocols for a secure ride.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          activeColor: Theme.of(context).primaryColor,
                          checkColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          onChanged: (value) {
                            setState(() {
                              _agreedToTerms = value ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'I agree to the safety terms.',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _getStarted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _agreedToTerms
                          ? Theme.of(context).primaryColor
                          : Colors.grey.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
