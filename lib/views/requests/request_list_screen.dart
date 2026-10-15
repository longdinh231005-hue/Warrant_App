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

class RequestListScreen extends StatelessWidget {
  const RequestListScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: mockDataRevision,
    builder: (context, _) => _buildBody(context),
  );

  Widget _buildBody(BuildContext context) {
    final isMock = context.select<AuthViewModel, bool>((vm) => vm.isMock);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            WarrantSafeAppBar(
              unreadCount: isMock ? unreadNotificationCount : 0,
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
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.white,
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
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([requests.refresh(), tickets.refresh()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        children: [
          const Text(
            'Yêu cầu trực tuyến',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (requests.loading && !requests.loaded)
            const Center(child: CircularProgressIndicator())
          else if (requests.error != null)
            _realFailure(requests.error!, requests.refresh)
          else if (requests.requests.isEmpty)
            const Text('Chưa có yêu cầu trực tuyến nào.')
          else
            for (final request in requests.requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RealRequestCard(
                  request: request,
                  onTap: () => context.push(
                    '${AppRoutes.requests}/${Uri.encodeComponent(request.code)}',
                  ),
                ),
              ),
          const SizedBox(height: 20),
          const Text(
            'Phiếu tiếp nhận của tôi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Phiếu tiếp nhận thuộc những lần trung tâm đã nhận thiết bị; mã phiếu không tự suy ra từ mã yêu cầu.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (tickets.loading && !tickets.loaded)
            const Center(child: CircularProgressIndicator())
          else if (tickets.error != null)
            _realFailure(tickets.error!, tickets.refresh)
          else if (tickets.tickets.isEmpty)
            const Text('Tài khoản chưa có phiếu tiếp nhận nào.')
          else
            for (final ticket in tickets.tickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ticketCard(context, ticket),
              ),
        ],
      ),
    );
  }

  Widget _realFailure(String message, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: retry, child: const Text('Thử lại')),
    ],
  );

  Widget _ticketCard(BuildContext context, PortalTicketSummary ticket) =>
      InkWell(
        onTap: () => context.push(AppRoutes.realTicket(ticket.code)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket.productName?.isNotEmpty == true
                    ? ticket.productName!
                    : 'Thiết bị',
              ),
              Text('Mã phiếu ${ticket.code}'),
              if (ticket.serialOrImei?.isNotEmpty == true)
                Text('Serial/IMEI: ${ticket.serialOrImei}'),
              Text(portalTicketStatusLabel(ticket.status)),
            ],
          ),
        ),
      );

  Widget _buildContent() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cardGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.assignment_outlined,
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
            'Bấm dấu + góc dưới để tạo yêu cầu bảo hành/sửa chữa mới.',
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
}
