import '../../../utils/services/supabase_service.dart';
import '../models/home_model.dart';
import 'home_repository_interface.dart';

class HomeRepository implements IHomeRepository {
  HomeRepository(this.service);
  final SupabaseService service;
  @override
  Future<HomeModel> get() async =>
      HomeModel.fromJson(await service.call('home.get'));
}
