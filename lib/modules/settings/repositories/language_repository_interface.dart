abstract interface class ILanguageRepository {
  Future<String?> read();
  Future<void> save(String code);
}
