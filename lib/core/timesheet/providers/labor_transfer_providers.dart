import 'package:el_race/core/timesheet/models/labor_transfer_models.dart';
import 'package:el_race/core/timesheet/network/labor_transfer_api.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final laborTransferApiProvider = Provider<LaborTransferApi>((ref) {
  final client = ref.watch(timesheetApiClientProvider);
  return LaborTransferApi(client.transport);
});

final laborTransferDetailProvider = FutureProvider.autoDispose
    .family<LaborTransferRecord, int>((ref, id) async {
  final api = ref.watch(laborTransferApiProvider);
  return api.detail(id);
});

/// Badge counts for Labor Transfers entry + To approve tab.
final laborTransferCountsProvider =
    FutureProvider.autoDispose<LaborTransferCounts>((ref) async {
  final api = ref.watch(laborTransferApiProvider);
  try {
    return await api.counts();
  } catch (_) {
    return LaborTransferCounts.empty;
  }
});
