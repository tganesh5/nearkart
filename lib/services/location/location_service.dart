import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logger/logger.dart';
import '../../core/exceptions/app_exception.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? pincode;
  final String? locality;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.pincode,
    this.locality,
  });
}

class LocationService {
  final Logger _logger = Logger();
  final Geocoding _geocoding = Geocoding();

  static const _fixTimeout = Duration(seconds: 10);
  static const _geocodeTimeout = Duration(seconds: 5);

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Location services are disabled. Please enable GPS.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permission permanently denied. Please enable in Settings.',
      );
    }

    return true;
  }

  Future<LocationData> getCurrentLocation() async {
    try {
      await checkPermission();
      final position = await _readPosition();
      _logger.i('Current location resolved successfully');
      return describeCoordinates(position.latitude, position.longitude);
    } on LocationException {
      rethrow;
    } catch (e) {
      _logger.e('Failed to get location', error: e);
      throw LocationException('Failed to get your location', originalError: e);
    }
  }

  /// Prefers the cached fix. Requesting a live fix makes geolocator start and
  /// then stop location updates, and its Android teardown calls
  /// LocationManager.removeNmeaListener on the platform main thread — a
  /// synchronous binder call that can wedge for tens of seconds and trigger an
  /// ANR. A cached fix never touches that path.
  Future<Position> _readPosition() async {
    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) return cached;
    } catch (e) {
      _logger.w('No cached position available', error: e);
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: _fixTimeout,
      ),
    );
  }

  /// Resolves a human-readable address for a point. Coordinates are always
  /// returned, so an unavailable or slow geocoder degrades the result rather
  /// than failing the call.
  Future<LocationData> describeCoordinates(
    double latitude,
    double longitude,
  ) async {
    final place = await _reverseGeocode(latitude, longitude);

    return LocationData(
      latitude: latitude,
      longitude: longitude,
      address: place == null
          ? null
          : [
              place.street,
              place.subLocality,
              place.locality,
              place.administrativeArea,
              place.postalCode,
            ].where((s) => s != null && s.isNotEmpty).join(', '),
      city: place?.locality ?? place?.administrativeArea,
      pincode: place?.postalCode,
      locality: place?.subLocality ?? place?.locality,
    );
  }

  /// Turns typed text — a place, an area, a street or just a pincode — into a
  /// point on the map.
  ///
  /// Returns null when the geocoder is unavailable or finds nothing, so the
  /// caller can fall back to letting the user place the pin by hand instead of
  /// showing an error they cannot act on.
  Future<LocationData?> locateAddress(String query) async {
    final text = query.trim();
    if (text.isEmpty) return null;

    try {
      // Emulators and de-Googled devices ship without a geocoder backend.
      if (!await _geocoding.isPresent().timeout(_geocodeTimeout)) {
        return null;
      }
      final results = await _geocoding
          .locationFromAddress(text)
          .timeout(_geocodeTimeout);
      if (results.isEmpty) return null;

      final match = results.first;
      return describeCoordinates(match.latitude, match.longitude);
    } catch (e) {
      _logger.w('Could not locate "$text"', error: e);
      return null;
    }
  }

  Future<Placemark?> _reverseGeocode(double latitude, double longitude) async {
    try {
      // Emulators and de-Googled devices ship without a geocoder backend.
      if (!await _geocoding.isPresent().timeout(_geocodeTimeout)) {
        return null;
      }
      final placemarks = await _geocoding
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(_geocodeTimeout);
      return placemarks.isEmpty ? null : placemarks.first;
    } catch (e) {
      _logger.w('Reverse geocoding unavailable', error: e);
      return null;
    }
  }

  /// Calculate distance between two points in kilometers (Haversine formula)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Check if a store is within delivery radius
  static bool isWithinDeliveryRadius({
    required double userLat,
    required double userLon,
    required double storeLat,
    required double storeLon,
    required double radiusKm,
  }) {
    return calculateDistance(userLat, userLon, storeLat, storeLon) <= radiusKm;
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
