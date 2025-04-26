import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const _storage = FlutterSecureStorage();
  static const _locationKey = 'last_known_location';
  static const _routeKey = 'last_known_route';
  static const _locationTimeout = Duration(seconds: 10);

  static const String _lastKnownLocationKey = 'last_known_location';
  static const String _lastKnownRouteKey = 'last_known_route';
  static SharedPreferences? _prefs;
  static StreamController<Position>? _locationController;
  static Stream<Position>? _locationStream;

  static Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permission
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current location with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _locationTimeout,
      ).timeout(_locationTimeout);

      // Cache the location
      await _cacheLocation(position);

      return position;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      // Try to get last known location from cache
      return await getLastKnownLocation();
    }
  }

  Future<void> _cacheLocation(Position position) async {
    try {
      await _storage.write(
        key: _locationKey,
        value: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': position.timestamp.millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('Error caching location: $e');
    }
  }

  static Future<Position?> getLastKnownLocation() async {
    try {
      final cached = await _storage.read(key: _locationKey);
      if (cached == null) return null;

      final data = jsonDecode(cached);
      return Position(
        latitude: data['latitude'],
        longitude: data['longitude'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp']),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    } catch (e) {
      debugPrint('Error getting last known location: $e');
      return null;
    }
  }

  static Future<void> cacheLastKnownLocation(LatLng location) async {
    try {
      await _storage.write(
        key: _locationKey,
        value: jsonEncode({
          'latitude': location.latitude,
          'longitude': location.longitude,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('Error caching location: $e');
    }
  }

  static Future<void> cacheLastKnownRoute(List<LatLng> route) async {
    try {
      await _storage.write(
        key: _routeKey,
        value: jsonEncode(
          route
              .map(
                (point) => {
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                },
              )
              .toList(),
        ),
      );
    } catch (e) {
      debugPrint('Error caching route: $e');
    }
  }

  static Future<List<LatLng>?> getLastKnownRoute() async {
    try {
      final cached = await _storage.read(key: _routeKey);
      if (cached == null) return null;

      final data = jsonDecode(cached) as List;
      return data
          .map((point) => LatLng(point['latitude'], point['longitude']))
          .toList();
    } catch (e) {
      debugPrint('Error getting last known route: $e');
      return null;
    }
  }

  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  static bool isWithinRadius(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
    double radiusInMeters,
  ) {
    final distance = calculateDistance(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    return distance <= radiusInMeters;
  }

  Future<Position> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled. Please enable location services in your device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are required to use the map.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied. Please enable them in your device settings.',
        );
      }

      // Try to get last known position first (skip on web)
      if (!kIsWeb) {
        try {
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            await cacheLastKnownLocation(
              LatLng(lastPosition.latitude, lastPosition.longitude),
            );
            return lastPosition;
          }
        } catch (e) {
          debugPrint('Error getting last known position: $e');
        }
      }

      // Get current position with longer timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      await cacheLastKnownLocation(
        LatLng(position.latitude, position.longitude),
      );
      return position;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      if (e is TimeoutException) {
        throw Exception(
          'Location request timed out. Please check your internet connection and try again.',
        );
      }
      throw Exception('Failed to get current location: ${e.toString()}');
    }
  }

  Future<LatLng> getCurrentLatLng() async {
    final position = await getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  static Stream<Position> getLocationStream() {
    if (_locationStream == null) {
      _locationController = StreamController<Position>.broadcast();
      _locationStream = _locationController!.stream;

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
          timeLimit: Duration(seconds: 30),
        ),
      ).listen(
        (Position position) {
          _locationController?.add(position);
          cacheLastKnownLocation(LatLng(position.latitude, position.longitude));
        },
        onError: (e) {
          debugPrint('Error in location stream: $e');
          _locationController?.addError(e);
        },
      );
    }
    return _locationStream!;
  }

  static void dispose() {
    _locationController?.close();
    _locationController = null;
    _locationStream = null;
  }
}
