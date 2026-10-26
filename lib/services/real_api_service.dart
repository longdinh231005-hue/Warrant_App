import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/portal_request_models.dart';
import '../models/portal_ticket_models.dart';
import '../models/portal_lookup_models.dart';
import '../models/portal_notification_models.dart';
import 'i_api_service.dart';

class RealApiService implements IApiService {
  RealApiService({required String baseUrl, HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _addInterceptors();
  }

  final Dio _dio;
  Future<String?> Function()? onAccessTokenExpired;
  Future<String?>? _refreshInFlight;
  String? _lastRenewedFromAuthorization;
  int _sessionEpoch = 0;

  // Set baseUrl dynamically
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  void _addInterceptors() {
    // Interceptors to handle global things like logging if needed
  }

  Future<Response<dynamic>> _postWithoutAuthorization(
    String path,
    Map<String, dynamic> data,
  ) {
    final request = Options(method: 'POST').compose(
      _dio.options,
      path,
      data: data,
    );
    // Keep the shared Bearer for concurrent GETs. Public auth endpoints must
    // not inherit an expired access token from the Dio defaults.
    request.headers.remove('Authorization');
    return _dio.fetch<dynamic>(request);
  }

  Future<Response<dynamic>> _get(String path) async {
    final sessionEpoch = _sessionEpoch;
    try {
      return await _dio.get(path);
    } on DioException catch (error) {
      final failedAuthorization =
          error.requestOptions.headers['Authorization'] as String?;
      if (error.response?.statusCode != 401 ||
          failedAuthorization == null ||
          sessionEpoch != _sessionEpoch ||
          onAccessTokenExpired == null) {
        _handleDioError(error);
      }
      if (kDebugMode) {
        debugPrint('GET ${error.requestOptions.path} -> 401; refresh pending');
      }

      // A different GET may already have refreshed the token. Otherwise only
      // one refresh may rotate the backend refresh credential at a time.
      final currentAuthorization =
          _dio.options.headers['Authorization'] as String?;
      String? accessToken;
      if (currentAuthorization != null &&
          currentAuthorization != failedAuthorization &&
          _lastRenewedFromAuthorization == failedAuthorization &&
          currentAuthorization.startsWith('Bearer ')) {
        accessToken = currentAuthorization.substring(7);
      } else {
        if (currentAuthorization != failedAuthorization &&
            _refreshInFlight == null) {
          _handleDioError(error);
        }
        final pending = _refreshInFlight ??= onAccessTokenExpired!();
        try {
          accessToken = await pending;
          if (accessToken != null) {
            _lastRenewedFromAuthorization = failedAuthorization;
          }
        } finally {
          if (identical(_refreshInFlight, pending)) _refreshInFlight = null;
        }
      }
      if (accessToken == null || sessionEpoch != _sessionEpoch) {
        _handleDioError(error);
      }

      // Only the failed GET is repeated, and only once. POST requests never
      // enter this path, including login, refresh and warranty submission.
      try {
        final response = await _dio.fetch<dynamic>(
          error.requestOptions.copyWith(
            headers: {
              ...error.requestOptions.headers,
              'Authorization': 'Bearer $accessToken',
            },
          ),
        );
        if (kDebugMode) {
          debugPrint(
            'GET ${error.requestOptions.path} retry -> ${response.statusCode}',
          );
        }
        return response;
      } on DioException catch (retryError) {
        if (kDebugMode) {
          debugPrint(
            'GET ${error.requestOptions.path} retry -> ${retryError.response?.statusCode ?? 'network'}',
          );
        }
        _handleDioError(retryError);
      }
    }
  }

  Never _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.response == null) {
      // Android may keep a stale pooled socket after airplane mode or a brief
      // network loss. A later user-triggered retry must open a fresh client.
      final adapter = _dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.close(force: true);
        _dio.httpClientAdapter = IOHttpClientAdapter();
      }
      throw const NetworkException();
    }

    if (e.response != null && e.response!.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        if (data['detail'] != null || data['type'] != null) {
          final detail = data['detail'] as String?;
          final fieldErrors = data['fieldErrors'] as List<dynamic>?;
          final sb = StringBuffer();
          final errors = <String, String>{};
          if (detail != null) sb.writeln(detail);
          if (fieldErrors != null && fieldErrors.isNotEmpty) {
            for (final fe in fieldErrors) {
              if (fe is Map<String, dynamic>) {
                final field = fe['field'] as String?;
                final message = fe['message'] as String?;
                if (field != null && message != null) errors[field] = message;
              }
            }
          }
          throw ApiException(
            sb.toString().trim().isEmpty
                ? 'Dữ liệu gửi đi không hợp lệ.'
                : sb.toString().trim(),
            statusCode: e.response?.statusCode,
            fieldErrors: errors,
          );
        }
      }
    }
    final message =
        (e.response?.data is Map<String, dynamic>
            ? (e.response!.data as Map<String, dynamic>)['message'] as String?
            : null) ??
        e.message ??
        'Đã xảy ra lỗi không mong muốn.';
    throw ApiException(message, statusCode: e.response?.statusCode);
  }

  @override
  void setAuthToken(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

  @override
  void clearAuthToken() {
    _sessionEpoch++;
    _lastRenewedFromAuthorization = null;
    _dio.options.headers.remove('Authorization');
  }

  @override
  Future<AuthResponse> login(String username, String password) async {
    try {
      final response = await _postWithoutAuthorization(
        '/auth/mobile/login',
        {'username': username.trim().toLowerCase(), 'password': password},
      );
      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    try {
      final response = await _postWithoutAuthorization(
        '/auth/mobile/refresh',
        {'refreshToken': refreshToken},
      );
      if (kDebugMode) {
        debugPrint('POST /auth/mobile/refresh -> ${response.statusCode}');
      }
      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (kDebugMode) {
        final data = e.response?.data;
        final rawCode = data is Map<String, dynamic> ? data['code'] : null;
        final code = rawCode is String &&
                RegExp(r'^[A-Z][A-Z0-9_]{0,63}$').hasMatch(rawCode)
            ? rawCode
            : 'unavailable';
        debugPrint(
          'POST /auth/mobile/refresh -> ${e.response?.statusCode ?? 'network'} code=$code',
        );
      }
      _handleDioError(e);
    }
  }

  @override
  Future<void> logout(String? refreshToken) async {
    try {
      await _dio.post(
        '/auth/mobile/logout',
        data: {'refreshToken': refreshToken, 'all': false},
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    throw UnimplementedError(
      'Registration via RealApiService not supported yet.',
    );
  }

  @override
  Future<UserModel> getProfile() async {
    final response = await _get('/portal/my/profile');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<OwnedDevice>> getMyDevices() async {
    final response = await _get('/portal/my/devices');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => OwnedDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PortalCatalog> getPortalCatalog() async {
    final response = await _get('/portal/catalog');
    return PortalCatalog.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<PortalRequestSummary>> getMyWarrantyRequests() async {
    final response = await _get('/portal/my/warranty-requests');
    return (response.data as List<dynamic>)
        .map(
          (item) => PortalRequestSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<PortalRequestDetail> getMyWarrantyRequest(String code) async {
    final response = await _get(
      '/portal/my/warranty-requests/${Uri.encodeComponent(code)}',
    );
    return PortalRequestDetail.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<PortalTicketSummary>> getMyTickets() async {
    final response = await _get('/portal/my/tickets');
    return (response.data as List<dynamic>)
        .map(
          (item) => PortalTicketSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<PortalTicketDetail> getPortalTicket(String code) async {
    final response = await _get('/portal/tickets/${Uri.encodeComponent(code)}');
    return PortalTicketDetail.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PortalNotificationInbox> getNotifications() async {
    final response = await _get('/notifications');
    return PortalNotificationInbox.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<void> markNotificationRead(String id) async {
    try {
      await _dio.post('/notifications/${Uri.encodeComponent(id)}/read');
    } on DioException catch (error) {
      _handleDioError(error);
    }
  }

  @override
  Future<PortalLookupRecord> lookupPortal(String code, String phone) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/portal/lookup',
        data: {'code': code.trim().toUpperCase(), 'phone': phone.trim()},
        options: Options(headers: {'Authorization': null}),
      );
      final grant = response.data!;
      final scope = grant['scope'] as String?;
      final grantedCode = grant['code'] as String?;
      final token = grant['accessToken'] as String?;
      if (grantedCode == null || token == null || token.isEmpty) {
        throw const ApiException('Phản hồi tra cứu không hợp lệ.');
      }
      // Keep the scoped token in this method. It must never replace the
      // signed-in customer's token or be persisted with the session.
      final path = switch (scope) {
        'REQUEST' =>
          '/portal/warranty-requests/${Uri.encodeComponent(grantedCode)}',
        'TICKET' => '/portal/tickets/${Uri.encodeComponent(grantedCode)}',
        _ => throw const ApiException('Phạm vi tra cứu không hợp lệ.'),
      };
      final detail = await _dio.get<Map<String, dynamic>>(
        path,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return scope == 'REQUEST'
          ? PortalLookupRecord.request(
              PortalRequestDetail.fromJson(detail.data!),
            )
          : PortalLookupRecord.ticket(
              PortalTicketDetail.fromJson(detail.data!),
            );
    } on DioException catch (error) {
      _handleDioError(error);
    }
  }

  @override
  Future<PortalTicketDetail> decidePortalQuotation(
    String ticketCode,
    String decision, {
    String? reason,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/portal/tickets/${Uri.encodeComponent(ticketCode)}/quotation-decision',
        data: {'decision': decision, 'reason': reason},
      );
      return PortalTicketDetail.fromJson(response.data!);
    } on DioException catch (error) {
      _handleDioError(error);
    }
  }

  @override
  Future<String> submitMyWarrantyRequest(OwnWarrantyRequestData data) async {
    try {
      final form = FormData();
      form.fields.add(MapEntry('data', jsonEncode(data.toJson())));
      for (final file in data.attachments) {
        form.files.add(
          MapEntry(
            'files',
            MultipartFile.fromStream(
              file.openRead,
              file.length,
              filename: file.name,
            ),
          ),
        );
      }
      final response = await _dio.post(
        '/portal/my/warranty-requests',
        data: form,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      if (response.statusCode != 201) {
        throw ApiException(
          'Máy chủ chưa xác nhận tạo yêu cầu.',
          statusCode: response.statusCode,
        );
      }
      final code = (response.data as Map<String, dynamic>)['code'] as String?;
      if (code == null || code.trim().isEmpty) {
        throw const ApiException(
          'Máy chủ không trả mã yêu cầu. Vui lòng kiểm tra danh sách trước khi gửi lại.',
        );
      }
      return code;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }
}
