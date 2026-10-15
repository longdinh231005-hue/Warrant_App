import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/portal_request_models.dart';
import '../../models/user_model.dart';
import '../../router/app_router.dart';
import '../../services/i_api_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/request_viewmodel.dart';
import '../../widgets/app_bar_widget.dart';

/// Real customer submission. The device comes only from /portal/my/devices;
/// catalog codes are chosen explicitly because OwnedDevice has no type code.
class RealCreateRequestScreen extends StatefulWidget {
  const RealCreateRequestScreen({super.key, this.prefilledDevice});
  final OwnedDevice? prefilledDevice;

  @override
  State<RealCreateRequestScreen> createState() =>
      _RealCreateRequestScreenState();
}

class _RealCreateRequestScreenState extends State<RealCreateRequestScreen> {
  final _symptomController = TextEditingController();
  PortalCatalog? _catalog;
  List<OwnedDevice> _devices = [];
  OwnedDevice? _device;
  String? _categoryCode;
  String? _deviceTypeCode;
  String? _stationCode;
  Map<String, String> _errors = {};
  String? _loadError;
  String? _submitError;
  String? _submittedCode;
  bool _loading = true;
  bool _submitting = false;
  bool _uncertain = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<AuthViewModel>();
      final catalog = await api.getPortalCatalog();
      final devices = await api.getMyDevices();
      if (!mounted) return;
      OwnedDevice? selected;
      if (widget.prefilledDevice != null) {
        final original = widget.prefilledDevice!;
        for (final candidate in devices) {
          if (candidate.code == original.code &&
              candidate.serialOrImei == original.serialOrImei) {
            selected = candidate;
            break;
          }
        }
        if (selected == null) {
          throw const ApiException(
            'Thiết bị đã chọn không còn trong danh sách sở hữu. Vui lòng tải lại danh sách thiết bị.',
          );
        }
      }
      setState(() {
        _catalog = catalog;
        _devices = devices;
        _device = selected;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is ApiException
            ? error.message
            : 'Không tải được danh mục hoặc thiết bị. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  List<PortalCategory> get _categories {
    final identifier = _device?.identifierType.toUpperCase();
    return (_catalog?.categories ?? [])
        .where(
          (category) => category.deviceTypes.any(
            (type) => type.identifierType.toUpperCase() == identifier,
          ),
        )
        .toList();
  }

  List<PortalDeviceType> get _types {
    final category = _categories
        .where((item) => item.code == _categoryCode)
        .firstOrNull;
    return category?.deviceTypes
            .where(
              (type) =>
                  type.identifierType.toUpperCase() ==
                  _device?.identifierType.toUpperCase(),
            )
            .toList() ??
        [];
  }

  Future<void> _submit() async {
    if (_submitting || _uncertain || _catalog == null) return;
    FocusScope.of(context).unfocus();
    final errors = OwnWarrantyRequestData.validate(
      device: _device,
      catalog: _catalog!,
      categoryCode: _categoryCode,
      deviceTypeCode: _deviceTypeCode,
      stationCode: _stationCode,
      symptom: _symptomController.text,
    );
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    final device = _device!;
    final data = OwnWarrantyRequestData(
      categoryCode: _categoryCode!,
      deviceTypeCode: _deviceTypeCode!,
      brandModel: OwnWarrantyRequestData.brandModelOf(device),
      identifierType: device.identifierType.toUpperCase(),
      serialOrImei: device.serialOrImei.trim(),
      symptom: _symptomController.text.trim(),
      preferredStation: _stationCode!,
    );
    setState(() {
      _submitting = true;
      _errors = {};
      _submitError = null;
    });
    try {
      final requests = context.read<RequestViewModel>();
      final code = await requests.submit(data);
      if (!mounted) return;
      setState(() => _submittedCode = code);
      // Fetch from the API; never insert a local copy of the submitted request.
      requests.refresh();
    } on NetworkException {
      if (!mounted) return;
      setState(() {
        _uncertain = true;
        _submitError =
            'Chưa xác định máy chủ đã nhận yêu cầu hay chưa. Hãy kiểm tra danh sách yêu cầu trước khi gửi lại để tránh tạo trùng.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _uncertain =
            error.statusCode == null ||
            error.statusCode! < 400 ||
            error.statusCode! >= 500;
        _errors = error.fieldErrors.map(
          (field, message) => MapEntry(field, _fieldError(field, message)),
        );
        _submitError = _uncertain
            ? 'Chưa xác định yêu cầu đã được tạo hay chưa. Hãy kiểm tra danh sách trước khi gửi lại.'
            : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uncertain = true;
        _submitError =
            'Chưa xác định yêu cầu đã được tạo hay chưa. Hãy kiểm tra danh sách trước khi gửi lại.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _fieldError(String field, String backendMessage) {
    final label = switch (field) {
      'categoryCode' => 'Nhóm thiết bị',
      'deviceTypeCode' => 'Loại thiết bị',
      'brandModel' => 'Tên thiết bị',
      'identifierType' => 'Loại mã',
      'serialOrImei' => 'Serial/IMEI',
      'symptom' => 'Mô tả lỗi',
      'preferredStation' => 'Trạm dịch vụ',
      _ => field,
    };
    final english = backendMessage.toLowerCase();
    if (english.contains('must not be blank') || english.contains('required')) {
      return '$label là bắt buộc.';
    }
    if (english.contains('size must be between')) {
      return '$label vượt quá độ dài cho phép.';
    }
    return '$label: $backendMessage';
  }

  @override
  Widget build(BuildContext context) {
    if (_submittedCode != null) return _success();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const WarrantSafeAppBar(),
            WarrantSafeTitleRow(
              title: 'Gửi yêu cầu bảo hành / sửa chữa',
              onBackTap: () => context.pop(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? _loadFailure()
                  : _form(),
            ),
            if (!_loading && _loadError == null && !_uncertain) _submitButton(),
          ],
        ),
      ),
    );
  }

  Widget _loadFailure() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _load, child: const Text('Tải lại')),
        ],
      ),
    ),
  );

  Widget _form() {
    final device = _device;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'Thông tin liên hệ được lấy từ hồ sơ tài khoản đang đăng nhập.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (widget.prefilledDevice != null && device != null)
          _deviceIdentity(device)
        else
          _select(
            'Thiết bị của bạn *',
            device?.code,
            _devices
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(
                      '${OwnWarrantyRequestData.brandModelOf(item)} · ${item.serialOrImei}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            (code) => setState(() {
              _device = _devices.where((item) => item.code == code).firstOrNull;
              _categoryCode = null;
              _deviceTypeCode = null;
              _errors = {};
            }),
            _errors['device'],
          ),
        if (device == null && _devices.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Tài khoản chưa có thiết bị sở hữu để gửi yêu cầu từ ứng dụng.',
          ),
        ],
        const SizedBox(height: 16),
        if (device != null) ...[
          if (widget.prefilledDevice == null) _deviceIdentity(device),
          const SizedBox(height: 16),
          const Text(
            'Chọn loại thiết bị trong danh mục của trung tâm. Mã loại không có trong hồ sơ thiết bị nên cần bạn xác nhận.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _select(
            'Nhóm thiết bị *',
            _categoryCode,
            _categories
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            (code) => setState(() {
              _categoryCode = code;
              _deviceTypeCode = null;
              _errors = {};
            }),
            _errors['categoryCode'],
          ),
          const SizedBox(height: 16),
          _select(
            'Loại thiết bị *',
            _deviceTypeCode,
            _types
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            _categoryCode == null
                ? null
                : (code) => setState(() {
                    _deviceTypeCode = code;
                    _errors = {};
                  }),
            _errors['deviceTypeCode'],
          ),
          const SizedBox(height: 16),
          const Text(
            'Mô tả lỗi *',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _symptomController,
            maxLines: 5,
            minLines: 3,
            maxLength: 2000,
            onChanged: (_) => setState(() => _errors.remove('symptom')),
            decoration: InputDecoration(
              hintText: 'Mô tả tình trạng thiết bị đang gặp phải',
              errorText: _errors['symptom'],
            ),
          ),
          const SizedBox(height: 16),
          _select(
            'Trạm dịch vụ mong muốn *',
            _stationCode,
            (_catalog?.stations ?? [])
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            (code) => setState(() {
              _stationCode = code;
              _errors.remove('preferredStation');
            }),
            _errors['preferredStation'],
          ),
          const SizedBox(height: 24),
          const Text(
            'Ảnh và khoảng thời gian mong muốn là tùy chọn theo API. Phiên bản này gửi yêu cầu không kèm ảnh hoặc thời gian hẹn.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Gửi yêu cầu trực tuyến không có nghĩa trung tâm đã nhận thiết bị. Trạng thái tiếp nhận sẽ được cập nhật theo quy trình thực tế.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
        if (_submitError != null) ...[
          const SizedBox(height: 18),
          Text(_submitError!, style: const TextStyle(color: AppColors.error)),
          for (final message in _errors.values)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (_uncertain) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.requests),
              child: const Text('Kiểm tra danh sách yêu cầu'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _deviceIdentity(OwnedDevice device) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          OwnWarrantyRequestData.brandModelOf(device),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text('${device.identifierType}: ${device.serialOrImei}'),
        if (_errors['device'] != null)
          Text(
            _errors['device']!,
            style: const TextStyle(color: AppColors.error),
          ),
      ],
    ),
  );

  Widget _select(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?>? onChanged,
    String? error,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: value,
        key: ValueKey('$label:$value'),
        isExpanded: true,
        hint: const Text('Vui lòng chọn'),
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(errorText: error),
      ),
    ],
  );

  Widget _submitButton() => Container(
    color: AppColors.white,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: ElevatedButton(
      onPressed: _submitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
      ),
      child: _submitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text('GỬI YÊU CẦU'),
    ),
  );

  Widget _success() => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 68,
              ),
              const SizedBox(height: 18),
              const Text(
                'Đã tạo yêu cầu',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Mã yêu cầu do hệ thống cấp: $_submittedCode',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Yêu cầu đã được ghi nhận trực tuyến. Trung tâm chưa xác nhận đã nhận thiết bị.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(
                  '${AppRoutes.requests}/${Uri.encodeComponent(_submittedCode!)}',
                ),
                child: const Text('XEM CHI TIẾT YÊU CẦU'),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.requests),
                child: const Text('XEM DANH SÁCH'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
