import '../models/home_model.dart';

abstract interface class IHomeRepository {
  Future<HomeModel> get();
}
