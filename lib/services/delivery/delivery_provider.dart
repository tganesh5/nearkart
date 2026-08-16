import '../../models/order_model.dart';

/// Abstract delivery provider interface.
/// Implement this for each delivery partner (Shadowfax, Porter, Dunzo, etc.)
abstract class DeliveryProvider {
  String get name;
  List<String> get supportedCities;

  bool isAvailable(String city) {
    return supportedCities.any(
      (c) => city.toLowerCase().contains(c.toLowerCase()),
    );
  }

  Future<DeliveryQuote> getQuote({
    required LatLng pickup,
    required LatLng drop,
  });

  Future<DeliveryTracking> createOrder({
    required String orderId,
    required String quoteId,
    required DeliveryAddress pickup,
    required DeliveryAddress drop,
  });

  Future<DeliveryTracking> getStatus(String deliveryOrderId);

  Future<bool> cancelOrder(String deliveryOrderId);
}

/// Delivery quote returned by any provider
class DeliveryQuote {
  final String quoteId;
  final String providerName;
  final double estimatedFare;
  final String estimatedTime;
  final double distanceKm;
  final String currency;

  DeliveryQuote({
    required this.quoteId,
    required this.providerName,
    required this.estimatedFare,
    required this.estimatedTime,
    required this.distanceKm,
    this.currency = 'INR',
  });
}

/// Lat/Lng coordinates
class LatLng {
  final double latitude;
  final double longitude;

  LatLng({required this.latitude, required this.longitude});
}

/// Address with contact info for pickup/drop
class DeliveryAddress {
  final String name;
  final String phone;
  final String address;
  final String city;
  final String pincode;
  final LatLng location;

  DeliveryAddress({
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    this.pincode = '',
    required this.location,
  });
}
