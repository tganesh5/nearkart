import 'package:cloud_firestore/cloud_firestore.dart';

class StoreModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String category;
  final String phone;
  final String address;
  final String? city;
  final String? pincode;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? bannerUrl;
  final double rating;
  final int totalRatings;
  final bool isOpen;
  final String openTime;
  final String closeTime;
  final bool offersDelivery;
  final double deliveryRadius;
  final double minOrderAmount;
  final double deliveryFee;
  final String upiId;
  final bool isVerified;

  /// Admin-controlled moderation state. [isOpen] is the manager's own
  /// trading switch; these two can only be changed by an admin.
  final bool isActive;
  final bool isBlacklisted;
  final String? blacklistReason;

  final DateTime createdAt;

  /// Whether customers may see and order from this store.
  bool get isVisibleToCustomers => isActive && !isBlacklisted;

  StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.category,
    required this.phone,
    required this.address,
    this.city,
    this.pincode,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.bannerUrl,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.isOpen = true,
    this.openTime = '09:00',
    this.closeTime = '21:00',
    this.offersDelivery = true,
    this.deliveryRadius = 5.0,
    this.minOrderAmount = 99.0,
    this.deliveryFee = 30.0,
    required this.upiId,
    this.isVerified = false,
    this.isActive = true,
    this.isBlacklisted = false,
    this.blacklistReason,
    required this.createdAt,
  });

  factory StoreModel.fromMap(String id, Map<String, dynamic> map) {
    return StoreModel(
      id: id,
      ownerId: map['ownerId']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unnamed store',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      city: map['city']?.toString(),
      pincode: map['pincode']?.toString(),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      imageUrl: map['imageUrl']?.toString(),
      bannerUrl: map['bannerUrl']?.toString(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (map['totalRatings'] as num?)?.toInt() ?? 0,
      isOpen: map['isOpen'] != false,
      openTime: map['openTime']?.toString() ?? '09:00',
      closeTime: map['closeTime']?.toString() ?? '21:00',
      offersDelivery: map['offersDelivery'] != false,
      deliveryRadius: (map['deliveryRadius'] as num?)?.toDouble() ?? 5.0,
      minOrderAmount: (map['minOrderAmount'] as num?)?.toDouble() ?? 0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0,
      upiId: map['upiId']?.toString() ?? '',
      isVerified: map['isVerified'] == true,
      // Stores created before moderation existed stay active and unbanned.
      isActive: map['isActive'] != false,
      isBlacklisted: map['isBlacklisted'] == true,
      blacklistReason: map['blacklistReason']?.toString(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory StoreModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => StoreModel.fromMap(doc.id, doc.data() ?? const {});

  StoreModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? category,
    String? phone,
    String? address,
    String? city,
    String? pincode,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? bannerUrl,
    double? rating,
    int? totalRatings,
    bool? isOpen,
    String? openTime,
    String? closeTime,
    bool? offersDelivery,
    double? deliveryRadius,
    double? minOrderAmount,
    double? deliveryFee,
    String? upiId,
    bool? isVerified,
    bool? isActive,
    bool? isBlacklisted,
    String? blacklistReason,
    DateTime? createdAt,
  }) {
    return StoreModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      offersDelivery: offersDelivery ?? this.offersDelivery,
      deliveryRadius: deliveryRadius ?? this.deliveryRadius,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      upiId: upiId ?? this.upiId,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isBlacklisted: isBlacklisted ?? this.isBlacklisted,
      blacklistReason: blacklistReason ?? this.blacklistReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
