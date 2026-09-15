import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';

/// Saved products, stored per user at users/{uid}/wishlist. The document id is
/// the product id so toggling is a single write with no lookup.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  static CollectionReference<Map<String, dynamic>>? collectionFor(String? uid) {
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wishlist');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final collection = collectionFor(uid);

    if (collection == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: const Center(child: Text('Please sign in to use your wishlist.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: collection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load your wishlist.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your wishlist is empty',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart on any product to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _WishlistTile(
                productId: doc.id,
                saved: doc.data(),
                onRemove: doc.reference.delete,
              );
            },
          );
        },
      ),
    );
  }
}

class _WishlistTile extends ConsumerWidget {
  const _WishlistTile({
    required this.productId,
    required this.saved,
    required this.onRemove,
  });

  final String productId;
  final Map<String, dynamic> saved;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The saved copy keeps the list usable offline; the live document decides
    // price and availability.
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get(),
      builder: (context, snapshot) {
        final live = snapshot.data;
        final exists = live?.exists == true;
        final product = exists ? ProductModel.fromDoc(live!) : null;
        final name = product?.name ?? saved['name']?.toString() ?? 'Product';
        final available =
            product != null && product.isAvailable && product.stockCount > 0;

        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary,
              ),
            ),
            title: Text(name),
            subtitle: Text(
              product == null
                  ? (snapshot.connectionState == ConnectionState.waiting
                        ? 'Checking availability…'
                        : 'No longer sold')
                  : available
                  ? '₹${product.price.toStringAsFixed(0)} • ${product.unit}'
                  : 'Out of stock',
              style: TextStyle(
                color: available ? AppColors.textSecondary : AppColors.error,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Add to cart',
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: available
                      ? () {
                          ref.read(cartProvider.notifier).addItem(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name added to cart.')),
                          );
                        }
                      : null,
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onRemove(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
