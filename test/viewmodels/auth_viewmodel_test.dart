import 'package:flutter_test/flutter_test.dart';
import 'package:warrant_safe/viewmodels/auth_viewmodel.dart';

import '../services/fake_api_service.dart';
import '../services/in_memory_token_storage.dart';

void main() {
  // ── Shared setup ─────────────────────────────────────────────────
  late FakeApiService     fakeApi;
  late InMemoryTokenStorage fakeStorage;
  late AuthViewModel      vm;

  setUp(() {
    fakeApi     = FakeApiService();
    fakeStorage = InMemoryTokenStorage();
    vm = AuthViewModel(apiService: fakeApi, tokenStorage: fakeStorage);
  });

  tearDown(() => vm.dispose());

  // ────────────────────────────────────────────────────────────────────
  // loginUser
  // ────────────────────────────────────────────────────────────────────

  group('loginUser', () {
    test('returns true and sets currentUser on success', () async {
      fakeApi.loginShouldSucceed = true;

      final result = await vm.loginUser('test@test.com', 'password');

      expect(result, isTrue);
      expect(vm.isAuthenticated, isTrue);
      expect(vm.currentUser?.email, equals('test@test.com'));
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('persists token and userId to storage on success', () async {
      fakeApi.loginShouldSucceed = true;

      await vm.loginUser('test@test.com', 'password');

      expect(fakeStorage.storedToken,  equals('mock_token_abc123'));
      expect(fakeStorage.storedUserId, equals('test_001'));
    });

    test('attaches auth token to ApiService on success', () async {
      fakeApi.loginShouldSucceed = true;

      await vm.loginUser('test@test.com', 'password');

      expect(fakeApi.authTokenSet, isTrue);
    });

    test('returns false and sets errorMessage on failure', () async {
      fakeApi.loginShouldSucceed = false;

      final result = await vm.loginUser('wrong@test.com', 'wrong');

      expect(result, isFalse);
      expect(vm.isAuthenticated, isFalse);
      expect(vm.currentUser, isNull);
      expect(vm.errorMessage, equals('Sai tài khoản hoặc mật khẩu.'));
      expect(vm.isLoading, isFalse);
    });

    test('forwards email to ApiService (trimming is ApiService responsibility)', () async {
      await vm.loginUser('  Admin@Test.COM  ', 'mypassword');

      // loginUser passes the trimmed value to _api.login.
      expect(fakeApi.capturedEmail, equals('Admin@Test.COM'));
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // registerUser
  // ────────────────────────────────────────────────────────────────────

  group('registerUser', () {
    test('returns true and sets currentUser on success', () async {
      final result = await vm.registerUser(
        fullName: 'New User',
        phone: '+84 123 456 789',
        email: 'new@test.com',
        password: 'SecurePass1!',
      );

      expect(result, isTrue);
      expect(vm.isAuthenticated, isTrue);
      expect(vm.isLoading, isFalse);
    });

    test('returns false with errorMessage when email already exists', () async {
      fakeApi.registerShouldSucceed = false;

      final result = await vm.registerUser(
        fullName: 'Existing',
        phone: '+84 000 000 000',
        email: 'existing@test.com',
        password: 'pass',
      );

      expect(result, isFalse);
      expect(vm.errorMessage, contains('đã được đăng ký'));
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // logout
  // ────────────────────────────────────────────────────────────────────

  group('logout', () {
    setUp(() async {
      // Log in first so there is a session to clear.
      fakeApi.loginShouldSucceed = true;
      await vm.loginUser('test@test.com', 'password');
    });

    test('clears currentUser', () async {
      await vm.logout();
      expect(vm.currentUser, isNull);
      expect(vm.isAuthenticated, isFalse);
    });

    test('clears token from storage', () async {
      await vm.logout();
      expect(fakeStorage.storedToken,  isNull);
      expect(fakeStorage.storedUserId, isNull);
    });

    test('clears auth token from ApiService', () async {
      await vm.logout();
      expect(fakeApi.authTokenCleared, isTrue);
    });

    test('sets isLoading to false after logout', () async {
      await vm.logout();
      expect(vm.isLoading, isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // tryAutoLogin
  // ────────────────────────────────────────────────────────────────────

  group('tryAutoLogin', () {
    test('restores session when valid token exists', () async {
      // Simulate a persisted session.
      await fakeStorage.saveSession(
        token: 'existing_token',
        userId: 'test_001',
      );
      fakeApi.profileShouldSucceed = true;

      await vm.tryAutoLogin();

      expect(vm.isAuthenticated, isTrue);
      expect(vm.isLoading, isFalse);
    });

    test('clears storage when getProfile fails (expired session)', () async {
      await fakeStorage.saveSession(
        token: 'expired_token',
        userId: 'test_001',
      );
      fakeApi.profileShouldSucceed = false;

      await vm.tryAutoLogin();

      expect(vm.isAuthenticated, isFalse);
      expect(fakeStorage.storedToken, isNull);
    });

    test('does nothing when no session is stored', () async {
      await vm.tryAutoLogin();

      expect(vm.isAuthenticated, isFalse);
      expect(vm.isLoading, isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // clearError
  // ────────────────────────────────────────────────────────────────────

  group('clearError', () {
    test('resets errorMessage to null', () async {
      fakeApi.loginShouldSucceed = false;
      await vm.loginUser('x', 'x');
      expect(vm.errorMessage, isNotNull);

      vm.clearError();
      expect(vm.errorMessage, isNull);
    });
  });
}
