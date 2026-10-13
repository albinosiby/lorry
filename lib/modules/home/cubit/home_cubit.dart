import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/home_model.dart';
import '../repositories/home_repository_interface.dart';

class HomeCubit extends ResourceCubit<HomeModel> {
  HomeCubit(this.repository);
  final IHomeRepository repository;
  Future<void> load() => fetch(repository.get);
}
