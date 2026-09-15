import 'package:flutter_test/flutter_test.dart';
import 'package:nearkart/core/utils/phone_auth.dart';
import 'package:nearkart/core/utils/validators.dart';

void main() {
  group('optional email', () {
    test('empty is allowed', () {
      expect(optionalEmail(''), isNull);
      expect(optionalEmail('   '), isNull);
      expect(Validators.email(''), isNull);
    });

    test('a real address is accepted', () {
      expect(optionalEmail('theja.anaga@gmail.com'), isNull);
    });

    test('a malformed address is rejected', () {
      expect(optionalEmail('not-an-email'), isNotNull);
    });
  });

  group('login identifier', () {
    test('accepts a real email', () {
      expect(loginIdentifier('manjula.kollegal@gmail.com'), isNull);
    });

    test('accepts a 10-digit mobile number', () {
      expect(loginIdentifier('9742721601'), isNull);
    });

    test('rejects an empty field', () {
      expect(loginIdentifier(''), isNotNull);
    });

    test('rejects a half-typed value', () {
      expect(loginIdentifier('manjula'), isNotNull);
    });
  });

  group('phone-only Auth email', () {
    test('maps a mobile number to the reserved domain', () {
      expect(phoneAuthEmail('9742721601'), '9742721601@$phoneAuthDomain');
    });

    test('login accepts a 10-digit number', () {
      expect(
        authEmailFromIdentifier('9742721601'),
        '9742721601@$phoneAuthDomain',
      );
    });

    test('login leaves a real email untouched', () {
      expect(
        authEmailFromIdentifier('manjula.kollegal@gmail.com'),
        'manjula.kollegal@gmail.com',
      );
    });

    test('the reserved domain is never shown', () {
      expect(displayEmail('9742721601@$phoneAuthDomain'), '');
      expect(displayEmail('theja.anaga@gmail.com'), 'theja.anaga@gmail.com');
    });
  });
}
