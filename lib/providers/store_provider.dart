import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef StoreDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Streams the store owned by the signed-in manager, or null when the account
/// has no store assigned yet.
final myStoreProvider = StreamProvider.autoDispose<StoreDoc?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream<StoreDoc?>.value(null);

  return FirebaseFirestore.instance
      .collection('stores')
      .where('ownerId', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .map((snapshot) => snapshot.docs.isEmpty ? null : snapshot.docs.first);
});
