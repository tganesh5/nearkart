import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../models/store_model.dart';

/// Every store customers can browse. Firestore rules allow public reads on
/// stores, so this works for signed-out browsing too.
final storesProvider = StreamProvider.autoDispose<List<StoreModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('stores')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map(StoreModel.fromDoc)
                // Suspended and blacklisted stores are hidden from shoppers.
                .where((store) => store.isVisibleToCustomers)
                .toList()
              // Open stores first, then by rating.
              ..sort((a, b) {
                if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
                return b.rating.compareTo(a.rating);
              }),
      );
});

/// Products belonging to a single store.
final storeProductsProvider = StreamProvider.autoDispose
    .family<List<ProductModel>, String>((ref, storeId) {
      return FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: storeId)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(ProductModel.fromDoc).toList());
    });

/// Raw order documents for one store. Sorting happens in Dart so the query
/// needs no composite index.
final storeOrdersProvider = StreamProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((
      ref,
      storeId,
    ) {
      return FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.toList()..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                aTime?.millisecondsSinceEpoch ?? 0,
              );
            }),
          );
    });

/// Orders placed by the signed-in customer.
final myOrdersProvider = StreamProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((
      ref,
      customerId,
    ) {
      return FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.toList()..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                aTime?.millisecondsSinceEpoch ?? 0,
              );
            }),
          );
    });

/// A single store document, used when only an id is known.
final storeByIdProvider = StreamProvider.autoDispose
    .family<StoreModel?, String>((ref, storeId) {
      return FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .snapshots()
          .map((doc) => doc.exists ? StoreModel.fromDoc(doc) : null);
    });
