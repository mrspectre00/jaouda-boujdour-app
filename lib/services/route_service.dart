import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  String? _apiKey;
  bool _isInitialized = false;
  final String _baseUrl = 'https://api.openrouteservice.org';

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Try to get API key from .env file first
      _apiKey =
          dotenv.env['OPENROUTESERVICE_API_KEY'] ??
          dotenv.env['OPENROUTE_API_KEY'];

      // If not in .env, try environment variable
      if (_apiKey == null || _apiKey!.isEmpty) {
        _apiKey = const String.fromEnvironment('OPENROUTESERVICE_API_KEY');
      }

      // If not in environment, try secure storage
      if (_apiKey == null || _apiKey!.isEmpty) {
        _apiKey = await const FlutterSecureStorage().read(
          key: 'openroute_api_key',
        );
      }

      if (_apiKey == null || _apiKey!.isEmpty) {
        throw Exception(
          'OpenRouteService API key not found. Please set OPENROUTESERVICE_API_KEY in environment variables or secure storage',
        );
      }

      _isInitialized = true;
      debugPrint('RouteService initialized successfully with API key');
    } catch (e) {
      debugPrint('Failed to initialize RouteService: $e');
      rethrow;
    }
  }

  Future<List<LatLng>> generateRoute(LatLng start, LatLng end) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('OpenRouteService API key not initialized');
    }

    try {
      debugPrint('Generating route with key length: ${_apiKey!.length}');

      // Format according to OpenRouteService API - POST request with coordinates in the body
      final response = await http.post(
        Uri.parse('$_baseUrl/v2/directions/driving-car/geojson'),
        headers: {
          'Authorization': _apiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coordinates': [
            [start.longitude, start.latitude],
            [end.longitude, end.latitude],
          ],
        }),
      );

      debugPrint('Route response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('Error response body: ${response.body}');
        throw Exception(
          'Failed to generate route: ${response.statusCode} - ${response.body}',
        );
      }

      // Log preview of response
      final previewLength = min(200, response.body.length);
      debugPrint(
        'Route response body preview: ${response.body.substring(0, previewLength)}...',
      );

      // Parse JSON response
      final data = jsonDecode(response.body);
      if (data['features'] == null || data['features'].isEmpty) {
        throw Exception('No route found between the specified points');
      }

      final coordinates =
          data['features'][0]['geometry']['coordinates'] as List;
      if (coordinates.isEmpty) {
        throw Exception('No route coordinates found');
      }

      debugPrint(
        'Route data received successfully with ${coordinates.length} points',
      );
      return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
    } catch (e) {
      debugPrint('Error generating route: $e');
      rethrow;
    }
  }

  Future<List<LatLng>> optimizeRoute(List<LatLng> locations) async {
    if (_apiKey == null) {
      await initialize();
    }

    if (locations.length < 2) {
      throw Exception(
        'At least two locations are required for route optimization',
      );
    }

    final url = Uri.parse('https://api.openrouteservice.org/v2/optimization');
    final headers = {
      'Authorization': _apiKey!,
      'Content-Type': 'application/json',
    };

    // Format coordinates as numbers
    final jobs =
        locations
            .map(
              (loc) => {
                'location': [loc.longitude, loc.latitude],
                'id': locations.indexOf(loc).toString(),
              },
            )
            .toList();

    final vehicles = [
      {
        'id': '1',
        'start': [locations.first.longitude, locations.first.latitude],
        'end': [locations.last.longitude, locations.last.latitude],
      },
    ];

    final body = jsonEncode({
      'jobs': jobs,
      'vehicles': vehicles,
      'geometry': true,
    });

    debugPrint('Optimization request body: $body');

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0]['steps'] as List;
        return route.map((step) {
          final location = step['location'] as List;
          final lat =
              location[1] is int
                  ? (location[1] as int).toDouble()
                  : location[1] as double;
          final lng =
              location[0] is int
                  ? (location[0] as int).toDouble()
                  : location[0] as double;
          return LatLng(lat, lng);
        }).toList();
      } else {
        debugPrint(
          'Route optimization failed with status: ${response.statusCode}',
        );
        debugPrint('Response body: ${response.body}');
        throw Exception('Failed to optimize route: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error optimizing route: $e');
      throw Exception('Failed to optimize route: $e');
    }
  }

  List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;

      // Decode latitude
      do {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (result & 0x20 != 0);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      // Decode longitude
      do {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (result & 0x20 != 0);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add([lat / 1E5, lng / 1E5]);
    }

    return points;
  }
}
