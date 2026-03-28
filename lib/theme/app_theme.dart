import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryOrange = Color(0xFFF25912);
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color accentYellow = Color(0xFFFFE100);
  static const Color successGreen = Color(0xFF08CB00);

  static const BoxDecoration premiumBackground = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(0.0, -0.2),
      radius: 1.2,
      colors: [
        Color(0xFF1A0A00),
        backgroundBlack,
      ],
      stops: [0.0, 1.0],
    ),
  );
}
