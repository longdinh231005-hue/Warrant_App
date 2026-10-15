import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_widget.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/user_model.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  bool _isLoading = true;
  String? _error;
  List<OwnedDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final devices = await context.read<AuthViewModel>().getMyDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi tải danh sách thiết bị. Vui lòng thử lại.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMock = context.watch<AuthViewModel>().isMock;
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

            // Tra cứu CTA
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: InkWell(
                onTap: () => context.push(AppRoutes.lookup),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tra cứu thiết bị qua Serial/IMEI',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primaryBlue.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isMock = context.watch<AuthViewModel>().isMock;

    if (isMock) {
      if (mockDevices.isEmpty) {
        return _buildEmptyState();
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: mockDevices.length,
        itemBuilder: (context, index) {
          final device = mockDevices[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DeviceCard(device: device),
          );
        },
      );
    } else {
      if (_error != null) {
        return _buildErrorState();
      }
      if (_devices.isEmpty) {
        return _buildEmptyState();
      }
      return RefreshIndicator(
        onRefresh: _fetchDevices,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            final device = _devices[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RealDeviceCard(device: device),
            );
          },
        ),
      );
    }
  }

  Widget _buildEmptyState() {
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
              Icons.devices_outlined,
              size: 36,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có thiết bị nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thiết bị đứng tên bạn sẽ xuất hiện tại đây khi có dữ liệu.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.lookup),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Tra cứu thiết bị'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Đã xảy ra lỗi',
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchDevices,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final MockDevice device;

  @override
  Widget build(BuildContext context) {
    final warrantyText = device.warrantyExpiryDate == null
        ? 'Chưa có ngày bảo hành Mock'
        : 'Hạn bảo hành mẫu: ${device.warrantyExpiryDate!.toIso8601String().substring(0, 10)}';
    const warrantyColor = AppColors.textSecondary;

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.devices}/detail', extra: device),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForCategory(device.deviceCategory),
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          device.deviceName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.identifierType}: ${device.identifierValue}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: warrantyColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      warrantyText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: warrantyColor,
                      ),
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

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'phone':
        return Icons.smartphone_outlined;
      case 'laptop':
        return Icons.laptop_outlined;
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'tv':
        return Icons.tv_outlined;
      case 'tablet':
        return Icons.tablet_outlined;
      case 'earbuds':
        return Icons.headphones_outlined;
      default:
        return Icons.devices_outlined;
    }
  }
}

class _RealDeviceCard extends StatelessWidget {
  const _RealDeviceCard({required this.device});

  final OwnedDevice device;

  @override
  Widget build(BuildContext context) {
    String warrantyText = 'Không xác định';
    Color warrantyColor = AppColors.textSecondary;

    if (device.warrantyStatus == 'IN_WARRANTY') {
      warrantyText = 'Còn bảo hành';
      if (device.warrantyExpiresOn != null) {
        warrantyText += ' (Đến ${device.warrantyExpiresOn})';
      }
      warrantyColor = AppColors.success;
    } else if (device.warrantyStatus == 'OUT_OF_WARRANTY') {
      warrantyText = 'Hết hạn bảo hành';
      warrantyColor = AppColors.error;
    } else if (device.warrantyStatus == 'NOT_ACTIVATED' ||
        device.warrantyActivatedOn == null) {
      warrantyText = 'Chưa kích hoạt bảo hành';
    }

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.devices}/detail', extra: device),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.devices_outlined,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          device.productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.identifierType}: ${device.serialOrImei}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: warrantyColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      warrantyText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: warrantyColor,
                      ),
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
}
