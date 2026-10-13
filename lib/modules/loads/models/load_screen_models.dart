import 'load_model.dart';

class LoadsScreenModel {
  const LoadsScreenModel(this.loads, this.filter, this.hasMore);
  final List<LoadModel> loads;
  final LoadFilter filter;
  final bool hasMore;
}

class LoadDetailsModel {
  const LoadDetailsModel(
    this.load, {
    this.ownerName = '',
    this.ownerPhone = '',
  });
  final LoadModel load;
  final String ownerName, ownerPhone;
}

class LoadFormModel {
  const LoadFormModel({this.load});
  final LoadModel? load;
}
