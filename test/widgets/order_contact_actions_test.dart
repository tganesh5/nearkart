import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearkart/screens/common/order_contact_actions.dart';

void main() {
  const order = {
    'customerName': 'Theja',
    'customerPhone': '9742721601',
    'storeName': 'Anaga Stores',
    'storePhone': '9876543210',
    'deliveryPartnerName': 'Subbanna',
    'deliveryPartnerPhone': '9000000001',
  };

  Future<void> pump(
    WidgetTester tester,
    OrderViewer viewer, {
    Map<String, dynamic> data = order,
    String? fallbackStorePhone,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderContactActions(
            data: data,
            viewer: viewer,
            fallbackStorePhone: fallbackStorePhone,
          ),
        ),
      ),
    );
  }

  group('who each persona can call', () {
    testWidgets('a customer can call the store and the partner', (
      tester,
    ) async {
      await pump(tester, OrderViewer.customer);

      expect(find.text('Call store'), findsOneWidget);
      expect(find.text('Call delivery partner'), findsOneWidget);
      expect(find.text('Call customer'), findsNothing);
    });

    testWidgets('a store can call the customer and the partner', (
      tester,
    ) async {
      await pump(tester, OrderViewer.store);

      expect(find.text('Call customer'), findsOneWidget);
      expect(find.text('Call delivery partner'), findsOneWidget);
      expect(find.text('Call store'), findsNothing);
    });

    testWidgets('a delivery partner can call the customer and the store', (
      tester,
    ) async {
      await pump(tester, OrderViewer.deliveryPartner);

      expect(find.text('Call customer'), findsOneWidget);
      expect(find.text('Call store'), findsOneWidget);
      expect(find.text('Call delivery partner'), findsNothing);
    });
  });

  group('chat', () {
    testWidgets('every reachable contact can also be messaged', (
      tester,
    ) async {
      await pump(tester, OrderViewer.customer);

      // One chat button per callable party, and no more.
      expect(find.byTooltip('WhatsApp store'), findsOneWidget);
      expect(find.byTooltip('WhatsApp delivery partner'), findsOneWidget);
      expect(find.byIcon(Icons.chat_outlined), findsNWidgets(2));
    });

    testWidgets('a contact with no number gets neither button', (tester) async {
      await pump(
        tester,
        OrderViewer.customer,
        data: const {'storeName': 'Anaga Stores', 'storePhone': '9876543210'},
      );

      expect(find.byTooltip('WhatsApp store'), findsOneWidget);
      expect(find.byTooltip('WhatsApp delivery partner'), findsNothing);
    });
  });

  group('missing numbers', () {
    testWidgets('no partner assigned hides the partner button', (
      tester,
    ) async {
      await pump(
        tester,
        OrderViewer.customer,
        data: const {'storeName': 'Anaga Stores', 'storePhone': '9876543210'},
      );

      expect(find.text('Call store'), findsOneWidget);
      expect(find.text('Call delivery partner'), findsNothing);
    });

    testWidgets('an order with no numbers explains itself', (tester) async {
      await pump(tester, OrderViewer.customer, data: const {});

      expect(
        find.text('No contact number recorded for this order yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a legacy order falls back to the live store number', (
      tester,
    ) async {
      await pump(
        tester,
        OrderViewer.customer,
        data: const {'storeName': 'Anaga Stores'},
        fallbackStorePhone: '9876543210',
      );

      expect(find.text('Call store'), findsOneWidget);
    });
  });

  group('normalisePhone', () {
    test('adds the country code to a 10-digit local number', () {
      expect(OrderContactActions.normalisePhone('9742721601'), '+919742721601');
    });

    test('keeps an already qualified number', () {
      expect(
        OrderContactActions.normalisePhone('+91 97427 21601'),
        '+919742721601',
      );
    });

    test('qualifies a 12-digit number that already carries 91', () {
      expect(
        OrderContactActions.normalisePhone('919742721601'),
        '+919742721601',
      );
    });

    test('treats a blank or missing number as no number', () {
      expect(OrderContactActions.normalisePhone(null), '');
      expect(OrderContactActions.normalisePhone('   '), '');
    });
  });
}
