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
  final DateTime createdAt;

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
    required this.createdAt,
  });

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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
