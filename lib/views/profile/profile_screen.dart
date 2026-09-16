import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// WarrantSafe – Profile & Settings Screen
///
/// Static UI matching the design mockup:
///   • Header: circular avatar, name, phone, email, verified badge
///   • PERSONAL group: Edit Personal Info, Contact Details
///   • SECURITY group: Change Password, Two‑Factor Authentication
///   • PREFERENCES group: Notification Settings (switch), Language & Region
///   • Red LOG OUT button at the bottom
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom App Bar ────────────────────────────────────
            _buildAppBar(),

            // ── Scrollable content ───────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Profile header ─────────────────────────────
                    _buildProfileHeader(),
                    const SizedBox(height: 24),

                    // ── PERSONAL ───────────────────────────────────
                    _buildSectionLabel('CÁ NHÂN'),
                    _buildGroupCard([
                      _buildMenuTile(
                        icon: Icons.person_outline_rounded,
                        iconBgColor: AppColors.primaryLight,
                        iconColor: AppColors.primaryBlue,
                        title: 'Chỉnh sửa Thông tin Cá nhân',
                        subtitle: 'Tên, email, địa chỉ',
                      ),
                      _divider(),
                      _buildMenuTile(
                        icon: Icons.phone_outlined,
                        iconBgColor: AppColors.primaryLight,
                        iconColor: AppColors.primaryBlue,
                        title: 'Chi tiết Liên hệ',
                        subtitle: '+84 912 345 678 · Đã xác minh',
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // ── SECURITY ───────────────────────────────────
                    _buildSectionLabel('BẢO MẬT'),
                    _buildGroupCard([
                      _buildMenuTile(
                        icon: Icons.lock_outline_rounded,
                        iconBgColor: const Color(0xFFFFF4E5),
                        iconColor: AppColors.warning,
                        title: 'Đổi Mật khẩu',
                        subtitle: 'Đổi lần cuối 3 tháng trước',
                      ),
                      _divider(),
                      _buildMenuTile(
                        icon: Icons.security_rounded,
                        iconBgColor: const Color(0xFFFFF4E5),
                        iconColor: AppColors.warning,
                        title: 'Xác thực Hai yếu tố',
                        subtitle: 'Thêm một lớp bảo mật bổ sung',
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // ── PREFERENCES ────────────────────────────────
                    _buildSectionLabel('TUỲ CHỈNH'),
                    _buildGroupCard([
                      _buildMenuTile(
                        icon: Icons.notifications_none_rounded,
                        iconBgColor: const Color(0xFFE8F4FD),
                        iconColor: AppColors.primaryBlue,
                        title: 'Cài đặt Thông báo',
                        subtitle: 'Cập nhật sửa chữa, cảnh báo bảo hành',
                        trailing: Switch(
                          value: _notificationsEnabled,
                          activeTrackColor: AppColors.primaryBlue,
                          onChanged: (v) =>
                              setState(() => _notificationsEnabled = v),
                        ),
                      ),
                      _divider(),
                      _buildMenuTile(
                        icon: Icons.language_rounded,
                        iconBgColor: const Color(0xFFE8F4FD),
                        iconColor: AppColors.primaryBlue,
                        title: 'Ngôn ngữ & Khu vực',
                        subtitle: 'Tiếng Việt (VN) · UTC+7',
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── LOG OUT ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final vm = context.read<AuthViewModel>();
                          await vm.logout();
                          // GoRouter detects isAuthenticated=false
                          // and redirects to /login automatically.
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.logout,
                          side: const BorderSide(
                            color: AppColors.logout,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'ĐĂNG XUẤT',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Footer ────────────────────────────────────
                    Text(
                      'WARRANTSAFE V2.4.1 — © 2026 TẤT CẢ QUYỀN ĐƯỢC BẢO LƯU',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppColors.textHint.withValues(alpha: 0.6),
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
  //  APP BAR
  // ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Logo icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 17,
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
          const Spacer(),
          // Notification bell
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  PROFILE HEADER
  // ──────────────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.avatarBg,
                child: const Text(
                  'AM',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
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
          const SizedBox(height: 14),

          // Name
          const Text(
            'Alex Morgan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Phone
          const Text(
            '+84 912 345 678',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),

          // Email
          const Text(
            'alex.morgan@gmail.com',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Verified badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 1.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 15,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 6),
                const Text(
                  'KHÁCH HÀNG ĐÃ XÁC MINH · THÀNH VIÊN 3 NĂM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
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
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 10),
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
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
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
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textHint,
          ),
      onTap: () {},
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(
        height: 1,
        thickness: 0.8,
        color: AppColors.divider,
      ),
    );
  }
}
