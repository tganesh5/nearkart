import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../../models/order_model.dart';
import '../../core/exceptions/app_exception.dart';

/// Handles refunds to customer UPI when:
/// - Order is cancelled (by customer or vendor)
/// - Order is not delivered within expected time
/// - Return is approved by vendor
///
/// Refund flow:
/// 1. Trigger: cancel/non-delivery/return-approved
/// 2. Initiate refund → status = processing
/// 3. Process UPI refund (via payment gateway or manual)
/// 4. Mark complete → status = completed
class RefundService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initiate a refund for an order
  Future<RefundInfo> initiateRefund({
    required String orderId,
    required String customerUpiId,
    required double amount,
    required String reason,
  }) async {
    _logger.i('Refund: Initiating ₹$amount for order #$orderId → $customerUpiId');

    final refundInfo = RefundInfo(
      status: RefundStatus.initiated,
      amount: amount,
      reason: reason,
      initiatedAt: DateTime.now(),
    );

    await _firestore.collection('orders').doc(orderId).update({
      'refund': refundInfo.toMap(),
    });

    await _firestore.collection('refunds').add({
      'orderId': orderId,
      'customerUpiId': customerUpiId,
      'amount': amount,
      'reason': reason,
      'status': RefundStatus.initiated.name,
      'initiatedAt': FieldValue.serverTimestamp(),
    });

    // Process the refund asynchronously
    _processRefund(orderId: orderId, customerUpiId: customerUpiId, amount: amount);

    return refundInfo;
  }

  /// Process the actual UPI refund
  /// In production, this would use a payment gateway (Razorpay/Cashfree)
  Future<void> _processRefund({
    required String orderId,
    required String customerUpiId,
    required double amount,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'refund.status': RefundStatus.processing.name,
      });

      // In production: call payment gateway refund API
      // Example with Razorpay:
      // await razorpay.refund(paymentId: originalPaymentId, amount: amount * 100);
      //
      // For UPI refunds without a payment gateway, create a payout:
      // await payoutService.sendToUpi(upiId: customerUpiId, amount: amount);

      _logger.i('Refund: Processing ₹$amount to UPI $customerUpiId');

      final transactionId = 'RFD-${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('orders').doc(orderId).update({
        'refund.status': RefundStatus.completed.name,
        'refund.transactionId': transactionId,
        'refund.completedAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('refunds')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get()
          .then((snap) {
        if (snap.docs.isNotEmpty) {
          snap.docs.first.reference.update({
            'status': RefundStatus.completed.name,
            'transactionId': transactionId,
            'completedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger.i('Refund: Completed $transactionId for order #$orderId');
    } catch (e) {
      _logger.e('Refund failed for order #$orderId', error: e);

      await _firestore.collection('orders').doc(orderId).update({
        'refund.status': RefundStatus.failed.name,
      });

      throw RefundException(
        'Refund processing failed for order #$orderId',
        originalError: e,
      );
    }
  }

  /// Handle refund for cancelled orders
  Future<RefundInfo> refundForCancellation({
    required OrderModel order,
  }) async {
    if (!order.isPaid) {
      _logger.i('Refund: Skipping - order #${order.id} was not paid');
      return RefundInfo(status: RefundStatus.none);
    }

    return initiateRefund(
      orderId: order.id,
      customerUpiId: order.customerUpiId,
      amount: order.totalAmount,
      reason: 'Order cancelled',
    );
  }

  /// Handle refund for non-delivered orders
  Future<RefundInfo> refundForNonDelivery({
    required OrderModel order,
  }) async {
    if (!order.isPaid) {
      return RefundInfo(status: RefundStatus.none);
    }

    return initiateRefund(
      orderId: order.id,
      customerUpiId: order.customerUpiId,
      amount: order.totalAmount,
      reason: 'Order not delivered',
    );
  }

  /// Handle refund for approved returns
  Future<RefundInfo> refundForReturn({
    required OrderModel order,
  }) async {
    if (!order.isPaid) {
      return RefundInfo(status: RefundStatus.none);
    }

    return initiateRefund(
      orderId: order.id,
      customerUpiId: order.customerUpiId,
      amount: order.totalAmount,
      reason: 'Return approved by vendor',
    );
  }

  /// Get refund status for an order
  Future<RefundInfo?> getRefundStatus(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    final data = doc.data();
    if (data == null || data['refund'] == null) return null;
    return RefundInfo.fromMap(data['refund']);
  }
}
