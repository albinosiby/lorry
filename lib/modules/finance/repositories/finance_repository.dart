import '../../../utils/services/supabase_service.dart';
import '../models/finance_entry_model.dart';
import 'finance_repository_interface.dart';

class FinanceRepository implements IFinanceRepository {
  FinanceRepository(this.service);
  final SupabaseService service;
  @override
  Future<List<FinanceEntryModel>> list() async =>
      (await service.callNext('finance.list') as List)
          .map(
            (row) => FinanceEntryModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
  @override
  Future<FinanceEntryModel> save(FinanceEntryDraft draft) async =>
      FinanceEntryModel.fromJson(
        Map<String, dynamic>.from(
          await service.callNext('finance.save', draft.toJson()),
        ),
      );
}
