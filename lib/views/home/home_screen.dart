import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/request_viewmodel.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/request_card.dart';
import '../../widgets/real_request_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

/// The main Trang chủ (Home) screen for the authenticated customer.
///
/// Sections:
///   1. Greeting + subtitle
///   2. Primary CTA — "Gửi yêu cầu bảo hành / sửa chữa"
///   3. "Cần bạn xử lý" — action-required cards (up to 2)
///   4. "Yêu cầu của tôi" — recent requests list (up to 3)
///   5. Empty state when no requests exist
///
/// Mock cards come from mock_data.dart; Real request summaries come from the
/// customer portal API through RequestViewModel.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mockDataRevision,
    builder: (context, _) => _buildBody(context),
  );

  Widget _buildBody(BuildContext context) {
    final user = context.select<AuthViewModel, dynamic>((vm) => vm.currentUser);

    // Extract first name (before first space) for the greeting.
    final firstName = _firstName(user?.fullName);

    final isMock = context.select<AuthViewModel, bool>((vm) => vm.isMock);

    final actions = isMock ? actionRequiredRequests : <MockRequest>[];
    final recent = isMock ? mockRequests.take(3).toList() : <MockRequest>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── App bar ─────────────────────────────────────────────
            WarrantSafeAppBar(
              unreadCount: isMock ? unreadNotificationCount : 0,
              onNotificationTap: () => context.go(AppRoutes.notifications),
            ),
            const Divider(height: 1),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Greeting ─────────────────────────────────────
                    _buildGreeting(firstName),
                    const SizedBox(height: 20),

                    // ── Primary CTA ──────────────────────────────────
                    _buildPrimaryCta(context),
                    const SizedBox(height: 24),

                    // ── Action Required section ───────────────────────
                    if (actions.isNotEmpty) ...[
                      _buildActionRequired(context, actions),
                      const SizedBox(height: 24),
                    ],

                    // ── Recent requests ───────────────────────────────
                    SectionHeader(
                      title: 'Yêu cầu của tôi',
                      onViewAll: () => context.go(AppRoutes.requests),
                    ),
                    const SizedBox(height: 12),

                    if (!isMock)
                      _buildRealRecent(context)
                    else if (recent.isEmpty)
                      _buildEmptyState()
                    else
                      ...recent.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RequestCard(
                            request: r,
                            onTap: () =>
                                context.push('${AppRoutes.requests}/${r.id}'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealRecent(BuildContext context) {
    final requests = context.watch<RequestViewModel>();
    if (!requests.loaded && !requests.loading && requests.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.read<RequestViewModel>().ensureLoaded();
      });
    }
    if (requests.loading && !requests.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (requests.error != null) {
      return TextButton(
        onPressed: requests.refresh,
        child: const Text('Không tải được yêu cầu. Chạm để thử lại.'),
      );
    }
    if (requests.requests.isEmpty) return _buildEmptyState();
    return Column(
      children: requests.requests
          .take(3)
          .map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RealRequestCard(
                request: request,
                onTap: () => context.push(
                  '${AppRoutes.requests}/${Uri.encodeComponent(request.code)}',
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Greeting ─────────────────────────────────────────────────────

  Widget _buildGreeting(String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xin chào, $firstName',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        const Text(
          'Bảo hành và sửa chữa',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // ── Primary CTA ──────────────────────────────────────────────────

  Widget _buildPrimaryCta(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => context.push('${AppRoutes.requests}/create'),
      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
      label: const Text('Gửi yêu cầu bảo hành / sửa chữa'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Action Required ───────────────────────────────────────────────

  Widget _buildActionRequired(BuildContext context, List<MockRequest> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cần bạn xử lý',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...actions
            .take(2)
            .map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildActionCard(context, r),
              ),
            ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, MockRequest r) {
    final isPickup = r.ticketStatus == TicketStatus.completed;

    if (isPickup) {
      return ActionCard(
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.success,
        backgroundColor: const Color(0xFFF0FDF4),
        borderColor: const Color(0xFFBBF7D0),
        title: 'Thiết bị sẵn sàng để nhận',
        subtitle: '${r.deviceName} · Mã phiếu ${r.ticketId ?? r.id}',
        buttonLabel: 'Xem cách nhận máy',
        buttonBackgroundColor: AppColors.white,
        buttonTextColor: AppColors.textPrimary,
        buttonIsOutlined: true,
        onButtonTap: () => context.push('${AppRoutes.requests}/${r.id}/ticket'),
      );
    }

    // Quote confirmation card
    final formattedTotal = r.quoteTotal != null
        ? _formatCurrency(r.quoteTotal!)
        : 'Xem chi tiết';

    return ActionCard(
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFB45309),
      backgroundColor: const Color(0xFFFFFBEB),
      borderColor: const Color(0xFFFDE68A),
      title: 'Chờ xác nhận báo giá',
      subtitle:
          '${r.deviceName} · ${r.ticketId ?? r.id}. Tổng chi phí dự kiến $formattedTotal.',
      buttonLabel: 'Xem báo giá',
      onButtonTap: () =>
          context.push('${AppRoutes.requests}/${r.id}/ticket/quote'),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cardGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 36,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có yêu cầu nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gửi yêu cầu bảo hành hoặc sửa chữa\nđể bắt đầu theo dõi tình trạng thiết bị.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _firstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'bạn';
    final parts = fullName.trim().split(' ');
    return parts.last; // Vietnamese names: last token is the given name
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final formatted = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) formatted.write('.');
      formatted.write(parts[i]);
    }
    return '$formatted VNĐ';
  }
}
