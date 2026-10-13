import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';
import '../repositories/load_repository_interface.dart';

class LoadsCubit extends ResourceCubit<LoadsScreenModel> {
  LoadsCubit(this.repository);
  final ILoadRepository repository;
  bool _mine = false;
  LoadFilter _filter = const LoadFilter();
  Future<void> load({bool? mine, LoadFilter? filter}) async {
    _mine = mine ?? _mine;
    _filter = filter ?? _filter;
    final current = _filter;
    final mineValue = _mine;
    await fetch(() async {
      final rows = await repository.list(mine: mineValue, filter: current);
      return LoadsScreenModel(rows, current, rows.length == 20);
    });
  }

  Future<void> more() async {
    final previous = state.data;
    if (previous == null || !previous.hasMore || state.loading) return;
    await fetch(() async {
      final rows = await repository.list(
        mine: _mine,
        filter: previous.filter,
        offset: previous.loads.length,
      );
      return LoadsScreenModel(
        [...previous.loads, ...rows],
        previous.filter,
        rows.length == 20,
      );
    });
  }
}
