import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/portal_lookup_models.dart';
import '../../models/portal_request_models.dart';
import '../../models/portal_ticket_models.dart';
import '../../services/i_api_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Signed-in customers look up only their own YC/TN records by code.
/// Serial/IMEI lookup is staff-only; this screen never calls that endpoint.
class RealLookupScreen extends StatefulWidget {
  const RealLookupScreen({super.key});

  @override
  State<RealLookupScreen> createState() => _RealLookupScreenState();
}

class _RealLookupScreenState extends State<RealLookupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  PortalLookupRecord? _record;
  String? _error;
  bool _canRetry = false;
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _canRetry = false;
      _record = null;
    });
    try {
      final code = _code.text.trim().toUpperCase();
      final auth = context.read<AuthViewModel>();
      final record = code.startsWith('YC-')
          ? PortalLookupRecord.request(await auth.getMyWarrantyRequest(code))
          : PortalLookupRecord.ticket(await auth.getPortalTicket(code));
      if (mounted) setState(() => _record = record);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _canRetry = error.statusCode == null;
        _error = switch (error.statusCode) {
          404 => 'Không tìm thấy yêu cầu/phiếu này trong tài khoản của bạn.',
          429 => 'Bạn đã tra cứu quá nhiều lần. Vui lòng đợi rồi thử lại.',
          null => 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
          _ =>
            'Tra cứu chưa thành công (${error.statusCode}). Vui lòng thử lại.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _canRetry = false;
          _error = 'Không đọc được kết quả tra cứu.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Tra cứu bảo hành'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/devices'),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tra cứu yêu cầu hoặc phiếu tiếp nhận của bạn bằng mã YC/TN.',
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Mã YC hoặc TN'),
                  validator: (value) =>
                      RegExp(
                        r'^(YC|TN)-[A-Z0-9]+(?:-[A-Z0-9]+)*$',
                      ).hasMatch(value?.trim().toUpperCase() ?? '')
                      ? null
                      : 'Nhập đầy đủ mã YC-... hoặc TN-... (phần sau dấu gạch không được trống).',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _lookup,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tra cứu'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            if (_canRetry)
              TextButton.icon(
                onPressed: _loading ? null : _lookup,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
          ],
          if (_record case final record?) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: record.request != null
                      ? _requestFields(record.request!)
                      : _ticketFields(record.ticket!),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  List<Widget> _requestFields(PortalRequestDetail request) => [
    Text(
      'Yêu cầu ${request.code}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    Text('Trạng thái yêu cầu: ${portalRequestStatusLabel(request.status)}'),
    if (request.brandModel != null) Text('Thiết bị: ${request.brandModel}'),
    if (request.serialOrImei != null)
      Text('Serial/IMEI: ${request.serialOrImei}'),
    if (request.ticketCode case final code?) Text('Phiếu liên kết: $code'),
    if (request.ticketCode == null)
      const Text(
        'Chưa có phiếu tiếp nhận; gửi trực tuyến không đồng nghĩa đã nhận máy.',
      ),
  ];

  List<Widget> _ticketFields(PortalTicketDetail ticket) => [
    Text(
      'Phiếu ${ticket.code}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    Text('Trạng thái phiếu: ${portalTicketStatusLabel(ticket.status)}'),
    if (ticket.productName != null) Text('Thiết bị: ${ticket.productName}'),
    if (ticket.serialOrImei != null)
      Text('Serial/IMEI: ${ticket.serialOrImei}'),
    if (ticket.stopped)
      const Text(
        'Phiếu đã dừng xử lý; hiện không có bước sửa chữa đang thực hiện.',
      )
    else
      for (final step in ticket.steps)
        Text(
          '${step.label}: ${step.state == 'DONE'
              ? 'Hoàn tất'
              : step.state == 'CURRENT'
              ? 'Hiện tại'
              : 'Chưa tới'}',
        ),
    if (ticket.pendingQuotation case final quote?)
      Text('Báo giá chờ quyết định: ${quote.code} · ${quote.grandTotal} VNĐ'),
    const SizedBox(height: 8),
    const Text('Tra cứu chỉ hiển thị dữ liệu thuộc tài khoản của bạn.'),
  ];
}
