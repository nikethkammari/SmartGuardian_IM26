import 'dart:js' as dart_js;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class MapsWebHelper {
  static bool get isSdkLoaded {
    try {
      if (!dart_js.context.hasProperty('google')) return false;
      final google = dart_js.context['google'];
      if (google == null) return false;


      if (google is! dart_js.JsObject) return false;
      if (!google.hasProperty('maps')) return false;

      final maps = google['maps'];
      if (maps == null || maps is! dart_js.JsObject) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getRouteDataWeb(
    LatLng start,
    LatLng dest,
  ) async {
    if (!isSdkLoaded) {
      debugPrint("Google Maps JS SDK not fully loaded yet");
      return null;
    }
    final completer = Completer<Map<String, dynamic>?>();

    try {
      final google = dart_js.context['google'];
      final maps = google['maps'];
      final directionsService = dart_js.JsObject(
        maps['DirectionsService'] as dart_js.JsFunction,
      );

      final request = dart_js.JsObject.jsify({
        'origin': {'lat': start.latitude, 'lng': start.longitude},
        'destination': {'lat': dest.latitude, 'lng': dest.longitude},
        'travelMode': 'DRIVING',
      });

      directionsService.callMethod('route', [
        request,
        dart_js.allowInterop((result, status) {
          if (status == 'OK') {
            final routes = result['routes'] as dart_js.JsArray;
            if (routes.isEmpty) {
              completer.complete(null);
              return;
            }

            final route = routes[0];
            final legs = route['legs'] as dart_js.JsArray;
            if (legs.isEmpty) {
              completer.complete(null);
              return;
            }

            final leg = legs[0];
            final steps = leg['steps'] as dart_js.JsArray;

            final List<LatLng> points = [];
            for (var i = 0; i < steps.length; i++) {
              final step = steps[i];
              final path = step['path'] as dart_js.JsArray;
              for (var j = 0; j < path.length; j++) {
                final latLng = path[j];
                points.add(
                  LatLng(
                    (latLng.callMethod('lat', []) as num).toDouble(),
                    (latLng.callMethod('lng', []) as num).toDouble(),
                  ),
                );
              }
            }

            completer.complete({
              'points': points,
              'distance': (leg['distance'] != null)
                  ? leg['distance']['text']
                  : '---',
              'duration': (leg['duration'] != null)
                  ? leg['duration']['text']
                  : '---',
            });
          } else {
            debugPrint('Directions failed: $status');
            completer.complete(null);
          }
        }),
      ]);
    } catch (e) {
      print("JS Interop Error: $e");
      completer.complete(null);
    }

    return completer.future;
  }

  static Future<String?> getAddressWeb(LatLng position) async {
    if (!isSdkLoaded) return null;
    final completer = Completer<String?>();

    try {
      final google = dart_js.context['google'];
      final maps = google['maps'];
      final geocoder = dart_js.JsObject(maps['Geocoder'] as dart_js.JsFunction);

      final request = dart_js.JsObject.jsify({
        'location': {'lat': position.latitude, 'lng': position.longitude},
      });

      geocoder.callMethod('geocode', [
        request,
        dart_js.allowInterop((results, status) {
          if (status == 'OK') {
            final resultsArray = results as dart_js.JsArray;
            if (resultsArray.isNotEmpty) {
              completer.complete(
                resultsArray[0]['formatted_address'] as String,
              );
            } else {
              completer.complete(null);
            }
          } else {
            debugPrint('Geocoding failed: $status');
            completer.complete(null);
          }
        }),
      ]);
    } catch (e) {
      debugPrint("JS Geocoding Error: $e");
      completer.complete(null);
    }

    return completer.future;
  }

  static Future<List<Map<String, String>>> getAutocompleteWeb(
    String input,
  ) async {
    if (input.isEmpty || !isSdkLoaded) return [];
    final completer = Completer<List<Map<String, String>>>();

    try {
      final google = dart_js.context['google'];
      final maps = google['maps'];
      final places = maps['places'];
      if (places == null) {
        debugPrint("Places library not loaded");
        return [];
      }

      final autocompleteService = dart_js.JsObject(
        places['AutocompleteService'] as dart_js.JsFunction,
      );

      final request = dart_js.JsObject.jsify({
        'input': input,

      });

      autocompleteService.callMethod('getPlacePredictions', [
        request,
        dart_js.allowInterop((predictions, status) {
          if (status == 'OK') {
            final predsArray = predictions as dart_js.JsArray;
            final List<Map<String, String>> results = [];
            for (var i = 0; i < predsArray.length; i++) {
              final pred = predsArray[i];
              results.add({
                'description': pred['description'] as String,
                'placeId': pred['place_id'] as String,
              });
            }
            completer.complete(results);
          } else {
            completer.complete([]);
          }
        }),
      ]);
    } catch (e) {
      debugPrint("JS Autocomplete Error: $e");
      completer.complete([]);
    }

    return completer.future;
  }

  static Future<LatLng?> getLatLngFromPlaceIdWeb(String placeId) async {
    if (!isSdkLoaded) return null;
    final completer = Completer<LatLng?>();

    try {
      final google = dart_js.context['google'];
      final maps = google['maps'];
      final geocoder = dart_js.JsObject(maps['Geocoder'] as dart_js.JsFunction);

      final request = dart_js.JsObject.jsify({'placeId': placeId});

      geocoder.callMethod('geocode', [
        request,
        dart_js.allowInterop((results, status) {
          if (status == 'OK') {
            final resultsArray = results as dart_js.JsArray;
            if (resultsArray.isNotEmpty) {
              final location = resultsArray[0]['geometry']['location'];
              completer.complete(
                LatLng(
                  (location.callMethod('lat', []) as num).toDouble(),
                  (location.callMethod('lng', []) as num).toDouble(),
                ),
              );
            } else {
              completer.complete(null);
            }
          } else {
            completer.complete(null);
          }
        }),
      ]);
    } catch (e) {
      debugPrint("JS PlaceId to LatLng Error: $e");
      completer.complete(null);
    }

    return completer.future;
  }
}
