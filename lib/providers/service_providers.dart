import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase/firebase_auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';
import '../services/payment/payment_service.dart';
import '../services/location/location_service.dart';
import '../services/notification/notification_service.dart';
import '../services/delivery/delivery_service.dart';

// Firebase services
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Payment
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

// Location
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Notifications
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Delivery
final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService();
});

// Location state
final currentLocationProvider = FutureProvider<LocationData?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  try {
    return await locationService.getCurrentLocation();
  } catch (_) {
    return null;
  }
});
