import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../widgets/shared_bottom_nav.dart';
import '../theme/app_theme.dart';
import '../services/journey_service.dart';
import '../services/map_marker_service.dart';

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final _startController = TextEditingController();
  final _destController = TextEditingController();
  bool _isJourneyActive = false;
  bool _isSending = false;


  LatLng? _startLocation;
  LatLng? _destinationLocation;
  bool _isSelectingStart = true;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  String? _currentJourneyId;
  StreamSubscription<Position>? _positionStream;
  bool _followingUser = true;
  String _distance = "---";
  String _duration = "---";
  bool _isMapLoading = false;
  String? _mapError;
  LatLng? _currentPos;
  BitmapDescriptor? _userIcon;
  bool _isDisposed = false;
  String? _vehicleType;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _initUserIcon();
    _loadDraftJourney();
  }

  void _loadDraftJourney() {
    WidgetsBinding.instance.addPostFrameCallback((_) {

      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _vehicleType = args['vehicleType'] as String?;
      }

      final journeyService = Provider.of<JourneyService>(
        context,
        listen: false,
      );
      setState(() {
        _startLocation = journeyService.draftStart;
        _destinationLocation = journeyService.draftDest;
        _startController.text = journeyService.draftStartAddress;
        _destController.text = journeyService.draftDestAddress;
      });
      if (_startLocation != null && _destinationLocation != null) {
        _getRoute(_startLocation!, _destinationLocation!);
      }
    });
  }

  Future<void> _initUserIcon() async {
    if (_isDisposed) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final photoUrl = authService.userPhotoUrl;

    try {
      final icon = await MapMarkerService.getProfileMarker(photoUrl);
      if (mounted && !_isDisposed) {
        setState(() {
          _userIcon = icon;
          _updateMarkers();
        });
      }
    } catch (e) {
      debugPrint("Error loading user icon: $e");
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _startController.dispose();
    _destController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;


    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _currentPos = LatLng(pos.latitude, pos.longitude);
          _updateMarkers();
        });
      }
    } catch (e) {
      debugPrint("Fast initial location fetch failed: $e");
    }

    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        ).listen((Position position) {
          final newPos = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentPos = newPos;
            _updateMarkers();
          });

          if (_followingUser && _mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
          }
        });
  }

  Future<void> _clearHomeFormState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('home_vehicle_type');
    await prefs.remove('home_brand');
    await prefs.remove('home_fuel');
    await prefs.remove('home_license');
    await prefs.remove('home_rc');
    await prefs.remove('home_emergency_name');
    await prefs.remove('home_emergency_contact');
  }

  Future<void> _toggleJourney() async {
    final journeyService = Provider.of<JourneyService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_startController.text.isEmpty ||
        _destController.text.isEmpty ||
        _startLocation == null ||
        _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select start and destination points on the map',
          ),
        ),
      );
      return;
    }

    if (!_isJourneyActive) {

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Start Journey?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Your ride is going to start. Click okay to continue.Set all your requirements.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'OKAY',
                style: TextStyle(color: AppTheme.primaryOrange),
              ),
            ),
          ],
        ),
      );

      if (proceed != true) return;


      final journeyId = await journeyService.startJourney(
        userId: authService.user?.id ?? '',
        start: _startLocation!,
        dest: _destinationLocation!,
        startAddress: _startController.text,
        destAddress: _destController.text,
      );

      if (journeyId != null) {
        _currentJourneyId = journeyId;
        await authService.updateOnlineStatus('On Journey');
        setState(
          () => _isJourneyActive = true,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to save journey to database. Check connection.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }


      if (mounted) {
        final journeyData = {
          'start': _startLocation,
          'dest': _destinationLocation,
          'startName': _startController.text,
          'destName': _destController.text,
          'vehicleType': _vehicleType,
        };
        journeyService.setActiveJourney(journeyData, _currentJourneyId);

        Navigator.pushNamed(context, '/map', arguments: journeyData);
      }
    } else {

      if (_currentJourneyId != null) {
        final dbSuccess = await journeyService.endJourney(_currentJourneyId!);
        if (dbSuccess) {

          await authService.updateOnlineStatus('Active');

          _currentJourneyId = null;
          setState(() => _isJourneyActive = false);
          journeyService.clearActiveJourney();
          await _clearHomeFormState();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to end journey in database.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSending = true);
    final emailService = EmailService();

    await emailService.sendJourneyNotification(
      userEmail: authService.currentUser ?? '',
      userName: authService.userFullName,
      startLocation: _startController.text,
      destination: _destController.text,
      isStarting: _isJourneyActive,
    );

    setState(() => _isSending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isJourneyActive ? 'Journey Started!' : 'Journey Completed!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onMapTap(LatLng position) async {
    if (_isJourneyActive) return;
    final journeyService = Provider.of<JourneyService>(context, listen: false);

    if (_isSelectingStart) {
      setState(() {
        _startLocation = position;
        _startController.text = "Loading address...";
        _updateMarkers();
      });
      journeyService.updateDraftStart(position, "Loading address...");
      final address = await journeyService.getAddressFromLatLng(position);
      if (mounted) {
        setState(() => _startController.text = address);
        journeyService.updateDraftStart(position, address);
      }
    } else {
      setState(() {
        _destinationLocation = position;
        _destController.text = "Loading address...";
        _updateMarkers();
      });
      journeyService.updateDraftDest(position, "Loading address...");
      final address = await journeyService.getAddressFromLatLng(position);
      if (mounted) {
        setState(() => _destController.text = address);
        journeyService.updateDraftDest(position, address);
      }
    }


    if (_startLocation != null && _destinationLocation != null) {
      _getRoute(_startLocation!, _destinationLocation!);
    }
  }

  Future<void> _setStartToLiveLocation() async {
    if (_currentPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching live location...')),
      );
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        ).timeout(const Duration(seconds: 5));
        setState(() => _currentPos = LatLng(pos.latitude, pos.longitude));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get live location')),
          );
        }
        return;
      }
    }

    if (_currentPos != null) {
      final journeyService = Provider.of<JourneyService>(
        context,
        listen: false,
      );
      setState(() {
        _startLocation = _currentPos;
        _startController.text = "Loading address...";
        _updateMarkers();
      });

      final address = await journeyService.getAddressFromLatLng(_currentPos!);
      if (mounted) {
        setState(() => _startController.text = address);
        journeyService.updateDraftStart(_currentPos!, address);
      }
    }
  }

  Future<void> _getRoute(LatLng start, LatLng dest) async {
    final journeyService = Provider.of<JourneyService>(context, listen: false);
    setState(() {
      _isMapLoading = true;
      _mapError = null;
    });

    try {
      final routeData = await journeyService.getRouteData(start, dest);
      if (routeData != null) {
        setState(() {
          _distance = routeData['distance'];
          _duration = routeData['duration'];
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId("route"),
              points: routeData['points'],
              color: AppTheme.primaryOrange,
              width: 6,
            ),
          );
          _isMapLoading = false;
        });
      } else {
        setState(() {
          _isMapLoading = false;
          _mapError =
              "No route found. Ensure Edge Functions are deployed and Directions API is enabled.";
        });
      }
    } catch (e) {
      debugPrint("Routing error in RideScreen: $e");
      setState(() {
        _isMapLoading = false;
        _mapError = "Connection error while fetching route.";
      });
    }
  }

  void _updateMarkers() {
    final Set<Marker> newMarkers = {};


    if (_currentPos != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('user_pos'),
          position: _currentPos!,
          icon:
              _userIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
          anchor: const Offset(0.5, 0.5),
          zIndex: 10,
        ),
      );
    }

    if (_startLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: _startLocation!,
          infoWindow: const InfoWindow(title: 'Start Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }
    if (_destinationLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isJourneyActive ? 'Active Ride' : 'Ride Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBar: const SharedBottomNav(currentRoute: '/ride'),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isJourneyActive ? 'Journey in Progress' : 'Plan Your Trip',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),


                _buildAutocompleteInput(
                  label: 'Start Location',
                  icon: Icons.my_location,
                  controller: _startController,
                  enabled: !_isJourneyActive,
                  isStart: true,
                  suffixIcon: Icons.location_on_outlined,
                  onSuffixPressed: _setStartToLiveLocation,
                ),
                const SizedBox(height: 12),
                _buildAutocompleteInput(
                  label: 'Destination',
                  icon: Icons.flag,
                  controller: _destController,
                  enabled: !_isJourneyActive,
                  isStart: false,
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _toggleJourney,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isJourneyActive
                          ? Colors.redAccent
                          : AppTheme.primaryOrange,
                      foregroundColor: Colors.black,
                    ),
                    child: _isSending
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            _isJourneyActive ? 'END JOURNEY' : 'START JOURNEY',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 30),


                if (!_isJourneyActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSelectionToggle(
                            'STARTING POINT',
                            _isSelectingStart,
                            () => setState(() => _isSelectingStart = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectionToggle(
                            'DESTINATION POINT',
                            !_isSelectingStart,
                            () => setState(() => _isSelectingStart = false),
                          ),
                        ),
                      ],
                    ),
                  ),


                Stack(
                  children: [
                    Container(
                      height: 400,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: const CameraPosition(
                              target: LatLng(28.6139, 77.2090),
                              zoom: 14,
                            ),
                            myLocationEnabled: true,
                            myLocationButtonEnabled:
                                false,
                            zoomControlsEnabled: true,
                            mapToolbarEnabled: false,
                            markers: _markers,
                            polylines: _polylines,
                            onTap: _onMapTap,
                            onCameraMove: (position) {
                              if (_followingUser) {
                                setState(() => _followingUser = false);
                              }
                            },
                            onMapCreated: (GoogleMapController controller) async {
                              _mapController = controller;


                              if (_startLocation == null &&
                                  _destinationLocation == null) {
                                try {

                                  if (!kIsWeb) {
                                    final lastPos =
                                        await Geolocator.getLastKnownPosition();
                                    if (lastPos != null && mounted) {
                                      _mapController?.moveCamera(
                                        CameraUpdate.newLatLngZoom(
                                          LatLng(
                                            lastPos.latitude,
                                            lastPos.longitude,
                                          ),
                                          15,
                                        ),
                                      );
                                      setState(() {
                                        _currentPos = LatLng(
                                          lastPos.latitude,
                                          lastPos.longitude,
                                        );
                                        _updateMarkers();
                                      });
                                    }
                                  }


                                  try {
                                    final pos =
                                        await Geolocator.getCurrentPosition(
                                          locationSettings:
                                              const LocationSettings(
                                                accuracy: LocationAccuracy.best,
                                              ),
                                        ).timeout(const Duration(seconds: 15));

                                    if (mounted) {
                                      _mapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(
                                          LatLng(pos.latitude, pos.longitude),
                                          15,
                                        ),
                                      );

                                      setState(() {
                                        _currentPos = LatLng(
                                          pos.latitude,
                                          pos.longitude,
                                        );
                                        _updateMarkers();
                                        _followingUser = true;
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      "Final accuracy check timed out or failed: $e",
                                    );
                                  }
                                } catch (e) {
                                  debugPrint(
                                    "Initial location error in RideScreen: $e",
                                  );
                                }
                              }
                            },
                          ),
                          if (_isMapLoading)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryOrange,
                                ),
                              ),
                            ),
                          if (_mapError != null)
                            Positioned(
                              top: 20,
                              left: 20,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _mapError!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        onPressed: () async {
                          if (_currentPos != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(_currentPos!, 15.5),
                            );
                            setState(() => _followingUser = true);
                          } else {

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Locating your position...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                            try {
                              final pos =
                                  await Geolocator.getCurrentPosition(
                                    locationSettings: const LocationSettings(
                                      accuracy: LocationAccuracy.best,
                                    ),
                                  ).timeout(
                                    const Duration(seconds: 10),
                                  );

                              final latLng = LatLng(
                                pos.latitude,
                                pos.longitude,
                              );
                              if (mounted) {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(latLng, 15.5),
                                );
                                setState(() {
                                  _currentPos = latLng;
                                  _followingUser = true;
                                  _updateMarkers();
                                });
                              }
                            } catch (e) {
                              debugPrint(
                                "Manual high-accuracy location fetch failed: $e",
                              );

                              if (!kIsWeb) {
                                final lastPos =
                                    await Geolocator.getLastKnownPosition();
                                if (lastPos != null && mounted) {
                                  final lastLatLng = LatLng(
                                    lastPos.latitude,
                                    lastPos.longitude,
                                  );
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      lastLatLng,
                                      15.5,
                                    ),
                                  );
                                  setState(() {
                                    _currentPos = lastLatLng;
                                    _followingUser = true;
                                    _updateMarkers();
                                  });
                                }
                              }
                            }
                          }
                        },
                        backgroundColor: AppTheme.primaryOrange,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _buildStatCard(
                  'Total Distance',
                  _distance,
                  Icons.route_outlined,
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  'Est. Duration',
                  _duration,
                  Icons.timer_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteInput({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = true,
    required bool isStart,
    VoidCallback? onSuffixPressed,
    IconData? suffixIcon,
  }) {
    final journeyService = Provider.of<JourneyService>(context, listen: false);

    return RawAutocomplete<Map<String, String>>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, String>>.empty();
        }
        return await journeyService.getAutocomplete(textEditingValue.text);
      },
      displayStringForOption: (option) => option['description'] ?? '',
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: fieldController,
              focusNode: focusNode,
              enabled: enabled,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                suffixIcon: suffixIcon != null
                    ? IconButton(
                        icon: Icon(suffixIcon, color: Colors.white70),
                        onPressed: onSuffixPressed,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              onSubmitted: (value) => onFieldSubmitted(),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[900],
            child: Container(
              width:
                  MediaQuery.of(context).size.width -
                  48,
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option['description'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (Map<String, String> selection) async {
        final placeId = selection['placeId'];
        if (placeId != null) {
          final latLng = await journeyService.getLatLngFromPlaceId(placeId);
          if (latLng != null && mounted) {
            setState(() {
              if (isStart) {
                _startLocation = latLng;
                journeyService.updateDraftStart(
                  latLng,
                  selection['description'],
                );
              } else {
                _destinationLocation = latLng;
                journeyService.updateDraftDest(
                  latLng,
                  selection['description'],
                );
              }
              _updateMarkers();


              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(latLng, 15),
              );
            });

            if (_startLocation != null && _destinationLocation != null) {
              _getRoute(_startLocation!, _destinationLocation!);
            }
          }
        }
      },
    );
  }

  Widget _buildSelectionToggle(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentYellow
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentYellow : Colors.white24,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentYellow, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.1);
  }
}
