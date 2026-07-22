abstract final class ClientsVendorsRouteNames {
  static const String clients = '/clients_vendors/clients';
  static const String vendors = '/clients_vendors/vendors';
  static const String accountsReceivable =
      '/clients_vendors/accounts_receivable';
  static const String outstandingInvoices =
      '/clients_vendors/outstanding_invoices';
}

class OutstandingInvoicesArgs {
  const OutstandingInvoicesArgs({
    this.year,
    this.month,
    this.partnerId,
    this.partnerName,
  });

  final int? year;
  final int? month;
  final int? partnerId;
  final String? partnerName;
}
