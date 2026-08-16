import 'package:logger/logger.dart';
import '../../core/exceptions/app_exception.dart';
import '../../models/order_model.dart';
import 'delivery_provider.dart';
import 'shadowfax_provider.dart';

/// Orchestrates delivery across multiple providers.
///
/// Current provider: Shadowfax (Bangalore + Mysore)
///
/// To add a new provider:
/// 1. Implement DeliveryProvider interface
/// 2. Register it in [_providers] list
/// 3. The service auto-selects the best available provider per city
class DeliveryService {
  final Logger _logger = Logger();

  /// Registered delivery providers (in priority order)
  final List<DeliveryProvider> _providers = [
    ShadowfaxProvider(),
    // Future: PorterProvider(), DunzoProvider(), etc.
  ];

  /// Get the best available provider for a given city
  DeliveryProvider? getProviderForCity(String city) {
    for (final provider in _providers) {
      if (provider.isAvailable(city)) {
        return provider;
      }
    }
    return null;
  }

  /// Check if delivery is available in the given city
  bool isDeliveryAvailable(String city) {
    return getProviderForCity(city) != null;
  }

  /// Get delivery quote — picks the best provider for the city
  Future<DeliveryQuote> getQuote({
    required String city,
    required LatLng pickup,
    required LatLng drop,
  }) async {
    final provider = getProviderForCity(city);
    if (provider == null) {
      throw DeliveryException(
        'Delivery not available in $city. We currently serve Bangalore and Mysore.',
      );
    }

    _logger.i('Delivery: Using ${provider.name} for $city');
    return provider.getQuote(pickup: pickup, drop: drop);
  }

  /// Get quotes from ALL available providers (for comparison)
  Future<List<DeliveryQuote>> getAllQuotes({
    required String city,
    required LatLng pickup,
    required LatLng drop,
  }) async {
    final available = _providers.where((p) => p.isAvailable(city));
    if (available.isEmpty) {
      throw DeliveryException('No delivery partners available in $city');
    }

    final quotes = <DeliveryQuote>[];
    for (final provider in available) {
      try {
        final quote = await provider.getQuote(pickup: pickup, drop: drop);
        quotes.add(quote);
      } catch (e) {
        _logger.w('${provider.name} quote failed: $e');
      }
    }

    if (quotes.isEmpty) {
      throw DeliveryException('All delivery partners failed to provide quotes');
    }

    quotes.sort((a, b) => a.estimatedFare.compareTo(b.estimatedFare));
    return quotes;
  }

  /// Create a delivery order with the specified provider
  Future<DeliveryTracking> dispatchDelivery({
    required String orderId,
    required String city,
    required DeliveryQuote quote,
    required DeliveryAddress pickup,
    required DeliveryAddress drop,
  }) async {
    final provider = _providers.firstWhere(
      (p) => p.name == quote.providerName,
      orElse: () => throw DeliveryException(
        'Provider ${quote.providerName} not found',
      ),
    );

    _logger.i('Delivery: Dispatching order #$orderId via ${provider.name}');

    return provider.createOrder(
      orderId: orderId,
      quoteId: quote.quoteId,
      pickup: pickup,
      drop: drop,
    );
  }

  /// Get live delivery status
  Future<DeliveryTracking> trackDelivery({
    required String deliveryOrderId,
    required String providerName,
  }) async {
    final provider = _providers.firstWhere(
      (p) => p.name == providerName,
      orElse: () => throw DeliveryException('Provider $providerName not found'),
    );

    return provider.getStatus(deliveryOrderId);
  }

  /// Cancel a delivery
  Future<bool> cancelDelivery({
    required String deliveryOrderId,
    required String providerName,
  }) async {
    final provider = _providers.firstWhere(
      (p) => p.name == providerName,
      orElse: () => throw DeliveryException('Provider $providerName not found'),
    );

    _logger.i('Delivery: Cancelling $deliveryOrderId via ${provider.name}');
    return provider.cancelOrder(deliveryOrderId);
  }

  /// Get all supported cities across all providers
  Set<String> get allSupportedCities {
    return _providers.expand((p) => p.supportedCities).toSet();
  }

  /// Get available provider names for a city
  List<String> getAvailableProviders(String city) {
    return _providers
        .where((p) => p.isAvailable(city))
        .map((p) => p.name)
        .toList();
  }
}
