import '../../../core/state/resource_cubit.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/app_language.dart';
import '../repositories/language_repository_interface.dart';

class LanguageCubit extends ResourceCubit<AppLanguage> {
  LanguageCubit(this.repository);
  final ILanguageRepository repository;
  Future<void> load() => fetch(() async {
    final language = AppLanguage.fromCode(await repository.read());
    await initializeDateFormatting(language.code);
    Intl.defaultLocale = language.code;
    return language;
  });
  Future<bool> select(AppLanguage language) async {
    final saved = await act(() async {
      await initializeDateFormatting(language.code);
      await repository.save(language.code);
    });
    if (saved && !isClosed) {
      Intl.defaultLocale = language.code;
      emit(ResourceState(data: language));
    }
    return saved;
  }
}
