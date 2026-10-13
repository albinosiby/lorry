import '../../../utils/services/contact_service.dart';
import '../../../utils/services/supabase_service.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';
import 'load_repository_interface.dart';

class LoadRepository implements ILoadRepository {
  LoadRepository(this.service);
  final SupabaseService service;
  @override
  Future<void> callContact(String phone) => ContactService().call(phone);
  @override
  Future<List<LoadModel>> list({
    bool mine = false,
    LoadFilter filter = const LoadFilter(),
    int offset = 0,
  }) async =>
      (await service.call('loads.list', {
                'mine': mine,
                ...filter.toJson(),
                'offset': offset,
              })
              as List)
          .map((j) => LoadModel.fromJson(j))
          .toList();
  @override
  Future<LoadDetailsModel> get(String id) async {
    final j = await service.call('loads.get', {'id': id});
    return LoadDetailsModel(
      LoadModel.fromJson(j),
      ownerName: j['owner_name'] ?? '',
      ownerPhone: j['owner_phone'] ?? '',
    );
  }

  @override
  Future<LoadModel> save(LoadDraft draft, {bool edit = false}) async =>
      LoadModel.fromJson(
        await service.call(
          edit ? 'loads.edit' : 'loads.create',
          draft.toJson(),
        ),
      );
  @override
  Future<void> cancel(String id) async {
    await service.call('loads.cancel', {'id': id});
  }
}
