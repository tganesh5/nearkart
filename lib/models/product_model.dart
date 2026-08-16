class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final String description;
  final String category;
  final double price;
  final double? mrp;
  final String unit;
  final double quantity;
  final String? imageUrl;
  final bool isAvailable;
  final bool isFeatured;
  final int stockCount;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.mrp,
    required this.unit,
    this.quantity = 1.0,
    this.imageUrl,
    this.isAvailable = true,
    this.isFeatured = false,
    this.stockCount = 100,
    required this.createdAt,
  });

  double get discount {
    if (mrp == null || mrp! <= price) return 0;
    return ((mrp! - price) / mrp! * 100).roundToDouble();
  }

  ProductModel copyWith({
    String? id,
    String? storeId,
    String? name,
    String? description,
    String? category,
    double? price,
    double? mrp,
    String? unit,
    double? quantity,
    String? imageUrl,
    bool? isAvailable,
    bool? isFeatured,
    int? stockCount,
    DateTime? createdAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      mrp: mrp ?? this.mrp,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      stockCount: stockCount ?? this.stockCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
