import 'package:warrant_safe/models/user_model.dart';
import 'package:warrant_safe/services/i_api_service.dart';

/// A lightweight test double for [IApiService].
///
/// Configure behaviour via the named fields before calling test methods:
///   ```dart
///   final api = FakeApiService()..loginShouldSucceed = true;
///   ```
class FakeApiService implements IApiService {
  // ── Behaviour flags ──────────────────────────────────────────────
  bool loginShouldSucceed    = true;
  bool registerShouldSucceed = true;
  bool profileShouldSucceed  = true;

  // ── Captured arguments (for assertion) ──────────────────────────
  String? capturedEmail;
  String? capturedPassword;
  bool    authTokenSet    = false;
  bool    authTokenCleared = false;

  // ── Mock return values ───────────────────────────────────────────
  UserModel mockUser = const UserModel(
    id: 'test_001',
    fullName: 'Test User',
    email: 'test@test.com',
    phone: '+84 900 000 000',
    role: 'customer',
    token: 'mock_token_abc123',
  );

  @override
  Future<UserModel> login(String email, String password) async {
    capturedEmail    = email;
    capturedPassword = password;
    if (!loginShouldSucceed) {
      throw const ApiException('Sai tài khoản hoặc mật khẩu.', statusCode: 401);
    }
    return mockUser;
  }

  @override
  Future<UserModel> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (!registerShouldSucceed) {
      throw const ApiException(
        'Email này đã được đăng ký.',
        statusCode: 409,
      );
    }
    return mockUser.copyWith(fullName: fullName, email: email, phone: phone);
  }

  @override
  Future<UserModel> getProfile(String userId) async {
    if (!profileShouldSucceed) {
      throw const ApiException('Không tìm thấy người dùng.', statusCode: 404);
    }
    return mockUser;
  }

  @override
  void setAuthToken(String token) => authTokenSet = true;

  @override
  void clearAuthToken() => authTokenCleared = true;
}
