import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/finance_entry_model.dart';
import '../repositories/finance_repository_interface.dart';

class FinanceCubit extends ResourceCubit<List<FinanceEntryModel>> {
  FinanceCubit(this.repository);
  final IFinanceRepository repository;
  Future<void> load() => fetch(repository.list);
  Future<bool> save(FinanceEntryDraft draft) => act(() async {
    await repository.save(draft);
    await load();
  }, notice: 'Finance entry saved.');
}
