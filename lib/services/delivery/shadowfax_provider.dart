import 'dart:convert';
import 'package:logger/logger.dart';
import '../../core/config/env_config.dart';
import '../../models/order_model.dart';
import 'delivery_provider.dart';

/// Shadowfax delivery integration for Bangalore & Mysore.
/// Docs: https://shadowfax.in/api (B2B partner API)
///
/// Supports:
/// - Hyperlocal delivery (10 min - 2 hours)
/// - Same-day delivery
/// - Reverse logistics (for returns)
/// - Real-time tracking
///
/// Coverage: 2,500+ cities, 15,656 PIN codes including Bangalore & Mysore
class ShadowfaxProvider extends DeliveryProvider {
  final Logger _logger = Logger();

  @override
  String get name => 'Shadowfax';

  @override
  List<String> get supportedCities => [
    'Bangalore', 'Bengaluru',
    'Mysore', 'Mysuru',
  ];

  String get _baseUrl {
    if (EnvConfig.isProd) {
      return 'https://api.shadowfax.in/v1';
    }
    return 'https://staging-api.shadowfax.in/v1';
  }

  String get _apiToken {
    return const String.fromEnvironment(
      'SHADOWFAX_TOKEN',
      defaultValue: '',
    );
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Token $_apiToken',
  };

  @override
  Future<DeliveryQuote> getQuote({
    required LatLng pickup,
    required LatLng drop,
  }) async {
    _logger.i('Shadowfax: Requesting delivery quote');

    final requestBody = {
      'pickup_lat': pickup.latitude,
      'pickup_lng': pickup.longitude,
      'drop_lat': drop.latitude,
      'drop_lng': drop.longitude,
      'service_type': 'hyperlocal',
    };

    _logger.d('Shadowfax quote request: ${jsonEncode(requestBody)}');

    // Production HTTP call:
    // final response = await http.post(
    //   Uri.parse('$_baseUrl/delivery/quote'),
    //   headers: _headers,
    //   body: jsonEncode(requestBody),
    // );
    // final data = jsonDecode(response.body);
    // return DeliveryQuote(
    //   quoteId: data['quote_id'],
    //   providerName: name,
    //   estimatedFare: data['estimated_cost'].toDouble(),
    //   estimatedTime: '${data['eta_minutes']} mins',
    //   distanceKm: data['distance_km'].toDouble(),
    // );

    final distance = _calculateDistance(pickup, drop);
    final fare = _estimateFare(distance);

    return DeliveryQuote(
      quoteId: 'SF-QT-${DateTime.now().millisecondsSinceEpoch}',
      providerName: name,
      estimatedFare: fare,
      estimatedTime: '${_estimateTime(distance)} mins',
      distanceKm: distance,
    );
  }

  @override
  Future<DeliveryTracking> createOrder({
    required String orderId,
    required String quoteId,
    required DeliveryAddress pickup,
    required DeliveryAddress drop,
  }) async {
    _logger.i('Shadowfax: Creating delivery for NearKart order #$orderId');

    final requestBody = {
      'client_order_id': orderId,
      'quote_id': quoteId,
      'service_type': 'hyperlocal',
      'pickup': {
        'name': pickup.name,
        'phone': pickup.phone,
        'address': pickup.address,
        'city': pickup.city,
        'pincode': pickup.pincode,
        'lat': pickup.location.latitude,
        'lng': pickup.location.longitude,
      },
      'drop': {
        'name': drop.name,
        'phone': drop.phone,
        'address': drop.address,
        'city': drop.city,
        'pincode': drop.pincode,
        'lat': drop.location.latitude,
        'lng': drop.location.longitude,
      },
      'order_details': {
        'order_value': 0,
        'payment_mode': 'prepaid',
        'description': 'NearKart order #$orderId',
      },
    };

    _logger.d('Shadowfax create request: ${jsonEncode(requestBody)}');

    // Production HTTP call:
    // final response = await http.post(
    //   Uri.parse('$_baseUrl/delivery/create'),
    //   headers: _headers,
    //   body: jsonEncode(requestBody),
    // );
    // final data = jsonDecode(response.body);
    // return DeliveryTracking(
    //   porterOrderId: data['sf_order_id'],
    //   currentStatus: 'assigned',
    //   driverName: data['rider_name'],
    //   driverPhone: data['rider_phone'],
    //   trackingUrl: data['tracking_url'],
    //   estimatedDeliveryTime: '${data['eta_minutes']} mins',
    // );

    final sfOrderId = 'SF-${DateTime.now().millisecondsSinceEpoch}';

    return DeliveryTracking(
      porterOrderId: sfOrderId,
      currentStatus: 'looking_for_rider',
      estimatedDeliveryTime: '30-45 mins',
    );
  }

  @override
  Future<DeliveryTracking> getStatus(String deliveryOrderId) async {
    _logger.i('Shadowfax: Checking status for $deliveryOrderId');

    // Production HTTP call:
    // final response = await http.get(
    //   Uri.parse('$_baseUrl/delivery/status/$deliveryOrderId'),
    //   headers: _headers,
    // );
    // final data = jsonDecode(response.body);

    return DeliveryTracking(
      porterOrderId: deliveryOrderId,
      currentStatus: 'in_transit',
      driverName: 'Delivery Partner',
      driverPhone: '+91 XXXXXXXXXX',
      trackingUrl: 'https://track.shadowfax.in/$deliveryOrderId',
      estimatedDeliveryTime: '15 mins',
    );
  }

  @override
  Future<bool> cancelOrder(String deliveryOrderId) async {
    _logger.i('Shadowfax: Cancelling delivery $deliveryOrderId');

    // Production HTTP call:
    // final response = await http.post(
    //   Uri.parse('$_baseUrl/delivery/cancel/$deliveryOrderId'),
    //   headers: _headers,
    // );
    // return response.statusCode == 200;

    return true;
  }

  /// Create a reverse pickup for returns
  Future<DeliveryTracking> createReturnPickup({
    required String orderId,
    required DeliveryAddress customerAddress,
    required DeliveryAddress storeAddress,
  }) async {
    _logger.i('Shadowfax: Creating return pickup for order #$orderId');

    // Reverse logistics — pick from customer, deliver to store
    return createOrder(
      orderId: 'RTN-$orderId',
      quoteId: 'SF-RTN-${DateTime.now().millisecondsSinceEpoch}',
      pickup: customerAddress,
      drop: storeAddress,
    );
  }

  double _calculateDistance(LatLng from, LatLng to) {
    final latDiff = (from.latitude - to.latitude).abs();
    final lngDiff = (from.longitude - to.longitude).abs();
    return double.parse(((latDiff + lngDiff) * 111).toStringAsFixed(1));
  }

  double _estimateFare(double distanceKm) {
    const baseFare = 25.0;
    const perKmRate = 10.0;
    const minFare = 30.0;
    final fare = baseFare + (distanceKm * perKmRate);
    return fare < minFare ? minFare : double.parse(fare.toStringAsFixed(0));
  }

  int _estimateTime(double distanceKm) {
    if (distanceKm <= 3) return 20;
    if (distanceKm <= 5) return 30;
    if (distanceKm <= 10) return 45;
    return 60;
  }
}
