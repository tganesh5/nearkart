import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../../models/order_model.dart';
import 'refund_service.dart';

/// Handles return requests from customers.
///
/// Return flow:
/// 1. Customer initiates return (within 7 days of delivery)
/// 2. Vendor reviews the return request
/// 3. If approved → refund is processed to customer UPI
/// 4. If rejected → customer is notified with reason
///
/// Return policy:
/// - Products must be in original condition
/// - Return window: 7 days from delivery
/// - Vendor has 48 hours to respond
/// - If vendor doesn't respond, return is auto-approved
class ReturnService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RefundService _refundService = RefundService();

  static const int returnWindowDays = 7;
  static const int vendorResponseHours = 48;

  /// Customer initiates a return request
  Future<ReturnInfo> requestReturn({
    required String orderId,
    required String reason,
  }) async {
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }

    final orderData = orderDoc.data()!;
    final deliveredAt = orderData['deliveredAt'] as Timestamp?;

    if (deliveredAt == null) {
      throw Exception('Order has not been delivered yet');
    }

    final daysSinceDelivery =
        DateTime.now().difference(deliveredAt.toDate()).inDays;
    if (daysSinceDelivery > returnWindowDays) {
      throw Exception(
        'Return window expired. Returns must be initiated within $returnWindowDays days of delivery.',
      );
    }

    final returnInfo = ReturnInfo(
      status: ReturnStatus.requested,
      reason: reason,
      requestedAt: DateTime.now(),
    );

    await _firestore.collection('orders').doc(orderId).update({
      'returnInfo': returnInfo.toMap(),
    });

    await _firestore.collection('returns').add({
      'orderId': orderId,
      'customerId': orderData['customerId'],
      'storeId': orderData['storeId'],
      'reason': reason,
      'status': ReturnStatus.requested.name,
      'requestedAt': FieldValue.serverTimestamp(),
      'vendorDeadline': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: vendorResponseHours)),
      ),
    });

    _logger.i('Return: Request initiated for order #$orderId');
    return returnInfo;
  }

  /// Vendor approves a return request → triggers refund
  Future<ReturnInfo> approveReturn({
    required String orderId,
    String? vendorRemarks,
  }) async {
    final returnInfo = ReturnInfo(
      status: ReturnStatus.approved,
      vendorRemarks: vendorRemarks ?? 'Return approved',
      resolvedAt: DateTime.now(),
    );

    await _firestore.collection('orders').doc(orderId).update({
      'returnInfo.status': ReturnStatus.approved.name,
      'returnInfo.vendorRemarks': returnInfo.vendorRemarks,
      'returnInfo.resolvedAt': FieldValue.serverTimestamp(),
    });

    await _updateReturnDoc(orderId, ReturnStatus.approved, vendorRemarks);

    // Get order details for refund
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    final orderData = orderDoc.data()!;

    // Process refund to customer
    await _refundService.initiateRefund(
      orderId: orderId,
      customerUpiId: orderData['customerUpiId'] ?? '',
      amount: (orderData['totalAmount'] ?? 0).toDouble(),
      reason: 'Return approved by vendor',
    );

    _logger.i('Return: Approved for order #$orderId, refund initiated');
    return returnInfo;
  }

  /// Vendor rejects a return request
  Future<ReturnInfo> rejectReturn({
    required String orderId,
    required String vendorRemarks,
  }) async {
    final returnInfo = ReturnInfo(
      status: ReturnStatus.rejected,
      vendorRemarks: vendorRemarks,
      resolvedAt: DateTime.now(),
    );

    await _firestore.collection('orders').doc(orderId).update({
      'returnInfo.status': ReturnStatus.rejected.name,
      'returnInfo.vendorRemarks': vendorRemarks,
      'returnInfo.resolvedAt': FieldValue.serverTimestamp(),
    });

    await _updateReturnDoc(orderId, ReturnStatus.rejected, vendorRemarks);

    _logger.i('Return: Rejected for order #$orderId — $vendorRemarks');
    return returnInfo;
  }

  /// Get pending return requests for a vendor
  Future<List<Map<String, dynamic>>> getPendingReturns(String storeId) async {
    final snapshot = await _firestore
        .collection('returns')
        .where('storeId', isEqualTo: storeId)
        .where('status', isEqualTo: ReturnStatus.requested.name)
        .orderBy('requestedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Get return history for a customer
  Future<List<Map<String, dynamic>>> getCustomerReturns(
    String customerId,
  ) async {
    final snapshot = await _firestore
        .collection('returns')
        .where('customerId', isEqualTo: customerId)
        .orderBy('requestedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Auto-approve returns where vendor hasn't responded within deadline
  Future<void> autoApproveExpiredReturns() async {
    final now = Timestamp.now();
    final snapshot = await _firestore
        .collection('returns')
        .where('status', isEqualTo: ReturnStatus.requested.name)
        .where('vendorDeadline', isLessThan: now)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      await approveReturn(
        orderId: data['orderId'],
        vendorRemarks: 'Auto-approved: vendor did not respond within 48 hours',
      );
    }

    if (snapshot.docs.isNotEmpty) {
      _logger.i('Return: Auto-approved ${snapshot.docs.length} expired returns');
    }
  }

  Future<void> _updateReturnDoc(
    String orderId,
    ReturnStatus status,
    String? remarks,
  ) async {
    final snap = await _firestore
        .collection('returns')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({
        'status': status.name,
        'vendorRemarks': remarks,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
