import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/map_marker_service.dart';
import '../services/journey_service.dart';
import '../services/auth_service.dart';
import 'dart:async';

class TrackerMapScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const TrackerMapScreen({super.key, required this.userProfile});

  @override
  State<TrackerMapScreen> createState() => _TrackerMapScreenState();
}

class _TrackerMapScreenState extends State<TrackerMapScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  GoogleMapController? _mapController;
  LatLng? _currentPos;
  LatLng? _startPos;
  LatLng? _destPos;
  String? _startAddress;
  String? _destAddress;

  RealtimeChannel? _channel;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  List<LatLng> _allRoutePoints = [];

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  Future<void> _initTracking() async {
    final userId = widget.userProfile['id'];
    final journeyService = Provider.of<JourneyService>(context, listen: false);


    try {
      final journey = await _supabase
          .from('journeys')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (journey != null) {
        final lat = journey['current_lat'] ?? journey['start_lat'];
        final lng = journey['current_lng'] ?? journey['start_lng'];

        _startPos = LatLng(journey['start_lat'], journey['start_lng']);
        _destPos = LatLng(journey['dest_lat'], journey['dest_lng']);
        _startAddress = journey['start_address'];
        _destAddress = journey['dest_address'];

        if (lat != null && lng != null) {
          _currentPos = LatLng(lat, lng);
        }


        if (_startPos != null && _destPos != null) {
          final points = await journeyService.getPolylinePoints(
            _startPos!,
            _destPos!,
          );
          setState(() {
            _allRoutePoints = points;
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: Colors.green,
                width: 5,
              ),
            );
          });
        }

        setState(() {
          _isLoading = false;
          _updateMarkers();
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching initial journey location: $e');
      setState(() => _isLoading = false);
    }


    _channel = _supabase
        .channel('tracker_journey_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'journeys',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['status'] == 'active') {
              final lat = newRecord['current_lat'];
              final lng = newRecord['current_lng'];
              if (lat != null && lng != null) {
                final newPos = LatLng(lat, lng);
                setState(() {
                  _currentPos = newPos;


                  if (_allRoutePoints.isNotEmpty) {
                    int closestIndex = 0;
                    double minDistance = double.infinity;

                    for (int i = 0; i < _allRoutePoints.length; i++) {
                      final p = _allRoutePoints[i];
                      final d = (p.latitude - newPos.latitude).abs() +
                                (p.longitude - newPos.longitude).abs();
                      if (d < minDistance) {
                        minDistance = d;
                        closestIndex = i;
                      }
                    }

                    final remainingPoints = _allRoutePoints.sublist(closestIndex);
                    _polylines.removeWhere((p) => p.polylineId.value == 'route');
                    _polylines.add(
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: remainingPoints,
                        color: Colors.green,
                        width: 5,
                      ),
                    );
                  }

                  _updateMarkers();
                });
                if (_mapController != null) {
                  _mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
                }
              }
            } else if (newRecord['status'] == 'completed') {

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User has reached their destination.'),
                  ),
                );
                Navigator.pop(context);
              }
            }
          },
        )
        .subscribe();
  }

  void _updateMarkers() async {
    final Set<Marker> newMarkers = {};


    if (_startPos != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('source'),
          position: _startPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: 'Starting Point',
            snippet: _startAddress,
          ),
        ),
      );
    }


    if (_destPos != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: _destAddress),
        ),
      );
    }


    if (_currentPos != null) {
      final photoUrl = widget.userProfile['photo_url'];
      BitmapDescriptor icon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );

      try {
        final customIcon = await MapMarkerService.getProfileMarker(photoUrl);
        icon = customIcon;
      } catch (e) {
        debugPrint('Error loading tracker map icon: $e');
      }

      newMarkers.add(
        Marker(
          markerId: const MarkerId('tracked_user'),
          position: _currentPos!,
          icon: icon,
          zIndex: 2,
          infoWindow: InfoWindow(
            title: widget.userProfile['full_name'] ?? 'User',
            snippet: '${widget.userProfile['vehicle_number'] ?? ''}\nNote: Monitoring your safety',
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking: ${widget.userProfile['full_name'] ?? 'User'}'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPos ?? const LatLng(28.6139, 77.2090),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_startPos != null && _destPos != null) {

                LatLngBounds bounds = LatLngBounds(
                  southwest: LatLng(
                    _startPos!.latitude < _destPos!.latitude
                        ? _startPos!.latitude
                        : _destPos!.latitude,
                    _startPos!.longitude < _destPos!.longitude
                        ? _startPos!.longitude
                        : _destPos!.longitude,
                  ),
                  northeast: LatLng(
                    _startPos!.latitude > _destPos!.latitude
                        ? _startPos!.latitude
                        : _destPos!.latitude,
                    _startPos!.longitude > _destPos!.longitude
                        ? _startPos!.longitude
                        : _destPos!.longitude,
                  ),
                );
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(bounds, 100),
                );
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: '''[
              {
                "featureType": "all",
                "elementType": "labels.text.fill",
                "stylers": [{"color": "#ffffff"}]
              },
              {
                "featureType": "all",
                "elementType": "labels.text.stroke",
                "stylers": [{"color": "#000000"}, {"lightness": 13}]
              },
              {
                "featureType": "administrative",
                "elementType": "geometry.fill",
                "stylers": [{"color": "#000000"}, {"lightness": 20}]
              },
              {
                "featureType": "landscape",
                "elementType": "geometry",
                "stylers": [{"color": "#212121"}]
              },
              {
                "featureType": "road",
                "elementType": "geometry",
                "stylers": [{"color": "#000000"}, {"lightness": 28}]
              },
              {
                "featureType": "water",
                "elementType": "geometry",
                "stylers": [{"color": "#000000"}]
              }
            ]''',
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            ),


          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'SECURED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),


          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.security,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Tracking Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Optimized safety monitoring in progress',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _showMessageDialog,
                            icon: const Icon(
                              Icons.message_rounded,
                              color: AppTheme.primaryOrange,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.05),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                      if (_startAddress != null && _destAddress != null) ...[
                        const Divider(color: Colors.white10, height: 24),
                        _buildRouteRow(
                          Icons.radio_button_checked,
                          'Source',
                          _startAddress!,
                          Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _buildRouteRow(
                          Icons.location_on,
                          'Destination',
                          _destAddress!,
                          Colors.redAccent,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageDialog() {
    final controller = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.message_rounded, color: AppTheme.primaryOrange),
              const SizedBox(width: 12),
              const Text('Send Message', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Send a quick safety message to ${widget.userProfile['full_name']}.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) return;
                      setState(() => isSending = true);

                      final authService = Provider.of<AuthService>(
                        context,
                        listen: false,
                      );
                      final trackerName =
                          authService.currentProfile?['full_name'] ?? 'Tracker';

                      try {
                        await _supabase.from('tracking_messages').insert({
                          'sender_id': _supabase.auth.currentUser!.id,
                          'receiver_id': widget.userProfile['id'],
                          'sender_name': trackerName,
                          'message': controller.text.trim(),
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Message sent successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => isSending = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error sending message: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'SEND',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteRow(
    IconData icon,
    String label,
    String address,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
