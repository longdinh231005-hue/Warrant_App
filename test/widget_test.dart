import 'package:flutter_test/flutter_test.dart';
import 'package:warrant_safe/main.dart';

void main() {
  testWidgets('WarrantSafe app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const WarrantSafeApp());
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
