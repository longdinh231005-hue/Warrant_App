import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/register_screen.dart';
import '../views/profile/profile_screen.dart';
import '../views/splash/splash_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route path constants
// ─────────────────────────────────────────────────────────────────────────────

/// Centralised route name/path constants.
/// Import this anywhere you need to navigate instead of hard-coding strings.
class AppRoutes {
  AppRoutes._();

  static const String splash   = '/';
  static const String login    = '/login';
  static const String register = '/register';
  static const String profile  = '/profile';
}

// ─────────────────────────────────────────────────────────────────────────────
// AppRouter
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [GoRouter] and exposes it as [router].
///
/// Requires an [AuthViewModel] so it can:
///   1. Use it as [GoRouter.refreshListenable] — every `notifyListeners()`
///      call from the ViewModel triggers a redirect re-evaluation.
///   2. Read [AuthViewModel.isLoading] and [AuthViewModel.isAuthenticated]
///      inside the redirect callback.
class AppRouter {
  AppRouter(AuthViewModel authViewModel)
      : router = GoRouter(
          initialLocation: AppRoutes.splash,
          debugLogDiagnostics: false,
          refreshListenable: authViewModel,
          redirect: (BuildContext context, GoRouterState state) =>
              _redirect(authViewModel, state),
          routes: _routes,
        );
  final GoRouter router;

  // ── Redirect logic ───────────────────────────────────────────────────────

  static String? _redirect(AuthViewModel vm, GoRouterState state) {
    final location = state.matchedLocation;
    final isLoading = vm.isLoading;
    final isAuth    = vm.isAuthenticated;

    // ① Still running tryAutoLogin → hold on splash.
    if (isLoading) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final isOnAuthScreen = location == AppRoutes.login ||
        location == AppRoutes.register;

    // ② Not authenticated and trying to access protected route → login.
    if (!isAuth && !isOnAuthScreen) return AppRoutes.login;

    // ③ Authenticated but on auth/splash screen → profile.
    if (isAuth && (isOnAuthScreen || location == AppRoutes.splash)) {
      return AppRoutes.profile;
    }

    // ④ No redirect needed.
    return null;
  }

  // ── Route definitions ────────────────────────────────────────────────────

  static final List<RouteBase> _routes = [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
  ];
}
