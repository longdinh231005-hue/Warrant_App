import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    backgroundColor: AppColors.milkCream,
    appBar: AppBar(
      title: Text(
        'Tra cứu bảo hành',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/devices'),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.paperWhite,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.sageBorder, width: 1),
              boxShadow: AppShadows.card,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tra cứu tiến độ xử lý',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.penguinNavy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nhập mã yêu cầu (YC-...) hoặc mã phiếu tiếp nhận (TN-...) của bạn.',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppColors.sageMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.penguinNavy,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Mã YC hoặc TN *',
                      hintText: 'Ví dụ: YC-2026-1023-00001',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(Icons.search_rounded, color: AppColors.forest, size: 20),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    validator: (value) =>
                        RegExp(
                          r'^(YC|TN)-[A-Z0-9]+(?:-[A-Z0-9]+)*$',
                        ).hasMatch(value?.trim().toUpperCase() ?? '')
                        ? null
                        : 'Nhập đầy đủ mã YC-... hoặc TN-... (không được để trống).',
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _lookup,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Tra cứu'),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.expiredTint,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: AppColors.peach),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.expiredWine, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(
                        color: AppColors.expiredWineDeep,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_canRetry)
                    TextButton(
                      onPressed: _loading ? null : _lookup,
                      child: const Text('Thử lại'),
                    ),
                ],
              ),
            ),
          ],
          if (_record case final record?) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: AppColors.paperWhite,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.sageBorder, width: 1),
                boxShadow: AppShadows.smoothCard,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: record.request != null
                    ? _requestFields(record.request!)
                    : _ticketFields(record.ticket!),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  List<Widget> _requestFields(PortalRequestDetail request) => [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Yêu cầu ${request.code}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.penguinNavy,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.honeyTint,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.honeyBorder),
          ),
          child: Text(
            portalRequestStatusLabel(request.status),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.honeyText,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    const Divider(),
    const SizedBox(height: 12),
    _kvRow('Mã yêu cầu', request.code, isMono: true),
    if (request.brandModel != null) _kvRow('Thiết bị', request.brandModel!),
    if (request.serialOrImei != null) _kvRow('Serial / IMEI', request.serialOrImei!, isMono: true),
    if (request.ticketCode != null) _kvRow('Phiếu tiếp nhận', request.ticketCode!, isMono: true),
    if (request.ticketCode == null)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.mintWash,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Chưa có phiếu tiếp nhận; gửi trực tuyến không đồng nghĩa đã nhận máy.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.forestDeep),
          ),
        ),
      ),
  ];

  List<Widget> _ticketFields(PortalTicketDetail ticket) => [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Phiếu ${ticket.code}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.penguinNavy,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.mintBorder),
          ),
          child: Text(
            portalTicketStatusLabel(ticket.status),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    const Divider(),
    const SizedBox(height: 12),
    _kvRow('Mã phiếu', ticket.code, isMono: true),
    if (ticket.productName != null) _kvRow('Thiết bị', ticket.productName!),
    if (ticket.serialOrImei != null) _kvRow('Serial / IMEI', ticket.serialOrImei!, isMono: true),
    if (ticket.stopped)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.honeyTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Phiếu đã dừng xử lý; hiện không có bước sửa chữa đang thực hiện.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.honeyText),
          ),
        ),
      )
    else
      for (final step in ticket.steps)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(step.label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.sageMuted)),
              Text(
                step.state == 'DONE'
                    ? '✓ Hoàn tất'
                    : step.state == 'CURRENT'
                    ? '● Đang thực hiện'
                    : '○ Chưa tới',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: step.state == 'DONE'
                      ? AppColors.forest
                      : step.state == 'CURRENT'
                      ? AppColors.honeyText
                      : AppColors.sageMuted,
                ),
              ),
            ],
          ),
        ),
    if (ticket.pendingQuotation case final quote?) ...[
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.honeyTint,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.honeyBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Báo giá: ${quote.code}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.honeyText,
              ),
            ),
            Text(
              '${quote.grandTotal} VNĐ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.expiredWine,
              ),
            ),
          ],
        ),
      ),
    ],
  ];

  Widget _kvRow(String label, String value, {bool isMono = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.sageMuted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: isMono
                ? GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.penguinNavy,
                  )
                : GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.penguinNavy,
                  ),
          ),
        ),
      ],
    ),
  );
}
