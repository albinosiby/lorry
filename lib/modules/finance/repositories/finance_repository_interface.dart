import '../models/finance_entry_model.dart';

abstract interface class IFinanceRepository {
  Future<List<FinanceEntryModel>> list();
  Future<FinanceEntryModel> save(FinanceEntryDraft draft);
}
