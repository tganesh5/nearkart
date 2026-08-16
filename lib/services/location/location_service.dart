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

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled. Please enable GPS.');
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String? address;
      String? city;
      String? pincode;
      String? locality;

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        locality = place.subLocality ?? place.locality;
        city = place.locality ?? place.administrativeArea;
        pincode = place.postalCode;
        address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
      }

      _logger.i('Location: ${position.latitude}, ${position.longitude} - $locality');

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        city: city,
        pincode: pincode,
        locality: locality,
      );
    } on LocationException {
      rethrow;
    } catch (e) {
      _logger.e('Failed to get location', error: e);
      throw LocationException('Failed to get your location', originalError: e);
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

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
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
