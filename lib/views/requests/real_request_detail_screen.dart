import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/portal_request_models.dart';
import '../../router/app_router.dart';
import '../../services/i_api_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_bar_widget.dart';

class RealRequestDetailScreen extends StatefulWidget {
  const RealRequestDetailScreen({super.key, required this.code});
  final String code;

  @override
  State<RealRequestDetailScreen> createState() =>
      _RealRequestDetailScreenState();
}

class _RealRequestDetailScreenState extends State<RealRequestDetailScreen> {
  PortalRequestDetail? _request;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await context.read<AuthViewModel>().getMyWarrantyRequest(
        widget.code,
      );
      if (mounted) {
        setState(() {
          _request = request;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException && error.statusCode == 404
              ? 'Không tìm thấy yêu cầu trong tài khoản này.'
              : error is ApiException
              ? error.message
              : 'Không tải được chi tiết yêu cầu.';
          _loading = false;
        });
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.requests);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          const WarrantSafeAppBar(),
          WarrantSafeTitleRow(title: 'Chi tiết yêu cầu', onBackTap: _back),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _details(_request!),
          ),
        ],
      ),
    ),
  );

  Widget _details(PortalRequestDetail request) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _card([
          Text(
            request.code,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            portalRequestStatusLabel(request.status),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (request.createdAt != null) ...[
            const SizedBox(height: 8),
            Text('Gửi lúc: ${_dateTime(request.createdAt!)}'),
          ],
          if (request.status == 'PENDING_INTAKE') ...[
            const SizedBox(height: 10),
            const Text(
              'Yêu cầu đã được ghi nhận trực tuyến. Trung tâm chưa xác nhận đã nhận thiết bị.',
            ),
          ],
        ]),
        const SizedBox(height: 16),
        _card([
          _row('Thiết bị', request.brandModel),
          _row(request.identifierType ?? 'Serial/IMEI', request.serialOrImei),
          _row('Mã nhóm thiết bị', request.categoryCode),
          _row('Mã loại thiết bị', request.deviceTypeCode),
          _row('Mã trạm mong muốn', request.preferredStation),
          _row(
            'Thời gian mong muốn mang máy tới (chưa xác nhận)',
            _preferredArrival(request),
          ),
        ]),
        const SizedBox(height: 16),
        _card([
          const Text(
            'Mô tả lỗi',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(request.symptom ?? 'Không có nội dung'),
        ]),
        if (request.ticketCode?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          _card([
            _row('Mã phiếu tiếp nhận', request.ticketCode),
            OutlinedButton(
              onPressed: () =>
                  context.push(AppRoutes.realTicket(request.ticketCode!)),
              child: const Text('Xem tiến độ phiếu'),
            ),
          ]),
        ] else if (request.status == 'PENDING_INTAKE') ...[
          const SizedBox(height: 16),
          _card([
            const Text(
              'Yêu cầu này chưa có phiếu tiếp nhận. Theo dõi mã yêu cầu cho đến khi trung tâm xử lý.',
            ),
          ]),
        ],
        if (request.cancelReason?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          _card([_row('Lý do hủy', request.cancelReason)]),
        ],
      ],
    ),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _row(String label, String? value) => value == null || value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('$label: $value'),
        );

  String? _preferredArrival(PortalRequestDetail request) {
    final from = request.preferredFrom;
    if (from == null) return null;
    final to = request.preferredTo;
    return to == null
        ? _dateTime(from)
        : '${_dateTime(from)} – ${_dateTime(to)}';
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
