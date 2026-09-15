import 'package:flutter_test/flutter_test.dart';
import 'package:nearkart/models/product_model.dart';
import 'package:nearkart/models/store_model.dart';
import 'package:nearkart/providers/platform_settings_provider.dart';

void main() {
  group('StoreModel.fromMap', () {
    test('reads a fully populated document', () {
      final store = StoreModel.fromMap('store-1', {
        'ownerId': 'owner-1',
        'name': 'NearKart Test Store',
        'category': 'Grocery & Kirana',
        'address': '80 Feet Road',
        'city': 'Bangalore',
        'pincode': '560034',
        'latitude': 12.9279,
        'longitude': 77.6271,
        'rating': 4.5,
        'isOpen': false,
        'deliveryFee': 30,
        'minOrderAmount': 99,
        'isVerified': true,
      });

      expect(store.id, 'store-1');
      expect(store.name, 'NearKart Test Store');
      expect(store.latitude, 12.9279);
      expect(store.isOpen, isFalse);
      expect(store.isVerified, isTrue);
      expect(store.deliveryFee, 30);
    });

    test('survives a document with missing fields', () {
      final store = StoreModel.fromMap('store-2', const {});

      expect(store.name, 'Unnamed store');
      expect(store.latitude, 0);
      expect(store.longitude, 0);
      // Absent flags should not hide a store from customers.
      expect(store.isOpen, isTrue);
      expect(store.isVerified, isFalse);
    });

    test('treats stores without moderation fields as visible', () {
      final store = StoreModel.fromMap('store-4', const {});

      expect(store.isActive, isTrue);
      expect(store.isBlacklisted, isFalse);
      expect(store.isVisibleToCustomers, isTrue);
    });

    test('hides deactivated and blacklisted stores from customers', () {
      final deactivated = StoreModel.fromMap('store-5', {'isActive': false});
      final blacklisted = StoreModel.fromMap('store-6', {
        'isBlacklisted': true,
        'blacklistReason': 'Selling prohibited items',
      });

      expect(deactivated.isVisibleToCustomers, isFalse);
      expect(blacklisted.isVisibleToCustomers, isFalse);
      expect(blacklisted.blacklistReason, 'Selling prohibited items');
    });

    test('accepts ints where doubles are expected', () {
      final store = StoreModel.fromMap('store-3', {
        'latitude': 12,
        'longitude': 77,
        'rating': 4,
      });

      expect(store.latitude, 12.0);
      expect(store.longitude, 77.0);
      expect(store.rating, 4.0);
    });
  });

  group('ProductModel.fromMap', () {
    test('reads a fully populated document', () {
      final product = ProductModel.fromMap('p1', {
        'storeId': 'store-1',
        'name': 'Milk 1L',
        'price': 62,
        'mrp': 70,
        'unit': 'piece',
        'stockCount': 12,
        'isAvailable': true,
      });

      expect(product.name, 'Milk 1L');
      expect(product.price, 62);
      expect(product.stockCount, 12);
      expect(product.discount, 11);
    });

    test('defaults stock to zero so bad data cannot oversell', () {
      final product = ProductModel.fromMap('p2', const {});

      expect(product.stockCount, 0);
      expect(product.price, 0);
      expect(product.discount, 0);
    });

    test('reports no discount when mrp is below price', () {
      final product = ProductModel.fromMap('p3', {'price': 100, 'mrp': 90});

      expect(product.discount, 0);
    });
  });

  group('PlatformSettings', () {
    test('charges the configured percentage', () {
      const settings = PlatformSettings(feePercent: 2);

      expect(settings.feeFor(500), 10);
    });

    test('applies the minimum fee to small baskets', () {
      const settings = PlatformSettings(feePercent: 1, minFee: 5);

      expect(settings.feeFor(100), 5);
      expect(settings.feeFor(900), 9);
    });

    test('caps the fee on large baskets', () {
      const settings = PlatformSettings(feePercent: 2, maxFee: 30);

      expect(settings.feeFor(5000), 30);
    });

    test('charges nothing when the fee is switched off', () {
      const settings = PlatformSettings(feePercent: 5, isFeeEnabled: false);

      expect(settings.feeFor(1000), 0);
    });

    test('charges nothing on an empty basket', () {
      const settings = PlatformSettings(feePercent: 5, minFee: 10);

      expect(settings.feeFor(0), 0);
    });

    test('cannot collect until a payee UPI id is configured', () {
      expect(const PlatformSettings().canCollectFee, isFalse);
      expect(
        const PlatformSettings(upiId: 'nearkart@okhdfcbank').canCollectFee,
        isTrue,
      );
      expect(
        const PlatformSettings(
          upiId: 'nearkart@okhdfcbank',
          isFeeEnabled: false,
        ).canCollectFee,
        isFalse,
      );
    });

    test('reads a stored configuration', () {
      final settings = PlatformSettings.fromMap({
        'feePercent': 1.5,
        'minFee': 2,
        'maxFee': 25,
        'isFeeEnabled': true,
        'upiId': 'nearkart@okaxis',
        'payeeName': 'NearKart Retail',
      });

      expect(settings.feePercent, 1.5);
      expect(settings.payeeName, 'NearKart Retail');
      expect(settings.feeFor(1000), 15);
      expect(settings.feeFor(100), 2);
    });
  });
}
