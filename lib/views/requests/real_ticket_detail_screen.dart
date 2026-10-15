import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/portal_ticket_models.dart';
import '../../router/app_router.dart';
import '../../services/i_api_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_bar_widget.dart';

class RealTicketDetailScreen extends StatefulWidget {
  const RealTicketDetailScreen({super.key, required this.code});
  final String code;

  @override
  State<RealTicketDetailScreen> createState() => _RealTicketDetailScreenState();
}

class _RealTicketDetailScreenState extends State<RealTicketDetailScreen> {
  PortalTicketDetail? _ticket;
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
      final ticket = await context.read<AuthViewModel>().getPortalTicket(
        widget.code,
      );
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException && error.statusCode == 404
            ? 'Không tìm thấy phiếu tiếp nhận trong tài khoản này.'
            : 'Không tải được chi tiết phiếu tiếp nhận. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.requests);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          const WarrantSafeAppBar(),
          WarrantSafeTitleRow(title: 'Phiếu tiếp nhận', onBackTap: _back),
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
                : _details(_ticket!),
          ),
        ],
      ),
    ),
  );

  Widget _details(PortalTicketDetail ticket) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _card([
          Text(
            ticket.code,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text('Trạng thái phiếu: ${portalTicketStatusLabel(ticket.status)}'),
          if (ticket.stopped)
            const Text('Phiếu đã dừng theo trạng thái trên hệ thống.'),
          Text('Tiếp nhận lúc: ${_dateTime(ticket.receivedAt)}'),
          if (ticket.promisedReturnAt != null)
            Text('Thời gian hẹn trả: ${_dateTime(ticket.promisedReturnAt!)}'),
          if (ticket.handedOverAt != null)
            Text('Bàn giao lúc: ${_dateTime(ticket.handedOverAt!)}'),
        ]),
        const SizedBox(height: 16),
        _card([
          const Text('Thiết bị', style: TextStyle(fontWeight: FontWeight.w700)),
          if (ticket.productName?.isNotEmpty == true) Text(ticket.productName!),
          if (ticket.brandName?.isNotEmpty == true)
            Text('Hãng: ${ticket.brandName}'),
          if (ticket.serialOrImei?.isNotEmpty == true)
            Text('Serial/IMEI: ${ticket.serialOrImei}'),
        ]),
        const SizedBox(height: 16),
        _card([
          const Text(
            'Các bước xử lý',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tiến độ tổng hợp do hệ thống trả về, không phải nhật ký từng công đoạn.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          for (final step in ticket.steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${_stepState(step.state)} · ${step.label}'),
            ),
        ]),
        const SizedBox(height: 16),
        _card([
          const Text(
            'Chi phí theo hệ thống',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Giá trị bảo hành miễn phí: ${_money(ticket.costs.inWarrantyAmount)}',
          ),
          Text(
            'Linh kiện tính phí: ${_money(ticket.costs.outOfWarrantyParts)}',
          ),
          Text('Phí dịch vụ: ${_money(ticket.costs.serviceFee)}'),
          Text('VAT: ${_money(ticket.costs.vat)}'),
          Text('Tổng đã ghi nhận: ${_money(ticket.costs.total)}'),
          Text('Thanh toán: ${_paymentStatus(ticket.costs.paymentStatus)}'),
        ]),
        if (ticket.pendingQuotation case final quote?) ...[
          const SizedBox(height: 16),
          _card([
            const Text(
              'Báo giá chờ khách quyết định',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Mã báo giá: ${quote.code}'),
            if (quote.validUntil != null)
              Text('Hiệu lực đến: ${_date(quote.validUntil!)}'),
            for (final line in quote.lines) ...[
              const SizedBox(height: 8),
              Text(
                '${line.lineNo}. ${line.description ?? 'Hạng mục'} · SL ${line.quantity}',
              ),
              if (line.unitPrice != null)
                Text('Đơn giá: ${_money(line.unitPrice!)}'),
              if (line.laborFee != null)
                Text('Công: ${_money(line.laborFee!)}'),
              if (line.lineTotal != null)
                Text('Thành tiền: ${_money(line.lineTotal!)}'),
            ],
            const Divider(),
            Text('Linh kiện: ${_money(quote.partsTotal)}'),
            Text('Tiền công: ${_money(quote.laborTotal)}'),
            Text('Tổng báo giá: ${_money(quote.grandTotal)}'),
            const SizedBox(height: 8),
            const Text(
              'Chức năng đồng ý/từ chối báo giá Real chưa mở trong ứng dụng.',
            ),
          ]),
        ],
        if (ticket.customerNotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _card([
            const Text(
              'Ghi chú cho khách',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final note in ticket.customerNotes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${_dateTime(note.at)} · ${note.text}'),
              ),
          ]),
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

  String _stepState(String state) => switch (state) {
    'DONE' => 'Hoàn tất',
    'CURRENT' => 'Hiện tại',
    'UPCOMING' => 'Chưa tới',
    _ => state,
  };

  String _paymentStatus(String status) => switch (status) {
    'UNPAID' => 'Chưa ghi nhận thanh toán',
    'PAID' => 'Đã thanh toán',
    'FREE_WARRANTY' => 'Bảo hành miễn phí',
    _ => status,
  };

  String _money(num value) => '${value.toString()} VNĐ';
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
