import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';

class FaceScannerView extends StatefulWidget {
  const FaceScannerView({super.key});

  @override
  State<FaceScannerView> createState() => _FaceScannerViewState();
}

class _FaceScannerViewState extends State<FaceScannerView>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  Timer? _webCaptureTimer;
  bool _isDetecting = false;
  bool _isScanning = false;
  String _statusMessage = 'Ready to scan';
  Color _statusColor = const Color(0xFF64FFDA);
  bool _helmetDetected = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
      imageFormatGroup: kIsWeb
          ? ImageFormatGroup.jpeg
          : ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _statusMessage = 'Press SCAN to begin';
          _statusColor = Colors.white;
        });

      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'CAMERA ERROR';
          _statusColor = Colors.redAccent;
        });
      }
    }
  }

  Future<void> _startManualScan() async {
    if (_helmetDetected ||
        _isScanning ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'CAPTURING...';
      _statusColor = const Color(0xFF0EA5E9);
    });

    try {

      await Future.delayed(const Duration(milliseconds: 500));

      final XFile file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      await _processImageBytes(bytes);
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'CAPTURE FAILED';
          _statusColor = Colors.redAccent;
        });
      }
    }
  }



  Future<void> _processImageBytes(Uint8List bytes) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      final technicalStatuses = [
        "CALIBRATING OPTICS...",
        "DEPTH ANALYSIS...",
        "SYMMETRY SCAN...",
        "PATTERN MATCHING...",
        "FINALIZING...",
      ];

      if (mounted && !_helmetDetected) {
        for (var status in technicalStatuses) {
          if (!mounted || _helmetDetected) break;
          setState(() {
            _statusMessage = status;
            _statusColor = const Color(0xFF0EA5E9);
          });
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }

      final result = await authService.verifyWithPython(bytes);

      if (mounted) {
        if (result['status'] == 'success') {
          setState(() {
            _helmetDetected = true;
            _statusMessage = "HELMET VERIFIED";
            _statusColor = const Color(0xFF64FFDA);
          });
          _stopCapture();
          _showHelmetDetectedAlert();
        } else {
          setState(() {
            _helmetDetected = false;
            _isScanning = false;
            _statusMessage = "SCAN FAILED";
            _statusColor = Colors.redAccent;
          });
          _stopCapture();
          _showNoHelmetAlert();
        }
      }
    } catch (e) {
      debugPrint('Processing error: $e');
    } finally {
      if (mounted) {
        _isDetecting = false;
      }
    }
  }

  void _showHelmetDetectedAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.verified_user, color: Color(0xFF64FFDA), size: 60),
            SizedBox(height: 16),
            Text(
              "Great! Helmet Detected",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          "Stay safe on your journey! Your helmet has been verified.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64FFDA),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "START RIDE",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoHelmetAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orangeAccent, size: 60),
            SizedBox(height: 16),
            Text(
              "No Helmet Detected",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          "Please wear your helmet for your safety. It's required to start your ride.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _helmetDetected = false;
                  _isScanning = false;
                  _statusMessage = 'Press SCAN to try again';
                  _statusColor = Colors.white;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "TRY AGAIN",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _stopCapture() {
    _webCaptureTimer?.cancel();
    if (!kIsWeb) {
      _cameraController?.stopImageStream();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _webCaptureTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF64FFDA)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [

          Transform.scale(
            scale: 1.25,
            child: Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),


          _buildScanningOverlay(),


          _buildStatusCard(),


          if (!_helmetDetected && !_isScanning) _buildScanButton(),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Stack(
      children: [

        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.4),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  height: 350,
                  width: 350,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ],
          ),
        ),


        if (!_helmetDetected)
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 350 + (10 * _pulseController.value),
                  height: 350 + (10 * _pulseController.value),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(
                        0xFF64FFDA,
                      ).withOpacity(0.3 + (0.4 * _pulseController.value)),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Stack(
                    children: [

                      Center(
                        child: Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 200,
                          color: const Color(
                            0xFF64FFDA,
                          ).withOpacity(0.05 + (0.1 * _pulseController.value)),
                        ),
                      ),
                      _buildReticleCorner(0, 0, 0),
                      _buildReticleCorner(null, 0, 1),
                      _buildReticleCorner(0, null, 2),
                      _buildReticleCorner(null, null, 3),
                      const _LaserSweepLine(),
                    ],
                  ),
                );
              },
            ),
          ),

        if (_helmetDetected)
          Center(
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF64FFDA), width: 4),
                borderRadius: BorderRadius.circular(40),
                color: const Color(0xFF64FFDA).withOpacity(0.1),
              ),
              child: const Center(
                child: Icon(
                  Icons.verified_user,
                  color: Color(0xFF64FFDA),
                  size: 100,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            ),
          ),
      ],
    );
  }

  Widget _buildReticleCorner(double? top, double? left, int rotation) {
    return Positioned(
      top: top,
      left: left,
      right: left == null ? 0 : null,
      bottom: top == null ? 0 : null,
      child: RotatedBox(
        quarterTurns: rotation,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF64FFDA), width: 4),
              left: BorderSide(color: Color(0xFF64FFDA), width: 4),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _helmetDetected
                            ? Icons.check_circle_rounded
                            : Icons.sensors_rounded,
                        color: _statusColor,
                        size: 28,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 2.seconds),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _helmetDetected
                            ? 'VERIFICATION COMPLETE'
                            : 'AI SCANNING SYSTEM',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildScanButton() {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF64FFDA).withOpacity(0.9),
                    const Color(0xFF0EA5E9).withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64FFDA).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _startManualScan,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.scanner,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'START SCAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
      ),
    );
  }
}

class _LaserSweepLine extends StatefulWidget {
  const _LaserSweepLine();

  @override
  State<_LaserSweepLine> createState() => _LaserSweepLineState();
}

class _LaserSweepLineState extends State<_LaserSweepLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: 350 * _controller.value,
          left: 0,
          right: 0,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF64FFDA).withOpacity(0.0),
                  const Color(0xFF64FFDA).withOpacity(0.3),
                  const Color(0xFF64FFDA).withOpacity(0.0),
                ],
              ),
            ),
            child: Center(
              child: Container(
                height: 2,
                color: const Color(0xFF64FFDA).withOpacity(0.8),
              ),
            ),
          ),
        );
      },
    );
  }
}
