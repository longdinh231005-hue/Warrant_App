import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/request_card.dart';
import '../../router/app_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/request_viewmodel.dart';
import '../../viewmodels/ticket_viewmodel.dart';
import '../../widgets/real_request_card.dart';
import '../../models/portal_ticket_models.dart';
import '../../widgets/soopi_ui.dart';

class RequestListScreen extends StatelessWidget {
  const RequestListScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mockDataRevision,
    builder: (context, _) => _buildBody(context),
  );

  Widget _buildBody(BuildContext context) {
    final isMock = context.select<AuthViewModel, bool>((vm) => vm.isMock);
    final unreadCount = context.select<AuthViewModel, int?>(
      (vm) => vm.notificationUnreadCount,
    );
    final notificationCountLoading = context.select<AuthViewModel, bool>(
      (vm) => vm.notificationCountLoading,
    );
    final notificationCountError = context.select<AuthViewModel, bool>(
      (vm) => vm.notificationCountError,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            WarrantSafeAppBar(
              unreadCount: isMock ? unreadNotificationCount : unreadCount,
              notificationCountLoading: !isMock && notificationCountLoading,
              notificationCountError: !isMock && notificationCountError,
              onNotificationTap: () => context.go(AppRoutes.notifications),
            ),
            const Divider(height: 1),

            Expanded(
              child: !isMock
                  ? _realContent(context)
                  : (mockRequests.isEmpty
                        ? _buildEmptyState(context)
                        : _buildContent()),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.createRequest),
        tooltip: 'Gửi yêu cầu bảo hành mới',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _realContent(BuildContext context) {
    final requests = context.watch<RequestViewModel>();
    final tickets = context.watch<TicketViewModel>();
    if (!requests.loaded && !requests.loading && requests.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.read<RequestViewModel>().ensureLoaded();
      });
    }
    if (!tickets.loaded && !tickets.loading && tickets.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.read<TicketViewModel>().ensureLoaded();
      });
    }
    return _RealHistory(requests: requests, tickets: tickets);
  }

  Widget _buildContent() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: mockRequests.length,
      itemBuilder: (context, index) {
        final request = mockRequests[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RequestCard(
            request: request,
            onTap: () => context.push('${AppRoutes.requests}/${request.id}'),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: SoopiEmpty(
        icon: Icons.assignment_outlined,
        title: 'Chưa có yêu cầu nào',
        text: 'Bấm dấu + góc dưới để tạo yêu cầu bảo hành/sửa chữa mới.',
      ),
    );
  }
}

/// Lịch sử bảo hành & sửa chữa (Real), cùng bố cục trang "Lịch sử" của web:
/// tiêu đề, bộ lọc theo nhóm trạng thái có đếm số, thẻ phiếu có tiến độ 6 bước,
/// rồi danh sách yêu cầu bảo hành trực tuyến.
class _RealHistory extends StatefulWidget {
  const _RealHistory({required this.requests, required this.tickets});

  final RequestViewModel requests;
  final TicketViewModel tickets;

  @override
  State<_RealHistory> createState() => _RealHistoryState();
}

class _RealHistoryState extends State<_RealHistory> {
  static const _filters = [
    ('ALL', 'Tất cả'),
    ('PROCESSING', 'Đang xử lý'),
    ('WAITING', 'Chờ linh kiện / xác nhận'),
    ('READY', 'Chờ nhận máy'),
    ('COMPLETED', 'Hoàn thành'),
  ];

  String _group = 'ALL';

  @override
  Widget build(BuildContext context) {
    final requests = widget.requests;
    final tickets = widget.tickets;
    final rows = [...tickets.tickets]
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final shown = rows.where((t) => ticketInGroup(_group, t.status)).toList();
    int count(String group) =>
        rows.where((t) => ticketInGroup(group, t.status)).length;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([requests.refresh(), tickets.refresh()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text('Lịch sử bảo hành & sửa chữa', style: AppText.pageTitle),
          const SizedBox(height: 4),
          Text(
            'Theo dõi tiến độ xử lý mọi thiết bị của bạn.',
            style: AppText.cardDesc,
          ),
          const SizedBox(height: 14),

          // ── Phiếu tiếp nhận ───────────────────────────────────────
          if (tickets.loading && !tickets.loaded)
            const Center(child: CircularProgressIndicator())
          else if (tickets.error != null)
            _failure(tickets.error!, tickets.refresh)
          else if (rows.isEmpty)
            const SoopiPanel(
              child: SoopiEmpty(
                icon: Icons.inbox_outlined,
                title: 'Chưa có phiếu bảo hành',
                text: 'Tài khoản chưa có phiếu tiếp nhận nào.',
              ),
            )
          else ...[
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final (key, label) = _filters[index];
                  return _FilterPill(
                    label: '$label (${count(key)})',
                    selected: _group == key,
                    onTap: () => setState(() => _group = key),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (shown.isEmpty)
              const SoopiPanel(
                child: SoopiEmpty(
                  icon: Icons.inbox_outlined,
                  title: 'Không tìm thấy phiếu bảo hành nào',
                  text: 'Không có phiếu nào khớp bộ lọc đang chọn.',
                ),
              )
            else
              for (final ticket in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ticketCard(context, ticket),
                ),
          ],

          // ── Yêu cầu trực tuyến ────────────────────────────────────
          const SizedBox(height: 12),
          Text('Yêu cầu bảo hành trực tuyến', style: AppText.cardTitle),
          const SizedBox(height: 10),
          if (requests.loading && !requests.loaded)
            const Center(child: CircularProgressIndicator())
          else if (requests.error != null)
            _failure(requests.error!, requests.refresh)
          else if (requests.requests.isEmpty)
            Text(
              'Chưa có yêu cầu trực tuyến nào.',
              style: AppText.cardDesc,
            )
          else
            for (final request in requests.requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RealRequestCard(
                  request: request,
                  onTap: () => context.push(
                    '${AppRoutes.requests}/${Uri.encodeComponent(request.code)}',
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _failure(String message, VoidCallback retry) => SoopiAlert(
    tone: StatusTone.danger,
    message: Text(message),
    action: SoopiSecondaryButton(
      compact: true,
      label: 'Thử lại',
      onPressed: retry,
    ),
  );

  /// Thẻ phiếu (ticket-card-box): mã + trạng thái, tên máy + Serial,
  /// tiến độ 6 bước, chân thẻ có nút xem chi tiết.
  Widget _ticketCard(BuildContext context, PortalTicketSummary ticket) {
    void open() => context.push(AppRoutes.realTicket(ticket.code));
    final step = ticket.currentStep;
    final stepText = ticket.stopped
        ? 'Phiếu đã dừng'
        : step >= kCustomerStepLabels.length
        ? 'Đã hoàn tất mọi bước'
        : 'Bước ${step + 1}/${kCustomerStepLabels.length}: '
              '${kCustomerStepLabels[step < 0 ? 0 : step]}';

    return SoopiPanel(
      onTap: open,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Mã phiếu ${ticket.code}', style: AppText.mono),
              StatusBadge(
                label: portalTicketStatusLabel(ticket.status),
                tone: ticketStatusTone(ticket.status),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Text(
            ticket.productName?.isNotEmpty == true
                ? ticket.productName!
                : 'Thiết bị',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.penguinNavy,
            ),
          ),
          if (ticket.serialOrImei?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.sageDivider,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                'Serial/IMEI: ${ticket.serialOrImei}',
                style: AppText.mono.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          MiniSteps(current: ticket.stopped ? -1 : step),
          const SizedBox(height: 8),
          Text(
            stepText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.navyBody,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tiếp nhận lúc ${soopiDateTime(ticket.receivedAt)}',
                  style: AppText.meta,
                ),
              ),
              const SizedBox(width: 8),
              SoopiPrimaryButton(
                compact: true,
                label: 'Xem chi tiết',
                onPressed: open,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút lọc (filter-pill): đang chọn thì nền mint dịu, chữ xanh rừng.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mintSoft : AppColors.paperWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.container),
        side: BorderSide(
          color: selected ? AppColors.forest : AppColors.sageBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.forest : AppColors.sageMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
