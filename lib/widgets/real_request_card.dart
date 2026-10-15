import 'package:flutter/material.dart';
import '../models/portal_request_models.dart';
import '../theme/app_theme.dart';

class RealRequestCard extends StatelessWidget {
  const RealRequestCard({super.key, required this.request, this.onTap});
  final PortalRequestSummary request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices_outlined, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.brandModel?.isNotEmpty == true
                      ? request.brandModel!
                      : 'Thiết bị',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mã yêu cầu ${request.code}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (request.serialOrImei?.isNotEmpty == true)
                  Text(
                    request.serialOrImei!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 7),
                Text(
                  portalRequestStatusLabel(request.status),
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    ),
  );
}
