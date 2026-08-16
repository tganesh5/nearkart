import 'cart_item_model.dart';

enum OrderStatus {
  placed,
  confirmed,
  preparing,
  readyForPickup,
  outForDelivery,
  delivered,
  cancelled,
}

enum DeliveryType { pickup, delivery }

enum RefundStatus { none, initiated, processing, completed, failed }

enum ReturnStatus { none, requested, vendorReview, approved, rejected, pickedUp, refunded }

class DeliveryTracking {
  final String? porterOrderId;
  final String? driverName;
  final String? driverPhone;
  final String? trackingUrl;
  final String? estimatedDeliveryTime;
  final String? currentStatus;

  DeliveryTracking({
    this.porterOrderId,
    this.driverName,
    this.driverPhone,
    this.trackingUrl,
    this.estimatedDeliveryTime,
    this.currentStatus,
  });

  Map<String, dynamic> toMap() => {
    'porterOrderId': porterOrderId,
    'driverName': driverName,
    'driverPhone': driverPhone,
    'trackingUrl': trackingUrl,
    'estimatedDeliveryTime': estimatedDeliveryTime,
    'currentStatus': currentStatus,
  };

  factory DeliveryTracking.fromMap(Map<String, dynamic> map) {
    return DeliveryTracking(
      porterOrderId: map['porterOrderId'],
      driverName: map['driverName'],
      driverPhone: map['driverPhone'],
      trackingUrl: map['trackingUrl'],
      estimatedDeliveryTime: map['estimatedDeliveryTime'],
      currentStatus: map['currentStatus'],
    );
  }
}

class RefundInfo {
  final RefundStatus status;
  final double amount;
  final String? reason;
  final String? transactionId;
  final DateTime? initiatedAt;
  final DateTime? completedAt;

  RefundInfo({
    this.status = RefundStatus.none,
    this.amount = 0,
    this.reason,
    this.transactionId,
    this.initiatedAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'amount': amount,
    'reason': reason,
    'transactionId': transactionId,
    'initiatedAt': initiatedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory RefundInfo.fromMap(Map<String, dynamic> map) {
    return RefundInfo(
      status: RefundStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RefundStatus.none,
      ),
      amount: (map['amount'] ?? 0).toDouble(),
      reason: map['reason'],
      transactionId: map['transactionId'],
      initiatedAt: map['initiatedAt'] != null
          ? DateTime.parse(map['initiatedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
    );
  }
}

class ReturnInfo {
  final ReturnStatus status;
  final String? reason;
  final String? vendorRemarks;
  final DateTime? requestedAt;
  final DateTime? resolvedAt;

  ReturnInfo({
    this.status = ReturnStatus.none,
    this.reason,
    this.vendorRemarks,
    this.requestedAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'reason': reason,
    'vendorRemarks': vendorRemarks,
    'requestedAt': requestedAt?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory ReturnInfo.fromMap(Map<String, dynamic> map) {
    return ReturnInfo(
      status: ReturnStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReturnStatus.none,
      ),
      reason: map['reason'],
      vendorRemarks: map['vendorRemarks'],
      requestedAt: map['requestedAt'] != null
          ? DateTime.parse(map['requestedAt'])
          : null,
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.parse(map['resolvedAt'])
          : null,
    );
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String customerUpiId;
  final String storeId;
  final String storeName;
  final List<CartItemModel> items;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final OrderStatus status;
  final DeliveryType deliveryType;
  final String deliveryAddress;
  final String? deliveryNotes;
  final String paymentMethod;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DeliveryTracking? deliveryTracking;
  final RefundInfo refund;
  final ReturnInfo returnInfo;

  OrderModel({
    required this.id,
    required this.customerId,
    this.customerUpiId = '',
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    this.status = OrderStatus.placed,
    this.deliveryType = DeliveryType.delivery,
    required this.deliveryAddress,
    this.deliveryNotes,
    this.paymentMethod = 'COD',
    this.isPaid = false,
    required this.createdAt,
    this.deliveredAt,
    this.deliveryTracking,
    this.refund = const _DefaultRefundInfo(),
    this.returnInfo = const _DefaultReturnInfo(),
  });

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? customerUpiId,
    String? storeId,
    String? storeName,
    List<CartItemModel>? items,
    double? subtotal,
    double? deliveryFee,
    double? totalAmount,
    OrderStatus? status,
    DeliveryType? deliveryType,
    String? deliveryAddress,
    String? deliveryNotes,
    String? paymentMethod,
    bool? isPaid,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DeliveryTracking? deliveryTracking,
    RefundInfo? refund,
    ReturnInfo? returnInfo,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerUpiId: customerUpiId ?? this.customerUpiId,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      deliveryType: deliveryType ?? this.deliveryType,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryTracking: deliveryTracking ?? this.deliveryTracking,
      refund: refund ?? this.refund,
      returnInfo: returnInfo ?? this.returnInfo,
    );
  }

  bool get canCancel =>
      status == OrderStatus.placed || status == OrderStatus.confirmed;

  bool get canReturn =>
      status == OrderStatus.delivered &&
      returnInfo.status == ReturnStatus.none &&
      deliveredAt != null &&
      DateTime.now().difference(deliveredAt!).inDays <= 7;

  bool get isRefundEligible =>
      status == OrderStatus.cancelled ||
      returnInfo.status == ReturnStatus.approved;
}

class _DefaultRefundInfo implements RefundInfo {
  const _DefaultRefundInfo();

  @override
  RefundStatus get status => RefundStatus.none;
  @override
  double get amount => 0;
  @override
  String? get reason => null;
  @override
  String? get transactionId => null;
  @override
  DateTime? get initiatedAt => null;
  @override
  DateTime? get completedAt => null;
  @override
  Map<String, dynamic> toMap() => {'status': 'none', 'amount': 0};
}

class _DefaultReturnInfo implements ReturnInfo {
  const _DefaultReturnInfo();

  @override
  ReturnStatus get status => ReturnStatus.none;
  @override
  String? get reason => null;
  @override
  String? get vendorRemarks => null;
  @override
  DateTime? get requestedAt => null;
  @override
  DateTime? get resolvedAt => null;
  @override
  Map<String, dynamic> toMap() => {'status': 'none'};
}
