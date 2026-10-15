import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warrant_safe/models/portal_request_models.dart';
import 'package:warrant_safe/models/portal_ticket_models.dart';
import 'package:warrant_safe/models/user_model.dart';
import 'package:warrant_safe/router/app_router.dart';
import 'package:warrant_safe/services/i_api_service.dart';
import 'package:warrant_safe/services/real_api_service.dart';
import 'package:warrant_safe/services/token_storage.dart';
import 'package:warrant_safe/viewmodels/auth_viewmodel.dart';
import 'package:warrant_safe/viewmodels/request_viewmodel.dart';
import 'package:warrant_safe/viewmodels/ticket_viewmodel.dart';
import 'package:warrant_safe/views/requests/real_request_detail_screen.dart';
import 'package:warrant_safe/views/requests/real_ticket_detail_screen.dart';
import 'package:warrant_safe/views/requests/request_list_screen.dart';

final _request = PortalRequestDetail.fromJson({
  'code': 'YC-1',
  'status': 'PENDING_INTAKE',
  'brandModel': 'Máy mẫu',
  'serialOrImei': 'SERIAL-1',
  'ticketCode': null,
});

final _ticketSummaryJson = <String, dynamic>{
  'code': 'TN-OLD',
  'productName': 'Máy mẫu',
  'serialOrImei': 'SERIAL-1',
  'receivedAt': '2026-09-07T13:45:00+07:00',
  'status': 'DELIVERED',
  'stopped': false,
  'currentStep': 6,
  'rating': null,
};

Map<String, dynamic> _ticketJson({bool pendingQuote = false}) => {
  'code': 'TN-OLD',
  'productName': 'Máy mẫu',
  'brandName': 'Hãng mẫu',
  'serialOrImei': 'SERIAL-1',
  'receivedAt': '2026-09-07T13:45:00+07:00',
  'promisedReturnAt': null,
  'status': pendingQuote ? 'AWAITING_CUSTOMER_CONFIRMATION' : 'DELIVERED',
  'stopped': false,
  'steps': [
    {'key': 'RECEIVED', 'label': 'Tiếp nhận', 'state': 'DONE'},
    {'key': 'DIAGNOSIS', 'label': 'Chẩn đoán', 'state': 'CURRENT'},
    {'key': 'AWAITING_PARTS', 'label': 'Chờ linh kiện', 'state': 'UPCOMING'},
  ],
  'customerNotes': [
    {'at': '2026-09-07T14:00:00+07:00', 'text': 'Đã kiểm tra'},
  ],
  'costs': {
    'inWarrantyAmount': 0,
    'outOfWarrantyParts': 0,
    'serviceFee': 0,
    'vat': 0,
    'total': 0,
    'paymentStatus': 'UNPAID',
  },
  'pendingQuotation': pendingQuote
      ? {
          'code': 'BG-1',
          'validUntil': '2026-10-20',
          'vatRate': 0.1,
          'lines': [
            {
              'lineNo': 1,
              'description': 'Linh kiện mẫu',
              'quantity': 2,
              'unitPrice': 100000,
              'laborFee': 50000,
              'lineTotal': 250000,
            },
          ],
          'partsTotal': 200000,
          'laborTotal': 50000,
          'grandTotal': 275000,
        }
      : null,
  'handedOverAt': null,
  'rating': null,
  'canRate': !pendingQuote,
};

class _Adapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    expect(options.method, 'GET');
    expect(options.headers['Authorization'], 'Bearer fixture-token');
    final body = options.uri.path.endsWith('/my/tickets')
        ? [_ticketSummaryJson]
        : _ticketJson();
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryStorage implements TokenStorage {
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

class _FakeApi implements IApiService {
  bool failTicketsOnce = false;
  Object? requestError;
  Object? ticketError;
  PortalRequestDetail request = _request;
  String? lastTicketCode;
  List<PortalTicketSummary> tickets = [];
  PortalTicketDetail detail = PortalTicketDetail.fromJson(_ticketJson());

  @override
  Future<AuthResponse> login(String username, String password) async =>
      const AuthResponse(
        accessToken: 'fixture-token',
        expiresIn: 60,
        refreshToken: null,
        refreshExpiresIn: null,
        user: UserModel(
          id: 'KH-1',
          fullName: 'Khách mẫu',
          username: 'customer',
          phone: '',
          role: 'CUSTOMER',
        ),
      );
  @override
  Future<UserModel> getProfile() async => (await login('', '')).user;
  @override
  Future<List<OwnedDevice>> getMyDevices() async => [];
  @override
  Future<PortalCatalog> getPortalCatalog() async =>
      throw UnsupportedError('Not used by tracking tests.');
  @override
  Future<List<PortalRequestSummary>> getMyWarrantyRequests() async => [
    _request,
  ];
  @override
  Future<PortalRequestDetail> getMyWarrantyRequest(String code) async {
    if (requestError != null) throw requestError!;
    return request;
  }

  @override
  Future<String> submitMyWarrantyRequest(OwnWarrantyRequestData data) async =>
      throw UnsupportedError('Tracking tests never submit a request.');
  @override
  Future<List<PortalTicketSummary>> getMyTickets() async {
    if (failTicketsOnce) {
      failTicketsOnce = false;
      throw const NetworkException();
    }
    return tickets;
  }

  @override
  Future<PortalTicketDetail> getPortalTicket(String code) async {
    lastTicketCode = code;
    if (ticketError != null) throw ticketError!;
    return detail;
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) => login('', '');
  @override
  Future<void> logout(String? refreshToken) async {}
  @override
  Future<AuthResponse> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) => login('', '');
  @override
  void setAuthToken(String token) {}
  @override
  void clearAuthToken() {}
}

Future<AuthViewModel> _auth(_FakeApi api) async {
  SharedPreferences.setMockInitialValues({'isMock': false});
  final auth = AuthViewModel(apiService: api, tokenStorage: _MemoryStorage());
  await auth.initialize();
  expect(await auth.loginUser('customer', ''), isTrue);
  return auth;
}

void main() {
  test(
    'ticket DTO preserves separate status, steps, costs and pending quote',
    () {
      final summary = PortalTicketSummary.fromJson(_ticketSummaryJson);
      expect(summary.code, 'TN-OLD');
      expect(summary.status, 'DELIVERED');
      expect(summary.currentStep, 6);
      final ticket = PortalTicketDetail.fromJson(
        _ticketJson(pendingQuote: true),
      );
      expect(ticket.status, 'AWAITING_CUSTOMER_CONFIRMATION');
      expect(ticket.steps.map((step) => step.state), [
        'DONE',
        'CURRENT',
        'UPCOMING',
      ]);
      expect(ticket.costs.total, 0);
      expect(ticket.pendingQuotation!.grandTotal, 275000);
      expect(ticket.pendingQuotation!.lines.single.quantity, 2);
      expect(
        PortalTicketDetail.fromJson(_ticketJson()).pendingQuotation,
        isNull,
      );
      expect(_request.ticketCode, isNull);
    },
  );

  test('Real ticket GETs use exact paths and Bearer auth', () async {
    final adapter = _Adapter();
    final api = RealApiService(
      baseUrl: 'http://127.0.0.1:8080/api/v1',
      adapter: adapter,
    )..setAuthToken('fixture-token');
    expect((await api.getMyTickets()).single.code, 'TN-OLD');
    expect((await api.getPortalTicket('TN-OLD')).code, 'TN-OLD');
    expect(adapter.paths, [
      '/api/v1/portal/my/tickets',
      '/api/v1/portal/tickets/TN-OLD',
    ]);
  });

  testWidgets('pending request has no ticket link; separate old ticket list', (
    tester,
  ) async {
    final api = _FakeApi()
      ..tickets = [PortalTicketSummary.fromJson(_ticketSummaryJson)];
    final auth = await _auth(api);
    final requests = RequestViewModel(auth);
    final tickets = TicketViewModel(auth);
    addTearDown(() {
      tickets.dispose();
      requests.dispose();
      auth.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider<RequestViewModel>.value(value: requests),
          ChangeNotifierProvider<TicketViewModel>.value(value: tickets),
        ],
        child: const MaterialApp(home: RequestListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mã yêu cầu YC-1'), findsOneWidget);
    expect(find.text('Mã phiếu TN-OLD'), findsOneWidget);
    expect(find.text('Đã bàn giao'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: const MaterialApp(home: RealRequestDetailScreen(code: 'YC-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa có phiếu tiếp nhận'), findsOneWidget);
    expect(find.text('Xem tiến độ phiếu'), findsNothing);
  });

  testWidgets('ticket empty and retry states are truthful', (tester) async {
    final api = _FakeApi()..failTicketsOnce = true;
    final auth = await _auth(api);
    final requests = RequestViewModel(auth);
    final tickets = TicketViewModel(auth);
    addTearDown(() {
      tickets.dispose();
      requests.dispose();
      auth.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider<RequestViewModel>.value(value: requests),
          ChangeNotifierProvider<TicketViewModel>.value(value: tickets),
        ],
        child: const MaterialApp(home: RequestListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Không tải được danh sách phiếu'),
      findsOneWidget,
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản chưa có phiếu tiếp nhận nào.'), findsOneWidget);
  });

  testWidgets('linked request opens only its backend ticket code', (
    tester,
  ) async {
    final api = _FakeApi()
      ..request = PortalRequestDetail.fromJson({
        'code': 'YC-LINK',
        'status': 'CONVERTED',
        'ticketCode': 'TN-LINK',
      });
    final auth = await _auth(api);
    final requests = RequestViewModel(auth);
    final tickets = TicketViewModel(auth);
    final router = AppRouter(auth).router;
    addTearDown(() {
      router.dispose();
      tickets.dispose();
      requests.dispose();
      auth.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider<RequestViewModel>.value(value: requests),
          ChangeNotifierProvider<TicketViewModel>.value(value: tickets),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/requests/YC-LINK');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Xem tiến độ phiếu'), 300);
    await tester.tap(find.text('Xem tiến độ phiếu'));
    await tester.pumpAndSettle();
    expect(api.lastTicketCode, 'TN-LINK');
    expect(find.text('Phiếu tiếp nhận'), findsOneWidget);
  });

  testWidgets('pending quotation fixture is read only', (tester) async {
    final api = _FakeApi()
      ..detail = PortalTicketDetail.fromJson(_ticketJson(pendingQuote: true));
    final auth = await _auth(api);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: const MaterialApp(home: RealTicketDetailScreen(code: 'TN-OLD')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Hiện tại · Chẩn đoán'), 300);
    expect(find.text('Hiện tại · Chẩn đoán'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Báo giá chờ khách quyết định'),
      300,
    );
    expect(find.text('Báo giá chờ khách quyết định'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tổng báo giá: 275000 VNĐ'), 300);
    expect(find.text('Tổng báo giá: 275000 VNĐ'), findsOneWidget);
    expect(find.text('ĐỒNG Ý'), findsNothing);
    expect(find.text('TỪ CHỐI'), findsNothing);
  });

  testWidgets('404 ownership responses show no other customer data', (
    tester,
  ) async {
    final api = _FakeApi()
      ..requestError = const ApiException('Not found', statusCode: 404)
      ..ticketError = const ApiException('Not found', statusCode: 404);
    final auth = await _auth(api);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: const MaterialApp(
          home: RealRequestDetailScreen(code: 'YC-OTHER'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Không tìm thấy yêu cầu trong tài khoản này.'),
      findsOneWidget,
    );
    expect(find.text('Máy mẫu'), findsNothing);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: const MaterialApp(
          home: RealTicketDetailScreen(code: 'TN-OTHER'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Không tìm thấy phiếu tiếp nhận trong tài khoản này.'),
      findsOneWidget,
    );
    expect(find.text('Máy mẫu'), findsNothing);
  });
}
