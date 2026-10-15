import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/portal_request_models.dart';
import '../models/portal_ticket_models.dart';
import '../services/i_api_service.dart';
import '../services/api_service.dart';
import '../services/real_api_service.dart';
import '../services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({TokenStorage? tokenStorage, IApiService? apiService})
    : _storage = tokenStorage ?? SecureTokenStorage(),
      _api = apiService ?? MockApiService(),
      _hasInjectedApi = apiService != null;

  final bool _hasInjectedApi;

  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();
    try {
      await _loadSettings();
      await tryAutoLogin();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMock = prefs.getBool('isMock') ?? true;

    // Explicit build config for production, fallback to local for debug
    const String envUrl = String.fromEnvironment('API_URL', defaultValue: '');
    String defaultUrl = envUrl.isNotEmpty
        ? envUrl
        : (kDebugMode ? 'http://10.0.2.2:8080/api/v1' : '');

    if (!kDebugMode && !_isMock) {
      if (defaultUrl.isEmpty) {
        throw Exception('Release build must specify a valid API_URL.');
      }
      final uri = Uri.tryParse(defaultUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.path != '/api/v1') {
        throw Exception(
          'Release build API_URL must be a valid HTTPS URL with a host and /api/v1 path.',
        );
      }
    }

    if (kDebugMode) {
      _baseUrl = prefs.getString('baseUrl') ?? defaultUrl;
    } else {
      _baseUrl = defaultUrl; // Do not allow editing in release
    }

    if (!_hasInjectedApi) {
      if (_isMock) {
        _api = MockApiService();
      } else {
        _api = RealApiService(baseUrl: _baseUrl);
      }
    }
  }

  late IApiService _api;
  final TokenStorage _storage;

  @visibleForTesting
  void setApiForTesting(IApiService api) {
    _api = api;
  }

  bool _isMock = true;
  bool get isMock => _isMock;

  String _baseUrl = 'http://10.0.2.2:8080/api/v1';
  String get baseUrl => _baseUrl;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  bool _hasSessionPendingRetry = false;
  bool get hasSessionPendingRetry => _hasSessionPendingRetry;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  Future<void> toggleMockMode(bool value) async {
    if (_isMock == value) return;
    if (_isLoading) return;

    _setLoading(true);
    try {
      // Clear session when switching modes (using original API)
      await logout(keepLoading: true);

      _isMock = value;
      if (!_hasInjectedApi) {
        if (_isMock) {
          _api = MockApiService();
        } else {
          _api = RealApiService(baseUrl: _baseUrl);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isMock', _isMock);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setBaseUrl(String url) async {
    if (!kDebugMode) return; // Allow editable local URLs only in debug mode

    // Basic validation
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.path != '/api/v1') {
      throw Exception(
        'Vui lòng nhập một URL hợp lệ có chứa host và path /api/v1 (ví dụ: http://10.0.2.2:8080/api/v1).',
      );
    }

    _baseUrl = url;
    if (!_isMock && _api is RealApiService) {
      (_api as RealApiService).setBaseUrl(url);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', _baseUrl);

    notifyListeners();
  }

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

  Future<bool> loginUser(String email, String password) async {
    _begin();
    try {
      final response = await _api.login(email.trim(), password);
      await _storage.saveSession(
        token: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.user.id,
        isMock: _isMock,
      );
      _api.setAuthToken(response.accessToken);
      _currentUser = response.user;
      await refreshProfile(); // Load additional profile details
      _end();
      return true;
    } on NetworkException catch (_) {
      _setError('Lỗi kết nối mạng, vui lòng kiểm tra lại.');
      _setLoading(false);
      return false;
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

  Future<bool> registerUser({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    _begin();
    try {
      final response = await _api.register(
        fullName: fullName.trim(),
        phone: phone.trim(),
        email: email.trim(),
        password: password,
      );
      await _storage.saveSession(
        token: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.user.id,
        isMock: _isMock,
      );
      _api.setAuthToken(response.accessToken);
      _currentUser = response.user;
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

  Future<void> refreshProfile() async {
    if (_currentUser == null) return;
    _begin();
    try {
      final profile = await _api.getProfile();
      _currentUser = _currentUser!.copyWith(
        customerCode: profile.customerCode,
        fullName: profile.fullName,
        phone: profile.phone,
        email: profile.email,
        address: profile.address,
      );
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('Không thể tải dữ liệu hồ sơ. Vui lòng thử lại.');
    } finally {
      _end();
    }
  }

  Future<List<OwnedDevice>> getMyDevices() {
    return _api.getMyDevices();
  }

  Future<PortalCatalog> getPortalCatalog() => _api.getPortalCatalog();

  Future<List<PortalRequestSummary>> getMyWarrantyRequests() =>
      _api.getMyWarrantyRequests();

  Future<PortalRequestDetail> getMyWarrantyRequest(String code) =>
      _api.getMyWarrantyRequest(code);

  Future<List<PortalTicketSummary>> getMyTickets() => _api.getMyTickets();

  Future<PortalTicketDetail> getPortalTicket(String code) =>
      _api.getPortalTicket(code);

  Future<String> submitMyWarrantyRequest(OwnWarrantyRequestData data) =>
      _api.submitMyWarrantyRequest(data);

  Future<void> tryAutoLogin() async {
    _setLoading(true);
    try {
      final session = await _storage.readSession(isMock: _isMock);
      final refreshToken = session['refreshToken'];
      final token = session['token'];

      if (refreshToken != null) {
        try {
          final response = await _api.refresh(refreshToken);
          await _storage.saveSession(
            token: response.accessToken,
            refreshToken: response.refreshToken,
            userId: response.user.id,
            isMock: _isMock,
          );
          _api.setAuthToken(response.accessToken);
          _currentUser = response.user;
          await refreshProfile(); // Ensure profile is loaded after refresh
          _hasSessionPendingRetry = false;
          return;
        } on NetworkException {
          rethrow;
        } on ApiException catch (e) {
          if (e.statusCode == 400 ||
              e.statusCode == 401 ||
              e.statusCode == 403) {
            await _storage.clearSession(isMock: _isMock);
            _hasSessionPendingRetry = false;
            return;
          }
          rethrow;
        } catch (_) {
          rethrow;
        }
      }

      if (token != null) {
        await _storage.clearSession(isMock: _isMock);
        _hasSessionPendingRetry = false;
      } else {
        await _storage.clearSession(isMock: _isMock);
        _hasSessionPendingRetry = false;
      }
    } on NetworkException catch (e) {
      _setError(e.message);
      _hasSessionPendingRetry = true;
    } on ApiException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 401 || e.statusCode == 403) {
        await _storage.clearSession(isMock: _isMock);
        _hasSessionPendingRetry = false;
      } else {
        _hasSessionPendingRetry = true;
      }
      _setError(e.message);
    } catch (_) {
      _hasSessionPendingRetry = true;
      _setError('Đã xảy ra lỗi không xác định. Vui lòng thử lại.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout({bool keepLoading = false}) async {
    _setLoading(true);
    try {
      final session = await _storage.readSession(isMock: _isMock);
      await _api.logout(session['refreshToken']);
    } catch (_) {
      // Ignore errors during logout
    }
    await _storage.clearSession(isMock: _isMock);
    _api.clearAuthToken();
    _currentUser = null;
    _errorMessage = null;
    _hasSessionPendingRetry = false;
    if (!keepLoading) _setLoading(false);
  }

  void clearError() => _setError(null);
}
