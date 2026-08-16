import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../../core/exceptions/app_exception.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  CollectionReference get usersCollection => _db.collection('users');
  CollectionReference get storesCollection => _db.collection('stores');
  CollectionReference get productsCollection => _db.collection('products');
  CollectionReference get ordersCollection => _db.collection('orders');
  CollectionReference get reviewsCollection => _db.collection('reviews');

  // --- User Operations ---

  Future<void> createUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      await usersCollection.doc(uid).set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Failed to create user profile', error: e);
      throw StorageException('Failed to save profile', originalError: e);
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await usersCollection.doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      _logger.e('Failed to get user profile', error: e);
      throw StorageException('Failed to load profile', originalError: e);
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await usersCollection.doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Failed to update user profile', error: e);
      throw StorageException('Failed to update profile', originalError: e);
    }
  }

  // --- Store Operations ---

  Future<String> createStore(Map<String, dynamic> data) async {
    try {
      final doc = await storesCollection.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isVerified': false,
        'rating': 0.0,
        'totalRatings': 0,
      });
      return doc.id;
    } catch (e) {
      _logger.e('Failed to create store', error: e);
      throw StorageException('Failed to create store', originalError: e);
    }
  }

  Future<void> updateStore(String storeId, Map<String, dynamic> data) async {
    try {
      await storesCollection.doc(storeId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Failed to update store', error: e);
      throw StorageException('Failed to update store', originalError: e);
    }
  }

  Stream<QuerySnapshot> getNearbyStores({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) {
    // Firestore GeoPoint-based query with bounding box
    final lat = latitude;
    final latDelta = radiusKm / 110.574;

    return storesCollection
        .where('latitude', isGreaterThan: lat - latDelta)
        .where('latitude', isLessThan: lat + latDelta)
        .where('isOpen', isEqualTo: true)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getStore(String storeId) async {
    try {
      final doc = await storesCollection.doc(storeId).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      throw StorageException('Failed to load store', originalError: e);
    }
  }

  Stream<QuerySnapshot> getStoresByOwner(String ownerId) {
    return storesCollection.where('ownerId', isEqualTo: ownerId).snapshots();
  }

  // --- Product Operations ---

  Future<String> addProduct(Map<String, dynamic> data) async {
    try {
      final doc = await productsCollection.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e) {
      _logger.e('Failed to add product', error: e);
      throw StorageException('Failed to add product', originalError: e);
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      await productsCollection.doc(productId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw StorageException('Failed to update product', originalError: e);
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await productsCollection.doc(productId).delete();
    } catch (e) {
      throw StorageException('Failed to delete product', originalError: e);
    }
  }

  Stream<QuerySnapshot> getProductsByStore(String storeId) {
    return productsCollection
        .where('storeId', isEqualTo: storeId)
        .where('isAvailable', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot>> searchProducts(String query) async {
    try {
      final snapshot = await productsCollection
          .where('searchKeywords', arrayContains: query.toLowerCase())
          .limit(30)
          .get();
      return snapshot.docs;
    } catch (e) {
      throw StorageException('Search failed', originalError: e);
    }
  }

  // --- Order Operations ---

  Future<String> createOrder(Map<String, dynamic> data) async {
    try {
      final doc = await ordersCollection.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e) {
      _logger.e('Failed to create order', error: e);
      throw StorageException('Failed to place order', originalError: e);
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await ordersCollection.doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (status == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw StorageException('Failed to update order', originalError: e);
    }
  }

  Stream<QuerySnapshot> getCustomerOrders(String customerId) {
    return ordersCollection
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getVendorOrders(String storeId) {
    return ordersCollection
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // --- Reviews ---

  Future<void> addReview({
    required String orderId,
    required String storeId,
    required String customerId,
    required double rating,
    String? comment,
  }) async {
    final batch = _db.batch();

    final reviewRef = reviewsCollection.doc();
    batch.set(reviewRef, {
      'orderId': orderId,
      'storeId': storeId,
      'customerId': customerId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update store rating
    final storeRef = storesCollection.doc(storeId);
    batch.update(storeRef, {
      'totalRatings': FieldValue.increment(1),
    });

    await batch.commit();
  }

  double _cosine(double degrees) {
    return _cos(degrees * 3.14159265359 / 180);
  }

  double _cos(double radians) {
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -radians * radians / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }
}
