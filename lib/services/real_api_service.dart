import 'package:dio/dio.dart';
import '../models/user_model.dart';
import 'i_api_service.dart';

/// Production HTTP implementation of [IApiService] using Dio.
///
/// Replace the [IApiService] injection in [AuthViewModel] with this class
/// when your backend is ready. All endpoint paths match the WarrantSafe API spec.
///
/// **Migration steps:**
/// 1. Set [_baseUrl] to your real backend URL.
/// 2. Ensure the backend returns JSON matching [UserModel.fromJson].
/// 3. Swap `MockApiService()` for `RealApiService()` in [AuthViewModel].
class RealApiService implements IApiService {
  RealApiService({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? 'https://api.warrantsafe.com/v1',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    _addInterceptors();
  }

  final Dio _dio;

  void _addInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          final message = e.response?.data?['message'] as String? ??
              e.message ??
              'An unexpected error occurred.';
          handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: ApiException(message, statusCode: e.response?.statusCode),
              type: e.type,
              response: e.response,
            ),
          );
        },
      ),
    );
  }

  @override
  void setAuthToken(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

  @override
  void clearAuthToken() =>
      _dio.options.headers.remove('Authorization');

  // ── AUTH endpoints ───────────────────────────────────────────────────────

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(e.message ?? 'Đăng nhập thất bại.', statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<UserModel> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'fullName': fullName,
          'phone': phone,
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(e.message ?? 'Đăng ký thất bại.', statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<UserModel> getProfile(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(e.message ?? 'Không thể tải hồ sơ.', statusCode: e.response?.statusCode);
    }
  }
}
