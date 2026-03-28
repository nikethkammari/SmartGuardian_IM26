import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

class SharedBottomNav extends StatelessWidget {
  final String currentRoute;

  const SharedBottomNav({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _buildNavIcon(context, Icons.home_rounded, 'Home', '/home'),
                   _buildNavIcon(context, Icons.directions_bike, 'Ride', '/ride'),
                   _buildNavIcon(context, Icons.map_rounded, 'Map', '/map'),
                   _buildNavIcon(context, Icons.sos_rounded, 'SOS', '/sos', isEmergency: true),
                   _buildNavIcon(context, Icons.person_rounded, 'Profile', '/profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(BuildContext context, IconData icon, String label, String route, {bool isEmergency = false}) {
    final isActive = currentRoute == route;
    final theme = Theme.of(context);
    final color = isEmergency ? theme.colorScheme.error : null;

    return _GlassNavIcon(
      icon: icon,
      label: label,
      onTap: () {
        if (!isActive) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      color: color,
      isActive: isActive,
    );
  }
}

class _GlassNavIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isActive;

  const _GlassNavIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isActive = false,
  });

  @override
  State<_GlassNavIcon> createState() => _GlassNavIconState();
}

class _GlassNavIconState extends State<_GlassNavIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final effectiveColor = widget.color ??
        (widget.isActive || _isHovered ? AppTheme.primaryOrange : Colors.white70);

    final showGlass = widget.isActive || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

          decoration: BoxDecoration(
            color: showGlass ? effectiveColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: showGlass ? effectiveColor.withOpacity(0.5) : Colors.transparent,
              width: 1,
            ),
            boxShadow: showGlass ? [
              BoxShadow(
                color: effectiveColor.withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: effectiveColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 10,
                  fontWeight: showGlass ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
