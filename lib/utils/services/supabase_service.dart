import 'package:supabase_flutter/supabase_flutter.dart';
import '../exceptions/app_exception.dart';
import 'workflow_sync_service.dart';

class SupabaseService {
  SupabaseService(this.client);
  final SupabaseClient client;
  Future<dynamic> _rpc(
    String rpc,
    String action,
    Map<String, dynamic> payload,
  ) async {
    final result = await client.rpc(
      rpc,
      params: {'action': action, 'payload': payload},
    );
    if (!action.endsWith('.get') && !action.endsWith('.list')) {
      WorkflowEvents.changed();
    }
    return result;
  }

  Future<T> guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      throw AppException.from(error);
    }
  }

  Future<dynamic> call(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) => guard(() => _rpc('lorry_api', action, payload));

  /// Role-scoped commands introduced by the logistics marketplace expansion.
  /// It is separate from the original API so existing bookings keep their
  /// tested transition behaviour during the incremental rollout.
  Future<dynamic> callNext(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) => guard(() => _rpc('lorry_next_api', action, payload));

  /// Protected customer-only marketplace commands: verification documents,
  /// availability discovery/invitations, and active-trip location sharing.
  Future<dynamic> callCustomer(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) => guard(() => _rpc('lorry_customer_api', action, payload));

  /// Calls a protected Edge Function. Provider keys (for example Google Places)
  /// belong in that function's secrets and must never be bundled with the app.
  Future<dynamic> invokeFunction(
    String name, [
    Map<String, dynamic> body = const {},
  ]) =>
      guard(() async => (await client.functions.invoke(name, body: body)).data);
}
