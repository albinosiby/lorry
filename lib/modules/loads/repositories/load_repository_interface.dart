import '../models/load_model.dart';
import '../models/load_screen_models.dart';

abstract interface class ILoadRepository {
  Future<void> callContact(String phone);
  Future<List<LoadModel>> list({
    bool mine = false,
    LoadFilter filter = const LoadFilter(),
    int offset = 0,
  });
  Future<LoadDetailsModel> get(String id);
  Future<LoadModel> save(LoadDraft draft, {bool edit = false});
  Future<void> cancel(String id);
}
