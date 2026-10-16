import 'package:shared_preferences/shared_preferences.dart';
import 'language_repository_interface.dart';

class LanguageRepository implements ILanguageRepository {
  final _preferences = SharedPreferencesAsync();
  static const key = 'app_language';
  @override
  Future<String?> read() => _preferences.getString(key);
  @override
  Future<void> save(String code) => _preferences.setString(key, code);
}
