abstract final class ClientsVendorsRouteNames {
  static const String clients = '/clients_vendors/clients';
  static const String vendors = '/clients_vendors/vendors';
  static const String accountsReceivable =
      '/clients_vendors/accounts_receivable';
  static const String outstandingInvoices =
      '/clients_vendors/outstanding_invoices';
  static const String vendorBills = '/clients_vendors/vendor_bills';
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

class VendorBillsArgs {
  const VendorBillsArgs({
    required this.scope,
    this.year,
    this.month,
    this.partnerId,
    this.partnerName,
  });

  /// One of: purchases | paid | outstanding | overdue | due_soon
  final String scope;
  final int? year;
  final int? month;
  final int? partnerId;
  final String? partnerName;
}
