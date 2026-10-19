import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  final _apiUrlEditorKey = GlobalKey<_ApiUrlEditorState>();
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
    if (!vm.isMock && kDebugMode) {
      final editor = _apiUrlEditorKey.currentState;
      if (editor != null && !await editor.apply(showSuccess: false)) return;
    }
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
    final hasSessionPendingRetry = context.select<AuthViewModel, bool>(
      (vm) => vm.hasSessionPendingRetry,
    );
    final errorMessage = context.select<AuthViewModel, String?>(
      (vm) => vm.errorMessage,
    );
    final isMock = context.select<AuthViewModel, bool>((vm) => vm.isMock);

    if (hasSessionPendingRetry) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 64,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 24),
                Text(
                  errorMessage ?? 'Lỗi kết nối',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => context.read<AuthViewModel>().tryAutoLogin(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'THỬ LẠI',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final vm = context.read<AuthViewModel>();
                          await vm.logout();
                          if (!context.mounted) return;
                          // Clear the error and show login form by triggering a state refresh
                          vm.tryAutoLogin(); // This will clear session internally because we logged out
                        },
                  child: const Text(
                    'Đăng nhập tài khoản khác',
                    style: TextStyle(color: AppColors.primaryBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                  'Đăng nhập',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đăng nhập để quản lý bảo hành của bạn.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                if (isMock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Chế độ Mock: chỉ dùng tài khoản mẫu bên dưới. Không kết nối API hoặc cơ sở dữ liệu.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (errorMessage != null && !hasSessionPendingRetry) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // ── Email / Phone field ─────────────────────────────
                CustomTextField(
                  label: 'Số điện thoại hoặc email *',
                  hintText: 'minhanh@example.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập tên đăng nhập hoặc email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                // ── Password field ──────────────────────────────────
                CustomTextField(
                  label: 'Mật khẩu *',
                  hintText: 'Nhập mật khẩu',
                  obscureText: _obscurePassword,
                  controller: _passwordCtrl,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
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
                      : const Text('Đăng nhập'),
                ),
                const SizedBox(height: 24),

                // ── API Configuration ───────────────────────────────
                _buildApiConfig(context),
                const SizedBox(height: 16),

                // ── Hint for demo / testing ─────────────────────────
                if (isMock) ...[
                  _buildDemoHint(),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => context.push(AppRoutes.register),
                    child: const Text('Tạo tài khoản Mock'),
                  ),
                ],
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
          'Trung tâm Bảo hành Điện tử',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  /// Small card showing demo credentials – visible during development only.
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
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.primaryBlue,
              ),
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
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildApiConfig(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chế độ Mock (Giao diện)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Switch(
                value: vm.isMock,
                onChanged: (val) =>
                    context.read<AuthViewModel>().toggleMockMode(val),
                activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
                activeThumbImage: null,
              ),
            ],
          ),
          if (!vm.isMock) ...[
            const SizedBox(height: 8),
            if (kDebugMode)
              _ApiUrlEditor(key: _apiUrlEditorKey, initialUrl: vm.baseUrl)
            else
              TextFormField(
                initialValue: vm.baseUrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL (Chỉ xem)',
                  isDense: true,
                ),
                enabled: false,
              ),
          ],
        ],
      ),
    );
  }
}

class _ApiUrlEditor extends StatefulWidget {
  final String initialUrl;
  const _ApiUrlEditor({super.key, required this.initialUrl});

  @override
  State<_ApiUrlEditor> createState() => _ApiUrlEditorState();
}

class _ApiUrlEditorState extends State<_ApiUrlEditor> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialUrl);
  }

  @override
  void didUpdateWidget(_ApiUrlEditor old) {
    super.didUpdateWidget(old);
    if (old.initialUrl != widget.initialUrl &&
        _ctrl.text != widget.initialUrl) {
      _ctrl.text = widget.initialUrl;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<bool> apply({bool showSuccess = true}) async {
    try {
      await context.read<AuthViewModel>().setBaseUrl(_ctrl.text.trim());
      if (showSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật Base URL'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              isDense: true,
            ),
            onFieldSubmitted: (_) => apply(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Áp dụng Base URL',
          icon: const Icon(
            Icons.check_circle_outline,
            color: AppColors.primaryBlue,
          ),
          onPressed: apply,
        ),
      ],
    );
  }
}
