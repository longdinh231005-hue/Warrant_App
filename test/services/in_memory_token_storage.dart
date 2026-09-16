import 'package:warrant_safe/services/token_storage.dart';

/// In-memory implementation of [TokenStorage] for unit tests.
/// No I/O, no encryption — just a map.
class InMemoryTokenStorage implements TokenStorage {
  String? _token;
  String? _userId;

  @override
  Future<void> saveSession({
    required String token,
    required String userId,
  }) async {
    _token  = token;
    _userId = userId;
  }

  @override
  Future<Map<String, String?>> readSession() async =>
      {'token': _token, 'userId': _userId};

  @override
  Future<void> clearSession() async {
    _token  = null;
    _userId = null;
  }

  /// Exposes raw values for assertions in tests.
  String? get storedToken  => _token;
  String? get storedUserId => _userId;
}
