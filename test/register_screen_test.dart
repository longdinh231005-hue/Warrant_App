import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warrant_safe/services/token_storage.dart';
import 'package:warrant_safe/viewmodels/auth_viewmodel.dart';
import 'package:warrant_safe/views/auth/register_screen.dart';

class _Storage implements TokenStorage {
  @override
  Future<void> clearSession({bool isMock = false}) async {}

  @override
  Future<Map<String, String?>> readSession({bool isMock = false}) async => {};

  @override
  Future<void> saveSession({
    required String token,
    String? refreshToken,
    required String userId,
    bool isMock = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Mock registration uses email without a phone field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'isMock': true});
    final auth = AuthViewModel(tokenStorage: _Storage());
    await auth.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    expect(find.text('Tạo tài khoản'), findsOneWidget);
    expect(find.textContaining('Chế độ minh họa'), findsOneWidget);
    expect(find.text('SỐ ĐIỆN THOẠI'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField).first, 'Khách thử');
    await tester.enterText(find.byType(TextFormField).last, 'demo@example.com');
    await tester.tap(find.text('TIẾP TỤC'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Password1!');
    await tester.enterText(find.byType(TextFormField).last, 'Password1!');
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('TẠO TÀI KHOẢN'));
    await tester.tap(find.text('TẠO TÀI KHOẢN'));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, true);
    expect(auth.currentUser?.email, 'demo@example.com');
    expect(auth.currentUser?.phone, isEmpty);
    auth.dispose();
  });

  testWidgets('Real registration does not offer an unsupported submit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'isMock': false,
      'baseUrl': 'http://10.0.2.2:8081/api/v1',
    });
    final auth = AuthViewModel(tokenStorage: _Storage());
    await auth.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    expect(find.textContaining('hiện chưa khả dụng'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('TẠO TÀI KHOẢN'), findsNothing);
    auth.dispose();
  });
}
