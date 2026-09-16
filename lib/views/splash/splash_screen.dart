import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Displayed while [AuthViewModel.tryAutoLogin] is in progress.
/// GoRouter shows this route at `/` and redirects away once loading is done.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),

            // Brand name
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Roboto',
                ),
                children: [
                  TextSpan(text: 'Warrant'),
                  TextSpan(
                    text: 'Safe',
                    style: TextStyle(color: AppColors.primaryBlue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Electronic Warranty Center',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 48),

            // Loading indicator
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
