import '../../loads/models/load_model.dart';
import 'customer_truck_model.dart';

class CustomerTrucksScreenModel {
  const CustomerTrucksScreenModel({
    required this.trucks,
    required this.openLoads,
    required this.query,
    required this.sort,
  });
  final List<CustomerTruckModel> trucks;
  final List<LoadModel> openLoads;
  final String query, sort;
}
