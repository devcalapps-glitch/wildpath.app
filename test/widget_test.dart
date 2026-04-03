import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wildpath/main.dart';
import 'package:wildpath/services/storage_service.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WildPath boots into onboarding for a new user', (tester) async {
    setUpFlutterSecureStorageMock();
    SharedPreferences.setMockInitialValues({});

    final storage = StorageService();
    await storage.init();

    await tester.pumpWidget(WildPathApp(storage: storage));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to WildPath'), findsOneWidget);
  });
}
