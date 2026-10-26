import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:warrant_safe/models/portal_lookup_models.dart';
import 'package:warrant_safe/models/portal_request_models.dart';
import 'package:warrant_safe/models/portal_ticket_models.dart';
import 'package:warrant_safe/services/api_service.dart';
import 'package:warrant_safe/services/i_api_service.dart';
import 'package:warrant_safe/viewmodels/auth_viewmodel.dart';
import 'package:warrant_safe/views/devices/real_lookup_screen.dart';

class _LookupApi extends MockApiService {
  final requestCodes = <String>[];
  final ticketCodes = <String>[];
  final requestResponses = <Object>[];
  final ticketResponses = <Object>[];
  int publicLookupCalls = 0;

  @override
  Future<PortalRequestDetail> getMyWarrantyRequest(String code) async {
    requestCodes.add(code);
    final response = requestResponses.removeAt(0);
    if (response is Exception) throw response;
    return response as PortalRequestDetail;
  }

  @override
  Future<PortalTicketDetail> getPortalTicket(String code) async {
    ticketCodes.add(code);
    final response = ticketResponses.removeAt(0);
    if (response is Exception) throw response;
    return response as PortalTicketDetail;
  }

  @override
  Future<PortalLookupRecord> lookupPortal(String code, String phone) async {
    publicLookupCalls++;
    throw StateError('Signed-in lookup must not use the public endpoint');
  }
}

const _request = PortalRequestDetail(code: 'YC-TEST', status: 'PENDING_INTAKE');

PortalTicketDetail _ticket() => PortalTicketDetail(
  code: 'TN-TEST',
  receivedAt: DateTime(2026, 10, 16),
  status: 'REPAIRING',
  stopped: false,
  steps: const [],
  customerNotes: const [],
  costs: const PortalCosts(
    inWarrantyAmount: 0,
    outOfWarrantyParts: 0,
    serviceFee: 0,
    vat: 0,
    total: 0,
    paymentStatus: 'UNPAID',
  ),
  canRate: false,
);

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

Future<void> _submit(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextFormField), code);
  await tester.tap(find.text('Tra cứu').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty and incomplete code stays local; phone is not requested', (
    tester,
  ) async {
    final api = _LookupApi();
    await _open(tester, api);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.textContaining('Số điện thoại'), findsNothing);

    await tester.tap(find.text('Tra cứu').last);
    await tester.pump();
    expect(find.textContaining('Nhập đầy đủ mã'), findsOneWidget);

    await _submit(tester, 'YC--');
    expect(api.requestCodes, isEmpty);
    expect(api.ticketCodes, isEmpty);
    expect(api.publicLookupCalls, 0);
  });

  testWidgets('YC code uses the owner-checked request GET', (tester) async {
    final api = _LookupApi()..requestResponses.add(_request);
    await _open(tester, api);
    await _submit(tester, 'yc-test');

    expect(api.requestCodes, ['YC-TEST']);
    expect(api.ticketCodes, isEmpty);
    expect(api.publicLookupCalls, 0);
    expect(find.text('Yêu cầu YC-TEST'), findsOneWidget);
  });

  testWidgets('TN code uses the owner-checked ticket GET', (tester) async {
    final api = _LookupApi()..ticketResponses.add(_ticket());
    await _open(tester, api);
    await _submit(tester, 'tn-test');

    expect(api.requestCodes, isEmpty);
    expect(api.ticketCodes, ['TN-TEST']);
    expect(api.publicLookupCalls, 0);
    expect(find.text('Phiếu TN-TEST'), findsOneWidget);
  });

  testWidgets('404 does not expose a record', (tester) async {
    final api = _LookupApi()
      ..requestResponses.add(const ApiException('NOT_FOUND', statusCode: 404));
    await _open(tester, api);
    await _submit(tester, 'YC-TEST');

    expect(api.requestCodes, ['YC-TEST']);
    expect(find.textContaining('trong tài khoản của bạn'), findsOneWidget);
    expect(find.text('Yêu cầu YC-TEST'), findsNothing);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('network error keeps code and Retry loads the record', (
    tester,
  ) async {
    final api = _LookupApi()
      ..requestResponses.addAll([const NetworkException(), _request]);
    await _open(tester, api);
    await _submit(tester, 'YC-TEST');

    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Không tìm thấy'), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'YC-TEST',
    );

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(api.requestCodes, ['YC-TEST', 'YC-TEST']);
    expect(find.text('Yêu cầu YC-TEST'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('429 is explained without exposing a record', (tester) async {
    final api = _LookupApi()
      ..requestResponses.add(
        const ApiException('RATE_LIMITED', statusCode: 429),
      );
    await _open(tester, api);
    await _submit(tester, 'YC-TEST');

    expect(api.requestCodes, ['YC-TEST']);
    expect(find.textContaining('tra cứu quá nhiều lần'), findsOneWidget);
    expect(find.text('Yêu cầu YC-TEST'), findsNothing);
    expect(find.text('Thử lại'), findsNothing);
  });
}
