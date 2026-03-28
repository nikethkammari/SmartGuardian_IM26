import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import 'maps_stub_helper.dart' if (dart.library.js) 'maps_web_helper.dart';

class JourneyService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();
  static const String _googleApiKey = GoogleMapsConfig.apiKey;

  LatLng? _draftStart;
  LatLng? _draftDest;
  String _draftStartAddress = "";
  String _draftDestAddress = "";


  LatLng? _currentIconPosition;
  String? _currentIconAddress;


  Map<String, dynamic>? _activeJourney;
  String? _activeJourneyId;
  DateTime? _journeyStartTime;
  DateTime? _lastLocationUpdate;
  List<LatLng> _sosPoints = [];
  List<Map<String, dynamic>> _globalSosEvents = [];
  RealtimeChannel? _sosChannel;

  LatLng? get draftStart => _draftStart;
  LatLng? get draftDest => _draftDest;
  String get draftStartAddress => _draftStartAddress;
  String get draftDestAddress => _draftDestAddress;

  LatLng? get currentIconPosition => _currentIconPosition;
  String? get currentIconAddress => _currentIconAddress;

  Map<String, dynamic>? get activeJourney => _activeJourney;
  String? get activeJourneyId => _activeJourneyId;
  DateTime? get journeyStartTime => _journeyStartTime;
  List<LatLng> get sosPoints => _sosPoints;
  List<Map<String, dynamic>> get globalSosEvents => _globalSosEvents;

  double get elapsedSeconds {
    if (_journeyStartTime == null) return 0;
    return DateTime.now().difference(_journeyStartTime!).inMilliseconds /
        1000.0;
  }

  void setActiveJourney(Map<String, dynamic> data, [String? id]) {
    _activeJourney = data;
    _activeJourneyId = id;
    _journeyStartTime = DateTime.now();
    _sosPoints = [];
    if (id != null) {
      fetchSOS(id);
    }
    notifyListeners();
  }

  void clearActiveJourney() {
    _activeJourney = null;
    _activeJourneyId = null;
    _journeyStartTime = null;
    _sosPoints = [];
    notifyListeners();
  }

  void updateDraftStart(LatLng? pos, String? address) {
    _draftStart = pos;
    if (address != null) _draftStartAddress = address;
    notifyListeners();
  }

  void updateDraftDest(LatLng? pos, String? address) {
    _draftDest = pos;
    if (address != null) _draftDestAddress = address;
    notifyListeners();
  }

  void updateIconPosition(LatLng? pos, [String? address]) {
    _currentIconPosition = pos;
    if (address != null) _currentIconAddress = address;


  }

  Future<String?> startJourney({
    required String userId,
    required LatLng start,
    required LatLng dest,
    required String startAddress,
    required String destAddress,
  }) async {
    try {
      final response = await _supabase
          .from('journeys')
          .insert({
            'user_id': userId,
            'start_lat': start.latitude,
            'start_lng': start.longitude,
            'dest_lat': dest.latitude,
            'dest_lng': dest.longitude,
            'start_address': startAddress,
            'dest_address': destAddress,
            'status': 'active',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response['id'].toString();
    } catch (e) {
      debugPrint('Error starting journey in DB: $e');
      return null;
    }
  }

  Future<bool> endJourney(String journeyId) async {
    try {
      await _supabase
          .from('journeys')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', journeyId);
      return true;
    } catch (e) {
      debugPrint('Error ending journey in DB: $e');
      return false;
    }
  }

  Future<void> updateLiveLocation(String journeyId, LatLng position) async {
    final now = DateTime.now();
    if (_lastLocationUpdate != null &&
        now.difference(_lastLocationUpdate!).inSeconds < 3) {
      return;
    }

    try {
      await _supabase
          .from('journeys')
          .update({
            'current_lat': position.latitude,
            'current_lng': position.longitude,
          })
          .eq('id', journeyId);
      _lastLocationUpdate = now;
      debugPrint('Supabase: Live location updated');
    } catch (e) {
      debugPrint('Error updating live location: $e');
    }
  }

  Future<void> saveSOS({
    required String userId,
    required LatLng position,
    required String address,
    String? userName,
  }) async {
    try {
      await _supabase.from('sos_events').insert({
        'user_id': userId,
        'user_name': userName,
        'journey_id': _activeJourneyId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'created_at': DateTime.now().toIso8601String(),
      });

      _sosPoints.add(position);



      notifyListeners();
    } catch (e) {
      debugPrint('Error saving SOS event in DB: $e');
    }
  }

  void initRealtimeSOS() {
    if (_sosChannel != null) return;

    _sosChannel =
        _supabase
            .channel('public:sos_events')
            .onPostgresChanges(
              event: PostgresChangeEvent
                  .all,
              schema: 'public',
              table: 'sos_events',
              callback: (payload) {
                if (payload.eventType == PostgresChangeEvent.insert) {
                  final newRecord = payload.newRecord;
                  final lat = (newRecord['latitude'] as num).toDouble();
                  final lng = (newRecord['longitude'] as num).toDouble();
                  final createdAt = newRecord['created_at'] as String;
                  final uName = newRecord['user_name'] as String?;
                  final type = newRecord['incident_type'] as String?;
                  final desc = newRecord['incident_description'] as String?;


                  final exists = _globalSosEvents.any(
                    (e) => e['created_at'] == createdAt,
                  );
                  if (!exists) {
                    _globalSosEvents.add({
                      'latitude': lat,
                      'longitude': lng,
                      'created_at': createdAt,
                      'user_name': uName,
                      'incident_type': type,
                      'incident_description': desc,
                    });
                    notifyListeners();
                  }
                } else if (payload.eventType == PostgresChangeEvent.update) {
                  final newRecord = payload.newRecord;
                  final createdAt = newRecord['created_at'] as String?;
                  if (createdAt != null) {
                    final index = _globalSosEvents.indexWhere(
                      (e) => e['created_at'] == createdAt,
                    );
                    if (index != -1) {
                      _globalSosEvents[index] = {
                        ..._globalSosEvents[index],
                        'incident_type': newRecord['incident_type'],
                        'incident_description':
                            newRecord['incident_description'],
                      };
                      notifyListeners();
                    }
                  }
                } else if (payload.eventType == PostgresChangeEvent.delete) {
                  final oldRecord = payload.oldRecord;
                  final createdAt = oldRecord['created_at'] as String?;
                  if (createdAt != null) {
                    _globalSosEvents.removeWhere(
                      (e) => e['created_at'] == createdAt,
                    );
                    notifyListeners();
                  }
                }
              },
            )
          ..subscribe();
  }

  @override
  void dispose() {
    _sosChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchAllGlobalSOS() async {
    try {
      final List<dynamic> data = await _supabase
          .from('sos_events')
          .select(
            'latitude, longitude, created_at, user_name, incident_type, incident_description',
          );

      _globalSosEvents = data
          .map(
            (e) => {
              'latitude': (e['latitude'] as num).toDouble(),
              'longitude': (e['longitude'] as num).toDouble(),
              'created_at': e['created_at'] as String,
              'user_name': e['user_name'] as String?,
              'incident_type': e['incident_type'] as String?,
              'incident_description': e['incident_description'] as String?,
            },
          )
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching all global SOS events: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMySOS(String userId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('sos_events')
          .select(
            'id, latitude, longitude, created_at, address, incident_type, incident_description',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Error fetching my SOS events: $e');
      return [];
    }
  }

  Future<bool> updateSOSDetails(
    String sosId,
    String type,
    String description,
  ) async {
    try {
      await _supabase
          .from('sos_events')
          .update({'incident_type': type, 'incident_description': description})
          .eq('id', sosId);
      return true;
    } catch (e) {
      debugPrint('Error updating SOS details: $e');
      return false;
    }
  }

  Future<bool> deleteSOS(String sosId) async {
    try {
      await _supabase.from('sos_events').delete().eq('id', sosId);

      return true;
    } catch (e) {
      debugPrint('Error deleting SOS event: $e');
      return false;
    }
  }

  Future<void> fetchSOS(String journeyId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('sos_events')
          .select('latitude, longitude')
          .eq('journey_id', journeyId);

      _sosPoints = data
          .map(
            (e) => LatLng(
              (e['latitude'] as num).toDouble(),
              (e['longitude'] as num).toDouble(),
            ),
          )
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching SOS events: $e');
    }
  }

  Future<String> getAddressFromLatLng(LatLng position) async {
    if (kIsWeb) {
      debugPrint("Attempting Geocoding API call via JS Interop...");
      try {
        final address = await MapsWebHelper.getAddressWeb(position);
        if (address != null) {
          return _cleanAddress(address);
        }
      } catch (e) {
        debugPrint("JS Geocoding exception: $e");
      }


      debugPrint("Attempting Geocoding API call via Supabase proxy...");
      try {
        final response = await _supabase.functions.invoke(
          'get-directions',
          body: {
            'type': 'geocode',
            'latlng': '${position.latitude},${position.longitude}',
            'key': _googleApiKey,
          },
        );
        if (response.status == 200 && response.data != null) {
          final data = response.data;
          if (data["status"] == "OK" &&
              data["results"] != null &&
              data["results"].isNotEmpty) {
            final rawAddress = data["results"][0]["formatted_address"];
            return _cleanAddress(rawAddress);
          }
        }
      } catch (e) {
        debugPrint("Geocoding proxy call exception: $e");
      }
    } else {
      final url =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_googleApiKey";
      try {
        final response = await _dio.get(url);
        if (response.statusCode == 200) {
          final data = response.data;
          if (data["status"] == "OK" &&
              data["results"] != null &&
              data["results"].isNotEmpty) {
            final rawAddress = data["results"][0]["formatted_address"];
            return _cleanAddress(rawAddress);
          }
        }
      } catch (e) {
        debugPrint("Geocoding error: $e");
      }
    }
    return "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
  }

  String _cleanAddress(String address) {

    final plusCodeRegex = RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}\s+');
    String cleaned = address.replaceFirst(plusCodeRegex, '');



    if (cleaned.contains("Ghatkesar Railway Footover bridge")) {
      cleaned = cleaned.replaceFirst(
        "Ghatkesar Railway Footover bridge",
        "AUDITORIUM, KOMMURI PRATAP REDDY INSTITUTE OF TECHNOLOGY",
      );
    }

    return cleaned.trim();
  }

  Future<Map<String, dynamic>?> getDirections(LatLng start, LatLng dest) async {
    if (kIsWeb) {
      debugPrint("Attempting Directions API call via JS Interop...");
      try {
        final data = await MapsWebHelper.getRouteDataWeb(start, dest);
        if (data != null) {


          return {
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {
                  "points": "",
                },
                "legs": [
                  {
                    "distance": {"text": data['distance']},
                    "duration": {"text": data['duration']},
                    "points_js": data['points'],
                  },
                ],
              },
            ],
          };
        }
        return null;
      } catch (e) {
        debugPrint("JS Directions exception: $e");
        return null;
      }
    }

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${dest.latitude},${dest.longitude}&key=$_googleApiKey";
    debugPrint("Attempting direct Directions API call (Non-Web)...");
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data["status"] == "OK" &&
            data["routes"] != null &&
            data["routes"].isNotEmpty) {
          return data;
        } else {
          debugPrint("Direct API status: ${data["status"]}");
        }
      }
    } catch (e) {
      debugPrint("Directions direct call error: $e");
    }
    return null;
  }

  Future<List<LatLng>> getPolylinePoints(LatLng start, LatLng dest) async {
    final routeData = await getRouteData(start, dest);
    return routeData?['points'] ?? [];
  }

  Future<Map<String, dynamic>?> getRouteData(LatLng start, LatLng dest) async {
    final directions = await getDirections(start, dest);
    if (directions != null &&
        directions["status"] == "OK" &&
        directions["routes"] != null &&
        directions["routes"].isNotEmpty) {
      final route = directions["routes"][0];
      final leg = route["legs"][0];


      if (leg["points_js"] != null) {
        return {
          'points': leg["points_js"] as List<LatLng>,
          'distance': leg["distance"]["text"],
          'duration': leg["duration"]["text"],
        };
      }

      final points = _decodePolyline(route["overview_polyline"]["points"]);
      return {
        'points': points,
        'distance': leg["distance"]["text"],
        'duration': leg["duration"]["text"],
      };
    }
    return null;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<List<Map<String, String>>> getAutocomplete(String input) async {
    if (input.isEmpty) return [];

    if (kIsWeb) {
      return await MapsWebHelper.getAutocompleteWeb(input);
    } else {
      final url =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_googleApiKey";
      try {
        final response = await _dio.get(url);
        if (response.statusCode == 200) {
          final data = response.data;
          if (data["status"] == "OK") {
            final List<dynamic> preds = data["predictions"];
            return preds
                .map(
                  (p) => {
                    'description': p['description'] as String,
                    'placeId': p['place_id'] as String,
                  },
                )
                .toList();
          }
        }
      } catch (e) {
        debugPrint("Autocomplete error: $e");
      }
    }
    return [];
  }

  Future<LatLng?> getLatLngFromPlaceId(String placeId) async {
    if (kIsWeb) {
      return await MapsWebHelper.getLatLngFromPlaceIdWeb(placeId);
    } else {
      final url =
          "https://maps.googleapis.com/maps/api/geocode/json?place_id=$placeId&key=$_googleApiKey";
      try {
        final response = await _dio.get(url);
        if (response.statusCode == 200) {
          final data = response.data;
          if (data["status"] == "OK" && data["results"].isNotEmpty) {
            final loc = data["results"][0]["geometry"]["location"];
            return LatLng(loc["lat"], loc["lng"]);
          }
        }
      } catch (e) {
        debugPrint("PlaceId to LatLng error: $e");
      }
    }
    return null;
  }
}
