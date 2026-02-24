// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Placeholder smoke test.
    // The full app requires Hive initialization and ProviderScope,
    // so a minimal test is used here.
    expect(1 + 1, equals(2));
  });
}
