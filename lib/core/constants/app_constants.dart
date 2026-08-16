class AppConstants {
  static const String appName = 'NearKart';
  static const String appTagline = 'Your Neighbourhood, Online';

  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  static const double borderRadius = 12.0;
  static const double cardRadius = 16.0;

  static const int otpLength = 6;
  static const int otpTimeout = 60;

  static const double deliveryRadiusKm = 5.0;
  static const double minOrderAmount = 99.0;
  static const double deliveryFee = 30.0;
  static const double freeDeliveryAbove = 499.0;

  static const double platformFeePercent = 0.5;
  static const String nearkartUpiId = 'nearkart@upi'; // Replace with real NearKart UPI

  static const List<String> storeCategories = [
    'Grocery & Kirana',
    'Fruits & Vegetables',
    'Bakery & Sweets',
    'Dairy & Milk',
    'Meat & Fish',
    'Pharmacy',
    'Electronics',
    'Clothing',
    'Stationery',
    'Hardware',
    'Beauty & Wellness',
    'Flowers & Gifts',
    'Pet Supplies',
    'Home & Kitchen',
    'Other',
  ];

  static const List<String> productUnits = [
    'kg',
    'g',
    'L',
    'ml',
    'piece',
    'pack',
    'dozen',
    'pair',
    'meter',
    'box',
  ];
}
