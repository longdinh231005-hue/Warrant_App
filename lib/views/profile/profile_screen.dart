import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_bar_widget.dart';
import '../../data/mock_data.dart';

/// WarrantSafe – Tài khoản (Profile & Settings) Screen
///
/// Changes from the previous version:
///   • Avatar initials and name/phone/email now come from [AuthViewModel.currentUser].
///   • A sensible placeholder is shown when a field is absent.
///   • Unavailable features show a tooltip/snackbar explaining they are prototypes.
///   • AppBar uses the shared [WarrantSafeAppBar] widget.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final user = vm.currentUser;
    final isLoading = vm.isLoading;

    final fullName = user?.fullName.trim();
    final phone = user?.phone.trim();
    final email = user?.email.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── App bar ─────────────────────────────────────────────
            WarrantSafeAppBar(
              unreadCount: vm.isMock
                  ? unreadNotificationCount
                  : vm.notificationUnreadCount,
              notificationCountLoading:
                  !vm.isMock && vm.notificationCountLoading,
              notificationCountError: !vm.isMock && vm.notificationCountError,
              onNotificationTap: () => context.go(AppRoutes.notifications),
            ),
            const Divider(height: 1),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    // ── Profile header ──────────────────────────────
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (vm.errorMessage != null &&
                        user?.customerCode == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: [
                            Text(
                              vm.errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => vm.refreshProfile(),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildProfileHeader(
                        fullName: fullName,
                        phone: phone,
                        email: email,
                      ),
                    const SizedBox(height: 20),

                    // ── CÁ NHÂN ────────────────────────────────────
                    _buildSectionLabel('CÁ NHÂN'),
                    _buildGroupCard([
                      _buildMenuTile(
                        icon: Icons.person_outline_rounded,
                        iconBgColor: AppColors.primaryLight,
                        iconColor: AppColors.primaryBlue,
                        title: 'Chỉnh sửa thông tin cá nhân',
                        subtitle: 'Tên, email, địa chỉ',
                        onTap: () =>
                            _showUnavailable(context, 'chỉnh sửa thông tin'),
                      ),
                      _divider(),
                      _buildMenuTile(
                        icon: Icons.phone_outlined,
                        iconBgColor: AppColors.primaryLight,
                        iconColor: AppColors.primaryBlue,
                        title: 'Chi tiết liên hệ',
                        subtitle: phone != null && phone.isNotEmpty
                            ? phone
                            : 'Chưa có số điện thoại',
                        onTap: () =>
                            _showUnavailable(context, 'chi tiết liên hệ'),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // ── BẢO MẬT ────────────────────────────────────
                    _buildSectionLabel('BẢO MẬT'),
                    _buildGroupCard([
                      _buildMenuTile(
                        icon: Icons.lock_outline_rounded,
                        iconBgColor: const Color(0xFFFFF4E5),
                        iconColor: AppColors.warning,
                        title: 'Đổi mật khẩu',
                        subtitle: '(Chưa hỗ trợ trong bản thử nghiệm)',
                        onTap: () => _showUnavailable(context, 'đổi mật khẩu'),
                      ),
                      _divider(),
                      _buildMenuTile(
                        icon: Icons.security_rounded,
                        iconBgColor: const Color(0xFFFFF4E5),
                        iconColor: AppColors.warning,
                        title: 'Xác thực hai yếu tố',
                        subtitle: '(Chưa hỗ trợ trong bản thử nghiệm)',
                        onTap: () =>
                            _showUnavailable(context, 'xác thực hai yếu tố'),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // ── TUỲ CHỈNH ──────────────────────────────────
                    _buildSectionLabel('TUỲ CHỈNH'),
                    _buildGroupCard([
                      _buildMenuTile(
                        icon: Icons.notifications_none_rounded,
                        iconBgColor: AppColors.primaryLight,
                        iconColor: AppColors.primaryBlue,
                        title: 'Cài đặt thông báo',
                        subtitle: 'Chưa hỗ trợ thay đổi cài đặt trong ứng dụng',
                        onTap: () =>
                            _showUnavailable(context, 'cài đặt thông báo'),
                      ),
                      _divider(),
                      _buildMenuTile(
                        icon: Icons.language_rounded,
                        iconBgColor: AppColors.primaryLight,
                        iconColor: AppColors.primaryBlue,
                        title: 'Ngôn ngữ & khu vực',
                        subtitle: 'Tiếng Việt (VN) · UTC+7',
                        onTap: () =>
                            _showUnavailable(context, 'cài đặt ngôn ngữ'),
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── ĐĂNG XUẤT ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.logout,
                          side: const BorderSide(
                            color: AppColors.logout,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'Đăng xuất',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Footer ─────────────────────────────────────
                    Text(
                      'WarrantSafe (Chưa có phiên bản chính thức)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  PROFILE HEADER
  // ──────────────────────────────────────────────────────────────────

  Widget _buildProfileHeader({
    required String? fullName,
    required String? phone,
    required String? email,
  }) {
    final displayName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : 'Khách hàng';
    final initials = _initials(displayName);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 20, bottom: 28),
      child: Column(
        children: [
          // ── Avatar ────────────────────────────────────────────
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.avatarBg,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 14,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Name ─────────────────────────────────────────────
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // ── Phone ────────────────────────────────────────────
          if (phone != null && phone.isNotEmpty)
            Text(
              phone,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),

          // ── Email ─────────────────────────────────────────────
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              email,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Customer badge ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 1.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: AppColors.primaryBlue,
                ),
                SizedBox(width: 6),
                Text(
                  'Khách hàng đã xác minh',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  SECTION HELPERS
  // ──────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing:
          trailing ??
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 0.8, color: AppColors.divider),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  ACTIONS
  // ──────────────────────────────────────────────────────────────────

  void _showUnavailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${_capitalize(feature)}" chưa khả dụng trong bản thử nghiệm này.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc muốn đăng xuất khỏi tài khoản này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.logout),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthViewModel>().logout();
      // GoRouter detects isAuthenticated=false and redirects to /login.
    }
  }

  // ──────────────────────────────────────────────────────────────────
  //  UTILITIES
  // ──────────────────────────────────────────────────────────────────

  /// Extracts up to 2 initials from a full name.
  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    // First letter of first word + first letter of last word.
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
