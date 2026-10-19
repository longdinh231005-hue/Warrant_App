import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/portal_ticket_models.dart';
import '../../router/app_router.dart';
import '../../services/i_api_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/request_viewmodel.dart';
import '../../viewmodels/ticket_viewmodel.dart';
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
  bool _deciding = false;
  bool _decisionUncertain = false;
  String? _decisionMessage;

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
        _decisionUncertain = false;
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

  Future<void> _decide(String decision) async {
    if (_deciding || _decisionUncertain || _ticket?.pendingQuotation == null) {
      return;
    }
    final quote = _ticket!.pendingQuotation!;
    var reasonText = '';
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: Text(
              decision == 'ACCEPT' ? 'Đồng ý báo giá?' : 'Từ chối báo giá?',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mã ${quote.code} · Tổng ${_money(quote.grandTotal)}'),
                const SizedBox(height: 8),
                const Text(
                  'Quyết định sẽ được ghi nhận trên hệ thống. Trạng thái tiếp theo do máy chủ trả về.',
                ),
                if (decision == 'DECLINE') ...[
                  const SizedBox(height: 12),
                  TextField(
                    maxLength: 500,
                    onChanged: (value) => update(() => reasonText = value),
                    decoration: const InputDecoration(
                      labelText: 'Lý do từ chối *',
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: decision == 'DECLINE' && reasonText.trim().isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(reasonText.trim()),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || reason == null) return;
      setState(() {
        _deciding = true;
        _decisionMessage = null;
      });
      try {
        final updated = await context
            .read<AuthViewModel>()
            .decidePortalQuotation(
              widget.code,
              decision,
              reason: decision == 'DECLINE' ? reason : null,
            );
        if (!mounted) return;
        setState(() {
          _ticket = updated;
          _decisionMessage =
              'Máy chủ đã ghi nhận quyết định. Trạng thái phiếu: ${portalTicketStatusLabel(updated.status)}.';
        });
        // Refresh the list state from GETs; never infer a status from the tap.
        Provider.of<TicketViewModel?>(context, listen: false)?.refresh();
        Provider.of<RequestViewModel?>(context, listen: false)?.refresh();
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _decisionUncertain =
              error.statusCode == null || error.statusCode == 409;
          _decisionMessage = error.statusCode == 409
              ? 'Báo giá đã có quyết định hoặc không còn chờ xác nhận. Tải lại phiếu trước khi thao tác tiếp.'
              : error.statusCode == null
              ? 'Chưa rõ máy chủ đã ghi nhận hay chưa. Tải lại phiếu để kiểm tra trước khi thao tác tiếp.'
              : 'Chưa ghi nhận quyết định (${error.statusCode}): ${error.message}';
        });
      }
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

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
        if (_decisionMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _decisionMessage!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_decisionUncertain)
            OutlinedButton(
              onPressed: _load,
              child: const Text('Tải lại phiếu'),
            ),
        ],
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
          if (ticket.stopped)
            const Text(
              'Phiếu đã dừng xử lý; hiện không có bước sửa chữa đang thực hiện.',
            )
          else
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
            Text(
              'VAT (${quote.vatRate}%): ${_money(quote.grandTotal - quote.partsTotal - quote.laborTotal)}',
            ),
            Text('Tổng báo giá: ${_money(quote.grandTotal)}'),
            const SizedBox(height: 8),
            const Text(
              'Báo giá đã duyệt nội bộ và đang chờ quyết định của khách hàng.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deciding || _decisionUncertain
                        ? null
                        : () => _decide('DECLINE'),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _deciding || _decisionUncertain
                        ? null
                        : () => _decide('ACCEPT'),
                    child: _deciding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đồng ý'),
                  ),
                ),
              ],
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
