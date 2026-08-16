import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/exceptions/app_exception.dart';

enum PaymentMethod { upi, cod }

enum PaymentStatus { pending, success, failed, cancelled }

class PaymentResult {
  final PaymentStatus status;
  final String? transactionId;
  final String? errorMessage;

  PaymentResult({
    required this.status,
    this.transactionId,
    this.errorMessage,
  });
}

class PlatformFeeConfig {
  /// Percentage charged on top of order amount to customer
  /// e.g., 0.5 means 0.5% convenience fee
  final double percentage;

  const PlatformFeeConfig({this.percentage = 0.5});

  /// Calculate convenience fee for an order
  /// ₹100 order → ₹0.50 fee → Customer pays ₹100.50
  double calculateFee(double orderAmount) {
    final fee = orderAmount * (percentage / 100);
    return double.parse(fee.toStringAsFixed(2));
  }

  /// Total amount customer pays (order + fee)
  double customerPays(double orderAmount) {
    return orderAmount + calculateFee(orderAmount);
  }
}

class PaymentService {
  final Logger _logger = Logger();
  final PlatformFeeConfig feeConfig;

  PaymentService({this.feeConfig = const PlatformFeeConfig()});

  /// Initiate UPI payment to vendor
  /// Customer pays: orderAmount + platform fee
  /// Vendor receives: orderAmount (direct to their UPI)
  /// NearKart receives: platform fee (separate transaction or collected periodically)
  Future<PaymentResult> payVendorViaUpi({
    required String vendorUpiId,
    required String vendorName,
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      final upiUrl = _buildUpiUrl(
        upiId: vendorUpiId,
        name: vendorName,
        amount: orderAmount,
        transactionRef: orderId,
        note: 'Order #$orderId via NearKart',
      );

      final uri = Uri.parse(upiUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.i('UPI payment: ₹$orderAmount to $vendorUpiId (order: $orderId)');
        return PaymentResult(status: PaymentStatus.pending);
      } else {
        throw PaymentException('No UPI app found on this device');
      }
    } catch (e) {
      if (e is PaymentException) rethrow;
      _logger.e('UPI payment failed', error: e);
      throw PaymentException('Failed to open UPI app', originalError: e);
    }
  }

  /// Collect platform fee from customer to NearKart UPI
  Future<PaymentResult> collectPlatformFee({
    required String nearkartUpiId,
    required double orderAmount,
    required String orderId,
  }) async {
    final fee = feeConfig.calculateFee(orderAmount);

    try {
      final upiUrl = _buildUpiUrl(
        upiId: nearkartUpiId,
        name: 'NearKart',
        amount: fee,
        transactionRef: 'FEE-$orderId',
        note: 'Convenience fee for order #$orderId',
      );

      final uri = Uri.parse(upiUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.i('Platform fee: ₹$fee for order $orderId');
        return PaymentResult(status: PaymentStatus.pending);
      } else {
        throw PaymentException('No UPI app found');
      }
    } catch (e) {
      if (e is PaymentException) rethrow;
      throw PaymentException('Failed to collect platform fee', originalError: e);
    }
  }

  /// Get full payment breakdown for checkout display
  Map<String, double> getCheckoutBreakdown(double orderAmount) {
    final fee = feeConfig.calculateFee(orderAmount);
    return {
      'orderAmount': orderAmount,
      'platformFeePercent': feeConfig.percentage,
      'platformFee': fee,
      'totalCustomerPays': orderAmount + fee,
    };
  }

  String _buildUpiUrl({
    required String upiId,
    required String name,
    required double amount,
    required String transactionRef,
    String? note,
  }) {
    final params = {
      'pa': upiId,
      'pn': name,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tr': transactionRef,
      'tn': note ?? 'NearKart Payment',
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'upi://pay?$queryString';
  }
}
