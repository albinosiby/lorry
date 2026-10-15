import '../../vehicles/models/vehicle_model.dart';
import 'driver_document_model.dart';

class DriverDocumentsScreenModel {
  const DriverDocumentsScreenModel({
    required this.documents,
    required this.vehicles,
  });

  final List<DriverDocumentModel> documents;
  final List<VehicleModel> vehicles;
}
