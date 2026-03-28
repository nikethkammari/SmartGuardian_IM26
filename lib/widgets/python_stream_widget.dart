import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PythonStreamWidget extends StatefulWidget {
  const PythonStreamWidget({super.key});

  @override
  State<PythonStreamWidget> createState() => _PythonStreamWidgetState();
}

class _PythonStreamWidgetState extends State<PythonStreamWidget> {
  final String streamUrl = "http://127.0.0.1:5000/video_feed";
  late String viewId;

  @override
  void initState() {
    super.initState();
    viewId = 'python-webcam-stream-${DateTime.now().millisecondsSinceEpoch}';
    if (kIsWeb) {
      _registerFactory();
    }
  }

  void _registerFactory() {

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => html.ImageElement()
        ..src = streamUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..onError.listen((event) {
          debugPrint("Stream error encountered");
        }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: kIsWeb ? _buildWebStream() : _buildMobileStream(),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
              onPressed: () {
                setState(() {
                  viewId = 'python-webcam-stream-${DateTime.now().millisecondsSinceEpoch}';
                  if (kIsWeb) _registerFactory();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStream() {
    return HtmlElementView(
      key: ValueKey(viewId),
      viewType: viewId,
    );
  }

  Widget _buildMobileStream() {
    return Image.network(
      streamUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorState();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.accentYellow),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            "BACKEND OFFLINE",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start python_server.py",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
