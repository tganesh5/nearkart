import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/product_model.dart';
import 'add_product_screen.dart';

class VendorProductsScreen extends StatelessWidget {
  const VendorProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Scaffold(
            appBar: _ProductsAppBar(),
            body: Center(child: Text('No store is assigned to this account.')),
          );
        }
        return _ProductsForStore(storeId: snapshot.data!.docs.first.id);
      },
    );
  }
}

class _ProductsForStore extends StatelessWidget {
  const _ProductsForStore({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _ProductsAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddProductScreen(storeId: storeId)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('storeId', isEqualTo: storeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load products.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!.docs.map(_productFromDoc).toList();
          if (products.isEmpty) {
            return const Center(child: Text('Add your first product.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) => _ProductTile(
              product: products[index],
              onEdit: () => showDialog<void>(
                context: context,
                builder: (_) => _EditProductDialog(product: products[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  ProductModel _productFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return ProductModel(
      id: doc.id,
      storeId: (data['storeId'] ?? '').toString(),
      name: (data['name'] ?? 'Unnamed product').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? 'General').toString(),
      price: (data['price'] as num? ?? 0).toDouble(),
      mrp: (data['mrp'] as num?)?.toDouble(),
      unit: (data['unit'] ?? 'piece').toString(),
      quantity: (data['quantity'] as num? ?? 1).toDouble(),
      imageUrl: data['imageUrl'] as String?,
      isAvailable: data['isAvailable'] as bool? ?? true,
      isFeatured: data['isFeatured'] as bool? ?? false,
      stockCount: data['stockCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class _ProductsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProductsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('My Products'));
  }
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;

  const _ProductTile({required this.product, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (product.mrp != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '₹${product.mrp!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: product.isAvailable
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  product.isAvailable ? 'Active' : 'Hidden',
                  style: TextStyle(
                    fontSize: 11,
                    color: product.isAvailable
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IconButton(
                tooltip: 'Edit price and availability',
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({required this.product});

  final ProductModel product;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late bool _available;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: widget.product.price.toString());
    _stock = TextEditingController(text: widget.product.stockCount.toString());
    _available = widget.product.isAvailable;
  }

  @override
  void dispose() {
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Selling price'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Stock'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available'),
            value: _available,
            onChanged: (value) => setState(() => _available = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text);
    final stock = int.tryParse(_stock.text);
    if (price == null || price <= 0 || stock == null || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price and stock.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .update({
            'price': price,
            'stockCount': stock,
            'isAvailable': _available,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.pop(context);
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update product.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
