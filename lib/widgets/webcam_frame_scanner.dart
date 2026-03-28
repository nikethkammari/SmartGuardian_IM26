import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class WebcamFrameScanner extends StatefulWidget {
  final VoidCallback? onVerified;

  const WebcamFrameScanner({super.key, this.onVerified});

  @override
  State<WebcamFrameScanner> createState() => _WebcamFrameScannerState();
}

class _WebcamFrameScannerState extends State<WebcamFrameScanner> with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isScanning = false;
  bool _helmetDetected = false;
  String _statusMessage = 'SYSTEM READY';
  Color _statusColor = Colors.white;
  late AnimationController _pulseController;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: kIsWeb ? ImageFormatGroup.jpeg : ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'HARDWARE ERROR';
          _statusColor = Colors.redAccent;
        });
      }
    }
  }

  Future<void> _startScan() async {
    if (_helmetDetected || _isScanning || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'INITIALIZING SENSORS';
      _statusColor = AppTheme.accentYellow;
    });

    try {
      final XFile file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      await _processImage(bytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'SIGNAL LOST';
          _statusColor = Colors.redAccent;
        });
      }
    }
  }

  Future<void> _processImage(Uint8List bytes) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    final bootSequence = [
      "CALIBRATING OPTICS...",
      "NEURAL MAPPING...",
      "PATTERN ANALYSIS...",
      "VERIFYING DATA..."
    ];

    for (var status in bootSequence) {
      if (!mounted) return;
      setState(() {
        _statusMessage = status;
        _statusColor = AppTheme.accentYellow;
      });
      await Future.delayed(const Duration(milliseconds: 700));
    }

    final result = await authService.verifyWithPython(bytes);

    if (mounted) {
      if (result['status'] == 'success') {
        setState(() {
          _helmetDetected = true;
          _statusMessage = "VERIFIED";
          _statusColor = AppTheme.successGreen;
        });
        if (widget.onVerified != null) widget.onVerified!();
      } else {
        setState(() {
          _isScanning = false;
          _statusMessage = "NO HELMET";
          _statusColor = Colors.redAccent;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return _buildContainer(
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentYellow),
        ),
      );
    }

    return _buildContainer(
      child: Stack(
        fit: StackFit.expand,
        children: [

          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Transform.scale(
              scale: 1.25,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),


          _buildTechOverlay(),


          _buildOverlayUI(),
        ],
      ),
    );
  }

  Widget _buildContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryOrange.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: child,
      ),
    );
  }

  Widget _buildTechOverlay() {
    return Stack(
      children: [

        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
              stops: const [0.6, 1.0],
            ),
          ),
        ),


        if (_isScanning && !_helmetDetected)
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * 0.45 * _scanLineController.value,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentYellow.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    color: AppTheme.accentYellow,
                  ),
                ),
              );
            },
          ),


        _buildReticleCorner(top: 20, left: 20, quarterTurns: 0),
        _buildReticleCorner(top: 20, right: 20, quarterTurns: 1),
        _buildReticleCorner(bottom: 20, left: 20, quarterTurns: 3),
        _buildReticleCorner(bottom: 20, right: 20, quarterTurns: 2),


        if (_helmetDetected)
          Center(
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.successGreen, width: 4),
                color: AppTheme.successGreen.withOpacity(0.1),
              ),
              child: const Icon(Icons.check_rounded, color: AppTheme.successGreen, size: 80),
            ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
          ),
      ],
    );
  }

  Widget _buildReticleCorner({double? top, double? bottom, double? left, double? right, required int quarterTurns}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white, width: 2),
              left: BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor.withOpacity(0.3 + (0.7 * _pulseController.value)),
                      boxShadow: [
                        BoxShadow(
                          color: _statusColor.withOpacity(0.5),
                          blurRadius: 10 * _pulseController.value,
                          spreadRadius: 2 * _pulseController.value,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AI VISION FEED',
                      style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    Text(
                      _statusMessage,
                      style: TextStyle(color: _statusColor, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              if (!_isScanning && !_helmetDetected)
                IconButton(
                  onPressed: _startScan,
                  icon: const Icon(Icons.flash_on, color: AppTheme.accentYellow),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
