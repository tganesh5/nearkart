import 'package:flutter_test/flutter_test.dart';
import 'package:nearkart/models/user_model.dart';

void main() {
  group('UserRole.fromStoredValue', () {
    test('maps every supported persona', () {
      expect(UserRole.fromStoredValue('customer'), UserRole.customer);
      expect(UserRole.fromStoredValue('storeManager'), UserRole.storeManager);
      expect(UserRole.fromStoredValue('admin'), UserRole.admin);
      expect(
        UserRole.fromStoredValue('deliveryPartner'),
        UserRole.deliveryPartner,
      );
    });

    test('keeps legacy vendor accounts working as store managers', () {
      expect(UserRole.fromStoredValue('vendor'), UserRole.storeManager);
    });

    test('defaults unknown roles to customer', () {
      expect(UserRole.fromStoredValue(null), UserRole.customer);
      expect(UserRole.fromStoredValue('unknown'), UserRole.customer);
    });
  });

  group('AccountStatus.fromStoredValue', () {
    test('maps approval states and keeps legacy accounts active', () {
      expect(AccountStatus.fromStoredValue('pending'), AccountStatus.pending);
      expect(AccountStatus.fromStoredValue('rejected'), AccountStatus.rejected);
      expect(AccountStatus.fromStoredValue(null), AccountStatus.active);
    });
  });
}
