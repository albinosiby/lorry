import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

void showNotice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LocalizedText(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message, {
  String confirm = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: LocalizedText(title),
        content: LocalizedText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const LocalizedText('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: LocalizedText(confirm),
          ),
        ],
      ),
    ) ??
    false;
Future<String?> cancellationReason(
  BuildContext context, {
  String title = 'Cancel booking?',
  String fieldLabel = 'Reason',
  String confirmLabel = 'Cancel booking',
}) async {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: LocalizedText(title),
      content: Form(
        key: form,
        child: TextFormField(errorBuilder: (context, message) => LocalizedText(message), 
          controller: controller,
          maxLength: 300,
          decoration: localizedDecoration(
            context,
            InputDecoration(
              labelText: fieldLabel,
              hintText: 'Tell the other party why',
            ),
          ),
          validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Please enter a reason.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const LocalizedText('Go back'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: LocalizedText(confirmLabel),
        ),
      ],
    ),
  );
  // The dialog route finishes its closing animation before disposing its field.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}
