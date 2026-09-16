import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/custom_text_field.dart';

/// WarrantSafe – Login Screen (connected to AuthViewModel)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Form ──────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AuthViewModel>();
    await vm.loginUser(_emailCtrl.text.trim(), _passwordCtrl.text);

    // GoRouter's refreshListenable fires when isAuthenticated changes.
    // If login succeeded, the router redirects to /profile automatically.
    // We only need to handle the error case here.
    if (mounted && vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      vm.clearError();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch only isLoading to rebuild the button spinner efficiently.
    final isLoading = context.select<AuthViewModel, bool>((vm) => vm.isLoading);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // ── Logo & Brand ────────────────────────────────────
                _buildLogo(),
                const SizedBox(height: 40),

                // ── Welcome text ────────────────────────────────────
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to manage your warranties',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),

                // ── Email / Phone field ─────────────────────────────
                CustomTextField(
                  label: 'Phone Number or Email',
                  hintText: 'alex.morgan@email.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập email hoặc số điện thoại';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                // ── Password field ──────────────────────────────────
                CustomTextField(
                  label: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  controller: _passwordCtrl,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Forgot Password ─────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'FORGOT PASSWORD?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── LOGIN button ────────────────────────────────────
                ElevatedButton(
                  onPressed: isLoading ? null : _onLogin,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('LOGIN'),
                ),
                const SizedBox(height: 28),

                // ── OR Divider ──────────────────────────────────────
                _buildOrDivider(),
                const SizedBox(height: 28),

                // ── Continue with Google ────────────────────────────
                OutlinedButton.icon(
                  onPressed: isLoading ? null : () {},
                  icon: Image.network(
                    'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                    height: 20,
                    width: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 24,
                      color: AppColors.google,
                    ),
                  ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Sign Up link ────────────────────────────────────────────
                // Wrap handles text overflow on narrow screens gracefully.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () => context.push(AppRoutes.register),
                      child: const Text(
                        'SIGN UP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Hint for demo / testing ─────────────────────────
                _buildDemoHint(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 22,
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
        const SizedBox(height: 4),
        const Text(
          'Electronic Warranty Center',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
              letterSpacing: 1,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  /// Small card showing mock credentials – visible during development only.
  Widget _buildDemoHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.primaryBlue),
              SizedBox(width: 6),
              // Flexible prevents overflow when container is narrow.
              Flexible(
                child: Text(
                  'Tài khoản thử nghiệm (Mock Data)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _hintRow('Admin', 'admin@gmail.com', '123456'),
          const SizedBox(height: 2),
          _hintRow('User', 'user@gmail.com', 'password123'),
        ],
      ),
    );
  }

  Widget _hintRow(String role, String email, String pass) {
    return GestureDetector(
      onTap: () {
        // Tapping the hint auto-fills the form for quick testing.
        setState(() {
          _emailCtrl.text = email;
          _passwordCtrl.text = pass;
        });
      },
      child: Text(
        '[$role] $email / $pass  (tap to fill)',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
