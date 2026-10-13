import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';
import '../repositories/load_repository_interface.dart';

class LoadFormCubit extends ResourceCubit<LoadFormModel> {
  LoadFormCubit(this.repository);
  final ILoadRepository repository;
  Future<void> load(String id) =>
      fetch(() async => LoadFormModel(load: (await repository.get(id)).load));
  Future<bool> save(LoadDraft draft, {bool edit = false}) => act(() async {
    await repository.save(draft, edit: edit);
  }, notice: edit ? 'Load updated.' : 'Your load is published.');
}
