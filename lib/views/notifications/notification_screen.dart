import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../router/app_router.dart';
import '../../widgets/app_bar_widget.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'real_notification_content.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    final isMock = context.select<AuthViewModel, bool>((vm) => vm.isMock);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WarrantSafeAppBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.home),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Thông báo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (isMock && mockNotifications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Text(
                      '${mockNotifications.where((n) => !n.isRead).length} chưa đọc',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          for (int i = 0; i < mockNotifications.length; i++) {
                            mockNotifications[i] = MockNotification(
                              id: mockNotifications[i].id,
                              title: mockNotifications[i].title,
                              body: mockNotifications[i].body,
                              isRead: true,
                              createdAt: mockNotifications[i].createdAt,
                              relatedRequestId:
                                  mockNotifications[i].relatedRequestId,
                            );
                          }
                        });
                        notifyMockDataChanged();
                      },
                      child: const Text(
                        'Đánh dấu đã đọc',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          mockNotifications.clear();
                        });
                        notifyMockDataChanged();
                      },
                      child: const Text(
                        'Xóa tất cả',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: !isMock
                  ? const RealNotificationContent()
                  : (mockNotifications.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: mockNotifications.length,
                            itemBuilder: (context, index) {
                              final notif = mockNotifications[index];
                              return _buildNotificationItem(notif, index);
                            },
                          )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.cardGrey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 36,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không có thông báo mới',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Các thông báo về tiến trình sửa chữa sẽ xuất hiện ở đây.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(MockNotification notif, int index) {
    return InkWell(
      onTap: () {
        setState(() {
          mockNotifications[index] = MockNotification(
            id: notif.id,
            title: notif.title,
            body: notif.body,
            isRead: true,
            createdAt: notif.createdAt,
            relatedRequestId: notif.relatedRequestId,
          );
        });
        notifyMockDataChanged();

        if (notif.relatedRequestId != null) {
          // If the title contains "Báo giá", try to navigate to quote
          if (notif.title.toLowerCase().contains('báo giá')) {
            context.push(
              '${AppRoutes.requests}/${notif.relatedRequestId}/ticket/quote',
            );
          } else {
            // Otherwise to ticket/request
            final req = mockRequests
                .where((r) => r.id == notif.relatedRequestId)
                .firstOrNull;
            if (req != null && req.ticketId != null) {
              context.push(
                '${AppRoutes.requests}/${notif.relatedRequestId}/ticket',
              );
            } else {
              context.push('${AppRoutes.requests}/${notif.relatedRequestId}');
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isRead
              ? AppColors.white
              : AppColors.primaryLight.withValues(alpha: 0.3),
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: notif.isRead
                    ? AppColors.cardGrey
                    : AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                notif.title.toLowerCase().contains('báo giá')
                    ? Icons.request_quote_rounded
                    : Icons.info_rounded,
                color: notif.isRead
                    ? AppColors.textHint
                    : AppColors.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notif.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: notif.isRead
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTimeAgo(notif.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }
}
