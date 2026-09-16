import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/i_api_service.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthViewModel
// ─────────────────────────────────────────────────────────────────────────────

/// MVVM ViewModel for the Authentication flow.
///
/// **Dependencies (injectable for testing):**
///   • [IApiService]   — mock or real HTTP client
///   • [TokenStorage]  — encrypted key-value store
///
/// **Reactive state exposed to the UI:**
///   • [isLoading]      — spinner state
///   • [errorMessage]   — SnackBar error text
///   • [currentUser]    — logged-in user, null when logged out
///   • [isAuthenticated]— convenience boolean
///
/// **GoRouter integration:**
/// This class is a [ChangeNotifier]. Pass it as `refreshListenable` to
/// [GoRouter] so route redirects re-evaluate on every auth state change.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    IApiService? apiService,
    TokenStorage? tokenStorage,
  })  : _api = apiService ?? MockApiService(),
        _storage = tokenStorage ?? SecureTokenStorage();

  final IApiService _api;
  final TokenStorage _storage;

  // ── Reactive state ───────────────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// `true` when a user session is active — used by GoRouter for redirects.
  bool get isAuthenticated => _currentUser != null;

  // ── Internal helpers ─────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _begin() {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
  }

  void _end() {
    _isLoading = false;
    notifyListeners();
  }

  // ── Public actions ───────────────────────────────────────────────────────

  /// Authenticates the user with [email] and [password].
  ///
  /// On success: persists session, sets [currentUser], notifies GoRouter.
  /// On failure: sets [errorMessage] for the UI to display.
  /// Returns `true` on success.
  Future<bool> loginUser(String email, String password) async {
    _begin();
    try {
      final user = await _api.login(email.trim(), password);
      await _storage.saveSession(token: user.token, userId: user.id);
      _api.setAuthToken(user.token);
      _currentUser = user;
      _end();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.');
      _setLoading(false);
      return false;
    }
  }

  /// Creates a new account and immediately logs the user in.
  /// Returns `true` on success.
  Future<bool> registerUser({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    _begin();
    try {
      final user = await _api.register(
        fullName: fullName.trim(),
        phone: phone.trim(),
        email: email.trim(),
        password: password,
      );
      await _storage.saveSession(token: user.token, userId: user.id);
      _api.setAuthToken(user.token);
      _currentUser = user;
      _end();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.');
      _setLoading(false);
      return false;
    }
  }

  /// Refreshes [currentUser] from the API (e.g. after profile edits).
  Future<void> refreshProfile() async {
    if (_currentUser == null) return;
    _begin();
    try {
      _currentUser = await _api.getProfile(_currentUser!.id);
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('Không thể tải dữ liệu hồ sơ. Vui lòng thử lại.');
    } finally {
      _end();
    }
  }

  /// Reads the persisted session from [TokenStorage] on app startup.
  ///
  /// If a valid token + userId exists, re-fetches the profile.
  /// On failure (expired / invalid), silently clears the session.
  /// GoRouter's [refreshListenable] will re-evaluate redirects once done.
  Future<void> tryAutoLogin() async {
    _setLoading(true);
    try {
      final session = await _storage.readSession();
      final token  = session['token'];
      final userId = session['userId'];

      if (token == null || userId == null) return;

      _api.setAuthToken(token);
      _currentUser = await _api.getProfile(userId);
    } on ApiException {
      await _storage.clearSession();
    } catch (_) {
      await _storage.clearSession();
    } finally {
      _setLoading(false);
    }
  }

  /// Logs the user out:
  ///   • Clears [TokenStorage] and [ApiService] auth header.
  ///   • Sets [currentUser] = null → GoRouter redirects to `/login`.
  Future<void> logout() async {
    _setLoading(true);
    await _storage.clearSession();
    _api.clearAuthToken();
    _currentUser  = null;
    _errorMessage = null;
    _setLoading(false);
  }

  /// Resets [errorMessage] — call after displaying a SnackBar.
  void clearError() => _setError(null);
}
