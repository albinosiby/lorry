import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/state/resource_cubit.dart';
import '../cubit/language_cubit.dart';
import '../models/app_language.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LanguageCubit, ResourceState<AppLanguage>>(
        builder: (context, state) {
          final current = state.data ?? AppLanguage.english;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: LocalizedText(current.languageLabel),
                  subtitle: Text(
                    current.nativeName == current.englishName
                        ? current.nativeName
                        : '${current.nativeName} · ${current.englishName}',
                  ),
                  trailing: const Icon(Icons.expand_more),
                  onTap: state.busy || state.loading
                      ? null
                      : () => _choose(context),
                ),
              ),
              if (state.error != null)
                LocalizedText(
                  'Could not save your language. Please try again.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          );
        },
      );

  Future<void> _choose(BuildContext context) async {
    final cubit = context.read<LanguageCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<LanguageCubit, ResourceState<AppLanguage>>(
          builder: (sheetContext, state) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LocalizedText(
                      'Choose language / भाषा / ഭാഷ',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    for (final language in AppLanguage.values)
                      ListTile(
                        title: Text(language.nativeName),
                        subtitle: Text(language.englishName),
                        selected:
                            language == (state.data ?? AppLanguage.english),
                        trailing: Icon(
                          language == (state.data ?? AppLanguage.english)
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        onTap: state.busy
                            ? null
                            : () async {
                                final saved = await cubit.select(language);
                                if (saved && sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                      ),
                    if (state.error != null)
                      const LocalizedText(
                        'Could not save language. Please try again.',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
