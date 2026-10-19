import 'portal_request_models.dart';
import 'portal_ticket_models.dart';

/// Only the record authorized by the short-lived portal lookup grant.
class PortalLookupRecord {
  const PortalLookupRecord.request(this.request) : ticket = null;
  const PortalLookupRecord.ticket(this.ticket) : request = null;

  final PortalRequestDetail? request;
  final PortalTicketDetail? ticket;
}
