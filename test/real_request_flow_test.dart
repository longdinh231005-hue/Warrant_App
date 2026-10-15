import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warrant_safe/models/portal_request_models.dart';
import 'package:warrant_safe/models/user_model.dart';
import 'package:warrant_safe/router/app_router.dart';
import 'package:warrant_safe/services/i_api_service.dart';
import 'package:warrant_safe/services/real_api_service.dart';
import 'package:warrant_safe/services/token_storage.dart';
import 'package:warrant_safe/viewmodels/auth_viewmodel.dart';
import 'package:warrant_safe/viewmodels/request_viewmodel.dart';
import 'package:warrant_safe/views/requests/real_create_request_screen.dart';

const _device = OwnedDevice(
  code: 'TB-1',
  productName: 'Máy mẫu',
  brandName: 'Hãng mẫu',
  identifierType: 'SERIAL',
  serialOrImei: 'SERIAL-1234',
);
const _catalog = PortalCatalog(
  [
    PortalCategory('CAT', 'Nhóm mẫu', [
      PortalDeviceType('TYPE', 'Loại mẫu', 'SERIAL'),
      PortalDeviceType('PHONE', 'Điện thoại', 'IMEI'),
    ]),
  ],
  [PortalStation('STATION', 'Trạm mẫu', null)],
);

class _RequestAdapter implements HttpClientAdapter {
  _RequestAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions, Stream<Uint8List>?)
  respond;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return respond(options, requestStream);
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

class _FakePortalApi extends IApiService {
  int submitCount = 0;
  int listCount = 0;
  Completer<String>? pending;
  Completer<List<PortalRequestSummary>>? pendingList;
  Object? submitError;

  @override
  Future<AuthResponse> login(String username, String password) async =>
      const AuthResponse(
        accessToken: '',
        expiresIn: 60,
        refreshToken: null,
        refreshExpiresIn: null,
        user: UserModel(
          id: 'ACCOUNT',
          fullName: 'Khách thử',
          username: 'customer',
          phone: '',
          role: 'CUSTOMER',
        ),
      );
  @override
  Future<UserModel> getProfile() async => const UserModel(
    id: 'ACCOUNT',
    fullName: 'Khách thử',
    username: 'customer',
    phone: '',
    role: 'CUSTOMER',
  );
  @override
  Future<List<OwnedDevice>> getMyDevices() async => [_device];
  @override
  Future<PortalCatalog> getPortalCatalog() async => _catalog;
  @override
  Future<List<PortalRequestSummary>> getMyWarrantyRequests() {
    listCount++;
    return pendingList?.future ?? Future.value([]);
  }

  @override
  Future<String> submitMyWarrantyRequest(OwnWarrantyRequestData data) {
    submitCount++;
    if (submitError != null) return Future.error(submitError!);
    return pending?.future ?? Future.value('YC-TEST');
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

Future<AuthViewModel> _authenticated(_FakePortalApi api) async {
  SharedPreferences.setMockInitialValues({'isMock': false});
  final auth = AuthViewModel(apiService: api, tokenStorage: _MemoryStorage());
  await auth.initialize();
  expect(await auth.loginUser('customer', ''), isTrue);
  return auth;
}

void main() {
  test(
    'catalog type must match the owned device identifier; no guessed code',
    () {
      final errors = OwnWarrantyRequestData.validate(
        device: _device,
        catalog: _catalog,
        categoryCode: 'CAT',
        deviceTypeCode: 'PHONE',
        stationCode: 'STATION',
        symptom: 'Máy không lên nguồn',
      );
      expect(errors['deviceTypeCode'], isNotNull);
      expect(
        OwnWarrantyRequestData.validate(
          device: _device,
          catalog: _catalog,
          categoryCode: 'CAT',
          deviceTypeCode: 'TYPE',
          stationCode: 'STATION',
          symptom: ' ',
        )['symptom'],
        isNotNull,
      );
      expect(
        OwnWarrantyRequestData.validate(
          device: _device,
          catalog: _catalog,
          categoryCode: 'CAT',
          deviceTypeCode: 'TYPE',
          stationCode: 'STATION',
          symptom: 'Máy không lên nguồn',
        ),
        isEmpty,
      );
    },
  );

  test('request model uses server fields and omits optional time/customer', () {
    const payload = OwnWarrantyRequestData(
      categoryCode: 'CAT',
      deviceTypeCode: 'TYPE',
      brandModel: 'Máy mẫu',
      identifierType: 'SERIAL',
      serialOrImei: 'SERIAL-1234',
      symptom: 'Máy không lên nguồn',
      preferredStation: 'STATION',
    );
    expect(
      payload.toJson().keys,
      containsAll([
        'categoryCode',
        'deviceTypeCode',
        'brandModel',
        'identifierType',
        'serialOrImei',
        'symptom',
        'preferredStation',
      ]),
    );
    expect(payload.toJson(), isNot(contains('customer')));
    expect(payload.toJson(), isNot(contains('preferredFrom')));
    expect(
      PortalRequestSummary.fromJson({
        'code': 'YC-1',
        'status': 'PENDING_INTAKE',
        'brandModel': 'Máy mẫu',
      }).status,
      'PENDING_INTAKE',
    );
    expect(
      portalRequestStatusLabel('PENDING_INTAKE'),
      'Chờ tiếp nhận thiết bị',
    );
  });

  test(
    'multipart submission sends one data part and accepts only server code',
    () async {
      final adapter = _RequestAdapter((options, stream) async {
        final bytes = await stream!.fold<List<int>>(
          [],
          (result, chunk) => result..addAll(chunk),
        );
        final body = utf8.decode(bytes);
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/portal/my/warranty-requests');
        expect(options.contentType, contains('multipart/form-data'));
        expect(body, contains('name="data"'));
        expect(body, contains('"categoryCode":"CAT"'));
        expect(body, isNot(contains('"customer"')));
        return ResponseBody.fromString(
          '{"code":"YC-SERVER"}',
          201,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final api = RealApiService(
        baseUrl: 'http://127.0.0.1:8080/api/v1',
        adapter: adapter,
      );
      final code = await api.submitMyWarrantyRequest(
        const OwnWarrantyRequestData(
          categoryCode: 'CAT',
          deviceTypeCode: 'TYPE',
          brandModel: 'Máy mẫu',
          identifierType: 'SERIAL',
          serialOrImei: 'SERIAL-1234',
          symptom: 'Máy không lên nguồn',
          preferredStation: 'STATION',
        ),
      );
      expect(adapter.calls, 1);
      expect(code, 'YC-SERVER');
    },
  );

  test(
    'problem+json keeps status and fieldErrors without a second POST',
    () async {
      final adapter = _RequestAdapter((options, stream) async {
        await stream!.drain<void>();
        return ResponseBody.fromString(
          jsonEncode({
            'type': 'https://example.invalid/errors/VALIDATION_FAILED',
            'detail': 'Dữ liệu không hợp lệ',
            'fieldErrors': [
              {'field': 'symptom', 'message': 'Không được để trống'},
            ],
          }),
          400,
          headers: {
            Headers.contentTypeHeader: ['application/problem+json'],
          },
        );
      });
      final api = RealApiService(
        baseUrl: 'http://127.0.0.1:8080/api/v1',
        adapter: adapter,
      );
      try {
        await api.submitMyWarrantyRequest(
          const OwnWarrantyRequestData(
            categoryCode: 'CAT',
            deviceTypeCode: 'TYPE',
            brandModel: 'Máy mẫu',
            identifierType: 'SERIAL',
            serialOrImei: 'SERIAL-1234',
            symptom: '',
            preferredStation: 'STATION',
          ),
        );
        fail('Expected an API validation error');
      } on ApiException catch (error) {
        expect(error.statusCode, 400);
        expect(error.fieldErrors['symptom'], 'Không được để trống');
      }
      expect(adapter.calls, 1);
    },
  );

  test('transport timeout stays uncertain and is not retried', () async {
    final adapter = _RequestAdapter((options, stream) async {
      await stream!.drain<void>();
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    });
    final api = RealApiService(
      baseUrl: 'http://127.0.0.1:8080/api/v1',
      adapter: adapter,
    );
    await expectLater(
      api.submitMyWarrantyRequest(
        const OwnWarrantyRequestData(
          categoryCode: 'CAT',
          deviceTypeCode: 'TYPE',
          brandModel: 'Máy mẫu',
          identifierType: 'SERIAL',
          serialOrImei: 'SERIAL-1234',
          symptom: 'Máy không lên nguồn',
          preferredStation: 'STATION',
        ),
      ),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.calls, 1);
  });

  test('authenticated list and detail use the customer portal paths', () async {
    final adapter = _RequestAdapter((options, stream) async {
      if (options.uri.path == '/api/v1/portal/my/warranty-requests') {
        return ResponseBody.fromString(
          '[{"code":"YC-1","status":"PENDING_INTAKE","brandModel":"Máy mẫu"}]',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      expect(options.uri.path, '/api/v1/portal/my/warranty-requests/YC-1');
      return ResponseBody.fromString(
        '{"code":"YC-1","status":"PENDING_INTAKE","symptom":"Không lên nguồn"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final api = RealApiService(
      baseUrl: 'http://127.0.0.1:8080/api/v1',
      adapter: adapter,
    );
    final list = await api.getMyWarrantyRequests();
    final detail = await api.getMyWarrantyRequest(list.single.code);
    expect(list.single.status, 'PENDING_INTAKE');
    expect(detail.symptom, 'Không lên nguồn');
    expect(adapter.calls, 2);
  });

  test('submission guard prevents concurrent duplicate request', () async {
    final api = _FakePortalApi()..pending = Completer<String>();
    final auth = await _authenticated(api);
    final requests = RequestViewModel(auth);
    addTearDown(() {
      requests.dispose();
      auth.dispose();
    });
    const payload = OwnWarrantyRequestData(
      categoryCode: 'CAT',
      deviceTypeCode: 'TYPE',
      brandModel: 'Máy mẫu',
      identifierType: 'SERIAL',
      serialOrImei: 'SERIAL-1234',
      symptom: 'Máy không lên nguồn',
      preferredStation: 'STATION',
    );
    final first = requests.submit(payload);
    await expectLater(requests.submit(payload), throwsStateError);
    expect(api.submitCount, 1);
    api.pending!.complete('YC-SERVER');
    expect(await first, 'YC-SERVER');
    expect(requests.requests, isEmpty); // The API list must supply records.
  });

  test('confirmed POST queues a fresh list after an older GET', () async {
    final api = _FakePortalApi()
      ..pendingList = Completer<List<PortalRequestSummary>>();
    final auth = await _authenticated(api);
    final requests = RequestViewModel(auth);
    addTearDown(() {
      requests.dispose();
      auth.dispose();
    });
    final oldList = api.pendingList!;
    final firstLoad = requests.refresh();
    const payload = OwnWarrantyRequestData(
      categoryCode: 'CAT',
      deviceTypeCode: 'TYPE',
      brandModel: 'Máy mẫu',
      identifierType: 'SERIAL',
      serialOrImei: 'SERIAL-1234',
      symptom: 'Máy không lên nguồn',
      preferredStation: 'STATION',
    );
    expect(await requests.submit(payload), 'YC-TEST');
    final queued = requests.refresh();
    api.pendingList = Completer<List<PortalRequestSummary>>();
    oldList.complete([]);
    await Future<void>.delayed(Duration.zero);
    api.pendingList!.complete([
      const PortalRequestSummary(code: 'YC-TEST', status: 'PENDING_INTAKE'),
    ]);
    await Future.wait([firstLoad, queued]);
    expect(api.listCount, 2);
    expect(requests.requests.single.code, 'YC-TEST');
  });

  testWidgets('device path fixes identity and rejects an incomplete form', (
    tester,
  ) async {
    final api = _FakePortalApi();
    final auth = await _authenticated(api);
    final requests = RequestViewModel(auth);
    addTearDown(() {
      requests.dispose();
      auth.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider<RequestViewModel>.value(value: requests),
        ],
        child: const MaterialApp(
          home: RealCreateRequestScreen(prefilledDevice: _device),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SERIAL: SERIAL-1234'), findsOneWidget);
    expect(find.text('Thiết bị của bạn *'), findsNothing);
    await tester.tap(find.text('GỬI YÊU CẦU'));
    await tester.pump();
    expect(find.text('Vui lòng chọn nhóm thiết bị.'), findsOneWidget);
    expect(api.submitCount, 0);
  });

  testWidgets('owned-device action hands the same device to the Real form', (
    tester,
  ) async {
    final api = _FakePortalApi();
    final auth = await _authenticated(api);
    final requests = RequestViewModel(auth);
    final router = AppRouter(auth);
    addTearDown(() {
      router.router.dispose();
      requests.dispose();
      auth.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider<RequestViewModel>.value(value: requests),
        ],
        child: MaterialApp.router(routerConfig: router.router),
      ),
    );
    router.router.go('${AppRoutes.devices}/detail', extra: _device);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu cho thiết bị này'));
    await tester.pumpAndSettle();
    expect(find.byType(RealCreateRequestScreen), findsOneWidget);
    expect(find.text('SERIAL: SERIAL-1234'), findsOneWidget);
  });

  testWidgets(
    'uncertain submission removes the send action and offers list check',
    (tester) async {
      final api = _FakePortalApi()..submitError = const NetworkException();
      final auth = await _authenticated(api);
      final requests = RequestViewModel(auth);
      addTearDown(() {
        requests.dispose();
        auth.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            ChangeNotifierProvider<RequestViewModel>.value(value: requests),
          ],
          child: const MaterialApp(
            home: RealCreateRequestScreen(prefilledDevice: _device),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      tester
          .widget<DropdownButtonFormField<String>>(dropdowns.at(0))
          .onChanged
          ?.call('CAT');
      await tester.pump();
      tester
          .widget<DropdownButtonFormField<String>>(dropdowns.at(1))
          .onChanged
          ?.call('TYPE');
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Trạm dịch vụ mong muốn *'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('Trạm dịch vụ mong muốn *:null')),
          )
          .onChanged
          ?.call('STATION');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Máy không lên nguồn');
      await tester.tap(find.text('GỬI YÊU CẦU'));
      await tester.pumpAndSettle();
      expect(api.submitCount, 1);
      expect(find.text('GỬI YÊU CẦU'), findsNothing);
      expect(find.text('Kiểm tra danh sách yêu cầu'), findsOneWidget);
    },
  );
}
