import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppStatusChip
// ─────────────────────────────────────────────────────────────────────────────

/// A small pill-shaped status label used throughout the app.
///
/// Color is never the sole indicator of status; the [label] text always conveys
/// the state. Colors are consistent with [AppColors] semantic tokens:
///   • [TicketStatus.completed] and [TicketStatus.delivered] → success green
///   • [TicketStatus.awaitingCustomerConfirmation] and quote-related → warning amber
///   • [TicketStatus.received] and [RequestStatus.pendingIntake] → neutral grey
///   • [TicketStatus.awaitingReturn] → warning; returnedUnrepaired → muted
///   • Everything else in progress → primary blue tint
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.chipColor,
    required this.textColor,
  });

  final String label;
  final Color chipColor;
  final Color textColor;

  /// Creates a chip pre-styled for a [TicketStatus].
  factory AppStatusChip.forTicket(TicketStatus status) {
    final (bg, fg) = _ticketColors(status);
    return AppStatusChip(label: status.label, chipColor: bg, textColor: fg);
  }

  /// Creates a chip pre-styled for a [RequestStatus].
  factory AppStatusChip.forRequest(RequestStatus status) {
    final (bg, fg) = _requestColors(status);
    return AppStatusChip(label: status.label, chipColor: bg, textColor: fg);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.2,
        ),
      ),
    );
  }

  static (Color bg, Color fg) _ticketColors(TicketStatus s) {
    switch (s) {
      case TicketStatus.completed:
      case TicketStatus.delivered:
        return (const Color(0xFFD1FAE5), AppColors.success);
      case TicketStatus.awaitingCustomerConfirmation:
      case TicketStatus.awaitingQuoteApproval:
      case TicketStatus.awaitingReturn:
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case TicketStatus.returnedUnrepaired:
        return (AppColors.cardGrey, AppColors.textSecondary);
      case TicketStatus.received:
        return (const Color(0xFFF1F5F9), AppColors.textSecondary);
      default:
        // In-progress states: inspecting, diagnosed, awaitingParts, repairing
        return (AppColors.primaryLight, AppColors.primaryBlue);
    }
  }

  static (Color bg, Color fg) _requestColors(RequestStatus s) {
    switch (s) {
      case RequestStatus.pendingIntake:
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case RequestStatus.converted:
        return (const Color(0xFFD1FAE5), AppColors.success);
      case RequestStatus.cancelled:
        return (AppColors.cardGrey, AppColors.textSecondary);
    }
  }
}
