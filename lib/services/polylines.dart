import 'dart:async';

import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  final Completer<GoogleMapController> _controller = Completer();

  LatLng? sourceLocation;
  LatLng? destinationLocation;

  List<LatLng> polylineCoordinates = [];
  bool _pickingDestination = false;
  bool _loadingLocation = true;
  StreamSubscription<Position>? _locationSub;


  Future<void> _startLiveLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;


    final loc = await Geolocator.getCurrentPosition();
    final initial = LatLng(loc.latitude, loc.longitude);

    if (mounted) {
      setState(() {
        sourceLocation = initial;
        _loadingLocation = false;
      });


      final ctrl = await _controller.future;
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(initial, 14));
    }


    _locationSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position loc) async {
          if (!mounted) return;
          final newPos = LatLng(loc.latitude, loc.longitude);
          setState(() => sourceLocation = newPos);


          if (destinationLocation != null) {
            _fetchPolyline();
          }
        });
  }


  void _fetchPolyline() {
    if (sourceLocation == null || destinationLocation == null) return;

    final google = js.context['google'];
    if (google == null) return;

    final maps = google['maps'];
    final directionsService = js.JsObject(
      maps['DirectionsService'] as js.JsFunction,
    );

    final request = js.JsObject.jsify({
      'origin': {
        'lat': sourceLocation!.latitude,
        'lng': sourceLocation!.longitude,
      },
      'destination': {
        'lat': destinationLocation!.latitude,
        'lng': destinationLocation!.longitude,
      },
      'travelMode': 'DRIVING',
    });

    directionsService.callMethod('route', [
      request,
      js.allowInterop((result, status) {
        if (status == 'OK') {
          final routes = result['routes'] as js.JsArray;
          if (routes.isEmpty) return;
          final legs = routes[0]['legs'] as js.JsArray;
          if (legs.isEmpty) return;
          final steps = legs[0]['steps'] as js.JsArray;

          final List<LatLng> points = [];
          for (var i = 0; i < steps.length; i++) {
            final latLngs = steps[i]['path'] as js.JsArray;
            for (var j = 0; j < latLngs.length; j++) {
              final latLng = latLngs[j];
              points.add(
                LatLng(
                  (latLng.callMethod('lat', []) as num).toDouble(),
                  (latLng.callMethod('lng', []) as num).toDouble(),
                ),
              );
            }
          }
          if (mounted) setState(() => polylineCoordinates = points);
        } else {
          debugPrint('Directions failed: $status');
        }
      }),
    ]);
  }


  void _onSetDestinationPressed() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.flag, color: Colors.green),
            SizedBox(width: 8),
            Text('Select Destination'),
          ],
        ),
        content: const Text(
          'Tap anywhere on the map to pin your destination.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _pickingDestination = true);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng tapped) {
    if (!_pickingDestination) return;
    setState(() {
      destinationLocation = tapped;
      _pickingDestination = false;
      polylineCoordinates = [];
    });
    Future.delayed(const Duration(milliseconds: 300), _fetchPolyline);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Destination set! Drawing route...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), _startLiveLocation);
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Track Order',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: _loadingLocation
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'Getting your location...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : Stack(
              children: [

                GoogleMap(
                  onMapCreated: (c) => _controller.complete(c),
                  initialCameraPosition: CameraPosition(
                    target: sourceLocation!,
                    zoom: 14,
                  ),
                  onTap: _onMapTap,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: polylineCoordinates,
                      color: Colors.green,
                      width: 6,
                      patterns: [],
                    ),
                  },
                  markers: {

                    Marker(
                      markerId: const MarkerId('source'),
                      position: sourceLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                      infoWindow: const InfoWindow(title: '📍 You are here'),
                    ),
                    if (destinationLocation != null)
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: destinationLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                        infoWindow: const InfoWindow(title: '🏁 Destination'),
                      ),
                  },
                ),


                if (_pickingDestination)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.green.withOpacity(0.92),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text(
                        '🗺️  Tap on the map to set your destination',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),


                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: _pickingDestination
                        ? null
                        : _onSetDestinationPressed,
                    icon: const Icon(Icons.flag),
                    label: Text(
                      _pickingDestination
                          ? 'Tap on the map...'
                          : destinationLocation == null
                          ? 'Set Destination'
                          : 'Change Destination',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.green.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
