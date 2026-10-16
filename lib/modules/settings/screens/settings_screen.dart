import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../design_system/design_system.dart';
import '../cubit/language_cubit.dart';
import '../models/app_language.dart';
import '../widgets/language_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final language =
        context.watch<LanguageCubit>().state.data ?? AppLanguage.english;
    return Scaffold(
      appBar: AppBar(title: LocalizedText(language.settingsLabel)),
      body: const PageBody(
        narrow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LanguagePicker(),
            SizedBox(height: 12),
            LocalizedText('Your language choice is saved on this device.'),
          ],
        ),
      ),
    );
  }
}
