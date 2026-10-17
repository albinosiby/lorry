import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/support_request.dart';
import '../services/formspree_support_service.dart';

class SupportCubit extends ResourceCubit<void> {
  SupportCubit(this.service);
  final FormspreeSupportService service;

  Future<bool> submit(SupportRequest request) => act(
    () => service.submit(request),
    notice: 'Your support request has been sent.',
  );
}
