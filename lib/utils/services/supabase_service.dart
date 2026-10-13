import 'package:supabase_flutter/supabase_flutter.dart';
import '../exceptions/app_exception.dart';

class SupabaseService {
  SupabaseService(this.client);
  final SupabaseClient client;
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
  ]) => guard(
    () =>
        client.rpc('lorry_api', params: {'action': action, 'payload': payload}),
  );
}
