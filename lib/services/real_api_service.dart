import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/user_model.dart';
import '../models/portal_request_models.dart';
import '../models/portal_ticket_models.dart';
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

  // Set baseUrl dynamically
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  void _addInterceptors() {
    // Interceptors to handle global things like logging if needed
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
  void clearAuthToken() => _dio.options.headers.remove('Authorization');

  @override
  Future<AuthResponse> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/auth/mobile/login',
        data: {'username': username.trim().toLowerCase(), 'password': password},
      );
      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/auth/mobile/refresh',
        data: {'refreshToken': refreshToken},
      );
      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
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
    try {
      final response = await _dio.get('/portal/my/profile');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<OwnedDevice>> getMyDevices() async {
    try {
      final response = await _dio.get('/portal/my/devices');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => OwnedDevice.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<PortalCatalog> getPortalCatalog() async {
    try {
      final response = await _dio.get('/portal/catalog');
      return PortalCatalog.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<PortalRequestSummary>> getMyWarrantyRequests() async {
    try {
      final response = await _dio.get('/portal/my/warranty-requests');
      return (response.data as List<dynamic>)
          .map(
            (item) =>
                PortalRequestSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<PortalRequestDetail> getMyWarrantyRequest(String code) async {
    try {
      final response = await _dio.get(
        '/portal/my/warranty-requests/${Uri.encodeComponent(code)}',
      );
      return PortalRequestDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<PortalTicketSummary>> getMyTickets() async {
    try {
      final response = await _dio.get('/portal/my/tickets');
      return (response.data as List<dynamic>)
          .map(
            (item) =>
                PortalTicketSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<PortalTicketDetail> getPortalTicket(String code) async {
    try {
      final response = await _dio.get(
        '/portal/tickets/${Uri.encodeComponent(code)}',
      );
      return PortalTicketDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<String> submitMyWarrantyRequest(OwnWarrantyRequestData data) async {
    try {
      final response = await _dio.post(
        '/portal/my/warranty-requests',
        data: FormData.fromMap({'data': jsonEncode(data.toJson())}),
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
