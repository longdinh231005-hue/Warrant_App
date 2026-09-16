import '../models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom exception (shared between Mock and Real implementations)
// ─────────────────────────────────────────────────────────────────────────────

/// Typed exception that wraps all API-level errors.
/// The ViewModel catches [ApiException] without leaking Dio internals.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;

  /// HTTP status code when available (null for network / mock errors).
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface — the ViewModel only depends on this
// ─────────────────────────────────────────────────────────────────────────────

/// Defines the contract for all API operations used by [AuthViewModel].
///
/// Concrete implementations:
///   • [MockApiService]  — in-memory mock with simulated latency (current)
///   • [RealApiService]  — Dio-backed HTTP client (future)
abstract class IApiService {
  /// Authenticates the user and returns a [UserModel] containing the JWT.
  /// Throws [ApiException] on invalid credentials.
  Future<UserModel> login(String email, String password);

  /// Creates a new account.
  /// Throws [ApiException] if [email] is already registered.
  Future<UserModel> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  });

  /// Fetches the profile for the given [userId].
  /// Throws [ApiException] if not found.
  Future<UserModel> getProfile(String userId);

  /// Attaches a Bearer token to all subsequent requests.
  void setAuthToken(String token);

  /// Removes the Bearer token (called on logout).
  void clearAuthToken();
}
