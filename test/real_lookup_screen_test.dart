import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:warrant_safe/models/portal_lookup_models.dart';
import 'package:warrant_safe/models/portal_request_models.dart';
import 'package:warrant_safe/services/api_service.dart';
import 'package:warrant_safe/services/i_api_service.dart';
import 'package:warrant_safe/viewmodels/auth_viewmodel.dart';
import 'package:warrant_safe/views/devices/real_lookup_screen.dart';

class _LookupApi extends MockApiService {
  int calls = 0;
  final responses = <Object>[];

  @override
  Future<PortalLookupRecord> lookupPortal(String code, String phone) async {
    calls++;
    final response = responses.removeAt(0);
    if (response is Exception) throw response;
    return response as PortalLookupRecord;
  }
}

Future<void> _open(WidgetTester tester, _LookupApi api) async {
  final auth = AuthViewModel(apiService: api);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: auth,
      child: const MaterialApp(home: RealLookupScreen()),
    ),
  );
}

void main() {
  testWidgets('empty and incomplete lookup stays local', (tester) async {
    final api = _LookupApi();
    await _open(tester, api);
    await tester.tap(find.text('Tra cứu').last);
    await tester.pump();
    expect(find.textContaining('Nhập đầy đủ mã'), findsOneWidget);
    expect(find.textContaining('Nhập số điện thoại hợp lệ'), findsOneWidget);
    expect(api.calls, 0);

    await tester.enterText(find.byType(TextFormField).first, 'YC--');
    await tester.enterText(find.byType(TextFormField).last, '---------');
    await tester.tap(find.text('Tra cứu').last);
    await tester.pump();
    expect(api.calls, 0);
  });

  testWidgets('network error keeps input and Retry loads the record', (
    tester,
  ) async {
    final api = _LookupApi()
      ..responses.addAll([
        const NetworkException(),
        const PortalLookupRecord.request(
          PortalRequestDetail(code: 'YC-TEST', status: 'PENDING_INTAKE'),
        ),
      ]);
    await _open(tester, api);
    await tester.enterText(find.byType(TextFormField).first, 'YC-TEST');
    await tester.enterText(find.byType(TextFormField).last, '0912345678');
    await tester.tap(find.text('Tra cứu').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Không tìm thấy'), findsNothing);
    expect(find.text('YC-TEST'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text('Yêu cầu YC-TEST'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('429 is explained without exposing a record', (tester) async {
    final api = _LookupApi()
      ..responses.add(const ApiException('RATE_LIMITED', statusCode: 429));
    await _open(tester, api);
    await tester.enterText(find.byType(TextFormField).first, 'YC-TEST');
    await tester.enterText(find.byType(TextFormField).last, '0912345678');
    await tester.tap(find.text('Tra cứu').last);
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.textContaining('tra cứu quá nhiều lần'), findsOneWidget);
    expect(find.text('Yêu cầu YC-TEST'), findsNothing);
    expect(find.text('Thử lại'), findsNothing);
  });
}
