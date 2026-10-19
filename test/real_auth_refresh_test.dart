import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warrant_safe/services/i_api_service.dart';
import 'package:warrant_safe/services/real_api_service.dart';
import 'package:warrant_safe/services/token_storage.dart';
import 'package:warrant_safe/viewmodels/auth_viewmodel.dart';

ResponseBody _json(Object value, int status) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

bool _hasAuthorization(RequestOptions request) => request.headers.keys.any(
  (key) => key.toLowerCase() == 'authorization',
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri.path}');
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _Storage implements TokenStorage {
  String? access = 'old-access';
  String? refresh = 'refresh-zero';
  String? userId = 'account-1';

  @override
  Future<Map<String, String?>> readSession({bool isMock = false}) async => {
    'token': access,
    'refreshToken': refresh,
    'userId': userId,
  };

  @override
  Future<void> saveSession({
    required String token,
    String? refreshToken,
    required String userId,
    bool isMock = false,
  }) async {
    access = token;
    refresh = refreshToken;
    this.userId = userId;
  }

  @override
  Future<void> clearSession({bool isMock = false}) async {
    access = null;
    refresh = null;
    userId = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'expired requests without renewal report 401 on both GET paths',
    () async {
      final adapter = _Adapter(
        (_) async => _json({'type': 'AUTH_TOKEN_INVALID'}, 401),
      );
      final api = RealApiService(
        baseUrl: 'http://test/api/v1',
        adapter: adapter,
      );
      api.setAuthToken('old-access');

      await expectLater(
        api.getMyWarrantyRequests(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      await expectLater(
        api.getMyTickets(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(adapter.calls, [
        'GET /api/v1/portal/my/warranty-requests',
        'GET /api/v1/portal/my/tickets',
      ]);
    },
  );

  test(
    'expired GET gets one refresh and one retry with the new token',
    () async {
      final adapter = _Adapter((request) async {
        expect(request.uri.path, '/api/v1/portal/my/warranty-requests');
        return request.headers['Authorization'] == 'Bearer new-access'
            ? _json([], 200)
            : _json({'type': 'AUTH_TOKEN_INVALID'}, 401);
      });
      final api = RealApiService(
        baseUrl: 'http://test/api/v1',
        adapter: adapter,
      );
      api.setAuthToken('old-access');
      var refreshes = 0;
      api.onAccessTokenExpired = () async {
        refreshes++;
        api.setAuthToken('new-access');
        return 'new-access';
      };

      expect(await api.getMyWarrantyRequests(), isEmpty);
      expect(refreshes, 1);
      expect(adapter.calls, [
        'GET /api/v1/portal/my/warranty-requests',
        'GET /api/v1/portal/my/warranty-requests',
      ]);
    },
  );

  test('simultaneous expired GETs share one refresh rotation', () async {
    final gate = Completer<void>();
    final refreshStarted = Completer<void>();
    final adapter = _Adapter((request) async {
      expect(request.method, 'GET');
      return request.headers['Authorization'] == 'Bearer new-access'
          ? _json([], 200)
          : _json({'type': 'AUTH_TOKEN_INVALID'}, 401);
    });
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    api.setAuthToken('old-access');
    var refreshes = 0;
    api.onAccessTokenExpired = () async {
      refreshes++;
      refreshStarted.complete();
      await gate.future;
      api.setAuthToken('new-access');
      return 'new-access';
    };

    final requests = Future.wait([
      api.getMyWarrantyRequests(),
      api.getMyTickets(),
    ]);
    await refreshStarted.future;
    expect(refreshes, 1);
    gate.complete();
    await requests;
    expect(refreshes, 1);
    expect(adapter.calls.where((call) => call.startsWith('GET ')).length, 4);
  });

  test('a late 401 from the old token uses the completed renewal', () async {
    final releaseLateResponse = Completer<void>();
    final adapter = _Adapter((request) async {
      if (request.uri.path.endsWith('/my/tickets') &&
          request.headers['Authorization'] == 'Bearer old-access') {
        await releaseLateResponse.future;
      }
      return request.headers['Authorization'] == 'Bearer new-access'
          ? _json([], 200)
          : _json({'type': 'AUTH_TOKEN_INVALID'}, 401);
    });
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    api.setAuthToken('old-access');
    var refreshes = 0;
    api.onAccessTokenExpired = () async {
      refreshes++;
      api.setAuthToken('new-access');
      return 'new-access';
    };

    final lateTickets = api.getMyTickets();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await api.getMyWarrantyRequests();
    releaseLateResponse.complete();
    await lateTickets;
    expect(refreshes, 1);
    expect(adapter.calls.length, 4);
  });

  test('a GET from a logged-out session cannot use another token', () async {
    final releaseOldResponse = Completer<void>();
    final adapter = _Adapter((request) async {
      await releaseOldResponse.future;
      return _json({'type': 'AUTH_TOKEN_INVALID'}, 401);
    });
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    api.setAuthToken('old-access');
    var refreshes = 0;
    api.onAccessTokenExpired = () async {
      refreshes++;
      return 'new-access';
    };

    final oldGet = api.getMyTickets();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    api.clearAuthToken();
    api.setAuthToken('other-session');
    releaseOldResponse.complete();
    await expectLater(oldGet, throwsA(isA<ApiException>()));
    expect(refreshes, 0);
    expect(adapter.calls.length, 1);
  });

  test(
    'ViewModel rotates stored credentials once for two expired GETs',
    () async {
      SharedPreferences.setMockInitialValues({
        'isMock': false,
        'baseUrl': 'http://test/api/v1',
      });
      final storage = _Storage();
      var refreshes = 0;
      var expiredGets = 0;
      var retriedGets = 0;
      final adapter = _Adapter((request) async {
        if (request.uri.path.endsWith('/auth/mobile/refresh')) {
          expect(request.method, 'POST');
          expect(_hasAuthorization(request), isFalse);
          refreshes++;
          return _json({
            'accessToken': refreshes == 1 ? 'old-access' : 'new-access',
            'expiresIn': 60,
            'refreshToken': refreshes == 1 ? 'refresh-one' : 'refresh-two',
            'refreshExpiresIn': 3600,
            'user': {
              'accountId': 'account-1',
              'displayName': 'Khách thử',
              'username': 'customer',
              'roles': [
                {'code': 'CUSTOMER'},
              ],
            },
          }, 200);
        }
        if (request.uri.path.endsWith('/portal/my/profile')) {
          expect(request.headers['Authorization'], 'Bearer old-access');
          return _json({'customerCode': 'KH-1', 'fullName': 'Khách thử'}, 200);
        }
        if (request.headers['Authorization'] == 'Bearer old-access') {
          expiredGets++;
          return _json({'type': 'AUTH_TOKEN_INVALID'}, 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-access');
        retriedGets++;
        return _json([], 200);
      });
      final api = RealApiService(
        baseUrl: 'http://test/api/v1',
        adapter: adapter,
      );
      final auth = AuthViewModel(tokenStorage: storage, apiService: api);
      await auth.initialize();

      await Future.wait([auth.getMyWarrantyRequests(), auth.getMyTickets()]);
      expect(refreshes, 2); // one startup restoration and one shared renewal
      expect(expiredGets, 2);
      expect(retriedGets, 2);
      expect(storage.access, 'new-access');
      expect(storage.refresh, 'refresh-two');
      expect(auth.isAuthenticated, isTrue);
      expect(
        adapter.calls.where((call) => call.endsWith('/my/tickets')).length,
        2,
      );
      expect(
        adapter.calls
            .where((call) => call.endsWith('/my/warranty-requests'))
            .length,
        2,
      );
      auth.dispose();
    },
  );

  test('rejected refresh does not repeat the GET', () async {
    final adapter = _Adapter(
      (_) async => _json({'type': 'AUTH_TOKEN_INVALID'}, 401),
    );
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    api.setAuthToken('old-access');
    api.onAccessTokenExpired = () async =>
        throw const ApiException('Refresh rejected', statusCode: 401);

    await expectLater(
      api.getMyTickets(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(adapter.calls, ['GET /api/v1/portal/my/tickets']);
  });

  test('network outage remains retryable without refreshing', () async {
    var disconnected = true;
    final adapter = _Adapter((request) async {
      if (disconnected) {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        );
      }
      return _json([], 200);
    });
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    api.setAuthToken('old-access');
    var refreshes = 0;
    api.onAccessTokenExpired = () async {
      refreshes++;
      return 'new-access';
    };

    await expectLater(api.getMyTickets(), throwsA(isA<NetworkException>()));
    disconnected = false;
    expect(await api.getMyTickets(), isEmpty);
    expect(refreshes, 0);
    expect(adapter.calls.length, 2);
  });

  test('a second 401 after renewal does not refresh again', () async {
    final adapter = _Adapter(
      (_) async => _json({'type': 'AUTH_TOKEN_INVALID'}, 401),
    );
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    api.setAuthToken('old-access');
    var refreshes = 0;
    api.onAccessTokenExpired = () async {
      refreshes++;
      api.setAuthToken('new-access');
      return 'new-access';
    };

    await expectLater(api.getMyTickets(), throwsA(isA<ApiException>()));
    expect(refreshes, 1);
    expect(adapter.calls.length, 2);
  });

  test('a failed POST is never repeated or refreshed', () async {
    final adapter = _Adapter(
      (_) async => _json({'type': 'AUTH_TOKEN_INVALID'}, 401),
    );
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    var refreshes = 0;
    api.onAccessTokenExpired = () async {
      refreshes++;
      return 'new-access';
    };

    await expectLater(
      api.login('fixture-user', 'fixture-value'),
      throwsA(isA<ApiException>()),
    );
    expect(refreshes, 0);
    expect(adapter.calls, ['POST /api/v1/auth/mobile/login']);
  });

  test('login does not inherit a previously set Bearer', () async {
    final adapter = _Adapter((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/auth/mobile/login');
      expect(_hasAuthorization(request), isFalse);
      return _json({'type': 'AUTH_INVALID_CREDENTIALS'}, 401);
    });
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    api.setAuthToken('expired-access');

    await expectLater(
      api.login('fixture-user', 'fixture-value'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(adapter.calls, ['POST /api/v1/auth/mobile/login']);
  });

  test(
    'invalid refresh credential clears only the Real local session',
    () async {
      SharedPreferences.setMockInitialValues({
        'isMock': false,
        'baseUrl': 'http://test/api/v1',
      });
      final storage = _Storage();
      var refreshes = 0;
      final adapter = _Adapter((request) async {
        if (request.uri.path.endsWith('/auth/mobile/refresh')) {
          expect(_hasAuthorization(request), isFalse);
          refreshes++;
          if (refreshes == 2) {
            return _json({'type': 'AUTH_TOKEN_INVALID'}, 401);
          }
          return _json({
            'accessToken': 'old-access',
            'expiresIn': 60,
            'refreshToken': 'refresh-one',
            'refreshExpiresIn': 3600,
            'user': {
              'accountId': 'account-1',
              'displayName': 'Khách thử',
              'username': 'customer',
              'roles': [
                {'code': 'CUSTOMER'},
              ],
            },
          }, 200);
        }
        if (request.uri.path.endsWith('/portal/my/profile')) {
          return _json({'customerCode': 'KH-1', 'fullName': 'Khách thử'}, 200);
        }
        expect(request.headers['Authorization'], 'Bearer old-access');
        return _json({'type': 'AUTH_TOKEN_INVALID'}, 401);
      });
      final api = RealApiService(
        baseUrl: 'http://test/api/v1',
        adapter: adapter,
      );
      final auth = AuthViewModel(tokenStorage: storage, apiService: api);
      await auth.initialize();
      expect(auth.isAuthenticated, isTrue);

      await expectLater(auth.getMyTickets(), throwsA(isA<ApiException>()));
      expect(refreshes, 2); // startup restoration, then one failed renewal
      expect(auth.isAuthenticated, isFalse);
      expect(storage.refresh, isNull);
      expect(
        adapter.calls.where((call) => call.endsWith('/my/tickets')).length,
        1,
      );
      auth.dispose();
    },
  );

  test('temporary refresh error keeps the Real local session', () async {
    SharedPreferences.setMockInitialValues({
      'isMock': false,
      'baseUrl': 'http://test/api/v1',
    });
    final storage = _Storage();
    var refreshes = 0;
    final adapter = _Adapter((request) async {
      if (request.uri.path.endsWith('/auth/mobile/refresh')) {
        refreshes++;
        if (refreshes == 2) {
          return _json({'type': 'TEMPORARY_FAILURE'}, 503);
        }
        return _json({
          'accessToken': 'old-access',
          'expiresIn': 60,
          'refreshToken': 'refresh-one',
          'refreshExpiresIn': 3600,
          'user': {
            'accountId': 'account-1',
            'displayName': 'Khách thử',
            'username': 'customer',
            'roles': [
              {'code': 'CUSTOMER'},
            ],
          },
        }, 200);
      }
      if (request.uri.path.endsWith('/portal/my/profile')) {
        return _json({'customerCode': 'KH-1', 'fullName': 'Khách thử'}, 200);
      }
      return _json({'type': 'AUTH_TOKEN_INVALID'}, 401);
    });
    final api = RealApiService(baseUrl: 'http://test/api/v1', adapter: adapter);
    final auth = AuthViewModel(tokenStorage: storage, apiService: api);
    await auth.initialize();

    await expectLater(
      auth.getMyTickets(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );
    expect(auth.isAuthenticated, isTrue);
    expect(storage.refresh, 'refresh-one');
    expect(
      adapter.calls.where((call) => call.endsWith('/my/tickets')).length,
      1,
    );
    auth.dispose();
  });
}
