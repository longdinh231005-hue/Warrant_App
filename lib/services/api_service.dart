import 'package:dio/dio.dart';
import '../models/user_model.dart';
import 'i_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock credentials
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Map<String, dynamic>> _mockUsers = {
  'admin@gmail.com': {
    'password': '123456',
    'user': {
      'id': 'usr_001',
      'fullName': 'Alex Morgan',
      'email': 'admin@gmail.com',
      'phone': '+84 912 345 678',
      'role': 'admin',
      'token': 'mock_jwt_eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.admin_001',
    },
  },
  'user@gmail.com': {
    'password': 'password123',
    'user': {
      'id': 'usr_002',
      'fullName': 'Nguyen Van B',
      'email': 'user@gmail.com',
      'phone': '+84 909 123 456',
      'role': 'customer',
      'token': 'mock_jwt_eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.customer_002',
    },
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// MockApiService
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory mock implementation of [IApiService].
///
/// All methods use [Future.delayed] to simulate realistic network latency.
/// No real HTTP calls are made. To switch to the real backend, replace
/// the [IApiService] injection in [AuthViewModel] with [RealApiService].
class MockApiService implements IApiService {
  static const Duration _latency = Duration(milliseconds: 1500);

  // Dio is kept here so we can inject the Bearer header even in mock mode,
  // giving the same API surface as [RealApiService].
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.warrantsafe.com/v1',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  @override
  void setAuthToken(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

  @override
  void clearAuthToken() =>
      _dio.options.headers.remove('Authorization');

  @override
  Future<UserModel> login(String email, String password) async {
    await Future.delayed(_latency);

    final entry = _mockUsers[email.trim().toLowerCase()];
    if (entry == null || entry['password'] != password) {
      throw const ApiException('Sai tài khoản hoặc mật khẩu.', statusCode: 401);
    }

    return UserModel.fromJson(
      Map<String, dynamic>.from(entry['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<UserModel> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    await Future.delayed(_latency);

    if (_mockUsers.containsKey(email.trim().toLowerCase())) {
      throw const ApiException(
        'Email này đã được đăng ký. Vui lòng sử dụng email khác.',
        statusCode: 409,
      );
    }

    return UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      email: email.trim().toLowerCase(),
      phone: phone,
      role: 'customer',
      token: 'mock_jwt_new_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Future<UserModel> getProfile(String userId) async {
    await Future.delayed(_latency);

    for (final entry in _mockUsers.values) {
      final userMap = entry['user'] as Map<String, dynamic>;
      if (userMap['id'] == userId) {
        return UserModel.fromJson(Map<String, dynamic>.from(userMap));
      }
    }

    throw const ApiException(
      'Không tìm thấy thông tin người dùng.',
      statusCode: 404,
    );
  }
}
