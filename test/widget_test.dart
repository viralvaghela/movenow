import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movenow/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoveNowApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(true, true);
  });
}
