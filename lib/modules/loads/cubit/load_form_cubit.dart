import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/services/place_search_service.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';
import '../repositories/load_repository_interface.dart';

class LoadFormCubit extends ResourceCubit<LoadFormModel> {
  LoadFormCubit(this.repository, this.placeSearch);
  final ILoadRepository repository;
  final IPlaceSearchService placeSearch;
  Future<void> load(String id) =>
      fetch(() async => LoadFormModel(load: (await repository.get(id)).load));
  Future<bool> save(LoadDraft draft, {bool edit = false}) => act(() async {
    await repository.save(draft, edit: edit);
  }, notice: edit ? 'Load updated.' : 'Your load is published.');

  Future<List<PlaceSearchResult>> searchPlace(String query) =>
      placeSearch.search(query);
}
