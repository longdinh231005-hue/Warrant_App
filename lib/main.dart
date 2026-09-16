import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const WarrantSafeApp());
}

class WarrantSafeApp extends StatefulWidget {
  const WarrantSafeApp({super.key});

  @override
  State<WarrantSafeApp> createState() => _WarrantSafeAppState();
}

class _WarrantSafeAppState extends State<WarrantSafeApp> {
  // Create ViewModel + Router once at the top level.
  // AppRouter needs the ViewModel as its refreshListenable, so both must be
  // created before build() — StatefulWidget initState is the right place.
  late final AuthViewModel _authViewModel;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel();
    _appRouter     = AppRouter(_authViewModel);
    // Kick off the auto-login check. GoRouter will react via
    // refreshListenable and redirect to /login or /profile once done.
    _authViewModel.tryAutoLogin();
  }

  @override
  void dispose() {
    _authViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Expose the ViewModel to every screen via context.read / context.watch.
        ChangeNotifierProvider<AuthViewModel>.value(value: _authViewModel),
      ],
      child: MaterialApp.router(
        title: 'WarrantSafe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _appRouter.router,
      ),
    );
  }
}
