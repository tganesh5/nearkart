import 'dart:convert';
import 'package:logger/logger.dart';
import '../../core/config/env_config.dart';
import '../../models/order_model.dart';
import 'delivery_provider.dart';

/// Porter delivery provider — for future use.
/// Best for: larger/heavier items, bulk grocery orders.
/// Coverage: Bangalore (Mysore limited).
///
/// To activate: add PorterProvider() to DeliveryService._providers list
class PorterProvider extends DeliveryProvider {
  final Logger _logger = Logger();

  @override
  String get name => 'Porter';

  @override
  List<String> get supportedCities => ['Bangalore', 'Bengaluru'];

  String get _baseUrl {
    if (EnvConfig.isProd) {
      return 'https://pfe-apigw-uat.porter.in/v1';
    }
    return 'https://pfe-apigw-uat.porter.in/v1';
  }

  String get _apiKey {
    return const String.fromEnvironment(
      'PORTER_API_KEY',
      defaultValue: '',
    );
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-API-KEY': _apiKey,
  };

  @override
  Future<DeliveryQuote> getQuote({
    required LatLng pickup,
    required LatLng drop,
  }) async {
    _logger.i('Porter: Requesting delivery quote');

    final requestBody = {
      'pickup_details': {
        'lat': pickup.latitude,
        'lng': pickup.longitude,
      },
      'drop_details': {
        'lat': drop.latitude,
        'lng': drop.longitude,
      },
      'customer': {
        'name': 'NearKart',
        'mobile': {'country_code': '+91', 'number': '0000000000'},
      },
    };

    _logger.d('Porter quote request: ${jsonEncode(requestBody)}');

    // Production:
    // final response = await http.post(
    //   Uri.parse('$_baseUrl/get_quote'),
    //   headers: _headers,
    //   body: jsonEncode(requestBody),
    // );

    final distance = _calculateDistance(pickup, drop);
    final fare = _estimateFare(distance);

    return DeliveryQuote(
      quoteId: 'PT-QT-${DateTime.now().millisecondsSinceEpoch}',
      providerName: name,
      estimatedFare: fare,
      estimatedTime: '${(distance * 4).round()} mins',
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
    _logger.i('Porter: Creating delivery for NearKart order #$orderId');

    final porterOrderId = 'PT-${DateTime.now().millisecondsSinceEpoch}';

    return DeliveryTracking(
      porterOrderId: porterOrderId,
      currentStatus: 'order_placed',
      estimatedDeliveryTime: '30-45 mins',
    );
  }

  @override
  Future<DeliveryTracking> getStatus(String deliveryOrderId) async {
    _logger.i('Porter: Checking status for $deliveryOrderId');

    return DeliveryTracking(
      porterOrderId: deliveryOrderId,
      currentStatus: 'in_transit',
      driverName: 'Delivery Partner',
      driverPhone: '+91 XXXXXXXXXX',
      estimatedDeliveryTime: '15 mins',
    );
  }

  @override
  Future<bool> cancelOrder(String deliveryOrderId) async {
    _logger.i('Porter: Cancelling delivery $deliveryOrderId');
    return true;
  }

  double _calculateDistance(LatLng from, LatLng to) {
    final latDiff = (from.latitude - to.latitude).abs();
    final lngDiff = (from.longitude - to.longitude).abs();
    return (latDiff + lngDiff) * 111;
  }

  double _estimateFare(double distanceKm) {
    const baseFare = 30.0;
    const perKmRate = 12.0;
    final fare = baseFare + (distanceKm * perKmRate);
    return double.parse(fare.toStringAsFixed(0));
  }
}
