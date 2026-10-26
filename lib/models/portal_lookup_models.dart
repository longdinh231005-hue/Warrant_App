import 'portal_request_models.dart';
import 'portal_ticket_models.dart';

/// A request or ticket returned after backend authorization.
class PortalLookupRecord {
  const PortalLookupRecord.request(this.request) : ticket = null;
  const PortalLookupRecord.ticket(this.ticket) : request = null;

  final PortalRequestDetail? request;
  final PortalTicketDetail? ticket;
}
