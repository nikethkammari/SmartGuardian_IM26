import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/python_stream_widget.dart';
import '../theme/app_theme.dart';

class HelmetDetectionScreen extends StatelessWidget {
  const HelmetDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'HELMET VERIFICATION',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.premiumBackground,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),


              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Text(
                      'AI SAFETY CHECK',
                      style: TextStyle(
                        color: AppTheme.accentYellow.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),
                    const SizedBox(height: 8),
                    const Text(
                      'Position your face and helmet within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                  ],
                ),
              ),

              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: PythonStreamWidget(),
                ),
              ),


              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.accentYellow, size: 20),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Our AI vision system requires a clear view of your helmet to authorize the ride.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
