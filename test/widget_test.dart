import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearkart/main.dart';

void main() {
  testWidgets('App launches with login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NearKartApp()),
    );

    expect(find.text('NearKart'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
