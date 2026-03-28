import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../theme/app_theme.dart';

class MapMarkerService {
  static const double markerSize = 70.0;
  static const double imageSize = 60.0;

  static Future<BitmapDescriptor> getProfileMarker(String? photoUrl) async {
    try {
      if (photoUrl == null || photoUrl.isEmpty) {
        return await _createDefaultMarker();
      }

      final resp = await http.get(Uri.parse(photoUrl)).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final bytes = resp.bodyBytes;
        final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: imageSize.toInt(),
          targetHeight: imageSize.toInt());
        final frame = await codec.getNextFrame();
        final image = frame.image;

        final circularBytes = await _createCircularImage(image);
        if (circularBytes != null) {
          return BitmapDescriptor.fromBytes(circularBytes);
        }
      }
    } catch (e) {
      debugPrint("Error loading profile marker: $e");
    }
    return await _createDefaultMarker();
  }

  static Future<BitmapDescriptor> _createDefaultMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = AppTheme.primaryOrange
      ..style = ui.PaintingStyle.fill;

    final center = markerSize / 2;
    canvas.drawCircle(Offset(center, center), center, paint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(center, center), center - 1.5, whitePaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(markerSize.toInt(), markerSize.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  static Future<Uint8List?> _createCircularImage(ui.Image image) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final center = markerSize / 2;
    final imgRadius = imageSize / 2;


    final borderPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(center, center), center, borderPaint);

    final bgPaint = Paint()..color = AppTheme.primaryOrange;
    canvas.drawCircle(Offset(center, center), center - 2, bgPaint);


    final path = Path()..addOval(Rect.fromCircle(center: Offset(center, center), radius: imgRadius));
    canvas.clipPath(path);


    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCircle(center: Offset(center, center), radius: imgRadius);
    canvas.drawImageRect(image, src, dst, Paint());

    final picture = pictureRecorder.endRecording();
    final circularImage = await picture.toImage(markerSize.toInt(), markerSize.toInt());
    final circularBytes = await circularImage.toByteData(format: ui.ImageByteFormat.png);
    return circularBytes?.buffer.asUint8List();
  }
}
