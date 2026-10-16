import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

abstract interface class IPaymentRequestStore {
  Future<String> keyFor(String fingerprint);
  Future<void> clear(String fingerprint);
}

/// Retain an uncertain request across page close/app restart so a network retry
/// cannot create a second income entry for the same collection attempt.
class SecurePaymentRequestStore implements IPaymentRequestStore {
  const SecurePaymentRequestStore();
  static const storage = FlutterSecureStorage();
  String _key(String fingerprint) => 'pending_freight_payment_$fingerprint';
  @override
  Future<String> keyFor(String fingerprint) async {
    final key = _key(fingerprint);
    final existing = await storage.read(key: key);
    if (existing != null) return existing;
    final value = const Uuid().v4();
    await storage.write(key: key, value: value);
    return value;
  }

  @override
  Future<void> clear(String fingerprint) =>
      storage.delete(key: _key(fingerprint));
}

class MemoryPaymentRequestStore implements IPaymentRequestStore {
  final keys = <String, String>{};
  @override
  Future<String> keyFor(String fingerprint) async =>
      keys.putIfAbsent(fingerprint, () => const Uuid().v4());
  @override
  Future<void> clear(String fingerprint) async {
    keys.remove(fingerprint);
  }
}
