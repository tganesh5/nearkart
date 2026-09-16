import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/exceptions/app_exception.dart';

enum PaymentMethod { upi, cod }

enum PaymentStatus { pending, success, failed, cancelled }

class PaymentResult {
  final PaymentStatus status;
  final String? transactionId;
  final String? errorMessage;

  PaymentResult({required this.status, this.transactionId, this.errorMessage});
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

  /// NPCI UPI intent. The VPA (`pa`) is left unencoded — GPay and PhonePe
  /// reject `name%40bank` as the payee address.
  static String buildUpiUrl({
    required String upiId,
    required String name,
    required double amount,
    required String transactionRef,
    String? note,
  }) {
    final params = <String, String>{
      'pa': upiId.trim(),
      'pn': name,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tr': transactionRef,
      'tn': note ?? 'NearKart Payment',
    };
    final query = params.entries
        .map((entry) {
          final value = entry.key == 'pa'
              ? entry.value
              : Uri.encodeComponent(entry.value);
          return '${entry.key}=$value';
        })
        .join('&');
    return 'upi://pay?$query';
  }

  /// Opens the device UPI app. Returns false when none is installed so the
  /// caller can fall back to a QR / "I've paid" sheet.
  Future<bool> openUpiApp({
    required String vendorUpiId,
    required String vendorName,
    required double orderAmount,
    required String orderId,
  }) async {
    final uri = Uri.parse(
      buildUpiUrl(
        upiId: vendorUpiId,
        name: vendorName,
        amount: orderAmount,
        transactionRef: orderId,
        note: 'Order #$orderId via NearKart',
      ),
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (launched) {
        _logger.i(
          'UPI payment: ₹$orderAmount to $vendorUpiId (order: $orderId)',
        );
      }
      return launched;
    } catch (e) {
      _logger.w('UPI app did not open', error: e);
      return false;
    }
  }

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
    final opened = await openUpiApp(
      vendorUpiId: vendorUpiId,
      vendorName: vendorName,
      orderAmount: orderAmount,
      orderId: orderId,
    );
    if (opened) {
      return PaymentResult(status: PaymentStatus.pending);
    }
    throw PaymentException('No UPI app found on this device');
  }

  /// Collect platform fee from customer to NearKart UPI
  Future<PaymentResult> collectPlatformFee({
    required String nearkartUpiId,
    required double orderAmount,
    required String orderId,
  }) async {
    final fee = feeConfig.calculateFee(orderAmount);
    final opened = await openUpiApp(
      vendorUpiId: nearkartUpiId,
      vendorName: 'NearKart',
      orderAmount: fee,
      orderId: 'FEE-$orderId',
    );
    if (opened) {
      _logger.i('Platform fee: ₹$fee for order $orderId');
      return PaymentResult(status: PaymentStatus.pending);
    }
    throw PaymentException('No UPI app found');
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
}
